"""Run ResNet inference with DALI preprocessing and a TensorRT engine."""

import argparse
import json
from io import BytesIO
import os
from pathlib import Path
import time

import numpy as np
import nvtx
from PIL import Image
import torch
from torchvision import transforms
from imagenetv2_pytorch import ImageNetV2Dataset
import nvidia.dali as dali
import nvidia.dali.experimental.dynamic as ndd
from nvidia.dali import types

from trt_model import TRTModel


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--data", default="./data")
    parser.add_argument("--engine", required=True)
    parser.add_argument("--images", type=int, default=10000)
    parser.add_argument("--batch-size", type=int, default=128)
    parser.add_argument("--threads", type=int, default=8)
    parser.add_argument("--huffman-threshold", type=int, default=1000000)
    parser.add_argument("--predictions")
    parser.add_argument("--check-preprocessing", type=int, default=0)
    parser.add_argument("--warmup-input", action="store_true")
    parser.add_argument("--profile", action="store_true")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    setup_start = time.perf_counter()
    torch.set_num_threads(1)
    ndd.set_num_threads(args.threads)
    dataset = ImageNetV2Dataset(variant="matched-frequency", location=args.data)
    files = dataset.fnames[:args.images]
    assert len(files) == args.images
    reader = ndd.readers.File(files=[str(p) for p in files],
                              labels=[int(p.parent.name) for p in files], random_shuffle=False)
    model = TRTModel(args.engine, args.batch_size)
    target_labels = torch.tensor([int(p.parent.name) for p in files], device="cuda")
    def prepare(encoded):
        shapes = ndd.peek_image_shape(encoded, adjust_orientation=False).torch().numpy()[:, :2].astype(np.int64)
        sizes = (shapes * 256 // shapes.min(axis=1, keepdims=True)).astype(np.float32)
        offsets = np.rint((sizes - 224) / 2).astype(np.float32)
        images = ndd.decoders.image(encoded, device="gpu", adjust_orientation=False,
                                   jpeg_fancy_upsampling=True,
                                   hybrid_huffman_threshold=args.huffman_threshold)
        images = ndd.resize(images, size=ndd.as_batch(list(sizes)),
                            interp_type=types.INTERP_LINEAR, antialias=True)
        crop_shapes = ndd.as_batch([np.array([224, 224], dtype=np.float32)] * encoded.batch_size)
        images = ndd.slice(images, ndd.as_batch(list(offsets)), crop_shapes, axes=[0, 1],
                           normalized_anchor=False, normalized_shape=False)
        images = ndd.crop_mirror_normalize(
            images, dtype=types.FLOAT16, output_layout="CHW",
            mean=[0.485 * 255, 0.456 * 255, 0.406 * 255],
            std=[0.229 * 255, 0.224 * 255, 0.225 * 255],
        ).torch().contiguous()
        return images

    stream = torch.cuda.Stream()
    stream.wait_stream(torch.cuda.current_stream())
    with torch.cuda.stream(stream):
        dummy = torch.randn(args.batch_size, 3, 224, 224, device="cuda", dtype=model.in_dtype)
        for _ in range(3):
            model(dummy)
        if args.warmup_input:
            # Warm the operators with a synthetic JPEG, without reading dataset images.
            buffer = BytesIO()
            Image.new("RGB", (500, 375), (128, 128, 128)).save(buffer, format="JPEG")
            encoded = ndd.as_batch([np.frombuffer(buffer.getvalue(), dtype=np.uint8).copy()
                                    for _ in range(args.batch_size)])
            model(prepare(encoded))
        top1 = torch.zeros((), device="cuda", dtype=torch.int64)
        top5 = torch.zeros((), device="cuda", dtype=torch.int64)
    torch.cuda.synchronize()
    setup_seconds = time.perf_counter() - setup_start
    preprocessing = transforms.Compose([
        transforms.Resize(256), transforms.CenterCrop(224), transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
    ])
    predictions = []
    maximum_error = 0.0
    seen = 0
    if args.profile:
        torch.cuda.profiler.start()
    with torch.inference_mode(), torch.cuda.stream(stream), nvtx.annotate("benchmark"):
        start = time.perf_counter()
        iterator = iter(reader.next_epoch(batch_size=args.batch_size))
        while seen < args.images:
            with nvtx.annotate("input"):
                encoded, _ = next(iterator)
                count = min(encoded.batch_size, args.images - seen)
                encoded = ndd.as_batch(encoded.tensors[:count])
            with nvtx.annotate("preprocess"):
                if count < args.batch_size:
                    # The partial final batch uses the preserved PIL path inside the timer.
                    cpu_images = []
                    for path in files[seen:seen + count]:
                        with Image.open(path) as image:
                            cpu_images.append(preprocessing(image))
                    images = torch.stack(cpu_images).to("cuda", dtype=model.in_dtype)
                else:
                    images = prepare(encoded)
                targets = target_labels[seen:seen + count]
            with nvtx.annotate("forward_pass"):
                logits = model(images)
            with nvtx.annotate("accuracy"):
                pred = logits.topk(5, dim=1).indices
                matches = pred.eq(targets.view(-1, 1))
                top1 += matches[:, :1].sum()
                top5 += matches.sum()
                if args.predictions:
                    predictions.extend(pred[:, 0].cpu().tolist())
            for index in range(seen, min(seen + count, args.check_preprocessing)):
                with Image.open(files[index]) as image:
                    reference = preprocessing(image).to("cuda")
                maximum_error = max(maximum_error,
                                    (reference - images[index - seen].float()).abs().max().item())
            seen += count
        torch.cuda.synchronize()
        top1, top5 = int(top1), int(top5)
        elapsed = time.perf_counter() - start
    if args.profile:
        torch.cuda.profiler.stop()
    result = vars(args) | {
        "elapsed_s": elapsed, "images_per_second": args.images / elapsed,
        "top1_percent": top1 / args.images * 100, "top5_percent": top5 / args.images * 100,
        "preprocessing_max_abs": maximum_error if args.check_preprocessing else None,
        "preprocessing_checked_images": min(args.check_preprocessing, args.images),
        "dali": dali.__version__,
        "cpu_tail_images": args.images % args.batch_size, "setup_seconds": setup_seconds,
        "adjust_orientation": False, "jpeg_fancy_upsampling": True,
        "cpu_affinity": sorted(os.sched_getaffinity(0)),
        "peak_pytorch_gpu_allocation_bytes": torch.cuda.max_memory_allocated(),
        "cuda_used_bytes_at_end": torch.cuda.mem_get_info()[1] - torch.cuda.mem_get_info()[0],
    }
    Path(args.output).write_text(json.dumps(result, indent=2) + "\n")
    if args.predictions:
        rows = [{"image": str(path.relative_to(Path(args.data))), "top1": pred}
                for path, pred in zip(files, predictions, strict=True)]
        Path(args.predictions).write_text(json.dumps(rows) + "\n")
    print(json.dumps(result), flush=True)


if __name__ == "__main__":
    main()
