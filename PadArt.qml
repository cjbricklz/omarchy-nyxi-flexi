// The NYXI Flexi drawn from above, lighting up as buttons are pressed.
// Everything is drawn from the shapes in Art.js (curves, circles, fillets and a hexagon lattice) in
// drawing coordinates, 780 x 550, scaled to the width given.
import QtQuick
import qs.Commons
import "Model.js" as Model
import "Art.js" as Art

Item {
  id: art

  property var ui: null                 // the panel: down(), dpad(), stickAxis(), face
  readonly property real s: width / Art.WIDTH
  readonly property color fg: ui.bar.foreground
  readonly property var pos: Art.FRONT
  function tint(alpha) { return Qt.rgba(fg.r, fg.g, fg.b, alpha) }

  implicitHeight: Art.HEIGHT * s
  height: implicitHeight

  Item {
    id: layer
    opacity: art.ui.connected ? 1 : 0.35
    width: Art.WIDTH; height: Art.HEIGHT
    scale: art.s
    transformOrigin: Item.TopLeft

    // ---------- Static drawing ----------
    Line { path: art.pos.body; stroke: art.tint(0.55) }
    Line { path: art.pos.plate; stroke: art.tint(0.35) }
    Line { path: Art.gripHexPaths(); stroke: art.tint(0.3); strokeWidth: 1.6 }
    Line { path: art.pos.dpadRing; stroke: art.tint(0.35) }
    Line { path: art.pos.dpadPlus; stroke: art.tint(0.55) }
    Line { path: art.pos.stickL.ring; stroke: art.tint(0.3) }
    Line { path: art.pos.stickR.ring; stroke: art.tint(0.3) }
    Line { path: art.pos.dot; stroke: art.tint(0.5) }

    // ---------- Live parts ----------
    // Sticks: the cap follows the axes and the socket fills when the stick is clicked in.
    Stick { spec: art.pos.stickL; sx: art.ui.stickAxis("lx"); sy: art.ui.stickAxis("ly"); pressed: art.ui.down(Model.BTN.l3) }
    Stick { spec: art.pos.stickR; sx: art.ui.stickAxis("rx"); sy: art.ui.stickAxis("ry"); pressed: art.ui.down(Model.BTN.r3) }

    // D-pad: the four arms of the plus fill when pressed.
    Arm { arm: art.pos.dpadArm.up; tri: art.pos.dpadTri.up; on: art.ui.dpad(Model.BTN.dpadUp, Model.ABS.hat0y, -1) }
    Arm { arm: art.pos.dpadArm.down; tri: art.pos.dpadTri.down; on: art.ui.dpad(Model.BTN.dpadDown, Model.ABS.hat0y, 1) }
    Arm { arm: art.pos.dpadArm.left; tri: art.pos.dpadTri.left; on: art.ui.dpad(Model.BTN.dpadLeft, Model.ABS.hat0x, -1) }
    Arm { arm: art.pos.dpadArm.right; tri: art.pos.dpadTri.right; on: art.ui.dpad(Model.BTN.dpadRight, Model.ABS.hat0x, 1) }

    // Face buttons: the letters follow the layout the controller reports as.
    Key { spec: art.pos.faceN; label: art.ui.face.north; on: art.ui.down(Model.BTN.north) }
    Key { spec: art.pos.faceW; label: art.ui.face.west; on: art.ui.down(Model.BTN.west) }
    Key { spec: art.pos.faceE; label: art.ui.face.east; on: art.ui.down(Model.BTN.east) }
    Key { spec: art.pos.faceS; label: art.ui.face.south; on: art.ui.down(Model.BTN.south) }

    // Centre: view and menu, the Flexi's own T and M buttons (which send no input), and the logo button.
    Key { spec: art.pos.view; label: "⧉"; on: art.ui.down(Model.BTN.back) || art.ui.down(Model.BTN.viewAlt) }
    Key { spec: art.pos.menu; label: "≡"; on: art.ui.down(Model.BTN.start) }
    Key { spec: art.pos.t; label: "T"; on: false; dim: true }
    Key { spec: art.pos.m; label: "M"; on: false; dim: true }
    Key { spec: art.pos.home; label: "◎"; on: art.ui.down(Model.BTN.home) || art.ui.down(Model.BTN.homeAlt) }

    // The four channel lights in the slots above the centre buttons; the one for the current mode glows.
    Repeater {
      model: art.pos.leds
      Rectangle {
        readonly property bool lit: art.ui.connected && Model.ledFor(art.ui.mode) === index + 1
        x: modelData.x; y: modelData.y; width: modelData.w; height: modelData.h
        radius: height / 2
        color: lit ? Model.LED_COLORS[index] : art.tint(0.12)
        border.width: lit ? 0 : 1.5
        border.color: art.tint(0.4)
      }
    }
  }

  // A button on the drawing: outlined, filled with the accent while pressed. `spec` is its centre and radius.
  component Key: Rectangle {
    property var spec: null
    property bool on: false
    property string label: ""
    property bool dim: false
    x: spec.x - spec.r; y: spec.y - spec.r
    width: spec.r * 2; height: width; radius: spec.r
    color: on ? Color.accent : Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 0.85)
    border.width: 2
    border.color: art.tint(on ? 0.9 : dim ? 0.3 : 0.55)
    Text {
      anchors.centerIn: parent
      text: parent.label
      color: parent.on ? Color.background : art.tint(parent.dim ? 0.5 : 1)
      font.family: art.ui.bar.fontFamily
      font.pixelSize: Math.min(parent.height * 0.58, 26)
      font.bold: true
    }
  }

  // One arm of the D-pad: filled while pressed, with its triangle.
  component Arm: Item {
    property string arm: ""
    property string tri: ""
    property bool on: false
    Line { path: parent.arm; stroke: "transparent"; fill: parent.on ? Color.accent : "transparent" }
    Line { path: parent.tri; strokeWidth: 1.6; stroke: parent.on ? Color.background : art.tint(0.5) }
  }

  // A thumbstick: a fixed socket that fills when the stick is clicked in, and a cap that moves with the axes.
  component Stick: Item {
    property var spec: null
    property real sx: 0
    property real sy: 0
    property bool pressed: false
    readonly property bool moved: Math.abs(sx) > 0.05 || Math.abs(sy) > 0.05
    Rectangle {
      x: spec.socket.x - spec.socket.r; y: spec.socket.y - spec.socket.r
      width: spec.socket.r * 2; height: width; radius: spec.socket.r
      color: pressed ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3) : "transparent"
      border.width: 2
      border.color: art.tint(0.5)
    }
    Rectangle {
      width: spec.cap.r * 2; height: width; radius: spec.cap.r
      x: spec.cap.x - spec.cap.r + sx * 16
      y: spec.cap.y - spec.cap.r + sy * 16
      color: moved || pressed ? Color.accent : art.tint(0.2)
      border.width: 2
      border.color: art.tint(0.6)
      Rectangle {   // the flat top of the cap
        anchors.centerIn: parent
        width: parent.width * 0.7; height: width; radius: width / 2
        color: "transparent"
        border.width: 1.5
        border.color: Qt.rgba(0, 0, 0, 0.3)
      }
    }
  }
}
