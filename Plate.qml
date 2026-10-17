// A button on the back or top edge: a filled outline that lights up with the input.
// `points` are drawing coordinates, so it must sit in a layer scaled like the drawing.
import QtQuick
import QtQuick.Shapes
import qs.Commons

Item {
  id: plate

  property var ui: null
  property var points: []        // [[x, y], ...]
  property string label: ""
  property real labelX: NaN      // where the label sits; the middle of the outline unless set
  property real labelY: NaN
  property int labelSize: 24
  property real value: 0         // 0..1: how far it is pressed
  property bool dim: false       // draws quieter, for a button that is not assigned yet
  property bool pulsing: false   // waiting to be assigned
  property real pulse: 0

  signal clicked()

  readonly property color fg: ui.bar.foreground
  readonly property var bounds: {
    var x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity
    points.forEach(function (p) { x0 = Math.min(x0, p[0]); y0 = Math.min(y0, p[1]); x1 = Math.max(x1, p[0]); y1 = Math.max(y1, p[1]) })
    return { x: (x0 + x1) / 2, y: (y0 + y1) / 2 }
  }

  SequentialAnimation on pulse {
    running: plate.pulsing
    loops: Animation.Infinite
    NumberAnimation { from: 0; to: 1; duration: 600; easing.type: Easing.InOutSine }
    NumberAnimation { from: 1; to: 0; duration: 600; easing.type: Easing.InOutSine }
  }

  Shape {
    id: shape
    containsMode: Shape.FillContains
    ShapePath {
      fillColor: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b,
                         plate.pulsing ? 0.1 + 0.3 * plate.pulse : 0.1 + 0.8 * plate.value)
      strokeColor: Qt.rgba(plate.fg.r, plate.fg.g, plate.fg.b,
                           plate.value > 0 || plate.pulsing ? 0.95 : plate.dim ? 0.3 : 0.55)
      strokeWidth: 2
      joinStyle: ShapePath.RoundJoin
      PathPolyline { path: plate.points.map(function (p) { return Qt.point(p[0], p[1]) }) }
    }
    TapHandler { onTapped: plate.clicked() }
  }

  Text {
    x: (isNaN(plate.labelX) ? plate.bounds.x : plate.labelX) - width / 2
    y: (isNaN(plate.labelY) ? plate.bounds.y : plate.labelY) - height / 2
    text: plate.label
    color: plate.value > 0.5 ? Color.background : Qt.rgba(plate.fg.r, plate.fg.g, plate.fg.b, plate.dim ? 0.55 : 1)
    font.family: plate.ui.bar.fontFamily
    font.pixelSize: plate.labelSize
    font.bold: true
  }
}
