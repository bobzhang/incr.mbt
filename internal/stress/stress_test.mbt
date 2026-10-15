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
