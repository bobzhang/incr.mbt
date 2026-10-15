///|
/// Cumulative counters. Evaluation counts count thunk bodies, not cell reads.
pub struct Stats {
  allocated : Int32
  evaluations : Int32
  cache_hits : Int32
  dirtyings : Int32
  cleanings : Int32
} derive(Eq, Debug)

///|
pub extend Stats with Eq::{equal, not_equal}

///|
pub extend Stats with Debug::{to_repr}

///|
pub fn Engine::stats(self : Engine) -> Stats {
  {
    allocated: self.nodes.length(),
    evaluations: self.evaluations,
    cache_hits: self.cache_hits,
    dirtyings: self.dirtyings,
    cleanings: self.cleanings,
  }
}
