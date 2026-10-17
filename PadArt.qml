// The NYXI Flexi drawn from above, lighting up as buttons are pressed.
// The outline is NYXI's own line drawing traced to vectors (Paths.js, made by tools/trace-art.py).
// The parts that light up are separate items placed over the gaps left in it. Coordinates are pixels of
// that drawing (the visible part spans x 50..830, y 240..790); everything is scaled to the width given.
import QtQuick
import qs.Commons
import "Model.js" as Model
import "Paths.js" as Paths
import "Hexes.js" as Hexes

Item {
  id: art

  property var ui: null                 // the panel: down(), dpad(), stickAxis(), face
  readonly property real s: width / 780
  readonly property color fg: ui.bar.foreground
  function tint(alpha) { return Qt.rgba(fg.r, fg.g, fg.b, alpha) }

  implicitHeight: 550 * s
  height: implicitHeight

  // ---------- Static drawing ----------
  Lines {
    anchors.fill: parent
    opacity: art.ui.connected ? 1 : 0.35
    paths: Paths.PATHS
    viewX: 50; viewY: 240; viewW: 780
    color: art.tint(0.5)
  }
  Canvas {   // the grip hexagons, redrawn identical and clean, and the status LED
    anchors.fill: parent
    onWidthChanged: requestPaint()
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      ctx.scale(art.s, art.s)
      ctx.translate(-50, -240)
      ctx.strokeStyle = art.tint(0.5)
      ctx.lineWidth = 2.2
      ctx.lineJoin = "round"
      ctx.beginPath()
      var hexes = Hexes.HEXES
      for (var i = 0; i < hexes.length; i++) {
        var h = hexes[i]
        for (var k = 0; k < 6; k++) {     // pointy-top, as on the grips
          var a = Math.PI / 6 + k * Math.PI / 3
          var x = h[0] + h[2] * Math.cos(a), y = h[1] + h[2] * Math.sin(a)
          if (k === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
        }
        ctx.closePath()
      }
      ctx.moveTo(441.5, 445)
      ctx.arc(438.5, 445, 3, 0, 2 * Math.PI)   // status LED
      ctx.stroke()
    }
  }

  // ---------- Live parts, in drawing coordinates ----------
  Item {
    id: layer
    opacity: art.ui.connected ? 1 : 0.35
    x: -50 * art.s
    y: -240 * art.s
    width: 1024
    height: 1024
    scale: art.s
    transformOrigin: Item.TopLeft

    // Sticks: the cap follows the axes and the socket fills when the stick is clicked in.
    Stick { socketX: 244; socketY: 372; socketR: 70; capX: 241; capY: 359; capD: 92
            sx: art.ui.stickAxis("lx"); sy: art.ui.stickAxis("ly"); pressed: art.ui.down(Model.BTN.l3) }
    Stick { socketX: 535; socketY: 489; socketR: 73; capX: 538; capY: 471; capD: 88
            sx: art.ui.stickAxis("rx"); sy: art.ui.stickAxis("ry"); pressed: art.ui.down(Model.BTN.r3) }

    // D-pad cross.
    Rectangle { x: 320; y: 466; width: 40; height: 44; color: art.tint(0.08) }
    Key { x: 320; y: 430; width: 40; height: 40; radius: 8; label: "▲"; on: art.ui.dpad(Model.BTN.dpadUp, Model.ABS.hat0y, -1) }
    Key { x: 320; y: 506; width: 40; height: 40; radius: 8; label: "▼"; on: art.ui.dpad(Model.BTN.dpadDown, Model.ABS.hat0y, 1) }
    Key { x: 280; y: 468; width: 42; height: 40; radius: 8; label: "◀"; on: art.ui.dpad(Model.BTN.dpadLeft, Model.ABS.hat0x, -1) }
    Key { x: 358; y: 468; width: 42; height: 40; radius: 8; label: "▶"; on: art.ui.dpad(Model.BTN.dpadRight, Model.ABS.hat0x, 1) }

    // Face buttons: the letters follow the layout the controller reports as.
    Key { x: 604; y: 304; width: 52; height: 52; round: true; label: art.ui.face.north; on: art.ui.down(Model.BTN.north) }
    Key { x: 557; y: 348; width: 52; height: 52; round: true; label: art.ui.face.west; on: art.ui.down(Model.BTN.west) }
    Key { x: 653; y: 348; width: 52; height: 52; round: true; label: art.ui.face.east; on: art.ui.down(Model.BTN.east) }
    Key { x: 607; y: 398; width: 52; height: 52; round: true; label: art.ui.face.south; on: art.ui.down(Model.BTN.south) }

    // Centre: view and menu, the Flexi's own T and M buttons (which send no input), and the logo button.
    Key { x: 338; y: 337; width: 38; height: 38; round: true; label: "⧉"; on: art.ui.down(Model.BTN.back) || art.ui.down(Model.BTN.viewAlt) }
    Key { x: 501; y: 336; width: 38; height: 38; round: true; label: "≡"; on: art.ui.down(Model.BTN.start) }
    Key { x: 382; y: 371; width: 40; height: 40; round: true; label: "T"; on: false; dim: true }
    Key { x: 455; y: 372; width: 40; height: 40; round: true; label: "M"; on: false; dim: true }
    Key { x: 417; y: 508; width: 46; height: 46; round: true; label: "◎"; on: art.ui.down(Model.BTN.home) || art.ui.down(Model.BTN.homeAlt) }

    // The four channel lights in the slots above the centre buttons; the one for the current mode glows.
    Repeater {
      model: [ { x: 398, y: 310.8, w: 79, h: 4.6 }, { x: 397, y: 325.2, w: 81, h: 4 },
               { x: 414, y: 339.4, w: 47, h: 3.8 }, { x: 431, y: 354, w: 13, h: 4.2 } ]
      Rectangle {
        readonly property bool lit: art.ui.connected && Model.ledFor(art.ui.mode) === index + 1
        x: modelData.x; y: modelData.y; width: modelData.w; height: modelData.h
        radius: height / 2
        color: lit ? Model.LED_COLORS[index] : art.tint(0.12)
      }
    }
  }

  // A button on the drawing: outlined, filled with the accent while pressed.
  component Key: Rectangle {
    property bool on: false
    property string label: ""
    property bool round: false
    property bool dim: false
    radius: round ? width / 2 : 8
    color: on ? Color.accent : Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 0.85)
    border.width: 2
    border.color: art.tint(on ? 0.9 : dim ? 0.3 : 0.55)
    Text {
      anchors.centerIn: parent
      text: parent.label
      color: parent.on ? Color.background : art.tint(parent.dim ? 0.5 : 1)
      font.family: art.ui.bar.fontFamily
      font.pixelSize: Math.min(parent.height * 0.62, 28)
      font.bold: true
    }
  }

  // A thumbstick. The socket is part of the traced drawing; this fills it when the stick is clicked in
  // and moves the cap with the axes. The cap sits a little above the socket, as in the drawing.
  component Stick: Item {
    property real socketX: 0
    property real socketY: 0
    property real socketR: 70
    property real capX: 0
    property real capY: 0
    property real capD: 90
    property real sx: 0
    property real sy: 0
    property bool pressed: false
    readonly property bool moved: Math.abs(sx) > 0.05 || Math.abs(sy) > 0.05
    Rectangle {
      x: parent.socketX - parent.socketR; y: parent.socketY - parent.socketR
      width: parent.socketR * 2; height: width; radius: width / 2
      color: parent.pressed ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3) : "transparent"
    }
    Rectangle {
      width: parent.capD; height: width; radius: width / 2
      x: parent.capX - width / 2 + parent.sx * 16
      y: parent.capY - height / 2 + parent.sy * 16
      color: parent.moved || parent.pressed ? Color.accent : art.tint(0.3)
      border.width: 2
      border.color: art.tint(0.6)
      Rectangle {   // the textured top of the cap
        anchors.centerIn: parent
        width: parent.width * 0.68; height: width; radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: Qt.rgba(0, 0, 0, 0.35)
      }
    }
  }
}
