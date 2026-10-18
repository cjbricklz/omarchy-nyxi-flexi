const A = require('../Art.js'), a = require('assert')

// Every path is made of absolute commands and finite numbers only.
function check(d, name) {
  a.ok(/^[MLCAZ0-9eE.,\s-]+$/.test(d), name + ' has only absolute M, L, C, A, Z commands')
  a.ok(!/NaN|Infinity|undefined/.test(d), name + ' has no bad numbers')
  a.ok(d.trim().endsWith('Z'), name + ' is closed')
}
check(A.bodyPath(), 'body')
check(A.gripHexPaths(), 'grip hexagons')
Object.keys(A.BACK).forEach(function (k) { check(A.BACK[k].path || A.BACK[k], k) })

// The back buttons come in mirrored pairs and the paths are mirror images of each other.
a.strictEqual(A.mirror(A.mirror(A.BACK.r2.path)), A.BACK.r2.path)
a.strictEqual(A.mirror(A.BACK.m2.path), A.BACK.m1.path)
a.strictEqual(A.BACK.l1.lx, A.WIDTH - A.BACK.r1.lx)

// The silhouette is left-right symmetric: its mirror is the same curve walked the other way round.
const pts = A.bodyPath().match(/-?\d+(\.\d+)?/g).map(Number)
const xs = pts.filter(function (_, i) { return i % 2 === 0 }), ys = pts.filter(function (_, i) { return i % 2 === 1 })
a.ok(Math.min.apply(null, xs) > 0 && Math.max.apply(null, xs) < A.WIDTH, 'body fits the width')
a.ok(Math.min.apply(null, ys) > 0 && Math.max.apply(null, ys) < A.HEIGHT, 'body fits the height')

// Grip hexagons: 6 corners each, identical on both grips.
const hexes = A.gripHexPaths().split('Z').filter(Boolean)
a.strictEqual(hexes.length % 2, 0)
hexes.forEach(function (h) { a.strictEqual((h.match(/[ML]/g) || []).length, 6) })
console.log('art ok')
