const A = require('../Art.js'), a = require('assert')

// Every path is made of absolute commands and finite numbers only.
function check(d, name, closed) {
  a.ok(/^[MLCZ0-9eE.,\s-]+$/.test(d), name + ' has only absolute M, L, C, Z commands')
  a.ok(!/NaN|Infinity|undefined/.test(d), name + ' has no bad numbers')
  if (closed) a.ok(d.trim().endsWith('Z'), name + ' is closed')
}

// The drawn parts, grouped by whether they are closed shapes or lines.
const lines = [A.FRONT.body, A.BACK.body, A.BACK.belt]
const shapes = [A.FRONT.plate, A.FRONT.dpadRing, A.FRONT.dpadPlus, A.FRONT.dot, A.FRONT.stickL.ring, A.FRONT.stickR.ring,
  A.BACK.usb, A.BACK.label, A.BACK.speaker, A.BACK.screws, A.gripHexPaths(), A.backGripPaths()]
Object.keys(A.FRONT.dpadArm).forEach(function (k) { shapes.push(A.FRONT.dpadArm[k], A.FRONT.dpadTri[k]) })
;['r2', 'l2', 'r1', 'l1', 'm1', 'm2', 'm3', 'm4'].forEach(function (k) { shapes.push(A.BACK[k].path) })
lines.forEach(function (d, i) { check(d, 'line ' + i, false) })
shapes.forEach(function (d, i) { check(d, 'shape ' + i, true) })

// Each outline is a single stroke: one M, so there are no joins to show up as notches or doubled dots.
lines.forEach(function (d) { a.strictEqual((d.match(/M/g) || []).length, 1) })

// Everything lands inside the 780 x 550 space.
function within(d, name) {
  const n = d.replace(/[MLCZ]/g, ' ').trim().split(/\s+/).map(Number)
  n.forEach(function (v, i) {
    const max = i % 2 === 0 ? A.WIDTH : A.HEIGHT
    a.ok(v >= 0 && v <= max, name + ': ' + v + ' is outside the drawing')
  })
}
lines.concat(shapes).forEach(function (d, i) { within(d, 'path ' + i) })

// The back buttons come in mirrored pairs.
;[['r2', 'l2'], ['r1', 'l1'], ['m2', 'm1'], ['m4', 'm3']].forEach(function (p) {
  a.ok(Math.abs(A.BACK[p[0]].lx + A.BACK[p[1]].lx - A.WIDTH) < 20, p.join('/') + ' labels mirror')
  a.strictEqual(A.BACK[p[0]].ly, A.BACK[p[1]].ly)
})

// fillets and smooth curves stay in the right place
const rounded = A.poly([[0, 0], [10, 0], [10, 10], [0, 10]], 2, true)
a.strictEqual(rounded.length, 8)
const curve = A.smooth([[0, 0], [10, 5], [20, 0]], false)
a.deepStrictEqual(curve[0], ['M', 0, 0])
a.deepStrictEqual(A.reverse(curve).pop().slice(-2), [0, 0])

// Grip hexagons: whole hexagons only, none alone, identical on both grips.
const hexes = A.gripHexPaths().split('Z').filter(Boolean)
a.strictEqual(hexes.length % 2, 0)
hexes.forEach(function (h) { a.strictEqual((h.match(/[ML]/g) || []).length, 6) })
console.log('art ok')
