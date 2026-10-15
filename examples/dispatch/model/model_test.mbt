///|
test "dispatch demo measures real locality projection and equal writes" {
  let app = @model.Session()
  let initial = app.read()
  assert_true(initial.verified)
  assert_eq(initial.evaluations, 604L)
  assert_eq(initial.baseline_evaluations, 604)
  assert_eq(initial.graph_nodes, 613)
  app.update(1, 0, 150)
  assert_eq(app.read().evaluations, 0L)
  app.update(4, 1, 1)
  let renamed = app.read()
  assert_true(renamed.verified)
  assert_eq(renamed.evaluations, 0L)
  app.update(0, 0, 5)
  let changed = app.read()
  assert_true(changed.verified)
  assert_eq(changed.evaluations, 202L)
  assert_true(
    changed.evaluated.all(label => {
      label == "summary" || label == "route:0" || label.has_prefix("quote:")
    }),
  )
  app.update(1, 0, 175)
  let global = app.read()
  assert_true(global.verified)
  assert_eq(global.evaluations, 601L)
  app.dispose()
}

///|
test "hidden dispatch views defer their work until demanded" {
  let app = @model.Session()
  ignore(app.read())
  app.update(5, 0, 0)
  assert_eq(app.read().evaluations, 1L)
  app.update(2, 0, 1)
  let hidden = app.read()
  assert_true(hidden.verified)
  assert_eq(hidden.evaluations, 0L)
  assert_eq(hidden.quotes.length(), 200)
  assert_eq(hidden.plans[2].depot, -2)
  app.update(5, 0, 2)
  let revealed = app.read()
  assert_true(revealed.verified)
  assert_eq(revealed.evaluations, 202L)
  app.dispose()
}

///|
test "fallback depots change dependencies and suspended quotes ignore fuel" {
  let app = @model.Session()
  app.update(5, 0, 0)
  assert_true(app.read().verified)
  app.update(3, 1, 0)
  assert_eq(app.read().evaluations, 0L)
  app.update(3, 0, 0)
  let fallback = app.read()
  assert_true(fallback.verified)
  assert_eq(fallback.plans[0].depot, 2)
  app.update(3, 2, 0)
  let stopped = app.read()
  assert_true(stopped.verified)
  assert_eq(stopped.unavailable, 200)
  app.update(1, 0, 200)
  assert_eq(app.read().evaluations, 0L)
  app.update(3, 0, 1)
  let resumed = app.read()
  assert_true(resumed.verified)
  assert_eq(resumed.unavailable, 0)
  app.dispose()
}

///|
test "mixed dispatch edits match an independent evaluator with bounded graph size" {
  let app = @model.Session()
  for step in 0..<240 {
    let zone = step * 7 % 3
    match step % 8 {
      0 => app.update(0, zone, step * 11 % 61)
      1 => app.update(1, 0, 50 + step * 17 % 251)
      2 => app.update(2, 0, step / 8 % 2)
      3 => app.update(3, zone, step / 8 % 2)
      4 => app.update(4, zone, step / 8 % 2)
      5 => app.update(5, 0, step / 8 % 4 - 1)
      6 => app.update(3, zone, 1)
      _ => app.update(0, zone, 0)
    }
    let report = app.read()
    assert_true(report.verified, msg="dispatch mismatch at step \{step}")
    assert_eq(report.graph_nodes, 613)
    assert_true(report.evaluations <= report.baseline_evaluations.to_int64())
  }
  app.dispose()
}
