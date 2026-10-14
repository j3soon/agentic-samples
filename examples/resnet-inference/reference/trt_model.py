"""Run the saved TensorRT engine on PyTorch tensors and the current CUDA stream."""

import torch


class TRTModel:
    def __init__(self, path, max_batch):
        import tensorrt as trt

        logger = trt.Logger(trt.Logger.WARNING)
        self.runtime = trt.Runtime(logger)
        with open(path, "rb") as source:
            self.engine = self.runtime.deserialize_cuda_engine(source.read())
        assert self.engine is not None, "Cannot load TensorRT engine."
        self.context = self.engine.create_execution_context()
        dtypes = {trt.float16: torch.float16, trt.float32: torch.float32}
        self.in_dtype = dtypes[self.engine.get_tensor_dtype("images")]
        dtype = dtypes[self.engine.get_tensor_dtype("logits")]
        self.output = torch.empty(max_batch, 1000, device="cuda", dtype=dtype)

    def __call__(self, images):
        self.context.set_input_shape("images", tuple(images.shape))
        self.context.set_tensor_address("images", images.data_ptr())
        self.context.set_tensor_address("logits", self.output.data_ptr())
        assert self.context.execute_async_v3(torch.cuda.current_stream().cuda_stream)
        return self.output[:len(images)]
