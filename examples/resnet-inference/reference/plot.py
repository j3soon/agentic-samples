"""Render recorded benchmark and trace events on a CPU."""

import csv
import json
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Patch


reference = Path(__file__).resolve().parent
destination = reference.parents[2] / "docs" / "assets"
destination.mkdir(parents=True, exist_ok=True)
results = json.loads((reference / "results.json").read_text())
variants = results["variants"]
colors = ["#69747f", "#2877b5", "#426694", "#76b900"]

fig, ax = plt.subplots(figsize=(8, 4.5))
fig.subplots_adjust(left=0.13, right=0.97, bottom=0.24, top=0.84)
values = [v["median_images_per_second"] for v in variants]
bars = ax.bar(range(len(variants)), values, color=colors, width=0.6, zorder=3)
ax.errorbar(range(len(variants)), values,
            yerr=[[v - min(row["images_per_second"]) for v, row in zip(values, variants)],
                  [max(row["images_per_second"]) - v for v, row in zip(values, variants)]],
            fmt="none", color="#25313c", capsize=5, zorder=4)
for bar, value in zip(bars, values):
    ax.annotate(f"{value:,.0f}", (bar.get_x() + bar.get_width() / 2, bar.get_height()),
                xytext=(0, 10), textcoords="offset points", ha="center", fontsize=12)
ax.set_ylim(0, max(max(row["images_per_second"]) for row in variants) * 1.2)
ax.set_xticks(range(len(variants)), [v["plot_label"] for v in variants], fontsize=11)
ax.set_ylabel("Images per second", fontsize=12)
ax.set_title("Inference throughput", fontsize=16, pad=12)
ax.grid(axis="y", alpha=0.2, zorder=0)
for side in ["top", "right"]:
    ax.spines[side].set_visible(False)
fig.text(0.5, 0.07, "10,000 images, one H200, 12 CPUs. Median and range of three unprofiled runs.",
         ha="center", fontsize=10, color="#48515b")
fig.text(0.5, 0.025, "Baseline and final measured together. Intermediate stages used other allocations.",
         ha="center", fontsize=9, color="#48515b")
fig.savefig(destination / "resnet-inference-throughput.png", dpi=100, facecolor="white")
plt.close(fig)

timeline = json.loads((reference / "timeline.json").read_text())
windows = timeline["windows"]
with (reference / "timeline.csv").open() as source:
    events = list(csv.DictReader(source))
for event in events:
    for column in ["start_ns", "end_ns", "stream_id"]:
        event[column] = int(event[column]) if event[column] else None
phase_colors = {"input": "#b5bdc5", "preprocess": "#dc8f2f",
                "h2d_transfer": "#8f69a8", "forward_pass": "#2877b5", "accuracy": "#76b900"}
reader_color = "#48a6a6"


def intervals(ax, events, row, color, origin, scale):
    """Draw recorded intervals, allowing the axes to clip window boundaries."""
    ax.broken_barh([((start - origin) / scale, (end - start) / scale)
                    for start, end in events],
                   (row - 0.28, 0.56), facecolors=color, linewidth=0)


def timeline_axes(ax, labels, duration, ticks, xlabel):
    ax.set_yticks(range(len(labels)), labels, fontsize=9)
    ax.set_ylim(-0.6, len(labels) - 0.4)
    ax.set_xlim(0, duration)
    ax.set_xticks(ticks)
    ax.set_xlabel(xlabel, fontsize=10)
    ax.tick_params(axis="x", bottom=True, labelbottom=True, labelsize=9)
    ax.grid(axis="x", alpha=0.2, zorder=0)
    for side in ["top", "right"]:
        ax.spines[side].set_visible(False)


fig, axes = plt.subplots(2, 1, figsize=(8, 6.8),
                         gridspec_kw={"height_ratios": [3, 5]})
