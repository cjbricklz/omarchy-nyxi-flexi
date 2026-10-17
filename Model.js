// Pure helpers for the NYXI Flexi panel: input codes, labels, axis scaling.
// Kept free of QML so it can be tested with node.

// Nerd Font (Material Design) glyphs are above U+FFFF, so build them from the code point.
function glyph(cp) {
  var n = cp - 0x10000
  return String.fromCharCode(0xD800 + (n >> 10), 0xDC00 + (n & 0x3FF))
}

var ICON = {
  pad: glyph(0xF02B4),
  download: glyph(0xF01DA),
  open: glyph(0xF03CC)
}

var MANUAL_URL = "https://nyxigame.com/pages/np05_manual"

// Linux evdev button codes (linux/input-event-codes.h). Positions, not letters:
// "south" is the bottom face button, wherever the controller prints an A or a B.
var BTN = {
  south: 0x130, east: 0x131, north: 0x133, west: 0x134,
  capture: 0x135, lb: 0x136, rb: 0x137, ltDigital: 0x138, rtDigital: 0x139,
  back: 0x13a, start: 0x13b, home: 0x13c, l3: 0x13d, r3: 0x13e,
  dpadUp: 0x220, dpadDown: 0x221, dpadLeft: 0x222, dpadRight: 0x223,
  // Xbox pads over Bluetooth report View and the Xbox button as media keys (KEY_BACK, KEY_HOMEPAGE).
  viewAlt: 0x9e, homeAlt: 0xac
}
var ABS = { x: 0x00, y: 0x01, z: 0x02, rx: 0x03, ry: 0x04, rz: 0x05, gas: 0x09, brake: 0x0a, hat0x: 0x10, hat0y: 0x11 }

// Which evdev axis carries which control. XInput over USB and the Switch Pro put the right stick on
// RX/RY and (XInput) the triggers on Z/RZ. An Xbox pad over Bluetooth instead puts the right stick on
// Z/RZ and the triggers on BRAKE/GAS, so the layout is chosen from the axes the device reports.
function axisMap(abs) {
  var has = function (c) { return abs && abs[c] !== undefined }
  if (!has(ABS.rx) && !has(ABS.ry) && has(ABS.z) && has(ABS.rz))
    return { lx: ABS.x, ly: ABS.y, rx: ABS.z, ry: ABS.rz, lt: ABS.brake, rt: ABS.gas }
  return { lx: ABS.x, ly: ABS.y, rx: ABS.rx, ry: ABS.ry, lt: ABS.z, rt: ABS.rz }
}

// Buttons the panel draws. Anything else that is pressed is listed as "other".
var DRAWN = {}
Object.keys(BTN).forEach(function (k) { DRAWN[BTN[k]] = true })

var VENDOR_NINTENDO = 0x057e
var VENDOR_MICROSOFT = 0x045e

// Face button letters follow the layout the controller reports as: Nintendo
// puts A on the right and B at the bottom, Xbox the other way round.
function faceLabels(vendor) {
  return vendor === VENDOR_NINTENDO
    ? { south: "B", east: "A", north: "X", west: "Y" }
    : { south: "A", east: "B", north: "Y", west: "X" }
}

// The mode the Flexi is in, from how it identifies itself over USB or Bluetooth.
// BACK + START held for 3 s cycles XInput -> Switch Pro -> DInput.
function modeFor(vendor, product) {
  if (vendor === VENDOR_NINTENDO) return "Switch Pro"
  if (vendor === VENDOR_MICROSOFT) return "XInput"
  return "DInput"
}

// The four channel lights above the centre buttons, top to bottom. The Flexi lights the first (red) in Switch Pro
// mode and the second (green) in Xbox mode; DInput is not known to light any of them.
var LED_COLORS = ["#e5484d", "#3fb950", "#e5484d", "#3fb950"]
function ledFor(mode) {
  return mode === "Switch Pro" ? 1 : mode === "XInput" ? 2 : 0
}

function hex(n) {
  var s = Number(n).toString(16)
  return "0x" + (s.length < 3 ? ("00" + s).slice(-3) : s)
}

// Sticks: -1..1 around the middle of the reported range.
function stick(value, range) {
  if (!range || range[1] === range[0] || value === undefined) return 0
  var mid = (range[0] + range[1]) / 2
  var half = (range[1] - range[0]) / 2
  return Math.max(-1, Math.min(1, (value - mid) / half))
}

// Triggers: 0..1 from the bottom of the reported range.
function trigger(value, range) {
  if (!range || range[1] === range[0] || value === undefined) return 0
  return Math.max(0, Math.min(1, (value - range[0]) / (range[1] - range[0])))
}

// One line of reader output -> object, or null when it is not valid JSON.
function parseLine(line) {
  try {
    var obj = JSON.parse(line)
    return obj && typeof obj === "object" && obj.t ? obj : null
  } catch (e) {
    return null
  }
}

// Folds a "dev" or "s" message into pressed-button and axis maps (returns copies).
function applyFrame(keys, axes, msg) {
  var k = Object.assign({}, keys), a = Object.assign({}, axes)
  Object.keys(msg.k || {}).forEach(function (c) { k[c] = msg.k[c] })
  Object.keys(msg.a || {}).forEach(function (c) { a[c] = msg.a[c] })
  return { keys: k, axes: a }
}

