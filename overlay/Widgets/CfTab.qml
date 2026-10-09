import QtQuick
import QtQuick.Shapes
import qs.Common

// A piece of screen furniture hanging from the top edge: a corner tab or the centre island.
// Phainon: soft rounded lower corners. Khaslana: lower corners cut on the diagonal, gold edge.
// Flame Reaver: a flat slab ending in a torn hem.
Item {
    id: root

    // "left" and "right" sit flush in a screen corner; "center" hangs free.
    property string side: "center"
    property color color: Theme.surface
    property color edge: Theme.outline

    readonly property bool soft: Form.phainon || !Form.active
    readonly property real softRadius: Math.min(height * 0.6, 24)
    readonly property real cut: Math.min(height * 0.45, 16)
    readonly property real hem: 6

    readonly property var outline: {
        const w = width, h = height;
        if (Form.khaslana) {
            const c = cut;
            if (side === "left")
                return [Qt.point(0, 0), Qt.point(w, 0), Qt.point(w, h - c), Qt.point(w - c, h), Qt.point(0, h), Qt.point(0, 0)];
            if (side === "right")
                return [Qt.point(0, 0), Qt.point(w, 0), Qt.point(w, h), Qt.point(c, h), Qt.point(0, h - c), Qt.point(0, 0)];
            return [Qt.point(0, 0), Qt.point(w, 0), Qt.point(w, h - c), Qt.point(w - c, h), Qt.point(c, h), Qt.point(0, h - c), Qt.point(0, 0)];
        }
        // Torn hem: a fixed zig-zag so it never shimmers when the tab resizes.
        const depths = [1.0, 0.25, 0.8, 0.1, 0.6, 0.35, 0.95, 0.2, 0.7, 0.05];
        const pts = [Qt.point(0, 0), Qt.point(w, 0), Qt.point(w, h - hem)];
        const step = 9;
        let i = 0;
        for (let x = w - step; x > 0; x -= step, i++)
            pts.push(Qt.point(x, h - hem + hem * depths[i % depths.length]));
        pts.push(Qt.point(0, h - hem), Qt.point(0, 0));
        return pts;
    }

    // Khaslana commands the simulation's errors: his edges carry a displaced red echo.
    Shape {
        visible: Form.khaslana
        x: 3
        y: 2
        width: parent.width
        height: parent.height
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.withAlpha(Theme.error, 0.55)
            strokeWidth: 1.5

            PathPolyline {
                path: Form.khaslana ? root.outline : []
            }
        }
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.soft ? softShape : polyShape
    }

    Component {
        id: softShape

        Rectangle {
            color: root.color
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: root.side === "left" ? 0 : root.softRadius
            bottomRightRadius: root.side === "right" ? 0 : root.softRadius
            border.width: Form.active ? 1 : 0
            border.color: Theme.withAlpha(root.edge, 0.6)
        }
    }

    Component {
        id: polyShape

        Shape {
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: root.color
                strokeColor: Form.khaslana ? root.edge : "transparent"
                strokeWidth: 1.5
                joinStyle: ShapePath.MiterJoin

                PathPolyline {
                    path: root.outline
                }
            }
        }
    }
}
