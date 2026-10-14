# ResNet inference on Nano4

Read before running, optimizing, or profiling this example. Keep the agent local.
Run dependency preparation, inference, engine builds, and profiling on Nano4
compute nodes through Slurm. Reuse the PyTorch SIF from README step 3.
Use the Nano4 skill and scripts, apply node exclusions, and report remaining jobs.
Keep commands, source snapshots, job IDs, node names, and downloaded evidence
under ignored `artifacts/resnet-inference/`.

## Baseline

Run `01_base.py` unchanged with `baseline.slurm` and `run-baseline.sh`.
See `docs/resnet-inference.md` for manual commands. Save the source hash,
throughput, top-1/top-5 accuracy, software versions, resources, and cache paths.
The task uses all 10,000 ImageNetV2 matched-frequency images and ResNet-152
`IMAGENET1K_V1` weights. Preserve labels, architecture, weights, resize to 256,
center crop to 224, and ImageNet normalization.

## Optimize and measure

Choose changes and tools from measurements and official documentation.
Develop candidates in separate files. Use the starting code, and read the
recorded solution only when the user requests it. Profiling is optional here.
Record skills actually read or followed, including their sources and versions.

Before each trial, append the change, expected effect, and planned measurement
to `artifacts/resnet-inference/journal.md`. Afterwards, append commands, results,
correctness checks, errors, and the keep-or-revert decision. Retain failed trials.

Use one H200 and 12 CPUs for comparisons. The original timer skips the first
image. Establish matching timers from the first input fetch through final GPU
synchronization and accuracy accumulation. Include decode, preprocessing,
transfers, and inference. Exclude downloads, loading, builds, and warmup.
Allow a warm filesystem cache, without predecoding the whole dataset.
Measure baseline and best candidate at least three times without profiling or
prediction collection. Report medians, ranges, memory use, and setup costs.

Check all 10,000 predictions by image path against the original baseline.
Permit at most a 0.1 percentage-point drop in each accuracy metric and require
at least 99% top-1 prediction agreement. Measure changed preprocessing numerically.
These tolerances are demo choices for human review.

Continue beyond the 2× milestone while worthwhile gains remain. The demo budget
is one allocated GPU-hour, excluding baseline and final profiling. Two consecutive
measured candidates that fail correctness or improve median throughput by less
than 5% suggest stopping. Continue only with a measured reason or a specific
correctable error, within budget. Preserve setup failures separately and explain
the stopping decision.

## Review with the Nsight Systems skill

Locate the bundled `skills/nsight-systems/SKILL.md` in the workload environment.
Make its complete pack accessible to the agent and follow its bootstrap,
capture guidance, report-health checks, and analysis workflow. Prepare missing
profiler dependencies privately on Nano4 compute nodes.

Capture CUDA and NVTX activity for baseline and best version using matching
inputs and resources. Keep native `.nsys-rep` files and analysis evidence.
Create a visual comparison with time ticks, units, and capture boundaries.
Host annotations can include waiting. Kernel counts do not measure SM utilization.

Write `artifacts/resnet-inference/review.md` with each change's purpose, measured
benefit, correctness, added complexity, failures, remaining bottleneck, and
reproduction commands. Cite trace intervals and analysis facts. Distinguish
observations from hypotheses and earlier motivations from later explanations.
Keep profiled timings separate from unprofiled speedups.
