import QtQuick
import QtQuick.Controls
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

    // Hovering a Titan says how its Coreflame is taken
    function tip(row) {
        return row[1] + " · " + row[3] + (row[2] ? " (taken)" : "");
    }
    readonly property string unlit: rows.filter(r => !r[2]).map(r => r[1].toLowerCase()).join(" · ")

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
                        id: medHover
                    }
                    ToolTip.visible: medHover.hovered
                    ToolTip.text: root.tip(modelData)
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
                        id: blockHover
                    }
                    ToolTip.visible: blockHover.hovered
                    ToolTip.text: root.tip(modelData)
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
                            id: glyphHover
                        }
                        ToolTip.visible: glyphHover.hovered
                        ToolTip.text: root.tip(modelData)
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
