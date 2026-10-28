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
    readonly property real hem: height > 120 ? 8 : 6

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
        return torn(0);
    }

    // The Flame Reaver's cloak: a slab whose bottom edge is torn into small irregular notches,
    // `inset` pixels inside the tab. Widths and depths are fixed so the tear never shimmers as the
    // tab resizes.
    function torn(inset) {
        const w = width, h = height, base = h - hem - inset;
        const steps = [7, 11, 5, 13, 8, 4, 10, 6, 12, 9, 5, 14];
        const depths = [1.0, 0.25, 0.8, 0.1, 0.6, 0.35, 0.95, 0.2, 0.7, 0.05, 0.85, 0.3];
        const pts = [Qt.point(inset, 0), Qt.point(w - inset, 0), Qt.point(w - inset, base)];
        let x = w - inset, i = 0;
        for (x -= steps[0]; x > inset; i++, x -= steps[i % steps.length])
            pts.push(Qt.point(x, base + hem * depths[i % depths.length]));
        pts.push(Qt.point(inset, base), Qt.point(inset, 0));
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

    // ── Flame Reaver: the cloak's ash, its purple lining, and the Black Tide caught in the hem ──
    Item {
        visible: Form.reaver
        anchors.fill: parent

        Image {
            width: parent.width
            height: parent.height - root.hem
            source: Form.reaver ? Qt.resolvedUrl("../assets/coreflame/ash-grain.png") : ""
            fillMode: Image.Tile
            opacity: 0.07
            smooth: false
        }

        // The inside of the cloak shows at its edges: open along the screen edge it hangs from.
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: Theme.withAlpha(Theme.live, 0.75)
                strokeWidth: 1
                joinStyle: ShapePath.MiterJoin

                PathPolyline {
                    path: Form.reaver ? root.torn(2.5).slice(1) : []
                }
            }
        }

        Repeater {
            // [position along the hem, size, violet?]: only panels, not the island at rest
            model: root.height > 60 ? [[0.08, 5, 0], [0.11, 3, 1], [0.34, 6, 0], [0.57, 4, 1], [0.6, 5, 0], [0.83, 4, 0], [0.92, 4, 1]] : []

            Rectangle {
                required property var modelData
                x: Math.round(root.width * modelData[0])
                y: root.height - root.hem - 1
                width: modelData[1]
                height: modelData[1]
                color: modelData[2] ? Theme.live : "#050407"
            }
        }
    }
}
