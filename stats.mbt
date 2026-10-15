///|
/// Cumulative 64-bit event counters, saturating at Int64 maximum.
/// Evaluation counts count thunk bodies, not cell reads.
/// `allocated` is the current graph node count and remains a 32-bit array size.
pub struct Stats {
  allocated : Int32
  evaluations : Int64
  cache_hits : Int64
  dirtyings : Int64
  cleanings : Int64
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
