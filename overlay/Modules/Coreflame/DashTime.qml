import QtQuick
import QtQuick.Shapes
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
// The hour's name stays on the island; the facts here are the week, the day of the year and the zone.
//   Phainon: lapis land in dots under gold markers, round preset pills.
//   Khaslana: gold plates for land, ember diamonds for cities, the time with its red echo.
//   Flame Reaver: ash dots for land, violet crosses for cities, lower case with // facts.
DashSheet {
    id: time

    title: "Time · Clock"
    glyph: "time"

    // [x, y, w, h] of the four cards in body coordinates
    readonly property var lay: ph ? ({
            now: [0, 0, 368, 232],
            world: [380, 0, 368, 232],
            timer: [0, 244, 368, 160],
            stopwatch: [380, 244, 368, 160]
        }) : kh ? ({
            now: [0, 0, spanW(2), 236],
            world: [colX(2), 0, bodyWidth - colX(2), 236],
            timer: [0, 241, spanW(2), 150],
            stopwatch: [colX(2), 241, bodyWidth - colX(2), 150]
        }) : ({
            now: [0, 0, 360, 250],
            world: [374, 0, 406, 250],
            timer: [0, 264, 430, 180],
            stopwatch: [444, 264, 336, 180]
        })

    bodyHeight: Math.max(...Object.values(lay).map(r => r[1] + r[3]))
    blocks: kh ? ["now", "world", "timer", "stopwatch"].map((k, i) => lay[k].concat([i === 0])) : []

    readonly property bool onScreen: Window.window?.visible ?? false
    readonly property date now: secs.date ?? new Date()
    readonly property int minuteKey: now.getHours() * 60 + now.getMinutes()

    SystemClock {
        id: secs
        enabled: time.onScreen
        precision: SystemClock.Seconds
    }

    CfInk {
        id: ink
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

    // ── the form's pieces ──

    // Body text in the form's ink
    component Ink: Text {
        property bool mut: false
        font.family: ink.font
        font.pixelSize: 14
        color: mut ? ink.muted : ink.text
    }

    // A big reading (`.val`): Khaslana's carries a red echo to the right, the Reaver's a split glow
    component Val: Item {
        id: val
        property string text: ""
        property int size: time.ph ? 44 : (time.kh ? 38 : 40)
        implicitWidth: face.implicitWidth + (time.kh ? 4 : 2)
        implicitHeight: Math.round(size * 1.1)
        baselineOffset: face.y + face.baselineOffset

        Repeater {
            model: time.kh ? [[val.size > 60 ? 4 : 3, "#8E1424"]] : (time.rv ? [[2, "#D98F7BE0"], [-2, "#8C4FD1C5"]] : [])

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
            font.italic: time.rv
            color: time.ph ? "#334786" : (time.kh ? "#F5D27A" : (val.size > 60 ? "#E9E7F2" : "#CFC6A8"))
        }
    }

    // A choice: a paper pill in Phainon, a cut gold plate in Khaslana, a slab with a left edge in
    // the Reaver.
    component Chip: Item {
        id: chip

        property string text: ""
        property bool on: false
        signal clicked

        implicitWidth: chipText.implicitWidth + 28
        implicitHeight: time.ph ? 28 : 26

        Rectangle {
            visible: time.ph
            anchors.fill: parent
            radius: height / 2
            color: chip.on ? "#334786" : (chipMouse.containsMouse ? "#FFFDF7" : "#FBF9F3")
            border.width: 1
            border.color: chip.on ? "#334786" : "#C8B27E"
        }

        CfQuad {
            visible: time.kh
            anchors.fill: parent
            points: [[0, 0], [1, 0], [1, 0.68], [1 - 8 / Math.max(8, chip.width), 1], [0, 1]]
            fill: chip.on ? "#E0B04A" : (chipMouse.containsMouse ? "#2A1015" : "transparent")
            stroke: "#E0B04A"
            strokeWidth: 1
        }

        Rectangle {
            visible: time.rv
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
            anchors.horizontalCenterOffset: time.rv ? 1 : 0
            text: time.rv ? (chip.on ? "> " : "") + chip.text.toLowerCase() : (time.kh ? chip.text.toUpperCase() : chip.text)
            font.family: time.kh ? "Cinzel" : ink.font
            font.pixelSize: time.kh ? 12 : 14
            font.weight: time.kh ? Font.DemiBold : Font.Normal
            font.letterSpacing: time.kh ? 1.7 : 0
            color: time.ph ? (chip.on ? "#F7F3E8" : "#334786") : (time.kh ? (chip.on ? "#0B080B" : "#F5D27A") : (chip.on ? "#E9E7F2" : "#A8A4BC"))
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    // A card of the view, placed from `lay`; Khaslana's mosaic draws the block under it
    component Cell: DashCard {
        property string at: ""
        readonly property var r: time.lay[at] ?? [0, 0, 0, 0]
        x: r[0]
        y: r[1]
        width: r[2]
        height: r[3]
        bare: time.kh
        flute: false
    }

    // Khaslana: the red corner stamped into the hero block
    Item {
        visible: time.kh
        x: time.lay.now[0] + time.lay.now[2] - 46
        y: time.lay.now[1] + time.lay.now[3] - 46
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
            x: 32
            width: 14
            height: 46
            color: "#C2252F"
        }
        Rectangle {
            y: 32
            width: 46
            height: 14
            color: "#8E1424"
        }
    }

    // ── the time of day in full ──
    Cell {
        at: "now"
        label: "I · Time · Now"
        glyph: "time"
        poly: [[0, 0], [1, 0.03], [0.97, 1], [0.02, 0.94]]

        Column {
            width: parent.width
            spacing: 2

            Row {
                spacing: 4

                Val {
                    id: bigTime
                    text: time.clockText(time.now, false)
                    size: time.ph ? 80 : (time.kh ? 96 : 84)
                }

                Val {
                    anchors.baseline: bigTime.baseline
                    text: ":" + String(time.now.getSeconds()).padStart(2, "0") + (SettingsData.use24HourClock ? "" : " " + time.now.toLocaleTimeString(Qt.locale(), "AP"))
                    size: time.kh ? 28 : 26
                }
            }

            Text {
                text: time.kh ? time.now.toLocaleDateString(Qt.locale(), "dddd").toUpperCase() : ink.tx(time.now.toLocaleDateString(Qt.locale(), "dddd"))
                font.family: time.ph ? "Marcellus" : (time.kh ? "Cinzel" : "Chakra Petch")
                font.pixelSize: time.ph ? 24 : (time.kh ? 22 : 15)
                font.weight: time.kh ? Font.Bold : Font.Normal
                font.letterSpacing: time.kh ? 3.5 : 0
                color: ink.text
            }

            Ink {
                mut: true
                text: ink.tx(time.now.toLocaleDateString(Qt.locale(), "d MMMM yyyy"))
                font.pixelSize: time.ph ? 18 : 15
            }

            Item {
                width: 1
                height: 6
            }

            Repeater {
                readonly property var facts: ["Week " + time.isoWeek(time.now) + " · Day " + time.dayOfYear(time.now) + " of " + time.daysInYear(time.now.getFullYear()), (time.zoneName ? time.zoneName + " · " : "") + time.utcText(time.localOffset)]
                model: time.kh ? [facts.join(" · ")] : facts

                Ink {
                    required property string modelData
                    width: parent.width
                    elide: Text.ElideRight
                    mut: true
                    text: (time.rv ? "// " : "") + ink.tx(modelData)
                    font.pixelSize: 13
                }
            }
        }
    }

    // ── world clock ──
    Cell {
        at: "world"
        label: "II · Passage · World clock"
        glyph: "passage"
        poly: [[0.04, 0], [1, 0], [0.96, 1], [0, 0.88]]

        Item {
            id: clockArea
            width: parent.width
            height: parent.height - addCity.height - 8

            Canvas {
                id: globe

                readonly property real radius: width / 2 - 2
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

                width: time.ph ? 120 : (time.kh ? 110 : 100)
                height: width
                anchors.verticalCenter: parent.verticalCenter

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const r = radius, cx = width / 2, cy = height / 2;
                    // the mockup draws the globe on a 200-unit square
                    const u = width / 200;
                    const rad = Math.PI / 180;
                    const phi0 = centerLat * rad, lam0 = centerLon * rad;
                    const sinP0 = Math.sin(phi0), cosP0 = Math.cos(phi0);
                    const ph = time.ph, kh = time.kh;

                    // Where the sun stands overhead now (declination, plus the equation of time).
                    const t = new Date();
                    const n = (Date.UTC(t.getUTCFullYear(), t.getUTCMonth(), t.getUTCDate()) - Date.UTC(t.getUTCFullYear(), 0, 0)) / 86400000;
                    const b = 2 * Math.PI * (n - 81) / 364;
                    const eot = 9.87 * Math.sin(2 * b) - 7.53 * Math.cos(b) - 1.5 * Math.sin(b);
                    const dec = -23.44 * Math.cos(2 * Math.PI * (n + 10) / 365) * rad;
                    const utcH = t.getUTCHours() + t.getUTCMinutes() / 60;
                    const sunLon = -15 * (utcH - 12 + eot / 60) * rad;
                    const daylit = (lat, lon) => Math.sin(lat) * Math.sin(dec) + Math.cos(lat) * Math.cos(dec) * Math.cos(lon - sunLon) > 0;

                    // The disc and its rim: parchment, obsidian ringed in gold, or dark glass in a dashed ash ring
                    ctx.fillStyle = ph ? "#EFE6CC" : (kh ? "#140C0F" : "#0D0B14");
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                    ctx.fill();
                    ctx.strokeStyle = ph ? "#C8B27E" : (kh ? "#E0B04A" : "#5C5478");
                    ctx.lineWidth = kh ? 1.5 : 1;
                    if (time.rv) {
                        const dash = 6 / 96, gap = 3 / 96;
                        for (let a = 0; a < 2 * Math.PI; a += dash + gap) {
                            ctx.beginPath();
                            ctx.arc(cx, cy, r, a, Math.min(a + dash, 2 * Math.PI));
                            ctx.stroke();
                        }
                    } else {
                        ctx.stroke();
                    }

                    // Land as dots, lit on the day side and dim at night.
                    const step = 7 * u;
                    const dot = (ph ? 1.7 : (kh ? 2 : 1.2)) * u;
                    ctx.fillStyle = ph ? "#334786" : (kh ? "#E0B04A" : "#A8A4BC");
                    for (let py = -r + step / 2; py < r; py += step) {
                        for (let px = -r + step / 2; px < r; px += step) {
                            const x = px / r, y = -py / r;
                            const rho = Math.sqrt(x * x + y * y);
                            if (rho >= 0.97)
                                continue;
                            const c = Math.asin(rho), sinC = Math.sin(c), cosC = Math.cos(c);
                            const lat = rho === 0 ? phi0 : Math.asin(cosC * sinP0 + y * sinC * cosP0 / rho);
                            const lon = lam0 + Math.atan2(x * sinC, rho * cosC * cosP0 - y * sinC * sinP0);
                            if (!LandMask.isLand(lat / rad, ((lon / rad + 540) % 360) - 180))
                                continue;
                            ctx.globalAlpha = daylit(lat, lon) ? 1 : (ph ? 0.4 : 0.3);
                            if (kh) {
                                ctx.fillRect(cx + px - dot, cy + py - dot, 2 * dot, 2 * dot);
                            } else {
                                ctx.beginPath();
                                ctx.arc(cx + px, cy + py, Math.max(0.6, dot), 0, 2 * Math.PI);
                                ctx.fill();
                            }
                        }
                    }

                    // Cities, and home larger: gold dots, ember diamonds or violet crosses
                    const project = (latD, lonD) => {
                        const lat = latD * rad, dl = lonD * rad - lam0;
                        const cosc = sinP0 * Math.sin(lat) + cosP0 * Math.cos(lat) * Math.cos(dl);
                        if (cosc <= 0)
                            return null;
                        return [cx + r * Math.cos(lat) * Math.sin(dl), cy - r * (cosP0 * Math.sin(lat) - sinP0 * Math.cos(lat) * Math.cos(dl))];
                    };
                    const mark = (p, big) => {
                        const s = (big ? 1.4 : 1) * 4.5 * u;
                        ctx.beginPath();
                        if (ph) {
                            ctx.fillStyle = big ? "#F1DA4F" : "#A87A22";
                            ctx.arc(p[0], p[1], Math.max(2, s), 0, 2 * Math.PI);
                            ctx.fill();
                            if (big) {
                                ctx.strokeStyle = "#A87A22";
                                ctx.lineWidth = 1;
                                ctx.stroke();
                            }
                        } else if (kh) {
                            const d = Math.max(2.5, s * 1.3);
                            ctx.fillStyle = big ? "#E2434E" : "#C2252F";
                            ctx.moveTo(p[0], p[1] - d);
                            ctx.lineTo(p[0] + d * 0.8, p[1]);
                            ctx.lineTo(p[0], p[1] + d);
                            ctx.lineTo(p[0] - d * 0.8, p[1]);
                            ctx.closePath();
                            ctx.fill();
                        } else {
                            const d = Math.max(2.5, s);
                            ctx.strokeStyle = big ? "#B9A8FF" : "#8F7BE0";
                            ctx.lineWidth = big ? 2 : 1.5;
                            ctx.moveTo(p[0] - d, p[1] - d);
                            ctx.lineTo(p[0] + d, p[1] + d);
                            ctx.moveTo(p[0] + d, p[1] - d);
                            ctx.lineTo(p[0] - d, p[1] + d);
                            ctx.stroke();
                        }
                    };
                    ctx.globalAlpha = 1;
                    for (const city of time.cities) {
                        const p = project(city.lat, city.lon);
                        if (p)
                            mark(p, false);
                    }
                    const hp = home ? project(home.lat, home.lon) : null;
                    if (hp)
                        mark(hp, true);
                }
            }

            Column {
                id: side
                anchors.left: globe.right
                anchors.leftMargin: time.ph ? 12 : 10
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                readonly property bool searching: query.text.trim().length > 0
                readonly property int rowHeight: Math.min(46, Math.floor(clockArea.height / Math.max(3, searching ? time.results.length : time.cities.length)))
                readonly property color rule: time.ph ? "#ECE3CC" : (time.kh ? "#3A1A1E" : "#2C2840")

                // Saved cities (click one to turn the globe to it), or the search's finds (click to add)
                Repeater {
                    model: side.searching ? time.results : time.cities

                    Item {
                        id: cityRow
                        required property var modelData
                        readonly property bool found: side.searching
                        width: side.width
                        height: side.rowHeight

                        HoverHandler {
                            id: rowHover
                            cursorShape: cityRow.found ? Qt.PointingHandCursor : Qt.ArrowCursor
                        }

                        TapHandler {
                            onTapped: {
                                if (!cityRow.found) {
                                    globe.turnTo(cityRow.modelData);
                                    return;
                                }
                                time.addCity(cityRow.modelData);
                                query.text = "";
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: side.rule
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - (cityRow.found ? 0 : cityClock.width + 30)

                            Ink {
                                width: parent.width
                                elide: Text.ElideRight
                                text: ink.tx(cityRow.modelData.name)
                                color: cityRow.found && rowHover.hovered ? ink.accent : ink.text
                            }

                            Ink {
                                width: parent.width
                                elide: Text.ElideRight
                                text: ink.tx(cityRow.found ? cityRow.modelData.country + " · " + cityRow.modelData.tz : time.cityNote(cityRow.modelData))
                                font.pixelSize: 12
                                opacity: 0.7
                            }
                        }

                        Text {
                            id: cityClock
                            visible: !cityRow.found
                            anchors.right: parent.right
                            anchors.rightMargin: 26
                            anchors.verticalCenter: parent.verticalCenter
                            text: time.clockText(time.cityTime(cityRow.modelData), true)
                            font.family: Form.numerals
                            font.pixelSize: 20
                            font.italic: time.rv
                            color: time.ph ? "#334786" : (time.kh ? "#F5D27A" : "#CFC6A8")
                        }

                        Text {
                            visible: !cityRow.found
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            horizontalAlignment: Text.AlignHCenter
                            text: time.kh ? "✕" : "×"
                            font.family: ink.font
                            font.pixelSize: 14
                            color: ink.text
                            opacity: rowHover.hovered ? 0.9 : 0.55

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: time.removeCity(cityRow.modelData)
                            }
                        }
                    }
                }

                Ink {
                    visible: side.searching ? time.searchState !== "" : time.cities.length === 0
                    width: side.width
                    wrapMode: Text.WordWrap
                    mut: true
                    text: ink.tx(!side.searching ? "No cities yet. Search below." : ({
                            "busy": "Searching…",
                            "none": "No place by that name.",
                            "offline": "Can't reach the search. Check the connection."
                        })[time.searchState] ?? "")
                    font.pixelSize: 13
                }
            }
        }

        // Add a city: a paper pill, a cut gold plate, or a bare prompt for the Reaver
        Item {
            id: addCity
            anchors.bottom: parent.bottom
            width: parent.width
            height: time.rv ? 24 : 30
            visible: time.cities.length < time.maxCities || side.searching

            Rectangle {
                visible: time.ph
                anchors.fill: parent
                radius: height / 2
                color: "#FBF9F3"
                border.width: 1
                border.color: query.activeFocus ? "#334786" : "#C8B27E"
            }

            CfQuad {
                visible: time.kh
                anchors.fill: parent
                points: [[0, 0], [1, 0], [1, 0.68], [1 - 8 / Math.max(8, addCity.width), 1], [0, 1]]
                stroke: query.activeFocus ? "#F5D27A" : "#E0B04A"
                strokeWidth: 1
            }

            DIcon {
                id: searchIcon
                visible: time.ph
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                name: "search"
                size: 16
                color: "#334786"
            }

            Text {
                id: prompt
                visible: !time.ph
                x: time.kh ? 12 : 0
                anchors.verticalCenter: parent.verticalCenter
                text: time.kh ? "⌕" : ">"
                font.family: ink.font
                font.pixelSize: 14
                color: time.kh ? "#F5D27A" : ink.muted
            }

            TextInput {
                id: query
                anchors.left: time.ph ? searchIcon.right : prompt.right
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                clip: true
                font.family: ink.font
                font.pixelSize: 13
                color: ink.text
                selectionColor: time.ph ? "#334786" : (time.kh ? "#8E1424" : "#2E2650")
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

                Text {
                    visible: query.text === ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: time.kh ? "ADD A CITY…" : ink.tx("Add a city…") + (time.rv ? "_" : "")
                    font.family: time.kh ? "Cinzel" : ink.font
                    font.pixelSize: time.kh ? 12 : 13
                    font.weight: time.kh ? Font.DemiBold : Font.Normal
                    font.letterSpacing: time.kh ? 1.7 : 0
                    color: time.kh ? "#F5D27A" : ink.muted
                }
            }
        }
    }

    // ── timer ──
    Cell {
        at: "timer"
        label: "III · Timer"
        glyph: "time"
        poly: [[0, 0.06], [1, 0], [0.98, 1], [0.03, 0.95]]

        Column {
            width: parent.width
            spacing: 8

            Item {
                width: parent.width
                height: timerFigure.height

                Val {
                    id: timerFigure
                    text: Chrono.format(Chrono.timerLeft)
                    size: time.ph ? 44 : (time.kh ? 38 : 40)
                }

                // Pause and reset while a timer is set
                Row {
                    visible: Chrono.timerActive
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Chip {
                        text: Chrono.timerRunning ? "Pause" : "Resume"
                        on: true
                        onClicked: Chrono.toggleTimer()
                    }

                    Chip {
                        text: "Reset"
                        onClicked: Chrono.resetTimer()
                    }
                }
            }

            Flow {
                width: parent.width
                spacing: 8

                Repeater {
                    model: [5, 15, 25, 45, 60]

                    Chip {
                        required property int modelData
                        text: modelData + " min"
                        on: Chrono.timerActive && Chrono.timerTotal === modelData * 60
                        onClicked: Chrono.startTimer(modelData * 60)
                    }
                }
            }
        }
    }

    // ── stopwatch ──
    Cell {
        at: "stopwatch"
        label: "IV · Stopwatch"
        glyph: "time"
        poly: [[0.02, 0.04], [1, 0], [0.97, 0.96], [0, 1]]

        Column {
            width: parent.width
            spacing: 8

            Val {
                text: Chrono.format(Chrono.stopwatchSeconds)
                size: time.ph ? 44 : (time.kh ? 38 : 40)
            }

            Row {
                spacing: 8

                Chip {
                    text: Chrono.stopwatchRunning ? "Stop" : "Start"
                    on: true
                    onClicked: Chrono.toggleStopwatch()
                }

                Chip {
                    text: "Reset"
                    onClicked: Chrono.resetStopwatch()
                }
            }
        }
    }
}
