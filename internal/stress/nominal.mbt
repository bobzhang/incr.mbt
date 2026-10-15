///|
priv struct Collision(Int32) derive(Eq)

///|
impl Hash for Collision with fn hash_combine(_self, hasher) {
  hasher.combine(0)
}

///|
/// Replay scoped name conflicts and allocator restoration against direct values.
pub fn nominal(seed : UInt32, steps : Int32) -> Int64 raise {
  let rng = Random(seed)
  let e = @incr.Engine()
  let values = Array::makei(8, _ => rng.pick(101) - 50)
  let inputs = values.map(x => e.cell(x))
  // (scope, name, source, bias). Different producers intentionally share names.
  let settings = Array::makei(12, i => (i % 3, i % 4, i % 8, i))
  let controls = settings.map(x => e.cell(x))
  let outputs = @incr.Cells(e)
  let memo = @incr.Memo(e, (arg : (Int32, Int32)) => {
    inputs[arg.0].force() * 3 + arg.1
  })
  let roots = controls.map(control => {
    let producer = e.thunk(() => {
      let (scope, key, source, bias) = control.force()
      e.ns(@incr.name_of_int(scope), () => {
        let name = @incr.name_of_int(key)
        let child = memo.named(name, (source, bias))
        outputs.cell(name, child.force())
      })
    })
    e.thunk(() => producer.force().force())
  })
  let structural = @incr.Memo(e, (arg : Collision) => {
    inputs[arg.0 % 8].force() + arg.0
  })
  let mut checksum = 0L
  for step in 0..<steps {
    match rng.pick(5) {
      0 => {
        let i = rng.pick(8)
        values[i] = rng.pick(101) - 50
        inputs[i].set(values[i])
      }
      1 => {
        let i = rng.pick(12)
        settings[i] = (rng.pick(3), rng.pick(4), rng.pick(8), rng.pick(41) - 20)
        controls[i].set(settings[i])
      }
      2 | 3 => {
        let scope = rng.pick(3)
        let key = rng.pick(4)
        e.ns(@incr.name_of_int(scope), () => {
          ignore(
            memo.named(@incr.name_of_int(key), (rng.pick(8), rng.pick(101))),
          )
          ignore(outputs.cell(@incr.name_of_int(key), rng.pick(101) + 1000))
        })
      }
      _ => ()
    }
    for _ in 0..<(1 + rng.pick(4)) {
      let i = rng.pick(12)
      let (_, _, source, bias) = settings[i]
      let expected = values[source] * 3 + bias
      expect(roots[i].force(), expected, seed, step, "nominal producer \{i}")
      checksum += expected.to_int64()
    }
    let argument = rng.pick(32)
    let a = structural.structural(Collision(argument))
    expect(
      a.force(),
      values[argument % 8] + argument,
      seed,
      step,
      "collision key",
    )
    expect(
      a == structural.structural(Collision(argument)),
      true,
      seed,
      step,
      "structural identity",
    )
    // All name/key spaces are bounded; changed arguments must reuse nodes.
    guard e.stats().allocated <= 100 else {
      fail(
        "seed=\{seed} step=\{step}: bounded nominal keys leaked nodes: \{e.stats().allocated}",
      )
    }
  }
  e.dispose()
  checksum
}
