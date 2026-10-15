# Collection performance and memory: 2026-10-15

On this machine, the MoonBit port completed all seven edit workloads faster than
Rust Adapton at both measured collection sizes. Its median peak RSS was also lower
in those edit workloads. These are measurements of these implementations and
inputs, not a general MoonBit-versus-Rust language benchmark.

## Environment and method

- Apple M2 Ultra, 192 GiB RAM, macOS ARM64.
- OS reported by Python: `macOS-26.4.1-arm64-arm-64bit-Mach-O`.
- MoonBit CLI `0.1.20261012`, compiler `0.10.15+943464bfa`; native release backend.
- `rustc 1.89.0 (29483883e 2025-08-04)`; Cargo release profile, unmodified Adapton 0.3.31.
- Port and benchmark source revision: `be1ea2010a3e885701181993e294170cd01a0131`. Raw results also record SHA-256 source hashes.
- Rust reference: `ea903dd961bee3568c483a18a72983d9f4ef5ed2`.
- One warmup plus five measured fresh processes per language/case, run serially in alternating order.
- Median total wall time includes startup, construction, first demand, edits, consumption/checksumming, and teardown; compilation and Python oracle work are excluded.
- Memory is median **whole-process peak RSS** from `wait4`, including allocator and runtime overhead. MiB means 1,048,576 bytes. No baseline subtraction.
- Exact outputs of small traces matched an independent Python array oracle; all 280 measured process checksums matched it. The 56 warmup checksums matched too.
- This final pass was run without concurrent local builds or test runs from this task. It is a single-host sample, not a controlled multi-machine study.

[Raw samples and metadata](results/2026-10-15-macos-arm64.json) · [Harness and reproduction instructions](README.md)

## Collection edits

“Speedup” is Rust median wall time divided by MoonBit median wall time. Each row
uses the same edits and demands in both implementations. Different workloads use
different edit counts, so compare languages within a row.

| Workload | Elements | Edits | MoonBit ms | Rust ms | Speedup | MoonBit peak MiB | Rust peak MiB |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Tree sum | 1,024 | 10,000 | 99.2 | 247.6 | 2.50× | 4.91 | 6.09 |
| Full sort | 1,024 | 1,000 | 201.9 | 800.4 | 3.96× | 14.92 | 19.27 |
| Sort first 32 | 1,024 | 5,000 | 67.3 | 183.4 | 2.73× | 9.62 | 11.92 |
| Full lazy map | 1,024 | 5,000 | 43.9 | 582.1 | 13.25× | 2.31 | 2.48 |
| Map first 32 | 1,024 | 50,000 | 33.0 | 225.7 | 6.84× | 2.16 | 2.27 |
| Full lazy filter | 1,024 | 5,000 | 35.9 | 247.6 | 6.90× | 2.25 | 2.44 |
| List → tree → sum | 1,024 | 5,000 | 83.7 | 291.1 | 3.48× | 2.58 | 3.47 |
| Tree sum | 4,096 | 10,000 | 134.0 | 331.2 | 2.47× | 13.23 | 16.38 |
| Full sort | 4,096 | 1,000 | 838.2 | 2924.3 | 3.49× | 56.66 | 73.69 |
| Sort first 32 | 4,096 | 5,000 | 94.3 | 224.8 | 2.38× | 22.05 | 28.02 |
| Full lazy map | 4,096 | 5,000 | 209.0 | 2325.4 | 11.13× | 2.84 | 3.28 |
| Map first 32 | 4,096 | 50,000 | 35.0 | 229.3 | 6.56× | 2.44 | 2.50 |
| Full lazy filter | 4,096 | 5,000 | 133.1 | 942.5 | 7.08× | 2.70 | 3.14 |
| List → tree → sum | 4,096 | 5,000 | 129.1 | 369.6 | 2.86× | 3.72 | 6.47 |

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
| Tree sum | 256 | 2.80 | 3.00 |
| Full sort | 256 | 3.81 | 4.19 |
| Full lazy map | 256 | 2.12 | 2.09 |
| Tree sum | 1,024 | 4.80 | 5.27 |
| Full sort | 1,024 | 11.34 | 12.33 |
| Full lazy map | 1,024 | 2.25 | 2.33 |
| Tree sum | 4,096 | 13.06 | 14.27 |
| Full sort | 4,096 | 46.25 | 50.72 |
| Full lazy map | 4,096 | 2.80 | 2.89 |

## Memory as the edit history grows

Full sorting of 1,024 elements, retaining the same engine throughout the edits.

| Edits | MoonBit peak MiB | Rust peak MiB |
| ---: | ---: | ---: |
| 0 | 11.34 | 12.33 |
| 100 | 12.38 | 14.38 |
| 1,000 | 14.92 | 19.27 |
| 10,000 | 15.97 | 21.64 |

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
| 1 | 4.80 | 5.27 |
| 100 | 5.28 | 5.95 |
| 1,000 | 5.28 | 6.95 |

Neither shows memory growth proportional to the number of lifetimes in this
workload. RSS includes allocator reuse and is a high-water mark, so this is not
a measurement of live retained bytes after disposal or proof of no leaks.

## Limits

The benchmark covers deterministic integer workloads, two edit-workload sizes,
one native machine, and the stock Rust collection representations. It does not
establish bounds for arbitrary edit histories, mutable user objects, large payloads,
other compilers, or JavaScript/Wasm. Tiny differences near the roughly 2 MiB
process footprint should not be interpreted as precise collection-memory savings.
Trie sets are excluded because the reference’s trie integration tests hit
unimplemented code. CI runs a correctness smoke comparison, not a speed gate.
