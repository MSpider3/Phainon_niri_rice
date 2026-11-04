import QtQuick
import QtQuick.Shapes
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets

// "Sky · Weather" per form (v3 mockup): Phainon paper cards, the sun over wheat and water standing
// in the humidity card; Khaslana an obsidian mosaic, the sun swept as a gold blade; the Flame
// Reaver plain numbers on shards. The dashboard holds the WeatherService ref.
DashSheet {
    id: sky

    title: "Sky · Weather"
    glyph: "sky"

    readonly property var w: WeatherService.weather
    readonly property bool ok: !!w.available
    readonly property var hours: (w.hourlyForecast ?? []).slice(w.currentHourIndex ?? 0, (w.currentHourIndex ?? 0) + 8)
    readonly property var days: (w.forecast ?? []).slice(0, 7)
    // Taken when the dashboard opens and when the weather refreshes; nothing ticks. The view stays
    // loaded while the dashboard is closed, so creation time alone would go stale.
    property var now: new Date()
    readonly property real sunrise: w.rawSunrise ? new Date(w.rawSunrise).getTime() : NaN
    readonly property real sunset: w.rawSunset ? new Date(w.rawSunset).getTime() : NaN
    readonly property bool hasSun: sunset > sunrise
    readonly property real sunAt: hasSun ? (now.getTime() - sunrise) / (sunset - sunrise) : -1
    readonly property bool sunUp: sunAt >= 0 && sunAt <= 1
    readonly property real burnt: sunUp ? sunAt : (sunAt > 1 ? 1 : 0)
    readonly property var moonTrack: ok ? WeatherService.getMoonTrack(now) : null
    readonly property string speedUnit: String(WeatherService.formatSpeed(0) ?? "").replace(/^[\d.]+\s*/, "")
    readonly property bool hasWind: w.windDirection !== null && w.windDirection !== undefined
    readonly property bool hasDew: w.dewPoint !== null && w.dewPoint !== undefined

    // Each card's [x, y, w, h] in the body, per the mockup; Khaslana's sit on its 4-column grid
    readonly property var lay: ph ? ({
            hero: [0, 0, 294, 142],
            hourly: [306, 0, 442, 142],
            sun: [0, 154, 368, 160],
            moon: [380, 154, 368, 160],
            humidity: [0, 326, 165, 116],
            wind: [177, 326, 165, 116],
            week: [354, 326, 394, 116]
        }) : kh ? ({
            hero: [0, 0, spanW(2), 136],
            hourly: [colX(2), 0, bodyWidth - colX(2), 136],
            sun: [0, 141, spanW(2), 156],
            moon: [colX(2), 141, bodyWidth - colX(2), 156],
            humidity: [0, 302, spanW(1), 110],
            wind: [colX(1), 302, spanW(1), 110],
            week: [colX(2), 302, bodyWidth - colX(2), 110]
        }) : ({
            hero: [0, 0, 300, 170],
            hourly: [314, 0, 466, 170],
            sky: [0, 184, 470, 150],
            air: [484, 184, 296, 150],
            week: [0, 348, 780, 132]
        })

    bodyHeight: Math.max(...Object.values(lay).map(r => r[1] + r[3]))
    blocks: kh ? Object.keys(lay).map(k => lay[k].concat([k === "hero"])) : []

    function degrees(c, f) {
        if (c === undefined || c === null)
            return "--";
        return (SettingsData.useFahrenheit ? f : c) + "°";
    }

    function clock(iso) {
        return iso ? WeatherService.formatTime(iso) : "--";
    }

    // The mockup's sky arc in a 300-wide box: a cubic from (14, hz) over (70, 4), (230, 4) to
    // (286, hz). Cut at t (de Casteljau): the path up to there and the point it ends on.
    function arcTo(t, hz) {
        const lerp = (a, b) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t];
        const p = [[14, hz], [70, 4], [230, 4], [286, hz]];
        const a = lerp(p[0], p[1]), b = lerp(p[1], p[2]), c = lerp(p[2], p[3]);
        const d = lerp(a, b), e = lerp(b, c), f = lerp(d, e);
        return {
            path: `M14 ${hz} C${a[0]} ${a[1]} ${d[0]} ${d[1]} ${f[0]} ${f[1]}`,
            x: f[0],
            y: f[1]
        };
    }

    // The moon's altitude (-1..1) as a height in the art box: the sky above the horizon, a sliver below
    function moonY(alt, hz, vh) {
        return hz - alt * (alt > 0 ? hz - 8 : vh - hz - 2);
    }

    onWChanged: now = new Date()

    Connections {
        target: sky.Window.window
        function onVisibleChanged() {
            if (sky.Window.window.visible)
                sky.now = new Date();
        }
    }

    CfInk {
        id: ink
    }

    // Body text in the form's ink
    component Ink: Text {
        property bool mut: false
        font.family: ink.font
        font.pixelSize: 13
        color: mut ? ink.muted : ink.text
    }

    // A big reading (`.val`): Khaslana's carries a red shadow 3 px right, the Reaver's hero a split glow
    component Val: Item {
        id: val
        property string text: ""
        property int size: sky.ph ? 34 : (sky.kh ? 38 : 40)
        property bool glitch: false
        implicitWidth: face.implicitWidth + (sky.kh ? 3 : 0)
        implicitHeight: Math.round(size * 1.1)

        Repeater {
            model: sky.kh ? [[3, "#8E1424"]] : (sky.rv && val.glitch ? [[2, "#D98F7BE0"], [-2, "#8C4FD1C5"]] : [])

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
            font.italic: sky.rv
            color: sky.ph ? "#334786" : (sky.kh ? "#F5D27A" : "#CFC6A8")
        }
    }

    // A card of the view, placed from `lay`; Khaslana's mosaic draws the block under it
    component Cell: DashCard {
        property string at: ""
        readonly property var r: sky.lay[at] ?? [0, 0, 0, 0]
        visible: !!sky.lay[at]
        x: r[0]
        y: r[1]
        width: r[2]
        height: r[3]
        bare: sky.kh
        flute: false
    }

    // Columns across a card (`.dv-hours`, `.dv-week`): each row is [name, bold figure, small line]
    component Columns: Row {
        id: cols
        property var rows: []
        readonly property real slot: width / Math.max(1, rows.length)

        Repeater {
            model: cols.rows

            Column {
                id: col
                required property var modelData
                required property int index
                // the first column is now / today: gold in Khaslana, violet in the Reaver
                readonly property color lead: index === 0 ? (sky.kh ? "#F5D27A" : (sky.rv ? "#B9A8FF" : ink.text)) : ink.text
                width: cols.slot

                Ink {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: ink.tx(col.modelData[0])
                    color: sky.rv ? col.lead : ink.text
                }

                Ink {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: col.modelData[1]
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    color: col.lead
                }

                Ink {
                    visible: text !== ""
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: col.modelData[2]
                    mut: !sky.rv
                    color: sky.rv ? col.lead : ink.muted
                }
            }
        }
    }

    // Sun or moon over the horizon, drawn in the mockup's 300-wide box and scaled to the card
    component SkyArt: Item {
        id: art
        property bool moon: false
        readonly property real vh: sky.ph ? 90 : 80
        readonly property real hz: sky.ph ? 74 : 72
        readonly property var sun: sky.arcTo(Math.max(0, Math.min(1, sky.sunAt)), hz)
        readonly property var track: sky.moonTrack
        readonly property real moonX: 300 * Math.max(0, Math.min(1, track?.progress ?? 0))
        width: parent.width
        height: Math.round(width * vh / 300)

        Item {
            width: 300
            height: art.vh
            scale: art.width / 300
            transformOrigin: Item.TopLeft

            Rectangle {
                y: art.hz
                width: 300
                height: 1
                color: sky.ph ? "#C8B27E" : "#80E0B04A"
            }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                // The sky's path: the sun's arc, or the moon's own track through today
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: sky.ph && !art.moon ? "#A87A22" : (sky.ph ? "#C8B27E" : "#3A1A1E")
                    strokeWidth: sky.ph ? 1 : 2
                    strokeStyle: sky.kh && !art.moon ? ShapePath.SolidLine : ShapePath.DashLine
                    // in stroke widths: 3 4 and 2 5 px for Phainon, 6 4 px for Khaslana
                    dashPattern: sky.kh ? [3, 2] : (art.moon ? [2, 5] : [3, 4])
                    capStyle: sky.ph ? ShapePath.RoundCap : ShapePath.FlatCap

                    PathSvg {
                        path: !art.moon ? sky.arcTo(1, art.hz).path : (art.track?.values ?? []).map((v, i, all) => (i ? "L" : "M") + (300 * i / Math.max(1, all.length - 1)) + " " + sky.moonY(v, art.hz, art.vh)).join(" ")
                    }
                }

                // Khaslana: the blade has swept from rise to now
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: sky.kh && !art.moon && sky.sunAt > 0 ? "#E0B04A" : "transparent"
                    strokeWidth: 5
                    capStyle: ShapePath.FlatCap

                    PathSvg {
                        path: art.sun.path
                    }
                }

                // Phainon: the wheat under the sun's horizon
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: sky.ph && !art.moon ? "#C9A24A" : "transparent"
                    strokeWidth: 1
                    capStyle: ShapePath.RoundCap

                    PathSvg {
                        path: "M20 90V76M34 90V78M48 90V75M62 90V77M76 90V76M90 90V78M104 90V75M118 90V77M132 90V76M146 90V78M160 90V75M174 90V77M188 90V76M202 90V78M216 90V75M230 90V77M244 90V76M258 90V78M272 90V75"
                    }
                }
            }

            // Phainon's sun with its pale ring
            Rectangle {
                visible: sky.ph && !art.moon && sky.sunUp
                x: art.sun.x - 14
                y: art.sun.y - 14
                width: 28
                height: 28
                radius: 14
                color: "transparent"
                border.width: 1
                border.color: "#73F1DA4F"

                Rectangle {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    radius: 8
                    color: "#F1DA4F"
                    border.width: 1
                    border.color: "#A87A22"
                }
            }

            // Khaslana: the blade's point, a gold diamond with its red shadow
            Repeater {
                model: sky.kh && !art.moon && sky.sunUp ? [[3, "#8E1424"], [0, "#F5D27A"]] : []

                Rectangle {
                    required property var modelData
                    x: art.sun.x - 6 + modelData[0]
                    y: art.sun.y - 6
                    width: 12
                    height: 12
                    rotation: 45
                    color: modelData[1]
                }
            }

            // The moon, in today's phase, where it stands on its track
            Rectangle {
                visible: art.moon && !!art.track
                x: art.moonX - 9
                y: Math.max(0, Math.min(art.vh - 18, sky.moonY(art.track?.altitude ?? 0, art.hz, art.vh) - 9))
                width: 18
                height: 18
                radius: 9
                color: sky.ph ? "#E4DAC0" : "#2A1015"
                border.width: 1
                border.color: sky.ph ? "#4A5484" : "#E0B04A"

                DNFIcon {
                    anchors.centerIn: parent
                    name: WeatherService.getMoonPhase(sky.now)
                    size: 16
                    color: sky.ph ? "#4A5484" : "#E0B04A"
                }
            }
        }
    }

    // Rise and set under an arc
    component RiseSet: Item {
        property string rise: ""
        property string set: ""
        anchors.bottom: parent.bottom
        width: parent.width
        height: 16

        Ink {
            mut: true
            text: "Rise " + parent.rise
        }

        Ink {
            anchors.right: parent.right
            mut: true
            text: "Set " + parent.set
        }
    }

    // ── I: now ──
    Cell {
        id: hero
        at: "hero"
        label: "I · " + (sky.w.city || "Weather")
        poly: [[0, 0], [1, 0.03], [0.97, 1], [0.02, 0.94]]

        // Khaslana's red corner on the hero block
        Item {
            visible: sky.kh
            anchors.right: parent.right
            anchors.rightMargin: -15
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -12
            width: 46
            height: 46

            Rectangle {
                x: 14
                y: 14
                width: 18
                height: 18
                color: "#3A0A12"
            }
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 14
                color: "#8E1424"
            }
            Rectangle {
                anchors.right: parent.right
                width: 14
                height: parent.height
                color: "#C2252F"
            }
        }

        Column {
            width: parent.width
            spacing: sky.rv ? 0 : 4

            Row {
                spacing: 12

                Val {
                    id: temp
                    size: sky.rv ? 60 : 64
                    glitch: true
                    text: (sky.rv ? "> " : "") + WeatherService.currentTempText()
                }

                // Phainon and Khaslana name the sky beside the figure
                Text {
                    visible: !sky.rv
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    width: Math.min(implicitWidth, hero.width - 30 - temp.width - 12)
                    elide: Text.ElideRight
                    text: sky.ok ? WeatherService.getWeatherCondition(sky.w.wCode) : "No weather data"
                    font.family: sky.ph ? "Marcellus" : "Cinzel"
                    font.pixelSize: sky.ph ? 20 : 18
                    font.weight: sky.kh ? Font.Bold : Font.Normal
                    font.capitalization: sky.kh ? Font.AllUppercase : Font.MixedCase
                    font.letterSpacing: sky.kh ? 2.5 : 0
                    color: sky.kh ? "#F5D27A" : ink.text
                }
            }

            Ink {
                visible: sky.rv
                width: parent.width
                elide: Text.ElideRight
                text: ink.tx(sky.ok ? WeatherService.getWeatherCondition(sky.w.wCode) : "No weather data")
                font.pixelSize: 15
            }

            Ink {
                visible: sky.ok
                width: parent.width
                elide: Text.ElideRight
                mut: true
                text: ink.tx("Feels like " + sky.degrees(sky.w.feelsLike, sky.w.feelsLikeF) + " · " + (sky.days.length ? sky.degrees(sky.days[0].tempMax, sky.days[0].tempMaxF) + " / " + sky.degrees(sky.days[0].tempMin, sky.days[0].tempMinF) : ""))
            }
        }
    }

    // ── II: the next hours, the temperature drawn as a line through them ──
    Cell {
        at: "hourly"
        label: "II · Hourly"
        poly: [[0.04, 0], [1, 0], [0.96, 1], [0, 0.88]]

        Column {
            width: parent.width
            spacing: 4

            Item {
                visible: !sky.rv && sky.hours.length > 1
                width: parent.width
                height: 30

                DSparkline {
                    x: hourCols.slot / 2
                    width: parent.width - hourCols.slot
                    height: parent.height
                    values: sky.hours.map(h => h.temp)
                    autoRange: true
                    curved: false
                    lineColor: sky.ph ? "#334786" : "#E0B04A"
                    lineWidth: sky.ph ? 1.5 : 2
                    fillOpacity: sky.ph ? 0.1 : 0
                }
            }

            Columns {
                id: hourCols
                width: parent.width
                rows: sky.hours.map((h, i) => [i === 0 ? (sky.rv ? "> now" : "Now") : String(h.time ?? "").replace(":00", ""), sky.degrees(h.temp, h.tempF), sky.kh ? "" : (sky.ph ? "☂ " : "") + (h.precipitationProbability ?? 0) + "%"])
            }
        }
    }

    // ── III, IV: sun and moon (Phainon, Khaslana) ──
    Cell {
        at: "sun"
        label: "III · Sun"

        SkyArt {}

        RiseSet {
            rise: sky.clock(sky.w.rawSunrise)
            set: sky.clock(sky.w.rawSunset)
        }
    }

    Cell {
        at: "moon"
        label: "IV · Moon"

        SkyArt {
            moon: true
        }

        RiseSet {
            rise: sky.clock(sky.w.moonrise)
            set: sky.clock(sky.w.moonset)
        }
    }

    // ── the Flame Reaver's sky: two plain lines and how much of the day has burnt ──
    Cell {
        at: "sky"
        label: "Sky"
        poly: [[0, 0.06], [1, 0], [0.98, 1], [0.03, 0.95]]

        Column {
            width: parent.width
            spacing: 4

            Grid {
                columns: 2
                columnSpacing: 18

                Repeater {
                    model: ["sun", sky.clock(sky.w.rawSunrise) + " → " + sky.clock(sky.w.rawSunset), "moon", sky.clock(sky.w.moonrise) + " → " + sky.clock(sky.w.moonset)]

                    Ink {
                        required property string modelData
                        text: modelData.toLowerCase()
                        font.pixelSize: 16
                    }
                }
            }

            Item {
                width: parent.width
                height: 14

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 4
                    color: "#2C2840"
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * sky.burnt
                    height: 4
                    color: "#8F7BE0"
                }
                // the ember, with a soft halo standing in for the mockup's glow
                Rectangle {
                    x: parent.width * sky.burnt - 7
                    width: 14
                    height: 14
                    radius: 7
                    color: "#66F07A85"

                    Rectangle {
                        anchors.centerIn: parent
                        width: 8
                        height: 8
                        radius: 4
                        color: "#F07A85"
                    }
                }
            }

            Ink {
                mut: true
                font.pixelSize: 12
                text: "// " + (sky.hasSun ? Math.round(sky.burnt * 100) + "%" : "--") + " of the day burnt"
            }
        }
    }

    // ── humidity: Phainon's card holds water as high as the air is wet ──
    Cell {
        id: humidity
        at: "humidity"
        label: "Humidity"

        Rectangle {
            visible: sky.ph
            x: -14
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -11
            width: parent.width + 28
            height: (humidity.height - 2) * Math.max(0, Math.min(100, sky.w.humidity ?? 0)) / 100
            bottomLeftRadius: 11
            bottomRightRadius: 11
            color: "#292E93A8"

            Rectangle {
                width: parent.width
                height: 1
                color: "#802E93A8"
            }
        }

        Val {
            id: humVal
            text: sky.ok ? sky.w.humidity + "%" : "--"
        }

        Ink {
            anchors.top: humVal.bottom
            visible: sky.hasDew
            mut: true
            text: "Dew " + WeatherService.formatTemp(Math.round(sky.w.dewPoint ?? 0))
        }
    }

    // ── wind, its arrow pointing where it blows ──
    Cell {
        at: "wind"
        label: "Wind"

        Column {
            spacing: 2

            Row {
                spacing: 6

                Val {
                    text: sky.ok ? String(WeatherService.formatSpeed(sky.w.wind, false)) : "--"
                }

                Ink {
                    visible: sky.ph
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    text: sky.speedUnit
                    font.pixelSize: 15
                }
            }

            Row {
                spacing: 6

                Ink {
                    visible: sky.kh
                    mut: true
                    text: sky.speedUnit
                }

                DIcon {
                    visible: sky.hasWind
                    name: "navigation"
                    size: 16
                    rotation: (sky.w.windDirection ?? 0) + 180
                    color: sky.ph ? "#A87A22" : "#F5D27A"
                }
            }
        }
    }

    // ── the Flame Reaver's air: humidity and wind as two lines ──
    Cell {
        at: "air"
        label: "Air"
        poly: [[0.03, 0], [1, 0], [1, 0.92], [0, 1]]

        Column {
            spacing: 2

            Ink {
                textFormat: Text.StyledText
                text: "humidity <font color='#CFC6A8'>" + (sky.ok ? sky.w.humidity + "%" : "--") + "</font>"
            }

            Row {
                spacing: 6

                Ink {
                    textFormat: Text.StyledText
                    text: "wind <font color='#CFC6A8'>" + (sky.ok ? WeatherService.formatSpeed(sky.w.wind, false) + " " + sky.speedUnit : "--") + "</font>"
                }

                DIcon {
                    visible: sky.hasWind
                    anchors.verticalCenter: parent.verticalCenter
                    name: "navigation"
                    size: 14
                    rotation: (sky.w.windDirection ?? 0) + 180
                    color: "#B9A8FF"
                }
            }

            Ink {
                visible: sky.hasDew
                mut: true
                text: "dew " + WeatherService.formatTemp(Math.round(sky.w.dewPoint ?? 0))
            }
        }
    }

    // ── the week ──
    Cell {
        at: "week"
        label: "The week"
        poly: [[0.02, 0.04], [1, 0], [0.97, 0.96], [0, 1]]

        Columns {
            width: parent.width
            // Khaslana's plates show only the low under the high, as the mockup does
            rows: sky.days.map((d, i) => [i === 0 ? (sky.rv ? "> today" : "Today") : String(d.day ?? "").substring(0, 3), sky.degrees(d.tempMax, d.tempMaxF) + (sky.rv ? " / " + sky.degrees(d.tempMin, d.tempMinF) : ""), sky.rv ? "rain " + (d.precipitationProbability ?? 0) + "%" : sky.degrees(d.tempMin, d.tempMinF) + (sky.ph ? " · ☂ " + (d.precipitationProbability ?? 0) + "%" : "")])
        }
    }
}
