///|
test "sequence tree roundtrip preserves order for empty repeated and named lists" {
  let e = @incr.Engine()
  let build = @catalog.tree_of_list(e)
  let reversed = @catalog.tree_of_list(e, reverse=true)
  let to_list = @catalog.list_of_tree(e)
  let backwards = @catalog.list_of_tree(e, reverse=true)
  for values in [[], [1], [1, 1, 1], [5, 3, 8, 2, 4, 0]] {
    let list : @catalog.List[Int32] = Named(
      @incr.name_of_string("start"),
      @catalog.List::from_array(values).append(
        Named(@incr.name_of_string("end"), Nil),
      ),
    )
    let tree = build.named(@incr.name_unit(), list).force()
    assert_eq(tree.to_array(), values)
    assert_eq(to_list.named(@incr.name_unit(), tree).force().to_array(), values)
    let expected = values.rev()
    assert_eq(
      reversed.named(@incr.name_unit(), list).force().to_array(),
      expected,
    )
    assert_eq(
      backwards.named(@incr.name_unit(), tree).force().to_array(),
      expected,
    )
  }
  e.dispose()
}

///|
test "sequential fold orders leaf branch and name callbacks" {
  let e = @incr.Engine()
  let tree : @catalog.Tree[String] = Named(
    @incr.name_unit(),
    2,
    Bin(1, Leaf("a"), Leaf("b")),
    Leaf("c"),
  )
  let forward = @catalog.tree_fold_seq(
    e,
    leaf=(x, acc) => acc + x,
    bin=(_, acc) => acc + "B",
    name=(_, _, acc) => acc + "N",
  )
  let reverse = @catalog.tree_fold_seq(
    e,
    reverse=true,
    leaf=(x, acc) => acc + x,
    bin=(_, acc) => acc + "B",
    name=(_, _, acc) => acc + "N",
  )
  assert_eq(
    forward.named(@incr.name_of_string("root"), (tree, "")).force(),
    "aBbNc",
  )
  assert_eq(
    reverse.named(@incr.name_of_string("root"), (tree, "")).force(),
    "cNbBa",
  )
  e.dispose()
}

///|
test "sequential fold reuses an unaffected prefix after insertion and deletion" {
  let e = @incr.Engine()
  let left = e.cell(@catalog.Tree::from_array([1, 2]))
  let right = e.cell(@catalog.Tree::from_array([3, 4]))
  let tree : @catalog.Tree[Int32] = Named(
    @incr.name_of_string("split"),
    1,
    Art(left),
    Art(right),
  )
  let visits = Ref(0)
  let fold = @catalog.tree_fold_seq(
    e,
    leaf=(x, acc) => {
      visits.val += 1
      acc + x
    },
    bin=(_, acc) => acc,
    name=(_, _, acc) => acc,
  )
  let result = fold.named(@incr.name_of_string("root"), (tree, 0))
  assert_eq(result.force(), 10)
  assert_eq(visits.val, 4)
  right.set(@catalog.Tree::from_array([3, 9, 4]))
  assert_eq(result.force(), 19)
  assert_eq(visits.val, 7)
  right.set(@catalog.Tree::from_array([4]))
  assert_eq(result.force(), 7)
  assert_eq(visits.val, 8)
  e.dispose()
}

///|
test "named sequence edits flow through construction aggregation sorting and roundtrip" {
  let e = @incr.Engine()
  let chunk = e.cell(@catalog.List::from_array([1, 2]))
  let tail : @catalog.List[Int32] = Named(
    @incr.name_of_string("tail"),
    @catalog.List::from_array([7, 8]),
  )
  let input = e.thunk(() => {
    @catalog.List::Named(
      @incr.name_of_string("chunk"),
      chunk.force().append(tail),
    )
  })
  let build = @catalog.tree_of_list(e)
  let tree = build.named(@incr.name_of_string("build"), Art(input))
  let sum = @catalog.monoid_of_tree(e, 0, x => x, (a, b) => a + b)
  let total = sum.named(@incr.name_of_string("sum"), Art(tree))
  let sort = @catalog.mergesort_list_of_tree(e)
  let sorted = sort.named(@incr.name_of_string("sort"), Art(tree))
  let roundtrip = @catalog.list_of_tree(e)
  let output = roundtrip.named(@incr.name_of_string("list"), Art(tree))
  for values in [[1, 2], [1, 9, 2], [2], [], [5, 4, 3]] {
    chunk.set(@catalog.List::from_array(values))
    let expected = values + [7, 8]
    assert_eq(tree.force().to_array(), expected)
    assert_eq(output.force().to_array(), expected)
    assert_eq(total.force(), expected.fold(init=0, (a, b) => a + b))
    expected.sort()
    assert_eq(sorted.force().to_array(), expected)
  }
  e.dispose()
}

///|
struct Counted {
  value : Int32
  hashes : Ref[Int32]
}

///|
impl Eq for Counted with fn equal(self, other) {
  self.value == other.value
}

///|
impl Hash for Counted with fn hash_combine(self, hasher) {
  self.hashes.val += 1
  hasher.combine(self.value)
}

///|
test "list-tree edits reuse hashing work in unchanged named suffixes" {
  let e = @incr.Engine()
  let prefix_hashes = Ref(0)
  let suffix_hashes = Ref(0)
  let suffix : @catalog.List[Counted] = Named(
    @incr.name_of_string("suffix"),
    @catalog.List::from_array([
      { value: 7, hashes: suffix_hashes, },
      { value: 8, hashes: suffix_hashes, },
    ]),
  )
  let build = @catalog.tree_of_list(e)
  let make_input = (values : Array[Int32]) => {
    @catalog.List::Named(
      @incr.name_of_string("root"),
      @catalog.List::from_array(
        values.map(value => { value, hashes: prefix_hashes, }),
      ).append(suffix),
    )
  }
  let first = build.named(@incr.name_unit(), make_input([1, 2]))
  assert_eq(first.force().to_array().map(x => x.value), [1, 2, 7, 8])
  let before = suffix_hashes.val
  assert_true(before > 0)
  for values in [[1, 9, 2], [2], []] {
    let tree = build.named(@incr.name_unit(), make_input(values))
    assert_eq(tree.force().to_array().map(x => x.value), values + [7, 8])
    assert_eq(suffix_hashes.val, before)
  }
  e.dispose()
}
