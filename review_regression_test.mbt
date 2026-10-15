///|
test "upstream four-node cycle traversal" {
  let e = @incr.Engine::new()
  let memo = @incr.Memo::recursive(e, (memo, n : Int32) => {
    let (a, b) = match n {
      0 => (1, 0)
      1 => (2, 3)
      2 => (3, 0)
      _ => (3, 1)
    }
    let at = memo.named(@incr.name_of_int(a), a)
    let bt = memo.named(@incr.name_of_int(b), b)
    [n] + at.force_cycle(Some([])) + bt.force_cycle(Some([]))
  })
  assert_eq(memo.named(@incr.name_of_int(0), 0).force(), [0, 1, 2, 3, 3])
  e.dispose()
}

///|
test "equal projection remains stable across other named writes" {
  let e = @incr.Engine::new()
  let cells = @incr.Cells::new(e)
  let name = @incr.name_unit()
  let pair = cells.cell(name, (1, 2))
  let parent = e.thunk(() => {
    let first = pair.force_map(p => p.0)
    ignore(cells.cell(name, (1, 3)))
    first
  })
  assert_eq(parent.force(), 1)
  e.dispose()
}

///|
test "projected thunk output avoids parent rerun" {
  let e = @incr.Engine::new()
  let x = e.cell((1, 2))
  let child = e.thunk(() => x.force())
  let parent = e.thunk(() => child.force_map(p => p.0))
  assert_eq(parent.force(), 1)
  let before = e.stats().evaluations
  x.set((1, 3))
  assert_eq(parent.force(), 1)
  assert_eq(e.stats().evaluations, before + 1)
  e.dispose()
}
