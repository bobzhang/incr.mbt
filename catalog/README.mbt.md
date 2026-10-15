# Incremental collections

Import `dii/incr/catalog` along with `dii/incr`.

A named node marks a reuse boundary. An articulation points to either a mutable
input or another computation. Collection values are persistent: replace a cell's
value to edit a structure. Keep the mapper or fold table across successive edits.

```mbt check
///|
test "readme tree aggregation" {
  let engine = @incr.Engine::new()
  let left = engine.cell(@catalog.Tree::from_array([1, 2]))
  let right = engine.cell(@catalog.Tree::from_array([3, 4]))
  let tree : @catalog.Tree[Int32] = Named(
    @incr.name_of_string("split"),
    1,
    Art(left),
    Art(right),
  )
  let sum = @catalog.monoid_of_tree(engine, 0, x => x, (a, b) => a + b)
  let result = sum.named(@incr.name_of_string("sum"), tree)
  assert_eq(result.force(), 10)
  left.set(@catalog.Tree::from_array([10, 20]))
  assert_eq(result.force(), 37)
}
```

`monoid_of_tree` and `tree_fold_up` cache the left and right children of each named
node separately. `mergesort_list_of_tree` uses the same mechanism to reuse sorted
subtrees. Plain `Bin` nodes are traversed within the enclosing computation.
`Tree::from_array` makes a balanced immutable tree; add names and cells at your
application's edit boundaries.

For editable sequences, `tree_of_list(engine)` converts a named list into a
hash-level tree and reuses named regions after insertions and deletions.
`tree_fold_seq(engine, leaf=..., bin=..., name=...)` visits leaves and branch
boundaries in order, memoizing both subtrees and their incoming accumulators.
Its argument is `(tree, initial_accumulator)`. `list_of_tree(engine)` performs
the inverse conversion to a named articulated list. Each accepts `reverse=true`
to reverse traversal order. Keep these tables across edits, just like the
bottom-up folds.

`list_merge(engine)` creates a reusable merge table for a pair of sorted lists.
`left.merge(right, engine=engine)` performs a single merge. Both suspend tails
at name boundaries; `mergesort_list_of_tree` uses the same lazy merge behavior,
so asking for a prefix does not perform every remaining merge comparison.

`list_map_lazy` and `list_filter_lazy` suspend at `List::Named` boundaries.
`to_array(limit=n)` demands at most the first `n` elements, leaving later named
tails unforced. `eager` explicitly demands the entire list. Basic `fold`, `reverse`,
and `append` materialize their input; they are not memoized transformations.

```mbt check
///|
test "readme lazy list" {
  let engine = @incr.Engine::new()
  let tail = engine.cell(@catalog.List::from_array([2, 3]))
  let input : @catalog.List[Int32] = Cons(
    1,
    Named(@incr.name_of_string("tail"), Art(tail)),
  )
  let mapper = @catalog.list_map_lazy(engine, x => x * 10)
  let output = mapper.named(@incr.name_of_string("map"), input)
  assert_eq(output.force().to_array(limit=1), [10])
  tail.set(@catalog.List::from_array([4, 5]))
  assert_eq(output.force().to_array(), [10, 40, 50])
}
```

`Trie` is an immutable hash set with equality-checked collision buckets. Structural equality includes collision-bucket order because sequential folds
can observe that order. Use `same_elements` to compare set membership regardless
of insertion order; this operation forces articulated contents. Named wrappers
and articulations also carry identity, so structural equality does not force
contents. `Trie::fold` traverses immediately; `trie_fold` creates a reusable table
whose argument is `(trie, initial_accumulator)` and caches at named boundaries.

These are ports of the useful reference collection algorithms with concrete
MoonBit types, rather than the Rust introduction/elimination trait hierarchy.
