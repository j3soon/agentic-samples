"""Measure the same workload with a full-dataset timer and optional changes."""

import argparse
import json
import os
from pathlib import Path
import time

import nvtx
import torch
from torch.utils.data import DataLoader, Subset
from torchvision import transforms
from torchvision.models import ResNet152_Weights, resnet152
from imagenetv2_pytorch import ImageNetV2Dataset


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--data", default="./data")
    parser.add_argument("--images", type=int, default=10000)
    parser.add_argument("--batch-size", type=int, default=1)
    parser.add_argument("--workers", type=int, default=0)
    parser.add_argument("--precision", choices=["fp32", "fp16"], default="fp32")
    parser.add_argument("--channels-last", action="store_true")
    parser.add_argument("--engine", help="Use a rebuilt TensorRT engine instead of PyTorch.")
    parser.add_argument("--defer-accuracy", action="store_true")
    parser.add_argument("--profile", action="store_true")
    parser.add_argument("--predictions")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    assert torch.cuda.is_available(), "CUDA required."

    preprocessing = transforms.Compose([
        transforms.Resize(256), transforms.CenterCrop(224), transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
    ])
    dataset = ImageNetV2Dataset(variant="matched-frequency", transform=preprocessing,
                              location=args.data)
    assert 2 <= args.images <= len(dataset), "Choose 2 to 10000 images."
    paths = dataset.fnames[:args.images]
    loader = DataLoader(Subset(dataset, range(args.images)), batch_size=args.batch_size,
                        shuffle=False, num_workers=args.workers,
                        pin_memory=args.workers > 0)
    dtype = torch.float16 if args.precision == "fp16" else torch.float32
    if args.engine:
        from trt_model import TRTModel
        assert not args.channels_last, "TensorRT input uses contiguous NCHW."
        model = TRTModel(args.engine, args.batch_size)
        assert dtype == model.in_dtype, "Precision must match the engine input."
    else:
        model = resnet152(weights=ResNet152_Weights.IMAGENET1K_V1).cuda().eval().to(dtype=dtype)
        if args.channels_last:
            model = model.to(memory_format=torch.channels_last)

    predictions = []
    top1 = torch.zeros((), device="cuda", dtype=torch.int64) if args.defer_accuracy else 0
    top5 = torch.zeros((), device="cuda", dtype=torch.int64) if args.defer_accuracy else 0
    stream = torch.cuda.Stream() if args.engine else torch.cuda.current_stream()
    stream.wait_stream(torch.cuda.current_stream())
    with torch.inference_mode(), torch.cuda.stream(stream):
        dummy = torch.randn(args.batch_size, 3, 224, 224, device="cuda", dtype=dtype)
        if args.channels_last:
            dummy = dummy.contiguous(memory_format=torch.channels_last)
        for _ in range(3):
            model(dummy)
        torch.cuda.synchronize()
        if args.profile:
            torch.cuda.profiler.start()
        with nvtx.annotate("benchmark"):
            start = time.perf_counter()
            for images, targets in loader:
                with nvtx.annotate("h2d_transfer"):
                    images = images.to("cuda", dtype=dtype, non_blocking=args.workers > 0)
                    targets = targets.to("cuda", non_blocking=args.workers > 0)
                    if args.channels_last:
                        images = images.contiguous(memory_format=torch.channels_last)
                with nvtx.annotate("forward_pass"):
                    logits = model(images)
                with nvtx.annotate("accuracy"):
                    pred = logits.topk(5, dim=1).indices
                    matches = pred.eq(targets.view(-1, 1))
                    if args.defer_accuracy:
                        top1 += matches[:, :1].sum()
                        top5 += matches.sum()
                    else:
                        top1 += matches[:, :1].sum().item()
                        top5 += matches.sum().item()
                    if args.predictions:
                        predictions.extend(pred[:, 0].cpu().tolist())
            torch.cuda.synchronize()
            top1, top5 = int(top1), int(top5)
            elapsed = time.perf_counter() - start
        if args.profile:
            torch.cuda.profiler.stop()

    result = vars(args) | {
        "elapsed_s": elapsed, "images_per_second": args.images / elapsed,
        "top1_percent": 100 * top1 / args.images,
        "top5_percent": 100 * top5 / args.images,
        "gpu": torch.cuda.get_device_name(), "torch": torch.__version__,
        "peak_gpu_memory_bytes": torch.cuda.max_memory_allocated(),
        "cpu_affinity": sorted(os.sched_getaffinity(0)),
        "cuda_used_bytes_at_end": torch.cuda.mem_get_info()[1] - torch.cuda.mem_get_info()[0],
    }
    Path(args.output).write_text(json.dumps(result, indent=2) + "\n")
    if args.predictions:
        rows = [{"image": str(path.relative_to(Path(args.data))), "top1": pred}
                for path, pred in zip(paths, predictions, strict=True)]
        Path(args.predictions).write_text(json.dumps(rows) + "\n")
    print(json.dumps(result), flush=True)


if __name__ == "__main__":
    main()
