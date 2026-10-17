const M = require('../Model.js'), a = require('assert')

// Sticks centre on the middle of their range, triggers start at the bottom.
a.strictEqual(M.stick(0, [-32767, 32767]), 0)
a.strictEqual(M.stick(32767, [-32767, 32767]), 1)
a.strictEqual(M.stick(-99999, [-32767, 32767]), -1, 'clamped')
a.strictEqual(M.stick(128, [0, 255]) > 0, true, 'unsigned range is centred on 127.5')
a.strictEqual(M.stick(5, undefined), 0, 'unknown range')
a.strictEqual(M.trigger(0, [0, 255]), 0)
a.strictEqual(M.trigger(255, [0, 255]), 1)
a.strictEqual(M.trigger(1023, [0, 1023]), 1)
a.strictEqual(M.trigger(7, [3, 3]), 0, 'empty range')

// Letters depend on the layout; positions do not.
a.deepStrictEqual(M.faceLabels(0x057e), { south: 'B', east: 'A', north: 'X', west: 'Y' })
a.deepStrictEqual(M.faceLabels(0x045e), { south: 'A', east: 'B', north: 'Y', west: 'X' })
a.strictEqual(M.modeFor(0x057e, 0x2009), 'Switch Pro')
a.strictEqual(M.modeFor(0x045e, 0x028e), 'XInput')
a.strictEqual(M.modeFor(0x1234, 1), 'DInput')
a.strictEqual(M.ledFor('Switch Pro'), 1)
a.strictEqual(M.ledFor('XInput'), 2)
a.strictEqual(M.ledFor('DInput'), 0)

// Reader output.
a.strictEqual(M.parseLine('not json'), null)
a.strictEqual(M.parseLine('{"x":1}'), null, 'no type')
a.strictEqual(M.parseLine('{"t":"none"}').t, 'none')

let s = M.applyFrame({}, {}, M.parseLine('{"t":"dev","k":{"304":0,"305":0},"a":{"0":0,"1":0}}'))
a.deepStrictEqual(s.keys, { 304: 0, 305: 0 })
const before = s
s = M.applyFrame(s.keys, s.axes, M.parseLine('{"t":"s","k":{"304":1},"a":{"0":-20000}}'))
a.strictEqual(s.keys[304], 1)
a.strictEqual(s.keys[305], 0, 'untouched buttons stay')
a.strictEqual(s.axes[0], -20000)
a.strictEqual(before.keys[304], 0, 'earlier state is not mutated, so QML sees a change')

// Buttons with no spot in the drawing are listed, e.g. M1-M4 on the back.
a.deepStrictEqual(M.otherPressed({ 304: 1, 0x2c0: 1, 0x2c1: 0, 0x2c3: 1 }), ['0x2c0', '0x2c3'])
a.deepStrictEqual(M.otherPressed({}), [])
a.strictEqual(M.hex(0x31), '0x031')

