import QtQuick
import QtQuick.Shapes
import qs.Common

// A Settings row's background per form, as the mockup draws it: Phainon a paper card, Khaslana a
// plate with its bottom-right corner cut, the Reaver no box, only a rule beneath. Static shapes.
Item {
    id: root

    property bool highlighted: false
    property bool selected: false

    readonly property color fill: Form.phainon ? "#FBF9F3" : (Form.khaslana ? "#140C0F" : "transparent")
    readonly property color shown: selected ? Theme.selectedContainer : !highlighted ? fill : (Form.reaver ? Theme.withAlpha("#B9A8FF", 0.12) : Theme.blend(fill, Theme.primary, SettingsMetrics.highlightBlend))

    Rectangle {
        visible: !Form.khaslana
        anchors.fill: parent
        radius: Form.phainon ? 16 : 0
        color: root.shown
        border.width: Form.phainon ? 1 : 0
        border.color: "#ECE3CC"
    }

    Rectangle {
        visible: Form.reaver
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: "#2C2840"
    }

    Loader {
        anchors.fill: parent
        active: Form.khaslana
        sourceComponent: Shape {
            id: plate
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: root.shown
                strokeColor: "#3A1A1E"
                strokeWidth: 1
                joinStyle: ShapePath.MiterJoin
                PathPolyline {
                    path: [Qt.point(0.5, 0.5), Qt.point(plate.width - 0.5, 0.5), Qt.point(plate.width - 0.5, plate.height - 9), Qt.point(plate.width - 9, plate.height - 0.5), Qt.point(0.5, plate.height - 0.5), Qt.point(0.5, 0.5)]
                }
            }
        }
    }
}
