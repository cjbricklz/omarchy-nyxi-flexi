// A stroked (and optionally filled) SVG path. Paths are in drawing coordinates, so it must sit in a layer
// scaled like the drawing. The curve renderer keeps edges smooth at any scale.
import QtQuick
import QtQuick.Shapes

Shape {
  id: line
  property string path: ""
  property color stroke: "white"
  property color fill: "transparent"
  property real strokeWidth: 2.2

  preferredRendererType: Shape.CurveRenderer
  ShapePath {
    strokeColor: line.stroke
    fillColor: line.fill
    strokeWidth: line.strokeWidth
    joinStyle: ShapePath.RoundJoin
    capStyle: ShapePath.RoundCap
    PathSvg { path: line.path }
  }
}
