///|
/// A typed family of named cells. Each family has its own name space.
/// Keep this object alive and reuse it across edits.
pub struct Cells[T] {
  priv engine : Engine
  priv named : Map[(Array[Name], Name), Art[T]]
  priv interned : Map[(Array[Name], T), Art[T]]
}

///|
pub fn[T] Cells::new(engine : Engine) -> Cells[T] {
  engine.check_context()
  let cells = {
    engine,
    named: Default::default(),
    interned: Default::default(),
  }
  engine.releases.push(() => {
    cells.named.clear()
    cells.interned.clear()
  })
  cells
}

///|
/// Allocate or update a named cell. Inside a thunk, records an allocation edge:
/// if someone changes the cell, the allocator must run again to restore it.
pub fn[T : Eq] Cells::cell(self : Cells[T], name : Name, value : T) -> Art[T] {
  let e = self.engine
  e.check_context()
  let key = (e.path.val, name)
  let art = match self.named.get(key) {
    Some(art) => {
      art.write(value)
      art
    }
    None => {
      let art = e.cell(value)
      self.named[key] = art
      art
    }
  }
  e.observe(art.node, () => art.value != Some(value), true)
  art
}

///|
/// Hash-cons an immutable value using both hash and equality, within this namespace.
pub fn[T : Hash + Eq] Cells::intern(self : Cells[T], value : T) -> Art[T] {
  let e = self.engine
  e.check_context()
  let key = (e.path.val, value)
  match self.interned.get(key) {
    Some(art) => art
    None => {
      let art = e.put(value)
      self.interned[key] = art
      art
    }
  }
}
