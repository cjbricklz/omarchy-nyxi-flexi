// The Flexi seen from behind: the triggers (R2, L2) on the shoulders, the bumpers (R1, L1) between them, and
// the four back paddles. The paddles send no signal of their own; the controller presses another button for
// them, so each lights with the button it repeats (see the panel).
// Drawn from the shapes in Art.js, in drawing coordinates scaled to the width given.
import QtQuick
import qs.Commons
import "Model.js" as Model
import "Art.js" as Art

Item {
  id: art

  property var ui: null
  readonly property real s: width / Art.WIDTH
  readonly property color fg: ui.bar.foreground

  implicitHeight: Art.HEIGHT * s
  height: implicitHeight

  Item {
    opacity: art.ui.connected ? 1 : 0.35
    width: Art.WIDTH; height: Art.HEIGHT
    scale: art.s
    transformOrigin: Item.TopLeft

    Line { path: Art.bodyPath(); stroke: Qt.rgba(art.fg.r, art.fg.g, art.fg.b, 0.5) }
    Line { path: Art.BACK.cover; stroke: Qt.rgba(art.fg.r, art.fg.g, art.fg.b, 0.3) }

    // Seen from behind, the controller's left side is on the right of the picture.
    // The big caps are the triggers (they fill as they are pulled); the thin strips between them are the bumpers.
    Plate { ui: art.ui; label: "R2"; path: Art.BACK.r2.path; labelX: Art.BACK.r2.lx; labelY: Art.BACK.r2.ly
            value: art.ui.trigger("rt", Model.BTN.rtDigital) }
    Plate { ui: art.ui; label: "L2"; path: Art.BACK.l2.path; labelX: Art.BACK.l2.lx; labelY: Art.BACK.l2.ly
            value: art.ui.trigger("lt", Model.BTN.ltDigital) }
    Plate { ui: art.ui; label: "R1"; labelSize: 18; path: Art.BACK.r1.path; labelX: Art.BACK.r1.lx; labelY: Art.BACK.r1.ly
            value: art.ui.down(Model.BTN.rb) ? 1 : 0 }
    Plate { ui: art.ui; label: "L1"; labelSize: 18; path: Art.BACK.l1.path; labelX: Art.BACK.l1.lx; labelY: Art.BACK.l1.ly
            value: art.ui.down(Model.BTN.lb) ? 1 : 0 }

    Repeater {
      model: [
        { name: "m2", label: "M2" }, { name: "m4", label: "M4" },
        { name: "m1", label: "M1" }, { name: "m3", label: "M3" }
      ]
      Plate {
        required property var modelData
        ui: art.ui
        path: Art.BACK[modelData.name].path
        label: modelData.label
        labelSize: 20
        labelX: Art.BACK[modelData.name].lx
        labelY: Art.BACK[modelData.name].ly
        value: art.ui.paddleDown(modelData.name) ? 1 : 0
        pulsing: art.ui.learning === modelData.name
        onClicked: art.ui.learn(modelData.name)
      }
    }
  }
}
