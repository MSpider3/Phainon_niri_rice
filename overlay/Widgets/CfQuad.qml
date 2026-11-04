import QtQuick
import QtQuick.Shapes

// A static polygon given as fractions of its size, e.g. the Flame Reaver's slightly torn quads:
// [[0, 0.12], [0.4, 0], [1, 0.08], [0.96, 1], [0.04, 0.94]].
Shape {
    id: quad

    property var points: [[0, 0], [1, 0], [1, 1], [0, 1]]
    property color fill: "transparent"
    property color stroke: "transparent"
    property real strokeWidth: 0

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: quad.fill
        strokeColor: quad.strokeWidth > 0 ? quad.stroke : "transparent"
        strokeWidth: quad.strokeWidth
        joinStyle: ShapePath.MiterJoin
        PathPolyline {
            path: quad.points.concat([quad.points[0]]).map(p => Qt.point(p[0] * quad.width, p[1] * quad.height))
        }
    }
}
