import QtQuick
import QtQuick.Shapes
import qs.DCommon.Common
import qs.DCommon.Widgets
import qs.Common as Shell

Rectangle {
    id: root

    property alias text: label.text
    property alias reserveText: label.reserveText
    property color textColor: Style.secondary

    readonly property real bevelDepth: Style.outlineWidthFocused
    // Coreflame: Phainon paper key with a ledge, Khaslana plate with a red offset, Reaver a skewed slab.
    readonly property bool cf: Shell.Form.active
    readonly property bool kh: Shell.Form.khaslana
    readonly property real offset: kh ? 2 : 0

    implicitWidth: Math.max(Math.ceil(label.reservedWidth) + Style.spacingS * 2, implicitHeight) + offset
    implicitHeight: Math.round(label.font.pixelSize * 2) + offset
    radius: !cf ? Style.cornerRadiusXS : (Shell.Form.phainon ? 8 : 0)
    color: !cf ? Style.outlineVariant : (Shell.Form.phainon ? "#DCCDA6" : "transparent")

    Rectangle {
        visible: root.kh
        anchors.fill: parent
        anchors.leftMargin: root.offset
        anchors.topMargin: root.offset
        color: "#8E1424"
    }

    Loader {
        anchors.fill: parent
        active: Shell.Form.reaver
        sourceComponent: Shape {
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "#1C1828"
                strokeColor: "transparent"
                startX: 0
                startY: 0

                PathLine {
                    x: root.width
                    y: root.height * 0.1
                }
                PathLine {
                    x: root.width * 0.96
                    y: root.height
                }
                PathLine {
                    x: root.width * 0.03
                    y: root.height * 0.9
                }
                PathLine {
                    x: 0
                    y: 0
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.bottomMargin: root.kh ? root.offset : (root.cf && Shell.Form.reaver ? 0 : root.bevelDepth)
        anchors.rightMargin: root.offset
        radius: root.radius
        color: !root.cf ? Style.chipSurface : (Shell.Form.reaver ? "transparent" : (root.kh ? "#160D10" : "#FBF9F3"))
        border.width: root.cf && Shell.Form.reaver ? 0 : Style.outlineWidth
        border.color: !root.cf ? Style.outlineVariant : (root.kh ? "#E0B04A" : "#C8B27E")

        NumericText {
            id: label
            anchors.fill: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.pixelSize: root.cf ? 12 : Style.fontSizeSmall
            font.weight: Style.fontWeightMedium
            font.family: root.cf ? "Chakra Petch" : label.resolvedFontFamily
            color: !root.cf ? root.textColor : (root.kh ? "#F5D27A" : (Shell.Form.reaver ? "#B9A8FF" : "#334786"))
        }
    }
}
