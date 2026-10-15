# Collection performance and memory after fixes: 2026-10-15

Rerun after the identity-counter, disposal-buffer, and merge-sort name-domain fixes.

On this machine, the MoonBit port completed all seven edit workloads faster than
Rust Adapton at both measured collection sizes. Its median peak RSS was also lower
in those edit workloads. These are measurements of these implementations and
inputs, not a general MoonBit-versus-Rust language benchmark.

## Environment and method

- Apple M2 Ultra, 192 GiB RAM, macOS ARM64.
- OS reported by Python: `macOS-26.4.1-arm64-arm-64bit-Mach-O`.
- MoonBit CLI `0.1.20261012`, compiler `0.10.15+943464bfa`; native release backend.
- `rustc 1.89.0 (29483883e 2025-08-04)`; Cargo release profile, unmodified Adapton 0.3.31.
- Port and benchmark source revision: `4dde382257195a8b6a86509bc150af530065c044`. Raw results also record SHA-256 source hashes.
- Rust reference: `ea903dd961bee3568c483a18a72983d9f4ef5ed2`.
- One warmup plus five measured fresh processes per language/case, run serially in alternating order.
- Median total wall time includes startup, construction, first demand, edits, consumption/checksumming, and teardown; compilation and Python oracle work are excluded.
- Memory is median **whole-process peak RSS** from `wait4`, including allocator and runtime overhead. MiB means 1,048,576 bytes. No baseline subtraction.
- Exact outputs of small traces matched an independent Python array oracle; all 280 measured process checksums matched it. The 56 warmup checksums matched too.
- This final pass was run without concurrent local builds or test runs from this task. It is a single-host sample, not a controlled multi-machine study.

[Post-fix raw samples and metadata](results/2026-10-15-macos-arm64-post-fixes.json) · [Previous raw samples](results/2026-10-15-macos-arm64.json) · [Harness and reproduction instructions](README.md)

## Collection edits

“Speedup” is Rust median wall time divided by MoonBit median wall time. Each row
uses the same edits and demands in both implementations. Different workloads use
different edit counts, so compare languages within a row.

| Workload | Elements | Edits | MoonBit ms | Rust ms | Speedup | MoonBit peak MiB | Rust peak MiB |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Tree sum | 1,024 | 10,000 | 107.4 | 250.4 | 2.33× | 4.91 | 6.30 |
| Full sort | 1,024 | 1,000 | 207.2 | 781.3 | 3.77× | 14.98 | 19.52 |
| Sort first 32 | 1,024 | 5,000 | 75.4 | 184.0 | 2.44× | 9.75 | 12.17 |
| Full lazy map | 1,024 | 5,000 | 45.9 | 595.1 | 12.95× | 2.31 | 2.59 |
| Map first 32 | 1,024 | 50,000 | 35.2 | 227.1 | 6.46× | 2.16 | 2.27 |
| Full lazy filter | 1,024 | 5,000 | 38.4 | 252.1 | 6.56× | 2.25 | 2.52 |
| List → tree → sum | 1,024 | 5,000 | 95.2 | 297.6 | 3.12× | 2.58 | 3.83 |
| Tree sum | 4,096 | 10,000 | 151.6 | 348.5 | 2.30× | 13.23 | 16.73 |
| Full sort | 4,096 | 1,000 | 822.3 | 3022.8 | 3.68× | 56.77 | 73.86 |
| Sort first 32 | 4,096 | 5,000 | 94.1 | 212.4 | 2.26× | 22.28 | 27.98 |
| Full lazy map | 4,096 | 5,000 | 209.3 | 2234.4 | 10.67× | 2.84 | 3.22 |
| Map first 32 | 4,096 | 50,000 | 35.7 | 222.8 | 6.25× | 2.44 | 2.52 |
| Full lazy filter | 4,096 | 5,000 | 141.5 | 912.6 | 6.45× | 2.70 | 3.05 |
| List → tree → sum | 4,096 | 5,000 | 128.9 | 367.1 | 2.85× | 3.72 | 6.47 |

The largest speed differences are in repeated full list traversal. The reference
uses recursively cloned boxed list segments; MoonBit shares immutable values.
This representation difference is part of the comparison. Direct node handles
and typed memo tables also differ from Rust’s heterogeneous location table.
These are plausible contributors, not conclusions from a CPU/allocation profile.

The 32-element map demand intentionally ignores most edits outside its prefix.
The sequence workload alternates insertion/deletion before summing; it does not
demand a complete list round trip. Hash-derived sequence tree shapes can differ.
Rust lazy map/filter removes name markers while MoonBit preserves them; both
harnesses demand the same element values. See the methodology for details.

## Initial graph memory scaling

Construct and demand once, without edits. These short runs primarily describe
memory, not reliable latency differences.

