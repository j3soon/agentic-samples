"""Train a small decoder on synthetic tokens and measure weak scaling."""

import argparse
from contextlib import nullcontext
from datetime import timedelta
import json
import math
import os
from pathlib import Path
import socket
import statistics
import time

import torch
from torch import nn
import torch.distributed as dist
import torch.nn.functional as F
from torch.nn.parallel import DistributedDataParallel as DDP


class Block(nn.Module):
    def __init__(self, width, heads):
        super().__init__()
        self.heads = heads
        self.norm1 = nn.LayerNorm(width)
        self.qkv = nn.Linear(width, 3 * width)
        self.projection = nn.Linear(width, width)
        self.norm2 = nn.LayerNorm(width)
        self.mlp = nn.Sequential(nn.Linear(width, 4 * width), nn.GELU(), nn.Linear(4 * width, width))

    def forward(self, x):
        batch, length, width = x.shape
        qkv = self.qkv(self.norm1(x)).reshape(batch, length, 3, self.heads, width // self.heads)
        q, k, v = qkv.permute(2, 0, 3, 1, 4).unbind(0)
        attention = F.scaled_dot_product_attention(q, k, v, is_causal=True)
        x = x + self.projection(attention.transpose(1, 2).reshape(batch, length, width))
        return x + self.mlp(self.norm2(x))


class Decoder(nn.Module):
    def __init__(self, vocab, sequence, width, layers, heads):
        super().__init__()
        self.token = nn.Embedding(vocab, width)
        self.position = nn.Embedding(sequence, width)
        self.blocks = nn.Sequential(*(Block(width, heads) for _ in range(layers)))
        self.norm = nn.LayerNorm(width)
        self.apply(self.initialize)

    @staticmethod
    def initialize(module):
        if isinstance(module, (nn.Linear, nn.Embedding)):
            nn.init.normal_(module.weight, std=0.02)
            if isinstance(module, nn.Linear):
                nn.init.zeros_(module.bias)

    def forward(self, tokens):
        x = self.token(tokens) + self.position(torch.arange(tokens.shape[1], device=tokens.device))
        return F.linear(self.norm(self.blocks(x)), self.token.weight)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=Path('outputs'))
    parser.add_argument('--batch-per-gpu', type=int, default=128)
    parser.add_argument('--microbatch', type=int, default=4)
    parser.add_argument('--sequence', type=int, default=512)
    parser.add_argument('--vocab', type=int, default=4096)
    parser.add_argument('--width', type=int, default=768)
    parser.add_argument('--layers', type=int, default=12)
    parser.add_argument('--heads', type=int, default=12)
    parser.add_argument('--warmup', type=int, default=2)
    parser.add_argument('--steps', type=int, default=30)
    parser.add_argument('--repeats', type=int, default=1)
    parser.add_argument('--seed', type=int, default=42)
    args = parser.parse_args()
    world = int(os.environ.get('WORLD_SIZE', '1'))
    rank = int(os.environ.get('RANK', '0'))
    local_rank = int(os.environ.get('LOCAL_RANK', '0'))
    for name in ('batch_per_gpu', 'microbatch', 'sequence', 'vocab', 'width', 'layers', 'heads',
                 'warmup', 'steps', 'repeats'):
        if getattr(args, name) < 1:
            parser.error(f'{name} must be positive')
    if args.batch_per_gpu % args.microbatch:
        parser.error('batch per GPU must be divisible by microbatch')
    if args.width % args.heads:
        parser.error('width must be divisible by heads')
    if not torch.cuda.is_available() or not torch.cuda.is_bf16_supported():
        parser.error('a CUDA GPU with BF16 support is required')

    torch.cuda.set_device(local_rank)
    device = torch.device('cuda', local_rank)
    torch.manual_seed(args.seed)
    torch.set_num_threads(1)
    if world > 1:
        dist.init_process_group('nccl', device_id=device, timeout=timedelta(minutes=3))
    args.output.mkdir(parents=True, exist_ok=True)
    log_dir = Path('logs')
    log_dir.mkdir(exist_ok=True)
    log = (log_dir / f'rank-{rank}.jsonl').open('w')

    def record(event, **values):
        entry = dict(event=event, rank=rank, **values)
        line = json.dumps(entry)
        log.write(line + '\n')
        log.flush()
        print(line, flush=True)

    config = vars(args).copy()
    config['output'] = str(args.output)
    config.update(precision='bf16', optimizer='AdamW', learning_rate=0.0003,
                  weight_decay=0.01, workload='synthetic-next-token-weak-v1')
    model = Decoder(args.vocab, args.sequence, args.width, args.layers, args.heads).to(device)
    raw_model = model
    if world > 1:
        model = DDP(model, device_ids=[local_rank], gradient_as_bucket_view=True)
    optimizer = torch.optim.AdamW(model.parameters(), lr=config['learning_rate'],
                                 weight_decay=config['weight_decay'], fused=True)
    local_batch = args.batch_per_gpu
    global_batch = local_batch * world
    accumulation = local_batch // args.microbatch

    # Keep each GPU's work fixed. Generate its examples once outside timing.
    samples = torch.arange(rank * local_batch, (rank + 1) * local_batch, device=device)
    positions = torch.arange(args.sequence, device=device)
    tokens = (samples[:, None] * 37 + positions[None, :]) % args.vocab
    targets = (tokens + 1) % args.vocab
    record('start', world_size=world, hostname=socket.gethostname(),
           gpu=torch.cuda.get_device_name(device), config=config,
           global_batch=global_batch, accumulation=accumulation)

    def train_step():
        optimizer.zero_grad(set_to_none=True)
        loss_sum = torch.zeros((), device=device)
        for micro in range(accumulation):
            start = micro * args.microbatch
            batch = slice(start, start + args.microbatch)
            # Reduce gradients once per optimizer step, after local accumulation.
            context = model.no_sync() if world > 1 and micro < accumulation - 1 else nullcontext()
            with context, torch.autocast('cuda', dtype=torch.bfloat16):
                logits = model(tokens[batch])
                loss = F.cross_entropy(logits.flatten(0, 1), targets[batch].flatten())
                (loss / accumulation).backward()
            loss_sum += loss.detach() / accumulation
        optimizer.step()
        return loss_sum

    trials = []
    for repeat in range(args.repeats):
        for _ in range(args.warmup):
            train_step()
        torch.cuda.synchronize()
        if world > 1:
            dist.barrier()
        started = time.perf_counter()
        for _ in range(args.steps):
            loss = train_step()
        torch.cuda.synchronize()
        elapsed = torch.tensor(time.perf_counter() - started, device=device, dtype=torch.float64)
        if world > 1:
            dist.all_reduce(elapsed, op=dist.ReduceOp.MAX)
            dist.all_reduce(loss, op=dist.ReduceOp.SUM)
            loss /= world
        seconds = elapsed.item()
        value = loss.item()
        if not math.isfinite(value):
            raise RuntimeError('nonfinite training loss')
        trial = dict(repeat=repeat + 1, seconds=seconds, loss=value,
                     tokens_per_second=global_batch * args.sequence * args.steps / seconds)
        trials.append(trial)
        record('measurement', **trial)

    # Save once on rank zero. Checkpoint I/O is excluded from training measurements.
    if rank == 0:
        metrics = dict(world_size=world, global_batch=global_batch, config=config, trials=trials,
                       parameters=sum(p.numel() for p in raw_model.parameters()),
                       median_seconds=statistics.median(t['seconds'] for t in trials),
                       torch_version=str(torch.__version__), cuda_version=torch.version.cuda,
                       gpu=torch.cuda.get_device_name(device), job_id=os.environ.get('SLURM_JOB_ID'))
        step = args.repeats * (args.warmup + args.steps)
        checkpoint = args.output / 'checkpoint.pt'
        partial = args.output / 'checkpoint.pt.partial'
        torch.save(dict(model=raw_model.state_dict(), config=config, step=step,
                        metrics=metrics), partial)
        partial.replace(checkpoint)
        restored = torch.load(checkpoint, map_location='cpu', weights_only=True)
        assert restored['step'] == step
        assert torch.equal(restored['model']['token.weight'], raw_model.token.weight.detach().cpu())
        metrics['checkpoint_verified'] = True
        (args.output / 'metrics.json').write_text(json.dumps(metrics, indent=2) + '\n')
        (args.output / 'config.json').write_text(json.dumps(config, indent=2) + '\n')
        record('checkpoint', path=str(checkpoint), bytes=checkpoint.stat().st_size, step=step)
    if world > 1:
        dist.barrier()
        dist.destroy_process_group()
    log.close()


if __name__ == '__main__':
    main()
