import QtQuick
import qs.Common

// Coreflame: a share (0..1) drawn one way per form (the v3 mockup): Phainon a navy line on cream,
// Khaslana ten red blocks capped in gold, the Flame Reaver ten skewed violet blocks. Nothing outside
// a Coreflame form.
Item {
    id: bar

    property real share: 0
    readonly property real clamped: Math.max(0, Math.min(1, share))
    readonly property int lit: Math.round(clamped * 10)

    visible: Form.active
    implicitHeight: Form.phainon ? 6 : (Form.khaslana ? 10 : 9)

    Rectangle {
        visible: Form.phainon
        anchors.fill: parent
        radius: 3
        color: "#E4DAC0"

        Rectangle {
            width: parent.width * bar.clamped
            height: parent.height
            radius: 3
            color: "#334786"
        }
    }

    Row {
        id: blocks
        visible: !Form.phainon
        anchors.fill: parent
        spacing: Form.khaslana ? 2 : 3

        Repeater {
            model: bar.visible && !Form.phainon ? 10 : 0

            Rectangle {
                required property int index
                width: (bar.width - 9 * blocks.spacing) / 10
                height: bar.height
                color: Form.khaslana ? (index < bar.lit - 1 ? "#C2252F" : (index === bar.lit - 1 ? "#F2C75C" : "#2A1015")) : (index < bar.lit ? "#8F7BE0" : "#2C2840")
                // skewX(-20deg) about the middle
                transform: Matrix4x4 {
                    matrix: Form.reaver ? Qt.matrix4x4(1, -0.364, 0, 0.182 * bar.height, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) : Qt.matrix4x4()
                }
            }
        }
    }
}
