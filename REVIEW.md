# Independent Codex CLI ultra review

Reviewed on 2026-10-15 with a fresh, ephemeral Codex CLI 0.153.4 session using
`gpt-6-astra` and `model_reasoning_effort="ultra"`. The reviewer inspected the
MoonBit implementation and the pinned Rust reference, ran cross-backend tests,
and used isolated scratch reproductions. It made no repository edits.

## Findings and corrections

| Finding | Correction | Commit |
| --- | --- | --- |
| P1: Result dirtying propagated through allocation-only edges and rejected a valid allocate/update/force sequence | Distinguish allocation and observation effects; only result observations propagate transitively | `aa8d540` |
| P1: Order-insensitive collision-bucket equality allowed a sequential trie fold to return an incorrect cached value | Make structural equality preserve bucket order and provide `same_elements` for set comparison | `a6df2fd` |
| P2: Named list merging and primary tree merge sort evaluated undemanded tails | Add reusable lazy merge tables and use them in tree merge sort | `b30e981` |
| P2: Functional upstream incremental sequence construction and traversal were missing | Port `tree_of_list`, `tree_fold_seq`, and `list_of_tree`, with forward/reverse and insertion/deletion reuse tests | `fd05259` |

The first reviewer independently verified the first two corrections at `c47f791`.
The latter two were implemented after that snapshot. Regression tests reproduce
the original failures and cover the new sequence pipeline. The equivalent Rust
allocation and named-merge reproductions passed; the reference's five trie
integration tests instead fail at an existing upstream `panic!("todo")`.

## Fresh verification after corrections

A second fresh, ephemeral Codex CLI session used the same model and ultra
reasoning setting to verify all four corrections against the Rust source. It
reported: "All four findings are addressed. No remaining actionable soundness
errors or translation mistakes found against `.repos/adapton`."

The focused review passed 42 tests on both Wasm GC and native, including 3,150
mixed edit steps. It checked lazy prefixes, stable merge ties, insertion and
deletion, reuse of unaffected regions, both traversal directions, and preservation
of names through round trips. Its reference comparison was source-level; it did
not repeat the broad audit, Rust suite, memory measurements, or CI.

The generated sequence and stable merge checks are retained in
`catalog/sequence_trace_test.mbt` and `catalog/merge_trace_test.mbt`. The complete
repository suite now passes 68 tests on each of Wasm, Wasm GC, JavaScript, and
native, with strict all-target checking and generated interfaces verified.

## Additional recommendations addressed

- Added 400 deterministic named allocation/overwrite/edit traces checked against
  a direct mathematical oracle, independently of the engine's naive mode.
- Retained the reviewer's four-node cycle, projection, composed collection, and
  trie permutation checks as permanent tests.
- Added insertion/deletion checks that count unchanged suffix hashing work and
  unchanged prefix fold work.
- GitHub CI tests Linux and macOS with both the pinned official toolchain
  `0.10.15+943464bfa` and `latest`, including formatting, public interfaces,
  all-backend type checking, and Wasm GC, JavaScript, and native execution.
- Added a repeatable native disposal benchmark and measured process memory.

## Native disposal measurement

On this macOS arm64 host, using MoonBit compiler `0.10.15+943464bfa`, a native
debug executable repeatedly allocated an engine, a named cell family, and a
recursive memo table with 65 computations. Each iteration forced the result,
edited its input, forced again, and disposed the engine.

| Iterations | Maximum RSS | Peak memory footprint | Checksum |
| --- | ---: | ---: | ---: |
| 200 | 2,179,072 bytes | 1,540,480 bytes | 16,400 |
| 20,000 | 2,179,072 bytes | 1,540,480 bytes | 1,640,000 |

The measured footprint did not grow with 100 times more cycles. This is evidence
for this workload, not proof that all applications are leak-free.

To repeat on macOS, build once so compiler memory is excluded:

```sh
moon build --target native bench/dispose
/usr/bin/time -l _build/native/debug/build/bench/dispose/dispose.exe
/usr/bin/time -l _build/native/debug/build/bench/dispose/dispose.exe large
```

On Linux use `/usr/bin/time -v` instead; its RSS units differ.
