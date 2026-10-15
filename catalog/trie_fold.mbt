///|
fn[T : Eq, R : Eq] fold_trie(
  memo : @incr.Memo[(Trie[T], R), R],
  tree : Trie[T],
  initial : R,
  body : (T, R) -> R,
) -> R {
  match tree.root {
    Empty => initial
    Bucket(_, values) => values.fold(init=initial, (r, x) => body(x, r))
    Branch(_, left, right) => {
      let result = fold_trie(memo, left, initial, body)
      fold_trie(memo, right, result, body)
    }
    Named(name, child) => memo.named(name, (child, initial)).force()
    Art(art) => fold_trie(memo, art.force(), initial, body)
  }
}

///|
/// Sequential trie fold, memoized at name boundaries with the accumulator as
/// part of each memoized call's argument, as in the reference's trie_fold.
pub fn[T : Eq, R : Eq] trie_fold(
  engine : @incr.Engine,
  body : (T, R) -> R,
) -> @incr.Memo[(Trie[T], R), R] {
  @incr.Memo::recursive(engine, (memo, arg) => {
    fold_trie(memo, arg.0, arg.1, body)
  })
}
