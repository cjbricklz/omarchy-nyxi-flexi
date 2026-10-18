// Geometry for the controller drawings, drawn from scratch as exact vector paths (SVG path strings).
// Nothing here is traced or sampled: the body is a few cubic curves mirrored about the middle, the
// buttons are circles, rectangles and capsules, and the grip texture is a computed hexagon lattice.
// Both views share one coordinate space, 780 x 550, so they draw at the same size.
// Kept free of QML so it can be tested with node.

var WIDTH = 780
var HEIGHT = 550
var MID = WIDTH / 2

function num(n) { return String(Math.round(n * 100) / 100) }

// Mirrors an absolute SVG path (M, L, C, A, Z only) about the vertical middle line.
// Arc flags are flipped because mirroring reverses the sweep direction.
function mirror(d) {
  return d.replace(/([MLCAZ])([^MLCAZ]*)/g, function (_, cmd, args) {
    var v = args.trim().length ? args.trim().split(/[\s,]+/).map(Number) : []
    if (cmd === "A") return "A" + [v[0], v[1], -v[2], v[3], 1 - v[4], WIDTH - v[5], v[6]].map(num).join(" ")
    if (cmd === "Z") return "Z"
    return cmd + v.map(function (n, i) { return num(i % 2 === 0 ? WIDTH - n : n) }).join(" ")
  })
}

// The silhouette, left half from the top middle down to the bottom middle as cubic segments
// [c1x, c1y, c2x, c2y, x, y]. Each join continues the tangent of the segment before it, so the line
// has no corners. The right half is the left one mirrored.
var START = [MID, 60]
var HALF = [
  [350, 60, 320, 52, 285, 48],        // top edge towards the shoulder
  [235, 42.3, 180, 48, 140, 82],      // shoulder
  [85, 130, 34, 250, 16, 370],        // outer edge of the grip
  [6, 440, 14, 505, 60, 526],         // bottom of the grip
  [108, 546, 152, 505, 178, 448],     // tip of the grip, curling in
  [196, 408, 232, 392, 272, 398],     // inner edge up to the underside
  [315, 404, 350, 414, MID, 414]      // underside
]

function bodyPath() {
  var d = "M" + START.join(" ")
  HALF.forEach(function (s) { d += "C" + s.map(num).join(" ") })
  // Right half: walk the left half backwards with every point mirrored.
  var pts = [START]
  HALF.forEach(function (s) { pts.push([s[4], s[5]]) })
  for (var i = HALF.length - 1; i >= 0; i--) {
    var s = HALF[i], from = pts[i]
    d += "C" + [WIDTH - s[2], s[3], WIDTH - s[0], s[1], WIDTH - from[0], from[1]].map(num).join(" ")
  }
  return d + "Z"
}

// A capsule (a rounded bar) of width w whose end caps are centred on (x1, y1) and (x2, y2).
function capsule(x1, y1, x2, y2, w) {
  var dx = x2 - x1, dy = y2 - y1, len = Math.sqrt(dx * dx + dy * dy)
  var nx = -dy / len * w / 2, ny = dx / len * w / 2, r = w / 2
  return "M" + num(x1 + nx) + " " + num(y1 + ny) +
    "L" + num(x2 + nx) + " " + num(y2 + ny) +
    "A" + [r, r, 0, 0, 0, x2 - nx, y2 - ny].map(num).join(" ") +
    "L" + num(x1 - nx) + " " + num(y1 - ny) +
    "A" + [r, r, 0, 0, 0, x1 + nx, y1 + ny].map(num).join(" ") + "Z"
}

// A rounded rectangle.
function roundRect(x, y, w, h, r) {
  return "M" + num(x + r) + " " + num(y) +
    "L" + num(x + w - r) + " " + num(y) + "A" + [r, r, 0, 0, 1, x + w, y + r].map(num).join(" ") +
    "L" + num(x + w) + " " + num(y + h - r) + "A" + [r, r, 0, 0, 1, x + w - r, y + h].map(num).join(" ") +
    "L" + num(x + r) + " " + num(y + h) + "A" + [r, r, 0, 0, 1, x, y + h - r].map(num).join(" ") +
    "L" + num(x) + " " + num(y + r) + "A" + [r, r, 0, 0, 1, x + r, y].map(num).join(" ") + "Z"
}

