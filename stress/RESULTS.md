# Randomized and sustained stress results

Run date: 2026-10-15. Local host: Apple M2 Ultra, 192 GiB RAM, macOS ARM64.
Source: `e9a048f70e0f2c9fbdef6415a17d16b5c9e94a91`. Compiler: MoonBit `0.10.15+943464bfa`.

The final local run passed **370 isolated cases in 300.7 seconds**,
including **19,440,000 randomized differential rounds**. Expected values come
from independent arrays and arithmetic, not the engine's naive mode.
[Raw seeds, assertions' exit status, checksums, source hashes and replay commands](results/2026-10-15-native-soak.json)
are retained. All recorded source hashes were checked against the recorded Git
revision. These runs measure correctness and process memory, not comparative speed.

## Coverage and process memory

| Mode | Cases | Total rounds / entries / chain nodes | Highest process peak RSS (MiB) |
| --- | ---: | ---: | ---: |
| engine | 122 | 12,200,000 | 2.38 |
| nominal | 122 | 6,100,000 | 2.36 |
| collections | 114 | 1,140,000 | 7.75 |
| lifecycle | 3 | 21,100 | 2.38 |
| retained | 3 | 1,110 | 9.28 |
| growing | 3 | 111,000 | 51.22 |
| depth | 3 | 10,752 | 12.25 |

Each lifecycle round additionally runs 16 DAG edits and 16 nominal edits before
disposing both engines. Each retained-handle round fills four 2,048-entry tables
and a 2,048-observer fanout, disposes the engine, and retains the empty handles.
Each depth case invalidates and demands its chain 128 times.

| Probe | Size / rounds | Process peak RSS (MiB) |
| --- | ---: | ---: |
| lifecycle | 100 | 2.38 |
| lifecycle | 1,000 | 2.38 |
| lifecycle | 20,000 | 2.38 |
| retained | 10 | 7.52 |
| retained | 100 | 8.27 |
| retained | 1,000 | 9.28 |
| growing | 1,000 | 2.91 |
| growing | 10,000 | 7.23 |
| growing | 100,000 | 51.22 |
| depth | 512 | 2.92 |
| depth | 2,048 | 4.73 |
| depth | 8,192 | 12.25 |

RSS is each child process's `wait4` high-water mark, including the runtime and
allocator. It is not live heap size or proof of no leaks. Unique keys retain
entries until disposal; this library has no cache eviction. Empty retained
handles also occupy memory. Native depth 8,192 passed here; ordinary tests cover
depth 128 across backends. Neither is a safe bound for arbitrary computation bodies.

## Issues found and addressed

**Identity rollover (`9bb8684`).** The initial five-minute soak passed, but a
targeted boundary reproduction found stale results after signed 32-bit edge IDs
wrapped and overwrote a live reverse dependency. Creating edge 0, seeding the
old counter at -1, allocating two more observations, and changing an input from
1 to 2 left the first observer incorrectly returning 1. This is a synthetic
boundary test, not a claim of executing 2^32 observations.

Engine and edge identities now use checked, nonnegative `Int64` and fail before
reuse. Diagnostic event counters saturate at the `Int64` maximum. The four public
`Stats` event fields changed from `Int` to `Int64`; explicit type annotations may
need adjustment. `Stats.allocated` remains the current `Int` node count. Regression
tests cover 32-bit rollover, the JavaScript 2^53 boundary, near-64-bit limits,
exhaustion, and saturation.

**Disposed handles retaining map buffers (`b25c3c9`).** The fresh xhigh reviewer
reproduced large backing buffers surviving `dispose()` because `Map::clear()`
removed entries without releasing capacity. Disposal now replaces the four
memo/cell maps and observer maps with empty maps. A white-box test verifies all
five capacities return to their initial size, including idempotent disposal.

| Retained disposal rounds | Before fix peak RSS (MiB) | After fix peak RSS (MiB) |
| --- | ---: | ---: |
| 10 | 9.38 | 7.69 |
| 100 | 27.66 | 8.25 |
| 1,000 | 210.62 | 9.27 |

[Raw before/after memory measurements](results/2026-10-15-retained-memory.json)
use the same retained-handle kernel against `9bb8684` and `b25c3c9`. The old
snapshot overlays only the new kernel and CLI dispatch. The final soak above
independently repeats the retained-handle probes on the final library revision.
To reproduce the comparison, archive each revision into a separate directory,
copy `internal/stress/lifecycle.mbt` and `cmd/stress/main.mbt` from `b25c3c9` into
the old snapshot, build release native `cmd/stress`, and measure
`stress.exe retained 1 10`, `100`, and `1000` in fresh processes with `wait4`.

**Merge-sort name domains (`e9a048f`).** A reviewer probe using distinct names
`m` and `name_fork(m).0` exposed an internal merge-name collision and panic.
The reviewer initially classified this as a naming-contract issue. We hardened
the implementation: it wraps source names in a separate structural domain before
deriving merge names, so source fork ancestry cannot alias generated merge names.
A targeted edit/prefix regression and the randomized collection kernel now cover
names and their fork descendants.

## Validation and readiness

All **84 tests passed on native, JavaScript, Wasm GC, and Wasm**, including the
reviewer's independent randomized projected-thunk and composed-collection tests.
Strict all-backend checking, formatting, and generated interfaces also passed.
The independent review and disposition of findings are recorded in
[PRODUCTION_REVIEW.md](PRODUCTION_REVIEW.md).

This supports cautious adoption for bounded, synchronous workloads that follow
the immutable-value/key and naming contracts. It is not a blanket production
certification: there is no automatic eviction, concurrency/async support, safe
panic recovery, or portable maximum depth. Application-specific sustained-load
and memory budgets still need validation.

```sh
python3 stress/run.py --profile full --soak-seconds 300
moon run --release --target native cmd/stress -- collections 771 10000
```

See [workload definitions and methodology](README.md). The manual Extended stress
workflow runs five-minute native suites on Linux and macOS and retains raw
reports, including failure replays. Ordinary CI tests both pinned and latest
MoonBit versions.

## Matching platform runs

[Extended stress run 38673957637](https://github.com/bobzhang/incr.mbt/actions/runs/38673957637)
passed on both platforms at `e9a048f`. Raw report source and runner hashes were
verified against that revision. Platform case counts differ because the runner
performs additional work until the minimum duration is reached.

| Platform and raw report | Cases | Elapsed seconds | Differential rounds |
| --- | ---: | ---: | ---: |
| [Linux CI](results/2026-10-15-linux-soak.json) | 330 | 300.1 | 17,350,000 |
| [macOS CI](results/2026-10-15-macos-ci-soak.json) | 193 | 300.7 | 10,000,000 |
