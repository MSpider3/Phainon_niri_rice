import QtQuick
import QtQuick.Shapes
import qs.Common

// The head of a Coreflame dialog, as the v3 mockup draws it: the titan's glyph and "Titan · Kind"
// over a rule (Phainon a gold meander, Khaslana a gold rule with a red echo, the Flame Reaver a dim
// rule after "//", lower case), then the dialog's own title. Static shapes only.
Column {
    id: head

    // A CfGlyph key that is also the titan word: passage, time, law, worldbearing...
    property string glyph: ""
    property string kind: ""
    property string title: ""
    property bool closable: false

    signal closeClicked

    readonly property bool kh: Form.khaslana
    readonly property bool rv: Form.reaver
    readonly property bool ph: !kh && !rv
    readonly property string line: glyph === "" ? "" : glyph.charAt(0).toUpperCase() + glyph.slice(1) + " · " + kind

    spacing: 0

    Item {
        width: head.width
        height: 34
        visible: head.line !== ""

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Text {
                visible: head.rv
                anchors.verticalCenter: parent.verticalCenter
                text: "//"
                font.family: "Chakra Petch"
                font.pixelSize: 15
                color: "#B9A8FF"
            }

            CfGlyph {
                visible: !head.rv
                anchors.verticalCenter: parent.verticalCenter
                name: head.glyph
                size: 22
                color: head.kh ? "#E0B04A" : "#A87A22"
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: head.rv ? head.line.toLowerCase() : head.line.toUpperCase()
                font.family: head.kh ? "Cinzel" : (head.rv ? "Chakra Petch" : "Marcellus")
                font.pixelSize: head.rv ? 15 : (head.kh ? 14 : 17)
                font.weight: head.kh ? Font.Bold : Font.Normal
                font.letterSpacing: head.kh ? 4.2 : (head.ph ? 2.4 : 0)
                color: head.kh ? "#F5D27A" : (head.rv ? "#CFC6A8" : "#334786")
            }
        }

        Text {
            visible: head.closable
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: head.rv ? "esc" : "✕"
            font.family: "Chakra Petch"
            font.pixelSize: 13
            opacity: 0.8
            color: head.kh ? "#F5D27A" : (head.rv ? "#A8A4BC" : "#334786")
            Accessible.role: Accessible.Button
            Accessible.name: I18n.tr("Close")

            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                onClicked: head.closeClicked()
            }
        }
    }

    // The rule under the head line
    Item {
        width: head.width
        height: head.ph ? 12 : (head.kh ? 5 : 1)
        visible: head.line !== ""

        Shape {
            visible: head.ph
            anchors.fill: parent
            opacity: 0.7
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: "#A87A22"
                strokeWidth: 1
                PathSvg {
                    path: {
                        const w = head.width;
                        let d = `M0 0.5H${w}M0 11.5H${w}`;
                        for (let x = 5.5; x < w; x += 12)
                            d += `M${x} 0V12`;
                        return head.ph && w > 0 ? d : "";
                    }
                }
            }
        }

        Rectangle {
            visible: head.kh
            y: 3
            width: parent.width
            height: 2
            color: "#8E1424"
        }

        Rectangle {
            visible: head.kh
            width: parent.width
            height: 2
            color: "#E0B04A"
        }

        Rectangle {
            visible: head.rv
            anchors.fill: parent
            color: "#2C2840"
        }
    }

    Item {
        width: 1
        height: 10
        visible: head.line !== "" && head.title !== ""
    }

    CfDialogText {
        width: head.width
        visible: head.title !== ""
        role: "title"
        // The Flame Reaver ends its titles with a full stop
        text: head.rv && !/[.?!]$/.test(head.title) ? head.title + "." : head.title
    }
}
