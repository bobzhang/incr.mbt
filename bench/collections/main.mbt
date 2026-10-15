///|
fn initial_value(i : Int32) -> Int32 {
  (i * 37 + 11) % 10007
}

///|
fn edit_index(step : Int32, n : Int32) -> Int32 {
  (step * 97 + 13) % n
}

///|
fn edit_value(step : Int32) -> Int32 {
  (step * 53 + 7) % 10007
}

///|
fn consume(values : Array[Int32], verify : Bool) -> Int64 {
  if verify {
    println(values.map(x => x.to_string()).join(","))
  }
  let mut digest = values.length().to_int64() * 1000000000L
  for i, value in values {
    digest += (i + 1).to_int64() * value.to_int64()
  }
  digest
}

///|
fn main {
  let args = @env.args()
  let mode = args[1]
  let n = try! @string.parse_int(args[2])
  let edits = try! @string.parse_int(args[3])
  let verify = args.contains("verify")
  guard n >= 16 && n % 16 == 0 && edits >= 0 else {
    abort("invalid size/edits")
  }
  let result = if mode == "lifecycle" {
    let mut total = 0L
    for _ in 0..<edits {
      total += tree_workload("sum", n, 0, verify)
    }
    total
  } else if mode == "sum" || mode == "sort_full" || mode == "sort_prefix" {
    tree_workload(mode, n, edits, verify)
  } else {
    list_workload(mode, n, edits, verify)
  }
  println("checksum=\{result}")
}
