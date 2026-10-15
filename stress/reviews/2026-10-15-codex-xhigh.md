# Independent Codex CLI xhigh review

Original review text; workspace links normalized for repository navigation.
The review finished while the final soak was running. See
[the disposition and completed validation](../PRODUCTION_REVIEW.md) for later results.

**Verdict: conditionally ready for bounded production workloads under the documented contract. I found no unresolved stale-result defect in `e9a048f`.** The remaining release gate is a completed soak and platform validation for that exact revision.

The repository advanced during this review. I independently checked the changes in isolated `/tmp` snapshots; I did not edit tracked files, commit, push, or delegate.

1. **P1 — Identity rollover: independently reproduced; fixed by `9bb8684`.**  
   On the previous revision, creating edge 0, seeding `next_edge = -1`, creating two observers, and writing `2` reproduced stale `1`.

   ```sh
   moon -C /tmp/incr-review-baseline test review_rollover_wbtest.mbt --target native
   ```

   The fix is sound in the inspected paths: engine IDs, edge IDs, and reverse-edge keys use `Int64`; exhaustion checks precede identity insertion. My additional tests crossed `2^32`, JavaScript’s `2^53` boundary, and approached `Int64::MAX`, preserving old observers. Saturating statistics do not participate in correctness decisions. See [graph.mbt](../../graph.mbt#L75) and [counter_wbtest.mbt](../../counter_wbtest.mbt#L68).

2. **P2 — Disposal retained large backing buffers: verified on `9bb8684`; fixed by `b25c3c9`.**  
   Clearing the four typed-cache maps and reverse-dependency maps removed entries but retained capacity while handles remained reachable. After 10,000 entries/observers, all five capacities remained **16,384**, despite an empty graph.

   ```sh
   moon -C /tmp/incr-review-mvvar49p test review_disposal_wbtest.mbt --target native
   ```

   This also failed on JavaScript. The same reproduction passes after the fix, with capacities returning to **8**. Keeping 1,000 disposed handle groups reachable produced approximately **210 MiB** peak RSS before the fix versus **9.3 MiB** afterward. Replacing the maps addresses the cause; the added [capacity regression](../../lifecycle_wbtest.mbt#L24) covers what the original lifecycle workload missed. Relevant release paths are [memo.mbt](../../memo.mbt#L26), [cells.mbt](../../cells.mbt#L18), and [lifecycle.mbt](../../lifecycle.mbt#L17).

The **remaining validation gap** is revision-specific. At my final read:

| Revision | Report status |
|---|---|
| `9bb8684` | Passed: 365 cases, 300.07 seconds |
| `b25c3c9` | Passed: 355 cases, 302.13 seconds |
| `e9a048f` | **Running:** 72 cases recorded, 49.95 seconds |

I verified case schedules, successful exits, checksum output, source hashes, and runner hashes against frozen snapshots. The latest [report](../results/2026-10-15-native-soak.json) cannot yet substantiate a completed five-minute run. GitHub run `38672783702` was not independently verified: the sandbox blocked the API request.

The randomized oracles provide useful evidence: expected results come from ordinary arrays/arithmetic, and mutable generator arrays are converted into immutable cached values. The nominal generator’s conflicting producers are demanded separately; those restoration tests are meaningful. I did not count deliberate conflicting allocation identities as library defects.

Their original coverage had gaps: disposal dropped handles, DAG projections primarily targeted cells, collection composition was limited, and the randomized trie exercised collision buckets rather than branching structure. Independent tests now retained in `bf78146` cover projected thunks, longer collection pipelines, and branching-trie order. One minor breadth limitation remains: seed `0` maps to `0x9e3779b9`, so those two listed seeds generate identical streams.

I also reproduced a naming-contract boundary involving a source name and its fork descendant colliding in derived merge allocations. I did not classify that as an independent stale-result defect under the stated allocation-name contract. The subsequent [source-name isolation](../../catalog/tree_fold.mbt#L73) in `e9a048f` passes the reproduction and mixed-edit regression.

Actual validation included:

- **84/84 tests on each** of native, JavaScript, Wasm GC, and Wasm at `e9a048f`.
- `moon check --target all --warn-list +unnecessary_annotation`.
- Additional native release runs on `e9a048f`:

  | Mode | Seed | Steps |
  |---|---:|---:|
  | engine | 20261016 | 1,000,000 |
  | nominal | 195948557 | 500,000 |
  | collections | 270544960 | 50,000 |
  | collections | 305419896 | 50,000 |

  All passed. Replay with `moon run --release --target native cmd/stress -- MODE SEED STEPS`.

- Independent timeout and abnormal-exit probes: the runner correctly rejected both.
- Source comparison with the pinned Rust implementation; I did not rerun the Rust suite or execute tests on Linux.

The [four event fields in `Stats`](../../stats.mbt#L5) changing from `Int` to `Int64` is an intentional **source-breaking API change**. Explicitly typed downstream consumers need migration; `allocated` remains `Int`.

No further implementation fix is established by this review. Before release, complete the matching `e9a048f` soak and obtain matching platform results. Retained graph growth, backend stack limits, immutable snapshots, synchronous evaluation, naming discipline, and discarding computations after panic remain operational requirements. These results support that constrained deployment model, not exhaustive correctness or unrestricted memory bounds.
