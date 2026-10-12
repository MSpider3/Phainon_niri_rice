import QtQuick
import qs.Common

// The Phainon chimera in the corner. Its state lives in the Chimera singleton, shared with the
// chimera plugin: asleep while the machine idles, then walking, running and sprinting.
Item {
    id: root

    property real size: 30

    implicitWidth: size
    implicitHeight: size

    onVisibleChanged: Chimera.watchers += visible ? 1 : -1
    Component.onCompleted: {
        if (visible)
            Chimera.watchers++;
    }
    Component.onDestruction: {
        if (visible)
            Chimera.watchers--;
    }

    Image {
        anchors.fill: parent
        source: Qt.resolvedUrl("../assets/coreflame/chimera/shime" + Chimera.frame + ".png")
        sourceSize: Qt.size(128, 128)
        fillMode: Image.PreserveAspectFit
        smooth: false
    }
}
