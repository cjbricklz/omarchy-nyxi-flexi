// NYXI Flexi bar widget + popup: download the user manual and watch the
// controller's buttons, sticks and triggers react live. Read-only: it never
// grabs the device or sends anything to it.
// Modeled on the built-in omarchy.monitor panel.
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "Model.js" as Model

Panel {
  id: root
  moduleName: "puck.nyxi-flexi"
  ipcTarget: "puck.nyxi-flexi"

  // ---------- Controller state, fed by gamepad-reader.py while the popup is open ----------
  property var dev: null            // last "dev" message, null while no controller is found
  property var keys: ({})           // evdev button code -> 0|1
  property var axes: ({})           // evdev axis code -> raw value
  property var battery: null        // {pct, status} from the reader; pct is null when the controller reports none
  readonly property bool connected: dev !== null
  readonly property var face: Model.faceLabels(dev ? dev.vendor : 0)
  readonly property string mode: dev ? Model.modeFor(dev.vendor, dev.product) : ""
  readonly property var others: Model.otherPressed(keys)

  function down(code) { return !!keys[code] }
  // Which axis carries each control depends on the mode and connection; see Model.axisMap.
  readonly property var axmap: Model.axisMap(dev ? dev.abs : null)
  function stickAxis(role) {
    var code = axmap[role]
    return Model.stick(axes[code], dev ? dev.abs[code] : null)
  }
  // Analog trigger when the controller reports one (XInput), else its digital button (Switch Pro).
  function trigger(role, btnCode) {
    var code = axmap[role]
    if (dev && dev.abs[code] !== undefined) return Model.trigger(axes[code], dev.abs[code])
    return down(btnCode) ? 1 : 0
  }
  // D-pad as buttons or as a hat axis, depending on the mode.
  function dpad(btnCode, hatCode, sign) {
    return down(btnCode) || (axes[hatCode] !== undefined && Math.sign(axes[hatCode]) === sign)
  }

  // ---------- Back paddles ----------
  // The paddles send no signal of their own: the controller presses another button for them, so a
  // paddle can only light up with the button it copies. Out of the box the Flexi has M1 on View,
  // M2 on Menu, M3 on D-pad left and M4 on D-pad right. Click a paddle, then press it, to follow
  // whatever it does on your controller; "m1" to "m4" in this widget's shell.json entry keep that.
  property var paddleBindings: ({})
  property string learning: ""
  function paddleBinding(name) {
    var b = paddleBindings[name]
    return b !== undefined ? b : Model.parseBinding(setting(name, ""))
  }
  function paddleDown(name) {
    var b = paddleBinding(name)
    if (b) return Model.bindingDown(b, keys, axes)
    if (name === "m1") return down(Model.BTN.back) || down(Model.BTN.viewAlt)
    if (name === "m2") return down(Model.BTN.start)
    if (name === "m3") return dpad(Model.BTN.dpadLeft, Model.ABS.hat0x, -1)
    return dpad(Model.BTN.dpadRight, Model.ABS.hat0x, 1)
  }
  function learn(name) {
    if (learning === name) { learning = ""; log("assignment cancelled"); return }
    learning = name
    log("press " + name.toUpperCase() + " on the back of the controller")
  }
  function learnFrom(msg) {
    var b = Model.bindingFromFrame(msg)
    if (!b) return
    var next = Object.assign({}, paddleBindings)
    next[learning] = b
    paddleBindings = next
    log(learning.toUpperCase() + " follows " + Model.bindingText(b) + "   keep it with \"" + learning + "\": \"" + Model.bindingText(b) + "\" in shell.json")
    learning = ""
  }

  // Console: the last few things the reader reported, so it is visible that input arrives.
  property var logLines: []
  property int eventCount: 0
  property var loggedAxes: ({})
  readonly property int logSize: 9

  function log(text) {
    var lines = logLines.concat([text])
    logLines = lines.slice(-logSize)
  }

  function handle(line) {
    var msg = Model.parseLine(line)
    if (!msg) { log("? " + line); return }
    if (msg.t === "dev") {
      log("connected: " + msg.name + " (" + Model.hex(msg.vendor) + ":" + Model.hex(msg.product) + ")")
      loggedAxes = ({})
      dev = msg
      var led = Model.ledFor(mode)
      log("mode: " + mode + (led ? " (channel light " + led + ")" : "") + ", " + face.east + " on the right and " + face.south + " at the bottom")
      var first = Model.applyFrame({}, {}, msg)
      keys = first.keys
      axes = first.axes
    } else if (msg.t === "bat") {
      if (!battery || battery.pct !== msg.pct) {
        log(msg.pct === null ? "battery: not reported over this connection"
            : "battery: " + (msg.level ? msg.level.toLowerCase() : msg.pct + "%") + " " + msg.status.toLowerCase())
      }
      battery = msg
    } else if (msg.t === "s") {
      if (learning !== "") learnFrom(msg)
      var described = Model.describeFrame(msg, face, dev ? dev.abs : null, loggedAxes)
      eventCount += Object.keys(msg.k || {}).length + Object.keys(msg.a || {}).length
      described.forEach(function (l) { log(l) })
      var next = Model.applyFrame(keys, axes, msg)
      keys = next.keys
      axes = next.axes
    } else {
      log(msg.t === "gone" ? "controller disconnected" : "waiting for a controller")
      dev = null
      battery = null
      keys = ({})
      axes = ({})
    }
  }

  function localPath(name) {
    return decodeURIComponent(String(Qt.resolvedUrl(name)).replace(/^file:\/\//, ""))
  }

  function stateJson() {
    return JSON.stringify({ connected: connected, mode: mode, name: dev ? dev.name : "",
                            keys: keys, axes: axes, battery: battery })
  }

  IpcHandler {
    target: "puck.nyxi-flexi.pad"
    function state(): string { return root.stateJson() }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // The reader only runs while the popup is open, so the widget costs nothing otherwise.
  onOpenedChanged: {
    if (opened) { logLines = []; eventCount = 0; log("starting input reader…") }
    reader.running = opened
    if (!opened) { dev = null; battery = null; keys = ({}); axes = ({}) }
  }

  Process {
    id: reader
    command: ["python3", root.localPath("gamepad-reader.py")]
    stdout: SplitParser { onRead: function(line) { root.handle(line) } }
    stderr: SplitParser { onRead: function(line) { root.log("reader error: " + line) } }
    onExited: function(code) { if (root.opened) root.log("reader stopped (exit " + code + ")") }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: Model.ICON.pad
    onPressed: function(b) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(780))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(940))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(12)

        // ---------- Hero ----------
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroText.implicitHeight, batteryView.implicitHeight)
          BatteryView {
            id: batteryView
            // XInput never reports a charge, so the icon only shows there if the kernel does give one.
            visible: root.connected && (root.mode !== "XInput" || (root.battery !== null && root.battery.pct !== null))
            info: root.battery
            anchors.right: parent.right
            anchors.rightMargin: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
          }
          Text {
            id: heroIcon
            text: Model.ICON.pad
            color: root.connected ? Color.accent : Qt.darker(root.bar.foreground, 1.8)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.display
            anchors.verticalCenter: parent.verticalCenter
          }
          Column {
            id: heroText
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: batteryView.left
            anchors.rightMargin: Style.space(14)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)
            Text {
              text: "NYXI Flexi"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }
            Text {
              text: root.connected ? "CONNECTED · " + root.mode.toUpperCase() + " MODE" : "NO CONTROLLER FOUND"
              color: root.connected ? Color.accent : Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
            }
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        // ---------- Live controller: front and back, the same size ----------
        Row {
          id: views
          width: parent.width
          spacing: Style.space(20)
          readonly property real viewWidth: (width - spacing) / 2

          Column {
            width: views.viewWidth
            spacing: Style.space(10)
            ViewCaption { text: "FRONT" }
            PadArt { width: parent.width; ui: root }
          }

          Column {
            width: views.viewWidth
            spacing: Style.space(10)
            ViewCaption { text: "BACK" }
            PadBack { width: parent.width; ui: root }
          }
        }
        Text {
          width: parent.width
          wrapMode: Text.WordWrap
          text: "Paddles copy other buttons, so each lights with the one it repeats. Click one, then press it, to change what it follows."
          color: Qt.darker(root.bar.foreground, 1.4)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
        }

        Column {
          visible: root.connected
          width: parent.width
          spacing: Style.space(8)
          PanelSeparator { foreground: root.bar.foreground }
          Stat { label: "LEFT STICK"
                 value: Model.formatAxis(root.stickAxis("lx")) + "  " + Model.formatAxis(root.stickAxis("ly")) }
          Stat { label: "RIGHT STICK"
                 value: Model.formatAxis(root.stickAxis("rx")) + "  " + Model.formatAxis(root.stickAxis("ry")) }
          Stat { label: "TRIGGERS  L2  R2"
                 value: Model.formatAxis(root.trigger("lt", Model.BTN.ltDigital)) + "  "
                        + Model.formatAxis(root.trigger("rt", Model.BTN.rtDigital)) }
          Stat { visible: root.others.length > 0; label: "OTHER BUTTONS"; value: root.others.join("  ") }
          Stat { label: "DEVICE"; value: root.dev ? root.dev.name : "" }
        }

        // ---------- Console ----------
        Column {
          width: parent.width
          spacing: Style.space(6)
          Item {
            width: parent.width
            implicitHeight: consoleHeader.implicitHeight
            PanelSectionHeader {
              id: consoleHeader
              text: "CONSOLE"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              text: root.eventCount + " inputs"
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              anchors.right: parent.right
              anchors.rightMargin: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
            }
          }
          Rectangle {
            width: parent.width
            height: consoleText.implicitHeight + Style.space(12)
            radius: Style.space(3)
            color: Qt.rgba(0, 0, 0, 0.25)
            border.width: 1
            border.color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.25)
            Text {
              id: consoleText
              anchors.fill: parent
              anchors.margins: Style.space(6)
              // Always nine lines tall, so the popup does not jump as the log fills.
              text: root.logLines.join("\n") + new Array(Math.max(0, root.logSize - root.logLines.length) + 1).join("\n ")
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.NoWrap
              elide: Text.ElideRight
              clip: true
            }
          }
        }

        Text {
          visible: !root.connected
          width: parent.width
          wrapMode: Text.WordWrap
          text: "Turn the controller on. Over the 2.4G receiver, hold B + HOME to power on, plug in the receiver and hold its button for 3 seconds. For Bluetooth, hold A + HOME and pair \"Xbox Wireless Controller\"."
          color: Qt.darker(root.bar.foreground, 1.4)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
        }

        Text {
          visible: root.connected
          width: parent.width
          wrapMode: Text.WordWrap
          text: "BACK + START held for 3 s cycles XInput, Switch Pro and DInput. T, M and the RGB button work inside the controller and send nothing to the PC."
          color: Qt.darker(root.bar.foreground, 1.4)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
        }

        Item { width: parent.width; height: Style.space(4) }
      }
    }
  }

  // A battery drawn to its charge, with the percentage beside it. Without a reading it is empty and says N/A.
  component BatteryView: Row {
    property var info: null
    readonly property bool known: info !== null && info.pct !== null
    readonly property int pct: known ? Math.max(0, Math.min(100, info.pct)) : 0
    readonly property bool charging: info !== null && info.status === "Charging"
    readonly property color level: !known ? Qt.darker(root.bar.foreground, 1.6)
        : pct < 15 ? Color.urgent : pct < 40 ? "#e5c07b" : Color.accent
    spacing: Style.space(8)

    Item {
      id: icon
      width: Style.space(46)
      height: Style.space(22)
      anchors.verticalCenter: parent.verticalCenter
      Rectangle {   // the case
        width: Style.space(42)
        height: parent.height
        radius: Style.space(4)
        color: "transparent"
        border.width: 2
        border.color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.7)
        Rectangle {   // the charge
          x: 3; y: 3
          height: parent.height - 6
          width: Math.max(0, (parent.width - 6) * pct / 100)
          radius: Style.space(2)
          color: level
        }
        Text {
          anchors.centerIn: parent
          visible: charging || !known
          text: charging ? "⚡" : "–"
          color: charging && pct > 50 ? Color.background : root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }
      Rectangle {   // the contact
        x: Style.space(43)
        y: (parent.height - height) / 2
        width: Style.space(3)
        height: Style.space(9)
        radius: Style.space(1)
        color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.7)
      }
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: !known ? "N/A" : info.level ? info.level : pct + "%"
      color: known ? root.bar.foreground : Qt.darker(root.bar.foreground, 1.4)
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.title
      font.bold: true
    }
  }

  component ViewCaption: Text {
    color: Qt.darker(root.bar.foreground, 1.4)
    font.family: root.bar.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
    font.letterSpacing: 1.2
  }

  component Stat: Item {
    property string label
    property string value
    width: parent ? parent.width : 0
    implicitHeight: statLabel.implicitHeight
    Text {
      id: statLabel
      text: parent.label
      color: Qt.darker(root.bar.foreground, 1.4)
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      font.letterSpacing: 1.2
      anchors.left: parent.left
      anchors.leftMargin: Style.space(6)
    }
    Text {
      text: parent.value
      color: root.bar.foreground
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.body
      anchors.right: parent.right
      anchors.rightMargin: Style.space(6)
      anchors.verticalCenter: statLabel.verticalCenter
      elide: Text.ElideLeft
    }
  }
}
