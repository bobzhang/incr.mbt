///|
test "names preserve structure and distinguish forks" {
  let root = @incr.name_of_string("root")
  let (a, b, c, d) = @incr.name_fork4(root)
  assert_eq(@incr.name_fork(root).0, a)
  assert_true(a != b && b != c && c != d)
  assert_true(@incr.name_of_int(1) != @incr.name_of_string("1"))
  assert_true(@incr.name_pair(a, b) != @incr.name_pair(b, a))
  let names : Map[@incr.Name, Int32] = Map([])
  names[a] = 42
  assert_eq(names[@incr.name_fork(root).0], 42)
}
