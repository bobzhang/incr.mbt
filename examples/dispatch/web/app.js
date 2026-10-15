import {reset, update} from './engine.js';

const $ = id => document.getElementById(id);
const zones = ['West', 'Central', 'East'];
const zoneColors = ['#8ab5ff', '#c4abff', '#ffcc8f'];
const money = cents => new Intl.NumberFormat('en-US', {style:'currency', currency:'USD', maximumFractionDigits:2}).format(cents/100);
const escape = value => String(value).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let report, actionNumber = 0, storyToken = 0, playing = false, renamed = false;
const history = [];

function showError(error) {
  const box = $('error'); box.hidden = false;
  box.textContent = `The demo stopped: ${error.message || error}. Reset to try again.`;
  console.error(error);
}

function stopStory() {
  storyToken++; playing = false;
  $('story').textContent = '▶ Play the 5-step story';
}

function accept(raw, event) {
  const next = JSON.parse(raw);
  // MoonBit serializes Int64 counters as decimal strings. Each per-action
  // evaluation delta is bounded by this demo’s 604 computation nodes.
  next.evaluations = Number(next.evaluations);
  if (!Number.isSafeInteger(next.evaluations)) throw new Error('Invalid evaluation count.');
  if (!next.verified) throw new Error('Incremental results did not match the independent evaluator.');
  if (next.evaluations !== next.evaluated.length) throw new Error('Trace and engine counters disagree.');
  report = next; actionNumber++;
  history.push({title:event.title, evaluated:next.evaluations, baseline:next.baseline_evaluations, verified:next.verified});
  if (history.length > 100) history.shift();
  render(event);
}

function change(kind, index, value, event) { accept(update(kind,index,value), event); }
function start() {
  renamed = false; $('error').hidden = true;
  accept(reset(), {kicker:'COLD START', title:'First demand: build the delivery plan once.', detail:'All 600 quotes, three route plans, and the summary run. Now change one input and watch the cache do its job.'});
}

