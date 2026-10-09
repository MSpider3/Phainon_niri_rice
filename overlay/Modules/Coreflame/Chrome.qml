import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Mpris
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
    WlrLayershell.layer: WlrLayer.Top
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
        running: (Quickshell.env("DMS_SHELL_DIR") ?? "") !== ""
        onTriggered: {
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

    function playTransformation() {
        if (Motion.still && !Form.reaver)
            return;
        transformLoader.active = true;
        transformLoader.item?.play();
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

                    Item {
                        id: ws
                        required property var modelData
                        readonly property bool current: modelData.is_active
                        width: mark.width
                        height: 18

                        Rectangle {
                            id: mark
                            anchors.centerIn: parent
                            width: ws.current ? 24 : 8
                            height: 8
                            radius: (Form.phainon || !Form.active) ? 4 : 0
                            rotation: (Form.khaslana && !ws.current) ? 45 : 0
                            color: ws.current ? Theme.primary : Theme.withAlpha(Theme.surfaceText, ws.modelData.active_window_id != null ? 0.7 : 0.28)

                            Behavior on width {
                                NumberAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Easing.OutCubic
                                }
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
        onToastChanged: toastTimer.restart()
        readonly property bool peek: islandHover.hovered && !busy && !!player
        property int recSeconds: 0

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
                if (!Form.active)
                    return;
                island.announce({
                    "icon": "all_inclusive",
                    "title": "Eternal Recurrence " + Form.cycleText,
                    "sub": Form.greeting
                }, 6000);
            }
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
            running: NiriService.hasActiveCast
            onRunningChanged: island.recSeconds = 0
            onTriggered: island.recSeconds++
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

                Rectangle {
                    visible: NiriService.hasActiveCast
                    anchors.verticalCenter: parent.verticalCenter
                    width: 9
                    height: 9
                    radius: Form.reaver ? 0 : 5
                    color: Theme.error
                }

                StyledText {
                    visible: NiriService.hasActiveCast
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

            readonly property color tone: island.activity?.tone === "error" ? Theme.error : Theme.primary

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
                color: Theme.surfaceText
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
                color: Theme.withAlpha(Theme.surfaceText, 0.65)
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
