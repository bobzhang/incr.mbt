///|
test "named cells retain identity and update observers" {
  let e = @incr.Engine()
  let cells = @incr.Cells(e)
  let name = @incr.name_of_string("input")
  let a = cells.cell(name, 2)
  let result = a.map(x => x * 10)
  assert_eq(result.force(), 20)
  assert_true(a == cells.cell(name, 3))
  assert_eq(result.force(), 30)
  let others = @incr.Cells(e)
  assert_true(a != others.cell(name, 3))
}

///|
test "named memo reuses equal arguments and replaces different arguments" {
  let e = @incr.Engine()
  let calls = Ref(0)
  let memo = @incr.Memo(e, x => {
    calls.val += 1
    x * 2
  })
  let name = @incr.name_unit()
  let a = memo.named(name, 3)
  let root = a.map(x => x + 1)
  assert_eq(root.force(), 7)
  assert_true(a == memo.named(name, 3))
  assert_eq(root.force(), 7)
  assert_eq(calls.val, 1)
  assert_true(a == memo.named(name, 4))
  assert_eq(root.force(), 9)
  assert_eq(calls.val, 2)
}

///|
test "recursive structural memoization" {
  let e = @incr.Engine()
  let fib = @incr.Memo::recursive(e, (memo, n : Int32) => {
    if n < 2 {
      n
    } else {
      memo.call(n - 1) + memo.call(n - 2)
    }
  })
  assert_eq(fib.call(20), 6765)
  assert_eq(e.stats().evaluations, 21)
  assert_eq(fib.call(19), 4181)
  assert_eq(e.stats().evaluations, 21)
}

///|
test "namespace is restored and retained by suspended computations" {
  let e = @incr.Engine()
  let cells = @incr.Cells(e)
  let local_name = @incr.name_of_string("local_name")
  let a = @incr.name_of_string("a")
  let b = @incr.name_of_string("b")
  let x = cells.cell(local_name, 0)
  let suspended = e.ns(a, () => e.thunk(() => cells.cell(local_name, 42)))
  let y = e.ns(b, () => suspended.force())
  assert_true(x != y)
  assert_true(y == e.ns(a, () => cells.cell(local_name, 42)))
  assert_true(x == cells.cell(local_name, 0))
  assert_eq(y.force(), 42)
}

///|
test "cell allocation dependencies restore overwritten output" {
  let e = @incr.Engine()
  let cells = @incr.Cells(e)
  let name = @incr.name_unit()
  let input = e.cell(1)
  let producer = e.thunk(() => cells.cell(name, input.force() * 10))
  let output = producer.force()
  assert_eq(output.force(), 10)
  output.set(99)
  assert_true(producer.force() == output)
  assert_eq(output.force(), 10)
  input.set(2)
  assert_eq(producer.force().force(), 20)
}

///|
test "thunk allocation dependencies restore overwritten arguments" {
  let e = @incr.Engine()
  let memo = @incr.Memo(e, x => x * 2)
  let name = @incr.name_unit()
  let producer = e.thunk(() => memo.named(name, 5))
  let output = producer.force()
  assert_eq(output.force(), 10)
  ignore(memo.named(name, 99))
  assert_eq(output.force(), 198)
  assert_true(producer.force() == output)
  assert_eq(output.force(), 10)
}

///|
test "interned values and namespaces" {
  let e = @incr.Engine()
  let cells = @incr.Cells(e)
  let a = cells.intern("hello")
  assert_true(a == cells.intern("hello"))
  assert_true(a != cells.intern("other"))
  let b = e.ns(@incr.name_unit(), () => cells.intern("hello"))
  assert_true(a != b)
  assert_eq(a.force(), b.force())
}

///|
test "panic conflicting name invalidates an active observer" {
  let e = @incr.Engine()
  let cells = @incr.Cells(e)
  let name = @incr.name_unit()
  let input = cells.cell(name, 0)
  let root = e.thunk(() => {
    let old = input.force()
    ignore(cells.cell(name, 1))
    old
  })
  ignore(root.force())
}

///|
test "cleaning may update a cell observed by its validating parent" {
  let e = @incr.Engine()
  let cells = @incr.Cells(e)
  let input = e.cell(1)
  let producer = e.thunk(() => cells.cell(@incr.name_unit(), input.force() * 10))
  let root = e.thunk(() => producer.force().force())
  assert_eq(root.force(), 10)
  input.set(2)
  assert_eq(root.force(), 20)
}

///|
test "review allocation-only edge must not observe result changes" {
  let e = @incr.Engine()
  let cells = @incr.Cells(e)
  let cell_name = @incr.name_of_string("input")
  let x = cells.cell(cell_name, 0)
  let memo = @incr.Memo(e, (_ : Unit) => x.force())
  let thunk_name = @incr.name_of_string("child")
  assert_eq(memo.named(thunk_name, ()).force(), 0)
  let parent = e.thunk(() => {
    let child = memo.named(thunk_name, ())
    ignore(cells.cell(cell_name, 1))
    child.force()
  })
  assert_eq(parent.force(), 1)
}

///|
test "result edits leave allocation-only parents clean but argument edits invalidate them" {
  let e = @incr.Engine()
  let input = e.cell(1)
  let memo = @incr.Memo(e, (x : Int32) => x + input.force())
  let name = @incr.name_unit()
  let parent = e.thunk(() => memo.named(name, 10))
  let child = parent.force()
  assert_eq(child.force(), 11)
  let before = e.stats().evaluations
  input.set(2)
  assert_true(parent.force() == child)
  assert_eq(e.stats().evaluations, before)
  assert_eq(child.force(), 12)
  ignore(memo.named(name, 20))
  assert_eq(child.force(), 22)
  assert_true(parent.force() == child)
  assert_eq(child.force(), 12)
  e.dispose()
}
