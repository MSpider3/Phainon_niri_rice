import QtQuick
import qs.Common

// One ember flicker on demand: call flare() and a small spark flares, gutters once and dies, in
// about 200 ms (Motion.base). Nothing moves until it is asked. Used when a Flame Reaver toggle
// changes or a flame is taken.
Item {
    id: root

    property color color: Theme.live
    property real size: 10

    implicitWidth: size
    implicitHeight: size

    function flare() {
        flick.restart();
    }

    Rectangle {
        id: spark
        anchors.centerIn: parent
        width: root.size
        height: width
        radius: width / 2
        color: root.color
        opacity: 0
        scale: 0.4

        // The white-hot core
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.4
            height: width
            radius: width / 2
            color: "#F4E9D6"
        }
    }

    SequentialAnimation {
        id: flick
        readonly property int d: Motion.base(200)

        ParallelAnimation {
            NumberAnimation {
                target: spark
                property: "opacity"
                from: 0
                to: 1
                duration: flick.d * 0.3
            }
            NumberAnimation {
                target: spark
                property: "scale"
                from: 0.4
                to: 1.25
                duration: flick.d * 0.3
                easing.type: Easing.OutQuad
            }
        }
        NumberAnimation {
            target: spark
            property: "opacity"
            to: 0.4
            duration: flick.d * 0.15
        }
        NumberAnimation {
            target: spark
            property: "opacity"
            to: 0.9
            duration: flick.d * 0.15
        }
        ParallelAnimation {
            NumberAnimation {
                target: spark
                property: "opacity"
                to: 0
                duration: flick.d * 0.4
            }
            NumberAnimation {
                target: spark
                property: "scale"
                to: 0.6
                duration: flick.d * 0.4
            }
        }
    }
}
