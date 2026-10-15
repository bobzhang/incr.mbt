///|
struct MergeItem {
  key : Int32
  id : Int32
  comparisons : Ref[Int32]
}

///|
impl Eq for MergeItem with fn equal(self, other) {
  self.key == other.key && self.id == other.id
}

///|
impl Compare for MergeItem with fn compare(self, other) {
  if self.key >= 100 && other.key >= 100 {
    self.comparisons.val += 1
  }
  self.key.compare(other.key)
}

///|
fn merge_input(items : Array[MergeItem]) -> @catalog.List[MergeItem] {
  let mut list : @catalog.List[MergeItem] = Nil
  for i = items.length() - 1; i >= 0; i = i - 1 {
    let item = items[i]
    list = Named(@incr.name_of_int(item.id), Cons(item, list))
  }
  list
}

///|
fn stable_merge_oracle(
  left : Array[MergeItem],
  right : Array[MergeItem],
) -> Array[(Int32, Int32)] {
  let result = []
  let mut i = 0
  let mut j = 0
  while i < left.length() || j < right.length() {
    if j == right.length() || (i < left.length() && left[i].key <= right[j].key) {
      result.push((left[i].key, left[i].id))
      i += 1
    } else {
      result.push((right[j].key, right[j].id))
      j += 1
    }
  }
  result
}

///|
test "lazy merge insertion deletion duplicates empty sides and stable ties" {
  let e = @incr.Engine()
  let left = e.cell(@catalog.List::Nil)
  let right = e.cell(@catalog.List::Nil)
  let count = Ref(0)
  let merge = @catalog.list_merge(e)
  let output = merge.named(
    @incr.name_of_string("merge"),
    (Art(left), Art(right)),
  )
  let scenarios = [
    [],
    [0],
    [1, 1, 2, 3],
    [1, 2],
    [1, 1, 1, 1],
    [0, 2, 4, 6],
    [2, 3, 5],
  ]
  for a in scenarios {
    for b in scenarios {
      let xs = a.mapi((i, key) => { key, id: i, comparisons: count, })
      let ys = b.mapi((i, key) => { key, id: 100 + i, comparisons: count, })
      left.set(merge_input(xs))
      right.set(merge_input(ys))
      let expect = stable_merge_oracle(xs, ys)
      assert_eq(
        output.force().to_array(limit=1).map(x => (x.key, x.id)),
        expect[:Int32::min(1, expect.length())].to_owned(),
      )
      assert_eq(output.force().to_array().map(x => (x.key, x.id)), expect)
    }
  }
  e.dispose()
}

///|
test "lazy merge reuses unchanged named suffix after prefix insertion deletion" {
  let e = @incr.Engine()
  let comparisons = Ref(0)
  let xs = [ for i in 0..<12 => { key: 100 + i * 2, id: i, comparisons, } ]
  let ys = [
    for i in 0..<12 => { key: 101 + i * 2, id: 100 + i, comparisons, }
  ]
  let suffix = merge_input(xs)
  let right = merge_input(ys)
  let merge = @catalog.list_merge(e)
  let initial = merge.named(@incr.name_of_string("merge"), (suffix, right))
  assert_eq(
    initial.force().to_array().map(x => (x.key, x.id)),
    stable_merge_oracle(xs, ys),
  )
  let before = comparisons.val
  assert_true(before > 0)
  for prefix in [[-2], [-2, -1], [], [-1], []] {
    let mut left = suffix
    for i = prefix.length() - 1; i >= 0; i = i - 1 {
      let value : MergeItem = { key: prefix[i], id: 1000 + i, comparisons, }
      left = Named(@incr.name_of_int(value.id), Cons(value, left))
    }
    let result = merge.named(@incr.name_of_string("merge"), (left, right))
    let expect = prefix + [ for i in 0..<24 => 100 + i ]
    let before = comparisons.val
    assert_eq(result.force().to_array().map(x => x.key), expect)
    // The first comparison at the named boundary may repeat; the remaining
    // 22 suffix comparisons must come from the existing cached merge tails.
    assert_true(comparisons.val - before <= 1)
  }
  e.dispose()
}
