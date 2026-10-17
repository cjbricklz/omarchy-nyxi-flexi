// The Flexi seen from behind: the shoulder bumpers (R1, L1) with the triggers (R2, L2) above them, and the
// four back paddles. The paddles send no signal of their own; the controller presses another button for
// them, so each lights with the button it repeats (see the panel).
// Drawing coordinates are pixels of NYXI's back-view drawing.
import QtQuick
import qs.Commons
import "Model.js" as Model
import "PathsBack.js" as Paths
import "RegionsBack.js" as Regions
import "Qr.js" as Qr

Item {
  id: art

  property var ui: null
  // Same on-screen size as the front view: the back drawing's body is 540 px wide to the front's 762,
  // so it shows a 575 px window against the front's 780.
  readonly property real s: width / 575
  readonly property color fg: ui.bar.foreground

  implicitHeight: 405 * s
  height: implicitHeight

  Lines {
    anchors.fill: parent
    opacity: art.ui.connected ? 1 : 0.35
    paths: Paths.PATHS
    viewX: 228; viewY: 57; viewW: 575
    color: Qt.rgba(art.fg.r, art.fg.g, art.fg.b, 0.5)
  }

  Item {
    x: -228 * art.s; y: -57 * art.s
    opacity: art.ui.connected ? 1 : 0.35
    width: 1024; height: 1024
    scale: art.s
    transformOrigin: Item.TopLeft

    // Seen from behind, the controller's left side is on the right of the picture. The outlines are
    // flood-filled from the drawing (tools/regions.py), so they match the buttons exactly.
    // The big caps are the triggers (they fill as they are pulled); the thin strips beside them are the bumpers.
    Plate { ui: art.ui; label: "R2"; points: Regions.REGIONS.capr; value: art.ui.trigger("rt", Model.BTN.rtDigital) }
    Plate { ui: art.ui; label: "L2"; points: Regions.REGIONS.capl; value: art.ui.trigger("lt", Model.BTN.ltDigital) }
    Plate { ui: art.ui; label: "R1"; labelSize: 20; points: Regions.REGIONS.bumpr; value: art.ui.down(Model.BTN.rb) ? 1 : 0 }
    Plate { ui: art.ui; label: "L1"; labelSize: 20; points: Regions.REGIONS.bumpl; value: art.ui.down(Model.BTN.lb) ? 1 : 0 }

    Repeater {
      model: [
        { name: "m2", label: "M2", lx: 408, ly: 259 },
        { name: "m4", label: "M4", lx: 402, ly: 312 },
        { name: "m1", label: "M1", lx: 623, ly: 259 },
        { name: "m3", label: "M3", lx: 629, ly: 312 }
      ]
      Plate {
        required property var modelData
        ui: art.ui
        points: Regions.REGIONS[modelData.name]
        label: modelData.label
        labelX: modelData.lx
        labelY: modelData.ly
        value: art.ui.paddleDown(modelData.name) ? 1 : 0
        pulsing: art.ui.learning === modelData.name
        onClicked: art.ui.learn(modelData.name)
      }
    }
  }

  // A QR code to the manual, in the middle of the back. Tap it to open the manual. It is made for the
  // default address, so it is hidden if "manualUrl" is changed in the widget's settings.
  QrCode {
    visible: art.ui.manualUrl === Qr.URL
    x: (515.5 - 52 - 228) * art.s
    y: (232 - 52 - 57) * art.s
    width: 104 * art.s
    height: width
    ink: Color.background
    paper: art.fg
    TapHandler { onTapped: art.ui.openManualOnline() }
  }
}
