///|
priv struct Entry[A, T] {
  arg : Ref[A]
  art : Art[T]
}

///|
/// A typed memoized function. The table itself identifies the program point.
/// Captured non-incremental state must stay fixed for the lifetime of the table.
pub struct Memo[A, T] {
  priv engine : Engine
  priv mut body : ((A) -> T)?
  priv mut named : Map[(Array[Name], Name), Entry[A, T]]
  priv mut structural : Map[(Array[Name], A), Art[T]]
}

///|
pub fn[A, T] Memo::Memo(engine : Engine, body : (A) -> T) -> Memo[A, T] {
  engine.check_context()
  let memo = {
    engine,
    body: Some(body),
    named: Default::default(),
    structural: Default::default(),
  }
  engine.releases.push(() => {
    memo.body = None
    memo.named = Default::default()
    memo.structural = Default::default()
  })
  memo
}

///|
/// Construct a memo table whose body can recursively call the same table.
pub fn[A, T] Memo::recursive(
  engine : Engine,
  body : (Memo[A, T], A) -> T,
) -> Memo[A, T] {
  let link : Ref[Memo[A, T]?] = Ref(None)
  let memo = Memo(engine, arg => body(link.val.unwrap(), arg))
  link.val = Some(memo)
  memo
}

///|
/// Reuse a stable name. Changing arguments invalidates its previous observers
/// and allocators, while preserving the returned articulation's identity.
pub fn[A : Eq, T] Memo::named(
  self : Memo[A, T],
  name : Name,
  arg : A,
) -> Art[T] {
  let e = self.engine
  e.check_context()
  let key = (e.path.val, name)
  let entry = match self.named.get(key) {
    Some(entry) => {
      if entry.arg.val != arg {
        guard !entry.art.node.running else {
          engine_abort("cannot replace an active named thunk")
        }
        entry.arg.val = arg
        entry.art.node.changed = true
        entry.art.node.dirty = true
        e.dirty_users(entry.art.node)
      }
      entry
    }
    None => {
      let argument = Ref(arg)
      let art = e.thunk(() => self.body.unwrap()(argument.val))
      let entry = { arg: argument, art, }
      self.named[key] = entry
      entry
    }
  }
  e.observe(entry.art.node, () => entry.arg.val != arg, true, Allocate)
  entry.art
}

///|
/// Memoize by argument value and current namespace. Hash collisions are resolved
/// by equality; different arguments never overwrite each other's results.
pub fn[A : Hash + Eq, T] Memo::structural(self : Memo[A, T], arg : A) -> Art[T] {
  let e = self.engine
  e.check_context()
  let key = (e.path.val, arg)
  match self.structural.get(key) {
    Some(art) => art
    None => {
      let art = e.thunk(() => self.body.unwrap()(arg))
      self.structural[key] = art
      art
    }
  }
}

///|
/// Allocate and immediately demand a structurally memoized computation.
pub fn[A : Hash + Eq, T : Eq] Memo::call(self : Memo[A, T], arg : A) -> T {
  self.structural(arg).force()
}
