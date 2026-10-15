#!/usr/bin/env python3
"""Run replayable differential and lifecycle stress cases in isolated processes."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
BINARY = ROOT / "_build/native/release/build/cmd/stress/stress.exe"
SEEDS = [0, 1, 31, 771, 0xABCDEF, 0xFFFFFFFF, 0x9E3779B9, 0xDEADBEEF,
         12345, 314159, 271828, 104729, 65537, 0x80000000, 42, 20261015]


def command(*args):
    return subprocess.check_output(args, cwd=ROOT, text=True).strip()


def measure(mode, seed, steps, timeout):
    argv = [str(BINARY), mode, str(seed), str(steps)]
    with tempfile.TemporaryFile() as out, tempfile.TemporaryFile() as err:
        start = time.monotonic()
        child = subprocess.Popen(argv, stdout=out, stderr=err, cwd=ROOT)
        timed_out = False
        while True:
            pid, status, usage = os.wait4(child.pid, os.WNOHANG)
            if pid:
                break
            if time.monotonic() - start > timeout:
                timed_out = True
                child.kill()
                _, status, usage = os.wait4(child.pid, 0)
                break
            time.sleep(0.05)
        child.returncode = os.waitstatus_to_exitcode(status)
        elapsed = time.monotonic() - start
        out.seek(0)
        stdout = out.read().decode(errors="replace")
        err.seek(0)
        stderr = err.read().decode(errors="replace")
    prefix = f"mode={mode} seed={seed} steps={steps} checksum="
    valid_output = stdout.strip().startswith(prefix)
    if valid_output:
        try:
            int(stdout.strip()[len(prefix):])
        except ValueError:
            valid_output = False
    return {"mode": mode, "seed": seed, "steps_or_depth_or_rounds": steps,
            "wall_seconds": elapsed, "user_seconds": usage.ru_utime,
            "system_seconds": usage.ru_stime,
            "peak_rss_bytes": usage.ru_maxrss * (1 if sys.platform == "darwin" else 1024),
            "exit_code": child.returncode, "timed_out": timed_out,
            "passed": child.returncode == 0 and valid_output and not timed_out,
            "stdout": stdout[-8192:], "stderr": stderr[-8192:],
            "replay": f"moon run --release --target native cmd/stress -- {mode} {seed} {steps}"}


def cases(profile):
    if profile == "smoke":
        return [(m, s, 100 if m == "collections" else 1000)
                for s in SEEDS[:2] for m in ("engine", "nominal", "collections")] + [
                    ("lifecycle", 771, 30), ("retained", 1, 3), ("depth", 1, 128), ("growing", 1, 1000)]
    return ([("engine", s, 100000) for s in SEEDS]
            + [("nominal", s, 50000) for s in SEEDS]
            + [("collections", s, 10000) for s in SEEDS[:8]]
            + [("lifecycle", 771, n) for n in (100, 1000, 20000)]
            + [("retained", 1, n) for n in (10, 100, 1000)]
            + [("growing", 1, n) for n in (1000, 10000, 100000)]
            + [("depth", 1, n) for n in (512, 2048, 8192)])


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--profile", choices=("smoke", "full"), default="full")
    p.add_argument("--soak-seconds", type=int, default=0, help="minimum run duration; repeat fresh-seeded cases until reached")
    p.add_argument("--timeout", type=int, default=300, help="watchdog seconds per child")
    p.add_argument("--skip-build", action="store_true")
    p.add_argument("--output", type=Path, default=ROOT / "_build/stress-results.json")
    args = p.parse_args()
    if sys.platform not in ("darwin", "linux"):
        p.error("RSS collection supports only macOS/Linux")
    if args.timeout <= 0 or args.soak_seconds < 0:
        p.error("timeout must be positive and soak duration nonnegative")
    if not args.skip_build:
        subprocess.run(["moon", "build", "--release", "--target", "native", "cmd/stress"], cwd=ROOT, check=True)
    sources = sorted(list((ROOT / "internal/stress").glob("*.mbt")) + list(ROOT.glob("*.mbt"))
                     + list((ROOT / "catalog").glob("*.mbt")) + list((ROOT / "cmd/stress").glob("*.mbt")))
    report = {"schema": 1, "timestamp_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
              "platform": platform.platform(), "compiler": command("moon", "version", "--all"),
              "source_commit": command("git", "rev-parse", "HEAD"),
              "source_dirty": bool(command("git", "status", "--porcelain")),
              "source_sha256": {str(f.relative_to(ROOT)): hashlib.sha256(f.read_bytes()).hexdigest() for f in sources},
              "runner_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              "profile": args.profile, "requested_soak_seconds": args.soak_seconds,
              "timeout_seconds": args.timeout, "status": "running", "cases": []}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    def save():
        args.output.write_text(json.dumps(report, indent=2) + "\n")
    work = cases(args.profile)
    started = time.monotonic()
    index = 0
    while index < len(work) or time.monotonic() - started < args.soak_seconds:
        if index < len(work):
            mode, seed, steps = work[index]
        else:
            offset = index - len(work)
            mode = ("engine", "nominal", "collections")[offset % 3]
            seed = (0x9E3779B9 * (offset + 1)) & 0xFFFFFFFF
            steps = {"engine": 100000, "nominal": 50000, "collections": 10000}[mode]
        sample = measure(mode, seed, steps, args.timeout)
        report["cases"].append(sample)
        report["elapsed_seconds"] = time.monotonic() - started
        if not sample["passed"]:
            report["status"] = "failed"
            save()
            print(json.dumps(sample, indent=2), flush=True)
            raise SystemExit(1)
        save()
        print(f"PASS {mode} seed={seed} count={steps} {sample['wall_seconds']:.2f}s RSS={sample['peak_rss_bytes']/1048576:.2f}MiB", flush=True)
        index += 1
    report["status"] = "passed"
    report["elapsed_seconds"] = time.monotonic() - started
    save()
    print(f"PASS {len(report['cases'])} cases in {report['elapsed_seconds']:.1f}s; {args.output}")


if __name__ == "__main__":
    main()
