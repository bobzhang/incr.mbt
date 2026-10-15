# incr.mbt

A MoonBit port of Adapton's demand-driven incremental computation model.
It provides mutable inputs, lazy cached computations, dynamic dependencies,
nominal and structural memoization, projection reads, and incremental collections.
There are no external dependencies.

The port is based on the local Rust Adapton 0.3.31 reference in `.repos/adapton`.
The API is adapted to MoonBit; see [PORTING.md](PORTING.md) for coverage and differences.

## Start with cells and thunks

Create one engine, put changing inputs in cells, and read them with `force` inside
thunks. Edits invalidate cached work; computation happens only when demanded.
No explicit stabilization step is needed.

```mbt check
///|
test "readme incremental total" {
  let engine = @incr.Engine::new()
  let price = engine.cell(20)
  let quantity = engine.cell(3)
  let total = engine.thunk(() => price.force() * quantity.force())
  assert_eq(total.force(), 60)
  assert_eq(total.force(), 60)
  assert_eq(engine.stats().evaluations, 1)
  quantity.set(4)
  assert_eq(engine.stats().evaluations, 1)
  assert_eq(total.force(), 80)
  assert_eq(engine.stats().evaluations, 2)
}
```

Dependencies can change with control flow. The engine checks old observations in
execution order and stops when one changes, so it does not evaluate an obsolete
branch. Equal writes do nothing. If an intermediate result remains equal, its
parent can reuse its cached result without rerunning.

## Reuse computations by argument or name

A `Memo[A, T]` is a typed family of computations. `call(arg)` uses structural
identity: equal arguments share a result. `named(name, arg)` uses nominal identity:
reusing a name updates its arguments while preserving the articulation's identity.
The table identifies the program point, so retain it across edits.

```mbt check
///|
test "readme memoization" {
  let engine = @incr.Engine::new()
  let fib = @incr.Memo::recursive(engine, (memo, n : Int32) => {
    if n < 2 {
      n
    } else {
      memo.call(n - 1) + memo.call(n - 2)
    }
  })
  assert_eq(fib.call(10), 55)
  assert_eq(engine.stats().evaluations, 11)
  let double = @incr.Memo::new(engine, x => x * 2)
  let name = @incr.name_of_string("answer")
  let answer = double.named(name, 21)
  assert_eq(answer.force(), 42)
  assert_true(answer == double.named(name, 30))
  assert_eq(answer.force(), 60)
}
```

`Cells[T]` similarly groups named mutable cells; `cells.cell(name, value)` allocates
or updates one. `cells.intern(value)` hash-conses immutable values. Typed families
have separate name spaces, including when their types happen to be the same.
`engine.ns(name, body)` nests a namespace. Suspended computations retain the
namespace in which they were allocated.

Named allocations inside thunks are tracked as dependencies too. If an allocated
cell or a thunk's arguments are overwritten later, its allocator is invalidated
and restores its allocation when next demanded. Conflicting writes to names that
an actively executing thunk has already observed are rejected.

## Observe just the part you need

`force_map` records a pure projection of a value. For cells, irrelevant changes
are pruned before dirtying observers. For thunks, projection equality can avoid
rerunning the observer during dependency cleaning.

```mbt check
///|
test "readme projection" {
  let engine = @incr.Engine::new()
  let record = engine.cell(("Ada", 20))
  let greeting = engine.thunk(() => "Hello, " + record.force_map(x => x.0))
  assert_eq(greeting.force(), "Hello, Ada")
  record.set(("Ada", 21))
  assert_eq(greeting.force(), "Hello, Ada")
  assert_eq(engine.stats().evaluations, 1)
}
```

## Collections and inspection

The `dii/incr/catalog` package includes named articulated lists, lazy mapping and
filtering, trees, memoized tree folds and merge sort, persistent hash trie sets,
and bit strings. See the [collection examples](catalog/README.mbt.md).

`engine.stats()` returns cumulative allocation, evaluation, cache hit, dirtying,
and cleaning counts. `engine.snapshot()` returns detached graph metadata with
ordered dependency lists. `Engine::new(naive=true)` reruns each demanded thunk,
which is useful for checking incremental results against fresh evaluation.

## Computation contract

- A computation uses one engine. Cross-engine observations are rejected.
- Thunk bodies are synchronous, deterministic, and non-raising. Represent expected
  failures as result values. `set` is allowed only between computations.
- Store immutable snapshots. Do not mutate an array, map, or mutable record that
  is already a cached value or memo key. Copy it and write the new value to a cell.
  Unlike Rust's `Clone`, MoonBit does not automatically deep-copy stored values.
- Capture changing values as cells. Other captured closure state must remain
  fixed for the lifetime of a thunk or memo table. Equality and hashing must be
  consistent. A `force_map` callback must neither observe nor allocate graph nodes.
- Names must be unique within each typed family and namespace for allocations
  that need independent identities. Use `name_fork` or nested namespaces to split
  them deterministically.
- `force_cycle(Some(fallback))` cuts a recursive demand with a supplied value;
  it is not a fixed-point solver. An unexpected cycle panics. Discard a computation
  after a panic; panic recovery is not a supported evaluation mechanism.
- Engines retain their graph and memo tables retain their entries. There is no
  eviction or graph garbage collection API. Use bounded workloads and call
  `engine.dispose()` when their lifetime ends. Disposal clears edges, values,
  closures, and typed caches, and invalidates existing handles. It is especially
  important on native backends, where reference cycles are not collected. Very deep
  demand chains and recursive collection transformations are limited by the backend call stack.

## Build and test

Validated with MoonBit `0.1.20261012`. From the repository root:

```sh
moon check --target all --warn-list +unnecessary_annotation
moon test
moon test --target js
moon test --target native
moon run cmd/demo
moon fmt
moon info
```

README examples are executable tests. Generated `pkg.generated.mbti` files record
the public API. The source reference under `.repos/` is not needed to build.
GitHub Actions runs formatting, interface checks, all-backend type checking,
and Wasm GC, JavaScript, and native tests on Linux and macOS.

License: MPL-2.0, following the Adapton reference. See [LICENSE](LICENSE).
