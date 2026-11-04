pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common

FloatingWindow {
    id: root

    readonly property bool isFloatingWindowSurface: true

    default property alias content: contentItem.data

    property color surfaceColor: Theme.floatingWindowSurface
    property bool contentVisible: true

    // A placeholder screen (no outputs left) is 0x0; a size derived from it is a zero geometry and the compositor drops the connection.
    function heightWithin(preferred, inset) {
        const available = (root.screen?.height ?? 0) - inset;
        return available > 0 ? Math.min(preferred, available) : preferred;
    }

    color: "transparent"

    Rectangle {
        anchors.fill: parent
        color: root.surfaceColor
        visible: root.contentVisible && !Form.active
    }

    // Coreflame: the form's frame instead of the plain surface; windows that draw their own
    // frame set surfaceColor transparent.
    CfFrame {
        anchors.fill: parent
        // Khaslana's red offset hangs 6px right and down; keep it inside the window
        anchors.rightMargin: Form.khaslana ? 6 : 0
        anchors.bottomMargin: Form.khaslana ? 6 : 0
        visible: root.contentVisible && Form.active && root.surfaceColor.a > 0
    }

    // No surfaceColor gate: compositor window rules can make this window translucent.
    // Coreflame: no blur under the forms; it is a rectangle and would show past cut or torn edges.
    WindowBlur {
        targetWindow: root
        blurEnabled: root.contentVisible && !Form.active
        blurX: 0
        blurY: 0
        blurWidth: root.visible ? root.width : 0
        blurHeight: root.visible ? root.height : 0
    }

    Item {
        id: contentItem

        readonly property bool isFloatingWindowSurface: true
        property bool disablePopupTransparency: true

        anchors.fill: parent
        visible: root.contentVisible
    }
}
