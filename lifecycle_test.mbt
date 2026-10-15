///|
test "dispose clears graph and is idempotent" {
  let e = @incr.Engine::new()
  let x = e.cell(1)
  let memo = @incr.Memo::recursive(e, (memo, n : Int32) => {
    if n == 0 {
      x.force()
    } else {
      memo.call(n - 1) + 1
    }
  })
  assert_eq(memo.call(5), 6)
  assert_true(e.snapshot().length() > 0)
  e.dispose()
  assert_eq(e.snapshot().length(), 0)
  assert_eq(e.stats().allocated, 0)
  e.dispose()
}

///|
test "panic force after disposal" {
  let e = @incr.Engine::new()
  let x = e.cell(42)
  e.dispose()
  ignore(x.force())
}

///|
test "panic memo allocation after disposal" {
  let e = @incr.Engine::new()
  let memo = @incr.Memo::new(e, (x : Int32) => x)
  e.dispose()
  ignore(memo.structural(42))
}
