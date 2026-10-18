// Geometry for the controller drawings: exact vector paths (SVG path strings), drawn by hand from the
// shape of the real controller. Nothing is traced or sampled from an image. Curves are cubic Beziers
// (smoothed through key points), corners are rounded with fillets, buttons are circles, and the grip texture
// is a computed lattice of whole hexagons.
// Shapes are written in the units of a reference picture of each view and mapped into a 780 x 550 space,
// so both views draw at the same size. Kept free of QML so it can be tested with node.

var WIDTH = 780
var HEIGHT = 550

function num(n) { return String(Math.round(n * 100) / 100) }

// ---------- Path building ----------
// A path is a list of segments: ["M", x, y], ["L", x, y] or ["C", x1, y1, x2, y2, x, y].

function end(seg) { return [seg[seg.length - 2], seg[seg.length - 1]] }

// Appends `more` to `segs`, continuing from where `segs` ends (its first M is dropped).
function join(segs, more) { return segs.concat(more.slice(1)) }

// The same path walked backwards.
function reverse(segs) {
  var out = [["M"].concat(end(segs[segs.length - 1]))]
  for (var i = segs.length - 1; i > 0; i--) {
    var s = segs[i], from = end(segs[i - 1])
    out.push(s[0] === "C" ? ["C", s[3], s[4], s[1], s[2], from[0], from[1]] : ["L", from[0], from[1]])
  }
  return out
}

function mapSegs(segs, fx) {
  return segs.map(function (s) {
    var o = [s[0]]
    for (var i = 1; i < s.length; i += 2) { var p = fx(s[i], s[i + 1]); o.push(p[0], p[1]) }
    return o
  })
}

// A smooth curve through the points (Catmull-Rom turned into cubic segments).
function smooth(pts, closed) {
  var n = pts.length, segs = [["M", pts[0][0], pts[0][1]]]
  var at = function (i) { return closed ? pts[(i + n) % n] : pts[Math.max(0, Math.min(n - 1, i))] }
  var count = closed ? n : n - 1
  for (var i = 0; i < count; i++) {
    var p0 = at(i - 1), p1 = at(i), p2 = at(i + 1), p3 = at(i + 2)
    segs.push(["C", p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6,
                    p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6, p2[0], p2[1]])
  }
  return segs
}

// A polygon with every corner rounded by a fillet of radius r (a number, or one per point).
function poly(pts, r, closed) {
  var n = pts.length, segs = []
  var rad = function (i) { return typeof r === "number" ? r : r[i] }
  for (var i = 0; i < n; i++) {
    var v = pts[i]
    if (!closed && (i === 0 || i === n - 1)) { segs.push([segs.length ? "L" : "M", v[0], v[1]]); continue }
    var a = pts[(i + n - 1) % n], b = pts[(i + 1) % n]
    var la = Math.hypot(a[0] - v[0], a[1] - v[1]), lb = Math.hypot(b[0] - v[0], b[1] - v[1])
    var d = Math.min(rad(i), la / 2, lb / 2)
    var p1 = [v[0] + (a[0] - v[0]) / la * d, v[1] + (a[1] - v[1]) / la * d]
    var p2 = [v[0] + (b[0] - v[0]) / lb * d, v[1] + (b[1] - v[1]) / lb * d]
    segs.push([segs.length ? "L" : "M", p1[0], p1[1]])
    segs.push(["C", p1[0] + (v[0] - p1[0]) * 0.55, p1[1] + (v[1] - p1[1]) * 0.55,
                    p2[0] + (v[0] - p2[0]) * 0.55, p2[1] + (v[1] - p2[1]) * 0.55, p2[0], p2[1]])
  }
  return segs
}

function ellipseSegs(cx, cy, rx, ry) {
  var k = 0.5523
  return [["M", cx + rx, cy],
    ["C", cx + rx, cy + ry * k, cx + rx * k, cy + ry, cx, cy + ry],
    ["C", cx - rx * k, cy + ry, cx - rx, cy + ry * k, cx - rx, cy],
    ["C", cx - rx, cy - ry * k, cx - rx * k, cy - ry, cx, cy - ry],
    ["C", cx + rx * k, cy - ry, cx + rx, cy - ry * k, cx + rx, cy]]
}

