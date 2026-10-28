import QtQuick
import qs.Common

// The Flame Reaver's toggle: his two swords. Crossed means on, parted means off. The blades move
// once (Motion.base(200)) when `checked` changes and an ember flares where they meet; nothing
// moves otherwise. Like DToggle, a click emits clicked() and toggled(!checked); the owner sets
// `checked`.
Item {
    id: root

    property bool checked: false
    property color color: Theme.surfaceText
    property color offColor: Theme.withAlpha(Theme.surfaceText, 0.4)

    signal clicked
    signal toggled(bool checked)

    implicitWidth: 34
    implicitHeight: 24
    opacity: enabled ? 1 : 0.4

    onCheckedChanged: ember.flare()

    Repeater {
        model: [-1, 1]

        // A blade: a thin steel line with a short guard near the hilt, hilt at the bottom.
        Item {
            id: blade
            required property int modelData
            readonly property real len: root.height * 1.15
            x: (root.width - width) / 2 + (root.checked ? 0 : blade.modelData * root.width * 0.24)
            y: (root.height - height) / 2
            width: 2
            height: len
            rotation: blade.modelData * (root.checked ? 42 : 10)

            Behavior on x {
                NumberAnimation {
                    duration: Motion.base(200)
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on rotation {
                NumberAnimation {
                    duration: Motion.base(200)
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                anchors.fill: parent
                color: root.checked ? root.color : root.offColor
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.78
                width: 7
                height: 2
                color: root.checked ? root.color : root.offColor
            }
        }
    }

    CfEmber {
        id: ember
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -root.height * 0.08
        size: 9
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.clicked();
            root.toggled(!root.checked);
        }
    }
}
