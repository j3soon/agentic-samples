# PyTorch scaling demo

Run the provided Transformer training on 1, 8, 16, and 32 Nano4 H200 GPUs,
using 1, 1, 2, and 4 nodes. Submit the four jobs independently so Slurm can run
them in parallel within account limits. Use fresh directories for each job.

In this repository, use `reference/initial/train.py`,
`reference/initial/train.slurm`, and `reference/plot.py`, relative to this brief.
Prepared demo copies put these files alongside this brief instead.

For the first sweep, keep the provided trainer and resource defaults unchanged.
Use weak scaling with the model and timing defaults: 128 sequences per GPU,
microbatch 4, and one interval of 30 optimizer steps after 2 warmup steps.
Keep work per GPU fixed as GPU count grows. Target 10 to 30 measured seconds
and under one minute for warmup plus training. Retain the two-minute allocation
limit for startup and cleanup. Timing excludes startup, warmup,
and checkpoints and uses the slowest worker. Download logs, metrics, and model
checkpoints. Check finite losses and verified reloads, then plot training time
and weak scaling efficiency.
Preserve this baseline, report it, and end the turn. Wait for the user's
optimization request before changing allocations or running another sweep.

When asked why scaling is poor, inspect the allocation records and logs.
Fix the resource bottleneck and rerun all four configurations, keeping the
trainer and workload identical. Compare timings and losses with
the baseline and produce a second scaling plot. Run one optimized sweep,
then report the results. Further tuning requires a follow-up request.

Use the Nano4 skill and scripts, reuse the SIF from step 3, and report remaining
jobs and suspected nodes at each handoff. Keep passwords in the user's terminal.
Work from this workspace. Do not read or retrieve the optimized reference or
previous experiment results, including from other directories or the repository
website.
