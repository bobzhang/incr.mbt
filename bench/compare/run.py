#!/usr/bin/env python3
"""Build, validate, and compare native MoonBit and pinned Rust Adapton workloads."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import statistics
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
REFERENCE = "ea903dd961bee3568c483a18a72983d9f4ef5ed2"
MODES = ("sum", "sort_full", "sort_prefix", "map_full", "map_prefix", "filter_full", "sequence")
BINS = {
    "moonbit": ROOT / "_build/native/release/build/bench/collections/collections.exe",
    "rust": ROOT / "bench/compare/rust/target/release/adapton-collections-bench",
}


def command(*args):
    return subprocess.check_output(args, cwd=ROOT, text=True).strip()


def initial(i):
    return (i * 37 + 11) % 10007


def index(step, n):
    return (step * 97 + 13) % n


def value(step):
    return (step * 53 + 7) % 10007


def expected(mode, n, edits):
    values = [initial(i) for i in range(n)]
    if mode == "lifecycle":
        for _ in range(edits):
            yield [sum(values)]
        return
    base_sum = sum(values)
    inserted = 0
    for step in range(-1, edits):
        if step >= 0:
            if mode == "sequence":
                inserted = value(step) if step % 2 == 0 else 0
            else:
                at = index(step, n)
                base_sum += value(step) - values[at]
                values[at] = value(step)
        if mode in ("sum", "sequence"):
            out = [base_sum + inserted]
        elif mode.startswith("sort_"):
            out = sorted(values)
        elif mode.startswith("map_"):
            out = [x * 3 + 1 for x in (values[:32] if mode.endswith("_prefix") else values)]
        elif mode == "filter_full":
            out = [x for x in values if x % 3 == 0]
        else:
            raise ValueError(mode)
        yield out[:32] if mode.endswith("_prefix") else out


def digest(outputs):
    return sum(len(xs) * 1_000_000_000 + sum((i + 1) * x for i, x in enumerate(xs)) for xs in outputs)


def run_child(language, mode, n, edits, verify=False):
    """wait4 reports this child's peak RSS, never the parent's or prior children'."""
    args = [str(BINS[language]), mode, str(n), str(edits)]
    if verify:
        args.append("verify")
    env = {k: v for k, v in os.environ.items() if not k.startswith("ADAPTON")}
    with tempfile.TemporaryFile() as stdout, tempfile.TemporaryFile() as stderr:
        start = time.perf_counter()
        child = subprocess.Popen(args, stdout=stdout, stderr=stderr, env=env)
        _, status, usage = os.wait4(child.pid, 0)
        elapsed = time.perf_counter() - start
        child.returncode = os.waitstatus_to_exitcode(status)
        stdout.seek(0)
        output = stdout.read().decode()
        stderr.seek(0)
        errors = stderr.read().decode()
        if child.returncode:
            raise RuntimeError(f"{args} exited {child.returncode}:\n{errors}")
    # macOS reports bytes; Linux reports KiB. Supported platforms are explicit.
    peak_bytes = usage.ru_maxrss * (1 if sys.platform == "darwin" else 1024)
    return {"wall_seconds": elapsed, "user_seconds": usage.ru_utime,
            "system_seconds": usage.ru_stime, "peak_rss_bytes": peak_bytes}, output


def validate(language, mode, n, edits, verify=False, expected_checksum=None):
    metrics, output = run_child(language, mode, n, edits, verify)
    if expected_checksum is None:
        expected_checksum = digest(expected(mode, n, edits))
    lines = output.splitlines()
    assert lines[-1] == f"checksum={expected_checksum}", (language, mode, n, edits, output[-200:])
    if verify:
        exact = [",".join(map(str, xs)) for xs in expected(mode, n, edits)]
        assert lines[:-1] == exact, (language, mode, "exact output mismatch")
    return metrics


def source_hashes():
    paths = list((ROOT / "bench/collections").glob("*.mbt"))
    paths += list((ROOT / "bench/compare/rust/src").glob("*.rs"))
    paths += [Path(__file__), ROOT / "bench/collections/moon.pkg", ROOT / "bench/compare/rust/Cargo.toml"]
    paths += list(ROOT.glob("*.mbt")) + list((ROOT / "catalog").glob("*.mbt"))
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(paths)}


