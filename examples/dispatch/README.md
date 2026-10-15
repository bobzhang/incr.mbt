# Dispatch: a city that only recalculates what changed

An interactive delivery operations dashboard backed by the real `dii/incr`
MoonBit engine, compiled to JavaScript. A fictional city has 600 shipments,
9,600 manifest lines, three depots, traffic delays, fuel pricing, and a bridge
that can close. Change an input and see exactly which cached calculations rerun.

## Open it

From the repository root, with MoonBit and Python 3 installed:

```sh
python3 examples/dispatch/build.py
open _build/dispatch/index.html  # macOS; otherwise open this file in your browser
```

The output is **one portable HTML file** with the compiled MoonBit engine,
JavaScript UI, styles, and SVG map embedded. No server, package installation,
or network connection is needed. You can send that file to someone else.
For a localhost preview, including browsers that restrict opening local files:

```sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory _build/dispatch
```

Open `http://127.0.0.1:8765`, then press **Play the 5-step story**.

## What to demonstrate

Starting from Reset, the guided story produces these actual engine counts:

| Action | Incremental calculations | Full evaluation of selected view | Lesson |
| --- | ---: | ---: | --- |
| First demand | 604 | 604 | Pay once to fill the cache |
| Close the East bridge | 202 | 604 | Only East's route, 200 quotes, and summary rerun |
| Rename Central Hub | 0 | 604 | Availability projection ignores label changes |
| Select West | 1 | 202 | Quotes are cached; only the summary changes |
| Increase hidden East traffic | 0 | 202 | Dirty work waits until demanded |
| Select East | 202 | 202 | Compute deferred work from the latest inputs |

Orange tiles and map dots identify quote bodies that actually ran. Mint means
cached; gray means outside the demanded view. Try fuel changes to see a shared
input affect all active quotes, or take depots offline to change fallback
dependencies. Writing the same fuel price performs no new calculations.

## How it works

The graph has a fixed 613 nodes: nine input cells, three route thunks, 600 quote
thunks, and a selected-view summary thunk. Routes read only the depot availability
flags they need. Quotes read fuel only when a depot is available. The summary
forces only the selected service areas. The engine discovers dependencies while
these ordinary functions execute; the UI does not manually invalidate anything.

- [model/engine.mbt](model/engine.mbt): cells, projections, dynamic branches, thunks.
- [model/oracle.mbt](model/oracle.mbt): independent full evaluator and verification.
- [model/model_test.mbt](model/model_test.mbt): precise work counts, branch changes,
  hidden demand, and 240 mixed edits checked against the oracle.
- [bridge/bridge.mbt](bridge/bridge.mbt): exported reset/update functions and JSON.
- [web/app.js](web/app.js): controls, guided story, and rendering. It contains no
  pricing or route calculation logic. MoonBit's Int64 JSON counters are converted
  to numbers only for bounded per-action evaluation counts.

The trace is instrumentation only: thunk bodies append their label when run;
no computation reads that trace. The reported count also has to equal the actual
`Engine.stats().evaluations` delta. Every action checks all demanded quote and
route values against the independent plain evaluator. Reset disposes the old
engine before creating a fresh one.

This demonstrates avoided **computation bodies**, not a measured speedup.
Bodies have different costs, and invalidation, dependency checking, serialization,
UI rendering, and the always-on full correctness check also take work. The plain
baseline shares one route calculation per area, just as the incremental model
does. There are no artificial slowdowns. The map and data are synthetic; this is
service-area dispatch/pricing, not a global vehicle-routing optimizer.

## Verify

```sh
moon test examples/dispatch/model --target all
python3 examples/dispatch/build.py
node examples/dispatch/check.mjs
```

The last command exercises the exact module embedded in the generated HTML,
checks the guided scenario counts, and repeats reset/disposal five times. CI runs
it in addition to the MoonBit tests. Browser verification over localhost covered the five-step story, reset, bridge
and rename buttons, fuel and traffic sliders, hidden demand, and desktop/narrow
layouts. The automated preview browser blocks `file:` URLs, so direct file
opening was not exercised there.
