///|
test "upstream set membership equality and insertion order" {
  let empty : @catalog.Trie[Int32] = @catalog.Trie::empty()
  assert_true(empty.is_empty())
  assert_false(empty.contains(7))
  let a = empty.add(7).add(1).add(8)
  let b = empty.add(8).add(7).add(1)
  assert_true(a == b)
  assert_true(a == a.add(7))
  assert_false(a.is_empty())
  for x in [1, 7, 8] {
    assert_true(a.contains(x))
  }
  assert_false(a.contains(0))
  assert_eq(a.fold(0, (x, sum) => sum + x), 16)
  assert_true(
    @catalog.Trie::from_list(@catalog.List::from_array([7, 1, 8])) == a,
  )
}

///|
struct Key(Int32) derive(Eq)

///|
impl Hash for Key with fn hash_combine(_self, hasher) {
  hasher.combine(0)
}

///|
test "trie collision buckets retain every distinct value" {
  let a = @catalog.Trie::empty().add(Key(1)).add(Key(2)).add(Key(3))
  let b = @catalog.Trie::empty().add(Key(3)).add(Key(2)).add(Key(1))
  assert_true(a == b)
  assert_eq(a.hash(), b.hash())
  assert_true(a.contains(Key(2)))
  assert_false(a.contains(Key(4)))
  assert_eq(a.fold(0, (_, n) => n + 1), 3)
}

///|
test "named trie fold tracks successive edits" {
  let e = @incr.Engine::new()
  let cell = e.cell(@catalog.Trie::empty())
  let tree = @catalog.Trie::named(
    @incr.name_of_string("set"),
    @catalog.Trie::art(cell),
  )
  let fold = @catalog.trie_fold(e, (x, sum) => sum + x)
  let result = fold.named(@incr.name_of_string("fold"), (tree, 0))
  let mut set = @catalog.Trie::empty()
  for i in 1..<20 {
    set = set.add(i)
    cell.set(set)
    assert_eq(result.force(), i * (i + 1) / 2)
  }
}

///|
test "bitstring width and upstream prepend shift cases" {
  let empty = @catalog.BitString::new(0, 0)
  assert_true(empty != empty.prepend(0))
  let bits = empty.prepend(1).prepend(0).prepend(1)
  assert_eq(bits.length, 3)
  assert_eq(bits.value, 5)
  assert_true(bits.is_set(2))
  assert_false(bits.is_set(1))
  assert_eq(bits.flip(1).value, 7)
  assert_eq(@catalog.BitString::new(2, 3).shift_left(1).value, 2)
  assert_eq(@catalog.BitString::new(4, 2).shift_left(2).value, 8)
  assert_eq(bits.shift_left(32).value, 0)
}
