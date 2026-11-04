import QtQuick
import qs.Common
import qs.DCommon.Widgets as DW

// Phainon a soft lapis tile in a tan rim, Khaslana a gold-edged plate with the red offset, the
// Flame Reaver a violet shard; the picked app on the form's picked tile.
Item {
    id: cfTile

    required property var model
    required property int index
    property bool isSelected: false

    signal clicked
    signal pointerMoved

    CfInk {
        id: tileInk
    }

    CfPick {
        anchors.fill: parent
        kind: "tile"
        visible: cfTile.isSelected || tileArea.containsMouse
        opacity: cfTile.isSelected ? 1 : 0.5
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - 8
        spacing: 6

        Item {
            width: 46
            height: 46
            anchors.horizontalCenter: parent.horizontalCenter

            Rectangle {
                visible: Form.khaslana
                x: 2
                y: 2
                width: 46
                height: 46
                color: "#8E1424"
            }

            Rectangle {
                visible: !Form.reaver
                anchors.fill: parent
                radius: Form.phainon ? 14 : 0
                color: Form.phainon ? "#E9EEF8" : "#1A0F12"
                border.width: 1
                border.color: Form.phainon ? "#C8B27E" : "#E0B04A"
            }

            CfQuad {
                visible: Form.reaver
                anchors.fill: parent
                points: [[0, 0.08], [1, 0], [0.92, 1], [0.06, 0.94]]
                fill: "#1C1828"
            }

            DW.AppIconRenderer {
                anchors.centerIn: parent
                width: 30
                height: 30
                iconSize: 30
                iconValue: cfTile.model.icon || ""
                fallbackText: tileInk.tx((cfTile.model.name || "?").charAt(0).toUpperCase())
                fallbackBackgroundColor: "transparent"
                fallbackTextColor: tileInk.accent
                iconColor: tileInk.accent
            }
        }

        DW.StyledText {
            width: parent.width
            text: tileInk.tx(cfTile.model.name || "")
            color: cfTile.isSelected ? tileInk.selText : tileInk.text
            font.family: tileInk.font
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.Wrap
        }
    }

    MouseArea {
        id: tileArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: cfTile.clicked()
        onPositionChanged: cfTile.pointerMoved()
    }
}
