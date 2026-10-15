# Native collection and memory comparison

This harness runs the MoonBit port and the **unmodified Rust Adapton 0.3.31**
reference at `ea903dd961bee3568c483a18a72983d9f4ef5ed2`. It measures the actual
public collection implementations, including their representation and cloning
costs. It does not substitute a newly optimized Rust implementation.

See [the recorded results](RESULTS.md) for timings, memory scaling, and the
measurement machine. The raw JSON preserves every measured sample.

## Reproduce

Requirements: MoonBit, Rust/Cargo, Python 3.9+, and macOS or Linux. From the
repository root, prepare the ignored reference checkout if it is absent:

```sh
git clone https://github.com/Adapton/adapton.rust.git .repos/adapton
git -C .repos/adapton checkout ea903dd961bee3568c483a18a72983d9f4ef5ed2
python3 bench/compare/run.py --quick --repeats 1 --warmups 0
python3 bench/compare/run.py --output bench/compare/results/local.json
```

The runner verifies the reference commit and rejects tracked modifications. Cargo
builds offline against that checkout using the committed lockfile. Both binaries
are release builds. Defaults are one warmup and five measured samples per
implementation per case. `--mode sort_full` selects one workload; `--skip-build`
reuses binaries (only use it when they are current). The JSON contains compiler
versions, source commit and hashes, all samples, checksums, and medians.

## Workloads

| Workload | Construction and demand | Edit schedule |
| --- | --- | --- |
| `sum` | Balanced named tree, every branch and leaf articulated; `monoid_of_tree` | Replace one leaf, then demand the sum |
| `sort_full` | Same tree; `mergesort_list_of_tree`, consume all values | Replace one leaf, then demand the entire sorted output |
| `sort_prefix` | Same sort, demand only 32 values | Replace one leaf, then demand the first 32 sorted values |
| `map_full` | Named list chunks of 16 values; lazy `x * 3 + 1` map | Replace one value, rebuild only its chunk, demand all mapped values |
| `map_prefix` | Same map, demand only 32 values | Same edits; most fall outside the demanded prefix |
| `filter_full` | Same chunks; lazy `x % 3 == 0` filter | Replace one value, then demand all matching values |
| `sequence` | Same chunks; `tree_of_list` followed by `monoid_of_tree` | Insert one value at a chunk boundary, remove it next step, then move to another chunk |
| `lifecycle` | Build and demand a tree sum, destroy engine, repeat | Counts are complete graph lifetimes, not edits |

Initial values are `(i * 37 + 11) % 10007`. Replacement index is
`(step * 97 + 13) % n`, replacement value is `(step * 53 + 7) % 10007`.
Sequence insertion/deletion pairs select chunk `(pair * 97 + 13) % (n / 16)`.
Both programs use 32-bit integer elements and 64-bit output checksums. All these
workload values and checksums fit in their respective types.

Tree topology and list chunk boundaries are identical. Each tree branch is a
cell containing a named branch with articulated children, so arguments do not
recursively clone whole unarticulated subtrees. The hash-derived sequence tree
shape can differ because the libraries use different hash functions. We isolate
sequence construction and aggregation in separate namespaces in both versions.

Rust's `vec_of_list` counts name markers toward its demand limit. The Rust harness
therefore traverses the public list constructors, counting only actual values,
to match MoonBit `to_array(limit=...)`. MoonBit's lazy map/filter preserves names;
the reference's corresponding functions discard those markers in the output.
The harness preserves each implementation's behavior and compares element values.

## Correctness and measurement

Before benchmarking, both binaries emit every result of small 64-element traces
and the runner compares those exact outputs to an independent Python array oracle.
Every measured process also has its checksum checked against that oracle. The
oracle runs outside the timed process. Checksums incorporate output length,
element positions, and values. They prevent dead-code elimination and detect
ordinary mismatches; checksums alone are not a proof of semantic equivalence.

The implementations run serially in alternating order, in fresh processes.
`ADAPTON*` environment settings are removed. Compilation is excluded. Wall time
includes process startup, input construction, initial demand, all edits and
subsequent demands, output checksumming, and engine teardown. These are total
workload times, not isolated update latencies. Tiny no-edit cases are intended for
memory scaling, not reliable speed comparisons.

`os.wait4` obtains **each child's peak resident set size**, normalized to bytes
(macOS reports bytes, Linux reports KiB). This is whole-process peak RSS, including
runtime, allocator, and temporary data; it is not retained graph size or an
allocation count. The parent process and compiler are not the measured processes.
Raw user/system CPU times are recorded as well. No baseline is subtracted.

For lifecycle cases MoonBit calls `Engine::dispose`; Rust replaces its global DCG
with the naive engine and drops the returned graph. Ordinary cases also tear down
the graph before exiting. The default matrix includes initial graph sizes of 256,
1,024, and 4,096, a 1,024-element full-sort edit-count sweep through 10,000 edits,
and lifecycle counts of 1, 100, and 1,000. Peak RSS measures high-water usage, not
post-disposal RSS, so a flat lifecycle curve is evidence for this workload only.

This is a single-threaded native comparison. It does not cover Wasm/JavaScript,
trie sets (the reference's trie integration tests reach unimplemented code),
concurrency, every edit distribution, or arbitrary user-supplied value types.
No performance threshold is enforced in CI.