function toD(segs, closed) {
  return segs.map(function (s) { return s[0] + s.slice(1).map(num).join(" ") }).join("") + (closed ? "Z" : "")
}

// A view: reference units -> the 780 x 550 space, mirrored about the vertical line x = axis.
function frame(k, ox, oy, axis) {
  var f = { k: k, axis: axis }
  f.pt = function (x, y) { return [(x - ox) * k, (y - oy) * k] }
  f.flip = function (x, y) { return [2 * axis - x, y] }
  f.x = function (x) { return (x - ox) * k }
  f.y = function (y) { return (y - oy) * k }
  f.len = function (n) { return n * k }
  f.d = function (segs, closed) { return toD(mapSegs(segs, f.pt), closed) }
  f.mirrored = function (segs) { return mapSegs(segs, f.flip) }
  // Both halves as one stroke: `left` runs from the middle to the end of the left half; the path
  // returns by the mirror image of it.
  f.symmetric = function (left) { return join(reverse(left), f.mirrored(left)) }
  f.circle = function (cx, cy, r) { return f.d(ellipseSegs(cx, cy, r, r), true) }
  f.at = function (cx, cy, r) { var p = f.pt(cx, cy); return { x: p[0], y: p[1], r: r * k } }
  return f
}

// ---------- Hexagon lattice ----------
function hexagon(cx, cy, r) {
  var d = ""
  for (var k = 0; k < 6; k++) {
    var a = Math.PI / 6 + k * Math.PI / 3
    d += (k === 0 ? "M" : "L") + num(cx + r * Math.cos(a)) + " " + num(cy + r * Math.sin(a))
  }
  return d + "Z"
}

function inside(pt, region) {
  var c = false
  for (var i = 0, j = region.length - 1; i < region.length; j = i++) {
    var a = region[i], b = region[j]
    if ((a[1] > pt[1]) !== (b[1] > pt[1]) && pt[0] < (b[0] - a[0]) * (pt[1] - a[1]) / (b[1] - a[1]) + a[0]) c = !c
  }
  return c
}

// Centres of whole hexagons on a pointy-top lattice that lie inside `region` (a polygon, already inset
// so that no hexagon touches an edge).
function latticeCentres(region, r, gap) {
  var pitch = r * Math.sqrt(3) + gap, rowH = pitch * Math.sqrt(3) / 2
  var xs = region.map(function (p) { return p[0] }), ys = region.map(function (p) { return p[1] })
  var x0 = Math.min.apply(null, xs), x1 = Math.max.apply(null, xs), y0 = Math.min.apply(null, ys), y1 = Math.max.apply(null, ys)
  var out = []
  for (var row = 0; y0 + row * rowH <= y1; row++) {
    for (var x = x0 + (row % 2 ? pitch / 2 : 0); x <= x1; x += pitch) {
      var c = [x, y0 + row * rowH]
      if (inside(c, region)) out.push(c)
    }
  }
  return pruned(out, pitch)
}

// Drops hexagons that stand out alone at the edge of the pattern (fewer than three neighbours).
function pruned(centres, pitch) {
  return centres.filter(function (c) {
    var near = centres.filter(function (o) { return o !== c && Math.hypot(o[0] - c[0], o[1] - c[1]) < pitch * 1.1 }).length
    return near >= 3
  })
}

// ======================================================================
// Front view. Reference units: the controller seen from above, about 660 wide.
// ======================================================================
var F = frame(1.17, 4, 64, 336.5)

// The outline, from the top middle round the left side to where the grip meets the face plate; the
// right side is its mirror image, so the whole line is one unbroken stroke.
var frontLeft =
  [["M", 336.5, 103], ["L", 290, 103],
   ["C", 284, 103, 281, 100, 279, 95], ["L", 272, 78],                  // the step down to the shoulder
   ["C", 270, 72, 266, 69, 258, 69],                                    // shoulder bumper
   ["C", 220, 69, 150, 92, 123, 110]]                                   // the bumper falls away to the grip
frontLeft = join(frontLeft, smooth([[123, 110], [96, 139], [54, 229], [21, 340], [9, 422], [14, 470], [35, 508],
                                    [71, 527], [107, 515], [143, 451], [179, 401], [210.6, 366.4]], false))

