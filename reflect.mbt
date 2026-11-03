///|
/// A detached graph snapshot. Dependencies retain their observation order.
/// Values are intentionally omitted so reflection works across all result types.
#derive(Eq, Debug)
pub struct NodeInfo {
  id : Int32
  kind : String
  path : Array[Name]
  dirty : Bool
  dependencies : Array[Int32]
}

///|
pub extend NodeInfo with Eq::{equal, not_equal}

///|
pub extend NodeInfo with Debug::{to_repr}

///|
pub fn Engine::snapshot(self : Engine) -> Array[NodeInfo] {
  self.nodes.map(node => {
    id: node.id,
    kind: match node.kind {
      Constant => "constant"
      Cell => "cell"
      Thunk => "thunk"
    },
    path: node.path.copy(),
    dirty: node.dirty,
    dependencies: node.deps.map(edge => edge.target.id),
  })
}
