import QtQuick
import QtQuick.Shapes
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets

// "Sky · Weather": hero, the next hours, sun and moon, humidity and wind, the week.
// Phainon draws the sun's path over a wheat horizon; Khaslana sweeps it as a gold blade; the
// Flame Reaver reads the sky as two plain lines. The dashboard holds the WeatherService ref.
Column {
    id: sky

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
    readonly property var moonTrack: ok ? WeatherService.getMoonTrack(now) : null
    readonly property real fourth: 124
    readonly property real arcWidth: (width - 3 * 12 - 2 * fourth) / 2
    readonly property color accent: Form.reaver ? Theme.live : Theme.primary
    readonly property string numberFont: Form.phainon || !Form.active ? Theme.fontFamily : Theme.monoFontFamily

    function tx(text) {
        return Form.reaver ? String(text).toLowerCase() : text;
    }

    function degrees(c, f) {
        if (c === undefined || c === null)
            return "--";
        return (SettingsData.useFahrenheit ? f : c) + "°";
    }

    function clock(iso) {
        return iso ? WeatherService.formatTime(iso) : "--";
    }

    function compass(deg) {
        if (deg === null || deg === undefined)
            return "";
        return ["N", "NE", "E", "SE", "S", "SW", "W", "NW"][Math.round(deg / 45) % 8];
    }

    onWChanged: now = new Date()

    Connections {
        target: sky.Window.window
        function onVisibleChanged() {
            if (sky.Window.window.visible)
                sky.now = new Date();
        }
    }

    spacing: 12

    // A sky arc: Phainon a soft path with a sun, Khaslana a blade sweep up to now with a diamond
    // at its tip. `at` is 0..1 across the arc, or outside that when below the horizon.
    component Arc: Item {
        id: arc

        property real at: -1
        property color tone: Theme.primary
        property bool sun: true
        readonly property bool up: at >= 0 && at <= 1
        readonly property real cx: width / 2
        readonly property real rx: width / 2 - 8
        readonly property real ry: height - 10
        readonly property real angle: Math.PI * (1 - Math.max(0, Math.min(1, at)))

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: Theme.withAlpha(Theme.outline, Form.khaslana ? 0.5 : 0.8)
                strokeWidth: Form.khaslana ? 1 : 1.5
                strokeStyle: Form.khaslana ? ShapePath.DashLine : ShapePath.SolidLine
                dashPattern: [3, 3]

                PathAngleArc {
                    centerX: arc.cx
                    centerY: arc.height
                    radiusX: arc.rx
                    radiusY: arc.ry
                    startAngle: 180
                    sweepAngle: 180
                }
            }

            // Khaslana: the blade has swept from rise to now
            ShapePath {
                fillColor: "transparent"
                strokeColor: Form.khaslana && arc.at > 0 ? arc.tone : "transparent"
                strokeWidth: 3
                capStyle: ShapePath.FlatCap

                PathAngleArc {
                    centerX: arc.cx
                    centerY: arc.height
                    radiusX: arc.rx
                    radiusY: arc.ry
                    startAngle: 180
                    sweepAngle: 180 * Math.max(0, Math.min(1, arc.at))
                }
            }
        }

        // Phainon: the sun itself, gold with a soft ring; the moon a pale disc
        Rectangle {
            visible: !Form.khaslana && arc.up
            x: arc.cx + arc.rx * Math.cos(arc.angle) - width / 2
            y: arc.height - arc.ry * Math.sin(arc.angle) - height / 2
            width: 14
            height: 14
            radius: 7
            color: arc.sun ? "#E9B92E" : Theme.surfaceContainerHighest
            border.width: arc.sun ? 3 : 1.5
            border.color: arc.sun ? Theme.withAlpha("#E9B92E", 0.3) : arc.tone
        }

        // Khaslana: the blade's point
        Rectangle {
            visible: Form.khaslana && arc.up
            x: arc.cx + arc.rx * Math.cos(arc.angle) - width / 2
            y: arc.height - arc.ry * Math.sin(arc.angle) - height / 2
            width: 9
            height: 9
            rotation: 45
            color: arc.tone
        }
    }

    // One reading (label over a big figure)
    component Reading: Column {
        property string label: ""
        property string value: ""
        property string note: ""
        spacing: 2

        StyledText {
            text: sky.tx(parent.value)
            font.family: sky.numberFont
            font.pixelSize: 26
            font.weight: Font.DemiBold
            color: Form.reaver ? Theme.live : Theme.surfaceText
        }

        StyledText {
            visible: text !== ""
            text: sky.tx(parent.note)
            font.family: Form.reaver ? Theme.monoFontFamily : Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.withAlpha(Theme.surfaceText, 0.6)
        }
    }

    Row {
        spacing: 12
        height: 150

        // Hero: temperature, condition, city
        DashCard {
            width: 300
            height: parent.height
            numeral: "I"
            glyph: "sky"
            label: sky.w.city || "Weather"

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                StyledText {
                    text: (Form.reaver ? "> " : "") + (sky.ok ? WeatherService.currentTempText(false) : "--")
                    font.family: Form.reaver ? Theme.monoFontFamily : (Form.khaslana ? Theme.monoFontFamily : Form.display(Theme.fontFamily))
                    font.pixelSize: 44
                    font.weight: Font.DemiBold
                    color: Form.reaver ? Theme.live : Theme.surfaceText
                }

                StyledText {
                    width: 260 - (Form.reaver ? 0 : 76)
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                    text: sky.tx(sky.ok ? WeatherService.getWeatherCondition(sky.w.wCode) : "No weather data")
                    font.family: Form.reaver ? Theme.monoFontFamily : Form.display(Theme.fontFamily)
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.withAlpha(Theme.surfaceText, 0.85)
                }

                StyledText {
                    visible: sky.ok
                    text: sky.tx("Feels like " + sky.degrees(sky.w.feelsLike, sky.w.feelsLikeF) + "   ·   " + (sky.days.length ? sky.degrees(sky.days[0].tempMax, sky.days[0].tempMaxF) + " / " + sky.degrees(sky.days[0].tempMin, sky.days[0].tempMinF) : ""))
                    font.family: sky.numberFont
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.withAlpha(Theme.surfaceText, 0.6)
                }
            }

            DIcon {
                visible: !Form.reaver
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                name: sky.ok ? WeatherService.getWeatherIcon(sky.w.wCode, sky.w.isDay) : "cloud_off"
                size: 64
                color: Form.phainon ? "#E9B92E" : Theme.primary
            }
        }

        // The next hours, with the temperature drawn as a line through them
        DashCard {
            id: hourly
            width: sky.width - 300 - 12
            height: parent.height
            numeral: "II"
            glyph: "time"
            label: "Hourly"
            readonly property real slot: width / Math.max(1, sky.hours.length)

            DSparkline {
                visible: !Form.reaver && sky.hours.length > 1
                x: -14 + hourly.slot / 2
                width: hourly.width - hourly.slot
                y: 48
                height: 24
                values: sky.hours.map(h => h.temp)
                autoRange: true
                lineColor: Theme.withAlpha(Theme.primary, 0.7)
                lineWidth: 1.5
                fillOpacity: Form.phainon ? 0.1 : 0
                curved: !Form.khaslana
                showDots: true
                dotRadius: 2
            }

            Row {
                x: -14
                anchors.top: parent.top

                Repeater {
                    model: sky.hours

                    Column {
                        id: hour
                        required property var modelData
                        required property int index
                        width: hourly.slot
                        spacing: 4

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: sky.tx(hour.index === 0 ? (Form.reaver ? "> now" : "Now") : String(hour.modelData.time ?? "").replace(":00", ""))
                            font.family: Form.reaver ? Theme.monoFontFamily : Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: hour.index === 0 ? Font.DemiBold : Font.Normal
                            color: hour.index === 0 ? sky.accent : Theme.withAlpha(Theme.surfaceText, 0.6)
                        }

                        DIcon {
                            visible: !Form.reaver
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: WeatherService.getWeatherIcon(hour.modelData.wCode, hour.modelData.isDay)
                            size: 20
                            color: Theme.primary
                        }

                        Item {
                            width: 1
                            height: Form.reaver ? 12 : 26
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: sky.degrees(hour.modelData.temp, hour.modelData.tempF)
                            font.family: sky.numberFont
                            font.pixelSize: Form.reaver ? Theme.fontSizeLarge : Theme.fontSizeMedium
                            font.weight: Font.DemiBold
                            color: Form.reaver && hour.index === 0 ? Theme.live : Theme.surfaceText
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: (Form.reaver ? "" : "☂ ") + (hour.modelData.precipitationProbability ?? 0) + "%"
                            font.family: sky.numberFont
                            font.pixelSize: 10
                            color: Theme.withAlpha(Theme.surfaceText, 0.5)
                        }
                    }
                }
            }
        }
    }

    Row {
        spacing: 12
        height: 132

        // Sun: Phainon and Khaslana draw it; the Flame Reaver gives it one line, with the moon
        DashCard {
            visible: !Form.reaver
            width: sky.arcWidth
            height: parent.height
            numeral: "III"
            glyph: "sky"
            label: "Sun"

            Arc {
                id: sunArc
                anchors.horizontalCenter: parent.horizontalCenter
                y: 4
                width: parent.width - 20
                height: 58
                at: sky.sunAt
                tone: Form.khaslana ? Theme.primary : "#E9B92E"
            }

            // Aedes Elysiae: the sun rises over wheat
            CfWheat {
                visible: Form.phainon
                anchors.horizontalCenter: parent.horizontalCenter
                y: sunArc.y + sunArc.height - 12
                width: parent.width - 20
                height: 14
                spacing: 10
            }

            Rectangle {
                visible: Form.khaslana
                anchors.horizontalCenter: parent.horizontalCenter
                y: sunArc.y + sunArc.height
                width: parent.width
                height: 1
                color: Theme.primary
            }

            Item {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 16

                StyledText {
                    text: sky.tx("Rise ") + sky.clock(sky.w.rawSunrise)
                    font.family: sky.numberFont
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.withAlpha(Theme.surfaceText, 0.65)
                }

                StyledText {
                    anchors.right: parent.right
                    text: sky.tx("Set ") + sky.clock(sky.w.rawSunset)
                    font.family: sky.numberFont
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.withAlpha(Theme.surfaceText, 0.65)
                }
            }
        }

        // Moon: its track through today, the phase riding on it
        DashCard {
            id: moonCard
            visible: !Form.reaver
            width: sky.arcWidth
            height: parent.height
            numeral: "IV"
            glyph: "sky"
            label: "Moon"

            readonly property var track: sky.moonTrack

            Item {
                id: moonSky
                anchors.horizontalCenter: parent.horizontalCenter
                y: 10
                width: parent.width - 20
                height: 52

                Rectangle {
                    y: parent.height / 2
                    width: parent.width
                    height: 1
                    color: Form.khaslana ? Theme.primary : Theme.withAlpha(Theme.outline, 0.5)
                }

                Shape {
                    visible: !!moonCard.track
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: Form.khaslana ? Theme.withAlpha(Theme.surfaceText, 0.55) : Theme.withAlpha(Theme.primary, 0.6)
                        strokeWidth: 1.5

                        PathPolyline {
                            path: (moonCard.track?.values ?? []).map((v, i, all) => Qt.point(moonSky.width * i / Math.max(1, all.length - 1), moonSky.height * (1 - v) / 2))
                        }
                    }
                }

                DNFIcon {
                    visible: !!moonCard.track
                    x: moonSky.width * Math.max(0, Math.min(1, moonCard.track?.progress ?? 0)) - width / 2
                    y: Math.max(-6, Math.min(moonSky.height - height, moonSky.height * (1 - (moonCard.track?.altitude ?? 0)) / 2 - height / 2))
                    name: WeatherService.getMoonPhase(sky.now)
                    size: 18
                    color: Form.khaslana ? Theme.primary : Theme.surfaceText
                }
            }

            Item {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 16

                StyledText {
                    text: sky.tx("Rise ") + sky.clock(sky.w.moonrise)
                    font.family: sky.numberFont
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.withAlpha(Theme.surfaceText, 0.65)
                }

                StyledText {
                    anchors.right: parent.right
                    text: sky.tx("Set ") + sky.clock(sky.w.moonset)
                    font.family: sky.numberFont
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.withAlpha(Theme.surfaceText, 0.65)
                }
            }
        }

        // The Flame Reaver: the sky in two lines, and how much of the day has burnt
        DashCard {
            visible: Form.reaver
            width: sky.arcWidth * 2 + 12
            height: parent.height
            label: "sky"

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                spacing: 8

                Repeater {
                    model: [["sun ", sky.clock(sky.w.rawSunrise) + " → " + sky.clock(sky.w.rawSunset)], ["moon", sky.clock(sky.w.moonrise) + " → " + sky.clock(sky.w.moonset)]]

                    Row {
                        required property var modelData
                        spacing: 10

                        StyledText {
                            text: modelData[0]
                            font.family: Theme.monoFontFamily
                            font.pixelSize: Theme.fontSizeLarge
                            color: Theme.live
                        }

                        StyledText {
                            text: modelData[1].toLowerCase()
                            font.family: Theme.monoFontFamily
                            font.pixelSize: Theme.fontSizeLarge
                            color: Theme.surfaceText
                        }
                    }
                }

                CfScorch {
                    width: parent.width
                    interactive: false
                    value: sky.sunUp ? sky.sunAt : (sky.sunAt > 1 ? 1 : 0)
                }
            }
        }

        DashCard {
            width: sky.fourth
            height: parent.height
            glyph: "ocean"
            label: "Humidity"

            // Phainon: the water stands in the card as high as the air is wet
            Rectangle {
                visible: Form.phainon
                x: -14
                anchors.bottom: parent.bottom
                anchors.bottomMargin: -14
                width: parent.width + 28
                height: (parent.height + 38) * (sky.w.humidity ?? 0) / 100
                radius: 14
                color: Theme.withAlpha(Theme.primary, 0.1)
            }

            Reading {
                anchors.verticalCenter: parent.verticalCenter
                value: sky.ok ? sky.w.humidity + "%" : "--"
                note: sky.w.dewPoint !== null && sky.w.dewPoint !== undefined ? "Dew " + WeatherService.formatTemp(Math.round(sky.w.dewPoint)) : ""
            }

            CfBlade {
                visible: !Form.phainon
                anchors.bottom: parent.bottom
                width: parent.width
                meter: true
                value: (sky.w.humidity ?? 0) / 100
                tone: sky.accent
            }
        }

        DashCard {
            width: sky.fourth
            height: parent.height
            glyph: "passage"
            label: "Wind"

            Reading {
                anchors.verticalCenter: parent.verticalCenter
                value: sky.ok ? String(WeatherService.formatSpeed(sky.w.wind, false)) : "--"
                note: String(WeatherService.formatSpeed(0) ?? "").replace(/^[\d.]+\s*/, "") + (sky.compass(sky.w.windDirection) ? "\nfrom " + sky.compass(sky.w.windDirection) : "")
            }

            // Points where the wind is going
            DIcon {
                visible: !Form.reaver && sky.w.windDirection !== null && sky.w.windDirection !== undefined
                anchors.right: parent.right
                anchors.top: parent.top
                name: "navigation"
                size: 18
                rotation: (sky.w.windDirection ?? 0) + 180
                color: Theme.primary
            }
        }
    }

    // The week
    Row {
        id: week
        readonly property real cardWidth: Math.floor((sky.width - 6 * 8) / 7)
        spacing: 8
        height: 112

        Repeater {
            model: sky.days

            DashCard {
                id: day
                required property var modelData
                required property int index
                width: week.cardWidth
                height: parent.height
                highlighted: index === 0 && !Form.reaver

                Column {
                    anchors.centerIn: parent
                    spacing: 5

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: sky.tx(day.index === 0 ? (Form.reaver ? "> today" : "Today") : String(day.modelData.day ?? "").substring(0, 3))
                        font.family: Form.reaver ? Theme.monoFontFamily : Form.display(Theme.fontFamily)
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.DemiBold
                        color: day.index === 0 ? sky.accent : Theme.withAlpha(Theme.surfaceText, 0.7)
                    }

                    DIcon {
                        visible: !Form.reaver
                        anchors.horizontalCenter: parent.horizontalCenter
                        // A day's forecast is the daytime sky, even when the view opens at night
                        name: WeatherService.getWeatherIcon(day.modelData.wCode, true)
                        size: 26
                        color: Theme.primary
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: sky.degrees(day.modelData.tempMax, day.modelData.tempMaxF) + (Form.reaver ? " / " + sky.degrees(day.modelData.tempMin, day.modelData.tempMinF) : "")
                        font.family: sky.numberFont
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.DemiBold
                        color: Theme.surfaceText
                    }

                    StyledText {
                        visible: !Form.reaver
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: sky.degrees(day.modelData.tempMin, day.modelData.tempMinF)
                        font.family: sky.numberFont
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.withAlpha(Theme.surfaceText, 0.55)
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: (Form.reaver ? "rain " : "☂ ") + (day.modelData.precipitationProbability ?? 0) + "%"
                        font.family: sky.numberFont
                        font.pixelSize: 10
                        color: Theme.withAlpha(Theme.surfaceText, 0.5)
                    }
                }
            }
        }
    }
}
