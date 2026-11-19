import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Bar button that draws one icon glyph and a separate text label, where the
// label can use a narrower (condensed) font than the icon's Nerd Font so short
// tags like "LTE" take less horizontal space. Mirrors BarIconButton's optical
// glyph fitting so the icon still lines up with neighbouring bar widgets.
WidgetButton {
  id: root

  property string labelText: ""
  // Condensed label font, with the bar font as a fallback when unavailable.
  property string labelFontFamily: fontFamily
  property real labelFontSize: fontSize
  property real slotSize: Style.bar.iconSlot
  property real opticalSize: Style.bar.iconCanvas
  property real iconSize: Math.min(Style.bar.iconSize, opticalSize)
  readonly property real visualIconSize: Style.bar.iconSize
  readonly property real canvasSize: Math.max(visualIconSize, opticalSize)

  labelVisible: false
  hasVisualContent: text !== "" || labelText !== ""
  fixedWidth: vertical ? -1 : slotSize
  fixedHeight: vertical ? slotSize : -1

  Item {
    id: content
    x: (root.width - width) / 2
    y: (root.height - height) / 2
    scale: root.pressScale
    width: root.canvasSize + (label.visible ? label.implicitWidth + Style.space(3) : 0)
    height: root.canvasSize

    Text {
      id: label
      visible: root.labelText !== ""
      textFormat: Text.PlainText
      text: root.labelText
      font.family: root.labelFontFamily
      font.pixelSize: root.labelFontSize
      color: root.active && root.useActiveColor ? root.activeColor : root.foreground
      y: (parent.height - height) / 2
        + (labelMetrics.descent - labelMetrics.ascent + labelMetrics.tightBoundingRect("0").height) / 2
      renderType: Text.NativeRendering
    }

    FontMetrics {
      id: labelMetrics
      font: label.font
    }

    Item {
      id: opticalCanvas
      x: label.visible ? label.implicitWidth + Style.space(3) : 0
      width: root.canvasSize
      height: root.canvasSize

      OpticalGlyph {
        anchors.fill: parent
        text: root.text
        fontFamily: root.fontFamily
        fontSize: root.fontSize
        paintedSize: root.visualIconSize
        color: root.active && root.useActiveColor ? root.activeColor : root.foreground
      }
    }
  }
}