// An ellipse tilted by deg degrees.
function ellipse(cx, cy, rx, ry, deg) {
  var t = deg * Math.PI / 180, dx = rx * Math.cos(t), dy = rx * Math.sin(t)
  return "M" + num(cx - dx) + " " + num(cy - dy) +
    "A" + [rx, ry, deg, 1, 1, cx + dx, cy + dy].map(num).join(" ") +
    "A" + [rx, ry, deg, 1, 1, cx - dx, cy - dy].map(num).join(" ") + "Z"
}

function circle(cx, cy, r) {
  return "M" + num(cx - r) + " " + num(cy) +
    "A" + [r, r, 0, 1, 0, cx + r, cy].map(num).join(" ") +
    "A" + [r, r, 0, 1, 0, cx - r, cy].map(num).join(" ") + "Z"
}

// ---------- Front ----------
var FRONT = {
  stickL: { x: 205, y: 150, socket: 62, cap: 82 },
  stickR: { x: 500, y: 285, socket: 62, cap: 82 },
  dpad: { x: 290, y: 285 },
  faceN: { x: 590, y: 104 }, faceW: { x: 544, y: 150 }, faceE: { x: 636, y: 150 }, faceS: { x: 590, y: 196 },
  view: { x: 330, y: 142 }, menu: { x: 450, y: 142 },
  t: { x: 362, y: 186 }, m: { x: 418, y: 186 },
  home: { x: MID, y: 318 },
  // The four channel lights, top to bottom, in slots above the centre buttons.
  leds: [ { x: 355, y: 74, w: 70, h: 6 }, { x: 355, y: 87, w: 70, h: 6 },
          { x: 355, y: 100, w: 70, h: 6 }, { x: 355, y: 113, w: 70, h: 6 } ]
}

// A circular ring of grip hexagons on the left grip, mirrored for the right. A pointy-top lattice is
// clipped to a tilted ellipse that sits wholly inside the grip.
function hexagon(cx, cy, r) {
  var d = ""
  for (var k = 0; k < 6; k++) {
    var a = Math.PI / 6 + k * Math.PI / 3
    d += (k === 0 ? "M" : "L") + num(cx + r * Math.cos(a)) + " " + num(cy + r * Math.sin(a))
  }
  return d + "Z"
}

function gripHexPaths() {
  var r = 6.5, gap = 4.5
  var pitch = r * Math.sqrt(3) + gap, rowH = pitch * Math.sqrt(3) / 2
  var ex = 86, ey = 446, rx = 54, ry = 88, tilt = -14 * Math.PI / 180
  var cos = Math.cos(tilt), sin = Math.sin(tilt)
  var left = []
  for (var row = -12; row <= 12; row++) {
    for (var col = -12; col <= 12; col++) {
      var x = ex + col * pitch + (row % 2 ? pitch / 2 : 0), y = ey + row * rowH
      var u = ((x - ex) * cos + (y - ey) * sin) / (rx - r)
      var v = (-(x - ex) * sin + (y - ey) * cos) / (ry - r)
      if (u * u + v * v <= 1) left.push([x, y])
    }
  }
  var d = ""
  left.forEach(function (p) { d += hexagon(p[0], p[1], r) + hexagon(WIDTH - p[0], p[1], r) })
  return d
}

// ---------- Back ----------
// Seen from behind, the controller's right side is on the left of the picture.
var BACK = {
  r2: { path: ellipse(190, 128, 60, 34, 22), lx: 190, ly: 128 },
  r1: { path: capsule(272, 80, 338, 88, 24), lx: 305, ly: 84 },
  m2: { path: capsule(230, 214, 284, 268, 42), lx: 257, ly: 241 },
  m4: { path: capsule(216, 298, 266, 346, 42), lx: 241, ly: 322 }
}
BACK.l2 = { path: mirror(BACK.r2.path), lx: WIDTH - BACK.r2.lx, ly: BACK.r2.ly }
BACK.l1 = { path: mirror(BACK.r1.path), lx: WIDTH - BACK.r1.lx, ly: BACK.r1.ly }
BACK.m1 = { path: mirror(BACK.m2.path), lx: WIDTH - BACK.m2.lx, ly: BACK.m2.ly }
BACK.m3 = { path: mirror(BACK.m4.path), lx: WIDTH - BACK.m4.lx, ly: BACK.m4.ly }
BACK.cover = roundRect(322, 150, 136, 170, 30)

if (typeof module !== "undefined") {
  module.exports = { WIDTH: WIDTH, HEIGHT: HEIGHT, mirror: mirror, bodyPath: bodyPath, capsule: capsule, roundRect: roundRect,
    ellipse: ellipse, circle: circle, hexagon: hexagon, gripHexPaths: gripHexPaths, FRONT: FRONT, BACK: BACK }
}
