import QtQuick
import qs.Common

// The Phainon chimera in the corner. Its state lives in the Chimera singleton, shared with the
// chimera plugin: asleep while the machine idles, then walking, running and sprinting.
Item {
    id: root

    property real size: 30

    implicitWidth: size
    implicitHeight: size

    // Counted at most once, so show/hide and teardown can never unbalance the shared count.
    property bool counted: false

    function count(on) {
        if (on === counted)
            return;
        counted = on;
        Chimera.watchers += on ? 1 : -1;
    }

    onVisibleChanged: count(visible)
    Component.onCompleted: count(visible)
    Component.onDestruction: count(false)

    Image {
        anchors.fill: parent
        source: Qt.resolvedUrl("../assets/coreflame/chimera/shime" + Chimera.frame + ".png")
        sourceSize: Qt.size(128, 128)
        fillMode: Image.PreserveAspectFit
        smooth: false
    }
}
