///|
fn[T : Hash] sequence_level(value : T) -> Int32 {
  let hasher = Hasher()
  hasher.combine(value)
  hasher.combine(1)
  hasher.finalize().reinterpret_as_uint().ctz() + 1
}

///|
fn[T : Hash + Eq] build_sequence_tree(
  memo : @incr.Memo[(List[T], Tree[T], Int32, Int32), (Tree[T], List[T])],
  cells : @incr.Cells[Tree[T]],
  input : List[T],
  tree : Tree[T],
  tree_level : Int32,
  parent_level : Int32,
  reverse : Bool,
) -> (Tree[T], List[T]) {
  match input {
    Nil => (tree, Nil)
    Art(art) =>
      build_sequence_tree(
        memo,
        cells,
        art.force(),
        tree,
        tree_level,
        parent_level,
        reverse,
      )
    Cons(head, tail) => {
      let level = sequence_level(head)
      if tree_level <= level && level <= parent_level {
        let (next, rest) = build_sequence_tree(
          memo,
          cells,
          tail,
          Leaf(head),
          0,
          level,
          reverse,
        )
        let combined : Tree[T] = if reverse {
          Bin(level, next, tree)
        } else {
          Bin(level, tree, next)
        }
        build_sequence_tree(
          memo, cells, rest, combined, level, parent_level, reverse,
        )
      } else {
        (tree, input)
      }
    }
    Named(name, tail) => {
      // Names sit above element levels and determine stable edit boundaries.
      let level = 32 + sequence_level(name)
      if tree_level <= level && level <= parent_level {
        let (a, b) = @incr.name_fork(name)
        let (next, rest) = memo.named(a, (tail, Nil, 0, level)).force()
        let combined : Tree[T] = if reverse {
          Named(name, level, next, tree)
        } else {
          Named(name, level, tree, next)
        }
        let articulated = Tree::Art(cells.cell(name, combined))
        memo.named(b, (rest, articulated, level, parent_level)).force()
      } else {
        (tree, input)
      }
    }
  }
}

///|
/// Convert a named list into a hash-level tree while reusing named regions after
/// insertions and deletions. Preserve the table between versions of the list.
/// `reverse=true` reverses leaf order. Shape uses MoonBit's 32-bit hash function.
pub fn[T : Hash + Eq] tree_of_list(
  engine : @incr.Engine,
  reverse~ : Bool = false,
) -> @incr.Memo[List[T], Tree[T]] {
  let cells = @incr.Cells(engine)
  let worker = @incr.Memo::recursive(engine, (memo, args) => {
    build_sequence_tree(memo, cells, args.0, args.1, args.2, args.3, reverse)
  })
  Memo(engine, input => {
    let (tree, rest) = build_sequence_tree(
      worker,
      cells,
      input,
      Nil,
      0,
      0x7fffffff,
      reverse,
    )
    guard rest.is_empty() else {
      abort("incomplete sequence tree construction")
    }
    tree
  })
}
