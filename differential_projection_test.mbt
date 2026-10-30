///|
fn projection_next(state : Ref[UInt32]) -> Int32 {
  let x = state.val
  let x = x ^ (x << 13)
  let x = x ^ (x >> 17)
  let x = x ^ (x << 5)
  state.val = x
  (x >> 1).reinterpret_as_int()
}

///|
test "random projected thunk branches with delayed demands" {
  for seed in [20261016U, 195948557U, 305419896U, 270544960U] {
    let rng = Ref(seed)
    let e = @incr.Engine()
    let inputs = Array::makei(8, _ => (0, 0))
    let controls = Array::makei(24, i => (0, i % (8 + i), (i + 1) % (8 + i)))
    let cells = inputs.map(x => e.cell(x))
    let rules = controls.map(x => e.cell(x))
    let nodes = cells.copy()
    for i in 0..<24 {
      let node = e.thunk(() => {
        let (mode, a, b) = rules[i].force()
        let first = nodes[a].force_map(x => x.0)
        let second = match mode {
          0 => nodes[a].force_map(x => x.1)
          1 => nodes[b].force_map(x => x.0)
          2 => nodes[b].force_map(x => x.1 % 7)
          3 => if first % 2 == 0 { nodes[b].force_map(x => x.1) } else { first }
          _ => nodes[a].force().1 + nodes[b].force_map(x => x.0)
        }
        ((first + second) % 101, (first - second) % 103)
      })
      nodes.push(node)
    }
    for step in 0..<20000 {
      for _ in 0..<(1 + projection_next(rng) % 5) {
        if projection_next(rng) % 3 == 0 {
          let i = projection_next(rng) % 24
          controls[i] = (
            projection_next(rng) % 5,
            projection_next(rng) % (8 + i),
            projection_next(rng) % (8 + i),
          )
          rules[i].set(controls[i])
        } else {
          let i = projection_next(rng) % 8
          let old = inputs[i]
          inputs[i] = if projection_next(rng) % 2 == 0 {
            (projection_next(rng) % 51 - 25, old.1)
          } else {
            (old.0, projection_next(rng) % 51 - 25)
          }
          cells[i].set(inputs[i])
        }
      }
      let expected = inputs.copy()
      for (mode, a, b) in controls {
        let (x, y) = expected[a]
        let (u, v) = expected[b]
        let z = match mode {
          0 => y
          1 => u
          2 => v % 7
          3 => if x % 2 == 0 { v } else { x }
          _ => y + u
        }
        expected.push(((x + z) % 101, (x - z) % 103))
      }
      for _ in 0..<(projection_next(rng) % 4) {
        let i = 8 + projection_next(rng) % 24
        assert_eq(
          nodes[i].force(),
          expected[i],
          msg="seed=\{seed}, step=\{step}, node=\{i}",
        )
      }
      if step % 101 == 0 || step == 19999 {
        for i in 31>=..8 {
          assert_eq(
            nodes[i].force(),
            expected[i],
            msg="seed=\{seed}, step=\{step}, node=\{i}",
          )
        }
      }
    }
    e.dispose()
  }
}
