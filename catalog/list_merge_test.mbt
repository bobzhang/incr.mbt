///|
test "named merge does not force an undemanded tail" {
  let e = @incr.Engine::new()
  let tail : @incr.Art[@catalog.List[Int32]] = e.thunk(() => {
    abort("undemanded merge tail")
  })
  let left : @catalog.List[Int32] = Named(
    @incr.name_of_int(1),
    Cons(1, Art(tail)),
  )
  let right : @catalog.List[Int32] = Cons(2, Nil)
  assert_eq(left.merge(right, engine=e).to_array(limit=1), [1])
  assert_eq(right.merge(left, engine=e).to_array(limit=1), [1])
  e.dispose()
}

///|
test "lazy merge tracks edited inputs after a partial demand" {
  let e = @incr.Engine::new()
  let tail = e.cell(@catalog.List::from_array([3, 5]))
  let left : @catalog.List[Int32] = Named(
    @incr.name_of_int(1),
    Cons(1, Art(tail)),
  )
  let right : @catalog.List[Int32] = Named(
    @incr.name_of_int(2),
    @catalog.List::from_array([2, 4]),
  )
  let merge = @catalog.list_merge(e)
  let result = merge.named(@incr.name_unit(), (left, right))
  assert_eq(result.force().to_array(limit=2), [1, 2])
  tail.set(@catalog.List::from_array([6, 8]))
  assert_eq(result.force().to_array(), [1, 2, 4, 6, 8])
  tail.set(@catalog.List::from_array([3, 5]))
  assert_eq(result.force().to_array(), [1, 2, 3, 4, 5])
  e.dispose()
}

///|
test "tree merge sort suspends named merge tails" {
  let e = @incr.Engine::new()
  let tree : @catalog.Tree[Int32] = Named(
    @incr.name_unit(),
    1,
    @catalog.Tree::from_array([3, 1]),
    @catalog.Tree::from_array([4, 2]),
  )
  let sort = @catalog.mergesort_list_of_tree(e)
  let sorted = sort.named(@incr.name_unit(), tree)
  assert_eq(sorted.force().to_array(limit=1), [1])
  let before = e.stats().evaluations
  assert_eq(sorted.force().to_array(), [1, 2, 3, 4])
  assert_true(e.stats().evaluations > before)
  e.dispose()
}
