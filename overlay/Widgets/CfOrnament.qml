import QtQuick
import qs.Common

// Form-specific dressing laid over a panel, plus a one-shot entrance when the panel appears.
// Nothing here loops: the entrance plays once and stops.
//   Phainon      a small sun and double rule on the left, one wing of feathers on the right
//                (he has a single wing), and a band of light that sweeps down once.
//   Khaslana     a gold seam with brackets on two corners, clusters of displaced blocks where
//                the simulation failed to render, and a few frames of tearing as it opens.
//   Flame Reaver one violet mark and the slats of his mask. No entrance.
Item {
    id: root

    visible: Form.active
    clip: true

    readonly property color gold: Theme.primary
    readonly property color trim: Theme.withAlpha(Theme.outline, 0.8)
    property int tear: 0
    property int unfurl: 6

    function noise(i) {
        return ((root.tear * 37 + i * 61) % 97) / 97;
    }

    onVisibleChanged: if (visible)
        play()

    // Runs the entrance once. Panels that keep their items alive while hidden call this themselves.
    function play() {
        if (!Form.active || Motion.still || width <= 0)
            return;
        if (Form.khaslana) {
            tear = 1;
            tearTimer.restart();
        } else if (Form.phainon) {
            sweep.restart();
            unfurl = 0;
            unfurlTimer.restart();
        }
    }

    Timer {
        id: tearTimer
        interval: 45
        repeat: true
        onTriggered: {
            root.tear++;
            if (root.tear > 6) {
                root.tear = 0;
                stop();
            }
        }
    }

    Timer {
        id: unfurlTimer
        interval: 45
        repeat: true
        onTriggered: {
            root.unfurl++;
            if (root.unfurl >= 6)
                stop();
        }
    }

    // ── Phainon ──
    Item {
        visible: Form.phainon
        anchors.fill: parent

        Item {
            x: Math.max(Theme.cornerRadius, 10)
            y: 6
            width: parent.width * 0.34
            height: 10

            Item {
                width: 10
                height: 10

                Repeater {
                    model: 4

                    Rectangle {
                        required property int index
                        anchors.centerIn: parent
                        width: 1.5
                        height: index % 2 === 0 ? 10 : 6.5
                        rotation: index * 45
                        radius: 1
                        color: Theme.secondary
                    }
                }
            }

            Rectangle {
                x: 16
                y: 3
                width: parent.width - 16
                height: 1
                color: root.trim
            }

            Rectangle {
                x: 16
                y: 6
                width: (parent.width - 16) * 0.55
                height: 1
                color: Theme.withAlpha(Theme.outline, 0.45)
            }
        }

        // The single wing
        Repeater {
            model: 6

            Rectangle {
                required property int index
                x: root.width - 34
                y: 34 - height
                width: 3
                height: 22 + index * 9
                radius: 2
                transformOrigin: Item.Bottom
                rotation: 22 + index * 12
                visible: index < root.unfurl
                color: Theme.withAlpha(Theme.primary, 0.20 - index * 0.022)
            }
        }

        Rectangle {
            id: light
            visible: sweep.running
            width: parent.width
            height: 90
            y: -90
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "transparent"
                }
                GradientStop {
                    position: 0.5
                    color: Theme.withAlpha(Theme.secondary, 0.22)
                }
                GradientStop {
                    position: 1
                    color: "transparent"
                }
            }

            NumberAnimation {
                id: sweep
                target: light
                property: "y"
                from: -90
                to: root.height
                duration: Math.max(260, Theme.mediumDuration + 160)
                easing.type: Easing.OutCubic
            }
        }
    }

    // ── Khaslana ──
    Item {
        visible: Form.khaslana
        anchors.fill: parent

        Rectangle {
            x: 34
            y: 5
            width: parent.width - 68
            height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: "transparent"
                }
                GradientStop {
                    position: 0.5
                    color: root.gold
                }
                GradientStop {
                    position: 1
                    color: "transparent"
                }
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 2
            width: 7
            height: 7
            rotation: 45
            color: root.gold
        }

        Rectangle {
            x: 5
            y: 5
            width: 20
            height: 2
            color: root.gold
        }
        Rectangle {
            x: 5
            y: 5
            width: 2
            height: 20
            color: root.gold
        }
        Rectangle {
            x: parent.width - 25
            y: parent.height - 7
            width: 20
            height: 2
            color: root.gold
        }
        Rectangle {
            x: parent.width - 7
            y: parent.height - 25
            width: 2
            height: 20
            color: root.gold
        }

        // Blocks that never rendered where they should: the black tide's flickering cubes, held still.
        Repeater {
            model: [[8, -30, 9, 5, 0], [20, -22, 5, 5, 1], [10, -14, 14, 3, 0], [30, -34, 4, 4, 1], [28, -12, 6, 6, 2], [44, -20, 3, 3, 0], [-30, 52, 10, 4, 1], [-16, 60, 5, 5, 0], [-36, 66, 4, 4, 2], [-12, 48, 8, 3, 0]]

            Rectangle {
                required property var modelData
                x: modelData[0] >= 0 ? modelData[0] : root.width + modelData[0]
                y: modelData[1] >= 0 ? modelData[1] : root.height + modelData[1]
                width: modelData[2]
                height: modelData[3]
                color: modelData[4] === 0 ? Theme.withAlpha(root.gold, 0.75) : (modelData[4] === 1 ? Theme.withAlpha(Theme.error, 0.7) : Theme.withAlpha(Theme.surfaceText, 0.35))
            }
        }

        // Tearing as the panel opens
        Repeater {
            model: root.tear > 0 ? 4 : 0

            Rectangle {
                required property int index
                x: Math.round((root.noise(index + 5) - 0.3) * root.width * 0.5)
                y: Math.round(root.noise(index) * root.height)
                width: Math.round(root.width * (0.35 + root.noise(index + 9) * 0.6))
                height: 2 + Math.round(root.noise(index + 3) * 7)
                color: index % 2 === 0 ? Theme.withAlpha(Theme.error, 0.55) : Theme.withAlpha(root.gold, 0.5)
            }
        }
    }

    // ── Flame Reaver ──
    Item {
        visible: Form.reaver
        anchors.fill: parent

        Rectangle {
            y: 14
            width: 2
            height: 30
            color: Theme.live
        }

        // The slats of the mask
        Repeater {
            model: 7

            Rectangle {
                required property int index
                x: root.width - 20 - index * 6
                y: 8
                width: 2
                height: 22 - Math.abs(index - 3) * 4
                color: Theme.withAlpha(Theme.surfaceText, 0.16)
            }
        }
    }
}
