"""Plot weak scaling from downloaded training metrics."""

import argparse
import csv
import json
import math
from pathlib import Path
import statistics

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt


def summarize(paths):
    runs = [json.loads(path.read_text()) for path in paths]
    runs.sort(key=lambda run: run['world_size'])
    if not runs or runs[0]['world_size'] != 1:
        raise ValueError('include a single-GPU baseline')
    counts = [run['world_size'] for run in runs]
    if len(set(counts)) != len(counts):
        raise ValueError('provide one metrics file per GPU count')
    reference = runs[0]['config'].copy()
    reference.pop('output', None)
    if 'batch_per_gpu' not in reference:
        raise ValueError('use weak-scaling runs with a fixed batch per GPU')
    for run in runs:
        config = run['config'].copy()
        config.pop('output', None)
        if config != reference or run['gpu'] != runs[0]['gpu']:
            raise ValueError('runs must use identical workloads and GPU models')
        if run.get('global_batch') != reference['batch_per_gpu'] * run['world_size']:
            raise ValueError('global batch must grow with GPU count')
        if not run.get('checkpoint_verified'):
            raise ValueError('run has no verified checkpoint')
        times = [trial['seconds'] for trial in run['trials']]
        if not times or any(not math.isfinite(value) or value <= 0 for value in times):
            raise ValueError('measurement times must be finite and positive')
    baseline = statistics.median(trial['seconds'] for trial in runs[0]['trials'])
    rows = []
    for run in runs:
        times = [trial['seconds'] for trial in run['trials']]
        seconds = statistics.median(times)
        tokens = run['global_batch'] * reference['sequence'] * reference['steps']
        efficiency = baseline / seconds
        rows.append(dict(gpus=run['world_size'], median_seconds=seconds,
                         min_seconds=min(times), max_seconds=max(times),
                         tokens_per_second=tokens / seconds,
                         throughput_scaling=run['world_size'] * efficiency,
                         efficiency=efficiency))
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('metrics', type=Path, nargs='+')
    parser.add_argument('--output', type=Path, default=Path('results/scaling'))
    parser.add_argument('--title', default='PyTorch weak scaling')
    args = parser.parse_args()
    rows = summarize(args.metrics)
    args.output.mkdir(parents=True, exist_ok=True)
    with (args.output / 'scaling.csv').open('w', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)

    gpus = [row['gpus'] for row in rows]
    seconds = [row['median_seconds'] for row in rows]
    baseline = rows[0]['median_seconds']
    error = [[row['median_seconds'] - row['min_seconds'] for row in rows],
             [row['max_seconds'] - row['median_seconds'] for row in rows]]
    fig, axes = plt.subplots(1, 2, figsize=(10, 4), layout='constrained')
    axes[0].axhline(baseline, linestyle='--', color='gray', label='Ideal')
    axes[0].errorbar(gpus, seconds, yerr=error, fmt='o-', capsize=4, label='Measured')
    axes[0].set_ylabel('Measured training time (s)')
    axes[0].set_ylim(0, max(20, max(row['max_seconds'] for row in rows) * 1.05))
    axes[0].legend()
    axes[1].plot(gpus, [100 * row['efficiency'] for row in rows], 'o-')
    axes[1].set_ylabel('Weak scaling efficiency (%)')
    axes[1].set_ylim(0, max(110, max(100 * row['efficiency'] for row in rows) * 1.05))
    for axis in axes:
        axis.set_xlabel('GPUs')
        axis.set_xticks(gpus)
        axis.grid(alpha=0.25)
    config = json.loads(args.metrics[0].read_text())['config']
    fig.suptitle(f"{args.title}, batch {config['batch_per_gpu']}/GPU, "
                 f"sequence {config['sequence']}\n"
                 f"Weak scaling, {config['steps']} measured steps, warmup excluded")
    fig.savefig(args.output / 'scaling.png', dpi=180)
    fig.savefig(args.output / 'scaling.svg')
    plt.close(fig)
    for row in rows:
        print(f"{row['gpus']:2d} GPUs: {row['median_seconds']:.2f}s, "
              f"{100 * row['efficiency']:.1f}% efficiency, "
              f"{row['tokens_per_second']:,.0f} tokens/s")


if __name__ == '__main__':
    main()