// The face plate: the raised panel that holds the sticks and buttons.
var plateHalf = [[225, 383], [193, 346], [135, 275], [104, 225], [97, 165], [123, 113], [228, 93], [298, 125]]
var plateRadii = [12, 12, 40, 40, 40, 6, 6, 8]
var plateAll = plateHalf.concat(plateHalf.slice().reverse().map(function (p) { return [673 - p[0], p[1]] }), [[413, 393], [260, 393]])
var plateAllRadii = plateRadii.concat(plateRadii.slice().reverse(), [14, 14])

// The D-pad: a plus, 32 wide and 102 across, inside a ring.
function plus(cx, cy, w, reach) {
  return [[-w, -reach], [w, -reach], [w, -w], [reach, -w], [reach, w], [w, w], [w, reach], [-w, reach],
          [-w, w], [-reach, w], [-reach, -w], [-w, -w]].map(function (p) { return [cx + p[0], cy + p[1]] })
}
function arm(cx, cy, w, reach, dir) {
  var rect = { up: [[-w, -reach], [w, -reach], [w, -w], [-w, -w]], down: [[-w, w], [w, w], [w, reach], [-w, reach]],
               left: [[-reach, -w], [-w, -w], [-w, w], [-reach, w]], right: [[w, -w], [reach, -w], [reach, w], [w, w]] }[dir]
  return rect.map(function (p) { return [cx + p[0], cy + p[1]] })
}
function triangle(cx, cy, dir, s) {
  var t = { up: [[0, -s], [s, s * 0.7], [-s, s * 0.7]], down: [[0, s], [s, -s * 0.7], [-s, -s * 0.7]],
            left: [[-s, 0], [s * 0.7, s], [s * 0.7, -s]], right: [[s, 0], [-s * 0.7, s], [-s * 0.7, -s]] }[dir]
  return t.map(function (p) { return [cx + p[0], cy + p[1]] })
}
var DP = { x: 253, y: 274, w: 16, reach: 51 }

function armD(dir) { return F.d(poly(arm(DP.x, DP.y, DP.w - 2.5, DP.reach - 2.5, dir), 5, true), true) }
function triD(dir) {
  var o = { up: [0, -33], down: [0, 33], left: [-33, 0], right: [33, 0] }[dir]
  return F.d(poly(triangle(DP.x + o[0], DP.y + o[1], dir, 6.5), 1.2, true), true)
}

var frontGrip = [[66, 238], [86, 246], [120, 290], [136, 312], [128, 345], [100, 385], [76, 434], [60, 422], [46, 388], [42, 340], [46, 295], [54, 262]]

function gripHexPaths() {
  var d = ""
  latticeCentres(frontGrip, 8, 3).forEach(function (c) {
    var a = F.pt(c[0], c[1]), b = F.pt(673 - c[0], c[1])
    d += hexagon(a[0], a[1], 8 * F.k) + hexagon(b[0], b[1], 8 * F.k)
  })
  return d
}

var FRONT = {
  w: WIDTH, h: HEIGHT,
  body: F.d(F.symmetric(frontLeft), false),
  plate: F.d(poly(plateAll, plateAllRadii, true), true),
  dpadRing: F.circle(DP.x, DP.y, 62),
  dpadPlus: F.d(poly(plus(DP.x, DP.y, DP.w, DP.reach), 6, true), true),
  dpadArm: { up: armD("up"), down: armD("down"), left: armD("left"), right: armD("right") },
  dpadTri: { up: triD("up"), down: triD("down"), left: triD("left"), right: triD("right") },
  stickL: { socket: F.at(166, 180, 62), ring: F.circle(166, 180, 46), cap: F.at(162, 163, 38) },
  stickR: { socket: F.at(428, 273, 62), ring: F.circle(428, 273, 46), cap: F.at(424, 257, 38) },
  faceN: F.at(500, 138, 21), faceW: F.at(462, 177, 21), faceE: F.at(543, 177, 21), faceS: F.at(505, 214, 21),
  view: F.at(267, 160, 14.5), menu: F.at(405, 160, 14.5), t: F.at(304, 192, 14.5), m: F.at(368, 192, 14.5),
  home: F.at(336, 313, 17),
  dot: F.circle(336.5, 237, 1.8),
  // The four channel lights in the slots above the centre buttons, top to bottom.
  leds: [[76, 126], [68, 136], [52, 146], [28, 156]].map(function (l) {
    var p = F.pt(336.5 - l[0] / 2, l[1] - 2.2)
    return { x: p[0], y: p[1], w: F.len(l[0]), h: F.len(4.4) }
  })
}

