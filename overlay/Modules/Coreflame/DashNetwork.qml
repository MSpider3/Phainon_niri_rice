import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets
import "../../Common/Format.js" as Format

// "Passage · Network": speeds now, the last minute as a graph, and the connection.
// The dashboard holds the "network" DgopService ref while it is open.
Column {
    id: net

    readonly property string ip: NetworkService.ethernetIP || NetworkService.wifiIP || NetworkService.cellularIP
    readonly property var rows: [["Connection", NetworkService.primaryConnection || (Form.reaver ? "nothing." : "Offline")], ["Address", ip || "--"], ["Status", NetworkService.networkStatus || "--"]]

    function tx(text) {
        return Form.reaver ? String(text).toLowerCase() : text;
    }

    spacing: 12

    Row {
        spacing: 12
        height: 104

        Repeater {
            model: [["Down", "download", DgopService.networkRxRate || 0], ["Up", "upload", DgopService.networkTxRate || 0]]

            DashCard {
                required property var modelData
                required property int index
                width: (net.width - 24) / 3
                height: parent.height
                numeral: index === 0 ? "I" : "II"
                glyph: "passage"
                label: modelData[0]

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    DIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !Form.reaver
                        name: modelData[1]
                        size: 26
                        color: index === 0 ? Theme.primary : Theme.withAlpha(Theme.surfaceText, 0.6)
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Format.formatRate(modelData[2])
                        font.family: Form.phainon ? Theme.fontFamily : Theme.monoFontFamily
                        font.pixelSize: 26
                        font.weight: Font.DemiBold
                        color: index === 0 ? (Form.reaver ? Theme.live : Theme.primary) : Theme.surfaceText
                    }
                }
            }
        }

        DashCard {
            width: (net.width - 24) / 3
            height: parent.height
            numeral: "III"
            glyph: "passage"
            label: "Connection"

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                spacing: 4

                Repeater {
                    model: net.rows

                    Row {
                        required property var modelData
                        width: parent.width
                        spacing: 6

                        StyledText {
                            width: 74
                            text: net.tx(modelData[0])
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.withAlpha(Theme.surfaceText, 0.55)
                        }

                        StyledText {
                            width: parent.width - 80
                            elide: Text.ElideRight
                            text: net.tx(modelData[1])
                            font.family: Theme.monoFontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                        }
                    }
                }
            }
        }
    }

    DashCard {
        width: net.width
        height: 230
        numeral: "IV"
        glyph: "passage"
        label: "The last minute"

        DSparkline {
            id: graph
            anchors.fill: parent
            anchors.bottomMargin: 20
            values: DgopService.networkHistory.rx
            secondaryValues: DgopService.networkHistory.tx
            historyLength: 60
            lineColor: Form.reaver ? Theme.live : Theme.primary
            secondaryLineColor: Theme.withAlpha(Theme.surfaceText, 0.5)
            lineWidth: Form.phainon ? 2 : 1.5
            fillOpacity: Form.reaver ? 0 : 0.12
            curved: Form.phainon || !Form.active
        }

        // Scale and legend under the graph
        Row {
            anchors.bottom: parent.bottom
            spacing: 18

            Repeater {
                model: [["down", Form.reaver ? Theme.live : Theme.primary], ["up", Theme.withAlpha(Theme.surfaceText, 0.5)]]

                Row {
                    required property var modelData
                    spacing: 6

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14
                        height: 2
                        color: modelData[1]
                    }

                    StyledText {
                        text: net.tx(modelData[0] === "down" ? "Down" : "Up")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.withAlpha(Theme.surfaceText, 0.6)
                    }
                }
            }
        }

        StyledText {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            text: net.tx("peak ") + Format.formatRate(1024 * Math.max(0, ...DgopService.networkHistory.rx, ...DgopService.networkHistory.tx)) + "  ·  60 s"
            font.family: Theme.monoFontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.withAlpha(Theme.surfaceText, 0.5)
        }
    }
}
