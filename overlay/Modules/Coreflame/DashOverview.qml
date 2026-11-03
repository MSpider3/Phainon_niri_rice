import QtQuick
import QtQuick.Shapes
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets
import "../../Common/Format.js" as Format

// The dashboard's summary page: the same ten cards in every form, laid out as Khaslana's obsidian
// mosaic held together with golden blood, the Flame Reaver's shattered pane, or Phainon's temple
// front. Positions are the v3 mockup's, in screen pixels from the layout's top-left corner.
Item {
    id: ov

    required property var host
    required property date now

    readonly property string f: Form.khaslana ? "kh" : (Form.reaver ? "rv" : "ph")
    readonly property var size: ({
            "kh": [1400, 688],
            "rv": [1400, 814],
            "ph": [1160, 716]
        })[f]
    // [x, y, width, height] of every card
    readonly property var slots: ({
            "kh": {
                "clock": [5, 5, 692, 268],
                "calendar": [702, 5, 461, 268],
                "weather": [1168, 5, 227, 129],
                "system": [1168, 139, 227, 134],
                "flame": [5, 278, 692, 147],
                "messages": [702, 278, 693, 147],
                "network": [5, 430, 460, 103],
                "music": [470, 430, 460, 103],
                "screen": [935, 430, 228, 103],
                "walls": [1168, 430, 227, 103]
            },
            "rv": {
                "calendar": [0, 0, 450, 400],
                "clock": [470, 0, 460, 250],
                "weather": [950, 0, 450, 220],
                "system": [950, 236, 450, 250],
                "messages": [470, 266, 460, 280],
                "network": [0, 416, 450, 150],
                "music": [950, 502, 450, 200],
                "screen": [0, 582, 450, 140],
                "flame": [470, 562, 460, 150],
                "walls": [470, 728, 460, 86]
            },
            "ph": {
                "clock": [15, 162, 367, 139],
                "calendar": [15, 311, 367, 227],
                "weather": [396, 162, 367, 220],
                "system": [396, 392, 367, 131],
                "network": [396, 533, 367, 80],
                "messages": [778, 162, 367, 180],
                "music": [778, 352, 367, 139],
                "screen": [778, 501, 367, 90],
                "flame": [0, 627, 930, 69],
                "walls": [935, 641, 207, 40]
            }
        })[f]
    // The Reaver's shards: the mockup's clip polygons, corners clockwise from top-left
    readonly property var shards: ({
            "calendar": [[0, 0], [1, 0.03], [0.97, 1], [0.02, 0.94]],
            "clock": [[0.04, 0], [1, 0], [0.96, 1], [0, 0.88]],
            "weather": [[0.03, 0], [1, 0], [1, 0.92], [0, 1]],
            "system": [[0, 0.06], [1, 0], [0.98, 1], [0.03, 0.95]],
            "messages": [[0.02, 0.04], [1, 0], [0.97, 0.96], [0, 1]],
            "network": [[0, 0], [0.98, 0.06], [1, 1], [0.03, 0.92]],
            "music": [[0, 0], [1, 0.08], [0.96, 1], [0.02, 0.9]],
            "screen": [[0.02, 0], [1, 0.05], [0.98, 1], [0, 0.94]],
            "flame": [[0, 0.08], [1, 0], [0.97, 1], [0.03, 0.92]],
            "walls": [[0, 0], [1, 0.12], [0.98, 1], [0.04, 0.86]]
        })

    // Ink per form: body text, muted text, the large figures
    readonly property bool light: Theme.isLightMode
    readonly property color ink: Form.khaslana ? "#F3E6CC" : (Form.reaver ? "#E9E7F2" : (light ? "#1E2752" : Theme.surfaceText))
    readonly property color mut: Form.khaslana ? "#C9B89E" : (Form.reaver ? "#A8A4BC" : (light ? "#4A5484" : Theme.withAlpha(Theme.surfaceText, 0.7)))
    readonly property color figure: Form.khaslana ? "#F5D27A" : (Form.reaver ? "#E9E7F2" : (light ? "#334786" : Theme.primary))
    readonly property color tint: Form.khaslana ? "#E0B04A" : (Form.reaver ? "#B9A8FF" : figure)
    readonly property string body: Form.phainon ? Form.numerals : "Chakra Petch"
    // Phainon's temple: the mockup's parchment in light mode, the theme's surfaces in dark mode
    readonly property color paper: light ? "#F7F3E8" : Theme.surfaceContainer
    readonly property color floor: light ? "#F4EFE2" : Theme.surface
    readonly property color card: light ? "#FBF9F3" : Theme.surfaceContainerHigh
    readonly property color rim: light ? "#C8B27E" : Theme.withAlpha(Theme.outline, 0.7)
    readonly property color track: light ? "#E4DAC0" : Theme.withAlpha(Theme.outline, 0.35)
    readonly property color gilt: light ? "#A87A22" : Theme.secondary
    readonly property color capInk: light ? "#8A6418" : Theme.primary

    readonly property var notes: NotificationService.groupedNotifications.slice(0, 3)
    readonly property MprisPlayer player: MprisController.activePlayer
    readonly property int hour: now.getHours()
    readonly property string time: now.toLocaleTimeString(I18n.locale(), SettingsData.use24HourClock ? "HH:mm" : "h:mm AP").replace(/\s*[AaPp]\.?[Mm]\.?$/, "")
    readonly property var weather: WeatherService.weather

    implicitWidth: size[0]
    implicitHeight: size[1]

    function tx(text) {
        return Form.reaver ? String(text).toLowerCase() : text;
    }

    // ── shared pieces ──

    component Label: Text {
        color: ov.ink
        font.family: ov.body
        font.pixelSize: 14
        elide: Text.ElideRight
        maximumLineCount: 1
        textFormat: Text.PlainText
        style: Form.khaslana ? Text.Outline : Text.Normal
        styleColor: "#0B080B"
    }

    // A large figure: Khaslana's carries a red echo, the Reaver's a violet and teal glitch.
    component Figure: Item {
        id: fig
        property string text: ""
        property int px: 40
        property bool italic: Form.reaver
        property color color: ov.figure
        implicitWidth: figMain.implicitWidth
        implicitHeight: px

        Repeater {
            model: Form.khaslana ? [[Math.max(2, Math.round(fig.px / 38)), "#8E1424"]] : (Form.reaver ? [[2, "#D98F7BE0"], [-2, "#8C4FD1C5"]] : [])

            Text {
                required property var modelData
                x: modelData[0]
                text: fig.text
                font: figMain.font
                color: modelData[1]
                height: fig.px
                verticalAlignment: Text.AlignVCenter
            }
        }

        Text {
            id: figMain
            text: fig.text
            height: fig.px
            verticalAlignment: Text.AlignVCenter
            font.family: Form.numerals
            font.pixelSize: fig.px
            font.italic: fig.italic
            color: fig.color
            style: Form.khaslana ? Text.Outline : Text.Normal
            styleColor: "#0B080B"
        }
    }

    // Eight blocks for a reading: Khaslana's red with a gold head, the Reaver's skewed violet
    // with a dashed gap, Phainon's thin ink line.
    component Gauge: Item {
        id: gauge
        property real value: 0
        property bool alarm: false
        readonly property int lit: Math.round(Math.max(0, Math.min(1, value)) * 8)
        implicitHeight: Form.phainon ? 4 : 10

        Rectangle {
            visible: Form.phainon
            anchors.fill: parent
            color: ov.track

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, gauge.value))
                height: parent.height
                color: gauge.alarm ? Theme.error : ov.figure
            }
        }

        Row {
            visible: !Form.phainon
            anchors.fill: parent
            spacing: Form.reaver ? 3 : 2

            Repeater {
                model: Form.phainon ? 0 : 8

                Rectangle {
                    required property int index
                    readonly property bool on: index < gauge.lit
                    width: (gauge.width - 7 * parent.spacing) / 8
                    height: Form.reaver ? 9 : 10
                    color: gauge.alarm && on ? Theme.error : (Form.khaslana ? (on ? (index === gauge.lit - 1 ? "#F2C75C" : "#C2252F") : "#2A1015") : (on ? "#8F7BE0" : (index === gauge.lit ? "transparent" : "#2C2840")))
                    border.width: Form.reaver && index === gauge.lit ? 1 : 0
                    border.color: "#5C5478"
                    transform: Matrix4x4 {
                        matrix: Form.reaver ? Qt.matrix4x4(1, -0.36, 0, 3, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) : Qt.matrix4x4()
                    }
                }
            }
        }
    }

    // Previous, play/pause and next for the active player
    component Transport: Row {
        property int iconSize: 22
        spacing: 18

        Repeater {
            model: ["skip_previous", ov.player?.playbackState === MprisPlaybackState.Playing ? "pause" : "play_arrow", "skip_next"]

            DIcon {
                required property string modelData
                required property int index
                readonly property bool able: index === 0 ? !!(ov.player?.canGoPrevious || ov.player?.canSeek) : index === 2 ? !!ov.player?.canGoNext : !!ov.player?.canTogglePlaying
                name: modelData
                size: parent.iconSize
                color: able ? ov.tint : Theme.withAlpha(ov.mut, 0.4)

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    enabled: parent.able
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (index === 0)
                            MprisController.previousOrRewind();
                        else if (index === 2)
                            MprisController.next();
                        else
                            ov.player?.togglePlaying();
                    }
                }
            }
        }
    }

    // A card in this form's slot and shape
    component Slot: DashCard {
        property string slot: ""
        readonly property var r: ov.slots[slot] ?? [0, 0, 0, 0]
        x: r[0]
        y: r[1]
        width: r[2]
        height: r[3]
        bare: Form.khaslana
        poly: Form.reaver ? ov.shards[slot] : null
    }

    // ── frames, behind the cards ──

    Loader {
        z: -1
        sourceComponent: Form.khaslana ? mosaic : (Form.reaver ? shatter : temple)
    }

    Component {
        id: mosaic

        Item {
            width: 1400
            height: 688

            // Gold in the seams between the obsidian blocks
            Shape {
                width: 1400
                height: 538
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: -1
                    fillGradient: LinearGradient {
                        x1: 0
                        y1: 0
                        x2: 1400
                        y2: 538
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
                    PathSvg {
                        path: "M0 0H1400V538H0Z"
                    }
                }
            }

            Repeater {
                model: Object.keys(ov.slots)

                Rectangle {
                    required property string modelData
                    readonly property var r: ov.slots[modelData]
                    x: r[0]
                    y: r[1]
                    width: r[2]
                    height: r[3]
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: modelData === "clock" || modelData === "messages" ? "#3A0A12" : "#0B080B"
                        }
                        GradientStop {
                            position: 0.7
                            color: "#0B080B"
                        }
                    }
                }
            }

            // The red corner blocks of the hero plate
            Item {
                x: ov.slots.clock[0] + ov.slots.clock[2] - 46
                y: ov.slots.clock[1] + ov.slots.clock[3] - 46
                width: 46
                height: 46

                Rectangle {
                    y: 32
                    width: 46
                    height: 14
                    color: "#8E1424"
                }
                Rectangle {
                    x: 32
                    width: 14
                    height: 46
                    color: "#C2252F"
                }
                Rectangle {
                    x: 14
                    y: 14
                    width: 18
                    height: 18
                    color: "#3A0A12"
                }
            }

            // Golden blood over the blocks, under the text
            CfCracks {
                width: 1400
                height: 538
                kind: "gold"
            }

            // The Black Tide spilling off the bottom edge
            CfTide {
                x: 6
                y: 538
                width: 1388
                height: 150
                edge: "top"
                seed: 3
                base: 0.22
                liquid: 150
                blocks: 90
                blockMax: 56
                cubes: 34
                cubeDepth: 150
            }
        }
    }

    Component {
        id: shatter

        CfCracks {
            width: 1400
            height: 814
            kind: "violet"
        }
    }

    Component {
        id: temple

        Item {
            width: 1160
            height: 716

            // Pediment with the hour's name
            Shape {
                width: 1160
                height: 96
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: ov.rim
                    strokeWidth: 1
                    fillColor: ov.paper
                    PathSvg {
                        path: "M580 0L1160 96H0Z"
                    }
                }
            }

            CfSigil {
                x: 568
                y: 30
                size: 24
                lit: (ov.hour % 12) || 12
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 58
                text: Form.dawnPeriod(ov.hour).toUpperCase()
                font.family: "Marcellus"
                font.pixelSize: 22
                font.letterSpacing: 7.5
                color: ov.figure
            }

            // Architrave: a Greek-key band and the recurrence count
            Rectangle {
                y: 96
                width: 1160
                height: 52
                color: ov.paper
                border.width: 1
                border.color: ov.rim

                Shape {
                    x: 16
                    y: 6
                    width: 1128
                    height: 12
                    opacity: 0.7
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeWidth: -1
                        fillColor: ov.gilt
                        PathSvg {
                            path: {
                                let d = "M0 0h1128v1h-1128zM0 11h1128v1h-1128z";
                                for (let x = 5; x < 1128; x += 12)
                                    d += `M${x} 0h1v12h-1z`;
                                return d;
                            }
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 24
                    spacing: 10

                    Text {
                        text: "Eternal Recurrence"
                        font.family: Form.numerals
                        font.pixelSize: 14
                        color: ov.mut
                    }
                    Text {
                        text: Form.cycleText
                        font.family: Form.numerals
                        font.pixelSize: 14
                        color: ov.mut
                    }
                }
            }

            // The columns' floor
            Rectangle {
                y: 148
                width: 1160
                height: 479
                color: ov.floor
                border.width: 1
                border.color: ov.rim
            }

            // Stylobate and steps
            Rectangle {
                y: 627
                width: 1160
                height: 69
                color: ov.paper
                border.width: 1
                border.color: ov.rim
            }
            Rectangle {
                x: -10
                y: 696
                width: 1180
                height: 10
                color: ov.paper
                border.width: 1
                border.color: ov.rim
            }
            Rectangle {
                x: -20
                y: 706
                width: 1200
                height: 10
                color: ov.paper
                border.width: 1
                border.color: ov.rim
            }
        }
    }

    // ── the ten cards ──

    // Clock: Khaslana's hero plate, the Reaver's "cycle", Phainon's clock. Opens the full clock.
    Slot {
        slot: "clock"
        clickable: true
        glyph: "time"
        label: Form.khaslana ? "Act IV · Recurrence " + Form.cycleText : (Form.reaver ? "the cycle" : "Time · Clock")
        capColor: Form.khaslana ? "#E2434E" : (Form.reaver ? "#B9A8FF" : ov.capInk)
        capCentered: Form.reaver
        onClicked: ov.host.view = "time"

        Column {
            x: Form.reaver ? Math.round((parent.width - width) / 2) : 0
            spacing: Form.khaslana ? 4 : 2

            Figure {
                x: Form.reaver ? Math.round((parent.width - width) / 2) : 0
                text: ov.time
                px: Form.khaslana ? 140 : (Form.reaver ? 92 : 60)
            }

            Label {
                visible: Form.khaslana
                text: Form.dawnPeriod(ov.hour).toUpperCase()
                font.family: "Cinzel"
                font.pixelSize: 30
                font.weight: Font.Bold
                font.letterSpacing: 4.8
            }

            Label {
                visible: Form.reaver
                x: Form.reaver ? Math.round((parent.width - width) / 2) : 0
                text: "cycle " + Form.cycleText
                font.pixelSize: 20
                color: "#CFC6A8"
            }

            Label {
                x: Form.reaver ? Math.round((parent.width - width) / 2) : 0
                text: ov.tx(ov.now.toLocaleDateString(I18n.locale(), "dddd, d MMMM"))
                color: ov.mut
            }
        }
    }

    DashCalendar {
        readonly property var r: ov.slots.calendar
        x: r[0]
        y: r[1]
        width: r[2]
        height: r[3]
        bare: Form.khaslana
        poly: Form.reaver ? ov.shards.calendar : null
        glyph: "time"
        label: Form.khaslana ? "Programme of " + ov.now.toLocaleDateString(Qt.locale("en_US"), "MMMM") : (Form.reaver ? "calendar · " + ov.now.toLocaleDateString(Qt.locale("en_US"), "MMMM").toLowerCase() : "Time · Calendar")
        live: ov.host.shown
        now: ov.now
    }

    // Weather, with sunrise and sunset. Opens the forecast.
    Slot {
        id: weatherCard
        slot: "weather"
        clickable: true
        glyph: "sky"
        label: Form.phainon ? "Sky · Weather" : "Sky"
        onClicked: ov.host.view = "weather"

        readonly property string temp: ov.weather.available ? WeatherService.currentTempText(false) : "--"
        readonly property string sky: ov.weather.available ? WeatherService.getWeatherCondition(ov.weather.wCode) : "No weather data"

        Row {
            id: skyRow
            spacing: 12

            DIcon {
                visible: Form.khaslana
                anchors.verticalCenter: parent.verticalCenter
                name: ov.weather.available ? WeatherService.getWeatherIcon(ov.weather.wCode) : "cloud_off"
                size: 30
                color: "#E0B04A"
            }

            Figure {
                anchors.verticalCenter: parent.verticalCenter
                text: weatherCard.temp
                px: Form.khaslana ? 44 : (Form.reaver ? 60 : 52)
            }

            Column {
                visible: !Form.khaslana
                anchors.verticalCenter: parent.verticalCenter

                Label {
                    text: ov.tx(weatherCard.sky)
                    color: Form.reaver ? ov.ink : ov.mut
                }
                Label {
                    visible: Form.reaver
                    text: "rose " + (ov.weather.sunrise ?? "") + " · sets " + (ov.weather.sunset ?? "")
                    color: ov.mut
                }
            }
        }

        Label {
            visible: Form.khaslana
            anchors.top: skyRow.bottom
            anchors.topMargin: 2
            width: parent.width
            text: weatherCard.sky.toLowerCase() + " · rises " + (ov.weather.sunrise ?? "") + " · sets " + (ov.weather.sunset ?? "")
            font.pixelSize: 13
            color: ov.mut
        }

        // Phainon: the sun's path today, sunrise on the left, sunset on the right
        Item {
            id: sunPath
            visible: Form.phainon
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 96

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: ov.gilt
                    strokeWidth: 1
                    strokeStyle: ShapePath.DashLine
                    dashPattern: [3, 4]
                    PathSvg {
                        path: `M10 74C${sunPath.width * 0.2} 6 ${sunPath.width * 0.8} 6 ${sunPath.width - 10} 74`
                    }
                }
                ShapePath {
                    strokeColor: ov.rim
                    strokeWidth: 1
                    fillColor: "transparent"
                    PathSvg {
                        path: `M0 74H${sunPath.width}`
                    }
                }
            }

            Rectangle {
                readonly property real t: ov.host.dayFraction
                // Near enough to the curve for a 14 px sun
                x: 10 + (sunPath.width - 20) * t - 7
                y: 74 - 51 * 4 * t * (1 - t) - 7
                width: 14
                height: 14
                radius: 7
                color: "#F1DA4F"
                border.width: 1
                border.color: ov.gilt
            }

            Label {
                y: 78
                text: "rises " + (ov.weather.sunrise ?? "")
                font.pixelSize: 13
                color: ov.mut
            }
            Label {
                anchors.right: parent.right
                y: 78
                text: "sets " + (ov.weather.sunset ?? "")
                font.pixelSize: 13
                color: ov.mut
            }
        }
    }

    // CPU, heat and memory. Opens the island's system monitor.
    Slot {
        slot: "system"
        clickable: true
        glyph: "law"
        label: Form.reaver ? "system" : "Law · System"
        onClicked: {
            const chrome = Form.chromes.find(c => c.screen === ov.host.screen) ?? Form.chromes[0];
            ov.host.close();
            chrome?.triggerProcesses("open");
        }

        Column {
            width: parent.width
            spacing: Form.reaver ? 8 : 6

            Repeater {
                model: [["CPU", DgopService.cpuUsage || 0, "%", 90], ["Heat", DgopService.cpuTemperature || 0, "°", 85], ["Mem", DgopService.memoryUsage || 0, "%", 90]]

                Row {
                    required property var modelData
                    readonly property bool alarm: modelData[1] > modelData[3]
                    readonly property int head: Form.khaslana ? 40 : 50
                    width: parent.width
                    spacing: 8

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.head
                        text: ov.tx(parent.modelData[0])
                    }
                    Gauge {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - parent.head - 44 - 16
                        value: parent.modelData[1] / 100
                        alarm: parent.alarm
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 44
                        horizontalAlignment: Text.AlignRight
                        text: Math.round(parent.modelData[1]) + parent.modelData[2]
                        color: parent.alarm ? Theme.error : ov.ink
                    }
                }
            }
        }
    }

    // Down and up now. Opens the network view.
    Slot {
        slot: "network"
        clickable: true
        glyph: "passage"
        label: Form.reaver ? "passage" : "Passage · Network"
        onClicked: ov.host.view = "network"

        Row {
            spacing: 16

            DIcon {
                visible: Form.khaslana
                anchors.verticalCenter: parent.verticalCenter
                name: "swap_vert"
                size: 24
                color: "#E0B04A"
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: ov.tx("↓ " + Format.formatRate(DgopService.networkRxRate || 0))
                font.pixelSize: Form.reaver ? 20 : 14
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: ov.tx((Form.reaver ? "· " : "") + "↑ " + Format.formatRate(DgopService.networkTxRate || 0))
                font.pixelSize: Form.reaver ? 20 : 14
                color: ov.mut
            }
        }

        DSparkline {
            visible: Form.phainon
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: 110
            height: 26
            values: DgopService.networkHistory.rx
            historyLength: 60
            lineColor: ov.figure
            lineWidth: 1
            fillOpacity: 0
            curved: false
        }
    }

    // The latest few messages. Opens the messages view.
    Slot {
        slot: "messages"
        clickable: true
        glyph: "romance"
        label: Form.phainon ? "Romance · Messages" : (Form.reaver ? "heralds" : "Heralds")
        onClicked: ov.host.view = "notifications"

        Label {
            visible: ov.notes.length > 0
            anchors.right: parent.right
            y: -24
            text: ov.tx("Clear all")
            font.pixelSize: 13
            color: ov.mut

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: NotificationService.clearAllNotifications()
            }
        }

        Label {
            visible: ov.notes.length === 0
            anchors.centerIn: parent
            text: ov.tx("All caught up")
            color: ov.mut
        }

        Column {
            id: noteList
            width: parent.width
            height: parent.height
            clip: true
            readonly property int rowHeight: Form.phainon ? 42 : 30
            readonly property int fits: Math.max(1, Math.floor(height / rowHeight))

            Repeater {
                model: ov.notes

                Item {
                    id: note
                    required property var modelData
                    required property int index
                    visible: index < noteList.fits
                    width: noteList.width
                    height: noteList.rowHeight

                    Rectangle {
                        width: parent.width
                        height: 1
                        y: Form.phainon ? 0 : parent.height - 1
                        color: Form.khaslana ? "#3A1A1E" : (Form.reaver ? "#2C2840" : ov.track)
                    }

                    Rectangle {
                        visible: Form.phainon
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 28
                        radius: 8
                        color: ov.track

                        Text {
                            anchors.centerIn: parent
                            text: (note.modelData.appName || "?").charAt(0).toUpperCase()
                            font.family: "Marcellus"
                            font.pixelSize: 13
                            color: ov.figure
                        }
                    }

                    CfGlyph {
                        visible: !Form.phainon
                        anchors.verticalCenter: parent.verticalCenter
                        name: Form.khaslana ? "worldbearing" : "romance"
                        size: 17
                        strokeWidth: 1.6
                        color: Form.khaslana ? "#E2434E" : "#B9A8FF"
                    }

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        x: Form.phainon ? 36 : 27
                        width: parent.width - x - noteAge.width - 8
                        text: ov.tx((note.modelData.appName || "") + " · " + (note.modelData.latestNotification?.summary ?? "").replace(/\s+/g, " "))
                    }

                    Label {
                        id: noteAge
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: note.modelData.latestNotification?.timeStr ?? ""
                        font.pixelSize: 12
                        color: ov.mut
                    }
                }
            }
        }
    }

    // Now playing, with controls. Opens the player.
    Slot {
        slot: "music"
        clickable: true
        glyph: "ocean"
        label: Form.khaslana ? "Ocean · The music" : (Form.reaver ? "music" : "Ocean · Now playing")
        onClicked: ov.host.view = "music"

        Label {
            visible: !ov.player
            text: Form.reaver ? "nothing." : "Nothing playing"
            color: ov.mut
        }

        Column {
            visible: !!ov.player
            width: parent.width
            spacing: 2

            Label {
                width: parent.width
                text: ov.tx((ov.player?.trackTitle || ov.player?.identity || "") + (Form.khaslana && ov.player?.trackArtist ? " · " + ov.player.trackArtist : ""))
                font.family: Form.phainon ? "Marcellus" : ov.body
                font.pixelSize: Form.phainon ? 17 : 14
                color: Form.khaslana ? "#F5D27A" : ov.ink
            }
            Label {
                visible: !Form.khaslana
                width: parent.width
                text: ov.tx(ov.player?.trackArtist || "")
                font.pixelSize: 13
                color: ov.mut
            }

            Rectangle {
                visible: Form.phainon
                width: parent.width
                height: 3
                color: ov.track

                Rectangle {
                    width: ov.player && ov.player.length > 0 ? parent.width * Math.min(1, ov.player.position / ov.player.length) : 0
                    height: parent.height
                    color: ov.figure
                }
            }

            Item {
                width: 1
                height: 4
            }

            Transport {
                x: Form.phainon ? Math.round((parent.width - width) / 2) : 0
            }
        }
    }

    // Screen time today. Opens the wellbeing view.
    Slot {
        id: screenCard
        slot: "screen"
        clickable: true
        glyph: "time"
        label: Form.phainon ? "Time · Wellbeing" : (Form.reaver ? "screen time" : "Screen time")
        onClicked: ov.host.view = "wellbeing"

        readonly property bool over: SettingsData.wellbeingDailyLimit > 0 && WellbeingService.today.active >= SettingsData.wellbeingDailyLimit * 60

        Row {
            spacing: 10

            Figure {
                text: WellbeingService.formatDuration(WellbeingService.today.active)
                px: Form.khaslana ? 30 : (Form.reaver ? 40 : 36)
                color: screenCard.over ? Theme.error : ov.figure
            }
            Label {
                visible: Form.phainon
                anchors.bottom: parent.bottom
                text: SettingsData.wellbeingDailyLimit > 0 ? "of " + WellbeingService.formatLimit(SettingsData.wellbeingDailyLimit) : "screen time today"
                color: ov.mut
            }
        }
    }

    // The Flame-Chase: the twelve Titans' Coreflames, on the stylobate for Phainon.
    Slot {
        slot: "flame"
        bare: Form.khaslana || Form.phainon
        glyph: "worldbearing"
        label: Form.phainon ? "" : (Form.reaver ? "coreflames · " + Coreflames.count + " / 12" : "Flame-Chase · Coreflames taken " + Coreflames.count + " / 12")

        Row {
            y: Form.phainon ? Math.round((parent.height - height) / 2) : 0
            spacing: 18

            Label {
                visible: Form.phainon
                anchors.verticalCenter: parent.verticalCenter
                text: "FLAME-CHASE\n" + Coreflames.count + " / 12"
                maximumLineCount: 2
                lineHeight: 1.1
                font.family: "Chakra Petch"
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.letterSpacing: 1.8
                color: ov.capInk
            }

            CfTitans {
                anchors.verticalCenter: parent.verticalCenter
                glyphSize: Form.phainon ? 20 : (Form.khaslana ? 30 : 26)
            }
        }
    }

    // Wallpapers
    Slot {
        id: walls
        slot: "walls"
        bare: Form.khaslana || Form.phainon
        clickable: Form.reaver
        onClicked: ov.host.view = "wallpaper"

        readonly property string file: SessionData.wallpaperPath.substring(SessionData.wallpaperPath.lastIndexOf("/") + 1)

        // Khaslana's red button, Phainon's pill
        Rectangle {
            visible: !Form.reaver
            anchors.centerIn: parent
            width: wallsRow.implicitWidth + 32
            height: Form.phainon ? 34 : 38
            radius: Form.phainon ? 17 : 0
            color: wallsMouse.containsMouse ? (Form.phainon ? ov.card : "#A01A2A") : (Form.phainon ? ov.card : "#8E1424")
            border.width: 1
            border.color: Form.phainon ? ov.rim : "#F2C75C"

            Row {
                id: wallsRow
                anchors.centerIn: parent
                spacing: 8

                DIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "image"
                    size: 16
                    color: Form.phainon ? ov.figure : "#F5D27A"
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Form.phainon ? "Worldbearing · Wallpapers" : "SCENERY"
                    font.family: Form.phainon ? Form.numerals : "Cinzel"
                    font.pixelSize: 13
                    font.weight: Form.phainon ? Font.Normal : Font.DemiBold
                    font.letterSpacing: Form.phainon ? 0 : 1.8
                    color: Form.phainon ? ov.figure : "#F5D27A"
                }
            }

            MouseArea {
                id: wallsMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ov.host.view = "wallpaper"
            }
        }

        // The Reaver's line: the current file and a way to change it
        Row {
            visible: Form.reaver
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            spacing: 10

            DIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "image"
                size: 22
                color: "#B9A8FF"
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 32 - changeLabel.width - 10
                text: "scenery · " + walls.file.toLowerCase()
            }
            Label {
                id: changeLabel
                anchors.verticalCenter: parent.verticalCenter
                text: "change ›"
                color: "#CFC6A8"
            }
        }
    }
}
