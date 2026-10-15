///|
/// Fictional shipment data; distances and prices are deliberately deterministic.
pub struct Shipment {
  id : Int32
  zone : Int32
  units : Array[Int32]
  deadline : Int32
} derive(Eq, ToJson)

///|
pub struct Depot {
  online : Bool
  label : String
} derive(Eq, ToJson)

///|
pub struct Plan {
  depot : Int32
  minutes : Int32
  km : Int32
  detour : Bool
} derive(Eq, ToJson)

///|
pub struct Quote {
  id : Int32
  zone : Int32
  cents : Int32
  minutes : Int32
  depot : Int32
  late : Bool
} derive(Eq, ToJson)

///|
pub struct Inputs {
  depots : Array[Depot]
  traffic : Array[Int32]
  fuel : Int32
  bridge_closed : Bool
  region : Int32
} derive(ToJson)

///|
pub struct Report {
  inputs : Inputs
  quotes : Array[Quote]
  plans : Array[Plan]
  evaluated : Array[String]
  evaluations : Int64
  baseline_evaluations : Int32
  cache_hits : Int64
  graph_nodes : Int32
  verified : Bool
  total_cents : Int32
  late : Int32
  unavailable : Int32
} derive(ToJson)

///|
pub struct Session {
  priv engine : @incr.Engine
  priv depots : Array[@incr.Art[Depot]]
  priv traffic : Array[@incr.Art[Int32]]
  priv fuel : @incr.Art[Int32]
  priv bridge : @incr.Art[Bool]
  priv region : @incr.Art[Int32]
  priv routes : Array[@incr.Art[Plan]]
  priv summary : @incr.Art[Array[Quote]]
  priv trace : Array[String]
  priv shipments : Array[Shipment]
}

///|
fn shipments() -> Array[Shipment] {
  Array::makei(600, id => {
    id,
    zone: id % 3,
    units: Array::makei(16, line => 1 + (id * 17 + line * 7) % 9),
    deadline: 35 + id % 35,
  })
}

///|
pub extend Shipment with Eq::{equal, not_equal}

///|
pub extend Depot with Eq::{equal, not_equal}

///|
pub extend Plan with Eq::{equal, not_equal}

///|
pub extend Quote with Eq::{equal, not_equal}

///|
pub extend Shipment with ToJson::{to_json}

///|
pub extend Depot with ToJson::{to_json}

///|
pub extend Plan with ToJson::{to_json}

///|
pub extend Quote with ToJson::{to_json}

///|
pub extend Inputs with ToJson::{to_json}

///|
pub extend Report with ToJson::{to_json}
