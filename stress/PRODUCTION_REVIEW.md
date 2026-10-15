# Production-readiness review and disposition

Date: 2026-10-15. Final implementation reviewed: `e9a048f70e0f2c9fbdef6415a17d16b5c9e94a91`.

A fresh, ephemeral **Codex CLI 0.153.4** process used **gpt-6-astra**, reasoning
**xhigh**. It inspected independent scratch snapshots, reproduced defects,
authored additional tests, reran all four backends, and reviewed the generators
and recorded reports. It did not edit this checkout, commit, push, or delegate.

Invocation settings were `codex exec --ephemeral --sandbox workspace-write
-c 'model_reasoning_effort="xhigh"'`. This was an actual fresh CLI session,
not a review by a subagent in the implementation conversation.

The [original review](reviews/2026-10-15-codex-xhigh.md) concluded:

> Conditionally ready for bounded production workloads under the documented contract.
> I found no unresolved stale-result defect in `e9a048f`.

## Findings and responses

| Finding | Disposition |
| --- | --- |
| P1: 32-bit dependency identities could wrap and overwrite a live observer, producing stale values | Independently reproduced on the old code; checked `Int64` identities and saturating statistics in `9bb8684`. Boundary regressions retained. |
| P2: cleared maps retained large buffers when disposed handles remained reachable | Reproduced on native and JavaScript; map replacement in `b25c3c9`, capacity assertions, and retained-handle stress added. |
| Validation gaps: projected thunks, longer consumer pipelines, branching tries | Independent randomized tests retained in `bf78146` and run on all backends. |
| Source names and fork descendants can collide in merge-derived allocations | Reviewer classified this as a naming-contract boundary. Hardened merge-sort name domains anyway in `e9a048f`; targeted edits and randomized fork-ancestry coverage pass. |
| Seeds 0 and `0x9e3779b9` generate the same stream | Documented canonicalization: 16 base seed values represent 15 distinct streams. Counts describe executed rounds, not distinct traces. |
| Final revision's five-minute soak and platform results were incomplete when review ended | Completed afterward on the exact reviewed implementation; see validation below. |

The reviewer independently passed **84/84 tests on native, JavaScript, Wasm GC,
and Wasm**, plus strict all-backend checking. Additional native release probes
passed: engine seed 20261016 for 1,000,000 rounds, nominal seed 195948557 for
500,000 rounds, and collections seeds 270544960 and 305419896 for 50,000 rounds
each. Its timeout and abnormal-exit probes confirmed the runner rejects failed
children. These additional runs are separate from the five-minute report totals.

## Completed release-gate validation

The implementation process completed and checked the following after the review;
the reviewer itself could not query GitHub from its sandbox.

- [Final local five-minute soak and memory results](RESULTS.md), including the
  fork-ancestry generator, disposal stress, deliberate growth, and depth probes.
- [Extended stress on Linux and macOS](https://github.com/bobzhang/incr.mbt/actions/runs/38673957637):
  both jobs passed on `e9a048f`; raw reports are retained with the results.
- [Regular CI](https://github.com/bobzhang/incr.mbt/actions/runs/38673941603):
  passed on `e9a048f`, covering Linux/macOS, pinned/latest MoonBit, formatting,
  interfaces, all-backend checking, native/JavaScript/Wasm GC tests, benchmark
  oracle verification, and stress smoke checks.

Source hashes in the local and platform stress reports are verified against the
recorded Git revision. Documentation added after `e9a048f` does not change the
reviewed runtime, tests, or stress runner.

## Supported deployment scope

Use bounded, synchronous graphs with immutable cached values and keys, stable
naming discipline, and explicit `Engine::dispose()` at the end of each lifetime.
The library retains live graph nodes and memo entries until disposal. There is no
automatic eviction, concurrent/async engine support, portable recursion-depth
guarantee, or recovery contract after a panic. Validate representative application
loads and memory budgets before rollout. This review is finite empirical evidence,
not a proof or an unrestricted production certification.

The four event fields in public `Stats` now use `Int64` instead of `Int`; this is
a source-breaking change for explicitly typed consumers. `allocated` remains
`Int`. No stale-result or disposal-capacity issue identified by this review is
left unresolved.
