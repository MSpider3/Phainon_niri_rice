import QtQuick
import QtQuick.Shapes
import qs.Common
import qs.Widgets
import "Numerals.js" as Numerals

// The system monitor's four tabs, one look per form (the v3 mockup): Phainon cream capsules with
// the picked one in navy; Khaslana square plates numbered I-IV like their keys, the picked one red
// with a gold edge and a hard offset; the Flame Reaver torn slips numbered as their keys, lower case,
// the picked one violet with an ember on change.
Row {
    id: root

    property var tabs: []
    property int current: 0

    signal picked(int index)

    height: 30
    spacing: 6

    Repeater {
        model: root.tabs

        Item {
            id: tab
            required property string modelData
            required property int index
            readonly property bool selected: root.current === index

            width: label.implicitWidth + 28
            height: root.height

            onSelectedChanged: {
                if (selected && Form.reaver)
                    ember.flare();
            }

            // Khaslana: the hard red offset under the picked plate
            Rectangle {
                visible: Form.khaslana && tab.selected
                x: 3
                y: 3
                width: parent.width
                height: parent.height
                color: "#3A0A12"
            }

            Rectangle {
                visible: !Form.reaver
                anchors.fill: parent
                radius: Form.phainon ? height / 2 : 0
                color: Form.phainon ? (tab.selected ? "#334786" : (hover.hovered ? "#F3ECDB" : "#FBF9F3")) : (tab.selected ? "#8E1424" : (hover.hovered ? "#1A0D10" : "transparent"))
                border.width: 1
                border.color: Form.phainon ? (tab.selected ? "#334786" : "#DCCDA6") : (tab.selected ? "#F2C75C" : "#8A5A2B")
            }

            // Flame Reaver: a torn slip
            Shape {
                visible: Form.reaver
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: tab.selected ? "#8F7BE0" : (hover.hovered ? "#262038" : "#1C1828")
                    strokeColor: "transparent"
                    PathPolyline {
                        path: Form.reaver ? [Qt.point(0, 0), Qt.point(tab.width, tab.height * 0.1), Qt.point(tab.width * 0.96, tab.height), Qt.point(tab.width * 0.03, tab.height * 0.9), Qt.point(0, 0)] : []
                    }
                }
            }

            Text {
                id: label
                anchors.centerIn: parent
                textFormat: Text.StyledText
                text: Form.khaslana ? `<font color="${tab.selected ? "#F5D27A" : "#B0824A"}" size="1">${Numerals.roman(tab.index + 1)}</font>&nbsp;&nbsp;${tab.modelData.toUpperCase()}` : (Form.reaver ? (tab.index + 1) + " " + tab.modelData.toLowerCase() : tab.modelData)
                font.family: Form.khaslana ? "Cinzel" : (Form.reaver ? "Chakra Petch" : "Marcellus")
                font.pixelSize: Form.khaslana ? 11 : 13
                font.weight: Form.khaslana || (Form.reaver && tab.selected) ? Font.DemiBold : Font.Normal
                font.letterSpacing: Form.khaslana ? 1.3 : 0
                color: Form.phainon ? (tab.selected ? "#F7F3E8" : "#334786") : (Form.khaslana ? (tab.selected ? "#F5D27A" : "#C9B89E") : (tab.selected ? "#0D0B14" : "#A8A4BC"))
            }

            CfEmber {
                id: ember
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.bottom
                anchors.verticalCenterOffset: -3
                size: 10
            }

            HoverHandler {
                id: hover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: root.picked(tab.index)
            }
        }
    }
}
