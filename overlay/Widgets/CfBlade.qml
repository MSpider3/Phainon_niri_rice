import QtQuick
import qs.Common

// The Dawnmaker blade as a meter or slider: a guard at the hilt, a steel track, and the core
// stripe as the level. Set `interactive` to let it be dragged.
Item {
    id: blade

    property real value: 0
    property bool interactive: false
    // A read-only meter: no guard, no crossguard, nothing that looks draggable.
    property bool meter: false
    property color tone: Theme.primary
    signal moved(real to)

    implicitHeight: 14

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        x: 5
        width: parent.width - 12
        height: 6
        radius: Form.phainon || !Form.active ? 3 : 0
        color: Theme.withAlpha(Theme.surfaceText, 0.16)

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(parent.width * Math.max(0, Math.min(1, blade.value)))
            height: Form.active ? 2 : parent.height
            color: blade.tone
        }

        // The point of the blade
        Rectangle {
            visible: !blade.meter && Form.active
            x: parent.width - 3
            anchors.verticalCenter: parent.verticalCenter
            width: 6
            height: 6
            rotation: 45
            color: parent.color
        }

        // Crossguard marking the level, only where it can be grabbed
        Rectangle {
            visible: blade.interactive
            anchors.verticalCenter: parent.verticalCenter
            x: Math.round(parent.width * Math.max(0, Math.min(1, blade.value))) - 2
            width: 4
            height: 14
            color: blade.tone
        }
    }

    Rectangle {
        visible: !blade.meter
        anchors.verticalCenter: parent.verticalCenter
        width: 8
        height: 8
        rotation: 45
        color: Theme.secondary
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -5
        enabled: blade.interactive
        cursorShape: blade.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor

        function report(mouse) {
            blade.moved(Math.max(0, Math.min(1, (mouse.x - 5 - track.x) / track.width)));
        }

        onPressed: mouse => report(mouse)
        onPositionChanged: mouse => {
            if (pressed)
                report(mouse);
        }
    }
}
