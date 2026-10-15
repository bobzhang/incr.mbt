# Adapton port coverage

Reference: `.repos/adapton`, Rust Adapton 0.3.31, commit
`ea903dd961bee3568c483a18a72983d9f4ef5ed2`.
The source reference is ignored by Git and is not a build dependency.
The port retains the reference's MPL-2.0 license.

## Implemented

| Reference feature | MoonBit API / behavior |
| --- | --- |
| DCG cells, values, thunks | `Engine::cell`, `put`, `thunk`, `Art::force`, `set` |
| Demand-driven change propagation | Reverse-edge dirtying, ordered dependency cleaning, equality-based reuse |
| Dynamic dependencies | Revoke old edges and record the new execution's observations |
| Nominal cells | `Cells[T]::cell` |
| Nominal thunk allocation | `Memo[A, T]::named`; changed arguments invalidate observers and allocators |
| Structural identity | `Memo::structural` / `call` and `Cells::intern`, with hash collision checks |
| Program points and spurious arguments | One stable body per typed memo table; fixed values captured by its closure |
| Allocation effects | Cell value and thunk argument dependencies, including writes during cleaning |
| Names, forks, pairs, namespaces | Structural `Name`, `name_*`, `Engine::ns`; thunks capture allocation paths |
| Projected observations | `Art::force_map`; cell projections prune dirtying |
| Cycle cutting | `Art::force_cycle` with optional fallback |
| Derived computations | `Art::map` creates a cached derived thunk |
| Naive evaluation | `Engine::new(naive=true)` reruns demanded bodies |
| Lifecycle | `Engine::dispose` releases graph edges, typed caches, and closures |
| Reflection | `Stats` and detached `NodeInfo` snapshots |
| Named lists | Persistent `List`, lazy map/filter, demand, conversion, fold, reverse, append, merge |
| Trees and sequences | Persistent `Tree`, balanced array construction, incremental hash-level `tree_of_list`, `list_of_tree`, and memoized bottom-up and sequential folds |
| Aggregation and sorting | `monoid_of_tree`, lazy `list_merge`, demand-driven `mergesort_list_of_tree` |
| Trie sets | Persistent `Trie`, add, membership, fold, named incremental fold, list conversion |
| Bit strings | Width-preserving values, prepend, flip, bit testing, masked shift |

## Deliberate adaptations

The engine is explicitly passed when constructing cells and memo families. Typed
families replace the Rust global heterogeneous location table and its dynamic
casts. Different families never alias names, even when they use the same value
type. Consequently, the reference's runtime type-conflict tests become a property
of the API's static typing and family isolation.

MoonBit values are shared references, so cached values and keys must be treated
as immutable snapshots. Identity equality/hashing on `Art` does not observe its
contents. `Memo` closes over a single body rather than accepting a new closure
and a Rust program-point macro at each allocation.

`Art::map` caches its derived result; the Rust `thunk_map` wrapper itself does not.
Naive mode uses the same mutable input interface and graph bookkeeping while
bypassing thunk result reuse. It is a semantic comparison mode, not a performance
baseline for a minimal from-scratch evaluator.

The trie uses MoonBit's 32-bit hashes and explicit collision buckets, rather than
reproducing Rust's seeded hashes, `Meta::min_depth`, and exact probabilistic shape.
Set contents are preserved. Structural equality includes collision-bucket order
to make sequential folds sound under memoization; `same_elements` provides
insertion-order-independent set comparison.
Bit strings validate widths up to the reference's supported maximum of 30.

## Not reproduced

This is an incremental-computation port, not a source-compatible translation of
every experimental utility. It does not reproduce Rust macros, dynamic value
serialization/parsing, nested reflection traces, environment-driven debug output,
the abstract-domain `AbsMapFam` optimization, or the entire polymorphic collection
trait hierarchy. General projected observations are available through `force_map`.

The experimental arithmetic parser and fixed-point stubs are not exported by the
reference's `catalog/mod.rs` and are omitted. The specialized name-passing
bottom-up fold, tree pruning/filter variants, and multiple experimental merge-sort
variants are also omitted. The main incremental list/tree conversion pipeline,
sequential and bottom-up folds, and demand-driven merge sort are available.

There is no asynchronous/concurrent evaluator, graph eviction, automatic cloning,
or fixed-point solver. See the README computation contract.

## Validation

Tests cover the reference's divide-by-zero and expensive-branch avoidance cases,
projection pruning, named cell and thunk replacement, allocation restoration,
dynamic edge removal, unchanged intermediate results, cycle handling, namespace
restoration, and misuse rejection. Additional tests compare direct, incremental,
and naive results across 300 edit sequences, verify hash collisions, and assert
reuse counts for lazy lists and tree edits. README examples run as tests.

Run `moon test`, `moon test --target js`, and `moon test --target native`;
`moon check --target all` checks the complete supported backend set.
