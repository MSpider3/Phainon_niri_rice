import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets
import "../../Common/Format.js" as Format

// The dashboard the island grows into. One summary page; a card opens in place into its full view.
PanelWindow {
    id: dash

    required property var targetScreen
    property int strip: 40

    // "" is the overview; otherwise "music", "weather", "wallpaper", "time", "notifications",
    // "wellbeing" or "network"
    property string view: ""
    onViewChanged: {
        if (view === "weather")
            Coreflames.earn("sky");
    }
    property bool shown: false
    property real opening: shown ? 1 : 0
    readonly property real reveal: Motion.step(opening)

    readonly property MprisPlayer player: MprisController.activePlayer
    readonly property bool playing: !!player && player.playbackState === MprisPlaybackState.Playing
    // Full views are 780 wide; the overview is as wide as the form's layout (DashOverview).
    readonly property real panelWidth: view === "" ? (Form.phainon ? 1160 : 1400) + 36 : 780
    readonly property real col: 240
    readonly property real gap: 12

    function open(which) {
        view = which || "";
        shown = true;
    }

    function close() {
        shown = false;
    }

    function toggle(which) {
        if (shown && view === (which || ""))
            close();
        else
            open(which);
    }

    function tx(text) {
        return Form.reaver ? String(text).toLowerCase() : text;
    }

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

    readonly property real dayFraction: {
        const d = clock.date ?? new Date();
        const now = d.getHours() * 60 + d.getMinutes();
        const rise = minutesOf(WeatherService.weather.sunrise, 360);
        const set = minutesOf(WeatherService.weather.sunset, 1080);
        return Math.max(0, Math.min(1, (now - rise) / Math.max(1, set - rise)));
    }

    screen: targetScreen
    visible: reveal > 0.001
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "coreflame:dashboard"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Behavior on opening {
        NumberAnimation {
            duration: Motion.openMs
            easing.type: Motion.openEasing
            easing.overshoot: 0.8
        }
    }

    // Destroyed while open (a screen unplugged, another theme picked): release what opening took.
    Component.onDestruction: {
        if (shown)
            shown = false;
    }

    onShownChanged: {
        if (shown) {
            DgopService.addRef(["cpu", "memory", "system", "network"]);
            WeatherService.addRef();
            panel.forceActiveFocus();
        } else {
            DgopService.removeRef(["cpu", "memory", "system", "network"]);
            WeatherService.removeRef();
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Keeps the seek position moving, only while the dashboard is open and something plays.
    Timer {
        interval: 1000
        repeat: true
        running: dash.shown && dash.playing
        onTriggered: dash.player?.positionChanged()
    }

    // Click outside to close
    MouseArea {
        anchors.fill: parent
        onClicked: dash.close()
    }

    Item {
        id: panel

        readonly property real fullHeight: dash.strip + body.implicitHeight + 34

        x: Math.round((dash.width - width) / 2)
        width: Math.round(420 + (dash.panelWidth - 420) * dash.reveal)
        height: Math.round(dash.strip + (fullHeight - dash.strip) * dash.reveal)
        clip: true
        focus: true

        Keys.onEscapePressed: {
            if (dash.view !== "")
                dash.view = "";
            else
                dash.close();
        }

        Behavior on width {
            enabled: dash.reveal > 0.99
            NumberAnimation {
                duration: Theme.shortDuration
                easing.type: Easing.OutCubic
            }
        }

        // No frame of its own: the island stays in sight above, and the overview and every full view
        // (DashSheet) draw the form's frame themselves.

        // Swallow clicks so they don't close the dashboard
        MouseArea {
            anchors.fill: parent
        }

        Loader {
            id: body

            // Views that live in their own files
            readonly property var files: ({
                    "music": "DashMusic.qml",
                    "weather": "DashWeather.qml",
                    "notifications": "DashNotifications.qml",
                    "wellbeing": "DashWellbeing.qml",
                    "network": "DashNetwork.qml",
                    "time": "DashTime.qml",
                    "wallpaper": "DashWallpapers.qml"
                })

            x: dash.view === "" ? 18 : 0
            y: dash.strip + 8
            width: dash.view === "" ? dash.panelWidth - 36 : dash.panelWidth
            opacity: dash.reveal
            sourceComponent: body.files[dash.view] ? fileView : overviewView
        }
    }

    // ── overview: the ten cards in the form's layout; each opens its full view ──
    Component {
        id: overviewView

        DashOverview {
            host: dash
            now: clock.date ?? new Date()
        }
    }

    Component {
        id: fileView

        Loader {
            id: fileLoader
            source: Qt.resolvedUrl(body.files[dash.view] ?? "")

            // The sheet's ‹ goes back to the overview
            Connections {
                target: fileLoader.item
                ignoreUnknownSignals: true

                function onBack() {
                    dash.view = "";
                }
            }
        }
    }
}
