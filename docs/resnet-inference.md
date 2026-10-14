# ResNet inference on Nano4

Optional commands for [README example 5](../README.md#5-use-nvidia-skills-for-optimization).
The [task brief](../examples/resnet-inference/TASK.md) defines measurement and
correctness. Keep the agent local and run workloads on Nano4 through Slurm.

## Manual baseline

After README step 3, reuse its SSH connection and PyTorch SIF. Run locally from
the repository root, replacing the SIF placeholder with your existing image:

```bash
nano4_account=$(sed -n 's/^NCHC_ISERVICE_SUPERCOMPUTER_ACCOUNT=//p' secrets/.env)
export NCHC_REMOTE_DIR="/work/$nano4_account/resnet-inference-$(date +%Y%m%d-%H%M%S)"
pytorch_sif=/work/YOUR_SUPERCOMPUTER_ACCOUNT/YOUR_RUN/container.sif

bash scripts/nano4/exec.sh mkdir -p "$NCHC_REMOTE_DIR/example"
rsync -a --protect-args --exclude=reference/ \
  -e "ssh -o \"ControlPath=$HOME/.ssh/nano4-control/%C\" -o BatchMode=yes" \
  examples/resnet-inference/ "$nano4_account@nano4.nchc.org.tw:$NCHC_REMOTE_DIR/example/"
bash scripts/nano4/submit.sh examples/resnet-inference/baseline.slurm "$pytorch_sif" 10000
```

The submission helper applies `cluster/nano4/excluded-nodes.txt`. The script
requests one H200, 12 CPUs, 32 GB RAM, and 20 minutes. These are example defaults.
First-run downloads may need a longer allocation. Allow about 3 GB for images
and weights, plus the SIF, and check your account quota before downloading.
The wrapper installs the two additional dependencies in a private environment
that inherits the SIF's PyTorch. Images go to `data/`, weights to `cache/torch/`.

Keep the same `NCHC_REMOTE_DIR` for status and download:

```bash
bash scripts/nano4/status.sh
```

After Slurm reports `COMPLETED` with exit code `0:0`, collect logs and artifacts.
Replace `JOB_ID` with the downloaded job ID:

```bash
bash scripts/nano4/download.sh logs artifacts submission
mkdir -p artifacts/resnet-inference
cp -R results/JOB_ID artifacts/resnet-inference/baseline-JOB_ID
bash scripts/nano4/exec.sh squeue --me
```

Record the source hash, resources, versions, remote directory, and SIF path in
the journal. The original timer covers 9,999 images. Establish a matching
full-dataset timer before claiming a speedup. For disconnected SSH or uncertain
submission, use README step 3's handoff and
[submission recovery](nano4.md#submission-recovery).

## Profiling and review

Locate Nsight Systems and its bundled skill in the workload environment. Copy
the complete pack for the agent, including its references and scripts. Follow
its bootstrap and prepare missing analysis dependencies privately on a Nano4
compute node using the reported interpreter. Do not assume local CUDA tools.
Use a private `NSYS_TMPDIR` for captures to avoid shared-directory ownership issues.

Profile matching inputs with CUDA and NVTX activity. Check capture health before
interpreting events. Pair timeline screenshots or event plots with unprofiled
throughput and correctness checks. Preserve native reports under
`artifacts/resnet-inference/` and explain the limits of short captures.

## Recorded example

The final [implementation](../examples/resnet-inference/reference/dali.py) uses
TensorRT FP16, DALI GPU JPEG decoding and transforms, batch 128, 11 DALI threads,
and one PyTorch CPU thread. The final 16 images use the original PIL transforms
inside the timer. Synthetic JPEG warmup initializes operators without predecoding
the dataset. The [baseline measurement](../examples/resnet-inference/reference/measure.py)
uses the same full-dataset timing boundaries and original backend defaults.

Job 539335 measured both versions on 25a-hgpn002. Their three-run medians are
76.38 and 4023.64 images/s, giving 52.7× throughput. The optimized version agrees
with 9,905 of 10,000 baseline predictions. Top-1/top-5 accuracy is 66.99%/87.22%,
compared with 66.98%/87.22%. [results.json](../examples/resnet-inference/reference/results.json)
keeps raw benchmark measurements and the software versions.

The throughput chart also shows batched PyTorch FP16 with a parallel loader
(1494.51 images/s) and TensorRT with a CPU input ring (2703.05 images/s).
These intermediate stages used other allocations with matching resource requests,
so placement and load can affect their differences. Their measurements illustrate
the optimization process. The reproduction commands below cover the final version.

The agent read TensorRT's
[ONNX quickstart skill](https://github.com/NVIDIA/TensorRT/tree/16ed0636df41e4a27d46f82d9028fc50fadc7200/.agents/skills/trt-onnx-quickstart)
for engine construction and numerical validation, and the
[DALI dynamic-mode skill](https://github.com/NVIDIA/DALI/tree/4dcaea9ac9b1f09972d212bc3b759b1a8fa121c7/skills/dali-dynamic-mode)
for GPU preprocessing. It adapted the guidance to the installed APIs.
An earlier DALI candidate was rejected at 98.89% prediction agreement.
Disabling EXIF orientation adjustment and enabling fancy JPEG upsampling raised
agreement to 99.05%. Across 200 checked images, the maximum normalized pixel
difference from PIL was 0.05276. Two later batch/decoder settings were slower,
so the loop stopped within its budget. This is a tested result, not a global optimum.

Engine export and building took about 149 seconds together. Optimized setup
takes 5.15 to 5.28 seconds, separate from 2.42 to 2.51 seconds of timed inference.
CUDA used memory at the end rises from about 0.98 to 2.78 GiB. This is not peak
memory, and PyTorch allocator statistics exclude private TensorRT/DALI allocations.
Review these costs alongside the throughput gain.

### Reproduce on Nano4

The recorded environment uses `nvcr.io/nvidia/pytorch:26.09-py3`, TensorRT 11.3,
DALI 2.3, and Nsight Systems 2026.5.1. Upload the reference Python files alongside
the baseline under `example/reference/`. Run the following inside the SIF on an
allocated H200 with 12 CPUs, reusing the baseline's private interpreter, images,
and weights. Have the agent prepare missing ONNX export dependencies privately
within the allocation:

```bash
python=.venv/bin/python
export TORCH_HOME="$PWD/cache/torch"
"$python" example/reference/build_engine.py --directory engines
"$python" example/reference/measure.py --data data --output baseline.json
"$python" example/reference/dali.py --data data --engine engines/resnet152_fp16.plan \
  --batch-size 128 --threads 11 --warmup-input --output optimized.json
```

Run separate correctness passes with `--predictions` for each version and compare
all predictions by image path. Add `--check-preprocessing 200` to the DALI
correctness pass. Exclude these diagnostic runs from throughput. Then measure
each version three times without prediction collection and report median and range.

For matching short captures, add `--profile --images 256` and follow the installed
Nsight skill's capture workflow. Its API gates bracket the timed loop.
The recorded skill version is 0.2.0. Both reports pass GPU identity, correlation,
NVTX, and timeline checks. The figures use a baseline window at 2,000 ms and the
optimized second batch at 163.704 ms after first fetch. CPU annotations include
waiting. No CPU scheduling or hardware GPU metrics were captured.

The supported `cuda_gpu_time_util_map` recipe used 200 bins with alignment
disabled. In the close-up's bin, normal and cumulative kernel time are 2.7%
and 2.9%, supporting concurrent kernels. These are time percentages. The captures
do not isolate each change's contribution or establish steady-state overlap.

### Regenerate the figures

[timeline.csv](../examples/resnet-inference/reference/timeline.csv) contains only
the plotted NVTX and CUDA intervals, with stream and correlation IDs.
[timeline.json](../examples/resnet-inference/reference/timeline.json) records
report names, window boundaries, capture counts, and recipe evidence.
[plot.py](../examples/resnet-inference/reference/plot.py) renders these inputs
on a CPU, without CUDA or Nsight:

```bash
python3 -m venv artifacts/resnet-inference/plot-env
artifacts/resnet-inference/plot-env/bin/pip install matplotlib
artifacts/resnet-inference/plot-env/bin/python examples/resnet-inference/reference/plot.py
```

### Independent OpenCode + RAP check

A fresh OpenCode 1.19.0 session using RAP + Kimi-K3 started without the recorded
solution or Git history. It selected PyTorch BF16, batch 128, channels-last,
11 loader workers, pinned memory, and GPU accuracy accumulation, retaining PIL
transforms. Its three-run medians rose from 78.03 to 1831.84 images/s (23.5×).
A full-dataset check at the selected batch size found 99.12% prediction agreement
and 67.02%/87.23% top-1/top-5 accuracy. The timings used separate allocations
with matching one-H200 and 12-CPU requests. The validation covers baseline and
optimization. The Nsight figures use the TensorRT/DALI reference above.

[Return to README example 5](../README.md#5-use-nvidia-skills-for-optimization).
