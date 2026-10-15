///|
test "disposal releases closures values edges and typed cache entries" {
  let engine = Engine()
  let cells = Cells::new(engine)
  let input = cells.cell(name_unit(), 42)
  let memo = Memo::new(engine, (x : Int32) => input.force() + x)
  let output = memo.named(name_unit(), 1)
  assert_eq(output.force(), 43)
  assert_true(output.node.deps.length() > 0)
  engine.dispose()
  assert_true(input.value is None)
  assert_true(output.value is None)
  assert_true(output.compute is None)
  assert_true(memo.body is None)
  assert_eq(memo.named.length(), 0)
  assert_eq(cells.named.length(), 0)
  assert_eq(output.node.deps.capacity(), 0)
  assert_eq(input.node.users.length(), 0)
  assert_eq(engine.releases.capacity(), 0)
  assert_eq(engine.nodes.capacity(), 0)
}

///|
test "disposal releases map capacity while families and input handles survive" {
  let e = Engine()
  let memo = Memo::new(e, (x : Int32) => x)
  let cells = Cells::new(e)
  let input = e.cell(1)
  let initial = (
    memo.named.capacity(),
    memo.structural.capacity(),
    cells.named.capacity(),
    cells.interned.capacity(),
    input.node.users.capacity(),
  )
  for i in 0..<2048 {
    ignore(memo.named(name_of_int(i), i))
    ignore(memo.structural(i))
    ignore(cells.cell(name_of_int(i), i))
    ignore(cells.intern(i))
    ignore(e.thunk(() => input.force()).force())
  }
  assert_true(memo.named.capacity() > initial.0)
  assert_true(memo.structural.capacity() > initial.1)
  assert_true(cells.named.capacity() > initial.2)
  assert_true(cells.interned.capacity() > initial.3)
  assert_true(input.node.users.capacity() > initial.4)
  e.dispose()
  e.dispose()
  assert_eq(memo.named.capacity(), initial.0)
  assert_eq(memo.structural.capacity(), initial.1)
  assert_eq(cells.named.capacity(), initial.2)
  assert_eq(cells.interned.capacity(), initial.3)
  assert_eq(input.node.users.capacity(), initial.4)
  assert_eq(e.stats().allocated, 0)
}
