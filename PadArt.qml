// The NYXI Flexi drawn from above, lighting up as buttons are pressed.
// Everything is drawn from the shapes in Art.js (curves, circles, rounded rectangles and a hexagon lattice)
// in drawing coordinates, 780 x 550, scaled to the width given.
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
    Line { path: Art.bodyPath(); stroke: art.tint(0.5) }
    Line { path: Art.gripHexPaths(); stroke: art.tint(0.35); strokeWidth: 1.8 }
    Line { path: Art.roundRect(art.pos.dpad.x - 20, art.pos.dpad.y - 20, 40, 40, 8); stroke: art.tint(0.3) }

    // ---------- Live parts ----------
    // Sticks: the cap follows the axes and the socket fills when the stick is clicked in.
    Stick { spec: art.pos.stickL; sx: art.ui.stickAxis("lx"); sy: art.ui.stickAxis("ly"); pressed: art.ui.down(Model.BTN.l3) }
    Stick { spec: art.pos.stickR; sx: art.ui.stickAxis("rx"); sy: art.ui.stickAxis("ry"); pressed: art.ui.down(Model.BTN.r3) }

    // D-pad: four keys around a fixed centre.
    Key { at: Qt.point(art.pos.dpad.x, art.pos.dpad.y - 46); size: 40; square: true; label: "▲"; on: art.ui.dpad(Model.BTN.dpadUp, Model.ABS.hat0y, -1) }
    Key { at: Qt.point(art.pos.dpad.x, art.pos.dpad.y + 46); size: 40; square: true; label: "▼"; on: art.ui.dpad(Model.BTN.dpadDown, Model.ABS.hat0y, 1) }
    Key { at: Qt.point(art.pos.dpad.x - 46, art.pos.dpad.y); size: 40; square: true; label: "◀"; on: art.ui.dpad(Model.BTN.dpadLeft, Model.ABS.hat0x, -1) }
    Key { at: Qt.point(art.pos.dpad.x + 46, art.pos.dpad.y); size: 40; square: true; label: "▶"; on: art.ui.dpad(Model.BTN.dpadRight, Model.ABS.hat0x, 1) }

    // Face buttons: the letters follow the layout the controller reports as.
    Key { at: Qt.point(art.pos.faceN.x, art.pos.faceN.y); size: 50; label: art.ui.face.north; on: art.ui.down(Model.BTN.north) }
    Key { at: Qt.point(art.pos.faceW.x, art.pos.faceW.y); size: 50; label: art.ui.face.west; on: art.ui.down(Model.BTN.west) }
    Key { at: Qt.point(art.pos.faceE.x, art.pos.faceE.y); size: 50; label: art.ui.face.east; on: art.ui.down(Model.BTN.east) }
    Key { at: Qt.point(art.pos.faceS.x, art.pos.faceS.y); size: 50; label: art.ui.face.south; on: art.ui.down(Model.BTN.south) }

    // Centre: view and menu, the Flexi's own T and M buttons (which send no input), and the logo button.
    Key { at: Qt.point(art.pos.view.x, art.pos.view.y); size: 38; label: "⧉"; on: art.ui.down(Model.BTN.back) || art.ui.down(Model.BTN.viewAlt) }
    Key { at: Qt.point(art.pos.menu.x, art.pos.menu.y); size: 38; label: "≡"; on: art.ui.down(Model.BTN.start) }
    Key { at: Qt.point(art.pos.t.x, art.pos.t.y); size: 38; label: "T"; on: false; dim: true }
    Key { at: Qt.point(art.pos.m.x, art.pos.m.y); size: 38; label: "M"; on: false; dim: true }
    Key { at: Qt.point(art.pos.home.x, art.pos.home.y); size: 46; label: "◎"; on: art.ui.down(Model.BTN.home) || art.ui.down(Model.BTN.homeAlt) }

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

  // A button on the drawing: outlined, filled with the accent while pressed. Placed by its centre.
  component Key: Rectangle {
    property point at: Qt.point(0, 0)
    property real size: 40
    property bool on: false
    property string label: ""
    property bool square: false
    property bool dim: false
    x: at.x - size / 2; y: at.y - size / 2
    width: size; height: size
    radius: square ? 8 : size / 2
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

  // A thumbstick: a fixed socket that fills when the stick is clicked in, and a cap that moves with the axes.
  component Stick: Item {
    property var spec: null
    property real sx: 0
    property real sy: 0
    property bool pressed: false
    readonly property bool moved: Math.abs(sx) > 0.05 || Math.abs(sy) > 0.05
    Rectangle {
      x: spec.x - spec.socket; y: spec.y - spec.socket
      width: spec.socket * 2; height: width; radius: width / 2
      color: pressed ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3) : "transparent"
      border.width: 2
      border.color: art.tint(0.5)
    }
    Rectangle {
      width: spec.cap; height: width; radius: width / 2
      x: spec.x - width / 2 + sx * 16
      y: spec.y - height / 2 + sy * 16
      color: moved || pressed ? Color.accent : art.tint(0.2)
      border.width: 2
      border.color: art.tint(0.6)
      Rectangle {   // the textured top of the cap
        anchors.centerIn: parent
        width: parent.width * 0.62; height: width; radius: width / 2
        color: "transparent"
        border.width: 1.5
        border.color: Qt.rgba(0, 0, 0, 0.3)
      }
    }
  }
}