// ======================================================================
// Back view. Reference units: the controller seen from behind, about 920 wide.
// ======================================================================
var B = frame(0.835, 14, 16, 480)

// The shell below the shoulders, from the middle of the bottom edge round the grip to the left shoulder.
var backLeft = smooth([[173, 127], [125, 185], [60, 300], [28, 420], [22, 500], [45, 590], [110, 650], [180, 672],
                       [235, 640], [262, 582], [290, 528], [322, 490], [334, 478]], false)
backLeft = reverse(join(backLeft, [["M", 334, 478], ["C", 338, 472, 344, 468, 356, 468], ["L", 480, 468]]))

// The seam across the shoulders.
var beltLeft = reverse(smooth([[164, 152], [215, 168], [290, 184], [380, 192], [480, 195]], false))

var backGrip = [[130, 222], [290, 222], [290, 268], [214, 290], [206, 470], [226, 556], [206, 606], [170, 632],
                [124, 612], [84, 560], [70, 500], [74, 424], [104, 320]]

// The speaker holes: four staggered rows.
function speakerDots() {
  var d = ""
  for (var row = 0; row < 4; row++) {
    var cols = 11 - (row % 2)
    for (var c = 0; c < cols; c++) {
      var x = 480 - (cols - 1) * 6.5 + c * 13, y = 348 + row * 12
      d += toD(mapSegs(ellipseSegs(x, y, 3.3, 3.3), B.pt), true)
    }
  }
  return d
}

function backGripPaths() {
  var d = ""
  latticeCentres(backGrip, 15, 7).forEach(function (c) {
    var a = B.pt(c[0], c[1]), b = B.pt(960 - c[0], c[1])
    d += hexagon(a[0], a[1], 15 * B.k) + hexagon(b[0], b[1], 15 * B.k)
  })
  return d
}

// Seen from behind, the controller's right side is on the left of the picture; each button is
// written for that side and mirrored for the other.
function button(segs, labelAt) {
  var mirrored = B.mirrored(segs)
  return {
    left: { path: B.d(segs, true), lx: B.x(labelAt[0]), ly: B.y(labelAt[1]) },
    right: { path: B.d(mirrored, true), lx: B.x(2 * B.axis - labelAt[0]), ly: B.y(labelAt[1]) }
  }
}
var r2 = button(smooth([[166, 108], [182, 72], [240, 52], [296, 62], [306, 102], [288, 132], [236, 144], [184, 140]], true), [236, 98])
var r1 = button(poly([[314, 68], [396, 80], [406, 90], [402, 98], [316, 108]], 8, true), [358, 88])
var m2 = button(poly([[250, 348], [268, 306], [338, 296], [341, 352], [262, 373]], 16, true), [298, 334])
var m4 = button(poly([[237, 392], [336, 378], [338, 432], [316, 468], [236, 470]], 16, true), [290, 426])

var BACK = {
  w: WIDTH, h: HEIGHT,
  r2: r2.left, l2: r2.right, r1: r1.left, l1: r1.right,
  m2: m2.left, m1: m2.right, m4: m4.left, m3: m4.right,
  body: B.d(B.symmetric(backLeft), false),
  belt: B.d(B.symmetric(beltLeft), false),
  usb: B.d(poly([[420, 80], [540, 80], [540, 104], [420, 104]], 10, true), true),
  label: B.d(poly([[375, 222], [585, 222], [585, 335], [375, 335]], 14, true), true),
  speaker: speakerDots(),
  screws: B.circle(390, 432, 8) + B.circle(570, 432, 8)
}

if (typeof module !== "undefined") {
  module.exports = { WIDTH: WIDTH, HEIGHT: HEIGHT, smooth: smooth, poly: poly, reverse: reverse, join: join, toD: toD,
    latticeCentres: latticeCentres, inside: inside, hexagon: hexagon, gripHexPaths: gripHexPaths, backGripPaths: backGripPaths,
    FRONT: FRONT, BACK: BACK }
}
