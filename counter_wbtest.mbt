///|
test "edge identities cross the 32-bit wrap boundary without losing observers" {
  let e = Engine::new()
  let input = e.cell(1)
  let old = e.thunk(() => input.force())
  assert_eq(old.force(), 1)
  // The previous Int32 implementation reached -1 then reused edge 0 here.
  e.next_edge = 4294967295L
  let before_boundary = e.thunk(() => input.force())
  let after_boundary = e.thunk(() => input.force())
  assert_eq(before_boundary.force(), 1)
  assert_eq(after_boundary.force(), 1)
  assert_eq(input.node.users.length(), 3)
  input.set(2)
  assert_eq(old.force(), 2)
  assert_eq(before_boundary.force(), 2)
  assert_eq(after_boundary.force(), 2)
  e.dispose()
}

///|
test "engine identities cross the signed 32-bit boundary" {
  next_engine.protect(2147483647L, () => {
    let a = Engine::new()
    let b = Engine::new()
    let first = a.cell(1)
    let second = b.cell(1)
    assert_true(first != second)
    assert_eq(a.id, 2147483647L)
    assert_eq(b.id, 2147483648L)
    a.dispose()
    b.dispose()
  })
}

///|
test "event counters stay nonnegative and saturate instead of wrapping" {
  let e = Engine::new()
  let input = e.cell(1)
  let output = e.thunk(() => input.force())
  e.evaluations = 2147483647L
  assert_eq(output.force(), 1)
  assert_eq(e.stats().evaluations, 2147483648L)
  e.evaluations = COUNTER_MAX
  e.cache_hits = COUNTER_MAX
  e.dirtyings = COUNTER_MAX
  e.cleanings = COUNTER_MAX
  assert_eq(output.force(), 1)
  input.set(2)
  assert_eq(output.force(), 2)
  assert_eq(e.stats().evaluations, COUNTER_MAX)
  assert_eq(e.stats().cache_hits, COUNTER_MAX)
  assert_eq(e.stats().dirtyings, COUNTER_MAX)
  assert_eq(e.stats().cleanings, COUNTER_MAX)
  e.dispose()
}

///|
test "panic exhausted dependency identity space fails before aliasing" {
  let e = Engine::new()
  let input = e.cell(1)
  let output = e.thunk(() => input.force())
  e.next_edge = COUNTER_MAX
  ignore(output.force())
}

///|
test "high 64-bit edge identities do not alias" {
  for
    start in [2147483646L, 4294967294L, 9007199254740990L, 9223372036854775804L] {
    let e = Engine::new()
    let x = e.cell(1)
    let old = e.thunk(() => x.force())
    assert_eq(old.force(), 1)
    e.next_edge = start
    let a = e.thunk(() => x.force())
    let b = e.thunk(() => x.force())
    assert_eq(a.force(), 1)
    assert_eq(b.force(), 1)
    assert_eq(x.node.users.length(), 3)
    // Move away from exhaustion before further observations are allocated.
    if start > 9007199254740990L {
      e.next_edge = 10L
    }
    x.set(2)
    assert_eq(old.force(), 2)
    assert_eq(a.force(), 2)
    assert_eq(b.force(), 2)
    e.dispose()
  }
}

///|
test "event counters reach and remain at maximum" {
  let e = Engine::new()
  let x = e.cell(1)
  let out = e.thunk(() => x.force())
  ignore(out.force())
  e.evaluations = COUNTER_MAX - 1L
  e.cache_hits = COUNTER_MAX - 1L
  e.cleanings = COUNTER_MAX - 1L
  e.dirtyings = COUNTER_MAX - 1L
  ignore(out.force())
  x.set(2)
  assert_eq(out.force(), 2)
  assert_eq(e.evaluations, COUNTER_MAX)
  assert_eq(e.cache_hits, COUNTER_MAX)
  assert_eq(e.cleanings, COUNTER_MAX)
  assert_eq(e.dirtyings, COUNTER_MAX)
  x.set(3)
  assert_eq(out.force(), 3)
  ignore(out.force())
  assert_eq(e.evaluations, COUNTER_MAX)
  assert_eq(e.cache_hits, COUNTER_MAX)
  assert_eq(e.cleanings, COUNTER_MAX)
  assert_eq(e.dirtyings, COUNTER_MAX)
  e.dispose()
}

///|
test "engine IDs preserve low and high bits" {
  for start in [4294967295L, 9007199254740991L, COUNTER_MAX - 2L] {
    next_engine.protect(start, () => {
      let a = Engine::new()
      let b = Engine::new()
      let x = a.cell(1)
      let y = b.cell(1)
      assert_true(x != y)
      assert_eq(a.id, start)
      assert_eq(b.id, start + 1L)
      a.dispose()
      b.dispose()
    })
  }
}
