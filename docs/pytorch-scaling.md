# PyTorch scaling reference

Optional supplement to [README step 4](../README.md#4-run-multi-node-workloads-on-nano4).
Complete the single-GPU access check in step 3 first. Run these commands locally
from the repository root with an authenticated Nano4 connection.

Both versions use the same [trainer](../examples/pytorch-scaling/reference/initial/train.py).
The [initial launcher](../examples/pytorch-scaling/reference/initial/train.slurm)
requests 1 CPU per GPU. The
[optimized launcher](../examples/pytorch-scaling/reference/optimized/train.slurm)
requests 12, Nano4's [published H200 maximum](https://man.twcc.ai/@nano4-manual/SJM_FuxDWe).
On an eight-GPU node this changes the allocation from 8 to 96 CPU cores.

The workload is an 88.6M-parameter Transformer using synthetic next-token data,
BF16, AdamW, sequence length 512, and microbatch 4. Weak scaling keeps
128 sequences per GPU and 32 gradient accumulation steps fixed. Global
batch therefore grows from 128 to 1024, 2048, and 4096 sequences as GPUs are added.
Ideally, runtime stays constant while total throughput grows with GPU count.
See [LLNL's scaling explanation](https://hpc.llnl.gov/documentation/tutorials/introduction-parallel-computing-tutorial).

Each job measures one interval of 30 optimizer steps after 2 warmup steps,
targeting 10 to 30 seconds. Timing uses the slowest rank and excludes startup,
warmup, and checkpoint I/O. Warmup plus training targets under one minute.
The two-minute Slurm limit allows startup and checkpoint work. Queue time
and local downloads are separate. This short demo shows an observable
performance difference, not a rigorous benchmark.

## Optional clean workspace

The README demo works in the current repository and agent session. For a
workshop, the [preparation script](../scripts/demos/prepare-scaling.sh) copies
the initial version and tools without the optimized version, recorded results,
or Git history. Ask your agent:

> Prepare a clean scaling demo in ~/nchc-scaling-demo, reusing the SIF from step 3.

A fresh agent session also avoids carrying earlier answers in its conversation.
The copy does not prevent access to other repositories or remote files.

To use the copy in Docker, exit the agent, then stop and remove its container
as described in [README step 2](../README.md#2-give-the-agent-a-suitable-environment).
In your host terminal, choose the workspace and an optional fresh private home:

```bash
cd ~/nchc-scaling-demo
export OPENCODE_PRIVATE_HOME="$HOME/docker/opencode-scaling"
```

Use step 2's launch block to mount these paths. A fresh private home needs
RAP setup from step 1 and Nano4 login from step 3. Reusing an existing private
home preserves its settings, credentials, and sessions. Stopping the container
closes its SSH connection, so reconnect Nano4 before running the demo.

## Run either sweep manually

Reuse the SIF from step 3. Replace the account and run placeholders below.
Run once with `version=initial`. After collecting the baseline, repeat with
`version=optimized`. Each invocation uses fresh remote directories.

```bash
export PYTORCH_SIF=/work/YOUR_SUPERCOMPUTER_ACCOUNT/YOUR_STEP_3_RUN/container.sif
version=initial  # Change to optimized for the second sweep.
export SCALING_ROOT="/work/YOUR_SUPERCOMPUTER_ACCOUNT/scaling-$version-$(date +%Y%m%d-%H%M%S)"
for spec in 1:1:dev 8:1:8gpus 16:2:16gpus 32:4:32gpus; do
  IFS=: read -r gpus nodes partition <<< "$spec"
  export NCHC_REMOTE_DIR="$SCALING_ROOT/${gpus}gpu"
  bash scripts/nano4/exec.sh mkdir -p "$NCHC_REMOTE_DIR"
  bash scripts/nano4/exec.sh tee "$NCHC_REMOTE_DIR/train.py" \
    < examples/pytorch-scaling/reference/initial/train.py > /dev/null
  bash scripts/nano4/submit.sh --partition="$partition" --nodes="$nodes" \
    --gpus-per-node="$((gpus / nodes))" -- \
    "examples/pytorch-scaling/reference/$version/train.slurm" "$PYTORCH_SIF"
done
```

The jobs are independent and can run in parallel within scheduler limits.
Check current account access and queue conditions when selecting partitions.
The scripts apply the tracked node exclusions automatically. One Slurm task
per node launches one `torchrun` worker per GPU. Static rendezvous uses the
fixed node ranks, master address, and port for this allocation.

For each GPU count, select its directory, check completion, and download:

```bash
export NCHC_REMOTE_DIR="$SCALING_ROOT/1gpu"  # Repeat for 8gpu, 16gpu, and 32gpu.
bash scripts/nano4/status.sh
bash scripts/nano4/download.sh
```

Check `COMPLETED` with exit code `0:0`, finite losses, and
`checkpoint_verified: true` in `outputs/metrics.json`. Each run saves and reloads
a model checkpoint of about 355 MB. `outputs/slurm-job.txt` records
actual allocations, and node logs show the expected one, two, or four hosts.

Plot each sweep locally with Python and Matplotlib, using its four job IDs:

```bash
python3 examples/pytorch-scaling/reference/plot.py \
  results/JOB_1/outputs/metrics.json results/JOB_8/outputs/metrics.json \
  results/JOB_16/outputs/metrics.json results/JOB_32/outputs/metrics.json \
  --output results/scaling-initial --title 'Initial: 1 CPU per GPU'
```

For the second sweep, use its job IDs, `--output results/scaling-optimized`,
and `--title 'Optimized: 12 CPUs per GPU'`. The plotter writes PNG, SVG, and CSV.
Weak scaling efficiency is the one-GPU time divided by the larger-GPU time.
Aggregate throughput scaling is GPU count times that efficiency. The figures
show training time and efficiency. Compare absolute times between sweeps to
measure the CPU allocation improvement.

## Reference measurements

The README figures show a measured pair with the settings above. The reference
launchers differ only in CPU allocation. Different node placements and cluster
load can affect timing, so the figures are examples rather than guaranteed results.

| GPUs | Initial seconds | Optimized seconds | Throughput gain |
|---:|---:|---:|---:|
| 1 | 12.28 | 14.28 | 0.86× |
| 8 | 12.96 | 14.27 | 0.91× |
| 16 | 15.49 | 14.50 | 1.07× |
| 32 | 15.91 | 14.28 | 1.11× |

Times cover 30 measured steps after 2 warmup steps. All eight jobs completed
and verified their model checkpoints. More CPUs helped the multi-node cases
in this run. One and eight GPUs did not improve. Compare losses between CPU
settings at the same GPU count. Global batch changes across GPU counts, so
losses across those counts need not match.

Each curve uses its own one-GPU baseline. A slower baseline can raise
normalized efficiency, so use absolute times to judge the CPU change.

After cluster actions, report the queue and unresolved suspected nodes:

```bash
bash scripts/nano4/exec.sh squeue --me
```

[Return to README: run multi-node workloads on Nano4](../README.md#4-run-multi-node-workloads-on-nano4).
