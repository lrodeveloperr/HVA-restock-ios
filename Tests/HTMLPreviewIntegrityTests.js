const assert = require('assert');
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const htmlPath = path.join(__dirname, '..', 'HVAC-Restock-iOS-Full-Preview.html');
const html = fs.readFileSync(htmlPath, 'utf8');
const match = html.match(/<script>([\s\S]*?)<\/script>/);
assert(match, 'The preview must contain one executable script.');

const tests = `
rerender = () => {};
let lastToast = '';
toast = (_device, message) => { lastToast = message; };

const test = (name, body) => {
  body();
  globalThis.__passes.push(name);
};

test('hostile HTML is escaped in cards and form attributes', () => {
  const hostile = {id:77,name:'<img src=x onerror=alert(1)>',part:'\" autofocus',cat:'Other',loc:'<&',qty:1,at:0,to:2};
  const markup = card(hostile, 'phone');
  assert(!markup.includes('<img src=x'));
  assert(markup.includes('&lt;img'));
  assert(h('\"<&') === '&quot;&lt;&amp;');
});

test('monotonic IDs cannot collide during rapid actions', () => {
  const ids = new Set(Array.from({length:10000}, () => newID()));
  assert.strictEqual(ids.size, 10000);
});

test('quantity arithmetic rejects both boundaries', () => {
  assert.strictEqual(safeAdd(0, -1), null);
  assert.strictEqual(safeAdd(MAX_QUANTITY, 1), null);
  assert.strictEqual(safeAdd(1, -1), 0);
});

test('use and add refuse impossible stock changes', () => {
  resetPreview('phone');
  const out = items.find(item => item.id === 3);
  const beforeEvents = events.length;
  useOne('phone', out.id);
  assert.strictEqual(out.qty, 0);
  assert.strictEqual(events.length, beforeEvents);
  out.qty = MAX_QUANTITY;
  addOne('phone', out.id);
  assert.strictEqual(out.qty, MAX_QUANTITY);
  assert.strictEqual(events.length, beforeEvents);
});

test('reversal uses immutable item ID even after a rename', () => {
  resetPreview('phone');
  const item = items.find(item => item.id === 1);
  const event = events.find(event => event.id === 102);
  item.name = 'Renamed capacitor';
  reverseEvent('phone', event.id);
  assert.strictEqual(item.qty, 2);
  assert.strictEqual(event.reversed, true);
  const afterFirst = events.length;
  reverseEvent('phone', event.id);
  assert.strictEqual(events.length, afterFirst);
});

test('deleted-item and impossible reversals are unavailable', () => {
  resetPreview('phone');
  const event = events.find(event => event.id === 101);
  items = items.filter(item => item.id !== event.itemID);
  assert.strictEqual(canReverse(event), false);
  const stocked = events.find(event => event.id === 103);
  assert.strictEqual(canReverse(stocked), false);
});

test('duplicate keys ignore case, whitespace, and accents', () => {
  const first = {name:'  Fusé ',part:'ABC',cat:'Fuse',loc:'Bin 1'};
  const second = {name:'fuse',part:'abc',cat:'Fuse',loc:'bin 1'};
  assert.strictEqual(duplicateKey(first), duplicateKey(second));
});

test('import limit is derived from actual duplicate keys', () => {
  resetPreview('phone');
  const plan = importAnalysis();
  assert.deepStrictEqual(plan, {duplicates:1,newCount:2,blocked:true});
});

test('unlock returns to the interrupted import', () => {
  resetPreview('phone');
  ui.phone.modal = 'import';
  requestImportUnlock('phone');
  assert.strictEqual(ui.phone.modal, 'unlock');
  purchasePreview('phone');
  assert.strictEqual(ui.phone.modal, 'import');
  assert.strictEqual(unlocked, true);
});

test('repeated imports merge instead of duplicating records', () => {
  resetPreview('phone');
  unlocked = true;
  applyImport('phone');
  assert.strictEqual(items.length, 11);
  assert.strictEqual(items.find(item => item.id === 1).qty, 3);
  assert.strictEqual(new Set(items.map(duplicateKey)).size, items.length);
  applyImport('phone');
  assert.strictEqual(items.length, 11);
  assert.strictEqual(items.find(item => item.id === 1).qty, 5);
});

test('failed import is atomic', () => {
  const fuse = items.find(item => duplicateKey(item) === duplicateKey(importRows[1]));
  fuse.qty = MAX_QUANTITY;
  const capacitorBefore = items.find(item => item.id === 1).qty;
  const eventCountBefore = events.length;
  applyImport('phone');
  assert.strictEqual(items.find(item => item.id === 1).qty, capacitorBefore);
  assert.strictEqual(events.length, eventCountBefore);
});

test('every tab and modal renders without a state exception', () => {
  resetPreview('phone');
  for (const device of ['phone', 'tablet']) {
    for (const tab of ['stock', 'restock', 'activity']) {
      ui[device].tab = tab;
      ui[device].modal = null;
      render(device);
    }
    for (const modalName of ['settings', 'unlock', 'import']) {
      ui[device].modal = modalName;
      render(device);
    }
    ui[device].edit = null;
    ui[device].modal = 'edit';
    render(device);
    ui[device].edit = items[0].id;
    render(device);
    ui[device].modal = 'stock';
    render(device);
  }
});

test('free limit is enforced again at commit time', () => {
  resetPreview('phone');
  const originalLookup = document.getElementById;
  const fields = {
    'phone-name': {value:'New relay'},
    'phone-part': {value:'REL-1'},
    'phone-cat': {value:'Other'},
    'phone-loc': {value:'Bin Z'},
    'phone-qty': {textContent:'1'},
    'phone-at': {textContent:'0'},
    'phone-to': {textContent:'2'}
  };
  document.getElementById = id => fields[id] || originalLookup(id);
  ui.phone.modal = 'edit';
  ui.phone.edit = null;
  saveItem('phone');
  assert.strictEqual(items.length, FREE_LIMIT);
  fields['phone-name'].value = 'Another relay';
  ui.phone.modal = 'edit';
  ui.phone.edit = null;
  saveItem('phone');
  assert.strictEqual(items.length, FREE_LIMIT);
  assert.strictEqual(ui.phone.modal, 'unlock');
  document.getElementById = originalLookup;
});

test('duplicate validation is enforced at commit time', () => {
  resetPreview('phone');
  const originalLookup = document.getElementById;
  const source = items[0];
  const fields = {
    'phone-name': {value:'  ' + source.name.toUpperCase() + '  '},
    'phone-part': {value:source.part.toLowerCase()},
    'phone-cat': {value:source.cat},
    'phone-loc': {value:source.loc.toLowerCase()},
    'phone-qty': {textContent:'1'},
    'phone-at': {textContent:'1'},
    'phone-to': {textContent:'4'}
  };
  document.getElementById = id => fields[id] || originalLookup(id);
  ui.phone.modal = 'edit';
  ui.phone.edit = null;
  saveItem('phone');
  assert.strictEqual(items.length, seed.length);
  assert.strictEqual(lastToast, 'That item already exists');
  document.getElementById = originalLookup;
});

test('CSV fields neutralize spreadsheet formulas and quote delimiters', () => {
  assert.strictEqual(csvCell('=2+2'), String.fromCharCode(34, 39) + '=2+2' + String.fromCharCode(34));
  assert.strictEqual(csvCell('a,"b"'), String.fromCharCode(34) + 'a,""b""' + String.fromCharCode(34));
});
`;

const source = match[1].replace(/\brerender\(\);\s*$/, '') + tests;
const sandbox = {
  assert,
  Blob,
  URL: { createObjectURL: () => 'blob:test', revokeObjectURL: () => {} },
  structuredClone,
  queueMicrotask,
  setTimeout: callback => callback(),
  confirm: () => true,
  document: {
    getElementById: () => ({
      innerHTML: '',
      value: '',
      textContent: '0',
      querySelector: () => null,
      appendChild() {},
      focus() {},
      setSelectionRange() {}
    }),
    createElement: () => ({ click() {} })
  },
  __passes: []
};

vm.runInNewContext(source, sandbox, { filename: htmlPath });
console.log(`HTML integrity fixtures: ${sandbox.__passes.length} PASS`);
for (const name of sandbox.__passes) console.log(`  ✓ ${name}`);
