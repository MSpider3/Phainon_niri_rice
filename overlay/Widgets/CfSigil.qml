import QtQuick
import qs.Common

// Kephale's thorned ring used as a clock face: twelve spikes, one per hour, lit as the hours pass.
Item {
    id: root

    property real size: 18
    property int lit: 12
    property color litColor: Theme.primary
    property color dimColor: Theme.withAlpha(Theme.widgetTextColor, 0.28)

    implicitWidth: size
    implicitHeight: size

    Rectangle {
        anchors.centerIn: parent
        width: root.size * 0.5
        height: width
        radius: width / 2
        color: "transparent"
        border.width: Math.max(1, root.size * 0.06)
        border.color: root.dimColor
    }

    Repeater {
        model: 12

        Item {
            required property int index
            anchors.centerIn: parent
            width: Math.max(1.5, root.size * 0.09)
            height: root.size
            rotation: index * 30 + 15

            Rectangle {
                width: parent.width
                height: root.size * (index % 3 === 0 ? 0.24 : 0.17)
                y: root.size * 0.24 - height
                radius: width / 2
                color: index < root.lit ? root.litColor : root.dimColor
            }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: root.size * 0.2
        height: width
        rotation: 45
        color: root.litColor
    }
}
