import QtQuick
import qs.Common

// The Flame Reaver's slider: a line scorched up to the value, with an ember for a handle. Static;
// the ember flares once (CfEmber) when it is grabbed. Same slider API as CfBlade: value, moved(to).
Item {
    id: root

    property real value: 0
    property bool interactive: true
    readonly property real level: Math.max(0, Math.min(1, value))
    readonly property real span: width - 12
    signal moved(real to)

    implicitHeight: 16

    // Not yet burnt: a faint ash thread
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: 6
        width: root.span
        height: 1
        color: Theme.withAlpha(Theme.surfaceVariantText, 0.35)
    }

    // Burnt: charred ash darkening into violet towards the ember
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: 6
        width: Math.round(root.span * root.level)
        height: 2
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: Theme.withAlpha(Theme.surfaceVariantText, 0.3)
            }
            GradientStop {
                position: 1
                color: Theme.live
            }
        }
    }

    // Scorch marks where the line has burnt through, fixed so nothing moves at rest
    Repeater {
        model: [0.12, 0.27, 0.4, 0.56, 0.7, 0.86]

        Rectangle {
            required property real modelData
            required property int index
            visible: modelData < root.level - 0.04
            x: 6 + Math.round(root.span * modelData)
            y: Math.round(root.height / 2) - (index % 2 ? 2 : 4)
            width: 1
            height: index % 2 ? 5 : 8
            color: Theme.withAlpha(Theme.surfaceVariantText, 0.5)
        }
    }

    // The ember head, shown even when the line can't be dragged
    Item {
        x: 6 + Math.round(root.span * root.level) - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 14
        height: 14

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Theme.withAlpha(Theme.live, 0.25)
        }

        Rectangle {
            anchors.centerIn: parent
            width: 7
            height: 7
            radius: 3.5
            color: Theme.live

            Rectangle {
                anchors.centerIn: parent
                width: 3
                height: 3
                radius: 1.5
                color: "#F4E9D6"
            }
        }

        CfEmber {
            id: ember
            anchors.centerIn: parent
            size: 14
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -5
        enabled: root.interactive
        cursorShape: Qt.PointingHandCursor

        function report(mouse) {
            root.moved(Math.max(0, Math.min(1, (mouse.x - 5 - 6) / root.span)));
        }

        onPressed: mouse => {
            ember.flare();
            report(mouse);
        }
        onPositionChanged: mouse => {
            if (pressed)
                report(mouse);
        }
    }
}
