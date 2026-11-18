import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "munzlind.wwan"
  ipcTarget: "munzlind.wwan"
  manageIpc: false

  readonly property string pluginDir: Quickshell.env("HOME") + "/Git/omarchy-wwan"
  readonly property string helper: pluginDir + "/scripts/wwan-status"
  readonly property string profile: String(setting("profile", "O2") || "O2")
  readonly property string displayMode: String(setting("displayMode", "full") || "full")
  readonly property bool hideWhenUnavailable: setting("hideWhenUnavailable", true) !== false
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  property var info: ({})
  property var rateState: ({ iface: "", rx: 0, tx: 0, time: 0, download: 0, upload: 0 })
  property real sessionRx: 0
  property real sessionTx: 0
  property bool actionPending: false
  property string lastError: ""

  readonly property bool available: info.available === "1"
  readonly property bool connected: Model.connected(info)
  readonly property bool locked: String(info.lock || "") === "sim-pin" || String(info.lock || "") === "sim-puk"
  readonly property int signal: Math.round(Model.number(info.signal, -1))
  readonly property string technology: String(info.technology || "").toUpperCase()
  readonly property string technologyLabel: technology || "MOBILE"
  readonly property string glyph: Model.signalIcon(signal, String(info.state || ""), locked, connected)
  readonly property string downRate: Model.formatRate(rateState.download)
  readonly property string upRate: Model.formatRate(rateState.upload)
  readonly property string sessionTotal: Model.formatBytes(sessionRx + sessionTx)
  readonly property string barLabel: {
    if (!available) return ""
    return technologyLabel
  }
  readonly property string statusText: {
    if (!available) return strings.t("status.unavailable")
    if (locked) return strings.t("status.locked")
    if (connected) return strings.t("status.connected")
    if (actionPending) return strings.t("status.changing")
    return String(info.state || strings.t("status.disconnected"))
  }

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function updateStatus(raw) {
    var next = Model.parseTabValues(raw)
    if (Object.keys(next).length === 0) return
    info = next
    if (!Model.connected(next)) {
      rateState = { iface: "", rx: 0, tx: 0, time: 0, download: 0, upload: 0 }
      sessionRx = 0
      sessionTx = 0
    }
  }

  function refreshRates() {
    var iface = String(info.iface || "")
    if (!connected || iface === "" || ratesProc.running) return
    ratesProc.command = [helper, "rates", iface]
    ratesProc.running = true
  }

  function updateRates(raw) {
    var sample = Model.parseTabValues(raw)
    if (sample.rx_bytes === undefined || sample.tx_bytes === undefined) return
    sample.iface = String(info.iface || "")
    var previous = rateState
    var next = Model.nextRates(previous, sample, Date.now())
    // Accumulate this connection's data. A lower counter means the interface
    // reset its statistics, so the new value itself is the delta, not a spike.
    var rxNow = Number(sample.rx_bytes) || 0
    var txNow = Number(sample.tx_bytes) || 0
    var prevRx = Number(previous.rx) || 0
    var prevTx = Number(previous.tx) || 0
    if (previous.iface === next.iface) {
      sessionRx += Math.max(0, rxNow >= prevRx ? rxNow - prevRx : rxNow)
      sessionTx += Math.max(0, txNow >= prevTx ? txNow - prevTx : txNow)
    } else if (previous.iface !== "" || next.iface !== "") {
      sessionRx = 0
      sessionTx = 0
    }
    rateState = next
  }

  function setConnection(up) {
    if (actionPending || actionProc.running || profile === "") return
    actionPending = true
    lastError = ""
    actionProc.command = up
      ? ["nmcli", "--wait", "0", "connection", "up", "id", profile]
      : ["nmcli", "connection", "down", "id", profile]
    actionProc.running = true
  }

  function openSettings() { Quickshell.execDetached(["nm-connection-editor"]) }

  IpcHandler {
    target: "munzlind.wwan"
    function open() { root.open() }
    function close() { root.close() }
    function toggle() { root.toggle() }
    function connect() { root.setConnection(true) }
    function disconnect() { root.setConnection(false) }
  }

  visible: available || !hideWhenUnavailable
  implicitWidth: visible ? button.implicitWidth : 0
  implicitHeight: visible ? button.implicitHeight : 0
  Component.onCompleted: refresh()
  onOpenedChanged: if (opened) refresh()

  Process {
    id: statusProc
    command: ["env", "WWAN_PROFILE=" + root.profile, root.helper]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.updateStatus(text) }
  }
  Process {
    id: ratesProc
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.updateRates(text) }
  }
  Process {
    id: actionProc
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: function(text) { if (text.trim() !== "") root.lastError = text.trim() } }
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: function(text) { if (text.trim() !== "") root.lastError = text.trim() } }
    onExited: function(code) {
      if (code !== 0 && root.lastError === "") root.lastError = strings.t("error.connection")
      root.actionPending = false
      actionRefresh.restart()
    }
  }
  Timer { interval: root.available ? 15000 : 120000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
  Timer { interval: 1000; running: root.connected; repeat: true; triggeredOnStart: true; onTriggered: root.refreshRates() }
  Timer { id: actionRefresh; interval: 1200; onTriggered: root.refresh() }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // BarIconButton renders `text` through OpticalGlyph. Keep it to one icon
    // and put readable status text in its dedicated label rather than trying
    // to render the whole label as a glyph.
    text: root.glyph
    labelText: root.barLabel
    slotSize: Style.bar.iconSlot * 2.5
    tooltipText: root.available
      ? (String(root.info.operator || strings.t("label.mobile")) + " · " + root.statusText + (root.connected ? " · ↓ " + root.downRate + " · ↑ " + root.upRate : ""))
      : strings.t("status.unavailable")
    active: root.opened
    onPressed: function() { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened && root.available
    contentWidth: panel.fittedContentWidth(Style.space(370))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    Column {
      id: content
      width: parent.width
      spacing: Style.space(14)

      Row {
        width: parent.width
        spacing: Style.space(12)
        Text { textFormat: Text.PlainText; text: root.glyph; color: root.connected ? root.foreground : root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.displayLarge }
        Column {
          width: parent.width - parent.children[0].implicitWidth - parent.spacing
          spacing: Style.space(2)
          Text { width: parent.width; textFormat: Text.PlainText; text: String(root.info.operator || strings.t("label.mobile")); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true; elide: Text.ElideRight }
          Text { width: parent.width; textFormat: Text.PlainText; text: (root.technology || "—") + " · " + root.statusText.toUpperCase(); color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 1 }
        }
      }

      PanelSeparator { foreground: root.foreground }

      Row {
        width: parent.width
        spacing: Style.space(20)
        InfoPair { width: (parent.width - parent.spacing) / 2; label: strings.t("label.signal"); value: root.signal >= 0 ? root.signal + "%" : "—" }
        InfoPair { width: (parent.width - parent.spacing) / 2; label: strings.t("label.profile"); value: root.profile }
      }
      Row {
        visible: root.connected
        width: parent.width
        spacing: Style.space(20)
        InfoPair { width: (parent.width - parent.spacing) / 2; label: strings.t("label.download"); value: "↓ " + root.downRate }
        InfoPair { width: (parent.width - parent.spacing) / 2; label: strings.t("label.upload"); value: "↑ " + root.upRate }
      }
      Row {
        visible: root.connected
        width: parent.width
        spacing: Style.space(20)
        InfoPair { width: (parent.width - parent.spacing) / 2; label: strings.t("label.session"); value: root.sessionTotal }
      }

      Text {
        visible: root.lastError !== ""
        width: parent.width
        textFormat: Text.PlainText
        text: root.lastError
        color: root.urgent
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
      }

      Row {
        width: parent.width
        spacing: Style.space(8)
        Button {
          width: (parent.width - parent.spacing) / 2
          text: root.connected ? strings.t("action.disconnect") : strings.t("action.connect")
          foreground: root.foreground
          fontFamily: root.fontFamily
          bordered: true
          active: root.connected
          enabled: !root.actionPending && !root.locked
          onClicked: root.setConnection(!root.connected)
        }
        Button {
          width: (parent.width - parent.spacing) / 2
          text: strings.t("action.settings")
          foreground: root.foreground
          fontFamily: root.fontFamily
          bordered: true
          onClicked: root.openSettings()
        }
      }
    }
  }

  component InfoPair: Column {
    property string label: ""
    property string value: ""
    spacing: Style.space(2)
    Text { textFormat: Text.PlainText; text: parent.label.toUpperCase(); color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 1 }
    Text { textFormat: Text.PlainText; text: parent.value; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body }
  }
}
