import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import qs.Common

// The Flame-Chase: the twelve Titans in Coreflames.order, each as its CfGlyph, lit once earned.
//   layout "medallions"  Phainon: round medallions, gold-filled when lit, name below
//   layout "blocks"      Khaslana: 6 x 2 grid of square plates with a red offset when lit
//   layout "glyphs"      Flame Reaver: a bare row of glyphs and a "// unlit: ..." line
Item {
    id: root

    property string layout: Form.khaslana ? "blocks" : (Form.reaver ? "glyphs" : "medallions")
    property real glyphSize: layout === "glyphs" ? 26 : (layout === "blocks" ? 34 : 32)
    property string fontFamily: Form.bodyFont

    // [glyph name, Titan, lit, how it is earned]; re-read only when the earned list changes
    readonly property var rows: Coreflames.order.map(n => [n, Coreflames.titans[n][0], Coreflames.has(n) && Coreflames.count >= 0, Coreflames.titans[n][1]])

    // Hovering a Titan says how its Coreflame is taken: [name, how]
    function tip(row) {
        const parts = [row[1], row[3] + (row[2] ? " (taken)" : "")];
        return Form.reaver ? parts.map(p => p.toLowerCase()) : parts;
    }
    // The Titan under the pointer; one tooltip follows it instead of one per Titan
    property Item hovered: null
    function hover(item, on) {
        if (on)
            hovered = item;
        else if (hovered === item)
            hovered = null;
    }
    readonly property string unlit: rows.filter(r => !r[2]).map(r => r[1].toLowerCase()).join(" · ")

    // The tooltip under a Titan, one look per form (the v3 mockup's Flame-Chase card):
    // Phainon a cream pill with a gold edge and a small pointer, Khaslana a cut obsidian plate with a
    // red offset, the Flame Reaver a torn shard with a violet left edge.
    component Tip: ToolTip {
        id: tip
        readonly property var parts: root.hovered ? root.tip(root.hovered.modelData) : ["", ""]
        parent: root.hovered ?? root
        visible: root.hovered !== null
        delay: 300
        enter: null
        exit: null
        x: 0
        y: parent ? parent.height + 8 : 0
        leftPadding: 14
        rightPadding: 14
        topPadding: 6
        bottomPadding: 6

        contentItem: Row {
            spacing: 0
            Text {
                anchors.baseline: how.baseline
                text: Form.khaslana ? tip.parts[0].toUpperCase() : tip.parts[0]
                font.family: Form.phainon ? "Marcellus" : (Form.khaslana ? "Cinzel" : "Chakra Petch")
                font.pixelSize: Form.phainon ? 14 : (Form.khaslana ? 12 : 13)
                font.weight: Form.phainon ? Font.Normal : Font.DemiBold
                font.letterSpacing: Form.khaslana ? 1.9 : (Form.phainon ? 0.8 : 0)
                color: Form.phainon ? "#334786" : (Form.khaslana ? "#F5D27A" : "#B9A8FF")
            }
            Text {
                id: how
                text: " · " + tip.parts[1]
                font.family: Form.phainon ? "Marcellus" : "Chakra Petch"
                font.pixelSize: Form.phainon ? 14 : 13
                color: Form.phainon ? "#1E2752" : (Form.khaslana ? "#F3E6CC" : "#E9E7F2")
                opacity: 0.8
            }
        }

        background: Item {
            implicitWidth: 40
            implicitHeight: 28

            // Phainon
            RectangularShadow {
                visible: Form.phainon
                anchors.fill: parent
                offset.y: 6
                blur: 18
                radius: height / 2
                color: Qt.rgba(15 / 255, 22 / 255, 51 / 255, 0.25)
            }
            Rectangle {   // the pointer, half hidden under the pill
                visible: Form.phainon
                x: 22
                y: -5
                width: 10
                height: 10
                rotation: 45
                color: "#FBF9F3"
                border.width: 1
                border.color: "#A87A22"
            }
            Rectangle {
                visible: Form.phainon
                anchors.fill: parent
                radius: height / 2
                color: "#FBF9F3"
                border.width: 1
                border.color: "#A87A22"
            }

            // Khaslana: the red offset, then the plate with its bottom-right corner cut
            Shape {
                id: plate
                visible: !Form.phainon
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                readonly property real w: width
                readonly property real h: height
                readonly property var outline: Form.khaslana ? [Qt.point(0, 0), Qt.point(w, 0), Qt.point(w, h - 8), Qt.point(w - 8, h), Qt.point(0, h), Qt.point(0, 0)] : [Qt.point(0, 0), Qt.point(w, h * 0.08), Qt.point(w * 0.98, h), Qt.point(0, h * 0.92), Qt.point(0, 0)]

                ShapePath {
                    fillColor: Form.khaslana ? "#8E1424" : "transparent"
                    strokeColor: "transparent"
                    PathPolyline {
                        path: Form.khaslana ? plate.outline.map(p => Qt.point(p.x + 4, p.y + 4)) : []
                    }
                }
                ShapePath {
                    fillColor: Form.khaslana ? "#0B080B" : "#0D0B14"
                    strokeColor: Form.khaslana ? "#E0B04A" : "transparent"
                    strokeWidth: 1
                    joinStyle: ShapePath.MiterJoin
                    PathPolyline {
                        path: plate.outline
                    }
                }
            }
            Rectangle {   // the Flame Reaver's violet edge
                visible: Form.reaver
                width: 2
                height: parent.height * 0.92
                color: "#8F7BE0"
            }
        }
    }

    Tip {
        id: shared
    }
    readonly property alias tipShown: shared.visible
    readonly property alias tipParts: shared.parts

    implicitWidth: loader.item ? loader.item.implicitWidth : 0
    implicitHeight: loader.item ? loader.item.implicitHeight : 0

    Loader {
        id: loader
        sourceComponent: root.layout === "blocks" ? blocks : (root.layout === "glyphs" ? glyphs : medallions)
    }

    Component {
        id: medallions

        Row {
            spacing: 6
            Repeater {
                model: root.rows
                Column {
                    required property var modelData
                    width: 50
                    spacing: 3
                    HoverHandler {
                        onHoveredChanged: root.hover(parent, hovered)
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.glyphSize + 12
                        height: width
                        radius: width / 2
                        color: parent.modelData[2] ? "#F5E07A" : "transparent"
                        border.width: 1
                        border.color: parent.modelData[2] ? "#A87A22" : "#C8B27E"
                        CfGlyph {
                            anchors.centerIn: parent
                            name: parent.parent.modelData[0]
                            size: root.glyphSize
                            strokeWidth: 1.4
                            color: parent.parent.modelData[2] ? "#334786" : "#B8AE90"
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: parent.modelData[1]
                        font.family: root.fontFamily
                        font.pixelSize: 11
                        color: parent.modelData[2] ? "#334786" : "#8E8770"
                    }
                }
            }
        }
    }

    Component {
        id: blocks

        Grid {
            columns: 6
            rowSpacing: 6
            columnSpacing: 8
            Repeater {
                model: root.rows
                Row {
                    required property var modelData
                    spacing: 7
                    HoverHandler {
                        onHoveredChanged: root.hover(parent, hovered)
                    }
                    Item {
                        width: root.glyphSize + 3
                        height: root.glyphSize + 3
                        Rectangle {   // the red offset, lit only
                            visible: parent.parent.modelData[2]
                            x: 3
                            y: 3
                            width: root.glyphSize
                            height: root.glyphSize
                            color: "#3A0A12"
                        }
                        Rectangle {
                            width: root.glyphSize
                            height: root.glyphSize
                            color: parent.parent.modelData[2] ? "#8E1424" : "#1A0D10"
                            border.width: 1
                            border.color: parent.parent.modelData[2] ? "#F2C75C" : "#3A1A1E"
                            CfGlyph {
                                anchors.centerIn: parent
                                name: parent.parent.parent.modelData[0]
                                size: root.glyphSize - 12
                                strokeWidth: 1.5
                                color: parent.parent.parent.modelData[2] ? "#F5D27A" : "#6E5F55"
                            }
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.modelData[1].toUpperCase()
                        font.family: root.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.3
                        color: parent.modelData[2] ? "#F5D27A" : "#7A6A5E"
                        style: Text.Outline
                        styleColor: "#0B080B"
                    }
                }
            }
        }
    }

    Component {
        id: glyphs

        Column {
            spacing: 8
            Row {
                spacing: 9
                Repeater {
                    model: root.rows
                    CfGlyph {
                        required property var modelData
                        name: modelData[0]
                        size: root.glyphSize
                        strokeWidth: 1.5
                        color: modelData[2] ? "#B9A8FF" : "#4A4562"
                        HoverHandler {
                            onHoveredChanged: root.hover(parent, hovered)
                        }
                    }
                }
            }
            Text {
                visible: root.unlit !== ""
                text: "// unlit: " + root.unlit
                font.family: root.fontFamily
                font.pixelSize: 12
                color: "#8A8399"
                elide: Text.ElideRight
                width: 12 * (root.glyphSize + 9)
            }
        }
    }
}
