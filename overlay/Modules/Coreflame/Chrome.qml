import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import qs.Common
import qs.Services
import qs.Widgets

// The Coreflame top of screen: a window-manager tab in the left corner, a control tab in the
// right corner, and the island between them. One transparent surface per screen; only the
// three pieces take input. It stands in for the stock bar, so popouts and IPC anchor to it.
PanelWindow {
    id: win

    required property var modelData
    readonly property int strip: 40
    readonly property var barConfig: SettingsData.barConfigs.length > 0 ? SettingsData.barConfigs[0] : null

    // The same hooks the stock bar offers, so `dms ipc call control-center|dankdash ...` keep working.
    readonly property var controlCenterButtonRef: rightCorner
    readonly property var clockButtonRef: island
    readonly property var systemUpdateButtonRef: null

    screen: modelData
    WlrLayershell.namespace: "coreflame:chrome"
    // Over a fullscreen app the chrome is hidden, except that the island rises above it for a
    // moment to show volume, brightness or a critical notification, then sinks back.
    readonly property bool fullscreenShowing: (ToplevelManager.toplevels?.values ?? []).some(t => t.fullscreen && t.activated)
    readonly property bool raised: fullscreenShowing && (island.busy || island.toast?.urgency === NotificationUrgency.Critical)
    WlrLayershell.layer: raised ? WlrLayer.Overlay : WlrLayer.Top
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: strip + 8
    exclusiveZone: strip
    color: "transparent"
    mask: Region {
        Region {
            item: leftCorner
        }
        Region {
            item: island
        }
        Region {
            item: rightCorner
        }
    }

    function place(popout, item, section) {
        if (!popout.setTriggerPosition) {
            popout.triggerScreen = win.screen;
            return;
        }
        const screenPos = item.mapToItem(null, 0, 0);
        const pos = SettingsData.getPopupTriggerPosition(screenPos, win.screen, win.strip, item.width, 4, 0, barConfig);
        popout.setTriggerPosition(pos.x, pos.y, pos.width, section, win.screen, 0, win.strip, 4, barConfig);
    }

    function triggerControlCenter() {
        controlLoader.active = true;
        controlLoader.item?.toggle();
    }

    function positionDash(popout, position) {
        place(popout, island, "center");
        return "center";
    }

    // The Coreflame dashboard grows out of the island. Stock tab names map onto its views.
    function triggerDashTab(tabId, position) {
        const views = {
            "overview": "",
            "media": "music",
            "wallpaper": "wallpaper",
            "weather": "weather"
        };
        dashLoader.active = true;
        if (!dashLoader.item)
            return false;
        dashLoader.item.toggle(views[tabId] ?? "");
        return true;
    }

    // Notifications live in the control panel's collapsible section.
    function triggerNotifications() {
        controlLoader.active = true;
        if (!controlLoader.item)
            return;
        controlLoader.item.notificationsOpen = true;
        controlLoader.item.toggle();
    }

    function triggerWallpaperBrowser() {
        triggerDashTab("wallpaper");
    }

    function triggerSystemUpdate() {
    }

    Component.onCompleted: Form.registerChrome(win)
    Component.onDestruction: Form.unregisterChrome(win)

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Fail-safe from the inside: on the real session, if the shell still has no connection to the
    // DMS backend half a minute after starting, hand back to stock DMS.
    Timer {
        interval: 30000
        running: (Quickshell.env("DMS_SHELL_DIR") ?? "") !== "" && !Form.startupChecked
        onTriggered: {
            Form.startupChecked = true;
            if (!DMSService.isConnected)
                Quickshell.execDetached(["systemctl", "--user", "start", "coreflame-fallback.service"]);
        }
    }

    // The transformation: one short full-screen moment when the form changes, then it unloads.
    LazyLoader {
        id: transformLoader

        Transformation {
            targetScreen: win.screen
            onFinished: transformLoader.active = false
        }
    }

    // The Flame-Chase: the events only this shell can see. The first screen reports them.
    readonly property bool lead: Form.chromes[0] === win
    readonly property bool fullCharge: BatteryService.batteryAvailable && BatteryService.isPluggedIn && BatteryService.batteryLevel >= 100
    onFullChargeChanged: {
        if (fullCharge && lead)
            Coreflames.earn("earth");
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        blockLoading: true
        printErrors: false
    }

    Connections {
        target: clock
        enabled: win.lead && !Coreflames.has("time")

        function onDateChanged() {
            uptimeFile.reload();
            if (parseFloat(uptimeFile.text()) >= 6 * 3600)
                Coreflames.earn("time");
        }
    }

    // Irontomb warnings: the battery nearly out, or the CPU close to its limit. A red-on-black
    // island alert and breaking glass, at most once every ten minutes.
    readonly property bool batteryCritical: BatteryService.batteryAvailable && !BatteryService.isPluggedIn && BatteryService.batteryLevel <= 5
    readonly property bool overheated: Chimera.temp >= 97
    property real lastIrontomb: 0
    onBatteryCriticalChanged: {
        if (batteryCritical)
            irontomb("Battery " + Math.round(BatteryService.batteryLevel) + "%", "The Coreflame is guttering");
    }
    onOverheatedChanged: {
        if (overheated)
            irontomb("CPU " + Math.round(Chimera.temp) + "°", "Irontomb stirs: let it cool");
    }

    function irontomb(title, sub) {
        // Not marked as shown until the island can actually show it (it is not ready for the
        // first seconds after start), so a warning at login is not lost.
        if (!lead || !island.ready || Date.now() - lastIrontomb < 600000)
            return;
        lastIrontomb = Date.now();
        island.announce({
            "icon": "warning",
            "title": "IRONTOMB · " + title,
            "sub": sub,
            "tone": "irontomb"
        }, 6000);
        Form.playSound("low-battery");
    }

    // Breaking glass once, as the battery drops under 20 % off the charger (first screen only).
    readonly property bool lowBattery: BatteryService.batteryAvailable && BatteryService.batteryLevel < 20 && !BatteryService.isPluggedIn
    onLowBatteryChanged: {
        if (lowBattery && Form.chromes[0] === win)
            Form.playSound("low-battery");
    }

    function playTransformation() {
        if (Motion.still && !Form.reaver)
            return;
        transformLoader.active = true;
        transformLoader.item?.play();
    }

    // The bottom-edge dock for this screen's current workspace
    EdgeDock {
        targetScreen: win.screen
    }

    LazyLoader {
        id: launcherLoader

        Launcher {
            targetScreen: win.screen
            strip: win.strip
        }
    }

    function triggerLauncher(what, typed) {
        launcherLoader.active = true;
        const item = launcherLoader.item;
        if (!item)
            return;
        if (what === "open")
            item.open(typed);
        else if (what === "close")
            item.close();
        else
            item.toggle();
    }

    LazyLoader {
        id: powerLoader

        PowerMenu {
            targetScreen: win.screen
        }
    }

    function triggerPowerMenu() {
        powerLoader.active = true;
        powerLoader.item?.toggle();
    }

    LazyLoader {
        id: controlLoader

        ControlPanel {
            targetScreen: win.screen
            strip: win.strip
        }
    }

    LazyLoader {
        id: clipboardLoader

        ClipboardPanel {
            targetScreen: win.screen
            strip: win.strip
        }
    }

    function triggerClipboard(what) {
        clipboardLoader.active = true;
        const item = clipboardLoader.item;
        if (!item)
            return;
        if (what === "open")
            item.open();
        else if (what === "close")
            item.close();
        else
            item.toggle();
    }

    LazyLoader {
        id: processLoader

        ProcessPanel {
            targetScreen: win.screen
            strip: win.strip
        }
    }

    function triggerProcesses(what) {
        processLoader.active = true;
        const item = processLoader.item;
        if (!item)
            return;
        if (what === "open")
            item.open();
        else if (what === "close")
            item.close();
        else
            item.toggle();
    }

    LazyLoader {
        id: dashLoader

        Dashboard {
            targetScreen: win.screen
            strip: win.strip
        }
    }

    // ── left corner: workspaces and the app in focus ──
    Item {
        id: leftCorner
        visible: !win.raised

        readonly property var workspaces: NiriService.allWorkspaces.filter(w => w.output === win.screen.name).sort((a, b) => a.idx - b.idx)
        readonly property var focusedWindow: NiriService.windows.find(w => w.is_focused) ?? null
        readonly property string appId: focusedWindow?.app_id ?? ""

        height: win.strip
        width: leftRow.implicitWidth + 30

        CfTab {
            anchors.fill: parent
            side: "left"
        }

        Row {
            id: leftRow
            x: 12
            height: win.strip - (Form.reaver ? 6 : 0)
            spacing: 12

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7

                Repeater {
                    model: leftCorner.workspaces

                    // Workspace marks, one language per form: orbital rings for Phainon (the
                    // current one full and lit, the others broken), Roman numerals for Khaslana,
                    // tally scratches for the Flame Reaver. Stock pills when no form is active.
                    Item {
                        id: ws
                        required property var modelData
                        readonly property bool current: modelData.is_active
                        readonly property bool occupied: modelData.active_window_id != null
                        readonly property int number: modelData.idx
                        readonly property color ink: current ? Theme.primary : Theme.withAlpha(Theme.surfaceText, occupied ? 0.7 : 0.32)
                        width: Form.phainon ? 16 : (Form.khaslana ? numeral.implicitWidth : (Form.reaver ? tally.implicitWidth : mark.width))
                        height: 18

                        Rectangle {
                            id: mark
                            visible: !Form.active
                            anchors.centerIn: parent
                            width: ws.current ? 24 : 8
                            height: 8
                            radius: 4
                            color: ws.ink

                            Behavior on width {
                                NumberAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        Shape {
                            visible: Form.phainon
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                strokeColor: ws.ink
                                strokeWidth: ws.current ? 1.8 : 1.4
                                fillColor: "transparent"
                                capStyle: ShapePath.RoundCap

                                PathAngleArc {
                                    centerX: 8
                                    centerY: 8
                                    radiusX: 6.5
                                    radiusY: 6.5
                                    startAngle: -60
                                    sweepAngle: ws.current ? 360 : 290
                                }
                            }

                            Rectangle {
                                visible: ws.current || ws.occupied
                                anchors.centerIn: parent
                                width: ws.current ? 6 : 3
                                height: width
                                radius: width / 2
                                color: ws.current ? Theme.secondary : ws.ink
                            }
                        }

                        StyledText {
                            id: numeral
                            visible: Form.khaslana
                            anchors.centerIn: parent
                            readonly property var numerals: ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"]
                            text: numerals[ws.number] ?? String(ws.number)
                            font.family: Form.display(Theme.fontFamily)
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: ws.current ? Font.Bold : Font.Medium
                            color: ws.ink
                        }

                        Row {
                            id: tally
                            visible: Form.reaver
                            anchors.centerIn: parent
                            spacing: 3

                            Repeater {
                                model: Math.floor(ws.number / 5)

                                Text {
                                    text: "||||"
                                    font.family: Theme.monoFontFamily
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.strikeout: true
                                    color: ws.ink
                                }
                            }

                            Text {
                                visible: ws.number % 5 > 0
                                text: "|".repeat(ws.number % 5)
                                font.family: Theme.monoFontFamily
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: ws.current ? Font.Bold : Font.Normal
                                color: ws.ink
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NiriService.switchToWorkspace(ws.modelData.id)
                        }
                    }
                }
            }

            Rectangle {
                visible: leftCorner.appId !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 16
                color: Theme.withAlpha(Theme.outline, 0.7)
            }

            IconImage {
                visible: leftCorner.appId !== ""
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 22
                source: leftCorner.appId !== "" ? Paths.getAppIcon(leftCorner.appId, DesktopEntries.heuristicLookup(Paths.moddedAppId(leftCorner.appId))) : ""
            }
        }
    }

    // ── centre: the island ──
    Item {
        id: island

        readonly property string section: "center"
        readonly property MprisPlayer player: MprisController.activePlayer
        readonly property bool playing: !!player && player.playbackState === MprisPlaybackState.Playing
        readonly property int hour: clock.date?.getHours() ?? 0

        // A live activity takes the island over for a moment: { icon, title, sub, value, tone }
        property var activity: null
        property bool ready: false
        readonly property bool busy: activity !== null
        readonly property bool slit: Form.reaver && !islandHover.hovered

        // The newest incoming notification takes the island over until it times out or is clicked.
        readonly property var toast: NotificationService.popups.length > 0 ? NotificationService.popups[NotificationService.popups.length - 1] : null
        onToastChanged: {
            toastTimer.restart();
            if (toast && win.lead)
                Coreflames.earn("romance");
        }
        onPlayingChanged: {
            if (playing && win.lead)
                Coreflames.earn("ocean");
        }
        readonly property bool peek: islandHover.hovered && !busy && !!player
        property int recSeconds: 0
        // A screen cast alone is only sharing (a meeting, OBS preview). It counts as a recording
        // when a recorder is running or OBS has a video file open for writing.
        property bool recording: false

        function announce(what, ms) {
            if (!ready)
                return;
            activity = what;
            activityTimer.interval = ms ?? 2200;
            activityTimer.restart();
        }

        function nudgeVolume(up) {
            const audio = AudioService.sink?.audio;
            if (!audio)
                return;
            audio.muted = false;
            audio.volume = Math.max(0, Math.min(1, audio.volume + (up ? 0.03 : -0.03)));
        }

        height: win.strip + (Form.reaver ? 6 : 0)
        width: (toast ? toastRow.implicitWidth : (busy ? activityRow.implicitWidth : islandRow.implicitWidth)) + 44
        x: Math.round((win.width - width) / 2)
        clip: true

        Component.onCompleted: WeatherService.addRef()
        Component.onDestruction: WeatherService.removeRef()

        // Phainon settles with a small overshoot, Khaslana glides in heavily, the Flame Reaver just moves.
        Behavior on width {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Form.phainon ? Easing.OutBack : (Form.khaslana ? Easing.InOutCubic : Easing.OutCubic)
                easing.overshoot: 1.4
            }
        }

        Timer {
            interval: 3000
            running: true
            onTriggered: {
                island.ready = true;
                if (win.batteryCritical)
                    win.irontomb("Battery " + Math.round(BatteryService.batteryLevel) + "%", "The Coreflame is guttering");
                else if (win.overheated)
                    win.irontomb("CPU " + Math.round(Chimera.temp) + "°", "Irontomb stirs: let it cool");
                if (!Form.active || island.activity)
                    return;
                island.announce({
                    "icon": "all_inclusive",
                    "title": "Eternal Recurrence " + Form.cycleText,
                    "sub": Form.greeting
                }, 6000);
            }
        }

        // Then Cyrene's line for this start, once the greeting has gone
        Timer {
            interval: 9500
            running: Form.active
            onTriggered: island.announce({
                "icon": "local_florist",
                "title": "Cyrene",
                "sub": Form.cyreneLine
            }, 6000)
        }

        Timer {
            id: activityTimer
            onTriggered: island.activity = null
        }

        Timer {
            id: toastTimer
            interval: 6000
            running: island.toast !== null && !islandHover.hovered
            onTriggered: {
                if (island.toast)
                    island.toast.popup = false;
            }
        }

        Timer {
            interval: 1000
            repeat: true
            running: island.recording
            onRunningChanged: island.recSeconds = 0
            onTriggered: island.recSeconds++
        }

        Process {
            id: recorderCheck
            command: ["sh", "-c", "pgrep -x 'wf-recorder|wl-screenrec|gpu-screen-reco|kooha' > /dev/null && exit 0; for p in $(pgrep -x obs); do for f in /proc/$p/fd/*; do case \"$(readlink \"$f\" 2> /dev/null)\" in *.mkv|*.mp4|*.mov|*.flv|*.ts|*.webm) case \"$(sed -n 's/^flags:[[:space:]]*//p' /proc/$p/fdinfo/${f##*/} 2> /dev/null)\" in *1|*2) exit 0 ;; esac ;; esac; done; done; exit 1"]
            onExited: code => island.recording = NiriService.hasActiveCast && code === 0
        }

        Timer {
            interval: 3000
            repeat: true
            triggeredOnStart: true
            running: NiriService.hasActiveCast
            onRunningChanged: {
                if (!running)
                    island.recording = false;
            }
            onTriggered: recorderCheck.running = true
        }

        Connections {
            target: AudioService.sink?.audio ?? null

            function onVolumeChanged() {
                const v = AudioService.sink.audio.volume;
                island.announce({
                    "icon": AudioService.sinkVolumeIconName,
                    "title": Math.round(v * 100) + "%",
                    "value": v
                });
            }

            function onMutedChanged() {
                const muted = AudioService.sink.audio.muted;
                island.announce({
                    "icon": AudioService.sinkVolumeIconName,
                    "title": muted ? "Muted" : Math.round(AudioService.sink.audio.volume * 100) + "%",
                    "value": muted ? 0 : AudioService.sink.audio.volume
                });
            }
        }

        Connections {
            target: DisplayService

            function onBrightnessChanged(showOsd) {
                island.announce({
                    "icon": DisplayService.brightnessIconName(DisplayService.getCurrentDeviceInfo()),
                    "title": DisplayService.brightnessLevel + "%",
                    "value": DisplayService.brightnessLevel / 100
                });
            }
        }

        Connections {
            target: island.player

            function onTrackTitleChanged() {
                if (!island.player?.trackTitle)
                    return;
                island.announce({
                    "icon": "music_note",
                    "title": island.player.trackTitle,
                    "sub": island.player.trackArtist || ""
                }, 3000);
            }
        }

        Connections {
            target: BatteryService

            function onIsPluggedInChanged() {
                if (!BatteryService.batteryAvailable)
                    return;
                island.announce({
                    "icon": BatteryService.isPluggedIn ? "bolt" : "battery_5_bar",
                    "title": (BatteryService.isPluggedIn ? "Charging" : "On battery") + " · " + Math.round(BatteryService.batteryLevel) + "%",
                    "value": BatteryService.batteryLevel / 100
                }, 3000);
            }

            function onIsLowBatteryChanged() {
                if (!BatteryService.isLowBattery || BatteryService.isCharging)
                    return;
                island.announce({
                    "icon": "battery_alert",
                    "title": "Battery low · " + Math.round(BatteryService.batteryLevel) + "%",
                    "tone": "error"
                }, 5000);
            }
        }

        Connections {
            target: BluetoothService

            function onConnectedChanged() {
                if (!BluetoothService.connected)
                    return;
                const device = BluetoothService.adapter?.devices?.values?.find(d => d.connected);
                island.announce({
                    "icon": "bluetooth_connected",
                    "title": device?.name || "Bluetooth connected",
                    "sub": (device && device.batteryAvailable) ? Math.round(device.battery * 100) + "%" : ""
                }, 3000);
            }
        }

        Connections {
            target: Chrono

            function onTimerFinished() {
                island.announce({
                    "icon": "timer",
                    "title": "Timer finished",
                    "tone": "error"
                }, 8000);
            }
        }

        Connections {
            target: Coreflames
            enabled: win.lead

            function onGathered(name) {
                island.announce({
                    "icon": "local_fire_department",
                    "title": "Coreflame of " + Coreflames.titans[name][0],
                    "sub": "Flame-Chase " + Coreflames.count + " / 12"
                }, 3200);
            }
        }

        Connections {
            target: Form

            function onFormChanged() {
                if (!Form.active)
                    return;
                win.playTransformation();
                island.announce({
                    "icon": Form.phainon ? "wb_sunny" : (Form.khaslana ? "local_fire_department" : "dark_mode"),
                    "title": Form.phainon ? "Phainon" : (Form.khaslana ? "Khaslana" : "Flame Reaver"),
                    "sub": Form.phainon ? "The Deliverer" : (Form.khaslana ? "Worldbearer" : "of the Deepest Dark")
                }, 2800);
            }
        }

        CfTab {
            anchors.fill: parent
            side: "center"
        }

        // Irontomb: a critical alert darkens the island to black under red text
        Rectangle {
            visible: island.busy && island.activity?.tone === "irontomb"
            anchors.fill: parent
            anchors.margins: 3
            radius: Form.phainon || !Form.active ? height / 2 : 0
            color: "#F2080305"
            border.width: 1
            border.color: Theme.error
        }

        HoverHandler {
            id: islandHover
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (island.toast)
                    island.toast.popup = false;
                else if (mouse.button === Qt.MiddleButton)
                    island.player?.togglePlaying();
                else
                    win.triggerDashTab("overview");
            }
            // Scrolling on the island walks the workspaces: up for the one above, down for the one below.
            onWheel: wheel => {
                if (wheelPause.running)
                    return;
                wheelPause.restart();
                NiriService.send({
                    "Action": wheel.angleDelta.y > 0 ? {
                        "FocusWorkspaceUp": {}
                    } : {
                        "FocusWorkspaceDown": {}
                    }
                });
            }

            Timer {
                id: wheelPause
                interval: 160
            }
        }

        // Resting face
        Row {
            id: islandRow
            visible: !island.busy && !island.toast
            anchors.horizontalCenter: parent.horizontalCenter
            height: win.strip
            spacing: 10

            // Phainon's island is symmetric: the day on the left, the hour in the middle, what is
            // playing and waiting on the right.
            Row {
                visible: Form.phainon && WeatherService.weather.available
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                DankIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: WeatherService.getWeatherIcon(WeatherService.weather.wCode)
                    size: 18
                    color: Theme.secondary
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: WeatherService.currentTempText(false)
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                }
            }

            StyledText {
                visible: Form.phainon
                anchors.verticalCenter: parent.verticalCenter
                text: clock.date?.toLocaleDateString(I18n.locale(), "ddd d MMM") ?? ""
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.withAlpha(Theme.surfaceText, 0.75)
            }

            Rectangle {
                visible: Form.phainon
                anchors.verticalCenter: parent.verticalCenter
                width: 5
                height: 5
                radius: 3
                color: "#E9B92E"
            }

            CfSigil {
                anchors.verticalCenter: parent.verticalCenter
                size: 20
                lit: (island.hour % 12) || 12
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    const d = clock.date;
                    if (!d)
                        return "";
                    return d.toLocaleTimeString(I18n.locale(), SettingsData.use24HourClock ? "HH:mm" : "h:mm AP");
                }
                font.family: Form.display(Theme.fontFamily)
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Bold
                color: Theme.surfaceText
            }

            // Khaslana rules his island off into fields and names the hour.
            Rectangle {
                visible: Form.khaslana
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 18
                color: Theme.withAlpha(Theme.outline, 0.9)
            }

            Text {
                visible: Form.khaslana
                anchors.verticalCenter: parent.verticalCenter
                text: Form.dawnPeriod(island.hour).toUpperCase()
                font.family: Form.display(Theme.fontFamily)
                font.pixelSize: 10
                font.letterSpacing: 1.6
                color: Theme.secondary
            }

            Rectangle {
                visible: Form.khaslana
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 18
                color: Theme.withAlpha(Theme.outline, 0.9)
            }

            // The Flame Reaver at rest is only the time and a slit in the mask,
            // lit when something is waiting or playing. Hovering opens the rest.
            Rectangle {
                visible: island.slit
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 2
                color: (NotificationService.unreadCount > 0 || island.playing) ? Theme.live : Theme.withAlpha(Theme.surfaceText, 0.3)
            }

            StyledText {
                visible: !island.slit && !Form.phainon
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    const day = clock.date?.toLocaleDateString(I18n.locale(), "ddd d MMM") ?? "";
                    return Form.reaver ? day.toLowerCase() : day;
                }
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.withAlpha(Theme.surfaceText, 0.75)
            }

            Row {
                visible: WeatherService.weather.available && !island.slit && !Form.phainon
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                DankIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: WeatherService.getWeatherIcon(WeatherService.weather.wCode)
                    size: 18
                    color: Theme.primary
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: WeatherService.currentTempText(false)
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                }
            }

            // A running timer stays on the island
            Row {
                visible: Chrono.timerActive
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                DankIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "timer"
                    size: 17
                    color: Chrono.timerLeft <= 60 ? Theme.warning : Theme.primary
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Chrono.format(Chrono.timerLeft)
                    font.pixelSize: Theme.fontSizeMedium
                    color: Chrono.timerLeft <= 60 ? Theme.warning : Theme.surfaceText
                }
            }

            // Recording, microphone and camera in use
            Row {
                visible: NiriService.hasActiveCast || PrivacyService.microphoneActive || PrivacyService.cameraActive
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // Shared, not recorded: an icon and nothing else
                DankIcon {
                    visible: NiriService.hasActiveCast && !island.recording
                    anchors.verticalCenter: parent.verticalCenter
                    name: "screen_share"
                    size: 17
                    color: Theme.error
                }

                Rectangle {
                    visible: island.recording
                    anchors.verticalCenter: parent.verticalCenter
                    width: 9
                    height: 9
                    radius: Form.reaver ? 0 : 5
                    color: Theme.error
                }

                StyledText {
                    visible: island.recording
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.floor(island.recSeconds / 60) + ":" + String(island.recSeconds % 60).padStart(2, "0")
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.error
                }

                DankIcon {
                    visible: PrivacyService.microphoneActive
                    anchors.verticalCenter: parent.verticalCenter
                    name: "mic"
                    size: 16
                    color: Theme.warning
                }

                DankIcon {
                    visible: PrivacyService.cameraActive
                    anchors.verticalCenter: parent.verticalCenter
                    name: "videocam"
                    size: 16
                    color: Theme.success
                }
            }

            // What is playing: cover and title; transport appears while the pointer is over the island.
            Row {
                visible: !!island.player && !island.slit
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7
                opacity: island.playing || island.peek ? 1 : 0.55

                ClippingRectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 24
                    radius: Form.phainon || !Form.active ? 12 : 0
                    color: Theme.surfaceContainerHigh

                    Image {
                        anchors.fill: parent
                        source: island.player?.trackArtUrl ?? ""
                        sourceSize: Qt.size(48, 48)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                    }

                    DankIcon {
                        anchors.centerIn: parent
                        visible: !(island.player?.trackArtUrl)
                        name: "music_note"
                        size: 15
                        color: Theme.primary
                    }
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, island.peek ? 240 : 150)
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    maximumLineCount: 1
                    text: island.player?.trackTitle || island.player?.identity || ""
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                }

                Repeater {
                    model: island.peek ? ["skip_previous", island.playing ? "pause" : "play_arrow", "skip_next"] : []

                    DankIcon {
                        required property string modelData
                        required property int index
                        anchors.verticalCenter: parent.verticalCenter
                        name: modelData
                        size: 20
                        color: Theme.primary

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -3
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (index === 0)
                                    MprisController.previousOrRewind();
                                else if (index === 2)
                                    MprisController.next();
                                else
                                    island.player?.togglePlaying();
                            }
                        }
                    }
                }
            }

            // Notification bell
            Item {
                visible: !island.slit
                anchors.verticalCenter: parent.verticalCenter
                width: bellRow.implicitWidth
                height: 24

                Row {
                    id: bellRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    DankIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: NotificationService.unreadCount > 0 ? "notifications_active" : "notifications"
                        size: 18
                        color: NotificationService.unreadCount > 0 ? Theme.primary : Theme.withAlpha(Theme.surfaceText, 0.5)
                    }

                    StyledText {
                        visible: NotificationService.unreadCount > 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: NotificationService.unreadCount > 99 ? "99+" : NotificationService.unreadCount
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.DemiBold
                        color: Theme.primary
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -5
                    cursorShape: Qt.PointingHandCursor
                    onClicked: win.triggerNotifications()
                }
            }
        }

        // Live-activity face
        Row {
            id: activityRow
            visible: island.busy && !island.toast
            anchors.horizontalCenter: parent.horizontalCenter
            height: win.strip
            spacing: 10

            readonly property bool irontomb: island.activity?.tone === "irontomb"
            readonly property color tone: irontomb ? "#FF6B5E" : (island.activity?.tone === "error" ? Theme.error : Theme.primary)

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: island.activity?.icon ?? "info"
                size: 20
                color: activityRow.tone
            }

            // The Dawnmaker blade as a level meter
            Item {
                visible: island.activity?.value !== undefined
                anchors.verticalCenter: parent.verticalCenter
                width: 150
                height: 10

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 8
                    height: 6
                    radius: Form.phainon || !Form.active ? 3 : 0
                    color: Theme.withAlpha(Theme.surfaceText, 0.18)

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.round(parent.width * Math.max(0, Math.min(1, island.activity?.value ?? 0)))
                        height: Form.active ? 2 : parent.height
                        color: activityRow.tone

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.shorterDuration
                            }
                        }
                    }
                }

                Rectangle {
                    x: -4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8
                    height: 8
                    rotation: 45
                    color: Theme.secondary
                }
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 260)
                elide: Text.ElideRight
                text: {
                    const t = island.activity?.title ?? "";
                    return Form.reaver ? t.toLowerCase() : t;
                }
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.DemiBold
                color: activityRow.irontomb ? "#FF6B5E" : Theme.surfaceText
            }

            StyledText {
                visible: !!island.activity?.sub
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 430)
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                maximumLineCount: 1
                text: {
                    const t = island.activity?.sub ?? "";
                    return Form.reaver ? t.toLowerCase() : t;
                }
                font.pixelSize: Theme.fontSizeMedium
                color: activityRow.irontomb ? "#D9C2BE" : Theme.withAlpha(Theme.surfaceText, 0.65)
            }
        }

        // Notification face: who, what, and the notification's own buttons
        Row {
            id: toastRow
            visible: !!island.toast
            anchors.horizontalCenter: parent.horizontalCenter
            height: win.strip
            spacing: 10

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "notifications_active"
                size: 20
                color: Theme.primary
            }

            // A line of lore in front of every notification: a decree, a recurrence notice,
            // or a log line from the cycle.
            StyledText {
                visible: Form.active
                anchors.verticalCenter: parent.verticalCenter
                text: Form.phainon ? "DECREE" : (Form.khaslana ? "[ RECURRENCE NOTICE ]" : "// signal caught in cycle " + Form.cycleText)
                font.family: Form.phainon ? Form.display(Theme.fontFamily) : Theme.monoFontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.letterSpacing: Form.phainon ? 1.5 : 0
                color: Form.reaver ? Theme.withAlpha(Theme.surfaceText, 0.45) : Theme.secondary
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 200)
                elide: Text.ElideRight
                text: island.toast?.summary || island.toast?.appName || ""
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.DemiBold
                color: Theme.surfaceText
            }

            StyledText {
                visible: !!island.toast?.body
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 300)
                elide: Text.ElideRight
                maximumLineCount: 1
                textFormat: Text.PlainText
                text: (island.toast?.body ?? "").replace(/\s+/g, " ")
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.withAlpha(Theme.surfaceText, 0.7)
            }

            Repeater {
                model: island.toast ? island.toast.actions.slice(0, 2) : []

                Item {
                    id: toastAction
                    required property var modelData
                    anchors.verticalCenter: parent.verticalCenter
                    width: actionLabel.implicitWidth + 18
                    height: 24

                    CfSurface {
                        anchors.fill: parent
                        color: Theme.primary
                        edgeWidth: 0
                        radius: 12
                        cut: 5
                    }

                    StyledText {
                        id: actionLabel
                        anchors.centerIn: parent
                        text: Form.reaver ? toastAction.modelData.text.toLowerCase() : toastAction.modelData.text
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.DemiBold
                        color: Theme.primaryText
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            toastAction.modelData.invoke();
                            if (island.toast)
                                island.toast.popup = false;
                        }
                    }
                }
            }
        }
    }

    // ── right corner: network, bluetooth, sound, battery; opens the control centre ──
    Item {
        id: rightCorner
        visible: !win.raised

        readonly property string section: "right"

        height: win.strip
        width: rightRow.implicitWidth + 30
        x: win.width - width

        CfTab {
            anchors.fill: parent
            side: "right"
        }

        Row {
            id: rightRow
            anchors.right: parent.right
            anchors.rightMargin: 12
            height: win.strip - (Form.reaver ? 6 : 0)
            spacing: 11

            DankIcon {
                visible: NetworkService.networkAvailable
                anchors.verticalCenter: parent.verticalCenter
                name: NetworkService.networkStatus === "ethernet" ? "lan" : NetworkService.wifiSignalIcon
                size: 19
                color: NetworkService.networkStatus !== "disconnected" ? Theme.primary : Theme.withAlpha(Theme.surfaceText, 0.5)
            }

            DankIcon {
                visible: BluetoothService.available && BluetoothService.enabled
                anchors.verticalCenter: parent.verticalCenter
                name: BluetoothService.connected ? "bluetooth_connected" : "bluetooth"
                size: 19
                color: BluetoothService.connected ? Theme.primary : Theme.withAlpha(Theme.surfaceText, 0.6)
            }

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: AudioService.sinkVolumeIconName
                size: 19
                color: Theme.surfaceText
            }

            // The chimera runs with the CPU; the battery figure sits beside it.
            CfChimera {
                anchors.verticalCenter: parent.verticalCenter
                size: 32
            }

            // The exact figure beside the pips
            StyledText {
                visible: BatteryService.batteryAvailable
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(BatteryService.batteryLevel) + "%"
                font.family: Form.display(Theme.fontFamily)
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Bold
                color: (BatteryService.isLowBattery && !BatteryService.isCharging) ? Theme.error : Theme.surfaceText
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: win.triggerControlCenter()
            onWheel: wheel => {
                if (!AudioService.sink?.audio)
                    return;
                const step = wheel.angleDelta.y > 0 ? 0.03 : -0.03;
                AudioService.sink.audio.muted = false;
                AudioService.sink.audio.volume = Math.max(0, Math.min(1, AudioService.sink.audio.volume + step));
            }
        }
    }
}
