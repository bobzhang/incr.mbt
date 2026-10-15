///|
/// A typed articulation: an immutable value, mutable cell, or cached computation.
/// Values and values captured by thunks must be treated as immutable snapshots.
pub struct Art[T] {
  priv engine : Engine
  priv node : Node
  priv mut value : T?
  priv mut compute : (() -> T)?
}

///|
pub impl[T] Eq for Art[T] with fn equal(self, other) {
  self.engine.id == other.engine.id && self.node.id == other.node.id
}

///|
pub impl[T] Hash for Art[T] with fn hash_combine(self, hasher) {
  hasher.combine(self.engine.id)
  hasher.combine(self.node.id)
}

///|
pub impl[T] Debug for Art[T] with fn to_repr(self) {
  Debug::to_repr((self.engine.id, self.node.id))
}

///|
pub extend Art with Eq::{equal, not_equal}

///|
pub extend Art with Hash::{hash, hash_combine}

///|
pub extend Art with Debug::{to_repr}

///|
fn[T] Engine::art(
  self : Engine,
  kind : Kind,
  value : T?,
  compute : (() -> T)?,
) -> Art[T] {
  let art = { engine: self, node: self.node(kind), value, compute, }
  self.releases.push(() => {
    art.value = None
    art.compute = None
  })
  art
}

///|
/// Create a fresh mutable input. Equal writes do not invalidate observers.
pub fn[T] Engine::cell(self : Engine, value : T) -> Art[T] {
  self.art(Cell, Some(value), None)
}

///|
/// Create an immutable articulation.
pub fn[T] Engine::put(self : Engine, value : T) -> Art[T] {
  self.art(Constant, Some(value), None)
}

///|
/// Suspend a computation. Its dependencies are discovered by `force` calls.
/// Bodies must be deterministic and may read cells but may not call `set`.
pub fn[T] Engine::thunk(self : Engine, compute : () -> T) -> Art[T] {
  self.art(Thunk, None, Some(compute))
}

///|
/// Update an input between computations. Panics for immutable values or thunks.
pub fn[T : Eq] Art::set(self : Art[T], value : T) -> Unit {
  self.engine.check_context()
  guard executing_engine.val is None else {
    engine_abort("set is only allowed outside computations")
  }
  guard self.node.kind is Cell else {
    engine_abort("set requires a mutable cell")
  }
  self.write(value)
}

///|
fn[T : Eq] Art::write(self : Art[T], value : T) -> Unit {
  if self.value != Some(value) {
    self.value = Some(value)
    self.engine.dirty_users(self.node)
  }
}

///|
fn[T] Art::read(self : Art[T], cycle : T?) -> T {
  self.engine.check_context()
  let engine = self.engine
  let node = self.node
  if node.running {
    return match cycle {
      Some(value) => value
      None => engine_abort("unexpected cycle in incremental computation")
    }
  }
  if node.kind is Thunk {
    node.running = true
    let result = executing_engine.protect(Some(engine.id), () => {
      engine.current.protect(None, () => {
        let mut rerun = engine.naive || self.value is None || node.changed
        if node.dirty && !rerun {
          // Stop at the first changed dependency. Later edges can belong to a
          // branch that is no longer demanded (including division by zero).
          for edge in node.deps {
            if (edge.differs)() {
              rerun = true
              break
            }
          }
          engine.cleanings += 1
        }
        if rerun || node.changed {
          node.detach()
          let compute = self.compute.unwrap()
          engine.evaluations += 1
          node.evaluating = true
          let value = engine.path.protect(node.path, () => {
            engine.current.protect(Some(node), compute)
          })
          node.evaluating = false
          self.value = Some(value)
        } else {
          engine.cache_hits += 1
        }
        node.dirty = false
        node.changed = false
        self.value.unwrap()
      })
    })
    node.running = false
    result
  } else {
    self.value.unwrap()
  }
}

///|
/// Demand a result and record an observation in the calling thunk.
pub fn[T : Eq] Art::force(self : Art[T]) -> T {
  self.force_cycle(None)
}

///|
/// Use `fallback` when this force encounters an active thunk, or panic if absent.
/// This is cycle cutting, not a fixed-point solver.
pub fn[T : Eq] Art::force_cycle(self : Art[T], fallback : T?) -> T {
  let value = self.read(fallback)
  if !(self.node.kind is Constant) {
    self.engine.observe(self.node, () => self.read(fallback) != value, false)
  }
  value
}

///|
/// Observe a pure projection. Changes outside the projection do not rerun users.
/// The mapping must not read or allocate articulations.
pub fn[T, U : Eq] Art::force_map(self : Art[T], map : (T) -> U) -> U {
  let value = map(self.read(None))
  if !(self.node.kind is Constant) {
    self.engine.observe(
      self.node,
      () => map(self.read(None)) != value,
      self.node.kind is Cell,
    )
  }
  value
}

///|
/// Create a cached derived articulation in the same engine.
pub fn[T : Eq, U] Art::map(self : Art[T], map : (T) -> U) -> Art[U] {
  self.engine.thunk(() => map(self.force()))
}
