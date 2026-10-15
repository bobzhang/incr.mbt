///|
/// Repeatedly build and dispose closure cycles, edge graphs, and typed tables.
pub fn lifecycle(seed : UInt32, rounds : Int32) -> Int64 raise {
  let mut checksum = 0L
  for round in 0..<rounds {
    let current = seed + round.reinterpret_as_uint()
    checksum += engine(current, 16)
    checksum += nominal(current, 16)
  }
  checksum
}

///|
/// Run separately when exploring backend-specific recursive demand limits.
pub fn depth(seed : UInt32, depth : Int32) -> Int64 raise {
  let e = @incr.Engine()
  let input = e.cell(0)
  let mut root = input
  for _ in 0..<depth {
    let child = root
    root = e.thunk(() => child.force() + 1)
  }
  let mut checksum = 0L
  for step in 0..<128 {
    input.set(step)
    let actual = root.force()
    expect(actual, depth + step, seed, step, "depth \{depth}")
    checksum += actual.to_int64()
  }
  expect(e.stats().allocated, depth + 1, seed, 128, "depth node count")
  e.dispose()
  checksum
}

///|
/// Measure deliberate cache growth with unique names, then release the graph.
pub fn growing(seed : UInt32, steps : Int32) -> Int64 raise {
  let rng = Random::new(seed)
  let e = @incr.Engine()
  let memo = @incr.Memo::new(e, (x : Int32) => x * 2)
  let mut checksum = 0L
  for step in 0..<steps {
    let art = memo.named(@incr.name_of_int(step), step)
    expect(art.force(), step * 2, seed, step, "new named entry")
    let previous = rng.pick(step + 1)
    let reused = memo.named(@incr.name_of_int(previous), previous)
    expect(reused.force(), previous * 2, seed, step, "old named entry")
    checksum += reused.force().to_int64()
    expect(e.stats().allocated, step + 1, seed, step, "unique-key growth")
  }
  e.dispose()
  expect(e.snapshot().length(), 0, seed, steps, "disposed growing cache")
  checksum
}

///|
/// Keep disposed handles reachable so retained table capacity cannot hide behind
/// dropping the entire engine. Empty handles themselves still require storage.
pub fn retained(seed : UInt32, rounds : Int32) -> Int64 raise {
  let handles : Array[
    (
      @incr.Engine,
      @incr.Cells[Int32],
      @incr.Memo[Int32, Int32],
      @incr.Art[Int32],
    ),
  ] = []
  let mut checksum = 0L
  for round in 0..<rounds {
    let e = @incr.Engine()
    let cells = @incr.Cells::new(e)
    let memo = @incr.Memo::new(e, (x : Int32) => x + round)
    let input = e.cell(round)
    for key in 0..<2048 {
      let name = @incr.name_of_int(key)
      expect(
        cells.cell(name, key).force(),
        key,
        seed,
        round,
        "retained named cell",
      )
      expect(
        cells.intern(key).force(),
        key,
        seed,
        round,
        "retained interned cell",
      )
      expect(
        memo.named(name, key).force(),
        key + round,
        seed,
        round,
        "retained named memo",
      )
      expect(
        memo.call(key),
        key + round,
        seed,
        round,
        "retained structural memo",
      )
      expect(
        e.thunk(() => input.force()).force(),
        round,
        seed,
        round,
        "retained observer",
      )
      checksum += (key + round).to_int64()
    }
    e.dispose()
    handles.push((e, cells, memo, input))
  }
  for (e, _, _, _) in handles {
    expect(e.snapshot().length(), 0, seed, rounds, "retained disposed graph")
  }
  checksum + handles.length().to_int64()
}
