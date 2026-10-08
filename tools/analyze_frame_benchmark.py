"""Summarise tests/benchmarks/gameplay_frame_benchmark.gd output.

    python tools/analyze_frame_benchmark.py default late

Reads .godot/perf-logs/gameplay_frame_<scenario>.jsonl and the events file,
prints percentiles per cost column, cost by load bins, every frame whose CPU
(process + physics + root render cpu) exceeds 8 ms or whose interval exceeds
16.7 ms with the nodes added in that and the previous frame, a 10 s timeline
and the run events.
"""
import collections
import json
import os
import statistics
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOG_DIR = os.path.join(ROOT, ".godot", "perf-logs")
COLS = [
    "frame", "t", "interval", "proc", "phys", "phys_ticks", "rcpu", "rgpu", "pfcpu", "pfgpu",
    "nodes", "orphans", "objects", "draws", "robjs", "prims", "pairs", "mem_kb", "enemies",
    "ebullets", "orbs", "pbullets", "paused", "token", "stage", "level", "gate", "phase", "added", "removed",
]


def load(name):
    rows = []
    with open(os.path.join(LOG_DIR, f"gameplay_frame_{name}.jsonl"), encoding="utf-8") as handle:
        for line in handle:
            if line.strip():
                rows.append(dict(zip(COLS, json.loads(line))))
    with open(os.path.join(LOG_DIR, f"gameplay_frame_events_{name}.json"), encoding="utf-8") as handle:
        events = json.load(handle)
    return rows, events


def pct(values, fraction):
    values = sorted(values)
    return values[min(len(values) - 1, int(len(values) * fraction))]


def stats(values):
    return f"med={statistics.median(values):5.2f} p95={pct(values, 0.95):5.2f} p99={pct(values, 0.99):5.2f} max={max(values):6.1f}"


def added_summary(added):
    return ",".join(f"{key}x{count}" for key, count in sorted(added.items(), key=lambda item: -item[1])[:5])


def summarize(name):
    rows, events = load(name)
    play = [row for row in rows if row["phase"] == "play"]
    unpaused = [row for row in play if not row["paused"]]
    print(f"\n===== {name}: frames={len(rows)} play={len(play)} unpaused={len(unpaused)}")
    for key in ("interval", "proc", "phys", "rcpu", "rgpu", "pfcpu", "pfgpu"):
        print(f"  {key:9s} {stats([row[key] for row in unpaused])}")
    cpu = [row["proc"] + row["phys"] + row["rcpu"] for row in unpaused]
    print(f"  cpu(proc+phys+rcpu) {stats(cpu)}   frames cpu>8ms={sum(1 for x in cpu if x > 8)} cpu>16.7={sum(1 for x in cpu if x > 16.7)}")
    print(f"  peaks: nodes={max(row['nodes'] for row in play)} ebullets={max(row['ebullets'] for row in play)} pbullets={max(row['pbullets'] for row in play)} enemies={max(row['enemies'] for row in play)} orbs={max(row['orbs'] for row in play)} draws={max(row['draws'] for row in play)} pairs={max(row['pairs'] for row in play)} mem={max(row['mem_kb'] for row in play) // 1024}MB")
    for key, step in (("ebullets", 25), ("enemies", 4), ("pbullets", 10)):
        bins = collections.defaultdict(list)
        for row in unpaused:
            bins[(row[key] // step) * step].append(row)
        print(f"  by {key}: bin -> n / proc med / phys med / playfield gpu med / interval p95")
        for lower in sorted(bins):
            group = bins[lower]
            if len(group) < 30:
                continue
            print(f"    {lower:4d}+ n={len(group):5d} proc={statistics.median([r['proc'] for r in group]):.2f} phys={statistics.median([r['phys'] for r in group]):.2f} pfgpu={statistics.median([r['pfgpu'] for r in group]):.2f} iv95={pct([r['interval'] for r in group], 0.95):.2f}")
    events_by_frame = collections.defaultdict(list)
    for event in events:
        events_by_frame[event["frame"]].append(f'{event["kind"]}:{event["detail"]}')
    print("\n--- frames with cpu(proc+phys+rcpu) > 8 ms or interval > 16.7 ms (all phases)")
    shown = 0
    for index, row in enumerate(rows):
        cost = row["proc"] + row["phys"] + row["rcpu"]
        if cost <= 8.0 and row["interval"] <= 16.7:
            continue
        previous = rows[index - 1]["added"] if index > 0 else {}
        near = []
        for frame in range(row["frame"] - 2, row["frame"] + 1):
            near += events_by_frame.get(frame, [])
        print(f"  f{row['frame']:6d} iv={row['interval']:6.1f} proc={row['proc']:5.1f} phys={row['phys']:4.1f}x{row['phys_ticks']} rcpu={row['rcpu']:4.1f} pfgpu={row['pfgpu']:4.1f} ph={row['phase']:<4} P={row['paused']} tok={row['token']:<2} eb={row['ebullets']:3d} pb={row['pbullets']:3d} en={row['enemies']:2d} nodes={row['nodes']:5d} rm={row['removed']:3d} add=[{added_summary(row['added'])}] prev=[{added_summary(previous)}] ev={near}")
        shown += 1
        if shown >= 80:
            print("  ...")
            break
    print("\n--- timeline (10 s buckets): iv med/p95/max | proc med/p95 | phys med/p95 | playfield gpu med/p95 | peaks")
    origin = play[0]["t"] if play else 0
    buckets = collections.defaultdict(list)
    for row in play:
        buckets[(row["t"] - origin) // 10000].append(row)
    for lower in sorted(buckets):
        group = [row for row in buckets[lower] if not row["paused"]] or buckets[lower]
        intervals = [row["interval"] for row in group]
        proc = [row["proc"] for row in group]
        phys = [row["phys"] for row in group]
        gpu = [row["pfgpu"] for row in group]
        last = buckets[lower][-1]
        print(f"  {lower * 10:4d}s: {statistics.median(intervals):5.2f}/{pct(intervals, 0.95):5.2f}/{max(intervals):5.1f} | {statistics.median(proc):4.2f}/{pct(proc, 0.95):4.2f} | {statistics.median(phys):4.2f}/{pct(phys, 0.95):4.2f} | {statistics.median(gpu):4.2f}/{pct(gpu, 0.95):4.2f} | eb={max(row['ebullets'] for row in buckets[lower]):3d} pb={max(row['pbullets'] for row in buckets[lower]):3d} en={max(row['enemies'] for row in buckets[lower]):2d} nodes={max(row['nodes'] for row in buckets[lower]):5d} draws={max(row['draws'] for row in buckets[lower]):4d} tok={last['token']} st={last['stage']} paused={sum(row['paused'] for row in buckets[lower])}")
    print("\n--- events")
    for event in events:
        print(f"  f{event['frame']:6d} {event['kind']} {event['detail']}")


if __name__ == "__main__":
    for scenario in sys.argv[1:] or ["default"]:
        summarize(scenario)
