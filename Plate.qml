// A button on the back: a filled outline that lights up with the input.
// `path` is in drawing coordinates, so it must sit in a layer scaled like the drawing.
import QtQuick
import QtQuick.Shapes
import qs.Commons

Item {
  id: plate

  property var ui: null
  property string path: ""
  property string label: ""
  property real labelX: 0        // where the label sits, in drawing coordinates
  property real labelY: 0
  property int labelSize: 24
  property real value: 0         // 0..1: how far it is pressed
  property bool dim: false       // draws quieter, for a button that is not assigned yet
  property bool pulsing: false   // waiting to be assigned
  property real pulse: 0

  signal clicked()

  readonly property color fg: ui.bar.foreground

  SequentialAnimation on pulse {
    running: plate.pulsing
    loops: Animation.Infinite
    NumberAnimation { from: 0; to: 1; duration: 600; easing.type: Easing.InOutSine }
    NumberAnimation { from: 1; to: 0; duration: 600; easing.type: Easing.InOutSine }
  }

  Shape {
    containsMode: Shape.FillContains
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b,
                         plate.pulsing ? 0.1 + 0.3 * plate.pulse : 0.1 + 0.8 * plate.value)
      strokeColor: Qt.rgba(plate.fg.r, plate.fg.g, plate.fg.b,
                           plate.value > 0 || plate.pulsing ? 0.95 : plate.dim ? 0.3 : 0.55)
      strokeWidth: 2.2
      joinStyle: ShapePath.RoundJoin
      PathSvg { path: plate.path }
    }
    TapHandler { onTapped: plate.clicked() }
  }

  Text {
    x: plate.labelX - width / 2
    y: plate.labelY - height / 2
    text: plate.label
    color: plate.value > 0.5 ? Color.background : Qt.rgba(plate.fg.r, plate.fg.g, plate.fg.b, plate.dim ? 0.55 : 1)
    font.family: plate.ui.bar.fontFamily
    font.pixelSize: plate.labelSize
    font.bold: true
  }
}
