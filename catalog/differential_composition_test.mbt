///|
fn composition_next(state : Ref[UInt32]) -> Int32 {
  let x = state.val
  let x = x ^ (x << 13)
  let x = x ^ (x >> 17)
  let x = x ^ (x << 5)
  state.val = x
  (x >> 1).reinterpret_as_int()
}

///|
test "composed consumers and branching trie across mixed edits" {
  for seed in [20261016U, 195948557U, 305419896U] {
    let rng = Ref(seed)
    let e = @incr.Engine()
    let cells = @incr.Cells(e)
    let input = e.cell(@catalog.List::Nil)
    let parameter = e.cell(0)
    let mapper = @catalog.list_map_lazy(e, (x : Int32) => {
      x * 3 + parameter.force()
    })
    let mapped = mapper.named(@incr.name_unit(), Art(input))
    let filter = @catalog.list_filter_lazy(e, x => x % 2 == 0)
    let filtered = filter.named(@incr.name_unit(), Art(mapped))
    let builder = @catalog.tree_of_list(e)
    let tree = builder.named(@incr.name_unit(), Art(filtered))
    let sort = @catalog.mergesort_list_of_tree(e)
    let sorted = sort.named(@incr.name_unit(), Art(tree))
    let after_sort = @catalog.list_map_lazy(e, x => x + 2)
    let result = after_sort.named(@incr.name_unit(), Art(sorted))
    let trie_in = e.cell(@catalog.Trie::empty())
    let fold = @catalog.trie_fold(e, (x : Int32, acc : Array[Int32]) => {
      acc + [x]
    })
    let trie_result = fold.named(
      @incr.name_of_string("root"),
      (@catalog.Trie::named(@incr.name_unit(), @catalog.Trie::art(trie_in)), []),
    )
    let mut entries = [ for i in 0..<24 => (i, i) ]
    for step in 0..<5000 {
      let index = composition_next(rng) % entries.length()
      entries[index] = (entries[index].0, composition_next(rng) % 2001 - 1000)
      if step % 7 == 0 {
        entries = entries.rev()
      }
      let bias = composition_next(rng) % 9 - 4
      parameter.set(bias)
      let length = composition_next(rng) % 25
      let values = entries[:length].map(x => x.1)
      let mut list : @catalog.List[Int32] = Nil
      for i = length - 1; i >= 0; i = i - 1 {
        let (id, value) = entries[i]
        let name = @incr.name_of_int(id)
        list = Named(name, Art(cells.cell(name, Cons(value, list))))
      }
      input.set(list)
      let expected = values.map(x => x * 3 + bias).filter(x => x % 2 == 0)
      expected.sort()
      let expected = expected.map(x => x + 2)
      let prefix = composition_next(rng) % (expected.length() + 1)
      assert_eq(
        result.force().to_array(limit=prefix),
        expected[:prefix].to_owned(),
        msg="seed=\{seed} step=\{step}",
      )
      if step % 11 == 0 || step == 4999 {
        assert_eq(
          result.force().to_array(),
          expected,
          msg="seed=\{seed} step=\{step}",
        )
      }
      let mut trie : @catalog.Trie[Int32] = @catalog.Trie::empty()
      let unique : Array[Int32] = []
      for x in values {
        trie = trie.add(x)
        if !unique.contains(x) {
          unique.push(x)
        }
      }
      trie_in.set(trie)
      // Trie order is lexicographic by low-to-high hash bits, then insertion order.
      let ordered_keys = unique.mapi((i, x) => (x, i))
      ordered_keys.sort_by((a, b) => {
        let ah = a.0.hash().reinterpret_as_uint()
        let bh = b.0.hash().reinterpret_as_uint()
        let mut order = 0
        for bit in 0..<32 {
          if order == 0 {
            order = ((ah >> bit) & 1U).compare((bh >> bit) & 1U)
          }
        }
        if order == 0 {
          a.1.compare(b.1)
        } else {
          order
        }
      })
      assert_eq(
        trie_result.force(),
        ordered_keys.map(x => x.0),
        msg="branching trie seed=\{seed} step=\{step}",
      )
      for x in values {
        assert_true(trie.contains(x))
      }
      let probe = composition_next(rng) % 2001 - 1000
      assert_eq(trie.contains(probe), values.contains(probe))
    }
    e.dispose()
  }
}
