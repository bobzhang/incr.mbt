///|
// Independent from-scratch evaluator: ordinary values, no Art/force or graph.
fn fresh(
  inputs : Inputs,
  shipments : Array[Shipment],
) -> (Array[Quote], Array[Plan], Int32) {
  let plans : Array[Plan] = []
  let mut work = 1 // summary evaluation
  for zone in 0..<3 {
    if inputs.region >= 0 && zone != inputs.region {
      plans.push({ depot: -2, minutes: 0, km: 0, detour: false, })
      continue
    }
    work += 1
    let candidates = [zone, (zone + 1) % 3, (zone + 2) % 3]
    let available = candidates.filter(id => inputs.depots[id].online)
    if available.is_empty() {
      plans.push({ depot: -1, minutes: 0, km: 0, detour: false, })
    } else {
      let chosen = available[0]
      let mut minutes = [20, 24, 28][zone] + inputs.traffic[zone]
      let mut km = [8, 10, 12][zone]
      if chosen != zone {
        minutes += 12
        km += 7
      }
      if zone == 2 && inputs.bridge_closed {
        minutes += 16
        km += 8
      }
      plans.push({
        depot: chosen,
        minutes,
        km,
        detour: zone == 2 && inputs.bridge_closed,
      })
    }
  }
  let result : Array[Quote] = []
  for shipment in shipments {
    if inputs.region >= 0 && shipment.zone != inputs.region {
      continue
    }
    work += 1
    let plan = plans[shipment.zone]
    let mut cents = 0
    let mut minutes = 0
    if plan.depot >= 0 {
      cents = 250 + plan.km * inputs.fuel / 10
      for line, count in shipment.units {
        cents += count * [4, 5, 6, 7, 8][line % 5]
        cents += (count / 3 + (if count % 3 == 0 { 0 } else { 1 })) * 7
      }
      minutes = plan.minutes + shipment.id % 9
    }
    result.push({
      id: shipment.id,
      zone: shipment.zone,
      cents,
      minutes,
      depot: plan.depot,
      late: plan.depot >= 0 && minutes > shipment.deadline,
    })
  }
  (result, plans, work)
}

///|
/// Demand the selected service areas, then compare every result to the oracle.
pub fn Session::read(self : Session) -> Report {
  self.trace.clear()
  let before = self.engine.stats()
  let quotes = self.summary.force()
  // Only expose demanded plans; inspecting hidden plans must not force them.
  let selected = self.region.force()
  let plans = self.routes.mapi((zone, plan) => {
    if selected < 0 || zone == selected {
      plan.force()
    } else {
      { depot: -2, minutes: 0, km: 0, detour: false, }
    }
  })
  let after = self.engine.stats()
  let inputs = Inputs::{
    depots: self.depots.map(x => x.force()),
    traffic: self.traffic.map(x => x.force()),
    fuel: self.fuel.force(),
    bridge_closed: self.bridge.force(),
    region: selected,
  }
  let (expected, expected_plans, baseline_evaluations) = fresh(
    inputs,
    self.shipments,
  )
  let mut total_cents = 0
  let mut late = 0
  let mut unavailable = 0
  for q in quotes {
    total_cents += q.cents
    if q.late {
      late += 1
    }
    if q.depot < 0 {
      unavailable += 1
    }
  }
  {
    inputs,
    quotes,
    plans,
    evaluated: self.trace.copy(),
    evaluations: after.evaluations - before.evaluations,
    baseline_evaluations,
    cache_hits: after.cache_hits - before.cache_hits,
    graph_nodes: after.allocated,
    verified: quotes == expected &&
    plans == expected_plans &&
    after.evaluations - before.evaluations == self.trace.length().to_int64(),
    total_cents,
    late,
    unavailable,
  }
}
