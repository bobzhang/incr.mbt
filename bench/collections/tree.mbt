///|
fn make_tree(
  e : @incr.Engine,
  lo : Int32,
  hi : Int32,
  id : Int32,
  leaves : Array[@incr.Art[@catalog.Tree[Int32]]],
) -> @catalog.Tree[Int32] {
  if hi - lo == 1 {
    let cell = e.cell(@catalog.Tree::Leaf(initial_value(lo)))
    leaves.push(cell)
    Art(cell)
  } else {
    let mid = (lo + hi) / 2
    let left = make_tree(e, lo, mid, id * 2, leaves)
    let right = make_tree(e, mid, hi, id * 2 + 1, leaves)
    // Articulate every branch, bounding structural equality/cloning costs.
    Art(e.cell(Named(@incr.name_of_int(id), 1, left, right)))
  }
}

///|
fn tree_workload(
  mode : String,
  n : Int32,
  edits : Int32,
  verify : Bool,
) -> Int64 {
  let e = @incr.Engine()
  let leaves = []
  let tree = make_tree(e, 0, n, 1, leaves)
  let demand : () -> Array[Int32] = if mode == "sum" {
    let fold = @catalog.monoid_of_tree(e, 0, x => x, (a, b) => a + b)
    let result = fold.named(@incr.name_of_string("root"), tree)
    () => [result.force()]
  } else {
    let sort = @catalog.mergesort_list_of_tree(e)
    let result = sort.named(@incr.name_of_string("root"), tree)
    let limit = if mode == "sort_prefix" { 32 } else { n }
    () => result.force().to_array(limit~)
  }
  let mut checksum = consume(demand(), verify)
  for step in 0..<edits {
    leaves[edit_index(step, n)].set(Leaf(edit_value(step)))
    checksum += consume(demand(), verify)
  }
  e.dispose()
  checksum
}
