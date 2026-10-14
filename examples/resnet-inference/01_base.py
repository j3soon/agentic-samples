import os
import sys
import time

import nvtx
import torch
from torch.utils.data import DataLoader, Subset
from torchvision import transforms
from torchvision.models import ResNet152_Weights, resnet152
from imagenetv2_pytorch import ImageNetV2Dataset


DATA_DIR = "./data"
MAX_IMAGES = 10000
WARMUP_RUNS = 3


# Ref: https://pytorch.org/hub/pytorch_vision_resnet/
def imagenet_preprocess():
    return transforms.Compose(
        [
            transforms.Resize(256),
            transforms.CenterCrop(224),
            transforms.ToTensor(),
            transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
        ]
    )


def main():
    assert torch.cuda.is_available(), "CUDA required."

    max_images = int(sys.argv[1]) if len(sys.argv) > 1 else MAX_IMAGES
    device = torch.device("cuda")

    model = resnet152(weights=ResNet152_Weights.IMAGENET1K_V1).to(device).eval()
    os.makedirs(DATA_DIR, exist_ok=True)
    dataset = ImageNetV2Dataset(
        variant="matched-frequency",
        transform=imagenet_preprocess(),
        location=DATA_DIR,
    )
    dataset = Subset(dataset, range(max_images))
    loader = DataLoader(dataset, shuffle=False)

    dummy = torch.randn(1, 3, 224, 224, device=device)
    with torch.inference_mode():
        with nvtx.annotate("warmup"):
            for _ in range(WARMUP_RUNS):
                model(dummy)
    torch.cuda.synchronize()

    top1_correct = 0
    top5_correct = 0

    with torch.inference_mode():
        def run_batch(images, targets):
            nonlocal top1_correct, top5_correct

            with nvtx.annotate("h2d_transfer"):
                images = images.to(device)
                targets = targets.to(device)

            with nvtx.annotate("forward_pass"):
                logits = model(images)

            with nvtx.annotate("accuracy"):
                _, pred = logits.topk(5, dim=1)
                matches = pred.eq(targets.view(-1, 1))
                top1_correct += matches[:, :1].sum().item()
                top5_correct += matches.sum().item()

        loader_iter = iter(loader)
        with nvtx.annotate("first_batch"):
            images, targets = next(loader_iter)
            run_batch(images, targets)

        torch.cuda.synchronize()
        start = time.perf_counter()

        for images, targets in loader_iter:
            run_batch(images, targets)

        torch.cuda.synchronize()
        elapsed_s = time.perf_counter() - start

    latency_ms = elapsed_s * 1000.0
    timed_images = len(dataset) - 1
    fps = timed_images / elapsed_s
    top1 = 100.0 * top1_correct / len(dataset)
    top5 = 100.0 * top5_correct / len(dataset)

    print(
        f"throughput: {fps:.2f} img/s, latency for {timed_images} images: "
        f"{latency_ms:.3f} ms, images: {len(dataset)}, top-1: {top1:.2f}%, "
        f"top-5: {top5:.2f}%"
    )


if __name__ == "__main__":
    main()
