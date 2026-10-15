///|
/// Persistent trees. Levels are preserved for applications that build treaps.
pub(all) enum Tree[T] {
  Nil
  Leaf(T)
  Bin(Int32, Tree[T], Tree[T])
  Named(@incr.Name, Int32, Tree[T], Tree[T])
  Art(@incr.Art[Tree[T]])
} derive(Eq, Hash, Debug)

///|
pub extend Tree with Eq::{equal, not_equal}

///|
pub extend Tree with Hash::{hash, hash_combine}

///|
pub extend Tree with Debug::{to_repr}

///|
/// Build a balanced immutable tree. Names can be added explicitly at edit boundaries.
pub fn[T] Tree::from_array(values : ArrayView[T]) -> Tree[T] {
  fn build(start : Int32, end : Int32) -> (Tree[T], Int32) {
    if start == end {
      (Nil, 0)
    } else if end - start == 1 {
      (Leaf(values[start]), 0)
    } else {
      let middle = start + (end - start) / 2
      let (left, ll) = build(start, middle)
      let (right, rl) = build(middle, end)
      let level = (if ll > rl { ll } else { rl }) + 1
      (Bin(level, left, right), level)
    }
  }
  build(0, values.length()).0
}

///|
/// Demand the leaves from left to right (or right to left with `reverse=true`).
pub fn[T : Eq] Tree::to_array(
  self : Tree[T],
  reverse~ : Bool = false,
) -> Array[T] {
  let result = []
  let pending = [self]
  while pending.pop() is Some(tree) {
    match tree {
      Nil => ()
      Leaf(value) => result.push(value)
      Bin(_, left, right) | Named(_, _, left, right) =>
        if reverse {
          pending.push(left)
          pending.push(right)
        } else {
          pending.push(right)
          pending.push(left)
        }
      Art(art) => pending.push(art.force())
    }
  }
  result
}

///|
/// Convert a tree to a list, preserving in-order name boundaries.
pub fn[T : Eq] Tree::to_list(self : Tree[T]) -> List[T] {
  fn walk(tree : Tree[T], tail : List[T]) -> List[T] {
    match tree {
      Nil => tail
      Leaf(x) => Cons(x, tail)
      Bin(_, left, right) => walk(left, walk(right, tail))
      Named(name, _, left, right) => walk(left, Named(name, walk(right, tail)))
      Art(art) => walk(art.force(), tail)
    }
  }
  walk(self, Nil)
}