| Workload | Elements | MoonBit peak MiB | Rust peak MiB |
| --- | ---: | ---: | ---: |
| Tree sum | 256 | 2.86 | 3.00 |
| Full sort | 256 | 3.89 | 4.16 |
| Full lazy map | 256 | 2.12 | 2.11 |
| Tree sum | 1,024 | 4.84 | 5.27 |
| Full sort | 1,024 | 11.41 | 12.34 |
| Full lazy map | 1,024 | 2.28 | 2.33 |
| Tree sum | 4,096 | 13.14 | 14.19 |
| Full sort | 4,096 | 46.33 | 50.73 |
| Full lazy map | 4,096 | 2.78 | 2.89 |

## Memory as the edit history grows

Full sorting of 1,024 elements, retaining the same engine throughout the edits.

| Edits | MoonBit peak MiB | Rust peak MiB |
| ---: | ---: | ---: |
| 0 | 11.41 | 12.34 |
| 100 | 12.39 | 14.36 |
| 1,000 | 14.98 | 19.52 |
| 10,000 | 16.09 | 21.66 |

Peak RSS increases with longer edit traces. New cached work and allocator
high-water usage can both contribute; these measurements do not separate them.
Growth over this trace is sublinear, which does not establish a universal memory
bound. The MoonBit engine still retains nodes and memo entries until disposal.

## Repeated engine disposal

Each round builds and demands a 1,024-element tree sum, then destroys the graph.
MoonBit uses `Engine::dispose`; Rust drops the DCG returned when replacing the
global engine with the naive engine.

| Complete graph lifetimes | MoonBit peak MiB | Rust peak MiB |
| ---: | ---: | ---: |
| 1 | 4.84 | 5.27 |
| 100 | 5.55 | 5.95 |
| 1,000 | 5.55 | 6.39 |

Neither shows memory growth proportional to the number of lifetimes in this
workload. RSS includes allocator reuse and is a high-water mark, so this is not
a measurement of live retained bytes after disposal or proof of no leaks.

## Change from the previous run

The previous run used `be1ea20`; this run uses `4dde382`.
Both use the same harness, workloads, compiler versions, and Rust reference on
the same host. Positive percentages mean slower total wall time in the new run.
The Rust column is an unchanged-implementation control. These are comparisons
between separate runs, not interleaved old/new MoonBit measurements or a causal
profile of individual fixes. Scheduling, allocator behavior, and host noise can
also affect results.

| Workload | Elements | MoonBit wall change | Rust control wall change | MoonBit peak MiB, before → after |
| --- | ---: | ---: | ---: | ---: |
| Tree sum | 1,024 | +8.2% | +1.1% | 4.91 → 4.91 |
| Full sort | 1,024 | +2.6% | -2.4% | 14.92 → 14.98 |
| Sort first 32 | 1,024 | +12.1% | +0.3% | 9.62 → 9.75 |
| Full lazy map | 1,024 | +4.6% | +2.2% | 2.31 → 2.31 |
| Map first 32 | 1,024 | +6.5% | +0.6% | 2.16 → 2.16 |
| Full lazy filter | 1,024 | +7.0% | +1.8% | 2.25 → 2.25 |
| List → tree → sum | 1,024 | +13.7% | +2.2% | 2.58 → 2.58 |
| Tree sum | 4,096 | +13.2% | +5.2% | 13.23 → 13.23 |
| Full sort | 4,096 | -1.9% | +3.4% | 56.66 → 56.77 |
| Sort first 32 | 4,096 | -0.3% | -5.5% | 22.05 → 22.28 |
| Full lazy map | 4,096 | +0.1% | -3.9% | 2.84 → 2.84 |
| Map first 32 | 4,096 | +1.9% | -2.8% | 2.44 → 2.44 |
| Full lazy filter | 4,096 | +6.3% | -3.2% | 2.70 → 2.70 |
| List → tree → sum | 4,096 | -0.1% | -0.7% | 3.72 → 3.72 |

The fixes remain enabled in all measurements: checked 64-bit identities,
saturating event counters, release of disposed map capacity, and source-name
isolation in merge sort. This harness drops engine handles at teardown, so it
does not expose the retained-handle disposal bug directly. The separate
[retained-handle stress comparison](../../stress/RESULTS.md) measures that fix.
Its roughly 210.6 → 9.3 MiB result is a different workload and is not a Rust comparison.

## Limits

The benchmark covers deterministic integer workloads, two edit-workload sizes,
one native machine, and the stock Rust collection representations. It does not
establish bounds for arbitrary edit histories, mutable user objects, large payloads,
other compilers, or JavaScript/Wasm. Tiny differences near the roughly 2 MiB
process footprint should not be interpreted as precise collection-memory savings.
Trie sets are excluded because the reference’s trie integration tests hit
unimplemented code. CI runs a correctness smoke comparison, not a speed gate.
