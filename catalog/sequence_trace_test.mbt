///|
fn sequence_random(state : Ref[Int32]) -> Int32 {
  state.val = (state.val * 1664525 + 1013904223) & 0x7fffffff
  state.val
}

///|
fn sequence_input(
  cells : @incr.Cells[@catalog.List[Int32]],
  entries : Array[(Int32, Int32)],
  layout : Int32,
) -> @catalog.List[Int32] {
  let mut tail : @catalog.List[Int32] = Named(@incr.name_of_string("end"), Nil)
  for i = entries.length() - 1; i >= 0; i = i - 1 {
    let (id, value) = entries[i]
    let name = @incr.name_of_int(id)
    tail = match layout {
      0 => Named(name, Cons(value, tail))
      1 => Named(name, Art(cells.cell(name, Cons(value, tail))))
      _ => Cons(value, Named(name, Art(cells.cell(name, tail))))
    }
  }
  Named(@incr.name_of_string("start"), tail)
}

///|
fn sequence_events(list : @catalog.List[Int32]) -> Array[String] {
  let output = []
  for rest = list {
    match rest {
      Nil => break output
      Cons(x, tail) => {
        output.push("v\{x}")
        continue tail
      }
      Named(n, tail) => {
        output.push("n\{Repr(n)}")
        continue tail
      }
      Art(a) => continue a.force()
    }
  }
}

///|
test "generated sequence insert delete replace and move traces preserve all directions" {
  for layout in 0..<3 {
    for seed in [1, 31, 771] {
      let e = @incr.Engine::new()
      let cells = @incr.Cells::new(e)
      let input = e.cell(@catalog.List::Nil)
      let builds = [
        @catalog.tree_of_list(e),
        @catalog.tree_of_list(e, reverse=true),
      ]
      let trees = builds.map(b => {
        b.named(@incr.name_of_string("build"), Art(input))
      })
      let outputs = trees.map(t => {
        let a = @catalog.list_of_tree(e)
        let b = @catalog.list_of_tree(e, reverse=true)
        (
          a.named(@incr.name_of_string("roundtrip"), Art(t)),
          b.named(@incr.name_of_string("reverse"), Art(t)),
        )
      })
      let folds = trees.map(t => {
        let a = @catalog.tree_fold_seq(
          e,
          leaf=(x : Int32, a : String) => a + ",\{x}",
          bin=(_, a) => a,
          name=(_, _, a) => a,
        )
        let b = @catalog.tree_fold_seq(
          e,
          reverse=true,
          leaf=(x : Int32, a : String) => a + ",\{x}",
          bin=(_, a) => a,
          name=(_, _, a) => a,
        )
        (
          a.named(@incr.name_of_string("forward"), (Art(t), "")),
          b.named(@incr.name_of_string("backward"), (Art(t), "")),
        )
      })
      let sorts = trees.map(t => {
        @catalog.mergesort_list_of_tree(e).named(
          @incr.name_of_string("sort"),
          Art(t),
        )
      })
      let random = Ref(seed)
      let mut entries : Array[(Int32, Int32)] = []
      let mut next_id = 0
      for step in 0..<350 {
        let op = sequence_random(random) % 5
        if entries.is_empty() || (op < 2 && entries.length() < 40) {
          let at = sequence_random(random) % (entries.length() + 1)
          let item = (next_id, sequence_random(random) % 11 - 5)
          next_id += 1
          entries = entries[:at].to_owned() + [item] + entries[at:].to_owned()
        } else {
          let at = sequence_random(random) % entries.length()
          if op == 2 {
            entries = entries[:at].to_owned() + entries[at + 1:].to_owned()
          } else if op == 3 {
            entries[at] = (entries[at].0, sequence_random(random) % 11 - 5)
          } else {
            let to = sequence_random(random) % entries.length()
            let temp = entries[at]
            entries[at] = entries[to]
            entries[to] = temp
          }
        }
        let list = sequence_input(cells, entries, layout)
        input.set(list)
        let values = entries.map(x => x.1)
        let events = sequence_events(list)
        let ordered = values.copy()
        ordered.sort()
        for i in 0..<2 {
          let expected = if i == 0 { values } else { values.rev() }
          let expect_events = if i == 0 { events } else { events.rev() }
          // Demand a downstream consumer before warming the constructor directly.
          assert_eq(
            sorts[i].force().to_array(limit=2),
            ordered[:Int32::min(2, ordered.length())].to_owned(),
          )
          assert_eq(outputs[i].0.force().to_array(), expected)
          assert_eq(outputs[i].1.force().to_array(), expected.rev())
          assert_eq(sequence_events(outputs[i].0.force()), expect_events)
          assert_eq(sequence_events(outputs[i].1.force()), expect_events.rev())
          assert_eq(trees[i].force().to_array(), expected)
          assert_eq(
            folds[i].0.force(),
            expected.fold(init="", (a, x) => a + ",\{x}"),
          )
          assert_eq(
            folds[i].1.force(),
            expected.rev().fold(init="", (a, x) => a + ",\{x}"),
          )
          if step % 3 == 0 {
            assert_eq(sorts[i].force().to_array(), ordered)
          }
        }
      }
      e.dispose()
    }
  }
}

