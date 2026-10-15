///|
priv struct Random {
  mut state : UInt32
}

///|
fn Random::new(seed : UInt32) -> Random {
  { state: if seed == 0U { 0x9e3779b9U } else { seed }, }
}

///|
fn Random::pick(self : Random, bound : Int32) -> Int32 {
  let mut x = self.state
  x = x ^ (x << 13)
  x = x ^ (x >> 17)
  x = x ^ (x << 5)
  self.state = x
  (x >> 1).reinterpret_as_int() % bound
}

///|
fn[T : Eq + Debug] expect(
  actual : T,
  expected : T,
  seed : UInt32,
  step : Int32,
  context : String,
) -> Unit raise {
  if actual != expected {
    fail(
      "seed=\{seed} step=\{step} \{context}: actual=\{Repr(actual)}, expected=\{Repr(expected)}",
    )
  }
}
