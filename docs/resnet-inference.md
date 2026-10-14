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

[Return to README example 5](../README.md#5-use-nvidia-skills-for-optimization).
