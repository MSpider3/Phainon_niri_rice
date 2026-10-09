import QtQuick
import QtQuick.Shapes
import qs.Common

// Background that takes the current form's shape: rounded paper (Phainon),
// a plate with the top-left and bottom-right corners cut (Khaslana), or a flat slab (Flame Reaver).
Item {
    id: root

    property color color: Theme.surfaceContainer
    property color edgeColor: Theme.withAlpha(Theme.outline, Form.edgeOpacity)
    property real edgeWidth: Form.edgeWidth
    property real radius: Theme.cornerRadius
    property string shape: Form.shape
    property real cut: Form.cut

    Loader {
        anchors.fill: parent
        sourceComponent: root.shape === "cut" ? cutShape : rectShape
    }

    Component {
        id: rectShape

        Rectangle {
            radius: root.shape === "round" ? Math.min(root.radius, height / 2) : 0
            color: root.color
            border.width: root.shape === "round" ? root.edgeWidth : 0
            border.color: root.edgeColor
        }
    }

    Component {
        id: cutShape

        Shape {
            id: plate
            readonly property real inset: root.edgeWidth / 2
            readonly property real c: Math.min(root.cut, height / 2)
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: root.color
                strokeColor: root.edgeWidth > 0 ? root.edgeColor : "transparent"
                strokeWidth: root.edgeWidth
                joinStyle: ShapePath.MiterJoin
                startX: plate.c
                startY: plate.inset

                PathLine {
                    x: plate.width - plate.inset
                    y: plate.inset
                }
                PathLine {
                    x: plate.width - plate.inset
                    y: plate.height - plate.c
                }
                PathLine {
                    x: plate.width - plate.c
                    y: plate.height - plate.inset
                }
                PathLine {
                    x: plate.inset
                    y: plate.height - plate.inset
                }
                PathLine {
                    x: plate.inset
                    y: plate.c
                }
                PathLine {
                    x: plate.c
                    y: plate.inset
                }
            }
        }
    }
}
