///|
test "list conversion fold merge and basic operations" {
  let xs = @catalog.List::from_array([1, 2, 3])
  assert_eq(xs.to_array(), [1, 2, 3])
  assert_eq(xs.to_array(limit=2), [1, 2])
  assert_eq(xs.to_array(limit=0), [])
  assert_eq(xs.reverse().to_array(), [3, 2, 1])
  assert_eq(xs.fold(0, (x, r) => x - r), 2)
  assert_eq(xs.append(xs).to_array(), [1, 2, 3, 1, 2, 3])
  assert_eq(
    xs
    .merge(@catalog.List::from_array([2, 4]), engine=@incr.Engine::new())
    .to_array(),
    [1, 2, 2, 3, 4],
  )
  assert_true((Nil : @catalog.List[Int32]).is_empty())
}

///|
test "lazy map only demands the named prefix and reuses unchanged tail" {
  let e = @incr.Engine::new()
  let tail = e.cell(@catalog.List::from_array([3, 4]))
  let input : @catalog.List[Int32] = Cons(
    1,
    Named(@incr.name_of_int(1), Cons(2, Named(@incr.name_of_int(2), Art(tail)))),
  )
  let calls = Ref(0)
  let map = @catalog.list_map_lazy(e, x => {
    calls.val += 1
    x * 10
  })
  let output = map.named(@incr.name_of_string("root"), input)
  assert_eq(output.force().to_array(limit=1), [10])
  assert_eq(calls.val, 1)
  assert_eq(output.force().to_array(), [10, 20, 30, 40])
  assert_eq(calls.val, 4)
  tail.set(@catalog.List::from_array([5]))
  assert_eq(output.force().to_array(), [10, 20, 50])
  assert_eq(calls.val, 5)
}

///|
test "lazy filter tracks cell edits" {
  let e = @incr.Engine::new()
  let tail = e.cell(@catalog.List::from_array([1, 2, 3, 4]))
  let filter = @catalog.list_filter_lazy(e, x => x % 2 == 0)
  let input : @catalog.List[Int32] = Named(@incr.name_of_int(1), Art(tail))
  let result = filter.named(@incr.name_of_string("root"), input)
  assert_eq(result.force().to_array(), [2, 4])
  tail.set(@catalog.List::from_array([5, 6, 8]))
  assert_eq(result.force().eager().to_array(), [6, 8])
}

///|
test "tree conversions preserve order and names" {
  let tree = @catalog.Tree::from_array([1, 2, 3, 4, 5])
  assert_eq(tree.to_array(), [1, 2, 3, 4, 5])
  assert_eq(tree.to_array(reverse=true), [5, 4, 3, 2, 1])
  assert_eq(tree.to_list().to_array(), [1, 2, 3, 4, 5])
  let named : @catalog.Tree[Int32] = Named(
    @incr.name_unit(),
    1,
    Leaf(1),
    Leaf(2),
  )
  assert_eq(named.to_list().to_array(), [1, 2])
}

///|
test "tree aggregate and sort reuse the unaffected subtree" {
  let e = @incr.Engine::new()
  let left = e.cell(@catalog.Tree::from_array([3, 1]))
  let right = e.cell(@catalog.Tree::from_array([4, 2]))
  let tree : @catalog.Tree[Int32] = Named(
    @incr.name_of_string("split"),
    1,
    Art(left),
    Art(right),
  )
  let visits = Ref(0)
  let sum = @catalog.monoid_of_tree(
    e,
    0,
    x => {
      visits.val += 1
      x
    },
    (a, b) => a + b,
  )
  let sort = @catalog.mergesort_list_of_tree(e)
  let result = sum.named(@incr.name_of_string("sum"), tree)
  let sorted = sort.named(@incr.name_of_string("sort"), tree)
  assert_eq(result.force(), 10)
  assert_eq(sorted.force().to_array(), [1, 2, 3, 4])
  assert_eq(visits.val, 4)
  left.set(@catalog.Tree::from_array([10, 5]))
  assert_eq(result.force(), 21)
  assert_eq(sorted.force().to_array(), [2, 4, 5, 10])
  assert_eq(visits.val, 6)
}
