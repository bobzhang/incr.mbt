///|
fn make_chunk(
  chunk : Int32,
  values : Array[Int32],
  tail : @catalog.List[Int32],
  step : Int32?,
) -> @catalog.List[Int32] {
  let mut result = tail
  // The sequence workload alternates inserting/removing one value at a chunk
  // boundary, retaining all the other chunks and their stable names.
  if step is Some(s) && s % 2 == 0 {
    result = Cons(edit_value(s), result)
  }
  for offset = 15; offset >= 0; offset = offset - 1 {
    result = Cons(values[chunk * 16 + offset], result)
  }
  result
}

///|
fn list_workload(
  mode : String,
  n : Int32,
  edits : Int32,
  verify : Bool,
) -> Int64 {
  let e = @incr.Engine::new()
  let values = Array::makei(n, initial_value)
  let chunks = n / 16
  let cells : Array[@incr.Art[@catalog.List[Int32]]] = Array::makei(chunks, _ => {
    e.cell(Nil)
  })
  let tails : Array[@catalog.List[Int32]] = Array::make(chunks, Nil)
  let mut input : @catalog.List[Int32] = Nil
  for chunk = chunks - 1; chunk >= 0; chunk = chunk - 1 {
    tails[chunk] = input
    cells[chunk].set(make_chunk(chunk, values, input, None))
    input = Named(@incr.name_of_int(chunk), Art(cells[chunk]))
  }
  let demand : () -> Array[Int32] = if mode == "sequence" {
    let build = @catalog.tree_of_list(e)
    let tree = e.ns(@incr.name_of_string("build"), () => {
      build.named(@incr.name_of_string("root"), input)
    })
    let fold = @catalog.monoid_of_tree(e, 0, x => x, (a, b) => a + b)
    let total = e.ns(@incr.name_of_string("sum"), () => {
      fold.named(@incr.name_of_string("root"), Art(tree))
    })
    () => [total.force()]
  } else {
    let transform = match mode {
      "map_full" | "map_prefix" => @catalog.list_map_lazy(e, x => x * 3 + 1)
      "filter_full" => @catalog.list_filter_lazy(e, x => x % 3 == 0)
      _ => abort("unknown workload")
    }
    let output = transform.named(@incr.name_of_string("root"), input)
    let limit = if mode == "map_prefix" { 32 } else { n }
    () => output.force().to_array(limit~)
  }
  let mut checksum = consume(demand(), verify)
  for step in 0..<edits {
    let index = edit_index(step, n)
    let chunk = if mode == "sequence" {
      // Paired insertion/deletion at the same chunk, then move to another one.
      edit_index(step / 2, chunks)
    } else {
      values[index] = edit_value(step)
      index / 16
    }
    cells[chunk].set(
      make_chunk(
        chunk,
        values,
        tails[chunk],
        if mode == "sequence" {
          Some(step)
        } else {
          None
        },
      ),
    )
    checksum += consume(demand(), verify)
  }
  e.dispose()
  checksum
}
