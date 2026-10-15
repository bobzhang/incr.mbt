///|
test "trie permutations preserve membership and ordinary-hash equality" {
  for count in [1, 2, 31, 32, 33, 127] {
    let mut a : @catalog.Trie[Int32] = @catalog.Trie::empty()
    let mut b : @catalog.Trie[Int32] = @catalog.Trie::empty()
    for i in 0..<count {
      a = a.add(i * 17)
      b = b.add((count - i - 1) * 17)
    }
    assert_true(a == b)
    assert_eq(a.hash(), b.hash())
    assert_eq(a.fold(0, (_, acc) => acc + 1), count)
    for i in 0..<count {
      assert_true(a.contains(i * 17))
      assert_false(a.contains(i * 17 + 1))
    }
  }
}

///|
test "lazy map and filter compose across repeated edits" {
  let e = @incr.Engine::new()
  let input = e.cell(@catalog.List::from_array([1, 2, 3]))
  let list : @catalog.List[Int32] = Named(@incr.name_of_int(5), Art(input))
  let map = @catalog.list_map_lazy(e, x => x * 3)
  let filter = @catalog.list_filter_lazy(e, x => x % 2 == 0)
  let mapped = map.named(@incr.name_of_string("map"), list)
  let filtered = filter.named(@incr.name_of_string("filter"), Art(mapped))
  for i in 0..<100 {
    input.set(@catalog.List::from_array([i, i + 1, i + 2]))
    let expect = [i * 3, (i + 1) * 3, (i + 2) * 3].filter(x => x % 2 == 0)
    assert_eq(filtered.force().to_array(), expect)
  }
  e.dispose()
}

///|
test "sort and lazy map compose across repeated edits" {
  let e = @incr.Engine::new()
  let left = e.cell(@catalog.Tree::from_array([4, 1]))
  let right = e.cell(@catalog.Tree::from_array([3, 2]))
  let tree : @catalog.Tree[Int32] = Named(
    @incr.name_of_int(1),
    1,
    Art(left),
    Art(right),
  )
  let sort = @catalog.mergesort_list_of_tree(e)
  let sorted = sort.named(@incr.name_of_string("sort"), tree)
  let map = @catalog.list_map_lazy(e, x => x * 3)
  let mapped = map.named(@incr.name_of_string("map"), Art(sorted))
  for i in 0..<100 {
    left.set(@catalog.Tree::from_array([i, i + 4]))
    let expected = [i, i + 4, 3, 2]
    expected.sort()
    assert_eq(mapped.force().to_array(), expected.map(x => x * 3))
  }
  e.dispose()
}
