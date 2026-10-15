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
