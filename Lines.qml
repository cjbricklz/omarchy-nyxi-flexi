// Draws traced line art (arrays of polylines, see tools/trace-art.py) scaled into this item.
// `viewX`/`viewY` are the drawing coordinates of the item's top-left corner; `viewW` is the width of
// drawing it should show, so the art scales to whatever width the item is given.
import QtQuick

Canvas {
  id: lines
  property var paths: []
  property real viewX: 0
  property real viewY: 0
  property real viewW: 100
  property color color: "white"
  property real lineWidth: 2.2

  onPathsChanged: requestPaint()
  onWidthChanged: requestPaint()
  onColorChanged: requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.clearRect(0, 0, width, height)
    ctx.save()
    ctx.scale(width / viewW, width / viewW)
    ctx.translate(-viewX, -viewY)
    ctx.lineJoin = "round"
    ctx.lineCap = "round"
    ctx.lineWidth = lineWidth
    ctx.strokeStyle = color
    ctx.beginPath()
    for (var i = 0; i < paths.length; i++) {
      var p = paths[i]
      ctx.moveTo(p[0], p[1])
      for (var j = 2; j < p.length; j += 2) ctx.lineTo(p[j], p[j + 1])
    }
    ctx.stroke()
    ctx.restore()
  }
}
