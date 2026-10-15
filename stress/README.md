# Differential tests and sustained stress

The ordinary test suite runs fixed seeds on every supported backend. The same
kernels are available through `cmd/stress` for larger, replayable runs. Expected
values come from ordinary arrays and arithmetic, not the incremental engine's
naive mode.

```sh
moon test internal/stress --target native
python3 stress/run.py --profile smoke
python3 stress/run.py --profile full --soak-seconds 300
# Replay any recorded case (seed and step count are decimal):
moon run --release --target native cmd/stress -- collections 771 10000
```

Use `--output path.json` to preserve results. The runner records source hashes,
compiler, seed, count, exit status, elapsed time, and each subprocess's peak RSS.
A per-child timeout (default 300 seconds) fails the run rather than silently
skipping work. A failed assertion includes the seed and edit step. A crash or
watchdog failure retains the replay command and stderr in the partial report.
The runner exits nonzero on the first failure. Peak RSS is a process high-water
mark, not live graph size or a proof of no leaks.

## Workloads

- `engine`: 16 pair-valued inputs and 48 acyclic computations, interpreted from
  plain arrays for the oracle. Random batches change input fields and expression
  rules. Demands include branches, separate projections of the same value,
  repeated observations, unchanged intermediate values, and guarded divisions.
  Some batches are left undemanded; consumers run in randomized order. Periodic
  checks demand the complete graph and validate dependency IDs and fixed node count.
- `nominal`: 12 producers share 12 names across three namespaces. Random argument
  and input changes, conflicting external allocations, and producer demand order
  exercise allocation restoration. A second structural table uses deliberately
  colliding hashes. A 100-node bound checks reuse of the finite key spaces.
- `collections`: sequences hold up to 64 elements using a reusable pool of 96
  identities, including names and their fork descendants. Insertions, deletions,
  replacement, moves, reversal, equal writes,
  and occasional resets change three named/articulated layouts. Consumers include
  map/filter composition, list-to-tree conversion, reversed round trips, lazy
  sort prefixes/full output, order-sensitive folds, and collision-bucket trie
  folds. Empty/partial/full demands run in varying order. Plain arrays supply
  expected values, order, and set membership. Collection caches may retain work
  beyond the currently visible elements; the input-size limit is not an engine
  memory bound.
- `lifecycle`: repeatedly constructs and disposes both DAG and nominal-table
  graphs, including closures and reference cycles. The full profile uses 100,
  1,000, and 20,000 complete rounds. Each round runs 16 edits in each kernel.
- `retained`: creates all four typed cache tables and a high-fanout input,
  disposes the engine, and keeps the engine, memo, cell family, and input handles
  reachable across 10, 100, and 1,000 rounds (2,048 entries per table per round).
  This exposes retained backing buffers that a drop-everything lifecycle test
  misses. Empty handles themselves still consume memory. A white-box regression
  also requires all five map capacities to return to their initial size.
- `growing`: deliberately creates 1,000, 10,000, and 100,000 distinct named cache
  entries. It checks exactly one allocation per new key, reuse of old keys, and
  empty graph snapshots after disposal. This documents retention for growing
  workloads instead of treating it as automatic eviction.
- `depth`: evaluates and invalidates chains of 512, 2,048, and 8,192 nodes in
  separate native processes. These are probes, not portable guarantees of safe
  depth; JavaScript, Wasm, host stack settings, and more complex bodies differ.
  The normal cross-backend suite checks depth 128.

The full profile first runs 16 seeds × 100,000 DAG rounds, 16 × 50,000 nominal
rounds, and 8 × 10,000 collection rounds, followed by lifecycle, growth, and depth
cases. `--soak-seconds 300` continues with additional deterministic seeds
until the complete process has run for at least five minutes; it is not a sleep.
All rounds for each seed use one persistent engine, except the lifecycle and
retained-handle workloads. The JSON records the exact extra cases because their count
is machine-dependent. This is finite seeded testing, not exhaustive verification.

CI runs the ordinary tests across backends and a native stress smoke job. The
manual **Extended stress** workflow runs the full five-minute suite on Linux and
macOS and uploads reports even when a test fails. It has no schedule or timing
performance threshold.

Seed `0` intentionally maps to `0x9e3779b9` because xorshift32 cannot start at
zero. Both are replayable, but they generate the same stream: the 16 base seed
values represent 15 distinct streams. Extra soak seeds may also repeat a base
stream; round totals are not counts of unique executions.

See [recorded results](RESULTS.md) and the [independent readiness review](PRODUCTION_REVIEW.md).
