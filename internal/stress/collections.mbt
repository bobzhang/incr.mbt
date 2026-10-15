///|
fn edit_entries(
  rng : Random,
  entries : Array[(Int32, Int32)],
) -> Array[(Int32, Int32)] {
  let op = rng.pick(9)
  if entries.is_empty() || (op < 3 && entries.length() < 64) {
    let mut id = rng.pick(96)
    while entries.any(x => x.0 == id) {
      id = (id + 1) % 96
    }
    let at = rng.pick(entries.length() + 1)
    entries[:at].to_owned() +
    [(id, rng.pick(41) - 20)] +
    entries[at:].to_owned()
  } else {
    let at = rng.pick(entries.length())
    match op {
      3 => entries[:at].to_owned() + entries[at + 1:].to_owned()
      4 => {
        entries[at] = (entries[at].0, rng.pick(41) - 20)
        entries
      }
      5 => entries.rev()
      6 => {
        let to = rng.pick(entries.length())
        let item = entries[at]
        entries[at] = entries[to]
        entries[to] = item
        entries
      }
      7 => if rng.pick(64) == 0 { [] } else { entries }
      _ => entries // Equal input replacement.
    }
  }
}

///|
fn collection_input(
  cells : @incr.Cells[@catalog.List[Int32]],
  entries : Array[(Int32, Int32)],
  layout : Int32,
) -> @catalog.List[Int32] {
  let mut tail : @catalog.List[Int32] = Nil
  for i = entries.length() - 1; i >= 0; i = i - 1 {
    let (id, value) = entries[i]
    let base = @incr.name_of_int(id / 4)
    let (left, right) = @incr.name_fork(base)
    // Distinct names may still share fork ancestry. Exercise those domains.
    let name = match id % 4 {
      0 => base
      1 => left
      2 => right
      _ => @incr.name_fork(left).0
    }
    tail = match layout {
      0 => Named(name, Cons(value, tail))
      1 => Named(name, Art(cells.cell(name, Cons(value, tail))))
      _ => Cons(value, Named(name, Art(cells.cell(name, tail))))
    }
  }
  tail
}

///|
/// Random mixed collection edits, bounded reusable identities and demand order.
pub fn collections(seed : UInt32, steps : Int32) -> Int64 raise {
  let rng = Random::new(seed)
  let e = @incr.Engine()
  let cells = @incr.Cells::new(e)
  let input = e.cell(@catalog.List::Nil)
  let map = @catalog.list_map_lazy(e, (x : Int32) => x * 3 + 1)
  let mapped = map.named(@incr.name_unit(), Art(input))
  let filter = @catalog.list_filter_lazy(e, x => x % 2 == 0)
  let filtered = filter.named(@incr.name_unit(), Art(mapped))
  let build = @catalog.tree_of_list(e)
  let tree = build.named(@incr.name_unit(), Art(input))
  let sum = @catalog.monoid_of_tree(e, 0, x => x, (a, b) => a + b)
  let total = sum.named(@incr.name_unit(), Art(tree))
  let sort = @catalog.mergesort_list_of_tree(e)
  let sorted = sort.named(@incr.name_unit(), Art(tree))
  let inverse = @catalog.list_of_tree(e, reverse=true)
  let backwards = inverse.named(@incr.name_unit(), Art(tree))
  let fold = @catalog.tree_fold_seq(
    e,
    leaf=(x : Int32, acc : (Int64, Int32)) => {
      (acc.0 + (acc.1 + 1).to_int64() * x.to_int64(), acc.1 + 1)
    },
    bin=(_, acc) => acc,
    name=(_, _, acc) => acc,
  )
  let folded = fold.named(@incr.name_unit(), (Art(tree), (0L, 0)))
  let trie_input = e.cell(@catalog.Trie::empty())
  let trie_fold = @catalog.trie_fold(e, (x : Collision, acc : Array[Int32]) => {
    acc + [x.0]
  })
  let trie_result = trie_fold.named(
    @incr.name_of_string("trie-root"),
    (
      @catalog.Trie::named(@incr.name_unit(), @catalog.Trie::art(trie_input)),
      [],
    ),
  )
  let mut entries : Array[(Int32, Int32)] = Array::makei(32, i => {
    (i, rng.pick(41) - 20)
  })
  let mut checksum = 0L
  for step in 0..<steps {
    for _ in 0..<(1 + rng.pick(3)) {
      entries = edit_entries(rng, entries)
    }
    input.set(collection_input(cells, entries, rng.pick(3)))
    let values = entries.map(x => x.1)
    let mapped_values = values.map(x => x * 3 + 1)
    let filtered_values = mapped_values.filter(x => x % 2 == 0)
    let ordered = values.copy()
    ordered.sort()
    let unique : Array[Int32] = []
    let mut trie : @catalog.Trie[Collision] = @catalog.Trie::empty()
    for x in values {
      trie = trie.add(Collision(x))
      if !unique.contains(x) {
        unique.push(x)
      }
    }
    trie_input.set(trie)
    let prefix = rng.pick(values.length() + 5)
    // Vary which consumer performs cleaning first; demand tiny or empty prefixes.
    match rng.pick(5) {
      0 =>
        expect(
          sorted.force().to_array(limit=prefix),
          ordered[:Int32::min(prefix, ordered.length())].to_owned(),
          seed,
          step,
          "sort prefix",
        )
      1 =>
        expect(
          filtered.force().to_array(limit=prefix),
          filtered_values[:Int32::min(prefix, filtered_values.length())].to_owned(),
          seed,
          step,
          "filter prefix",
        )
      2 =>
        expect(
          backwards.force().to_array(),
          values.rev(),
          seed,
          step,
          "reverse roundtrip",
        )
      3 =>
        expect(
          mapped.force().to_array(limit=prefix),
          mapped_values[:Int32::min(prefix, mapped_values.length())].to_owned(),
          seed,
          step,
          "map prefix",
        )
      _ =>
        expect(
          total.force(),
          values.fold(init=0, (a, b) => a + b),
          seed,
          step,
          "sum",
        )
    }
    let mut weighted = 0L
    for i, x in values {
      weighted += (i + 1).to_int64() * x.to_int64()
    }
    expect(
      folded.force(),
      (weighted, values.length()),
      seed,
      step,
      "sequential fold",
    )
    expect(trie_result.force(), unique, seed, step, "ordered collision trie")
    checksum += weighted
    if step % 17 == 0 || step == steps - 1 {
      expect(sorted.force().to_array(), ordered, seed, step, "full sort")
      expect(
        filtered.force().to_array(),
        filtered_values,
        seed,
        step,
        "full filter",
      )
      expect(mapped.force().to_array(), mapped_values, seed, step, "full map")
      expect(tree.force().to_array(), values, seed, step, "sequence tree")
      expect(
        backwards.force().to_array(),
        values.rev(),
        seed,
        step,
        "full roundtrip",
      )
    }
  }
  e.dispose()
  expect(e.snapshot().length(), 0, seed, steps, "disposed collections")
  checksum
}
