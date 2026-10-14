"""Export the fixed ResNet-152 weights and build an H200 TensorRT FP16 engine."""

import argparse
import json
from pathlib import Path
import time

import onnx
import tensorrt as trt
import torch
from torchvision.models import ResNet152_Weights, resnet152


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", default="engines")
    args = parser.parse_args()
    directory = Path(args.directory)
    directory.mkdir(parents=True, exist_ok=True)
    onnx_path = directory / "resnet152_fp16.onnx"
    model = resnet152(weights=ResNet152_Weights.IMAGENET1K_V1).cuda().half().eval()
    dummy = torch.randn(128, 3, 224, 224, device="cuda", dtype=torch.float16)
    start = time.perf_counter()
    torch.onnx.export(
        model, (dummy,), str(onnx_path), input_names=["images"], output_names=["logits"],
        dynamic_shapes={"x": {0: torch.export.Dim("batch", min=1, max=256)}},
        dynamo=True, external_data=False,
    )
    exported = time.perf_counter()
    graph = onnx.load(onnx_path)
    print("ONNX inputs", [(x.name, x.type.tensor_type.elem_type) for x in graph.graph.input])
    onnx.checker.check_model(graph)
    logger = trt.Logger(trt.Logger.WARNING)
    builder = trt.Builder(logger)
    network = builder.create_network(0)
    importer = trt.OnnxParser(network, logger)
    if not importer.parse_from_file(str(onnx_path)):
        raise RuntimeError([str(importer.get_error(i)) for i in range(importer.num_errors)])
    config = builder.create_builder_config()
    config.builder_optimization_level = 5
    profile = builder.create_optimization_profile()
    profile.set_shape("images", (1, 3, 224, 224), (128, 3, 224, 224), (256, 3, 224, 224))
    config.add_optimization_profile(profile)
    engine = builder.build_serialized_network(network, config)
    assert engine is not None, "TensorRT engine build failed."
    plan_path = directory / "resnet152_fp16.plan"
    plan_path.write_bytes(engine)
    result = {"onnx": str(onnx_path), "engine": str(plan_path),
              "export_seconds": exported - start,
              "build_seconds": time.perf_counter() - exported,
              "torch": torch.__version__, "tensorrt": trt.__version__,
              "gpu": torch.cuda.get_device_name()}
    (directory / "build.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result), flush=True)


if __name__ == "__main__":
    main()
