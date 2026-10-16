import QtQuick
import QtQuick.Shapes
import qs.Common

// Battery as the Coreflame on its altar. The flame's height follows the charge; on mains two
// embers rise from it; below 20 % it shrinks to a red ember. Plugging in flashes it once.
// Nothing here repeats: it only redraws when the battery state changes.
Item {
    id: root

    property real level: 0
    property bool charging: false
    property bool low: false
    property color stone: Theme.withAlpha(Theme.surfaceText, 0.55)

    readonly property real flame: low ? 0.35 : 0.55 + Math.min(1, level / 100) * 0.45
    readonly property color fire: low ? Theme.error : (charging ? Theme.secondary : Theme.primary)

    implicitWidth: 26
    implicitHeight: 30

    onChargingChanged: {
        if (charging)
            ignite.restart();
    }

    // Altar: base, column, bowl
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.stone
            strokeColor: "transparent"
            PathSvg {
                path: "M 5 29 L 21 29 L 21 27 L 5 27 Z M 10 27 L 16 27 L 16 21 L 10 21 Z M 4 18 L 22 18 L 19 21 L 7 21 Z"
            }
        }
    }

    // Flame, standing in the bowl and scaled from its foot
    Shape {
        id: flameShape
        x: 3
        y: 0
        width: 20
        height: 18
        preferredRendererType: Shape.CurveRenderer
        transform: Scale {
            origin.x: 10
            origin.y: 18
            xScale: 0.6 + root.flame * 0.4
            yScale: root.flame
        }

        ShapePath {
            fillColor: root.fire
            strokeColor: "transparent"
            PathSvg {
                path: "M 10 0 C 12 5 16 8 16 12 C 16 15.5 13.5 18 10 18 C 6.5 18 4 15.5 4 12 C 4 9 6 7.5 7 5 C 8 7.5 9 8 10 0 Z"
            }
        }

        ShapePath {
            fillColor: Theme.withAlpha("#FFFFFF", 0.55)
            strokeColor: "transparent"
            PathSvg {
                path: "M 10 8 C 11 10.5 13 12 13 14 C 13 16 11.5 17 10 17 C 8.5 17 7 16 7 14 C 7 12.5 9 11 10 8 Z"
            }
        }
    }

    // Two embers above the flame while on mains
    Repeater {
        model: root.charging && !root.low ? [[6, 3], [18, 6]] : []

        Rectangle {
            required property var modelData
            x: modelData[0]
            y: modelData[1]
            width: 2
            height: 2
            color: Theme.secondary
        }
    }

    // One flash of gold when the charger goes in
    Rectangle {
        id: flash
        anchors.centerIn: flameShape
        width: 26
        height: 26
        radius: 13
        color: Theme.secondary
        opacity: 0

        SequentialAnimation {
            id: ignite
            NumberAnimation {
                target: flash
                property: "opacity"
                to: 0.7
                duration: 90
            }
            NumberAnimation {
                target: flash
                property: "opacity"
                to: 0
                duration: 420
                easing.type: Easing.OutCubic
            }
        }
    }
}
