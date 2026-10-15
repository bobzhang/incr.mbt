///|
fn main {
  let runs = if @env.args().contains("large") { 20000 } else { 200 }
  let mut sum = 0
  for _ in 0..<runs {
    let e = @incr.Engine()
    let cells = @incr.Cells::new(e)
    let input = cells.cell(@incr.name_unit(), 17)
    let memo = @incr.Memo::recursive(e, (memo, n : Int32) => {
      if n == 0 {
        input.force()
      } else {
        memo.call(n - 1) + 1
      }
    })
    guard memo.call(64) == 81 else { abort("bad initial result") }
    input.set(18)
    sum += memo.call(64)
    e.dispose()
  }
  println("runs=\{runs}, checksum=\{sum}")
}
