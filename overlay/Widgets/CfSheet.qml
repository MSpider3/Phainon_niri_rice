import QtQuick
import QtQuick.Shapes
import qs.Common

// The frame of the island's windows (clipboard, system monitor, notes), one per form as the v3
// mockup draws them: Phainon a parchment sheet floating under the island with a meander under its
// title; Khaslana an obsidian plate hanging from the island, lower corners cut, a gold edge open at
// the top and a hard red offset; the Flame Reaver a torn shard of ash floating free, all lower case.
// Content goes in the body between the header and the hint line. Static shapes only.
Item {
    id: sheet

    property string title: ""
    property string glyph: ""
    property string count: ""
    property string hint: ""
    default property alias content: body.data

    readonly property bool kh: Form.khaslana
    readonly property bool rv: Form.reaver
    readonly property bool ph: !kh && !rv
    readonly property real padX: rv ? 34 : (kh ? 24 : 26)
    readonly property real padTop: rv ? 24 : (kh ? 14 : 18)
    readonly property real headerHeight: padTop + 34 + (ph ? 16 : 12)
    readonly property real footerHeight: hint === "" ? 16 : (rv ? 54 : 44)
    readonly property alias body: body

    // Where the window's top sits: Khaslana hangs from the island, the others float below it
    function topFor(strip) {
        return kh ? strip : strip + 10;
    }

    function tx(text) {
        return rv ? String(text).toLowerCase() : text;
    }

    CfFrame {
        anchors.fill: parent
    }

    // ── header: the window's glyph and name, the count on the right, then a rule ──
    Item {
        x: sheet.padX
        y: sheet.padTop
        width: sheet.width - 2 * sheet.padX
        height: 34

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Text {
                visible: sheet.rv
                anchors.verticalCenter: parent.verticalCenter
                text: "//"
                font.family: "Chakra Petch"
                font.pixelSize: 15
                color: "#B9A8FF"
            }

            CfGlyph {
                visible: !sheet.rv && sheet.glyph !== ""
                anchors.verticalCenter: parent.verticalCenter
                name: sheet.glyph
                size: 22
                strokeWidth: 1.6
                color: sheet.kh ? "#E0B04A" : "#A87A22"
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: sheet.rv ? sheet.title.toLowerCase() : sheet.title.toUpperCase()
                font.family: sheet.kh ? "Cinzel" : (sheet.rv ? "Chakra Petch" : "Marcellus")
                font.pixelSize: sheet.rv ? 15 : 17
                font.weight: sheet.kh ? Font.Bold : Font.Normal
                font.letterSpacing: sheet.kh ? 5 : (sheet.ph ? 2.4 : 0)
                color: sheet.kh ? "#F5D27A" : (sheet.rv ? "#CFC6A8" : Theme.primary)
            }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: sheet.count
            font.family: "Chakra Petch"
            font.pixelSize: 13
            color: sheet.kh ? "#C9B89E" : (sheet.rv ? "#A8A4BC" : Theme.withAlpha(Theme.surfaceText, 0.7))
        }
    }

    // Phainon: a meander of gold ticks between two rules
    Shape {
        visible: sheet.ph
        x: sheet.padX
        y: sheet.padTop + 34
        width: sheet.width - 2 * sheet.padX
        height: 12
        opacity: 0.7
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: "#A87A22"
            strokeWidth: 1
            PathSvg {
                path: {
                    const w = sheet.width - 2 * sheet.padX;
                    let d = `M0 0.5H${w}M0 11.5H${w}`;
                    for (let x = 5.5; x < w; x += 12)
                        d += `M${x} 0V12`;
                    return sheet.ph && w > 0 ? d : "";
                }
            }
        }
    }

    // Khaslana: a gold rule with a red echo under it
    Rectangle {
        visible: sheet.kh
        x: sheet.padX
        y: sheet.padTop + 37
        width: sheet.width - 2 * sheet.padX
        height: 2
        color: "#8E1424"
    }
    Rectangle {
        visible: sheet.kh
        x: sheet.padX
        y: sheet.padTop + 34
        width: sheet.width - 2 * sheet.padX
        height: 2
        color: "#E0B04A"
    }

    // Flame Reaver: a dim rule
    Rectangle {
        visible: sheet.rv
        x: sheet.padX
        y: sheet.padTop + 34
        width: sheet.width - 2 * sheet.padX
        height: 1
        color: "#2C2840"
    }

    Item {
        id: body
        x: sheet.padX
        y: sheet.headerHeight
        width: sheet.width - 2 * sheet.padX
        height: sheet.height - sheet.headerHeight - sheet.footerHeight
    }

    // ── the hint line at the foot, over a rule ──
    Rectangle {
        visible: sheet.hint !== ""
        x: sheet.rv ? sheet.padX : 0
        y: sheet.height - sheet.footerHeight + 6
        width: sheet.rv ? sheet.width - 2 * sheet.padX : sheet.width
        height: sheet.rv ? 2 : 1
        color: sheet.kh ? "#5A3A1E" : (sheet.rv ? "#8F7BE0" : Theme.withAlpha(Theme.outline, 0.45))
    }

    Text {
        visible: sheet.hint !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        y: sheet.height - sheet.footerHeight + 6
        height: sheet.footerHeight - 6 - (sheet.kh ? 10 : (sheet.rv ? 14 : 0))
        verticalAlignment: Text.AlignVCenter
        text: sheet.tx(sheet.hint)
        font.family: "Chakra Petch"
        font.pixelSize: 12
        color: sheet.kh ? "#C9B89E" : (sheet.rv ? "#A8A4BC" : Theme.withAlpha(Theme.surfaceText, 0.7))
    }
}