a.strictEqual(M.formatAxis(0.5), ' 0.50')
a.strictEqual(M.formatAxis(-1), '-1.00')
a.strictEqual(M.glyph(0xF02B4).length, 2, 'astral glyph is a surrogate pair')
a.ok(M.MANUAL_URL.startsWith('https://nyxigame.com/'))
// Console wording.
const face = M.faceLabels(0x057e), range = { 0: [-32767, 32767], 2: [0, 255] }
let logged = {}
a.deepStrictEqual(M.describeFrame({ k: { 304: 1 }, a: {} }, face, range, logged), ['B pressed  (0x130)'])
a.deepStrictEqual(M.describeFrame({ k: { 305: 0 } }, face, range, logged), ['A released  (0x131)'])
a.deepStrictEqual(M.describeFrame({ a: { 0: 32767 } }, face, range, logged), ['LEFT STICK X 1.00'])
a.deepStrictEqual(M.describeFrame({ a: { 0: 32800 } }, face, range, logged), [], 'tiny move is not logged')
a.deepStrictEqual(M.describeFrame({ a: { 0: 100 } }, face, range, logged), ['LEFT STICK X 0.00'], 'return to centre is logged')
a.deepStrictEqual(M.describeFrame({ a: { 2: 255 } }, face, range, logged), ['L2 1.00'])
a.deepStrictEqual(M.describeFrame({ k: { 0x2c0: 1 } }, face, range, logged), ['BUTTON pressed  (0x2c0)'])
// Axis layouts: Xbox over Bluetooth moves the right stick to Z/RZ and the triggers to BRAKE/GAS.
const xboxBt = { 0: [0, 65535], 1: [0, 65535], 2: [0, 65535], 5: [0, 65535], 9: [0, 1023], 10: [0, 1023], 16: [-1, 1], 17: [-1, 1] }
a.deepStrictEqual(M.axisMap(xboxBt), { lx: 0, ly: 1, rx: 2, ry: 5, lt: 10, rt: 9 })
a.deepStrictEqual(M.axisMap({ 0: [0, 1], 1: [0, 1], 3: [0, 1], 4: [0, 1], 2: [0, 1], 5: [0, 1] }), { lx: 0, ly: 1, rx: 3, ry: 4, lt: 2, rt: 5 }, 'XInput over USB')
a.deepStrictEqual(M.axisMap({ 0: [0, 1], 1: [0, 1], 3: [0, 1], 4: [0, 1] }), { lx: 0, ly: 1, rx: 3, ry: 4, lt: 2, rt: 5 }, 'Switch Pro')
a.deepStrictEqual(M.axisMap(null), { lx: 0, ly: 1, rx: 3, ry: 4, lt: 2, rt: 5 })
logged = {}
a.deepStrictEqual(M.describeFrame({ a: { 2: 65535 } }, face, xboxBt, logged), ['RIGHT STICK X 1.00'], 'Z is the right stick here')
a.deepStrictEqual(M.describeFrame({ a: { 9: 1023 } }, face, xboxBt, logged), ['R2 1.00'])
a.deepStrictEqual(M.describeFrame({ a: { 17: 1 } }, face, xboxBt, logged), ['D-PAD Y 1.00'])
// View and the Xbox button arrive as media keys over Bluetooth; they are drawn, so not "other".
a.deepStrictEqual(M.otherPressed({ 0x9e: 1, 0xac: 1, 0x2c0: 1 }), ['0x2c0'])
a.deepStrictEqual(M.describeFrame({ k: { 0x9e: 1 } }, face, {}, {}), ['VIEW pressed  (0x09e)'])
// Paddle bindings.
a.deepStrictEqual(M.parseBinding('0x09e'), { kind: 'key', code: 0x9e })
a.deepStrictEqual(M.parseBinding(306), { kind: 'key', code: 306 })
a.deepStrictEqual(M.parseBinding('hat0x:-1'), { kind: 'hat', code: 16, sign: -1 })
a.deepStrictEqual(M.parseBinding('HAT0Y:1'), { kind: 'hat', code: 17, sign: 1 })
a.strictEqual(M.parseBinding(''), null)
a.strictEqual(M.parseBinding('nonsense'), null)
a.strictEqual(M.parseBinding(0), null)
a.strictEqual(M.bindingText({ kind: 'key', code: 0x9e }), '0x09e')
a.strictEqual(M.bindingText({ kind: 'hat', code: 16, sign: -1 }), 'hat0x:-1')
a.strictEqual(M.bindingDown({ kind: 'key', code: 5 }, { 5: 1 }, {}), true)
a.strictEqual(M.bindingDown({ kind: 'key', code: 5 }, { 5: 0 }, {}), false)
a.strictEqual(M.bindingDown({ kind: 'hat', code: 16, sign: -1 }, {}, { 16: -1 }), true)
a.strictEqual(M.bindingDown({ kind: 'hat', code: 16, sign: -1 }, {}, { 16: 1 }), false)
a.strictEqual(M.bindingDown(null, {}, {}), false)
a.deepStrictEqual(M.bindingFromFrame({ k: { 0x9e: 1 }, a: {} }), { kind: 'key', code: 0x9e })
a.deepStrictEqual(M.bindingFromFrame({ k: { 0x9e: 0 }, a: { 16: -1 } }), { kind: 'hat', code: 16, sign: -1 })
a.strictEqual(M.bindingFromFrame({ k: {}, a: { 16: 0, 0: 500 } }), null, 'release and stick noise are not bindings')
console.log('model ok')
