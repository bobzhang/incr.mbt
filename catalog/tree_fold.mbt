///|
fn[T : Eq, R : Eq] fold_tree(
  memo : @incr.Memo[Tree[T], R],
  tree : Tree[T],
  nil : () -> R,
  leaf : (T) -> R,
  bin : (Int32, R, R) -> R,
  name : (@incr.Name, Int32, R, R) -> R,
) -> R {
  match tree {
    Nil => nil()
    Leaf(x) => leaf(x)
    Bin(level, left, right) =>
      bin(
        level,
        fold_tree(memo, left, nil, leaf, bin, name),
        fold_tree(memo, right, nil, leaf, bin, name),
      )
    Named(n, level, left, right) => {
      let (a, b) = @incr.name_fork(n)
      let l = memo.named(a, left).force()
      let r = memo.named(b, right).force()
      name(n, level, l, r)
    }
    Art(art) => fold_tree(memo, art.force(), nil, leaf, bin, name)
  }
}

///|
/// Bottom-up fold with separate memoized left and right subtrees at each name.
/// This ports the reference's tree_fold_up; retain the table between edits.
pub fn[T : Eq, R : Eq] tree_fold_up(
  engine : @incr.Engine,
  nil~ : () -> R,
  leaf~ : (T) -> R,
  bin~ : (Int32, R, R) -> R,
  name~ : (@incr.Name, Int32, R, R) -> R,
) -> @incr.Memo[Tree[T], R] {
  @incr.Memo::recursive(engine, (memo, tree) => {
    fold_tree(memo, tree, nil, leaf, bin, name)
  })
}

///|
/// Incrementally aggregate a tree using an associative operation and identity.
pub fn[T : Eq, R : Eq] monoid_of_tree(
  engine : @incr.Engine,
  identity : R,
  leaf : (T) -> R,
  combine : (R, R) -> R,
) -> @incr.Memo[Tree[T], R] {
  tree_fold_up(
    engine,
    nil=() => identity,
    leaf~,
    bin=(_, l, r) => combine(l, r),
    name=(_, _, l, r) => combine(l, r),
  )
}

///|
/// Incremental merge sort: sorted results are reused at named tree boundaries.
pub fn[T : Eq + Compare] mergesort_list_of_tree(
  engine : @incr.Engine,
) -> @incr.Memo[Tree[T], List[T]] {
  monoid_of_tree(engine, Nil, x => Cons(x, Nil), (l, r) => l.merge(r))
}
