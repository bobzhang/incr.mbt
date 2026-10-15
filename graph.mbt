///|
// Identities must never wrap and alias an older live engine or edge.
const COUNTER_MAX : Int64 = 9223372036854775807L

///|
fn next_counter(value : Int64) -> Int64 {
  if value == COUNTER_MAX {
    value
  } else {
    value + 1
  }
}

///|
priv enum Kind {
  Constant
  Cell
  Thunk
}

///|
priv struct Node {
  id : Int32
  kind : Kind
  path : Array[Name]
  mut dirty : Bool
  mut changed : Bool
  mut evaluating : Bool
  mut running : Bool
  deps : Array[Edge]
  mut users : Map[Int64, Edge]
}

///|
priv enum Effect {
  Observe
  Allocate
}

///|
priv struct Edge {
  id : Int64
  source : Node
  target : Node
  differs : () -> Bool
  immediate : Bool
  effect : Effect
}

///|
/// An independent, synchronous incremental computation graph.
/// Use one engine for all articulations in a computation.
pub struct Engine {
  priv mut disposed : Bool
  priv releases : Array[() -> Unit]
  priv naive : Bool
  priv id : Int64
  priv current : Ref[Node?]
  priv path : Ref[Array[Name]]
  priv nodes : Array[Node]
  priv mut next_edge : Int64
  priv mut evaluations : Int64
  priv mut cache_hits : Int64
  priv mut dirtyings : Int64
  priv mut cleanings : Int64
}

///|
let next_engine : Ref[Int64] = Ref(0)

///|
let executing_engine : Ref[Int64?] = Ref(None)

///|
pub fn Engine::Engine(naive~ : Bool = false) -> Engine {
  guard next_engine.val >= 0 && next_engine.val < COUNTER_MAX else {
    engine_abort("engine identity space exhausted")
  }
  let id = next_engine.val
  next_engine.val += 1
  {
    id,
    naive,
    disposed: false,
    releases: [],
    current: Ref(None),
    path: Ref([]),
    nodes: [],
    next_edge: 0,
    evaluations: 0,
    cache_hits: 0,
    dirtyings: 0,
    cleanings: 0,
  }
}

///|
fn Engine::check_context(self : Engine) -> Unit {
  guard !self.disposed else { engine_abort("engine has been disposed") }
  if executing_engine.val is Some(id) {
    guard id == self.id else {
      engine_abort("cannot mix incremental engines in a computation")
    }
  }
}

///|
fn Engine::node(self : Engine, kind : Kind) -> Node {
  self.check_context()
  let node = {
    id: self.nodes.length(),
    kind,
    path: self.path.val,
    dirty: false,
    changed: false,
    evaluating: false,
    running: false,
    deps: [],
    users: Map([]),
  }
  self.nodes.push(node)
  node
}

///|
fn Engine::observe(
  self : Engine,
  target : Node,
  differs : () -> Bool,
  immediate : Bool,
  effect : Effect,
) -> Unit {
  if self.current.val is Some(source) {
    guard self.next_edge >= 0 && self.next_edge < COUNTER_MAX else {
      engine_abort("dependency identity space exhausted")
    }
    let edge = {
      id: self.next_edge,
      source,
      target,
      differs,
      immediate,
      effect,
    }
    self.next_edge += 1
    source.deps.push(edge)
    target.users[edge.id] = edge
  }
}

///|
fn Node::detach(self : Node) -> Unit {
  for edge in self.deps {
    edge.target.users.remove(edge.id)
  }
  self.deps.clear()
  self.deps.shrink_to_fit()
}

///|
// Push invalidation through reverse edges without recursively walking the stack.
fn Engine::dirty_users(self : Engine, node : Node) -> Unit {
  let pending : Array[Node] = []
  for _, edge in node.users {
    if !edge.immediate || (edge.differs)() {
      pending.push(edge.source)
    }
  }
  while pending.pop() is Some(next) {
    guard !next.evaluating else {
      engine_abort(
        "a named allocation changed a dependency of an active computation",
      )
    }
    // Cleaning can trigger allocations that change an earlier observation.
    // The validating node must then rerun instead of accepting its old cache.
    if next.running {
      next.changed = true
    }
    if !next.dirty {
      next.dirty = true
      self.dirtyings = next_counter(self.dirtyings)
      for _, edge in next.users {
        // A dirty result affects observers, not callers that only allocated
        // this thunk. Its arguments have not changed in this propagation step.
        if edge.effect is Observe {
          pending.push(edge.source)
        }
      }
    }
  }
}

///|
/// Run a body inside a nested namespace. Lazy thunks retain their allocation path.
pub fn[T] Engine::ns(
  self : Engine,
  name : Name,
  body : () -> T raise?,
) -> T raise? {
  self.check_context()
  let path = self.path.val.copy()
  path.push(name)
  self.path.protect(path, body)
}

///|
// Panics abort the graph's use. Clear the global guard so an embedding that
// catches panics (such as the test runner) can still create independent engines.
fn[T] engine_abort(message : String) -> T {
  executing_engine.val = None
  abort(message)
}
