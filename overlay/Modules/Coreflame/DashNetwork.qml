import QtQuick
import QtQuick.Shapes
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets
import "../../Common/Format.js" as Format

// "Passage · Network": speeds now, the connection, and the last minute as a graph.
// The dashboard holds the "network" DgopService ref while it is open.
//   Phainon: three paper cards and the minute as a soft lapis area over faint rules.
//   Khaslana: speeds in his numerals with a red echo, the connection on a red block, the minute a
//     hard gold line.  Flame Reaver: a shard per reading, the minute a broken violet line ending
//     in one ember.
DashSheet {
    id: view

    readonly property string ip: NetworkService.ethernetIP || NetworkService.wifiIP || NetworkService.cellularIP
    readonly property var rows: [["Connection", NetworkService.primaryConnection || (rv ? "nothing." : "Offline")], ["Address", ip || "--"], ["Status", NetworkService.networkStatus || "--"]]
    readonly property var rates: [DgopService.networkRxRate || 0, DgopService.networkTxRate || 0]
    readonly property int gap: ph ? 12 : (kh ? 5 : 14)
    readonly property int topH: ph ? 104 : (kh ? 104 : 120)
    readonly property int graphH: ph ? 210 : (kh ? 205 : 220)
    // [x, w] of Down, Up and Connection across the top row
    readonly property var cols: ph ? [0, 1, 2].map(i => [i * (bodyWidth + gap) / 3, (bodyWidth - 2 * gap) / 3]) : (kh ? [[colX(0), spanW(1)], [colX(1), spanW(1)], [colX(2), spanW(2)]] : [[0, 240], [254, 220], [488, 292]])
    readonly property color down: ph ? "#334786" : (kh ? "#E0B04A" : "#B9A8FF")
    readonly property color up: ph ? "#8C93B3" : (kh ? "#8E1424" : "#5C5478")

    title: "Passage · Network"
    glyph: "passage"
    bodyHeight: topH + gap + graphH
    blocks: kh ? cols.map((c, i) => [c[0], 0, c[1], topH, i === 2]).concat([[0, topH + gap, bodyWidth, graphH, false]]) : []

    CfInk {
        id: ink
    }

    // ── Down and Up ──
    Repeater {
        model: 2

        DashCard {
            id: speed

            required property int index

            x: view.cols[index][0]
            width: view.cols[index][1]
            height: view.topH
            bare: view.kh
            flute: false
            poly: index === 0 ? [[0, 0], [1, 0.03], [0.97, 1], [0.02, 0.94]] : [[0.04, 0], [1, 0], [0.96, 1], [0, 0.88]]
            glyph: "passage"
            label: index === 0 ? "I · Down" : "II · Up"

            // Khaslana: the red echo behind his numerals
            Text {
                visible: view.kh
                x: 3
                anchors.verticalCenter: rate.verticalCenter
                text: rate.text
                font: rate.font
                color: "#8E1424"
            }

            Text {
                id: rate
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                elide: Text.ElideRight
                text: (view.ph ? (speed.index === 0 ? "↓ " : "↑ ") : "") + ink.tx(Format.formatRate(view.rates[speed.index]))
                font.family: Form.numerals
                font.pixelSize: view.ph ? 32 : 30
                font.italic: view.rv
                color: speed.index === 0 ? (view.ph ? "#334786" : (view.kh ? "#F5D27A" : "#CFC6A8")) : ink.muted
            }
        }
    }

    // ── the connection ──
    DashCard {
        x: view.cols[2][0]
        width: view.cols[2][1]
        height: view.topH
        bare: view.kh
        flute: false
        poly: [[0.03, 0], [1, 0], [1, 0.92], [0, 1]]
        glyph: "passage"
        label: "III · Connection"

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            spacing: 3

            Repeater {
                model: view.rows

                Row {
                    required property var modelData
                    required property int index
                    width: parent.width
                    spacing: 10

                    Text {
                        width: view.rv ? 76 : 86
                        text: ink.tx(modelData[0])
                        font.family: ink.font
                        font.pixelSize: 13
                        color: ink.muted
                    }

                    Text {
                        width: parent.width - (view.rv ? 86 : 96)
                        elide: Text.ElideRight
                        text: ink.tx(modelData[1])
                        font.family: ink.font
                        font.pixelSize: 13
                        color: view.kh && index === 0 ? "#F5D27A" : ink.text
                    }
                }
            }
        }
    }

    // ── the last minute ──
    DashCard {
        y: view.topH + view.gap
        width: view.bodyWidth
        height: view.graphH
        bare: view.kh
        flute: false
        poly: [[0.02, 0.04], [1, 0], [0.97, 0.96], [0, 1]]
        glyph: "passage"
        label: "The last minute"

        // faint rules under the line
        Repeater {
            model: view.rv ? 0 : 3

            Rectangle {
                required property int index
                y: Math.round((index + 1) * graph.height / 4)
                width: parent.width
                height: 1
                color: view.ph ? "#ECE3CC" : "#2A1015"
            }
        }

        DSparkline {
            id: graph
            anchors.fill: parent
            anchors.bottomMargin: 24
            values: DgopService.networkHistory.rx
            secondaryValues: DgopService.networkHistory.tx
            historyLength: 60
            // The Flame Reaver draws its own broken line below
            lineColor: view.rv ? "transparent" : view.down
            secondaryLineColor: view.up
            lineWidth: view.kh ? 2.2 : 1.6
            // Phainon a soft lapis area; Khaslana's hard gold line and the Reaver's have none
            fillOpacity: view.ph ? 0.1 : 0
            curved: false
        }

        // Flame Reaver: the minute as a broken violet line (the mockup's 14 px dashes, 3 px breaks)
        Loader {
            active: view.rv
            anchors.fill: graph

            sourceComponent: Shape {
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: view.down
                    strokeWidth: graph.lineWidth
                    strokeStyle: ShapePath.DashLine
                    // in stroke widths
                    dashPattern: [14 / graph.lineWidth, 3 / graph.lineWidth]
                    fillColor: "transparent"
                    capStyle: ShapePath.FlatCap
                    joinStyle: ShapePath.MiterJoin

                    PathSvg {
                        path: graph.linePath
                    }
                }
            }
        }

        // Flame Reaver: the minute ends in one ember
        Rectangle {
            readonly property var last: graph.points.length > 0 ? graph.points[graph.points.length - 1] : null
            visible: view.rv && last !== null
            x: graph.x + (last ? last.x : 0) - width / 2
            y: graph.y + (last ? last.y : 0) - height / 2
            width: 8
            height: 8
            radius: 4
            color: "#F07A85"
        }

        // Legend and peak under the graph
        Row {
            anchors.bottom: parent.bottom
            spacing: 14

            Repeater {
                model: [["Down", view.down], ["Up", view.up]]

                Row {
                    required property var modelData
                    spacing: 6

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14
                        height: 2
                        color: modelData[1]
                    }

                    Text {
                        text: ink.tx(modelData[0])
                        font.family: ink.font
                        font.pixelSize: 13
                        color: ink.muted
                    }
                }
            }
        }

        Text {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            text: (view.rv ? "// " : "") + ink.tx("peak " + Format.formatRate(1024 * Math.max(0, ...DgopService.networkHistory.rx, ...DgopService.networkHistory.tx)) + " · 60 s")
            font.family: ink.font
            font.pixelSize: 13
            color: ink.muted
        }
    }
}