function render(event) {
  const activeId = document.activeElement?.id;
  const r = report, selected = r.inputs.region;
  const ran = new Set(r.evaluated);
  const reuse = Math.max(0,100*(1-r.evaluations/r.baseline_evaluations));
  $('rerun').textContent = r.evaluations;
  $('baseline').textContent = ` / ${r.baseline_evaluations}`;
  $('reuse').textContent = `${reuse.toFixed(reuse===100 || reuse===0 ? 0 : 1)}%`;
  $('reuse-bar').style.width = `${reuse}%`;
  $('total').textContent = money(r.total_cents);
  $('order-count').textContent = `${r.quotes.length} demanded deliveries · ${r.quotes.length*16} manifest lines`;
  $('verified').textContent = '✓ Every result matches';
  $('verify-detail').textContent = `${r.quotes.length} quotes + ${selected<0?3:1} route plans checked`;
  $('late').textContent = r.late; $('unavailable').textContent = r.unavailable;
  $('graph-size').textContent = `${r.graph_nodes} graph nodes`;
  $('event-kicker').textContent = event.kicker;
  $('event-title').textContent = event.title;
  $('event-detail').textContent = event.detail;
  $('event-sequence').textContent = String(actionNumber).padStart(2,'0');
  $('bridge-status').textContent = r.inputs.bridge_closed ? 'DETOUR' : 'OPEN';
  $('bridge-status').className = `tag${r.inputs.bridge_closed?' closed':''}`;
  $('bridge-toggle').className = `wide-button${r.inputs.bridge_closed?' closed':''}`;
  $('bridge-toggle').innerHTML = `${r.inputs.bridge_closed?'Reopen the bridge':'Close the bridge'} <span>↗</span>`;
  $('fuel').value = r.inputs.fuel; $('fuel-value').textContent = money(r.inputs.fuel);
  $('rename').innerHTML = `${renamed?'Restore depot name':'Rename Central Hub'} <span>↗</span>`;
  document.querySelectorAll('[data-action="region"]').forEach(button => button.setAttribute('aria-pressed',Number(button.dataset.value)===selected));
  $('depot-controls').innerHTML = r.inputs.depots.map((depot,i)=>`<div class="depot-control"><div class="depot-row"><span class="zone-dot zone-${i}"></span><span class="depot-label">${escape(depot.label)}</span><button id="depot-${i}" class="toggle ${depot.online?'':'off'}" data-action="depot" data-index="${i}" aria-pressed="${depot.online}" aria-label="${zones[i]} depot available">${depot.online?'ONLINE':'OFFLINE'}</button></div><div class="traffic-row"><label for="traffic-${i}">Traffic</label><input type="range" id="traffic-${i}" data-traffic="${i}" min="0" max="60" step="5" value="${r.inputs.traffic[i]}" aria-label="${zones[i]} traffic delay in minutes"><output for="traffic-${i}">+${r.inputs.traffic[i]}</output></div></div>`).join('');
  $('quote-grids').innerHTML = zones.map((zone,z)=>{
    const demanded = selected<0 || selected===z;
    const count = Array.from({length:200},(_,i)=>i*3+z).filter(id=>ran.has(`quote:${id}`)).length;
    return `<div><div class="grid-header"><span><i class="zone-dot zone-${z}"></i> ${zone}</span><small>${demanded?`${count} / 200 rerun`:'Not demanded'}</small></div><div class="tiles" aria-label="${zone}: ${demanded?count+' of 200 quote bodies evaluated':'not demanded'}">${Array.from({length:200},(_,i)=>{const id=i*3+z;return `<span class="tile ${!demanded?'hidden':ran.has('quote:'+id)?'ran':''}" title="Shipment D-${String(id+1).padStart(4,'0')}: ${!demanded?'not demanded':ran.has('quote:'+id)?'recalculated':'cached'}"></span>`;}).join('')}</div></div>`;
  }).join('');
  renderMap(r,ran);
  $('manifest-count').textContent = `FIRST 12 OF ${r.quotes.length} DEMANDED DELIVERIES`;
  $('manifest-body').innerHTML = r.quotes.slice(0,12).map(q=>`<tr><td class="shipment-id">D-${String(q.id+1).padStart(4,'0')}</td><td><span class="zone-dot zone-${q.zone}"></span> ${zones[q.zone]}</td><td>${q.depot<0?'Unassigned':escape(r.inputs.depots[q.depot].label)}</td><td class="${q.late?'eta-late':''}">${q.depot<0?'—':q.minutes+' min'+(q.late?' · at risk':'')}</td><td>${q.depot<0?'—':money(q.cents)}</td><td class="${ran.has('quote:'+q.id)?'state-ran':'state-cached'}">${ran.has('quote:'+q.id)?'↻ Recalculated':'✓ Cached'}</td></tr>`).join('');
  if(activeId) $(activeId)?.focus({preventScroll:true});
  // Read-only diagnostics for tests and curious readers. No control over engine state.
  window.dispatchDemo = Object.freeze({get report(){return JSON.parse(JSON.stringify(report));},get history(){return history.slice();}});
}

