import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets
import "LandMask.js" as LandMask

// "Time · Clock": the full time of day, a world clock on a dotted globe (cities found online),
// then the timer and stopwatch. Ticks every second only while the dashboard is on screen.
Column {
    id: time

    function tx(text) {
        return Form.reaver ? String(text).toLowerCase() : text;
    }

    spacing: 12

    readonly property bool onScreen: Window.window?.visible ?? false
    readonly property date now: secs.date ?? new Date()
    readonly property int minuteKey: now.getHours() * 60 + now.getMinutes()

    SystemClock {
        id: secs
        enabled: time.onScreen
        precision: SystemClock.Seconds
    }

    // ── calendar facts ──
    function isoWeek(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        const day = t.getUTCDay() || 7;
        t.setUTCDate(t.getUTCDate() + 4 - day);
        const yearStart = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
        return Math.ceil(((t - yearStart) / 86400000 + 1) / 7);
    }
    function dayOfYear(d) {
        return Math.round((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - new Date(d.getFullYear(), 0, 1)) / 86400000) + 1;
    }
    function daysInYear(y) {
        return (y % 4 === 0 && y % 100 !== 0) || y % 400 === 0 ? 366 : 365;
    }
    // Minutes east of UTC as "UTC+05:30"
    function utcText(minutes) {
        const a = Math.abs(minutes);
        return "UTC" + (minutes < 0 ? "−" : "+") + String(Math.floor(a / 60)).padStart(2, "0") + ":" + String(a % 60).padStart(2, "0");
    }
    readonly property int localOffset: -now.getTimezoneOffset()

    // ── world clock: cities in ~/.config/coreflame/worldclock.json ──
    readonly property var defaultCities: [
        {
            "name": "London",
            "country": "United Kingdom",
            "tz": "Europe/London",
            "lat": 51.51,
            "lon": -0.13
        },
        {
            "name": "New York",
            "country": "United States",
            "tz": "America/New_York",
            "lat": 40.71,
            "lon": -74.01
        },
        {
            "name": "Tokyo",
            "country": "Japan",
            "tz": "Asia/Tokyo",
            "lat": 35.69,
            "lon": 139.69
        }
    ]
    property var cities: []
    // tz -> minutes east of UTC, from the system's time zone data (DST included)
    property var offsets: ({})
    property string zoneName: ""
    readonly property int maxCities: 5
    readonly property var tzPattern: /^[A-Za-z0-9_+\-\/]+$/

    FileView {
        id: cityFile
        path: Form.stateDir + "/worldclock.json"
        printErrors: false
        onLoaded: {
            try {
                const list = JSON.parse(text());
                time.cities = Array.isArray(list) ? list.filter(c => c && time.tzPattern.test(c.tz ?? "") && isFinite(c.lat) && isFinite(c.lon)).slice(0, time.maxCities) : time.defaultCities;
            } catch (e) {
                time.cities = time.defaultCities;
            }
        }
        onLoadFailed: time.cities = time.defaultCities
    }

    function saveCities(list) {
        cities = list;
        cityFile.setText(JSON.stringify(list, null, 2) + "\n");
    }

    function addCity(c) {
        if (cities.length >= maxCities || cities.some(x => x.tz === c.tz && x.name === c.name))
            return;
        saveCities(cities.concat([c]));
        globe.turnTo(c);
    }

    function removeCity(c) {
        saveCities(cities.filter(x => x !== c));
    }

    // Reads every city's current UTC offset (and the local zone's short name) in one call.
    Process {
        id: offsetProc
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                for (const line of text.trim().split("\n")) {
                    const [tz, off] = line.split(" ");
                    const m = /^([+-])(\d\d)(\d\d)$/.exec(off ?? "");
                    if (tz === "@local")
                        time.zoneName = off ?? "";
                    else if (m)
                        map[tz] = (m[1] === "-" ? -1 : 1) * (parseInt(m[2]) * 60 + parseInt(m[3]));
                }
                time.offsets = map;
            }
        }
    }

    function readOffsets() {
        offsetProc.command = ["sh", "-c", "printf '@local %s\\n' \"$(date +%Z)\"; for tz; do printf '%s %s\\n' \"$tz\" \"$(TZ=\"$tz\" date +%z)\"; done", "sh"].concat(cities.map(c => c.tz));
        offsetProc.running = true;
    }
    onCitiesChanged: readOffsets()
    // Offsets move with daylight saving; check again on the hour.
    onMinuteKeyChanged: if (now.getMinutes() === 0)
        readOffsets()

    function cityTime(c) {
        const off = offsets[c.tz];
        if (off === undefined)
            return null;
        return new Date(now.getTime() + (off - localOffset) * 60000);
    }

    // In Qt "h" alone is still the 24-hour hour; the 12-hour clock needs "AP" in the format.
    function clockText(d, withAp) {
        if (!d)
            return "--:--";
        if (SettingsData.use24HourClock)
            return d.toLocaleTimeString(Qt.locale(), "HH:mm");
        const t = d.toLocaleTimeString(Qt.locale(), "h:mm AP");
        return withAp ? t : t.replace(/\s*[AaPp]\.?[Mm]\.?$/, "");
    }

    function cityNote(c) {
        const t = cityTime(c);
        const off = offsets[c.tz];
        if (!t)
            return "";
        const dayDiff = Math.round((new Date(t.getFullYear(), t.getMonth(), t.getDate()) - new Date(now.getFullYear(), now.getMonth(), now.getDate())) / 86400000);
        const diff = off - localOffset;
        const a = Math.abs(diff);
        const shift = diff === 0 ? "same time" : (diff < 0 ? "−" : "+") + Math.floor(a / 60) + (a % 60 ? ":" + String(a % 60).padStart(2, "0") : "") + "h";
        return (dayDiff > 0 ? "Tomorrow · " : (dayDiff < 0 ? "Yesterday · " : "")) + shift;
    }

    // ── city search (Open-Meteo's free geocoding; needs the internet) ──
    property var results: []
    property string searchState: "" // "", "busy", "none", "offline"
    property var searchReq: null

    function search(q) {
        const req = new XMLHttpRequest();
        searchReq = req;
        searchState = "busy";
        req.onreadystatechange = () => {
            if (req.readyState !== XMLHttpRequest.DONE || req !== time.searchReq)
                return;
            if (req.status !== 200) {
                time.results = [];
                time.searchState = "offline";
                return;
            }
            try {
                const found = (JSON.parse(req.responseText).results ?? []).filter(r => time.tzPattern.test(r.timezone ?? "") && isFinite(r.latitude) && isFinite(r.longitude));
                time.results = found.slice(0, 4).map(r => ({
                            "name": r.name,
                            "country": [r.admin1, r.country].filter(Boolean).join(", "),
                            "tz": r.timezone,
                            "lat": r.latitude,
                            "lon": r.longitude
                        }));
                time.searchState = time.results.length ? "" : "none";
            } catch (e) {
                time.results = [];
                time.searchState = "offline";
            }
        };
        req.open("GET", "https://geocoding-api.open-meteo.com/v1/search?count=8&language=en&format=json&name=" + encodeURIComponent(q));
        req.send();
    }

    Timer {
        id: searchDelay
        interval: 450
        onTriggered: time.search(query.text.trim())
    }

    // Per form: Phainon lapis land under gold markers, Khaslana gold plates and ember markers,
    // the Flame Reaver ash dots and violet marks.
    // Phainon's lapis is primary in light mode and secondary in dark; his gold is the calendar's sun.
    readonly property color landColor: Form.phainon ? (Theme.isLightMode ? Theme.primary : Theme.secondary) : Theme.primary
    readonly property color markColor: Form.phainon ? "#E9B92E" : (Form.reaver ? Theme.live : Theme.secondary)
    readonly property string figureFont: Form.reaver || Form.khaslana ? Theme.monoFontFamily : Form.display(Theme.fontFamily)

    component SmallChip: Item {
        id: chip

        property string icon: ""
        property string label: ""
        property bool on: false
        signal clicked

        implicitWidth: chipRow.implicitWidth + 20
        implicitHeight: 30

        CfSurface {
            anchors.fill: parent
            color: chip.on ? Theme.primary : (chipMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer)
            edgeColor: Theme.withAlpha(Theme.outline, 0.5)
            edgeWidth: Form.reaver ? 0 : 1
            lining: false
            radius: 15
        }

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 5

            DIcon {
                visible: chip.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                name: chip.icon
                size: 16
                color: chip.on ? Theme.primaryText : Theme.primary
            }

            StyledText {
                visible: chip.label !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: time.tx(chip.label)
                font.pixelSize: Theme.fontSizeSmall
                color: chip.on ? Theme.primaryText : Theme.surfaceText
            }
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    Row {
        spacing: 12
        height: 238

        // ── the time of day in full ──
        DashCard {
            width: 290
            height: parent.height
            numeral: "I"
            glyph: "time"
            label: "Time · Now"

            CfSigil {
                visible: Form.phainon
                anchors.right: parent.right
                anchors.top: parent.top
                size: 34
                lit: (time.now.getHours() % 12) || 12
                dimColor: Theme.withAlpha(Theme.surfaceText, 0.2)
            }

            Column {
                width: parent.width
                spacing: 3

                Row {
                    spacing: 4

                    StyledText {
                        id: bigTime
                        text: time.clockText(time.now, false)
                        font.family: time.figureFont
                        font.pixelSize: 54
                        font.weight: Font.Bold
                        color: Form.reaver ? Theme.surfaceText : Theme.primary
                    }

                    StyledText {
                        anchors.baseline: bigTime.baseline
                        text: ":" + String(time.now.getSeconds()).padStart(2, "0") + (SettingsData.use24HourClock ? "" : " " + time.now.toLocaleTimeString(Qt.locale(), "AP"))
                        font.family: time.figureFont
                        font.pixelSize: 22
                        font.weight: Font.DemiBold
                        color: Form.reaver ? Theme.live : Theme.withAlpha(Theme.primary, 0.7)
                    }
                }

                StyledText {
                    text: time.tx(time.now.toLocaleDateString(Qt.locale(), "dddd"))
                    font.family: Form.reaver ? Theme.monoFontFamily : Form.display(Theme.fontFamily)
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                    font.letterSpacing: Form.khaslana ? 2 : 0
                    color: Theme.surfaceText
                }

                StyledText {
                    text: time.tx(time.now.toLocaleDateString(Qt.locale(), "d MMMM yyyy"))
                    font.family: Form.reaver ? Theme.monoFontFamily : Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.withAlpha(Theme.surfaceText, 0.85)
                }

                Item {
                    width: 1
                    height: 6
                }

                Repeater {
                    model: [
                        "Week " + time.isoWeek(time.now) + "  ·  Day " + time.dayOfYear(time.now) + " of " + time.daysInYear(time.now.getFullYear()),
                        Form.dawnPeriod(time.now.getHours()),
                        (time.zoneName ? time.zoneName + "  ·  " : "") + time.utcText(time.localOffset)
                    ]

                    StyledText {
                        required property string modelData
                        text: (Form.reaver ? "// " : "") + time.tx(modelData)
                        font.family: Form.phainon ? Theme.fontFamily : Theme.monoFontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.withAlpha(Theme.surfaceText, 0.6)
                    }
                }
            }
        }

        // ── world clock ──
        DashCard {
            width: time.width - 290 - 12
            height: parent.height
            numeral: "II"
            glyph: "passage"
            label: "Passage · World clock"

            Canvas {
                id: globe

                readonly property real radius: Math.min(width, height) / 2 - 2
                property real centerLat: 20
                property real centerLon: -time.now.getTimezoneOffset() / 4
                property var home: WeatherService.location ? {
                    "lat": WeatherService.location.latitude,
                    "lon": WeatherService.location.longitude
                } : null

                function turnTo(c) {
                    centerLat = Math.max(-35, Math.min(35, c.lat));
                    centerLon = c.lon;
                }

                Behavior on centerLon {
                    enabled: !Motion.still
                    NumberAnimation {
                        duration: Motion.base(420)
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on centerLat {
                    enabled: !Motion.still
                    NumberAnimation {
                        duration: Motion.base(420)
                        easing.type: Easing.OutCubic
                    }
                }

                onHomeChanged: if (home)
                    turnTo(home)
                onCenterLonChanged: requestPaint()
                onCenterLatChanged: requestPaint()
                Connections {
                    target: time
                    function onMinuteKeyChanged() {
                        globe.requestPaint();
                    }
                    function onCitiesChanged() {
                        globe.requestPaint();
                    }
                }
                Connections {
                    target: Form
                    function onFormChanged() {
                        globe.requestPaint();
                    }
                }

                width: 192
                height: 192
                anchors.verticalCenter: parent.verticalCenter

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const r = radius, cx = width / 2, cy = height / 2;
                    const rad = Math.PI / 180;
                    const phi0 = centerLat * rad, lam0 = centerLon * rad;
                    const sinP0 = Math.sin(phi0), cosP0 = Math.cos(phi0);

                    // Where the sun stands overhead now (declination, plus the equation of time).
                    const t = new Date();
                    const n = (Date.UTC(t.getUTCFullYear(), t.getUTCMonth(), t.getUTCDate()) - Date.UTC(t.getUTCFullYear(), 0, 0)) / 86400000;
                    const b = 2 * Math.PI * (n - 81) / 364;
                    const eot = 9.87 * Math.sin(2 * b) - 7.53 * Math.cos(b) - 1.5 * Math.sin(b);
                    const dec = -23.44 * Math.cos(2 * Math.PI * (n + 10) / 365) * rad;
                    const utcH = t.getUTCHours() + t.getUTCMinutes() / 60;
                    const sunLon = -15 * (utcH - 12 + eot / 60) * rad;
                    const daylit = (lat, lon) => Math.sin(lat) * Math.sin(dec) + Math.cos(lat) * Math.cos(dec) * Math.cos(lon - sunLon) > 0;

                    // The disc and its rim
                    ctx.globalAlpha = Form.reaver ? 0 : 0.06;
                    ctx.fillStyle = time.landColor;
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                    ctx.fill();
                    ctx.globalAlpha = Form.reaver ? 0.3 : 0.4;
                    ctx.strokeStyle = Form.reaver ? Theme.live : time.landColor;
                    ctx.lineWidth = 1;
                    ctx.stroke();

                    // Land as dots: lit on the day side, dim at night.
                    const step = Form.reaver ? 4 : 5;
                    const dot = Form.reaver ? 1.6 : (Form.khaslana ? 2.6 : 1.5);
                    ctx.fillStyle = time.landColor;
                    for (let py = -r + step / 2; py < r; py += step) {
                        for (let px = -r + step / 2; px < r; px += step) {
                            const x = px / r, y = -py / r;
                            const rho = Math.sqrt(x * x + y * y);
                            if (rho >= 0.985)
                                continue;
                            const c = Math.asin(rho), sinC = Math.sin(c), cosC = Math.cos(c);
                            const lat = rho === 0 ? phi0 : Math.asin(cosC * sinP0 + y * sinC * cosP0 / rho);
                            const lon = lam0 + Math.atan2(x * sinC, rho * cosC * cosP0 - y * sinC * sinP0);
                            const land = LandMask.isLand(lat / rad, ((lon / rad + 540) % 360) - 180);
                            const day = daylit(lat, lon);
                            if (!land) {
                                if (Form.reaver || !day)
                                    continue;
                                ctx.globalAlpha = 0.07;
                            } else {
                                ctx.globalAlpha = day ? (Form.reaver ? 0.85 : 1) : (Form.reaver ? 0.3 : 0.42);
                            }
                            if (Form.phainon) {
                                ctx.beginPath();
                                ctx.arc(cx + px, cy + py, dot, 0, 2 * Math.PI);
                                ctx.fill();
                            } else {
                                ctx.fillRect(cx + px - dot / 2, cy + py - dot / 2, dot, dot);
                            }
                        }
                    }

                    // Cities, and home
                    const project = (latD, lonD) => {
                        const lat = latD * rad, dl = lonD * rad - lam0;
                        const cosc = sinP0 * Math.sin(lat) + cosP0 * Math.cos(lat) * Math.cos(dl);
                        if (cosc <= 0)
                            return null;
                        return [cx + r * Math.cos(lat) * Math.sin(dl), cy - r * (cosP0 * Math.sin(lat) - sinP0 * Math.cos(lat) * Math.cos(dl))];
                    };
                    ctx.globalAlpha = 1;
                    ctx.fillStyle = time.markColor;
                    ctx.strokeStyle = time.markColor;
                    ctx.lineWidth = 1.5;
                    for (const city of time.cities) {
                        const p = project(city.lat, city.lon);
                        if (!p)
                            continue;
                        ctx.beginPath();
                        if (Form.khaslana)
                            ctx.rect(p[0] - 3.5, p[1] - 3.5, 7, 7);
                        else
                            ctx.arc(p[0], p[1], 3.5, 0, 2 * Math.PI);
                        ctx.stroke();
                    }
                    if (home) {
                        const p = project(home.lat, home.lon);
                        if (p) {
                            ctx.beginPath();
                            ctx.arc(p[0], p[1], 3.2, 0, 2 * Math.PI);
                            ctx.fill();
                        }
                    }
                }
            }

            Column {
                id: side
                anchors.left: globe.right
                anchors.leftMargin: 14
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: 2

                readonly property bool searching: query.text.trim().length > 0

                // Saved cities: click one to turn the globe to it.
                Repeater {
                    model: side.searching ? [] : time.cities

                    Item {
                        id: cityRow
                        required property var modelData
                        width: side.width
                        height: 30

                        HoverHandler {
                            id: rowHover
                        }

                        TapHandler {
                            onTapped: globe.turnTo(cityRow.modelData)
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - cityClock.width - 26

                            StyledText {
                                width: parent.width
                                elide: Text.ElideRight
                                text: time.tx(cityRow.modelData.name)
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.DemiBold
                                color: Theme.surfaceText
                            }

                            StyledText {
                                width: parent.width
                                elide: Text.ElideRight
                                text: time.tx(time.cityNote(cityRow.modelData))
                                font.pixelSize: 10
                                color: Theme.withAlpha(Theme.surfaceText, 0.55)
                            }
                        }

                        StyledText {
                            id: cityClock
                            anchors.right: parent.right
                            anchors.rightMargin: 22
                            anchors.verticalCenter: parent.verticalCenter
                            text: time.clockText(time.cityTime(cityRow.modelData), true)
                            font.family: time.figureFont
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                            color: time.markColor
                        }

                        DIcon {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            visible: rowHover.hovered
                            name: "close"
                            size: 15
                            color: Theme.withAlpha(Theme.surfaceText, 0.6)

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: time.removeCity(cityRow.modelData)
                            }
                        }
                    }
                }

                // Search results
                Repeater {
                    model: side.searching ? time.results : []

                    Item {
                        id: resultRow
                        required property var modelData
                        width: side.width
                        height: 30

                        HoverHandler {
                            id: resultHover
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: {
                                time.addCity(resultRow.modelData);
                                query.text = "";
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width

                            StyledText {
                                width: parent.width
                                elide: Text.ElideRight
                                text: time.tx(resultRow.modelData.name)
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.DemiBold
                                color: resultHover.hovered ? Theme.primary : Theme.surfaceText
                            }

                            StyledText {
                                width: parent.width
                                elide: Text.ElideRight
                                text: time.tx(resultRow.modelData.country + "  ·  " + resultRow.modelData.tz)
                                font.pixelSize: 10
                                color: Theme.withAlpha(Theme.surfaceText, 0.55)
                            }
                        }
                    }
                }

                StyledText {
                    visible: side.searching ? time.searchState !== "" : time.cities.length === 0
                    width: side.width
                    wrapMode: Text.WordWrap
                    text: time.tx(!side.searching ? "No cities yet. Search below." : ({
                                "busy": "Searching…",
                                "none": "No place by that name.",
                                "offline": "Can't reach the search. Check the connection."
                            })[time.searchState] ?? "")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.withAlpha(Theme.surfaceText, 0.55)
                }
            }

            // Add a city
            Item {
                anchors.left: side.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 30
                visible: time.cities.length < time.maxCities || side.searching

                CfSurface {
                    anchors.fill: parent
                    color: Theme.surfaceContainer
                    edgeColor: query.activeFocus ? Theme.primary : Theme.withAlpha(Theme.outline, 0.5)
                    edgeWidth: 1
                    lining: false
                    radius: 15
                }

                DIcon {
                    id: searchIcon
                    x: 9
                    anchors.verticalCenter: parent.verticalCenter
                    name: "travel_explore"
                    size: 16
                    color: Theme.withAlpha(Theme.surfaceText, 0.6)
                }

                TextInput {
                    id: query
                    anchors.left: searchIcon.right
                    anchors.leftMargin: 6
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                    color: Theme.surfaceText
                    selectionColor: Theme.primary
                    onTextChanged: {
                        time.results = [];
                        time.searchState = text.trim().length >= 2 ? "busy" : "";
                        if (text.trim().length >= 2)
                            searchDelay.restart();
                        else
                            searchDelay.stop();
                    }
                    Keys.onEscapePressed: event => {
                        if (text !== "") {
                            text = "";
                            event.accepted = true;
                        } else {
                            event.accepted = false;
                        }
                    }
                    Keys.onReturnPressed: {
                        if (time.results.length) {
                            time.addCity(time.results[0]);
                            text = "";
                        }
                    }

                    StyledText {
                        visible: query.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: time.tx("Add a city…")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.withAlpha(Theme.surfaceText, 0.4)
                    }
                }
            }
        }
    }

    Row {
        spacing: 12
        height: 150

        // ── timer ──
        DashCard {
            width: (time.width - 12) / 2
            height: parent.height
            numeral: "III"
            glyph: "time"
            label: "Timer"

            Column {
                width: parent.width
                spacing: 8

                Item {
                    width: parent.width
                    height: timerFigure.height

                    StyledText {
                        id: timerFigure
                        text: Chrono.format(Chrono.timerLeft)
                        font.family: Form.phainon ? Theme.fontFamily : Theme.monoFontFamily
                        font.pixelSize: 34
                        font.weight: Font.DemiBold
                        color: Chrono.timerActive ? (Form.reaver ? Theme.live : Theme.primary) : Theme.withAlpha(Theme.surfaceText, 0.5)
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        SmallChip {
                            icon: Chrono.timerRunning ? "pause" : "play_arrow"
                            on: Chrono.timerRunning
                            onClicked: Chrono.toggleTimer()
                        }

                        SmallChip {
                            icon: "restart_alt"
                            onClicked: Chrono.resetTimer()
                        }
                    }
                }

                CfBlade {
                    meter: true
                    width: parent.width
                    value: Chrono.timerTotal > 0 ? Chrono.timerLeft / Chrono.timerTotal : 0
                }

                Row {
                    spacing: 6

                    Repeater {
                        model: [5, 15, 25, 45, 60]

                        SmallChip {
                            required property int modelData
                            label: modelData + " min"
                            onClicked: Chrono.startTimer(modelData * 60)
                        }
                    }
                }
            }
        }

        // ── stopwatch ──
        DashCard {
            width: (time.width - 12) / 2
            height: parent.height
            numeral: "IV"
            glyph: "time"
            label: "Stopwatch"

            Column {
                width: parent.width
                spacing: 12

                StyledText {
                    text: Chrono.format(Chrono.stopwatchSeconds)
                    font.family: Form.phainon ? Theme.fontFamily : Theme.monoFontFamily
                    font.pixelSize: 34
                    font.weight: Font.DemiBold
                    color: Chrono.stopwatchRunning ? (Form.reaver ? Theme.live : Theme.primary) : Theme.surfaceText
                }

                Row {
                    spacing: 6

                    SmallChip {
                        icon: Chrono.stopwatchRunning ? "pause" : "play_arrow"
                        label: Chrono.stopwatchRunning ? "Stop" : "Start"
                        on: Chrono.stopwatchRunning
                        onClicked: Chrono.toggleStopwatch()
                    }

                    SmallChip {
                        icon: "restart_alt"
                        label: "Reset"
                        onClicked: Chrono.resetStopwatch()
                    }
                }
            }
        }
    }
}
