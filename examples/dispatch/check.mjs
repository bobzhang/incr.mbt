// Run after: python3 examples/dispatch/build.py
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

// Import the actual embedded module, so this also checks the portable build.
const html = readFileSync(new URL('../../_build/dispatch/index.html', import.meta.url), 'utf8');
const moduleUrl = html.match(/from '(data:text\/javascript;base64,[A-Za-z0-9+/=]+)'/)[1];
const {reset, update} = await import(moduleUrl);
assert(!html.includes('src="app.js"'));
assert(!html.includes('href="style.css"'));

function check(raw, count, baseline = 604) {
  const report = JSON.parse(raw);
  assert.equal(report.verified, true);
  // MoonBit Int64 values are decimal strings across the JSON boundary.
  assert.equal(Number(report.evaluations), count);
  assert.equal(report.evaluated.length, count);
  assert.equal(report.baseline_evaluations, baseline);
  assert.equal(report.graph_nodes, 613);
  return report;
}
for (let cycle = 0; cycle < 5; cycle++) {
  check(reset(), 604);
  const bridge = check(update(2, 0, 1), 202);
  assert.equal(bridge.evaluated.filter(x => x.startsWith('quote:')).length, 200);
  assert(bridge.evaluated.filter(x => x.startsWith('quote:')).every(x => Number(x.slice(6)) % 3 === 2));
  check(update(4, 1, 1), 0); // Projection: rename does not affect availability.
  check(update(5, 0, 0), 1, 202);
  check(update(0, 2, 25), 0, 202); // Hidden East remains lazy.
  check(update(5, 0, 2), 202, 202);
  check(update(1, 0, 150), 0, 202); // Equal input.
  check(update(1, 0, 175), 201, 202); // Fuel changes quotes, not routes.
}
console.log('Dispatch: embedded MoonBit module, guided scenarios, and five reset cycles passed.');
