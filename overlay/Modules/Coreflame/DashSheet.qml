import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Widgets

// The frame a full dashboard view hangs in, per form (v3 mockup, "Dashboard views"). 780 wide.
//   Phainon: a parchment sheet, the view's name centred over a Greek-key band.
//   Khaslana: an obsidian mosaic in gold seams (the view's `blocks`), a red header block,
//     golden-blood cracks over the blocks and the Black Tide hanging under them.
//   Flame Reaver: a header shard over the view's own shards (DashCard `poly`), violet cracks behind.
// The view's cards go in as children, placed from (0, 0) of the body; `bodyWidth` is their room.
Item {
    id: sheet

    property string title: ""
    property string glyph: ""
    property real bodyHeight: 300
    // Khaslana's blocks, [x, y, w, h, red] in body coordinates; the cards on them are `bare`
    property var blocks: []
    signal back

    default property alias content: body.data

    readonly property bool ph: Form.phainon
    readonly property bool kh: Form.khaslana
    readonly property bool rv: Form.reaver
    readonly property real bodyX: ph ? 16 : (kh ? 5 : 0)
    readonly property real bodyY: ph ? 74 : (kh ? 54 : 72)
    readonly property real bodyWidth: width - 2 * bodyX
    readonly property real gridBottom: bodyY + bodyHeight + (kh ? 5 : 0)
    // Khaslana's four columns: x of column i, width of a span of n
    readonly property real cw: (bodyWidth - 15) / 4
    function colX(i) {
        return Math.floor(i * (cw + 5));
    }
    function spanW(n) {
        return Math.round(n * cw + (n - 1) * 5);
    }

    width: 780
    implicitHeight: gridBottom + (ph ? 16 : (kh ? 110 : 0))

    // ── Phainon: the parchment sheet ──
    RectangularShadow {
        visible: sheet.ph
        anchors.fill: paper
        offset.y: 14
        blur: 30
        radius: 24
        color: Qt.rgba(15 / 255, 22 / 255, 51 / 255, 0.3)
    }

    Rectangle {
        id: paper
        visible: sheet.ph
        width: parent.width
        height: sheet.implicitHeight
        radius: 24
        color: "#F7F3E8"
        border.width: 1
        border.color: "#C8B27E"
    }

    // Greek key under the name
    Item {
        visible: sheet.ph
        x: 18
        y: 48
        width: parent.width - 36
        height: 12
        opacity: 0.7

        Rectangle {
            width: parent.width
            height: 1
            color: "#A87A22"
        }
        Rectangle {
            y: 11
            width: parent.width
            height: 1
            color: "#A87A22"
        }
        Repeater {
            model: sheet.ph ? Math.floor(parent.width / 12) : 0
            Rectangle {
                required property int index
                x: index * 12 + 5
                width: 1
                height: 12
                color: "#A87A22"
            }
        }
    }

    // ── Khaslana: gold in the seams, obsidian blocks, cracks, the tide ──
    Rectangle {
        visible: sheet.kh
        width: parent.width
        height: sheet.gridBottom
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: "#F2C75C"
            }
            GradientStop {
                position: 0.4
                color: "#B07A1E"
            }
            GradientStop {
                position: 0.6
                color: "#F2C75C"
            }
            GradientStop {
                position: 1
                color: "#9C6A18"
            }
        }
    }

    Repeater {
        model: sheet.kh ? sheet.blocks.concat([[0, -49, sheet.bodyWidth, 44, true]]) : []

        Rectangle {
            required property var modelData
            x: sheet.bodyX + modelData[0]
            y: sheet.bodyY + modelData[1]
            width: modelData[2]
            height: modelData[3]
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop {
                    position: 0
                    color: modelData[4] ? "#3A0A12" : "#0B080B"
                }
                GradientStop {
                    position: 0.7
                    color: "#0B080B"
                }
            }
        }
    }

    Loader {
        active: sheet.kh
        sourceComponent: CfCracks {
            width: sheet.width
            height: sheet.gridBottom
            kind: "gold"
            trunk: 0.7
            branch: 0.7
        }
    }

    Loader {
        active: sheet.kh
        y: sheet.gridBottom
        x: 6
        sourceComponent: CfTide {
            width: sheet.width - 12
            height: 110
            edge: "top"
            seed: 5
            base: 0.2
            liquid: 110
            blocks: 50
            blockMax: 40
            cubes: 16
            cubeDepth: 110
        }
    }

    // ── Flame Reaver: violet cracks behind the shards, and the header shard ──
    Loader {
        active: sheet.rv
        z: -1
        sourceComponent: CfCracks {
            width: sheet.width
            height: sheet.gridBottom
            kind: "violet"
        }
    }

    DashCard {
        visible: sheet.rv
        width: parent.width
        height: 58
        poly: [[0, 0], [1, 0.1], [0.98, 1], [0.01, 0.92]]
    }

    // ── the header: back, the Titan's glyph, the view's name ──
    Item {
        id: head
        x: sheet.kh ? 5 : 0
        y: sheet.kh ? 5 : 0
        width: parent.width - 2 * x
        height: sheet.ph ? 48 : (sheet.kh ? 44 : 58)

        Row {
            id: headRow
            x: sheet.ph ? Math.round((head.width - width) / 2) : (sheet.kh ? 16 : 26)
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: sheet.ph ? 2 : 0
            spacing: sheet.kh ? 12 : 10

            Text {
                visible: !sheet.ph
                anchors.verticalCenter: parent.verticalCenter
                text: sheet.rv ? "<" : "‹"
                font.family: sheet.rv ? "Chakra Petch" : "Cinzel"
                font.pixelSize: sheet.rv ? 14 : 24
                font.weight: Font.DemiBold
                color: sheet.rv ? "#B9A8FF" : "#E0B04A"
            }

            CfGlyph {
                anchors.verticalCenter: parent.verticalCenter
                name: sheet.glyph
                size: sheet.rv ? 18 : 20
                strokeWidth: 1.5
                color: sheet.ph ? "#A87A22" : (sheet.kh ? "#E0B04A" : "#B9A8FF")
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: sheet.rv ? "// " + sheet.title.toLowerCase() : (sheet.kh ? sheet.title.toUpperCase() : sheet.title)
                font.family: sheet.ph ? "Marcellus" : (sheet.kh ? "Cinzel" : "Chakra Petch")
                font.pixelSize: sheet.ph ? 20 : (sheet.kh ? 18 : 14)
                font.weight: sheet.ph ? Font.Normal : (sheet.kh ? Font.Bold : Font.DemiBold)
                font.letterSpacing: sheet.ph ? 1.2 : (sheet.kh ? 3.6 : 2.2)
                color: sheet.ph ? "#334786" : (sheet.kh ? "#F5D27A" : "#B9A8FF")
                style: sheet.kh ? Text.Outline : Text.Normal
                styleColor: "#0B080B"
            }
        }

        // Phainon's back mark sits apart at the left; the others lead the row with it
        Text {
            visible: sheet.ph
            x: 22
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 2
            text: "‹"
            font.family: "Marcellus"
            font.pixelSize: 26
            color: "#A87A22"
        }

        MouseArea {
            width: sheet.ph ? 60 : headRow.x + 40
            height: parent.height
            cursorShape: Qt.PointingHandCursor
            onClicked: sheet.back()
        }
    }

    Item {
        id: body
        x: sheet.bodyX
        y: sheet.bodyY
        width: sheet.bodyWidth
        height: sheet.bodyHeight
    }
}
