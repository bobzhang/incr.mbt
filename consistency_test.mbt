///|
test "incremental and naive engines agree with direct evaluation after edits" {
  for naive in [false, true] {
    let e = @incr.Engine::new(naive~)
    let input = e.cell((0, 1))
    let choose = e.cell(true)
    let left = e.thunk(() => input.force_map(p => p.0) * 3)
    let right = e.thunk(() => input.force_map(p => p.1) * 5)
    let root = e.thunk(() => {
      let answer = if choose.force() { left.force() } else { right.force() }
      (answer, input.force_map(p => p.0 + p.1))
    })
    for i in 0..<300 {
      let a = i * 17 % 23
      let b = i * 7 % 19
      let flag = i % 3 == 0
      input.set((a, b))
      choose.set(flag)
      assert_eq(root.force(), (if flag { a * 3 } else { b * 5 }, a + b))
      assert_eq(root.force(), (if flag { a * 3 } else { b * 5 }, a + b))
    }
  }
}

///|
test "naive mode reruns demanded thunks" {
  let e = @incr.Engine::new(naive=true)
  let x = e.cell(3)
  let y = x.map(x => x * 2)
  assert_eq(y.force(), 6)
  assert_eq(y.force(), 6)
  assert_eq(e.stats().evaluations, 2)
  x.set(4)
  assert_eq(y.force(), 8)
}

///|
struct Collision(Int32) derive(Eq)

///|
impl Hash for Collision with fn hash_combine(_self, hasher) {
  hasher.combine(0)
}

///|
test "structural memo handles hash collisions using equality" {
  let e = @incr.Engine::new()
  let memo = @incr.Memo::new(e, (x : Collision) => x.0 * 2)
  let a = memo.structural(Collision(1))
  let b = memo.structural(Collision(2))
  assert_true(a != b)
  assert_eq(a.force(), 2)
  assert_eq(b.force(), 4)
  assert_true(a == memo.structural(Collision(1)))
}

///|
test "graph snapshots detach obsolete dependencies" {
  let e = @incr.Engine::new()
  let flag = e.cell(true)
  let a = e.cell(1)
  let b = e.cell(2)
  let root = e.thunk(() => if flag.force() { a.force() } else { b.force() })
  assert_eq(root.force(), 1)
  let before = e.snapshot()
  assert_eq(before[3].dependencies, [0, 1])
  flag.set(false)
  assert_true(e.snapshot()[3].dirty)
  assert_eq(root.force(), 2)
  assert_eq(e.snapshot()[3].dependencies, [0, 2])
  assert_eq(before[3].dependencies, [0, 1])
}

///|
test "multiple projection observations are retained independently" {
  let e = @incr.Engine::new()
  let x = e.cell((1, 2))
  let root = e.thunk(() => x.force_map(p => p.0) + x.force_map(p => p.1))
  assert_eq(root.force(), 3)
  x.set((1, 4))
  assert_eq(root.force(), 5)
  x.set((3, 4))
  assert_eq(root.force(), 7)
}

///|
test "namespaces restore after checked errors" {
  let e = @incr.Engine::new()
  let cells = @incr.Cells::new(e)
  let name = @incr.name_unit()
  let original = cells.cell(name, 42)
  e.ns(name, () => fail("expected")) catch {
    _ => ()
  }
  assert_true(cells.cell(name, 42) == original)
}
