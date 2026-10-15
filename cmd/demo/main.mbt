///|
fn main {
  let engine = @incr.Engine()
  let numerator = engine.cell(42)
  let denominator = engine.cell(2)
  let quotient = engine.thunk(() => numerator.force() / denominator.force())
  let safe = engine.thunk(() => {
    if denominator.force() == 0 {
      None
    } else {
      Some(quotient.force())
    }
  })
  for value in [2, 0, 3, 3] {
    denominator.set(value)
    println(
      "denominator=\{value}, result=\{Repr(safe.force())}, evaluations=\{engine.stats().evaluations}",
    )
  }
  engine.dispose()
}
