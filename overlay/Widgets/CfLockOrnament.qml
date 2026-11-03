import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.Common
import qs.Services
import qs.DCommon.Widgets as DW

// The Coreflame lock screen: one composition per form, laid around DMS's own password box
// (centre of the screen) and notifications (just below it), which stay untouched.
//   Phainon      the sky stays open: the sun on its path at the hour, the time in a navy
//                medallion inside a laurel wreath, the quote on a ribbon.
//   Khaslana     a stage open on the wallpaper: valance, two drapes, a playbill with the time,
//                the Black Tide pooled on the stage floor, footlights for the Flame-Chase.
//   Flame Reaver shards on his crack: the cycle, the quote.
// Solid shapes only, no blur; nothing animates; the clock updates once a minute.
Item {
    id: root

    property string screenName: ""
    property string backgroundKey: ""

    // "h" without an am/pm marker in the format prints 24-hour time, so format with it and drop it.
    readonly property string time: (clock.date?.toLocaleTimeString(Qt.locale(), SettingsData.use24HourClock ? "HH:mm" : "h:mm ap") ?? "").replace(/\s*[ap]\.?m\.?$/i, "")
    readonly property string day: clock.date?.toLocaleDateString(Qt.locale(), "dddd · d MMMM") ?? ""
    readonly property string period: Form.dawnPeriod(clock.date?.getHours() ?? 0)
    // A 1920 × 1080 composition scaled to the screen, centred
    readonly property real s: Math.min(width / 1920, height / 1080)
    readonly property real ox: (width - 1920 * s) / 2
    readonly property real oy: (height - 1080 * s) / 2

    readonly property string battery: BatteryService.batteryAvailable ? Math.round(BatteryService.batteryLevel) + "% · " + (BatteryService.isPluggedIn ? "plugged in" : "on battery") : ""
    readonly property string network: NetworkService.networkStatus === "ethernet" ? "Ethernet" : (NetworkService.wifiEnabled ? (NetworkService.currentWifiSSID || "Wi-Fi on") : "Wi-Fi off")

    visible: Form.active

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Loader {
        anchors.fill: parent
        active: root.visible
        sourceComponent: Form.khaslana ? khLock : (Form.reaver ? rvLock : phLock)
    }

    // The scaled composition box, for each form's centre pieces
    component Stage: Item {
        x: root.ox
        y: root.oy
        width: 1920
        height: 1080
        scale: root.s
        transformOrigin: Item.TopLeft
    }

    // Phainon's status chip
    component Chip: Rectangle {
        id: chip
        property string icon
        property string label
        visible: label !== ""
        width: chipRow.implicitWidth + 28
        height: 30
        radius: 15
        color: "#F7F3E8"
        border.width: 1
        border.color: "#C8B27E"

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 8

            DW.DIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: chip.icon
                size: 16
                color: "#334786"
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                font.family: Form.numerals
                font.pixelSize: 15
                color: "#334786"
            }
        }
    }

    // Khaslana's drape: dark red folds cut to a gathered edge, hemmed in gold along it
    component Drape: Shape {
        id: drape
        property bool leftSide: true
        readonly property var outline: leftSide ? [Qt.point(0, 0), Qt.point(width, 0), Qt.point(width * 0.7, height / 2), Qt.point(width, height), Qt.point(0, height), Qt.point(0, 0)] : [Qt.point(0, 0), Qt.point(width, 0), Qt.point(width, height), Qt.point(0, height), Qt.point(width * 0.3, height / 2), Qt.point(0, 0)]
        width: 150
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            fillGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: 40
                y2: 0
                spread: ShapeGradient.RepeatSpread
                GradientStop {
                    position: 0
                    color: "#3A0A12"
                }
                GradientStop {
                    position: 0.449
                    color: "#3A0A12"
                }
                GradientStop {
                    position: 0.45
                    color: "#5A0E1C"
                }
                GradientStop {
                    position: 0.749
                    color: "#5A0E1C"
                }
                GradientStop {
                    position: 0.75
                    color: "#3A0A12"
                }
                GradientStop {
                    position: 1
                    color: "#3A0A12"
                }
            }
            PathPolyline {
                path: drape.outline
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: "#E0B04A"
            strokeWidth: 2
            PathPolyline {
                path: drape.leftSide ? [Qt.point(drape.width - 1, 0), Qt.point(drape.width * 0.7 - 1, drape.height / 2), Qt.point(drape.width - 1, drape.height)] : [Qt.point(1, 0), Qt.point(drape.width * 0.3 + 1, drape.height / 2), Qt.point(1, drape.height)]
            }
        }
    }

    // The Flame Reaver's shard: a violet edge and a dark face cut to the same outline
    component Shard: Item {
        id: shard
        property var outline: []
        default property alias content: face.data

        function at(i) {
            const w = width - 2 * i, h = height - 2 * i;
            const pts = outline.map(p => Qt.point(i + p[0] * w, i + p[1] * h));
            pts.push(pts[0]);
            return pts;
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: -1
                fillGradient: LinearGradient {
                    x1: 0
                    y1: 0
                    x2: shard.width
                    y2: shard.height
                    GradientStop {
                        position: 0
                        color: "#B9A8FF"
                    }
                    GradientStop {
                        position: 0.5
                        color: "#5C5478"
                    }
                    GradientStop {
                        position: 1
                        color: "#8F7BE0"
                    }
                }
                PathPolyline {
                    path: shard.at(0)
                }
            }

            ShapePath {
                strokeWidth: -1
                fillColor: Qt.rgba(13 / 255, 11 / 255, 20 / 255, 0.95)
                PathPolyline {
                    path: shard.at(2)
                }
            }
        }

        Item {
            id: face
            anchors.fill: parent
        }
    }

    // One laurel branch (32 × 32 units), stroked in gold
    component Laurel: Shape {
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: "#E2B84A"
            // The stroke does not scale with the path: 0.35 units of the 32-unit branch
            strokeWidth: 5.5
            scale: Qt.size(508 / 32, 508 / 32)
            PathSvg {
                path: "M16 29C9 25 6 18 7 9M9 12c-3 0-4-2-4-4 3 0 4 2 4 4zM8 17c-3 1-5-1-5-3 3-1 5 1 5 3zM9.5 21.5c-2 2-5 1-6-1 3-1 5 0 6 1zM12.5 25c-1 2.5-4 3-5.5 1.5 2-2 4-2 5.5-1.5zM8 12c0-3 1.5-4.5 3.5-4.5 0 2.5-1.5 4.5-3.5 4.5zM8.5 17c.5-3 2.5-4 4.5-3.5-.5 2.5-2.5 4-4.5 3.5z"
            }
        }
    }

    // ── Phainon ──
    Component {
        id: phLock

        Item {
            Stage {
                // The sun's path across the sky, and the sun on it at the hour (06:00 to 18:00)
                Shape {
                    id: arc
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    readonly property real t: {
                        const d = clock.date;
                        const h = d ? d.getHours() + d.getMinutes() / 60 : 12;
                        return Math.max(0, Math.min(1, (h - 6) / 12));
                    }
                    readonly property point sun: {
                        const u = 1 - t;
                        return Qt.point(u * u * u * 40 + 3 * u * u * t * 300 + 3 * u * t * t * 1620 + t * t * t * 1880, u * u * u * 1000 - 3 * u * u * t * 60 - 3 * u * t * t * 60 + t * t * t * 1000);
                    }

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: Qt.rgba(251 / 255, 249 / 255, 243 / 255, 0.75)
                        strokeWidth: 2
                        strokeStyle: ShapePath.DashLine
                        dashPattern: [1.5, 4.5]
                        PathSvg {
                            path: "M40 1000C300 -60 1620 -60 1880 1000"
                        }
                    }
                }

                Rectangle {
                    x: arc.sun.x - 36
                    y: arc.sun.y - 36
                    width: 72
                    height: 72
                    radius: 36
                    color: "transparent"
                    border.width: 2
                    border.color: Qt.rgba(241 / 255, 218 / 255, 79 / 255, 0.6)

                    Rectangle {
                        anchors.centerIn: parent
                        width: 44
                        height: 44
                        radius: 22
                        color: "#F1DA4F"
                        border.width: 2
                        border.color: "#A87A22"
                    }
                }

                // The laurel wreath around the medallion: one branch and its mirror
                Laurel {
                    x: 76
                    y: 186
                    width: 508
                    height: 508
                }

                Laurel {
                    x: 76
                    y: 186
                    width: 508
                    height: 508
                    transform: Scale {
                        origin.x: 254
                        xScale: -1
                    }
                }

                // The medallion: navy disc, a lighter band and a gold rim
                Rectangle {
                    x: 330 - 203
                    y: 440 - 203
                    width: 406
                    height: 406
                    radius: 203
                    color: "#E2B84A"

                    Rectangle {
                        anchors.centerIn: parent
                        width: 395
                        height: 395
                        radius: 197.5
                        color: "#2B3A78"

                        Rectangle {
                            anchors.centerIn: parent
                            width: 368
                            height: 368
                            radius: 184
                            color: "#1F2A5C"
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.period
                            font.family: "Cormorant Garamond"
                            font.italic: true
                            font.pixelSize: 21
                            color: "#D9DEF5"
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.time
                            font.family: Form.numerals
                            font.pixelSize: 132
                            color: "#FBF2D8"
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.min(implicitWidth, 320)
                            fontSizeMode: Text.HorizontalFit
                            minimumPixelSize: 12
                            horizontalAlignment: Text.AlignHCenter
                            text: root.day.toUpperCase()
                            font.family: "Marcellus"
                            font.pixelSize: 18
                            font.letterSpacing: 2.5
                            color: "#F1DA4F"
                        }
                    }
                }

                // The quote on a ribbon
                Item {
                    x: 80
                    y: 712
                    width: 500
                    height: ribbonCol.implicitHeight + 24

                    Shape {
                        id: ribbon
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            strokeWidth: -1
                            fillColor: "#F7F3E8"
                            PathPolyline {
                                path: {
                                    const w = ribbon.width, h = ribbon.height;
                                    return [Qt.point(0, 0), Qt.point(w, 0), Qt.point(w * 0.94, h / 2), Qt.point(w, h), Qt.point(0, h), Qt.point(w * 0.06, h / 2), Qt.point(0, 0)];
                                }
                            }
                        }
                    }

                    Column {
                        id: ribbonCol
                        x: 34
                        y: 12
                        width: parent.width - 68
                        spacing: 4

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            text: "“" + Form.quote + "”"
                            font.family: "Cormorant Garamond"
                            font.italic: true
                            font.pixelSize: 23
                            lineHeight: 1.1
                            color: "#1E2752"
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: ("Phainon · " + Form.epithet).toUpperCase()
                            font.family: "Chakra Petch"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            font.letterSpacing: 2
                            color: "#8A6418"
                        }
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 28
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 22
                spacing: 10

                Chip {
                    icon: BatteryService.isPluggedIn ? "battery_charging_full" : "battery_5_bar"
                    label: root.battery
                }

                Chip {
                    icon: NetworkService.wifiEnabled ? "wifi" : "wifi_off"
                    label: root.network
                }

                Chip {
                    icon: "local_fire_department"
                    label: "Recurrence " + Form.cycleText
                }
            }
        }
    }

    // ── Khaslana ──
    Component {
        id: khLock

        Item {
            id: stage

            // The Black Tide pooled on the stage floor
            CfTide {
                x: 150
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 40
                width: parent.width - 300
                height: 300
                edge: "bottom"
                seed: 31
                base: 0.34
                liquid: 200
                cubes: 30
                cubeDepth: 300
            }

            Drape {
                height: stage.height
                leftSide: true
            }

            Drape {
                anchors.right: parent.right
                height: stage.height
                leftSide: false
            }

            // The valance: a red pelmet with scallops hanging from its gold hem
            Rectangle {
                width: parent.width
                height: 74
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: "#6E1020"
                    }
                    GradientStop {
                        position: 1
                        color: "#4A0B16"
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 2
                    color: "#E0B04A"
                }
            }

            Item {
                y: 74
                width: parent.width
                height: 26
                clip: true

                Row {
                    x: 2
                    spacing: 4

                    Repeater {
                        model: Math.ceil(stage.width / 56) + 1

                        Rectangle {
                            y: -26
                            width: 52
                            height: 52
                            radius: 26
                            color: "#4A0B16"
                        }
                    }
                }
            }

            // The playbill
            Stage {
                Item {
                    x: 1920 - 190 - 470
                    y: 170
                    width: 470
                    height: bill.implicitHeight + 50

                    Rectangle {
                        x: 8
                        y: 8
                        width: parent.width
                        height: parent.height
                        color: "#8E1424"
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "#0B080B"
                        border.width: 2
                        border.color: "#E0B04A"
                        clip: true

                        CfCracks {
                            anchors.fill: parent
                            kind: "gold"
                            trunk: 0.5
                            branch: 0.5
                            opacity: 0.18
                        }
                    }

                    Column {
                        id: bill
                        x: 30
                        y: 24
                        width: parent.width - 60
                        spacing: 4

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: ("Tonight · " + root.period).toUpperCase()
                            font.family: "Cinzel"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            font.letterSpacing: 4.8
                            color: "#E2434E"
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: ("Khaslana · " + Form.epithet).toUpperCase()
                            font.family: "Cinzel"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            font.letterSpacing: 2.6
                            color: "#E0B04A"
                        }

                        Item {
                            width: parent.width
                            height: billTime.implicitHeight + 12

                            // The red offset behind the time
                            Text {
                                x: billTime.x + 4
                                y: billTime.y
                                text: root.time
                                font: billTime.font
                                color: "#8E1424"
                            }

                            Text {
                                id: billTime
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 6
                                text: root.time
                                font.family: Form.numerals
                                font.pixelSize: 140
                                color: "#F5D27A"
                            }
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: root.day
                            font.family: "Chakra Petch"
                            font.pixelSize: 19
                            color: "#C9B89E"
                        }

                        Item {
                            width: 1
                            height: 10
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            text: "“" + Form.quote + "”"
                            font.family: "Cormorant Garamond"
                            font.italic: true
                            font.pixelSize: 25
                            lineHeight: 1.15
                            color: "#F3E6CC"
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: "KHASLANA · RECURRENCE " + Form.cycleText
                            font.family: "Cinzel"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            font.letterSpacing: 2.6
                            color: "#E2434E"
                        }
                    }
                }
            }

            // Status on a black plate, stage left
            Rectangle {
                x: 180
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 56
                width: khStatus.implicitWidth + 28
                height: khStatus.implicitHeight + 10
                color: "#0B080B"
                border.width: 1
                border.color: "#8A5A2B"

                Row {
                    id: khStatus
                    anchors.centerIn: parent
                    spacing: 16

                    Text {
                        visible: root.battery !== ""
                        text: root.battery
                        font.family: "Chakra Petch"
                        font.pixelSize: 15
                        color: "#F3E6CC"
                    }

                    Text {
                        text: root.network
                        font.family: "Chakra Petch"
                        font.pixelSize: 15
                        color: "#C9B89E"
                    }
                }
            }

            // Footlights: one lit for every Coreflame of the Flame-Chase gathered
            Rectangle {
                x: 150
                anchors.bottom: parent.bottom
                width: parent.width - 300
                height: 40
                color: "#0B080B"

                Rectangle {
                    width: parent.width
                    height: 2
                    color: "#E0B04A"
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 10

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        rightPadding: 2
                        text: "FLAME-CHASE"
                        font.family: "Cinzel"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        font.letterSpacing: 2.4
                        color: "#E0B04A"
                    }

                    Repeater {
                        model: 12

                        Rectangle {
                            required property int index
                            readonly property bool lit: index < Coreflames.count
                            anchors.verticalCenter: parent.verticalCenter
                            width: 60
                            height: 14
                            color: lit ? "#C2252F" : "#3A0A12"
                            border.width: 1
                            border.color: lit ? "#F2C75C" : "#8E1424"
                        }
                    }
                }
            }
        }
    }

    // ── Flame Reaver ──
    Component {
        id: rvLock

        Item {
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(6 / 255, 5 / 255, 10 / 255, 0.45)
            }

            CfCracks {
                anchors.fill: parent
                kind: "violet"
                opacity: 0.85
            }

            Stage {
                Shard {
                    x: 110
                    y: 170
                    width: 700
                    height: 310
                    outline: [[0, 0.1], [0.95, 0], [1, 0.82], [0.06, 1]]

                    Column {
                        x: 50
                        y: 38
                        spacing: 4

                        Text {
                            text: "// cycle"
                            font.family: "Chakra Petch"
                            font.pixelSize: 20
                            color: "#B9A8FF"
                        }

                        // Two shifted copies make the glitch, drawn once with the text
                        Item {
                            width: cyc.implicitWidth
                            height: cyc.implicitHeight

                            Text {
                                x: 2
                                text: cyc.text
                                font: cyc.font
                                color: Qt.rgba(143 / 255, 123 / 255, 224 / 255, 0.85)
                            }

                            Text {
                                x: -2
                                text: cyc.text
                                font: cyc.font
                                color: Qt.rgba(79 / 255, 209 / 255, 197 / 255, 0.55)
                            }

                            Text {
                                id: cyc
                                text: Form.cycleText
                                font.family: Form.numerals
                                font.italic: true
                                font.pixelSize: 108
                                color: "#F2EEE0"
                            }
                        }

                        Row {
                            spacing: 10

                            Text {
                                anchors.baseline: rvDay.baseline
                                text: root.time
                                font.family: Form.numerals
                                font.italic: true
                                font.pixelSize: 30
                                color: "#E9E7F2"
                            }

                            Text {
                                id: rvDay
                                text: "· " + root.day.toLowerCase()
                                font.family: "Chakra Petch"
                                font.pixelSize: 24
                                color: "#E9E7F2"
                            }
                        }
                    }
                }

                Shard {
                    x: 150
                    y: 560
                    width: 640
                    height: rvQuote.implicitHeight + 70
                    outline: [[0.02, 0], [1, 0.12], [0.97, 1], [0, 0.86]]

                    Column {
                        id: rvQuote
                        x: 44
                        y: 28
                        width: parent.width - 88
                        spacing: 8

                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: "“" + Form.quote + "”"
                            font.family: "Cormorant Garamond"
                            font.italic: true
                            font.pixelSize: 25
                            lineHeight: 1.15
                            color: "#E9E7F2"
                        }

                        Text {
                            text: "// flame reaver · " + Form.epithet.toLowerCase()
                            font.family: "Chakra Petch"
                            font.pixelSize: 13
                            color: "#A8A4BC"
                        }
                    }
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 28
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 24
                width: rvStatus.implicitWidth + 28
                height: rvStatus.implicitHeight + 12
                color: Qt.rgba(13 / 255, 11 / 255, 20 / 255, 0.95)
                border.width: 1
                border.color: "#5C5478"

                Row {
                    id: rvStatus
                    anchors.centerIn: parent
                    spacing: 14

                    Repeater {
                        model: [[BatteryService.isPluggedIn ? "battery_charging_full" : "battery_5_bar", root.battery], [NetworkService.wifiEnabled ? "wifi" : "wifi_off", root.network]]

                        Row {
                            id: stat
                            required property var modelData
                            visible: modelData[1] !== ""
                            spacing: 6

                            DW.DIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: stat.modelData[0]
                                size: 16
                                color: "#B9A8FF"
                            }

                            Text {
                                text: String(stat.modelData[1]).toLowerCase()
                                font.family: "Chakra Petch"
                                font.pixelSize: 15
                                color: "#E9E7F2"
                            }
                        }
                    }
                }
            }
        }
    }
}
