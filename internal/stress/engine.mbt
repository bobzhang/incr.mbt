///|
priv struct Rule {
  mode : Int32
  a : Int32
  b : Int32
  source : Int32
} derive(Eq)

///|
fn random_rule(rng : Random, index : Int32) -> Rule {
  {
    mode: rng.pick(7),
    a: rng.pick(16 + index),
    b: rng.pick(16 + index),
    source: rng.pick(16),
  }
}

///|
fn graph_read(
  inputs : Array[@incr.Art[(Int32, Int32)]],
  nodes : Array[@incr.Art[Int32]],
  index : Int32,
) -> Int32 {
  if index < 16 {
    inputs[index].force_map(p => p.0)
  } else {
    nodes[index - 16].force()
  }
}

///|
// This interpreter uses only ordinary arrays, never cached nodes or naive mode.
fn interpret(
  inputs : Array[(Int32, Int32)],
  rules : Array[Rule],
) -> Array[Int32] {
  let values = inputs.map(p => p.0)
  for r in rules {
    let (first, second) = inputs[r.source]
    let result = match r.mode {
      0 => first
      1 => second
      2 => values[r.a] + values[r.b]
      3 => if first % 2 == 0 { values[r.a] } else { values[r.b] }
      4 => values[r.a] % 5
      5 => values[r.a] * 2 + first - second
      _ => if second == 0 { 0 } else { values[r.a] / second }
    }
    values.push(result % 10007)
  }
  values
}

///|
/// Replay random input edits, rule changes, delayed demands and demand orders.
pub fn engine(seed : UInt32, steps : Int32) -> Int64 raise {
  let rng = Random(seed)
  let e = @incr.Engine()
  let inputs = Array::makei(16, _ => (rng.pick(201) - 100, rng.pick(21) - 10))
  let cells = inputs.map(x => e.cell(x))
  let rules = Array::makei(48, i => random_rule(rng, i))
  let controls = rules.map(x => e.cell(x))
  let nodes : Array[@incr.Art[Int32]] = []
  for i in 0..<48 {
    nodes.push(
      e.thunk(() => {
        let r = controls[i].force()
        let read = index => graph_read(cells, nodes, index)
        let result = match r.mode {
          0 => cells[r.source].force_map(p => p.0)
          1 => cells[r.source].force_map(p => p.1)
          2 => read(r.a) + read(r.b)
          3 =>
            if cells[r.source].force_map(p => p.0 % 2) == 0 {
              read(r.a)
            } else {
              read(r.b)
            }
          4 => read(r.a) % 5
          5 =>
            read(r.a) +
            read(r.a) +
            cells[r.source].force_map(p => p.0) -
            cells[r.source].force_map(p => p.1)
          _ => {
            let denominator = cells[r.source].force_map(p => p.1)
            if denominator == 0 {
              0
            } else {
              read(r.a) / denominator
            }
          }
        }
        result % 10007
      }),
    )
  }
  let allocated = e.stats().allocated
  let mut checksum = 0L
  for step in 0..<steps {
    // Multiple edits before demands, including equal writes and zero divisors.
    for _ in 0..<(1 + rng.pick(4)) {
      let op = rng.pick(6)
      if op < 4 {
        let i = rng.pick(16)
        let (a, b) = inputs[i]
        let next = match op {
          0 => (rng.pick(201) - 100, b)
          1 => (a, rng.pick(21) - 10)
          2 => (a, 0)
          _ => (a, b)
        }
        inputs[i] = next
        cells[i].set(next)
      } else {
        let i = rng.pick(48)
        rules[i] = random_rule(rng, i)
        controls[i].set(rules[i])
      }
    }
    let expected = interpret(inputs, rules)
    // Some rounds leave everything dirty for the next batch of edits.
    for _ in 0..<rng.pick(5) {
      let i = rng.pick(48)
      let actual = nodes[i].force()
      expect(actual, expected[i + 16], seed, step, "DAG node \{i}")
      expect(nodes[i].force(), actual, seed, step, "cached DAG node \{i}")
      checksum += actual.to_int64()
    }
    if step % 97 == 0 || step == steps - 1 {
      for i = 47; i >= 0; i = i - 1 {
        expect(
          nodes[i].force(),
          expected[i + 16],
          seed,
          step,
          "complete DAG \{i}",
        )
      }
      expect(
        e.stats().allocated,
        allocated,
        seed,
        step,
        "fixed graph node count",
      )
      for node in e.snapshot() {
        for dependency in node.dependencies {
          guard dependency >= 0 && dependency < allocated else {
            fail("seed=\{seed} step=\{step}: dangling dependency")
          }
        }
      }
    }
  }
  e.dispose()
  expect(e.snapshot().length(), 0, seed, steps, "disposed DAG")
  checksum
}
