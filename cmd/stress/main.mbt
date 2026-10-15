///|
fn main {
  let args = @env.args()
  let mode = args[1]
  let seed = try! @string.parse_uint(args[2])
  let steps = try! @string.parse_int(args[3])
  guard steps > 0 else { abort("steps must be positive") }
  let checksum = match mode {
    "engine" => try! @checks.engine(seed, steps)
    "nominal" => try! @checks.nominal(seed, steps)
    _ => abort("unknown mode")
  }
  println("mode=\{mode} seed=\{seed} steps=\{steps} checksum=\{checksum}")
}