function renderMap(r,ran) {
  const parts = [`<defs><linearGradient id="water" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#1b3e50"/><stop offset="1" stop-color="#15303d"/></linearGradient><pattern id="map-grid" width="30" height="30" patternUnits="userSpaceOnUse"><path d="M30 0H0V30" fill="none" stroke="#1e2e3e" stroke-width=".6"/></pattern></defs><rect width="900" height="400" fill="#0f1c29"/><rect width="900" height="400" fill="url(#map-grid)"/>`];
  for(let z=0;z<3;z++){
    const left=[48,338,648][z];
    for(let row=0;row<5;row++)for(let col=0;col<5;col++){
      parts.push(`<rect x="${left+col*40}" y="${65+row*51}" width="28" height="35" rx="4" fill="#172a39" stroke="#203343" stroke-width=".7"/>`);
    }
  }
  parts.push(`<path d="M607 -20 C567 80 652 128 608 204 S590 320 631 425" fill="none" stroke="url(#water)" stroke-width="43"/><path d="M12 210H888 M301 35V376 M35 343H865 M32 42H858" stroke="#344759" stroke-width="8" fill="none"/><path d="M12 210H888 M301 35V376 M35 343H865 M32 42H858" stroke="#8192a2" stroke-opacity=".24" stroke-width="1" stroke-dasharray="5 8" fill="none"/>`);
  parts.push(`<text x="614" y="100" transform="rotate(77 614 100)" font-size="9" fill="#608a9e" letter-spacing="3">NORTH RIVER</text>`);
  const depots=[[140,290],[430,90],[770,290]], centers=[[175,195],[450,220],[745,190]];
  for(let z=0;z<3;z++){
    const demanded=r.inputs.region<0||r.inputs.region===z,plan=r.plans[z];
    parts.push(`<text x="${[60,348,658][z]}" y="26" fill="${zoneColors[z]}" opacity="${demanded?'.85':'.35'}" font-size="10" letter-spacing="2.5">${zones[z].toUpperCase()} DISTRICT</text>`);
    if(demanded&&plan.depot>=0){
      const [x,y]=depots[plan.depot],[tx,ty]=centers[z];
      const path=plan.detour?`M${x} ${y} L${x} 343 L${tx} 343 L${tx} ${ty}`:`M${x} ${y} Q${(x+tx)/2+30} ${Math.min(y,ty)-60} ${tx} ${ty}`;
      parts.push(`<path d="${path}" fill="none" stroke="${ran.has('route:'+z)?'#ffb56b':zoneColors[z]}" stroke-opacity=".55" stroke-width="2" stroke-dasharray="5 5"/>`);
    }
    for(let i=0;i<200;i++){
      const id=i*3+z,x=[54,344,654][z]+(i*37%211),y=65+(i*61%255);
      const color=!demanded?'#425366':ran.has('quote:'+id)?'#ffb56b':'#72e3b4';
      parts.push(`<circle cx="${x}" cy="${y}" r="${demanded?1.9:1.4}" fill="${color}" opacity="${demanded ? .85 : .3}"/>`);
    }
  }
  depots.forEach(([x,y],i)=>{
    const online=r.inputs.depots[i].online;
    parts.push(`<circle cx="${x}" cy="${y}" r="24" fill="#0c1925" opacity=".9"/><circle cx="${x}" cy="${y}" r="16" fill="${online?'#273e50':'#28313a'}" stroke="${online?zoneColors[i]:'#596674'}" stroke-width="1.5"/><path d="M${x-6} ${y+5}v-9l6-4 6 4v9h-4v-5h-4v5z" fill="${online?zoneColors[i]:'#75808c'}"/><rect x="${x-56}" y="${y+28}" width="112" height="19" rx="4" fill="#0b1824"/><text x="${x}" y="${y+41}" text-anchor="middle" font-size="8" fill="#ced9e4">${zones[i]} · ${online?'available':'offline'}</text>`);
  });
  parts.push(`<rect x="578" y="201" width="58" height="18" rx="4" fill="${r.inputs.bridge_closed?'#6d4430':'#314c53'}" stroke="${r.inputs.bridge_closed?'#ffb56b':'#72e3b4'}"/><text x="607" y="214" text-anchor="middle" fill="${r.inputs.bridge_closed?'#ffca91':'#96dfc5'}" font-size="9">${r.inputs.bridge_closed?'CLOSED':'BRIDGE'}</text><text x="848" y="380" text-anchor="end" font-size="8" fill="#657f93" letter-spacing="1">600 SHIPMENTS / SCHEMATIC</text>`);
  $('city-map').innerHTML=parts.join('');
}

