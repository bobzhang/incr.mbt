///|
fn[T] with_name(name : @incr.Name?, list : List[T]) -> List[T] {
  match name {
    None => list
    Some(name) => Named(name, list)
  }
}

///|
fn[T : Eq + Compare] merge_lists(
  memo : @incr.Memo[(@incr.Name?, List[T], @incr.Name?, List[T]), List[T]],
  left_name : @incr.Name?,
  left : List[T],
  right_name : @incr.Name?,
  right : List[T],
) -> List[T] {
  match left {
    Nil => with_name(right_name, right)
    Named(name, tail) => merge_lists(memo, Some(name), tail, right_name, right)
    Art(art) => merge_lists(memo, left_name, art.force(), right_name, right)
    Cons(a, atail) =>
      match right {
        Nil => with_name(left_name, left)
        Named(name, tail) =>
          merge_lists(memo, left_name, left, Some(name), tail)
        Art(art) => merge_lists(memo, left_name, left, right_name, art.force())
        Cons(b, btail) =>
          if a <= b {
            match left_name {
              None => Cons(a, merge_lists(memo, None, atail, right_name, right))
              Some(name) => {
                let (call_name, output_name) = @incr.name_fork(name)
                let tail = memo.named(
                  call_name,
                  (None, atail, right_name, right),
                )
                Named(output_name, Cons(a, Art(tail)))
              }
            }
          } else {
            match right_name {
              None => Cons(b, merge_lists(memo, left_name, left, None, btail))
              Some(name) => {
                let (call_name, output_name) = @incr.name_fork(name)
                let tail = memo.named(call_name, (left_name, left, None, btail))
                Named(output_name, Cons(b, Art(tail)))
              }
            }
          }
      }
  }
}

///|
fn[T : Eq + Compare] merge_table(
  engine : @incr.Engine,
) -> @incr.Memo[(@incr.Name?, List[T], @incr.Name?, List[T]), List[T]] {
  @incr.Memo::recursive(engine, (memo, args) => {
    merge_lists(memo, args.0, args.1, args.2, args.3)
  })
}

///|
/// Create a reusable stable merge of two sorted lists. Names suspend merge
/// tails, so demanding a prefix does not evaluate the remainder of the merge.
pub fn[T : Eq + Compare] list_merge(
  engine : @incr.Engine,
) -> @incr.Memo[(List[T], List[T]), List[T]] {
  let memo = merge_table(engine)
  @incr.Memo::new(engine, args => merge_lists(memo, None, args.0, None, args.1))
}

///|
/// Merge sorted lists lazily at named boundaries. Use `list_merge` to retain
/// one memo table across successive merges. The engine must own all input arts.
pub fn[T : Eq + Compare] List::merge(
  self : List[T],
  other : List[T],
  engine~ : @incr.Engine,
) -> List[T] {
  merge_lists(merge_table(engine), None, self, None, other)
}