///|
test "reverse sequential fold reuses unaffected traversal prefix" {
  let e = @incr.Engine::new()
  let left = e.cell(@catalog.Tree::from_array([1, 2]))
  let right = e.cell(@catalog.Tree::from_array([3, 4]))
  let tree : @catalog.Tree[Int32] = Named(
    @incr.name_of_string("split"),
    2,
    Art(left),
    Art(right),
  )
  let visits = Ref(0)
  let fold = @catalog.tree_fold_seq(
    e,
    reverse=true,
    leaf=(x, acc : String) => {
      visits.val += 1
      acc + ",\{x}"
    },
    bin=(_, a) => a,
    name=(_, _, a) => a,
  )
  let result = fold.named(@incr.name_of_string("fold"), (tree, ""))
  assert_eq(result.force(), ",4,3,2,1")
  assert_eq(visits.val, 4)
  left.set(@catalog.Tree::from_array([1, 9, 2]))
  assert_eq(result.force(), ",4,3,2,9,1")
  assert_eq(visits.val, 7)
  left.set(@catalog.Tree::from_array([2]))
  assert_eq(result.force(), ",4,3,2")
  assert_eq(visits.val, 8)
  e.dispose()
}

///|
test "inverse conversion reuses unaffected named tail identity" {
  for reverse in [false, true] {
    let e = @incr.Engine::new()
    let left = e.cell(@catalog.Tree::from_array([1, 2]))
    let right = e.cell(@catalog.Tree::from_array([3, 4]))
    let tree : @catalog.Tree[Int32] = Named(
      @incr.name_of_string("split"),
      2,
      Art(left),
      Art(right),
    )
    let convert = @catalog.list_of_tree(e, reverse~)
    let output = convert.named(@incr.name_of_string("inverse"), tree)
    let mut first = output.force()
    while first is Cons(_, tail) {
      first = tail
    }
    let tail_art = match first {
      Named(_, Art(a)) => a
      _ => abort("missing expected named articulation")
    }
    assert_eq(
      tail_art.force().to_array(),
      if reverse {
        [2, 1]
      } else {
        [3, 4]
      },
    )
    let changed = if reverse { right } else { left }
    let suffix = if reverse { [2, 1] } else { [3, 4] }
    for values in [[7, 8, 9], [6], [], [2, 2]] {
      changed.set(@catalog.Tree::from_array(values))
      let expected = (if reverse { values.rev() } else { values }) + suffix
      let current = output.force()
      assert_eq(current.to_array(), expected)
      let mut marker = current
      while marker is Cons(_, tail) {
        marker = tail
      }
      match marker {
        Named(_, Art(a)) => assert_true(a == tail_art)
        _ => abort("missing reused articulation")
      }
    }
    e.dispose()
  }
}
