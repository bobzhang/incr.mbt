///|
fn[T : Eq, R : Eq] fold_tree_seq(
  memo : @incr.Memo[(Tree[T], R), R],
  tree : Tree[T],
  initial : R,
  reverse : Bool,
  leaf : (T, R) -> R,
  bin : (Int32, R) -> R,
  name : (@incr.Name, Int32, R) -> R,
) -> R {
  match tree {
    Nil => initial
    Leaf(x) => leaf(x, initial)
    Bin(level, left, right) => {
      let (first, second) = if reverse { (right, left) } else { (left, right) }
      let acc = fold_tree_seq(memo, first, initial, reverse, leaf, bin, name)
      let acc = bin(level, acc)
      fold_tree_seq(memo, second, acc, reverse, leaf, bin, name)
    }
    Named(n, level, left, right) => {
      let (first, second) = if reverse { (right, left) } else { (left, right) }
      let (a, b) = @incr.name_fork(n)
      let acc = memo.named(a, (first, initial)).force()
      let acc = name(n, level, acc)
      memo.named(b, (second, acc)).force()
    }
    Art(art) =>
      fold_tree_seq(memo, art.force(), initial, reverse, leaf, bin, name)
  }
}

///|
/// Fold in tree traversal order, memoizing each named subtree together with its
/// incoming accumulator. `reverse=true` visits the right subtree first.
pub fn[T : Eq, R : Eq] tree_fold_seq(
  engine : @incr.Engine,
  reverse~ : Bool = false,
  leaf~ : (T, R) -> R,
  bin~ : (Int32, R) -> R,
  name~ : (@incr.Name, Int32, R) -> R,
) -> @incr.Memo[(Tree[T], R), R] {
  @incr.Memo::recursive(engine, (memo, args) => {
    fold_tree_seq(memo, args.0, args.1, reverse, leaf, bin, name)
  })
}

///|
/// Convert a tree back into a named articulated list using incremental sequential
/// folding. `reverse=true` returns leaves in right-to-left order.
pub fn[T : Eq] list_of_tree(
  engine : @incr.Engine,
  reverse~ : Bool = false,
) -> @incr.Memo[Tree[T], List[T]] {
  let cells = @incr.Cells(engine)
  let leaf = (x, tail) => List::Cons(x, tail)
  let bin = (_, tail) => tail
  let name = (name, _, tail) => List::Named(name, Art(cells.cell(name, tail)))
  let worker = tree_fold_seq(engine, reverse=!reverse, leaf~, bin~, name~)
  Memo(engine, tree => {
    fold_tree_seq(worker, tree, Nil, !reverse, leaf, bin, name)
  })
}
