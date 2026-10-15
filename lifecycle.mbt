///|
/// Release graph edges, cached values, closures, and typed memo/cell tables.
/// Call between computations when finished with an engine, especially on native
/// backends where reference cycles are not collected automatically.
/// Idempotent. Previously allocated handles may no longer be forced or edited.
pub fn Engine::dispose(self : Engine) -> Unit {
  guard executing_engine.val is None else {
    engine_abort("dispose is only allowed outside computations")
  }
  if !self.disposed {
    self.disposed = true
    for release in self.releases {
      release()
    }
    self.releases.clear()
    self.releases.shrink_to_fit()
    for node in self.nodes {
      node.deps.clear()
      node.deps.shrink_to_fit()
      node.users = Map([])
    }
    self.nodes.clear()
    self.nodes.shrink_to_fit()
    self.path.val = []
    self.current.val = None
  }
}
