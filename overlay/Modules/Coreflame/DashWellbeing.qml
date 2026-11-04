import QtQuick
import QtQuick.Shapes
import QtQuick.Window
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.DDash.Wellbeing
import qs.Modules.ControlCenter.Widgets
import "../DDash/Wellbeing/Wellbeing.js" as Wellbeing

// "Time · Wellbeing": today and the daily limit, the week's screen time (stock DMS's chart in the
// form's bars) and the most-used apps with their limits.
//   Phainon: round lapis bars with today in gold, round steppers.
//   Khaslana: bars stacked from red blocks under a gold cap, today in gold blocks.
//   Flame Reaver: bars of skewed violet scratches, today an ember red.
DashSheet {
    id: well

    title: "Time · Wellbeing"
    glyph: "time"

    // [x, y, w, h] of the three cards in body coordinates
    readonly property var lay: ph ? ({
            today: [0, 0, 748, 76],
            week: [0, 88, 748, 200],
            apps: [0, 300, 748, 208]
        }) : kh ? ({
            today: [0, 0, bodyWidth, 86],
            week: [0, 91, spanW(2), 236],
            apps: [colX(2), 91, bodyWidth - colX(2), 236]
        }) : ({
            today: [0, 0, 780, 100],
            week: [0, 114, 360, 320],
            apps: [374, 114, 406, 320]
        })

    bodyHeight: Math.max(...Object.values(lay).map(r => r[1] + r[3]))
    blocks: kh ? ["today", "week", "apps"].map((k, i) => lay[k].concat([i === 0])) : []

    // What the stock wellbeing tab kept: the summary of past days, refreshed while on screen
    readonly property bool live: Window.window?.visible ?? false
    property var days: []
    readonly property date today: new Date()
    readonly property int firstDayOfWeek: SettingsData.firstDayOfWeek >= 7 || SettingsData.firstDayOfWeek < 0 ? Qt.locale().firstDayOfWeek : SettingsData.firstDayOfWeek
    readonly property date anchor: Wellbeing.addDays(today, chart.weekOffset * Wellbeing.weekLength)
    property string period: "day"
    readonly property var apps: Wellbeing.topApps(Wellbeing.periodDays(days, anchor, firstDayOfWeek, period, today), WellbeingMetrics.listedApps)
    readonly property real longest: apps.length > 0 ? apps[0].seconds : 0
    // The app whose limit is being set in its row
    property string editing: ""
    readonly property bool overToday: SettingsData.wellbeingDailyLimit > 0 && WellbeingService.today.active >= SettingsData.wellbeingDailyLimit * 60

    function refresh() {
        WellbeingService.summary(result => well.days = result);
    }

    Component.onCompleted: refresh()
    onLiveChanged: if (live)
        refresh()
    readonly property int revision: WellbeingService.revision
    onRevisionChanged: if (live)
        refresh()

    CfInk {
        id: ink
    }

    // ── the form's pieces ──

    component Ink: Text {
        property bool mut: false
        font.family: ink.font
        font.pixelSize: 14
        color: mut ? ink.muted : ink.text
    }

    // A big reading (`.val`): Khaslana's carries a red echo, the Reaver's a split glow
    component Val: Item {
        id: val
        property string text: ""
        property color tone: well.ph ? "#334786" : (well.kh ? "#F5D27A" : "#CFC6A8")
        readonly property int size: well.ph ? 34 : (well.kh ? 38 : 40)
        implicitWidth: face.implicitWidth + 4
        implicitHeight: Math.round(size * 1.1)

        Repeater {
            model: well.kh ? [[3, "#8E1424"]] : (well.rv ? [[2, "#D98F7BE0"], [-2, "#8C4FD1C5"]] : [])

            Text {
                required property var modelData
                x: modelData[0]
                anchors.verticalCenter: parent.verticalCenter
                text: face.text
                font: face.font
                color: modelData[1]
            }
        }

        Text {
            id: face
            anchors.verticalCenter: parent.verticalCenter
            text: val.text
            font.family: Form.numerals
            font.pixelSize: val.size
            font.italic: well.rv
            color: val.tone
        }
    }

    // A choice: a paper pill in Phainon, a cut gold plate in Khaslana, a slab with a left edge in
    // the Reaver.
    component Chip: Item {
        id: chip

        property string text: ""
        property bool on: false
        signal clicked

        implicitWidth: chipText.implicitWidth + 24
        implicitHeight: 24

        Rectangle {
            visible: well.ph
            anchors.fill: parent
            radius: height / 2
            color: chip.on ? "#334786" : (chipMouse.containsMouse ? "#FFFDF7" : "#FBF9F3")
            border.width: 1
            border.color: chip.on ? "#334786" : "#C8B27E"
        }

        CfQuad {
            visible: well.kh
            anchors.fill: parent
            points: [[0, 0], [1, 0], [1, 0.68], [1 - 8 / Math.max(8, chip.width), 1], [0, 1]]
            fill: chip.on ? "#E0B04A" : (chipMouse.containsMouse ? "#2A1015" : "transparent")
            stroke: "#E0B04A"
            strokeWidth: 1
        }

        Rectangle {
            visible: well.rv
            anchors.fill: parent
            color: chipMouse.containsMouse ? "#1A1528" : "transparent"
            border.width: 1
            border.color: chip.on ? "#8F7BE0" : "#5C5478"

            Rectangle {
                width: 3
                height: parent.height
                color: parent.border.color
            }
        }

        Text {
            id: chipText
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: well.rv ? 1 : 0
            text: well.rv ? (chip.on ? "> " : "") + chip.text.toLowerCase() : (well.kh ? chip.text.toUpperCase() : chip.text)
            font.family: well.kh ? "Cinzel" : ink.font
            font.pixelSize: well.kh ? 11 : 13
            font.weight: well.kh ? Font.DemiBold : Font.Normal
            font.letterSpacing: well.kh ? 1.5 : 0
            color: well.ph ? (chip.on ? "#F7F3E8" : "#334786") : (well.kh ? (chip.on ? "#0B080B" : "#F5D27A") : (chip.on ? "#E9E7F2" : "#A8A4BC"))
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    // A stepper's key
    component Key: Item {
        id: key
        property string text: ""
        signal clicked
        width: 26
        height: 26

        Rectangle {
            visible: !well.rv
            anchors.fill: parent
            radius: well.ph ? 13 : 0
            color: keyMouse.containsMouse ? (well.ph ? "#EFE6CC" : "#2A1015") : "transparent"
            border.width: 1
            border.color: well.ph ? "#C8B27E" : "#E0B04A"
        }

        Shape {
            visible: well.rv
            anchors.fill: parent

            ShapePath {
                fillColor: keyMouse.containsMouse ? "#1A1528" : "transparent"
                strokeColor: "#5C5478"
                strokeWidth: 1
                strokeStyle: ShapePath.DashLine
                dashPattern: [2, 2]
                PathPolyline {
                    path: [Qt.point(0.5, 0.5), Qt.point(25.5, 0.5), Qt.point(25.5, 25.5), Qt.point(0.5, 25.5), Qt.point(0.5, 0.5)]
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: key.text
            font.family: ink.font
            font.pixelSize: 15
            color: well.ph ? "#334786" : (well.kh ? "#F5D27A" : "#B9A8FF")
        }

        MouseArea {
            id: keyMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: key.clicked()
        }
    }

    // − minutes +: round keys for Phainon, gold squares for Khaslana, dashed squares for the Reaver.
    // A step is a quarter of an hour; at nothing the limit is off.
    component Stepper: Row {
        id: step

        property int minutes: 0
        property string label: ""
        signal committed(int minutes)

        function by(delta) {
            committed(Math.max(0, Math.min(24 * 60 - 1, minutes + delta)));
        }

        spacing: 10

        Text {
            visible: step.label !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: well.kh ? step.label.toUpperCase() : ink.tx(step.label)
            font.family: well.kh ? "Cinzel" : ink.font
            font.pixelSize: well.kh ? 12 : 14
            font.weight: well.kh ? Font.DemiBold : Font.Normal
            font.letterSpacing: well.kh ? 2.6 : 0
            color: well.kh ? "#E0B04A" : ink.muted
        }

        Key {
            anchors.verticalCenter: parent.verticalCenter
            text: "−"
            onClicked: step.by(-15)
        }

        Ink {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(implicitWidth, 52)
            horizontalAlignment: Text.AlignHCenter
            text: ink.tx(step.minutes > 0 ? WellbeingService.formatDuration(step.minutes * 60) : "Off")
            font.weight: Font.DemiBold
            color: well.ph ? ink.text : (well.kh ? "#F5D27A" : "#CFC6A8")
        }

        Key {
            anchors.verticalCenter: parent.verticalCenter
            text: "+"
            onClicked: step.by(15)
        }
    }

    // A card of the view, placed from `lay`; Khaslana's mosaic draws the block under it
    component Cell: DashCard {
        property string at: ""
        readonly property var r: well.lay[at] ?? [0, 0, 0, 0]
        x: r[0]
        y: r[1]
        width: r[2]
        height: r[3]
        bare: well.kh
        flute: false
    }

    // ── today and the daily limit ──
    Cell {
        at: "today"
        label: "I · Today"
        glyph: "time"
        poly: [[0, 0], [1, 0.03], [0.97, 1], [0.02, 0.94]]

        Val {
            text: WellbeingService.formatDuration(WellbeingService.today.active)
            tone: well.overToday ? ink.danger : (well.ph ? "#334786" : (well.kh ? "#F5D27A" : "#CFC6A8"))
        }

        Stepper {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            // centred on the card, not under the caption
            anchors.verticalCenterOffset: -8
            label: "Daily limit"
            minutes: SettingsData.wellbeingDailyLimit
            onCommitted: next => SettingsData.set("wellbeingDailyLimit", next)
        }
    }

    // ── the week ──
    Cell {
        at: "week"
        label: "This week"
        glyph: "time"
        poly: [[0.04, 0], [1, 0], [0.96, 1], [0, 0.88]]

        Ink {
            visible: !WellbeingService.available
            anchors.centerIn: parent
            mut: true
            text: ink.tx("Screen time needs a newer dms. Update it, then restart the shell.")
            width: parent.width
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }

        WeeklyChart {
            id: chart
            visible: WellbeingService.available
            anchors.fill: parent
            bare: true
            showTitle: false
            days: well.days
            today: well.today
            firstDayOfWeek: well.firstDayOfWeek
            limitSeconds: SettingsData.wellbeingDailyLimit * 60
        }
    }

    // ── the most-used apps and their limits ──
    Cell {
        id: appsCard
        at: "apps"
        label: "Most used"
        glyph: "time"
        poly: [[0, 0.06], [1, 0], [0.98, 1], [0.03, 0.95]]

        // The period, on the caption's line
        Row {
            anchors.right: parent.right
            y: -20
            spacing: 6

            Repeater {
                model: [["day", "Day"], ["week", "Week"], ["month", "Month"]]

                Chip {
                    required property var modelData
                    text: modelData[1]
                    on: well.period === modelData[0]
                    onClicked: well.period = modelData[0]
                }
            }
        }

        Ink {
            visible: well.apps.length === 0
            anchors.centerIn: parent
            mut: true
            text: ink.tx("Nothing tracked yet")
        }

        Column {
            width: parent.width

            Repeater {
                // as many as the card holds under its caption
                model: well.apps.slice(0, Math.max(1, Math.floor((appsCard.height - (well.rv ? 56 : 44)) / 32)))

                Item {
                    id: row

                    required property var modelData
                    readonly property string appId: modelData.appId
                    readonly property int limitMinutes: WellbeingService.appLimitMinutes(appId)
                    readonly property bool overLimit: limitMinutes > 0 && modelData.seconds >= limitMinutes * 60
                    readonly property bool editing: well.editing === appId

                    width: parent.width
                    height: 32

                    CcAppIcon {
                        id: icon
                        anchors.verticalCenter: parent.verticalCenter
                        appId: row.appId
                        iconSize: 22
                    }

                    Ink {
                        id: name
                        anchors.left: icon.right
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: well.ph ? 110 : 76
                        elide: Text.ElideRight
                        text: ink.tx(WellbeingService.appName(row.appId))
                    }

                    // Its share of the most-used app's time
                    Item {
                        visible: !row.editing
                        anchors.left: name.right
                        anchors.leftMargin: 10
                        anchors.right: spent.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        height: 5

                        Rectangle {
                            anchors.fill: parent
                            radius: well.ph ? 3 : 0
                            color: well.ph ? "#E4DAC0" : (well.kh ? "#2A1015" : "#2C2840")
                            // the Reaver's track leans like his bars
                            transform: Matrix4x4 {
                                matrix: Qt.matrix4x4(1, well.rv ? -0.364 : 0, 0, well.rv ? 0.91 : 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                            }

                            Rectangle {
                                width: well.longest > 0 ? parent.width * row.modelData.seconds / well.longest : 0
                                height: parent.height
                                radius: parent.radius
                                color: row.overLimit ? ink.danger : (well.ph ? "#334786" : (well.kh ? "#C2252F" : "#8F7BE0"))

                                // Khaslana's gold tip
                                Rectangle {
                                    visible: well.kh
                                    anchors.right: parent.right
                                    width: Math.min(3, parent.width)
                                    height: parent.height
                                    color: "#F2C75C"
                                }
                            }
                        }
                    }

                    // Setting this app's limit, in place of its bar
                    Stepper {
                        visible: row.editing
                        anchors.left: name.right
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        minutes: row.limitMinutes
                        onCommitted: next => WellbeingService.setAppLimit(row.appId, next)
                    }

                    Ink {
                        id: spent
                        visible: !row.editing
                        anchors.right: limitChip.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: well.ph ? 64 : 40
                        horizontalAlignment: Text.AlignRight
                        text: WellbeingService.formatDuration(row.modelData.seconds)
                        color: row.overLimit ? ink.danger : ink.text
                    }

                    Chip {
                        id: limitChip
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.editing ? "Done" : (row.limitMinutes > 0 ? WellbeingService.formatDuration(row.limitMinutes * 60) + (well.ph ? " ✓" : "") : "Limit")
                        on: row.editing || (row.limitMinutes > 0 && !well.ph)
                        onClicked: well.editing = row.editing ? "" : row.appId
                    }
                }
            }
        }
    }
}
