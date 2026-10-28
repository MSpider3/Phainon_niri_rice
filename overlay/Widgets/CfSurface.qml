import QtQuick
import QtQuick.Shapes
import qs.Common

// Background that takes the current form's shape: rounded paper (Phainon),
// a plate with the top-left and bottom-right corners cut (Khaslana), or a flat slab (Flame Reaver).
// The Flame Reaver's slab carries a thin violet lining just inside its edge (`lining`), and with
// `torn` it becomes a piece of his cloak: torn hem, lining and ash grain, as on his panels.
Item {
    id: root

    property color color: Theme.surfaceContainer
    property color edgeColor: Theme.withAlpha(Theme.outline, Form.edgeOpacity)
    property real edgeWidth: Form.edgeWidth
    property real radius: Theme.cornerRadius
    property string shape: Form.shape
    property real cut: Form.cut
    property bool lining: Form.reaver
    property bool torn: false

    Loader {
        anchors.fill: parent
        sourceComponent: root.shape === "cut" ? cutShape : (root.torn && Form.reaver ? tornShape : rectShape)
    }

    Component {
        id: tornShape

        CfTab {
            color: root.color
        }
    }

    Component {
        id: rectShape

        Rectangle {
            radius: root.shape === "round" ? Math.min(root.radius, height / 2) : 0
            color: root.color
            border.width: root.shape === "round" ? root.edgeWidth : 0
            border.color: root.edgeColor

            Rectangle {
                visible: root.lining && root.shape === "slab"
                anchors.fill: parent
                anchors.margins: 2
                color: "transparent"
                border.width: 1
                border.color: Theme.withAlpha(Theme.live, 0.6)
            }
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