// Pressed buttons the drawing has no spot for, e.g. the Flexi's M1-M4 back buttons.
function otherPressed(keys) {
  return Object.keys(keys || {}).filter(function (c) { return keys[c] && !DRAWN[c] })
    .map(Number).sort(function (a, b) { return a - b }).map(hex)
}

// Console wording for one reader frame. `face` is Model.faceLabels(vendor); `dev.abs` has axis ranges.
// Axes are only logged when they moved noticeably since the last logged value (`logged`, mutated),
// so a stick resting against its drift does not flood the console.
var ROLE_NAMES = { lx: "LEFT STICK X", ly: "LEFT STICK Y", rx: "RIGHT STICK X", ry: "RIGHT STICK Y", lt: "L2", rt: "R2" }

function buttonName(code, face) {
  var map = {}
  map[BTN.south] = face.south; map[BTN.east] = face.east; map[BTN.north] = face.north; map[BTN.west] = face.west
  map[BTN.capture] = "CAPTURE"; map[BTN.lb] = "L1"; map[BTN.rb] = "R1"; map[BTN.ltDigital] = "L2"
  map[BTN.rtDigital] = "R2"; map[BTN.back] = "BACK"; map[BTN.start] = "START"; map[BTN.home] = "HOME"
  map[BTN.l3] = "L3"; map[BTN.r3] = "R3"; map[BTN.dpadUp] = "D-PAD UP"; map[BTN.dpadDown] = "D-PAD DOWN"
  map[BTN.dpadLeft] = "D-PAD LEFT"; map[BTN.dpadRight] = "D-PAD RIGHT"
  map[BTN.viewAlt] = "VIEW"; map[BTN.homeAlt] = "HOME"
  return map[code] || "BUTTON"
}

function describeFrame(msg, face, abs, logged) {
  var out = []
  var roleOf = {}
  var map = axisMap(abs)
  Object.keys(map).forEach(function (role) { roleOf[map[role]] = role })
  Object.keys(msg.k || {}).forEach(function (c) {
    out.push(buttonName(Number(c), face) + " " + (msg.k[c] ? "pressed" : "released") + "  (" + hex(c) + ")")
  })
  Object.keys(msg.a || {}).forEach(function (c) {
    var role = roleOf[c]
    var isTrigger = role === "lt" || role === "rt"
    var v = isTrigger ? trigger(msg.a[c], abs && abs[c]) : stick(msg.a[c], abs && abs[c])
    var last = logged[c] === undefined ? 0 : logged[c]
    if (Math.abs(v - last) < 0.1 && !(v === 0 && last !== 0)) return
    logged[c] = v
    var name = ROLE_NAMES[role] || (Number(c) === ABS.hat0x ? "D-PAD X" : Number(c) === ABS.hat0y ? "D-PAD Y" : "AXIS " + hex(c))
    out.push(name + " " + formatAxis(v).trim())
  })
  return out
}

// A paddle follows another input: a button code, or one direction of the D-pad hat axis. Written in
// shell.json as "0x09e" for a button, or "hat0x:-1" (0x or 0y, -1 or 1) for a D-pad direction.
var HAT = { hat0x: ABS.hat0x, hat0y: ABS.hat0y }

function parseBinding(v) {
  if (typeof v === "number") return v > 0 ? { kind: "key", code: v } : null
  var t = String(v || "").trim().toLowerCase()
  var hat = /^(hat0[xy]):(-1|1)$/.exec(t)
  if (hat) return { kind: "hat", code: HAT[hat[1]], sign: Number(hat[2]) }
  if (/^(0x[0-9a-f]+|\d+)$/.test(t)) return { kind: "key", code: Number(t) }
  return null
}

function bindingText(b) {
  if (b.kind === "key") return hex(b.code)
  return (b.code === ABS.hat0x ? "hat0x" : "hat0y") + ":" + b.sign
}

function bindingDown(b, keys, axes) {
  if (!b) return false
  if (b.kind === "key") return !!keys[b.code]
  return axes[b.code] !== undefined && Math.sign(axes[b.code]) === b.sign
}

// What a frame of input could be bound to: the first pressed button, else a pressed D-pad direction.
function bindingFromFrame(msg) {
  var pressed = Object.keys(msg.k || {}).filter(function (c) { return msg.k[c] === 1 })
  if (pressed.length) return { kind: "key", code: Number(pressed[0]) }
  var hats = Object.keys(msg.a || {}).filter(function (c) { return (Number(c) === ABS.hat0x || Number(c) === ABS.hat0y) && msg.a[c] !== 0 })
  if (hats.length) return { kind: "hat", code: Number(hats[0]), sign: Math.sign(msg.a[hats[0]]) }
  return null
}

function formatAxis(v) {
  var s = (Math.round(v * 100) / 100).toFixed(2)
  return (v >= 0 ? " " : "") + s
}

if (typeof module !== "undefined") {
  module.exports = { glyph: glyph, ICON: ICON, MANUAL_URL: MANUAL_URL, BTN: BTN, ABS: ABS,
    faceLabels: faceLabels, modeFor: modeFor, ledFor: ledFor, LED_COLORS: LED_COLORS, hex: hex, stick: stick, trigger: trigger,
    parseBinding: parseBinding, bindingText: bindingText, bindingDown: bindingDown, bindingFromFrame: bindingFromFrame, parseLine: parseLine, axisMap: axisMap, describeFrame: describeFrame, buttonName: buttonName, applyFrame: applyFrame, otherPressed: otherPressed, formatAxis: formatAxis }
}
