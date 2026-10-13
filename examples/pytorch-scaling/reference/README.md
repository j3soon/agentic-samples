# CPU allocation scaling example

These two launchers run the [same trainer](initial/train.py) with different
CPU allocations. The optimized trainer path links to this shared source.
Both use weak scaling with fixed work per GPU and one short measured interval.

- [Initial launcher](initial/train.slurm): 1 CPU per GPU, or 8 cores on an
  eight-GPU node.
- [Optimized launcher](optimized/train.slurm): 12 CPUs per GPU, or 96 cores on
  an eight-GPU node. This is Nano4's published H200 maximum.
- [Plotter](plot.py): checks matching workloads and verified checkpoints,
  then writes PNG, SVG, and CSV.

This models an actual earlier issue where eight GPU workers shared eight
CPU cores. The workload stays identical in both sweeps.

See the [reference guide](../../../docs/pytorch-scaling.md) for manual commands
and measurements.

[Return to README: run multi-node workloads on Nano4](../../../README.md#4-run-multi-node-workloads-on-nano4).
