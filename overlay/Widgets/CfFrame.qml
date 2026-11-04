import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Common

// The form's window background, as the v3 mockup draws it: Phainon a parchment sheet with a
// soft shadow; Khaslana an obsidian plate, lower corners cut, a gold edge open at the top and a
// hard red offset; the Flame Reaver a torn shard of ash. Used by CfSheet (the island's windows)
// and DModalHost (every DMS pop-up). Static shapes only.
Item {
    id: frame

    readonly property bool kh: Form.khaslana
    readonly property bool rv: Form.reaver
    readonly property bool ph: !kh && !rv

    // ── Phainon: a floating sheet ──
    RectangularShadow {
        visible: frame.ph
        anchors.fill: parent
        offset.y: 14
        blur: 40
        radius: 26
        color: Qt.rgba(15 / 255, 22 / 255, 51 / 255, 0.3)
    }

    Rectangle {
        visible: frame.ph
        anchors.fill: parent
        radius: 26
        color: Theme.surface
        border.width: 1
        border.color: Theme.withAlpha(Theme.outline, 0.8)
    }

    // ── Khaslana: the red offset, the plate, its gold edge (open at the top) ──
    Shape {
        id: plate
        visible: frame.kh
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        readonly property real w: width
        readonly property real h: height
        readonly property real c: 22

        ShapePath {
            fillColor: "#8E1424"
            strokeColor: "transparent"
            PathPolyline {
                path: frame.kh ? [Qt.point(6, 6), Qt.point(plate.w + 6, 6), Qt.point(plate.w + 6, plate.h + 6 - plate.c), Qt.point(plate.w + 6 - plate.c, plate.h + 6), Qt.point(plate.c + 6, plate.h + 6), Qt.point(6, plate.h + 6 - plate.c)] : []
            }
        }
        ShapePath {
            fillColor: "#0B080B"
            strokeColor: "transparent"
            PathPolyline {
                path: frame.kh ? [Qt.point(0, 0), Qt.point(plate.w, 0), Qt.point(plate.w, plate.h - plate.c), Qt.point(plate.w - plate.c, plate.h), Qt.point(plate.c, plate.h), Qt.point(0, plate.h - plate.c)] : []
            }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: "#E0B04A"
            strokeWidth: 1
            joinStyle: ShapePath.MiterJoin
            PathPolyline {
                path: frame.kh ? [Qt.point(0.5, 0), Qt.point(0.5, plate.h - plate.c), Qt.point(plate.c, plate.h - 0.5), Qt.point(plate.w - plate.c, plate.h - 0.5), Qt.point(plate.w - 0.5, plate.h - plate.c), Qt.point(plate.w - 0.5, 0)] : []
            }
        }
    }

    // ── Flame Reaver: a torn shard of ash ──
    Shape {
        visible: frame.rv
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: Qt.rgba(13 / 255, 11 / 255, 20 / 255, 0.93)
            strokeColor: Theme.withAlpha(Theme.live, 0.45)
            strokeWidth: 1
            joinStyle: ShapePath.MiterJoin
            // The mockup's shard, as fractions of the size
            PathPolyline {
                path: frame.rv ? [[0, 0.03], [0.3, 0], [0.62, 0.025], [1, 0], [0.98, 0.6], [1, 0.97], [0.64, 1], [0.4, 0.96], [0.03, 1], [0.01, 0.55], [0, 0.03]].map(p => Qt.point(p[0] * frame.width, p[1] * frame.height)) : []
            }
        }
    }

    Image {
        visible: frame.rv
        x: frame.width * 0.03
        y: frame.height * 0.04
        width: frame.width * 0.94
        height: frame.height * 0.9
        source: frame.rv ? Qt.resolvedUrl("../assets/coreflame/ash-grain.png") : ""
        fillMode: Image.Tile
        opacity: 0.07
        smooth: false
    }
}
