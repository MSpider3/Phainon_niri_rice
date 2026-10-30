import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Widgets

// The desktop layer under the windows: a large clock and one small widget per form, set *into*
// the wallpaper. Each form's wallpaper has a depth mask (overlay/assets/coreflame/depth/, made with
// Depth Anything V2 Small, cut solid with a narrow soft edge). The near layer of the same wallpaper
// is drawn again on top through that mask, so the character really stands in front of the clock.
// Everything is placed in the wallpaper's own coordinates, so it lines up with DMS's "Fill" crop on
// any screen. On a wallpaper that is not the form's own, the widgets show without the depth layer.
PanelWindow {
    id: root

    required property var targetScreen

    // All positions are 0..1 of the wallpaper image; sizes are a share of its shown height.
    // left/baseline: the time; arc: the Phainon sun path (x0, y, x1, y); embers: the Khaslana row's
    // left/top; ledger: the Reaver readout's right/top.
    readonly property var specs: ({
            "phainon": {
                "imageW": 5760,
                "imageH": 3120,
                "left": 0.56019,
                "baseline": 0.64352,
                "dateAbove": true,
                "size": 0.22222,
                "dateSize": 0.03704,
                "arc": [0.70062, 0.37037, 0.94136, 0.37037]
            },
            "khaslana": {
                "imageW": 2048,
                "imageH": 1146,
                "left": 0.12177,
                "baseline": 0.26389,
                "size": 0.2037,
                "dateSize": 0.03519,
                "embers": [0.59844, 0.55556]
            },
            "reaver": {
                "imageW": 4096,
                "imageH": 2171,
                "left": 0.07794,
                "baseline": 0.43426,
                "dateRight": true,
                "size": 0.22222,
                "dateSize": 0.03519,
                "ledger": [0.93188, 0.55556]
            }
        })

    // Not bound to Form.form: the swap waits until the wallpaper transition is over.
    property string shownForm: ""
    Component.onCompleted: shownForm = Form.form
    readonly property var spec: specs[shownForm] ?? null
    Timer {
        id: swapDelay
        interval: Motion.still ? 1 : 1100
        onTriggered: {
            root.shownForm = Form.form;
            root.swapping = false;
            fade.opacity = 1;
        }
    }
    Connections {
        target: Form
        function onFormChanged() {
            root.swapping = true;
            fade.opacity = 0;
            swapDelay.restart();
        }
    }

    // Never cover DMS's wallpaper surface completely: niri stops sending frames to a fully hidden
    // surface, Qt then treats it as unexposed and a wallpaper change freezes half-done.
    // It shares the background layer with the wallpaper, where the surface mapped last is on top:
    // so it maps a moment after start, and unmaps during a form swap (the wallpaper may be redrawn)
    // and in the overview, coming back above the wallpaper each time.
    property bool settled: false
    property bool swapping: false
    Timer {
        id: settle
        running: true
        interval: 1500
        onTriggered: root.settled = true
    }

    // DMS re-creates its wallpaper surface after the screen wakes (outputs reload) or the lock
    // screen ends, which would put the wallpaper over this layer; map again once that is over.
    function remap() {
        settled = false;
        settle.interval = 4000;
        settle.restart();
    }
    Connections {
        target: NiriService
        function onOutputsChanged() {
            root.remap();
        }
    }
    Connections {
        target: IdleService
        function onIsShellLockedChanged() {
            if (!IdleService.isShellLocked)
                root.remap();
        }
    }

    readonly property string wallpaperNow: SessionData.getMonitorWallpaper(targetScreen?.name ?? "")
    readonly property bool depth: !!spec && wallpaperNow === Form.wallpapers[shownForm]
    onDepthChanged: console.info("Coreflame depth clock:", shownForm, depth ? "depth on" : "no depth (" + wallpaperNow + ")")

    // DMS "Fill": the wallpaper scaled to cover the screen, centred.
    readonly property real fillScale: spec ? Math.max(width / spec.imageW, height / spec.imageH) : 1
    readonly property real shownW: spec ? spec.imageW * fillScale : width
    readonly property real shownH: spec ? spec.imageH * fillScale : height
    readonly property real shownX: (width - shownW) / 2
    readonly property real shownY: (height - shownH) / 2
    function toX(u) {
        return shownX + u * shownW;
    }
    function toY(v) {
        return shownY + v * shownH;
    }
    function px(share) {
        return Math.round(share * shownH);
    }

    SystemClock {
        id: clock
        enabled: root.visible
        precision: SystemClock.Minutes
    }
    readonly property date now: clock.date ?? new Date()
    readonly property string timeText: SettingsData.use24HourClock ? now.toLocaleTimeString(Qt.locale(), "HH:mm") : now.toLocaleTimeString(Qt.locale(), "h:mm AP").replace(/\s*[AaPp]\.?[Mm]\.?$/, "")
    readonly property string dateText: {
        if (shownForm === "reaver")
            return now.toLocaleDateString(Qt.locale(), "dddd, d MMMM").toLowerCase();
        const d = now.toLocaleDateString(Qt.locale(), "dddd · d MMMM");
        return shownForm === "khaslana" ? d.toUpperCase() : d;
    }

    // Per form: Phainon in Marcellus, warm white on a lapis glow; Khaslana in Chakra Petch, pale
    // gold with a navy rim; the Flame Reaver in Cormorant italic, bone on a dark violet glow.
    readonly property color ink: shownForm === "khaslana" ? "#FADE8C" : (shownForm === "reaver" ? "#EEE6D4" : "#FFFCF0")
    readonly property color glow: shownForm === "khaslana" ? "#0C0818" : (shownForm === "reaver" ? "#3A1C78" : "#1E3C96")
    readonly property color sunGold: "#F4C542"

    function minutesOf(text, fallback) {
        const m = String(text ?? "").match(/(\d+):(\d+)\s*(AM|PM)?/i);
        if (!m)
            return fallback;
        let h = parseInt(m[1]);
        if (m[3]) {
            const pm = m[3].toUpperCase() === "PM";
            if (pm && h < 12)
                h += 12;
            if (!pm && h === 12)
                h = 0;
        }
        return h * 60 + parseInt(m[2]);
    }

    screen: targetScreen
    visible: settled && !swapping && Form.active && !!spec && !NiriService.inOverview
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    // Clicks go through to the desktop.
    mask: Region {}
    // niri slides bottom-layer surfaces with each workspace, while the wallpaper sits still in the
    // backdrop (the "^quickshell$" place-within-backdrop rule DMS relies on). The same namespace and
    // layer put this in the backdrop too, so the near layer stays on top of the wallpaper it copies.
    WlrLayershell.namespace: "quickshell"
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Item {
        id: fade
        anchors.fill: parent
        Behavior on opacity {
            NumberAnimation {
                duration: Motion.base(300)
            }
        }

        // ── what stands behind the character ──
        Item {
            id: face
            anchors.fill: parent
            visible: false

            Text {
                id: time
                x: root.toX(root.spec?.left ?? 0)
                y: root.toY(root.spec?.baseline ?? 0) - baselineOffset
                text: root.timeText
                color: root.ink
                font.family: root.shownForm === "khaslana" ? "Chakra Petch" : (root.shownForm === "reaver" ? "Cormorant Garamond" : "Marcellus")
                font.italic: root.shownForm === "reaver"
                font.weight: root.shownForm === "khaslana" ? Font.Bold : (root.shownForm === "reaver" ? Font.Medium : Font.Normal)
                font.pixelSize: root.px(root.spec?.size ?? 0.2)
                style: root.shownForm === "khaslana" ? Text.Outline : Text.Normal
                styleColor: "#0E1024"
            }

            Text {
                id: date
                // Flush right under the time where the character's edge would cut its start (Reaver).
                x: root.spec?.dateRight ? time.x + time.width - width : time.x + root.px(0.006)
                // Under the time; above it where the character covers the space below (Phainon).
                y: root.spec?.dateAbove ? time.y + time.baselineOffset - time.font.pixelSize * 0.78 - height : time.y + time.baselineOffset + font.pixelSize * 0.45
                text: root.dateText
                color: root.ink
                font.family: root.shownForm === "khaslana" ? "Cinzel" : (root.shownForm === "reaver" ? "Cormorant Garamond" : "Marcellus")
                font.italic: root.shownForm === "reaver"
                font.pixelSize: root.px(root.spec?.dateSize ?? 0.04)
                font.letterSpacing: root.shownForm === "khaslana" ? 2 : 0.5
                opacity: 0.92
            }
        }

        // The glow that lifts the time and date off the wallpaper; redrawn when the minute changes.
        MultiEffect {
            source: face
            anchors.fill: face
            shadowEnabled: true
            shadowColor: root.glow
            shadowBlur: 1.0
            blurMax: 48
            shadowScale: 1.02
            shadowOpacity: root.shownForm === "khaslana" ? 0.85 : 0.9
            shadowVerticalOffset: root.shownForm === "khaslana" ? 3 : 0
        }

        // ── small widgets, also behind the character ──
        // Phainon: the sun's path over the open sky, sunrise to sunset, a gold sun at now.
        Canvas {
            id: arc
            visible: root.shownForm === "phainon" && !!root.spec?.arc
            readonly property real x0: root.toX(root.spec?.arc?.[0] ?? 0)
            readonly property real x1: root.toX(root.spec?.arc?.[2] ?? 0)
            readonly property real horizon: root.toY(root.spec?.arc?.[1] ?? 0)
            readonly property real r: (x1 - x0) / 2
            readonly property int rise: root.minutesOf(WeatherService.weather.sunrise, 360)
            readonly property int set: root.minutesOf(WeatherService.weather.sunset, 1080)
            readonly property int nowMin: root.now.getHours() * 60 + root.now.getMinutes()
            readonly property bool day: nowMin >= rise && nowMin <= set
            readonly property real frac: Math.max(0, Math.min(1, (nowMin - rise) / Math.max(1, set - rise)))
            x: x0 - 24
            y: horizon - r - 24
            width: r * 2 + 48
            height: r + 48
            onNowMinChanged: requestPaint()
            onRiseChanged: requestPaint()
            onSetChanged: requestPaint()
            onWidthChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const cx = width / 2, cy = height - 24;
                ctx.shadowColor = "#1E3C96";
                ctx.shadowBlur = 10;
                // the whole path, thin; the day so far, bright and thicker
                ctx.strokeStyle = root.sunGold;
                ctx.lineWidth = 2.5;
                ctx.globalAlpha = day ? 0.55 : 0.6;
                ctx.beginPath();
                ctx.arc(cx, cy, r, Math.PI, 2 * Math.PI);
                ctx.stroke();
                if (day) {
                    ctx.lineWidth = 4;
                    ctx.globalAlpha = 1;
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, Math.PI, Math.PI + frac * Math.PI);
                    ctx.stroke();
                }
                // horizon ticks
                ctx.lineWidth = 2.5;
                ctx.globalAlpha = 0.8;
                ctx.beginPath();
                ctx.moveTo(cx - r - 14, cy);
                ctx.lineTo(cx - r + 14, cy);
                ctx.moveTo(cx + r - 14, cy);
                ctx.lineTo(cx + r + 14, cy);
                ctx.stroke();
                // the sun: rides the path by day, waits on the eastern horizon at night
                const a = Math.PI + (day ? frac : 0) * Math.PI;
                const sx = cx + r * Math.cos(a), sy = cy + r * Math.sin(a);
                ctx.globalAlpha = day ? 1 : 0.75;
                ctx.fillStyle = root.sunGold;
                ctx.beginPath();
                ctx.arc(sx, sy, 11, 0, 2 * Math.PI);
                ctx.fill();
                ctx.globalAlpha = day ? 0.35 : 0.15;
                ctx.beginPath();
                ctx.arc(sx, sy, 20, 0, 2 * Math.PI);
                ctx.fill();
            }
        }

        Text {
            visible: arc.visible
            x: arc.x0 - width / 2
            y: arc.horizon + root.px(0.012)
            text: (arc.day ? "" : "rises ") + (WeatherService.weather.sunrise || "--")
            color: root.ink
            font.family: "Marcellus"
            font.pixelSize: root.px(0.024)
        }

        Text {
            visible: arc.visible
            x: arc.x1 - width / 2
            y: arc.horizon + root.px(0.012)
            text: WeatherService.weather.sunset || "--"
            color: root.ink
            font.family: "Marcellus"
            font.pixelSize: root.px(0.024)
        }

        // Khaslana: the twelve Coreflames as embers, lit as the Flame-Chase gathers them.
        Row {
            visible: root.shownForm === "khaslana" && !!root.spec?.embers
            x: root.toX(root.spec?.embers?.[0] ?? 0)
            y: root.toY(root.spec?.embers?.[1] ?? 0)
            spacing: root.px(0.011)

            Repeater {
                model: Coreflames.order

                CfGlyph {
                    required property string modelData
                    readonly property bool lit: Coreflames.has(modelData) && Coreflames.count >= 0
                    name: modelData
                    size: root.px(0.03)
                    strokeWidth: lit ? 2.2 : 1.4
                    color: lit ? "#FF9A3D" : Qt.rgba(0.98, 0.87, 0.55, 0.3)
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: root.px(0.006)
                text: "FLAME-CHASE · " + Coreflames.count + " / 12"
                color: root.ink
                font.family: "Cinzel"
                font.pixelSize: root.px(0.016)
                font.letterSpacing: 1.5
                opacity: 0.85
            }
        }

        // The Flame Reaver: a quiet readout in the night sky over the lake.
        Column {
            visible: root.shownForm === "reaver" && !!root.spec?.ledger
            x: root.toX(root.spec?.ledger?.[0] ?? 0) - width
            y: root.toY(root.spec?.ledger?.[1] ?? 0)
            spacing: root.px(0.004)

            Repeater {
                model: {
                    const w = WeatherService.weather;
                    const player = MprisController.activePlayer;
                    return [w.available ? WeatherService.currentTempText(false) + " " + WeatherService.getWeatherCondition(w.wCode) : "no weather", BatteryService.batteryAvailable ? "battery " + Math.round(BatteryService.batteryLevel) + "%" + (BatteryService.isCharging ? " · charging" : "") : "on mains", "now: " + (player?.trackTitle || "silence")];
                }

                Text {
                    required property string modelData
                    anchors.right: parent.right
                    text: ("// " + modelData).toLowerCase()
                    style: Text.Outline
                    styleColor: "#1A0E33"
                    color: root.ink
                    font.family: Theme.monoFontFamily
                    font.pixelSize: root.px(0.018)
                    opacity: 0.9
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, root.px(0.42))
                    horizontalAlignment: Text.AlignRight
                }
            }
        }

        // ── the near layer of the same wallpaper, in front ──
        Image {
            id: wall
            visible: false
            x: root.shownX
            y: root.shownY
            width: root.shownW
            height: root.shownH
            source: root.depth ? "file://" + root.wallpaperNow : ""
            sourceSize: Qt.size(Math.round(root.shownW), Math.round(root.shownH))
            asynchronous: true
        }

        Image {
            id: near
            visible: false
            x: root.shownX
            y: root.shownY
            width: root.shownW
            height: root.shownH
            source: root.depth ? Qt.resolvedUrl("../../assets/coreflame/depth/" + root.shownForm + "-mask.png") : ""
            sourceSize: Qt.size(Math.round(root.shownW), Math.round(root.shownH))
            asynchronous: true
            cache: false
        }

        MultiEffect {
            visible: root.depth && wall.status === Image.Ready && near.status === Image.Ready
            x: root.shownX
            y: root.shownY
            width: root.shownW
            height: root.shownH
            source: wall
            maskEnabled: true
            maskSource: near
        }
    }
}