fig.subplots_adjust(left=0.25, right=0.97, bottom=0.24, top=0.87, hspace=0.9)
detail = timeline["parallelism_detail"]
for ax, window in zip(axes, windows):
    rows = [event for event in events if event["capture"] == window["name"]]
    optimized = window["name"] == "optimized"
    origin = window["window_start_ns"]
    host_row = 4 if optimized else 2
    copy_row = 2 if optimized else 1
    # Group host NVTX lanes above CUDA execution lanes, as in a trace viewer.
    ax.axhspan(copy_row + 0.5, host_row + 0.6, color="#eef1f4", zorder=-1)
    ax.axhline(copy_row + 0.5, color="#adb5bd", linewidth=0.7, zorder=0)
    for row in range(copy_row + 1):
        if row % 2 == 0:
            ax.axhspan(row - 0.5, row + 0.5, color="#f7f9fb", zorder=-1)
    for name, color in phase_colors.items():
        intervals(ax, [(event["start_ns"], event["end_ns"])
                       for event in rows if event["kind"] == "host" and event["name"] == name],
                  host_row, color, origin, 1e6)
    intervals(ax, [(event["start_ns"], event["end_ns"]) for event in rows if event["kind"] == "copy"],
              copy_row, phase_colors["h2d_transfer"], origin, 1e6)
    intervals(ax, [(event["start_ns"], event["end_ns"]) for event in rows
                   if event["kind"] == "kernel" and event["stream_id"] == window["main_gpu_stream"]],
              0, phase_colors["forward_pass"], origin, 1e6)
    labels = [f'Main GPU stream {window["main_gpu_stream"]}',
              "GPU copies", "Host: main NVTX"]
    if optimized:
        intervals(ax, [(event["start_ns"], event["end_ns"]) for event in rows if event["kind"] == "reader"],
                  3, reader_color, origin, 1e6)
        intervals(ax, [(event["start_ns"], event["end_ns"]) for event in rows
                       if event["kind"] == "kernel" and event["stream_id"] != window["main_gpu_stream"]],
                  1, phase_colors["preprocess"], origin, 1e6)
        labels = [labels[0], "Preprocess GPU streams", "GPU copies (all streams)",
                  "Host: DALI reader NVTX", "Host: main NVTX"]
        middle = ((detail["start_ns"] + detail["end_ns"]) / 2 - origin) / 1e6
        ax.axvspan((detail["start_ns"] - origin) / 1e6,
                   (detail["end_ns"] - origin) / 1e6, color="#17212b", alpha=0.2)
        ax.annotate("Close-up below", xy=(middle, copy_row), xytext=(10, 2.75), fontsize=9,
                    arrowprops={"arrowstyle": "->", "color": "#384754"})
        for name, label, size, color in [("preprocess", "Preprocess", 9, "#34240c"),
                                         ("forward_pass", "Forward", 7, "white")]:
            event = next(event for event in rows if event["kind"] == "host" and event["name"] == name)
            middle = (max(origin, event["start_ns"]) + event["end_ns"]) / 2
            ax.text((middle - origin) / 1e6, host_row, label,
                    ha="center", va="center", fontsize=size, color=color)
    offset = (origin - window["benchmark_start_ns"]) / 1e6
    ax.set_title(f'{window["name"].title()} (batch {window["batch_size"]}), '
                 f'window starts at {offset:,.2f} ms', fontsize=12, pad=10)
    timeline_axes(ax, labels, 31, range(0, 31, 5), "Time within selected window (ms)")
fig.suptitle("Nsight Systems: two 31 ms windows", fontsize=16, y=0.97)
fig.legend(handles=[Patch(color=phase_colors[name], label=label) for name, label in
                    [("preprocess", "Preprocess"), ("forward_pass", "Forward / main GPU"),
                     ("accuracy", "Accuracy"), ("h2d_transfer", "GPU copies")]]
           + [Patch(color=reader_color, label="Reader ranges")],
           loc="lower center", bbox_to_anchor=(0.5, 0.105), ncol=3, frameon=False, fontsize=9)
kernels = [window["total_kernels"] for window in windows]
readbacks = [window["device_to_host_copies"] for window in windows]
fig.text(0.5, 0.075, f"Full 256-image captures: {kernels[0]:,} → {kernels[1]:,} GPU kernels, "
         f"{readbacks[0]:,} → {readbacks[1]:,} GPU-to-CPU copies.",
         ha="center", fontsize=9, color="#48515b")
fig.text(0.5, 0.04, "Host annotations include waiting. Equal windows show different amounts of work.",
         ha="center", fontsize=9, color="#48515b")
fig.savefig(destination / "resnet-inference-timeline.png", dpi=100, facecolor="white")
plt.close(fig)

fig, ax = plt.subplots(figsize=(8, 3.8))
fig.subplots_adjust(left=0.22, right=0.97, bottom=0.30, top=0.79)
origin = detail["start_ns"]
rows = [event for event in events if event["capture"] == "optimized"
        and event["start_ns"] < detail["end_ns"] and event["end_ns"] > origin]
kernel_colors = {"dctQuantInvJpegKernelMultiChannel": phase_colors["preprocess"],
                 "ycbcr_to_format_kernel_roi": phase_colors["accuracy"]}
for row, stream in enumerate(reversed(detail["streams"])):
    if row % 2 == 0:
        ax.axhspan(row - 0.5, row + 0.5, color="#f7f9fb", zorder=-1)
    intervals(ax, [(event["start_ns"], event["end_ns"]) for event in rows
                   if event["kind"] == "copy" and event["stream_id"] == stream],
              row, phase_colors["h2d_transfer"], origin, 1000)
    for event in rows:
        if event["kind"] == "kernel" and event["stream_id"] == stream:
            color = kernel_colors[event["name"]]
            intervals(ax, [(event["start_ns"], event["end_ns"])], row, color, origin, 1000)
offset = (origin - windows[1]["benchmark_start_ns"]) / 1e6
timeline_axes(ax, [f"CUDA stream {stream}" for stream in reversed(detail["streams"])],
              140, range(0, 141, 20), f"Time from {offset:.3f} ms after first fetch (microseconds)")
ax.axvspan(68.701, 71.197, color="#17212b", alpha=0.12)
ax.annotate("Two JPEG kernels\nrun concurrently", xy=(70, 1.5), xytext=(86, 2.7), fontsize=9,
            arrowprops={"arrowstyle": "->", "color": "#384754"})
fig.suptitle("GPU preprocessing: overlapping JPEG work", fontsize=16, y=0.97)
fig.legend(handles=[Patch(color=phase_colors[name], label=label) for name, label in
                    [("h2d_transfer", "Host-to-device copy"), ("preprocess", "JPEG IDCT kernel"),
                     ("accuracy", "Color conversion kernel")]],
           loc="lower center", bbox_to_anchor=(0.5, 0.07), ncol=3, frameon=False, fontsize=9)
fig.text(0.5, 0.025, "Four selected streams from the optimized second batch. Bars show GPU execution intervals.",
         ha="center", fontsize=9, color="#48515b")
fig.savefig(destination / "resnet-inference-overlap.png", dpi=100, facecolor="white")
plt.close(fig)
