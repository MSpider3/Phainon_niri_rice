import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Common

// A right-click menu's background, per form as the v3 mockup draws it: Phainon a parchment card
// (rounded 20, tan rim, soft shadow); Khaslana an obsidian plate with a gold edge, the lower
// right corner cut and a hard red offset; the Flame Reaver a near-black, slightly torn slab with a
// violet edge down its left side. Only the current form's version is built.
Item {
    id: plate

    readonly property real phRadius: 20

    Loader {
        anchors.fill: parent
        sourceComponent: Form.khaslana ? khPlate : (Form.reaver ? rvPlate : phPlate)
    }

    Component {
        id: phPlate

        Item {
            RectangularShadow {
                anchors.fill: parent
                offset.y: 10
                blur: 28
                radius: plate.phRadius
                color: Qt.rgba(15 / 255, 22 / 255, 51 / 255, 0.3)
            }

            Rectangle {
                anchors.fill: parent
                radius: plate.phRadius
                color: "#F7F3E8"
                border.width: 1
                border.color: "#C8B27E"
            }
        }
    }

    Component {
        id: khPlate

        Shape {
            id: kh
            readonly property real c: 14
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "#8E1424"
                strokeColor: "transparent"
                PathPolyline {
                    path: [Qt.point(5, 5), Qt.point(kh.width + 5, 5), Qt.point(kh.width + 5, kh.height + 5 - kh.c), Qt.point(kh.width + 5 - kh.c, kh.height + 5), Qt.point(5, kh.height + 5), Qt.point(5, 5)]
                }
            }
            ShapePath {
                fillColor: "#0B080B"
                strokeColor: "#E0B04A"
                strokeWidth: 1
                joinStyle: ShapePath.MiterJoin
                PathPolyline {
                    path: [Qt.point(0.5, 0.5), Qt.point(kh.width - 0.5, 0.5), Qt.point(kh.width - 0.5, kh.height - kh.c), Qt.point(kh.width - kh.c, kh.height - 0.5), Qt.point(0.5, kh.height - 0.5), Qt.point(0.5, 0.5)]
                }
            }
        }
    }

    Component {
        id: rvPlate

        Item {
            CfQuad {
                anchors.fill: parent
                points: [[0, 0], [1, 0.03], [0.98, 1], [0, 0.97]]
                fill: Qt.rgba(13 / 255, 11 / 255, 20 / 255, 0.97)
            }

            Rectangle {
                width: 2
                height: parent.height * 0.97
                color: "#8F7BE0"
            }
        }
    }
}