const delay=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function story(){
  if(playing){stopStory();return;}
  stopStory();playing=true;const token=storyToken;$('story').textContent='■ Stop story';start();
  const steps=[
    ()=>change(2,0,1,{kicker:'01 / LOCAL INVALIDATION',title:'One bridge closes. Two districts keep their cache.',detail:'Only the east route, its 200 quotes, and the selected-view summary rerun: 202 of 604 calculations.'}),
    ()=>{renamed=true;change(4,1,1,{kicker:'02 / PROJECTION',title:'A new depot name. Zero new quotes.',detail:'Routes observe availability, not the label. The UI shows the new name while all quote calculations stay cached.'});},
    ()=>change(5,0,0,{kicker:'03 / CHOOSE WHAT TO DEMAND',title:'Open the West view. Its quotes are already cached.',detail:'Only the summary changes. East and Central are now outside the demanded result.'}),
    ()=>change(0,2,25,{kicker:'04 / DEFER HIDDEN WORK',title:'East traffic gets worse. West does no extra work.',detail:'East is dirty, but hidden. No route or quote body runs until that service area is demanded.'}),
    ()=>change(5,0,2,{kicker:'05 / RECOMPUTE ON DEMAND',title:'Open East. Its delayed work catches up now.',detail:'The engine computes the east route and 200 quotes from the latest inputs. Every result still matches the independent full evaluation.'})
  ];
  for(const step of steps){await delay(2400);if(token!==storyToken)return;step();}
  if(token===storyToken){playing=false;$('story').textContent='↻ Replay the 5-step story';}
}

document.addEventListener('click',event=>{
  const button=event.target.closest('button[data-action]');if(!button)return;
  try{
    const action=button.dataset.action;
    if(action==='story'){story().catch(showError);return;}
    stopStory();
    if(action==='reset'){start();return;}
    if(action==='bridge')change(2,0,report.inputs.bridge_closed?0:1,{kicker:'ROAD NETWORK',title:report.inputs.bridge_closed?'The east bridge reopens.':'A detour changes eastbound plans.',detail:'Only consumers of the east route need new results. If East is hidden, that work waits until it is demanded.'});
    if(action==='region'){const region=Number(button.dataset.value);change(5,0,region,{kicker:'DEMAND-DRIVEN VIEW',title:region<0?'All three service areas are now demanded.':`${zones[region]} is the only demanded service area.`,detail:'Cached results are reused. Dirty or never-computed results run only when this view asks for them.'});}
    if(action==='depot'){const i=Number(button.dataset.index),online=report.inputs.depots[i].online;change(3,i,online?0:1,{kicker:'DYNAMIC DEPENDENCIES',title:`${zones[i]} depot goes ${online?'offline':'online'}.`,detail:'A route reads fallback depot availability only when it needs a fallback. Unrelated routes keep their existing dependencies.'});}
    if(action==='rename'){renamed=!renamed;change(4,1,renamed?1:0,{kicker:'PROJECTED OBSERVATION',title:'A label changes. Availability stays the same.',detail:'The route graph observes only the online flag. No pricing computation needs the depot name, so the label can change without recalculation.'});}
    if(action==='equal')change(1,0,report.inputs.fuel,{kicker:'EQUAL INPUT',title:'Same fuel price. Nothing to invalidate.',detail:'Writing an equal input leaves the cached graph valid. The independent evaluator still checks every demanded result.'});
  }catch(error){stopStory();showError(error);}
});
document.addEventListener('input',event=>{
  if(event.target.id==='fuel')$('fuel-value').textContent=money(Number(event.target.value));
  if(event.target.hasAttribute('data-traffic'))event.target.nextElementSibling.value='+'+event.target.value;
});
document.addEventListener('change',event=>{
  try{
    if(event.target.id==='fuel'){stopStory();change(1,0,Number(event.target.value),{kicker:'SHARED DEPENDENCY',title:'Fuel changes the economics of every active delivery.',detail:'Active quotes depend on fuel, so they rerun. Route geometry stays cached. Incremental computation saves only work whose inputs still apply.'});}
    if(event.target.hasAttribute('data-traffic')){stopStory();const zone=Number(event.target.dataset.traffic);change(0,zone,Number(event.target.value),{kicker:'LOCAL TRAFFIC',title:`${zones[zone]} travel times change.`,detail:'Only that area’s route and quotes need updating. Other service areas reuse their previous calculations.'});}
  }catch(error){stopStory();showError(error);}
});
window.addEventListener('pagehide',stopStory);
try{start();}catch(error){showError(error);}
