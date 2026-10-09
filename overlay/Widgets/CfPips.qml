import QtQuick
import qs.Common

// Battery as Coreflame: twelve pips, plus three short overflow pips that light when full on mains.
Row {
    id: root

    property real level: 0
    property bool charging: false
    property bool low: false
    property real pipHeight: 10
    property color litColor: low ? Theme.error : (charging ? Theme.primary : Theme.widgetTextColor)
    property color dimColor: Theme.withAlpha(Theme.widgetTextColor, 0.25)
    // The Flame Reaver: every lit pip is tarnished, and only the last one still burns.
    property color lastColor: Form.reaver && !low ? Theme.live : litColor

    readonly property int litCount: level <= 0 ? 0 : Math.max(1, Math.round(level * 12 / 100))
    readonly property bool overflow: charging && level >= 99

    spacing: 2

    Repeater {
        model: 15

        Rectangle {
            required property int index
            readonly property bool extra: index >= 12
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(2, Math.round(root.pipHeight * 0.3))
            height: extra ? Math.round(root.pipHeight * 0.5) : root.pipHeight
            color: (extra ? root.overflow : index < root.litCount) ? ((!extra && index === root.litCount - 1) ? root.lastColor : root.litColor) : root.dimColor
        }
    }
}
