///|
// Instrumentation only: the trace never influences a computed value.
fn[T] tracked(
  engine : @incr.Engine,
  trace : Array[String],
  label : String,
  compute : () -> T,
) -> @incr.Art[T] {
  engine.thunk(() => {
    trace.push(label)
    compute()
  })
}

///|
pub fn Session::Session() -> Session {
  let engine = @incr.Engine()
  let trace : Array[String] = []
  let depots = ["West Market", "Central Hub", "Harbor Depot"].map(label => {
    engine.cell(Depot::{ online: true, label, })
  })
  let traffic = [0, 0, 0].map(x => engine.cell(x))
  let fuel = engine.cell(150)
  let bridge = engine.cell(false)
  let region = engine.cell(-1)
  let routes = Array::makei(3, zone => {
    tracked(engine, trace, "route:\{zone}", () => {
      // Read fallbacks only when the preferred depot is unavailable.
      let mut depot = -1
      for offset in 0..<3 {
        let candidate = (zone + offset) % 3
        if depots[candidate].force_map(x => x.online) {
          depot = candidate
          break
        }
      }
      if depot < 0 {
        { depot: -1, minutes: 0, km: 0, detour: false, }
      } else {
        let detour = zone == 2 && bridge.force()
        let fallback = if depot == zone { 0 } else { 1 }
        {
          depot,
          minutes: 20 +
          zone * 4 +
          fallback * 12 +
          traffic[zone].force() +
          (if detour { 16 } else { 0 }),
          km: 8 + zone * 2 + fallback * 7 + (if detour { 8 } else { 0 }),
          detour,
        }
      }
    })
  })
  let shipments = shipments()
  let quotes = shipments.map(shipment => {
    tracked(engine, trace, "quote:\{shipment.id}", () => {
      let plan = routes[shipment.zone].force()
      if plan.depot < 0 {
        {
          id: shipment.id,
          zone: shipment.zone,
          cents: 0,
          minutes: 0,
          depot: -1,
          late: false,
        }
      } else {
        // Packaging and handling derive from all 16 manifest lines.
        let mut handling = 0
        for line, units in shipment.units {
          handling += units * (4 + line % 5) + (units + 2) / 3 * 7
        }
        let minutes = plan.minutes + shipment.id % 9
        {
          id: shipment.id,
          zone: shipment.zone,
          cents: 250 + handling + plan.km * fuel.force() / 10,
          minutes,
          depot: plan.depot,
          late: minutes > shipment.deadline,
        }
      }
    })
  })
  let summary = tracked(engine, trace, "summary", () => {
    let selected = region.force()
    let result : Array[Quote] = []
    for id, quote in quotes {
      if selected < 0 || id % 3 == selected {
        result.push(quote.force())
      }
    }
    result
  })
  {
    engine,
    depots,
    traffic,
    fuel,
    bridge,
    region,
    routes,
    summary,
    trace,
    shipments,
  }
}

///|
/// Edit inputs between demands. Values are range-checked at this boundary.
pub fn Session::update(
  self : Session,
  kind : Int32,
  index : Int32,
  value : Int32,
) -> Unit {
  match kind {
    0 => {
      guard index >= 0 && index < 3 && value >= 0 && value <= 60 else {
        abort("invalid traffic")
      }
      self.traffic[index].set(value)
    }
    1 => {
      guard value >= 50 && value <= 300 else { abort("invalid fuel price") }
      self.fuel.set(value)
    }
    2 => self.bridge.set(value != 0)
    3 => {
      guard index >= 0 && index < 3 else { abort("invalid depot") }
      let old = self.depots[index].force()
      self.depots[index].set({ online: value != 0, label: old.label, })
    }
    4 => {
      guard index >= 0 && index < 3 else { abort("invalid depot") }
      let old = self.depots[index].force()
      let base = ["West Market", "Central Hub", "Harbor Depot"][index]
      self.depots[index].set({
        online: old.online,
        label: if value == 0 {
          base
        } else {
          base + " · night shift"
        },
      })
    }
    5 => {
      guard value >= -1 && value < 3 else { abort("invalid region") }
      self.region.set(value)
    }
    _ => abort("unknown update")
  }
}

///|
pub fn Session::dispose(self : Session) -> Unit {
  self.engine.dispose()
}
