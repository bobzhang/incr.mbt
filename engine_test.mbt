///|
test "cells constants and lazy caches" {
  let e = @incr.Engine::new()
  let input = e.cell(21)
  let calls = Ref(0)
  let result = e.thunk(() => {
    calls.val += 1
    input.force() * 2
  })
  assert_eq(calls.val, 0)
  assert_eq(result.force(), 42)
  assert_eq(result.force(), 42)
  assert_eq(calls.val, 1)
  input.set(21)
  assert_eq(result.force(), 42)
  assert_eq(calls.val, 1)
  input.set(30)
  assert_eq(calls.val, 1)
  assert_eq(result.force(), 60)
  assert_eq(calls.val, 2)
  assert_eq(e.put("constant").force(), "constant")
}

///|
test "upstream avoid divide by zero" {
  let e = @incr.Engine::new()
  let num = e.cell(42)
  let den = e.cell(2)
  let div = e.thunk(() => num.force() / den.force())
  let check = e.thunk(() => {
    if den.force() == 0 {
      None
    } else {
      Some(div.force())
    }
  })
  assert_eq(check.force(), Some(21))
  den.set(0)
  assert_eq(check.force(), None)
  den.set(2)
  assert_eq(check.force(), Some(21))
}

///|
test "upstream avoid expensive subcomputation and remove obsolete edges" {
  let e = @incr.Engine::new()
  let flag = e.cell(true)
  let iterations = e.cell(3)
  let input = e.cell(42)
  let calls = Ref(0)
  let expensive = e.thunk(() => {
    calls.val += 1
    let n = iterations.force()
    guard n < 100 else { abort("undemanded branch executed") }
    input.force() * n
  })
  let root = e.thunk(() => {
    if flag.force() {
      expensive.force()
    } else {
      input.force()
    }
  })
  assert_eq(root.force(), 126)
  flag.set(false)
  iterations.set(999999999)
  assert_eq(root.force(), 42)
  assert_eq(calls.val, 1)
  let before = e.stats().evaluations
  iterations.set(2)
  assert_eq(root.force(), 42)
  assert_eq(e.stats().evaluations, before)
  flag.set(true)
  assert_eq(root.force(), 84)
}

///|
test "equal intermediate output cleans parent without rerunning" {
  let e = @incr.Engine::new()
  let x = e.cell(2)
  let parity = x.map(x => x % 2)
  let root = parity.map(x => x == 0)
  assert_eq(root.force(), true)
  let before = e.stats().evaluations
  x.set(4)
  assert_eq(root.force(), true)
  assert_eq(e.stats().evaluations - before, 1)
  x.set(5)
  assert_eq(root.force(), false)
}

///|
test "upstream force_map prunes dirty traversal" {
  let e = @incr.Engine::new()
  let pair = e.cell((1234, 5678))
  let first = e.thunk(() => pair.force_map(p => p.0) + 100)
  assert_eq(first.force(), 1334)
  let before = e.stats()
  pair.set((1234, 8765))
  assert_eq(first.force(), 1334)
  assert_eq(e.stats().dirtyings, before.dirtyings)
  assert_eq(e.stats().evaluations, before.evaluations)
  pair.set((12, 8765))
  assert_eq(first.force(), 112)
}

///|
test "diamond dependencies and repeated observations" {
  let e = @incr.Engine::new()
  let x = e.cell(1)
  let a = x.map(x => x + 10)
  let b = x.map(x => x * 10)
  let c = e.thunk(() => a.force() + b.force() + a.force())
  assert_eq(c.force(), 32)
  x.set(2)
  assert_eq(c.force(), 44)
  assert_eq(e.stats().evaluations, 6)
}

///|
test "cycle fallback" {
  let e = @incr.Engine::new()
  let link : Ref[@incr.Art[Int32]?] = Ref(None)
  let value = e.cell(2)
  let cycle = e.thunk(() => {
    value.force() + link.val.unwrap().force_cycle(Some(0))
  })
  link.val = Some(cycle)
  assert_eq(cycle.force(), 2)
  value.set(3)
  assert_eq(cycle.force(), 3)
}

///|
test "panic unexpected cycle" {
  let e = @incr.Engine::new()
  let link : Ref[@incr.Art[Int32]?] = Ref(None)
  let cycle = e.thunk(() => link.val.unwrap().force())
  link.val = Some(cycle)
  ignore(cycle.force())
}

///|
test "panic set during computation" {
  let e = @incr.Engine::new()
  let x = e.cell(0)
  ignore(
    e
    .thunk(() => {
      x.set(1)
      x.force()
    })
    .force(),
  )
}

///|
test "panic cross engine dependency" {
  let a = @incr.Engine::new()
  let b = @incr.Engine::new()
  let input = a.cell(42)
  ignore(b.thunk(() => input.force()).force())
}

///|
test "panic immutable update" {
  @incr.Engine::new().put(1).set(2)
}
