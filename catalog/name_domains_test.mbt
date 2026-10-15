///|
test "merge sort separates source names from internal forked names" {
  let m = @incr.name_of_int(1)
  let (left, right) = @incr.name_fork(m)
  for q in [left, right, @incr.name_fork(left).0] {
    let e = @incr.Engine()
    let input = e.cell(@catalog.Tree::Nil)
    let sort = @catalog.mergesort_list_of_tree(e)
    let output = sort.named(@incr.name_of_string("sort-root"), Art(input))
    for step in 0..<24 {
      let values = [1 + step % 5, 2 - step, 4 + step, 3 - step % 7]
      input.set(
        Named(
          @incr.name_of_int(2),
          2,
          Named(m, 1, Leaf(values[0]), Leaf(values[1])),
          Named(q, 1, Leaf(values[2]), Leaf(values[3])),
        ),
      )
      values.sort()
      let prefix = step % 5
      assert_eq(
        output.force().to_array(limit=prefix),
        values[:prefix].to_owned(),
      )
      assert_eq(output.force().to_array(), values)
    }
    e.dispose()
  }
}
