///|
test "random dependency graphs match a plain array interpreter" {
  for seed in [1U, 31U, 771U, 0xabcdefU, 0xffffffffU, 0U] {
    ignore(@stress.engine(seed, 1000))
  }
}

///|
test "random scoped allocation conflicts restore the demanded producer" {
  for seed in [1U, 31U, 771U, 0xabcdefU, 0xffffffffU, 0U] {
    ignore(@stress.nominal(seed, 1000))
  }
}

///|
test "random collection edits match plain arrays with reused names" {
  for seed in [1U, 31U, 771U, 0xabcdefU, 0xffffffffU, 0U] {
    ignore(@stress.collections(seed, 500))
  }
}

///|
test "repeated disposal and bounded depth" {
  ignore(@stress.lifecycle(771U, 30))
  ignore(@stress.depth(1U, 128))
}

///|
test "disposed families and observers remain reachable" {
  ignore(@stress.retained(1U, 3))
}
