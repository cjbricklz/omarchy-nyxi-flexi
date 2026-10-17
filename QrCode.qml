// A QR code drawn from the rows in Qr.js: dark modules in `ink` on a `paper` square with a quiet margin.
import QtQuick
import "Qr.js" as Qr

Canvas {
  id: qr
  property color ink: "black"
  property color paper: "white"
  readonly property int quiet: 2
  readonly property int modules: Qr.ROWS.length

  onWidthChanged: requestPaint()
  onInkChanged: requestPaint()
  onPaperChanged: requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.clearRect(0, 0, width, height)
    var total = modules + 2 * quiet
    var cell = width / total
    ctx.fillStyle = paper
    ctx.beginPath()
    ctx.roundedRect(0, 0, width, height, cell, cell)
    ctx.fill()
    ctx.fillStyle = ink
    for (var y = 0; y < modules; y++) {
      var row = Qr.ROWS[y]
      for (var x = 0; x < modules; x++) {
        if (row.charAt(x) !== "1") continue
        // Cells are floored and overlapped by a pixel so there are no hairline gaps.
        var x0 = Math.floor((x + quiet) * cell), y0 = Math.floor((y + quiet) * cell)
        ctx.fillRect(x0, y0, Math.floor((x + quiet + 1) * cell) - x0 + 0.5, Math.floor((y + quiet + 1) * cell) - y0 + 0.5)
      }
    }
  }
}
