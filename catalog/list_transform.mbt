///|
fn[A : Eq, B] map_list(
  memo : @incr.Memo[List[A], List[B]],
  input : List[A],
  body : (A) -> B,
) -> List[B] {
  match input {
    Nil => Nil
    Cons(head, tail) => Cons(body(head), map_list(memo, tail, body))
    Named(name, tail) => Named(name, Art(memo.named(name, tail)))
    Art(art) => map_list(memo, art.force(), body)
  }
}

///|
/// Create a reusable list mapper. Mapping suspends at each name boundary.
/// Use the same table for successive versions of the input.
pub fn[A : Eq, B] list_map_lazy(
  engine : @incr.Engine,
  body : (A) -> B,
) -> @incr.Memo[List[A], List[B]] {
  @incr.Memo::recursive(engine, (memo, input) => map_list(memo, input, body))
}

///|
fn[T : Eq] filter_list(
  memo : @incr.Memo[List[T], List[T]],
  input : List[T],
  predicate : (T) -> Bool,
) -> List[T] {
  match input {
    Nil => Nil
    Cons(head, tail) =>
      if predicate(head) {
        Cons(head, filter_list(memo, tail, predicate))
      } else {
        filter_list(memo, tail, predicate)
      }
    Named(name, tail) => Named(name, Art(memo.named(name, tail)))
    Art(art) => filter_list(memo, art.force(), predicate)
  }
}

///|
/// Create a reusable list filter with lazy named boundaries.
pub fn[T : Eq] list_filter_lazy(
  engine : @incr.Engine,
  predicate : (T) -> Bool,
) -> @incr.Memo[List[T], List[T]] {
  @incr.Memo::recursive(engine, (memo, input) => {
    filter_list(memo, input, predicate)
  })
}

///|
/// Demand all elements of an articulated list while retaining its names.
pub fn[T : Eq] List::eager(self : List[T]) -> List[T] {
  match self {
    Nil => Nil
    Cons(head, tail) => Cons(head, tail.eager())
    Named(name, tail) => Named(name, tail.eager())
    Art(art) => art.force().eager()
  }
}

///|
/// Stable merge of two sorted lists. Names are preserved around their tails.
pub fn[T : Compare + Eq] List::merge(
  self : List[T],
  other : List[T],
) -> List[T] {
  match (self, other) {
    (Nil, _) => other
    (_, Nil) => self
    (Named(name, tail), _) => Named(name, tail.merge(other))
    (_, Named(name, tail)) => Named(name, self.merge(tail))
    (Art(art), _) => art.force().merge(other)
    (_, Art(art)) => self.merge(art.force())
    (Cons(a, atail), Cons(b, btail)) =>
      if a <= b {
        Cons(a, atail.merge(other))
      } else {
        Cons(b, self.merge(btail))
      }
  }
}