def cases(quick):
    if quick:
        return [(mode, 64, 8) for mode in MODES] + [("lifecycle", 64, 3)]
    counts = {"sum": 10000, "sort_full": 1000, "sort_prefix": 5000,
              "map_full": 5000, "map_prefix": 50000, "filter_full": 5000, "sequence": 5000}
    result = [(mode, n, counts[mode]) for n in (1024, 4096) for mode in MODES]
    # Initial graph footprint, retention as edit count grows, and full teardown.
    result += [(mode, n, 0) for n in (256, 1024, 4096) for mode in ("sum", "sort_full", "map_full")]
    result += [("sort_full", 1024, edits) for edits in (100, 10000)]
    result += [("lifecycle", 1024, rounds) for rounds in (1, 100, 1000)]
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--quick", action="store_true", help="small correctness/measurement smoke run")
    parser.add_argument("--skip-build", action="store_true")
    parser.add_argument("--repeats", type=int, default=5)
    parser.add_argument("--warmups", type=int, default=1)
    parser.add_argument("--output", type=Path, default=ROOT / "_build/collection-benchmark.json")
    parser.add_argument("--mode", choices=MODES + ("lifecycle",), help="run only one workload")
    args = parser.parse_args()
    if sys.platform not in ("darwin", "linux"):
        parser.error("wait4/RSS units are supported only on macOS and Linux")
    if args.repeats < 1 or args.warmups < 0:
        parser.error("repeats must be positive and warmups nonnegative")
    reference = ROOT / ".repos/adapton"
    if command("git", "-C", str(reference), "rev-parse", "HEAD") != REFERENCE:
        parser.error(f"Rust reference must be checked out at {REFERENCE}")
    if command("git", "-C", str(reference), "status", "--porcelain", "--untracked-files=no"):
        parser.error("Rust reference has tracked modifications")
    if not args.skip_build:
        subprocess.run(["moon", "build", "--release", "--target", "native", "bench/collections"], cwd=ROOT, check=True)
        subprocess.run(["cargo", "build", "--release", "--offline", "--locked", "--manifest-path", "bench/compare/rust/Cargo.toml"], cwd=ROOT, check=True)
    for mode in MODES + ("lifecycle",):
        for language in BINS:
            validate(language, mode, 64, 20 if mode != "lifecycle" else 3, verify=True)
    print("Exact small-workload outputs match the independent array oracle.", flush=True)
    report = {
        "schema": 1, "timestamp_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "platform": platform.platform(), "machine": platform.machine(),
        "moonbit": command("moon", "version", "--all"), "rustc": command("rustc", "--version"),
        "source_commit": command("git", "rev-parse", "HEAD"), "source_dirty": bool(command("git", "status", "--porcelain")),
        "source_sha256": source_hashes(), "reference_commit": REFERENCE,
        "repeats": args.repeats, "warmups": args.warmups,
        "method": "Release native; separate serial processes; alternating language order; wall includes setup, initial demand, edits, checksum, teardown; wait4 process peak RSS; compile excluded; ADAPTON* environment unset",
        "correctness": "Exact outputs on size 64, 20 edits (3 lifecycle rounds); every measured process checksum checked against independent Python array oracle",
        "cases": [],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    for mode, n, edits in cases(args.quick):
        if args.mode and mode != args.mode:
            continue
        expected_checksum = digest(expected(mode, n, edits))
        samples = {lang: [] for lang in BINS}
        for rep in range(args.warmups + args.repeats):
            languages = list(BINS) if rep % 2 == 0 else list(reversed(BINS))
            for lang in languages:
                sample = validate(lang, mode, n, edits, expected_checksum=expected_checksum)
                if rep >= args.warmups:
                    samples[lang].append(sample)
        entry = {"workload": mode, "size": n, "edits_or_rounds": edits, "checksum": expected_checksum, "languages": {}}
        for lang, runs in samples.items():
            entry["languages"][lang] = {"median_wall_seconds": statistics.median(x["wall_seconds"] for x in runs),
                "median_peak_rss_bytes": statistics.median(x["peak_rss_bytes"] for x in runs), "samples": runs}
        report["cases"].append(entry)
        args.output.write_text(json.dumps(report, indent=2) + "\n")
        m, r = (entry["languages"][lang] for lang in BINS)
        print(f"{mode:12} n={n:5} edits/rounds={edits:4} | MoonBit {m['median_wall_seconds']:.4f}s {m['median_peak_rss_bytes']/1048576:.2f}MiB | Rust {r['median_wall_seconds']:.4f}s {r['median_peak_rss_bytes']/1048576:.2f}MiB", flush=True)
    print(f"Saved {args.output}")


if __name__ == "__main__":
    main()
