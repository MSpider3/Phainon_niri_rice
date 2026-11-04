import QtQuick
import QtQuick.Shapes
import qs.Common

// Holds a control-centre menu that comes out from under its switch and pushes the rows below
// down as it grows; closing runs it back in. The menu is built only while open or closing.
// Phainon unrolls with a slight overshoot, Khaslana drops slow then fast trailed by a red line,
// the Flame Reaver cracks open in four hard steps along a torn violet edge (the v3 mockup).
Item {
    id: slide

    property bool open: false
    property alias sourceComponent: loader.sourceComponent
    readonly property alias item: loader.item
    property string lay: "phainon"

    property real out: open ? 1 : 0
    readonly property real shown: lay === "reaver" ? Math.ceil(out * 4) / 4 : Math.max(0, out)
    readonly property bool moving: out > 0 && out !== 1
    readonly property int duration: Motion.openMs === 0 ? 0 : (lay === "khaslana" ? 300 : (lay === "reaver" ? 200 : 260))

    height: Math.round((loader.item ? loader.item.implicitHeight : 0) * shown)
    visible: height > 0
    // Only while moving: at rest Khaslana's red offset hangs outside the menu
    clip: moving

    Behavior on out {
        NumberAnimation {
            duration: slide.duration
            easing.type: slide.lay === "reaver" ? Easing.Linear : Easing.BezierSpline
            // Phainon overshoots only on the way out; closing settles without dipping below zero
            easing.bezierCurve: slide.lay === "khaslana" ? [0.6, 0, 0.2, 1, 1, 1] : (slide.open ? [0.3, 1.2, 0.5, 1, 1, 1] : [0.4, 0, 0.2, 1, 1, 1])
        }
    }

    Loader {
        id: loader
        width: parent.width
        // Bottom first, as if pulled out from under the switch; an overshoot only pushes further down
        y: Math.min(0, slide.height - (item ? item.implicitHeight : 0))
        active: slide.open || slide.out > 0
    }

    // The leading edge while it moves
    Rectangle {
        visible: slide.moving && slide.lay === "khaslana"
        anchors.bottom: parent.bottom
        width: parent.width
        height: 3
        color: "#8E1424"
    }

    Loader {
        active: slide.moving && slide.lay === "reaver"
        anchors.bottom: parent.bottom
        width: parent.width
        height: 3

        sourceComponent: Shape {
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "#B9A8FF"
                strokeColor: "transparent"
                // The mockup's torn edge, as fractions of the width
                PathPolyline {
                    path: [[0, 0], [0.12, 1], [0.25, 0.2], [0.41, 1], [0.58, 0], [0.72, 0.9], [0.86, 0.1], [1, 1], [1, 0], [0, 0]].map(p => Qt.point(p[0] * slide.width, p[1] * 3))
                }
            }
        }
    }
}
