import QtQuick
import qs.Common
import qs.DCommon.Widgets as DW

// A control-centre level (volume, brightness, microphone) in the form's shape, dragged to set.
//   Khaslana: a tall meter of red blocks with a gold top, icon and number below.
//   Flame Reaver: a row of ten skewed violet blocks.
//   Phainon: a thin lapis line with a gold knob.
Item {
    id: lvl

    required property var cc
    property string icon: ""
    property real value: 0
    property string valueText: ""
    signal moved(real to)
    signal iconClicked

    readonly property string look: cc.lay === "khaslana" ? "meter" : (cc.lay === "reaver" ? "bars" : "line")
    readonly property real level: Math.max(0, Math.min(1, value))
    // Khaslana's meter: 12 blocks; the Reaver's bars: 10
    readonly property int blocks: look === "meter" ? 12 : 10
    readonly property int lit: Math.round(level * blocks)

    implicitHeight: look === "meter" ? 300 : 24

    // The draggable track for each look
    readonly property Item track: look === "meter" ? meter : (look === "bars" ? bars : line)

    function setFrom(x, y) {
        const t = track;
        const p = lvl.mapToItem(t, x, y);
        const v = look === "meter" ? 1 - p.y / t.height : p.x / t.width;
        lvl.moved(Math.max(0, Math.min(1, v)));
    }

    // Khaslana: vertical meter
    Rectangle {
        id: meter
        visible: lvl.look === "meter"
        width: parent.width
        height: 250
        color: "#0B080B"
        border.width: 1
        border.color: "#8A5A2B"

        Column {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 3

            Repeater {
                model: lvl.blocks

                Rectangle {
                    required property int index
                    // The top block is drawn first
                    readonly property int n: lvl.blocks - index
                    width: parent.width
                    height: (meter.height - 8 - 3 * (lvl.blocks - 1)) / lvl.blocks
                    color: n > lvl.lit ? "#22100F" : (n === lvl.lit ? "#F2C75C" : "#C2252F")
                }
            }
        }
    }

    Column {
        visible: lvl.look === "meter"
        y: meter.height + 8
        width: parent.width
        spacing: 2

        DW.DIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: lvl.icon
            size: 20
            color: "#E0B04A"

            MouseArea {
                anchors.fill: parent
                anchors.margins: -5
                cursorShape: Qt.PointingHandCursor
                onClicked: lvl.iconClicked()
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: lvl.valueText.replace("%", "")
            font.family: "Chakra Petch"
            font.pixelSize: 14
            color: "#F3E6CC"
        }
    }

    // Reaver and Phainon: icon, track, number on one line
    DW.DIcon {
        visible: lvl.look !== "meter"
        anchors.verticalCenter: parent.verticalCenter
        name: lvl.icon
        size: 18
        color: lvl.cc.pal.accent

        MouseArea {
            anchors.fill: parent
            anchors.margins: -5
            cursorShape: Qt.PointingHandCursor
            onClicked: lvl.iconClicked()
        }
    }

    Row {
        id: bars
        visible: lvl.look === "bars"
        x: 30
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 30 - 46
        height: 9
        spacing: 3

        Repeater {
            model: lvl.blocks

            Rectangle {
                required property int index
                width: (bars.width - 3 * (lvl.blocks - 1)) / lvl.blocks
                height: 9
                antialiasing: true
                color: index < lvl.lit ? "#8F7BE0" : "#2C2840"
                transform: Matrix4x4 {
                    // CSS skewX(-20deg) about the centre: the top leans right
                    matrix: Qt.matrix4x4(1, -0.364, 0, 0.364 * 4.5, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                }
            }
        }
    }

    Item {
        id: line
        visible: lvl.look === "line"
        x: 32
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 32 - 56
        height: 18

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 2
            color: lvl.cc.pal.rim
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * lvl.level
            height: 4
            color: lvl.cc.pal.lapis
        }

        Rectangle {
            x: parent.width * lvl.level - 9
            width: 18
            height: 18
            radius: 9
            color: lvl.cc.parch ? "#F1DA4F" : Theme.primary
            border.width: 1
            border.color: lvl.cc.pal.edge
        }
    }

    Text {
        visible: lvl.look !== "meter"
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 44
        horizontalAlignment: Text.AlignRight
        text: lvl.look === "bars" ? lvl.valueText.replace("%", "") : lvl.valueText
        font.family: lvl.cc.body
        font.pixelSize: 14
        color: lvl.cc.pal.ink
    }

    MouseArea {
        x: lvl.track.x - 6
        y: lvl.track.y - 6
        width: lvl.track.width + 12
        height: lvl.track.height + 12
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => lvl.setFrom(mouse.x + x, mouse.y + y)
        onPositionChanged: mouse => {
            if (pressed)
                lvl.setFrom(mouse.x + x, mouse.y + y);
        }
    }
}
