///|
/// Persistent lists with named memoization boundaries and incremental tails.
pub(all) enum List[T] {
  Nil
  Cons(T, List[T])
  Named(@incr.Name, List[T])
  Art(@incr.Art[List[T]])
} derive(Eq, Hash, Debug)

///|
pub extend List with Eq::{equal, not_equal}

///|
pub extend List with Hash::{hash, hash_combine}

///|
pub extend List with Debug::{to_repr}

///|
pub fn[T] List::from_array(values : ArrayView[T]) -> List[T] {
  let mut result : List[T] = Nil
  for i in (values.length() - 1)>=..0 {
    result = Cons(values[i], result)
  }
  result
}

///|
/// Observe at most `limit` elements, or the whole list when omitted.
/// No tail beyond the demanded prefix is forced.
pub fn[T : Eq] List::to_array(self : List[T], limit? : Int32) -> Array[T] {
  let result = []
  let mut rest = self
  while limit is None || result.length() < limit.unwrap() {
    match rest {
      Nil => break
      Cons(value, tail) => {
        result.push(value)
        rest = tail
      }
      Named(_, tail) => rest = tail
      Art(art) => rest = art.force()
    }
  }
  result
}

///|
pub fn[T : Eq] List::uncons(self : List[T]) -> (T, List[T])? {
  for rest = self {
    match rest {
      Nil => break None
      Cons(value, tail) => break Some((value, tail))
      Named(_, tail) => continue tail
      Art(art) => continue art.force()
    }
  }
}

///|
pub fn[T : Eq] List::is_empty(self : List[T]) -> Bool {
  self.uncons() is None
}

///|
/// Nonmemoized right fold, matching the reference's list_fold order.
pub fn[T : Eq, R] List::fold(
  self : List[T],
  initial : R,
  body : (T, R) -> R,
) -> R {
  let values = self.to_array()
  let mut result = initial
  for i in (values.length() - 1)>=..0 {
    result = body(values[i], result)
  }
  result
}

///|
pub fn[T : Eq] List::reverse(self : List[T]) -> List[T] {
  let mut result : List[T] = Nil
  let mut rest = self
  while rest.uncons() is Some((head, tail)) {
    result = Cons(head, result)
    rest = tail
  }
  result
}

///|
pub fn[T : Eq] List::append(self : List[T], other : List[T]) -> List[T] {
  self.fold(other, (x, tail) => Cons(x, tail))
}
