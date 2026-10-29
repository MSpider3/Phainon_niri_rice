import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets
import Qt.labs.folderlistmodel
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
    property real reveal: shown ? 1 : 0

    readonly property MprisPlayer player: MprisController.activePlayer
    readonly property bool playing: !!player && player.playbackState === MprisPlaybackState.Playing
    // Three equal columns of 240 with 12 between them; every card and button sits on that grid.
    readonly property real panelWidth: 780
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

    Behavior on reveal {
        NumberAnimation {
            duration: Theme.mediumDuration
            easing.type: Form.phainon ? Easing.OutBack : (Form.khaslana ? Easing.InOutCubic : Easing.OutCubic)
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

    component Chip: Item {
        id: chip

        property string icon: ""
        property string label: ""
        property bool on: false
        signal clicked

        implicitWidth: chipRow.implicitWidth + 24
        implicitHeight: 34

        CfSurface {
            anchors.fill: parent
            color: chip.on ? Theme.primary : (chipMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)
            edgeColor: Theme.withAlpha(Theme.outline, 0.5)
            edgeWidth: Form.reaver ? 0 : 1
            radius: 17
        }

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 6

            DIcon {
                visible: chip.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                name: chip.icon
                size: 18
                color: chip.on ? Theme.primaryText : Theme.primary
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: Form.reaver ? chip.label.toLowerCase() : chip.label
                font.pixelSize: Theme.fontSizeMedium
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

    component Transport: Row {
        property int iconSize: 24
        readonly property MprisPlayer player: MprisController.activePlayer
        readonly property bool playing: !!player && player.playbackState === MprisPlaybackState.Playing
        spacing: 14

        Repeater {
            model: ["skip_previous", parent.playing ? "pause" : "play_arrow", "skip_next"]

            DIcon {
                required property string modelData
                required property int index
                anchors.verticalCenter: parent.verticalCenter
                // Faded when the player doesn't offer this button.
                readonly property bool able: index === 0 ? !!(MprisController.activePlayer?.canGoPrevious || MprisController.activePlayer?.canSeek) : index === 2 ? !!MprisController.activePlayer?.canGoNext : !!MprisController.activePlayer?.canTogglePlaying
                name: modelData
                size: index === 1 ? parent.iconSize + 8 : parent.iconSize
                color: able ? Theme.primary : Theme.withAlpha(Theme.surfaceText, 0.3)

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    enabled: parent.able
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (index === 0)
                            MprisController.previousOrRewind();
                        else if (index === 2)
                            MprisController.next();
                        else
                            MprisController.activePlayer?.togglePlaying();
                    }
                }
            }
        }
    }

    component Cover: ClippingRectangle {
        id: cover
        readonly property string art: MprisController.activePlayer?.trackArtUrl ?? ""
        radius: Form.phainon || !Form.active ? width / 2 : 0
        color: Theme.surfaceContainerHighest

        Image {
            id: coverImage
            anchors.fill: parent
            source: cover.art
            sourceSize: Qt.size(cover.width * 2, cover.height * 2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
        }

        DIcon {
            anchors.centerIn: parent
            visible: coverImage.status !== Image.Ready
            name: "music_note"
            size: cover.width * 0.45
            color: Theme.primary
        }
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

        CfTab {
            anchors.fill: parent
            side: "center"
        }

        CfOrnament {
            id: ornament
            anchors.fill: parent
        }

        Connections {
            target: dash

            function onShownChanged() {
                if (dash.shown)
                    ornament.play();
            }
        }

        // Swallow clicks so they don't close the dashboard
        MouseArea {
            anchors.fill: parent
        }

        // Header: the island's own line, kept in place while the panel grows beneath it
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            height: dash.strip
            spacing: 10

            DIcon {
                visible: dash.view !== ""
                anchors.verticalCenter: parent.verticalCenter
                name: "arrow_back"
                size: 20
                color: Theme.primary

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: dash.view = ""
                }
            }

            CfSigil {
                anchors.verticalCenter: parent.verticalCenter
                size: 20
                lit: ((clock.date?.getHours() ?? 0) % 12) || 12
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    const names = {
                        "": Form.dawnPeriod(clock.date?.getHours() ?? 0),
                        "music": "Ocean · Now playing",
                        "weather": "Sky · Weather",
                        "wallpaper": "Worldbearing · Wallpapers",
                        "time": "Time · Clock",
                        "notifications": "Romance · Messages",
                        "wellbeing": "Time · Wellbeing",
                        "network": "Passage · Network"
                    };
                    return dash.tx(names[dash.view] ?? "");
                }
                font.family: Form.display(Theme.fontFamily)
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.DemiBold
                color: Theme.surfaceText
            }
        }

        StyledText {
            visible: dash.view === ""
            anchors.right: parent.right
            // Reaver's mask slats sit in the last 58 px of the edge.
            anchors.rightMargin: Form.reaver ? 70 : 22
            height: dash.strip
            verticalAlignment: Text.AlignVCenter
            opacity: dash.reveal
            text: dash.tx("Recurrence ") + Form.cycleText
            font.family: Theme.monoFontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.withAlpha(Theme.surfaceText, 0.45)
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
                    "time": "DashTime.qml"
                })
            readonly property var components: ({
                    "wallpaper": wallpaperView
                })

            x: 18
            y: dash.strip + 8
            width: dash.panelWidth - 36
            opacity: dash.reveal
            sourceComponent: body.files[dash.view] ? fileView : (body.components[dash.view] ?? overviewView)
        }
    }

    // ── overview: a grid of cards; each opens its full view ──
    Component {
        id: overviewView

        Column {
            id: overview
            spacing: dash.gap

            // Left column (clock, system, calendar) and right column (Flame-Chase, weather, notifications)
            readonly property real leftWidth: 420
            readonly property real rightWidth: dash.panelWidth - 36 - leftWidth - dash.gap
            readonly property real half: (leftWidth - dash.gap) / 2
            readonly property var notes: NotificationService.groupedNotifications.slice(0, 3)

            Row {
                spacing: dash.gap

                Column {
                    id: leftColumn
                    spacing: dash.gap

                    Row {
                        spacing: dash.gap

                        // Clock: opens the full clock (world clock, timer, stopwatch)
                        DashCard {
                            width: overview.half
                            height: 116
                            clickable: true
                            numeral: "I"
                            glyph: "time"
                            label: "Time · Clock"
                            onClicked: dash.view = "time"

                            Row {
                                anchors.centerIn: parent
                                spacing: 10

                                CfSigil {
                                    visible: !Form.reaver
                                    anchors.verticalCenter: parent.verticalCenter
                                    size: 44
                                    lit: ((clock.date?.getHours() ?? 0) % 12) || 12
                                    dimColor: Theme.withAlpha(Theme.surfaceText, 0.22)
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter

                                    StyledText {
                                        text: (clock.date?.toLocaleTimeString(I18n.locale(), SettingsData.use24HourClock ? "HH:mm" : "h:mm AP") ?? "").replace(/\s*[AaPp]\.?[Mm]\.?$/, "")
                                        font.family: Form.reaver ? Theme.monoFontFamily : Form.display(Theme.fontFamily)
                                        font.pixelSize: 34
                                        font.weight: Font.Bold
                                        color: Theme.primary
                                    }

                                    StyledText {
                                        text: dash.tx(clock.date?.toLocaleDateString(I18n.locale(), "ddd, d MMM") ?? "")
                                        font.family: Form.reaver ? Theme.monoFontFamily : Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Medium
                                        color: Theme.withAlpha(Theme.surfaceText, 0.75)
                                    }
                                }
                            }
                        }

                        // CPU, heat and memory: opens the island's system monitor
                        DashCard {
                            width: overview.half
                            height: 116
                            clickable: true
                            numeral: "II"
                            glyph: "law"
                            label: "Law · System"
                            onClicked: {
                                const chrome = Form.chromes.find(c => c.screen === dash.screen) ?? Form.chromes[0];
                                dash.close();
                                chrome?.triggerProcesses("open");
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                spacing: 8

                                Repeater {
                                    model: [["CPU", DgopService.cpuUsage || 0, "%", 90], ["Heat", DgopService.cpuTemperature || 0, "°", 85], ["Mem", DgopService.memoryUsage || 0, "%", 90]]

                                    Row {
                                        required property var modelData
                                        readonly property bool alarm: modelData[1] > modelData[3]
                                        width: parent.width
                                        spacing: 6

                                        StyledText {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 36
                                            text: dash.tx(modelData[0])
                                            font.family: Form.reaver ? Theme.monoFontFamily : Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.withAlpha(Theme.surfaceText, 0.65)
                                        }

                                        CfBlade {
                                            anchors.verticalCenter: parent.verticalCenter
                                            meter: true
                                            width: parent.width - 36 - 38 - 12
                                            value: modelData[1] / 100
                                            tide: modelData[0] === "Mem"
                                            tone: parent.alarm ? Theme.error : (Form.reaver ? Theme.live : Theme.primary)
                                        }

                                        StyledText {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 38
                                            horizontalAlignment: Text.AlignRight
                                            text: Math.round(modelData[1]) + modelData[2]
                                            font.family: Form.phainon ? Theme.fontFamily : Theme.monoFontFamily
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Font.Bold
                                            color: parent.alarm ? Theme.error : Theme.surfaceText
                                        }
                                    }
                                }
                            }
                        }
                    }

                    DashCalendar {
                        width: overview.leftWidth
                        height: 330
                        live: dash.shown
                        now: clock.date ?? new Date()
                    }
                }

                Column {
                    spacing: dash.gap

                    // The Flame-Chase: twelve Titans' Coreflames, lit as they are gathered (or, for the
                    // Flame Reaver, taken: each one an ember held in his row).
                    DashCard {
                        width: overview.rightWidth
                        height: 104
                        numeral: "IV"
                        glyph: "worldbearing"
                        label: Form.reaver ? "taken · " + Coreflames.count + " / 12" : "Flame-Chase " + Coreflames.count + " / 12"

                        Column {
                            anchors.centerIn: parent
                            spacing: Form.reaver ? 6 : 8

                            Grid {
                                anchors.horizontalCenter: parent.horizontalCenter
                                columns: 6
                                columnSpacing: 22
                                rowSpacing: Form.reaver ? 6 : 10

                                Repeater {
                                    model: Coreflames.order

                                    CfGlyph {
                                        id: titan
                                        required property string modelData
                                        readonly property bool lit: Coreflames.has(modelData) && Coreflames.count >= 0
                                        name: modelData
                                        size: 20
                                        strokeWidth: lit ? 1.9 : 1.3
                                        color: lit ? (Form.reaver ? Theme.live : Theme.primary) : Theme.withAlpha(Theme.surfaceText, 0.22)
                                        onLitChanged: if (lit && Form.reaver)
                                            ember.flare()

                                        CfEmber {
                                            id: ember
                                            anchors.centerIn: parent
                                            size: 12
                                            color: Theme.live
                                        }

                                        HoverHandler {
                                            id: titanHover
                                        }

                                        ToolTip.visible: titanHover.hovered
                                        ToolTip.text: Coreflames.titans[modelData][0] + " · " + Coreflames.titans[modelData][1]
                                    }
                                }
                            }

                            StyledText {
                                visible: Form.reaver
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "the flame-chase will not end..."
                                font.family: Theme.monoFontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.italic: true
                                color: Theme.withAlpha(Theme.live, 0.85)
                            }
                        }
                    }

                    // Wallpapers: under the Flame-Chase, in the card grid rather than a loose button row
                    Chip {
                        width: overview.rightWidth
                        icon: "wallpaper"
                        label: "Wallpapers"
                        onClicked: dash.view = "wallpaper"
                    }

                    // Weather: opens the forecast
                    DashCard {
                        width: overview.rightWidth
                        height: 116
                        clickable: true
                        numeral: "V"
                        glyph: "sky"
                        label: "Sky · Weather"
                        onClicked: dash.view = "weather"

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12

                            DIcon {
                                visible: !Form.reaver
                                anchors.verticalCenter: parent.verticalCenter
                                name: WeatherService.weather.available ? WeatherService.getWeatherIcon(WeatherService.weather.wCode) : "cloud_off"
                                size: 44
                                color: Theme.primary
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1

                                StyledText {
                                    text: WeatherService.weather.available ? WeatherService.currentTempText(false) : "--"
                                    font.family: Form.khaslana || Form.reaver ? Theme.monoFontFamily : Theme.fontFamily
                                    font.pixelSize: 26
                                    font.weight: Font.DemiBold
                                    color: Form.reaver ? Theme.live : Theme.surfaceText
                                }

                                StyledText {
                                    width: Form.phainon ? 110 : 150
                                    elide: Text.ElideRight
                                    text: dash.tx(WeatherService.weather.available ? WeatherService.getWeatherCondition(WeatherService.weather.wCode) : "No weather data")
                                    font.family: Form.reaver ? Theme.monoFontFamily : Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.withAlpha(Theme.surfaceText, 0.75)
                                }

                                // The Flame Reaver reads the sun as one plain line.
                                StyledText {
                                    visible: Form.reaver && WeatherService.weather.available
                                    text: dash.tx("sun " + (WeatherService.weather.sunrise ?? "") + " → " + (WeatherService.weather.sunset ?? ""))
                                    font.family: Theme.monoFontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.withAlpha(Theme.surfaceText, 0.55)
                                }
                            }
                        }

                        // Khaslana: humidity and wind as cut figures on the right
                        Column {
                            visible: Form.khaslana && WeatherService.weather.available
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            Repeater {
                                model: [["humidity_percentage", WeatherService.weather.humidity !== undefined ? WeatherService.weather.humidity + "%" : "--"], ["air", WeatherService.weather.wind ?? "--"]]

                                Row {
                                    required property var modelData
                                    anchors.right: parent.right
                                    spacing: 4

                                    DIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: modelData[0]
                                        size: 14
                                        color: Theme.primary
                                    }

                                    StyledText {
                                        text: modelData[1]
                                        font.family: Theme.monoFontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceText
                                    }
                                }
                            }
                        }

                        // Phainon: the sun's path today, sunrise on the left, sunset on the right
                        Item {
                            visible: Form.phainon
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            width: 120
                            height: 70

                            Shape {
                                anchors.fill: parent
                                preferredRendererType: Shape.CurveRenderer

                                ShapePath {
                                    fillColor: "transparent"
                                    strokeColor: Theme.withAlpha(Theme.outline, 0.8)
                                    strokeWidth: 1.5

                                    PathAngleArc {
                                        centerX: 60
                                        centerY: 56
                                        radiusX: 52
                                        radiusY: 44
                                        startAngle: 180
                                        sweepAngle: 180
                                    }
                                }
                            }

                            Rectangle {
                                x: 4
                                y: 56
                                width: 112
                                height: 1
                                color: Theme.withAlpha(Theme.outline, 0.5)
                            }

                            Rectangle {
                                readonly property real angle: Math.PI * (1 - dash.dayFraction)
                                x: 60 + 52 * Math.cos(angle) - 7
                                y: 56 - 44 * Math.sin(angle) - 7
                                width: 14
                                height: 14
                                radius: 7
                                color: "#E9B92E"
                                border.width: 3
                                border.color: Theme.withAlpha("#E9B92E", 0.3)
                            }

                            StyledText {
                                y: 59
                                text: WeatherService.weather.sunrise ?? ""
                                font.pixelSize: 9
                                color: Theme.withAlpha(Theme.surfaceText, 0.55)
                            }

                            StyledText {
                                anchors.right: parent.right
                                y: 59
                                text: WeatherService.weather.sunset ?? ""
                                font.pixelSize: 9
                                color: Theme.withAlpha(Theme.surfaceText, 0.55)
                            }
                        }
                    }

                    // Notifications: the latest few; opens the messages view
                    DashCard {
                        width: overview.rightWidth
                        height: leftColumn.height - 104 - 34 - 116 - 3 * dash.gap
                        clickable: true
                        numeral: "VI"
                        glyph: "romance"
                        label: "Romance · Messages" + (NotificationService.notifications.length > 0 ? "  ·  " + NotificationService.notifications.length : "")
                        onClicked: dash.view = "notifications"

                        Column {
                            visible: overview.notes.length === 0
                            anchors.centerIn: parent
                            spacing: 10

                            CfSigil {
                                visible: !Form.reaver
                                anchors.horizontalCenter: parent.horizontalCenter
                                size: 40
                                lit: 0
                                litColor: Theme.withAlpha(Theme.surfaceText, 0.3)
                                dimColor: Theme.withAlpha(Theme.surfaceText, 0.3)
                            }

                            CfGlyph {
                                visible: Form.reaver
                                anchors.horizontalCenter: parent.horizontalCenter
                                name: "mask"
                                size: 34
                                strokeWidth: 1.4
                                color: Theme.withAlpha(Theme.live, 0.7)
                            }

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: dash.tx("All caught up")
                                font.family: Form.reaver ? Theme.monoFontFamily : Theme.fontFamily
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.withAlpha(Theme.surfaceText, 0.6)
                            }
                        }

                        // Only as many apps as fully fit in the card; the rest are in the messages view.
                        Column {
                            id: noteList
                            visible: overview.notes.length > 0
                            width: parent.width
                            height: parent.height
                            clip: true
                            spacing: 10

                            readonly property real rowHeight: noteRows.itemAt(0)?.implicitHeight ?? 1
                            readonly property int fits: Math.max(1, Math.floor((height + spacing) / (rowHeight + spacing)))

                            Repeater {
                                id: noteRows
                                model: overview.notes

                                Column {
                                    required property var modelData
                                    required property int index
                                    visible: index < noteList.fits
                                    width: parent.width
                                    spacing: 1

                                    StyledText {
                                        width: parent.width
                                        elide: Text.ElideRight
                                        wrapMode: Text.NoWrap
                                        text: dash.tx((modelData.appName || "") + (modelData.count > 1 ? "  ·  " + modelData.count : "") + "  ·  " + (modelData.latestNotification?.timeStr ?? ""))
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Form.reaver ? Theme.withAlpha(Theme.live, 0.9) : Theme.withAlpha(Theme.surfaceText, 0.55)
                                    }

                                    StyledText {
                                        width: parent.width
                                        elide: Text.ElideRight
                                        wrapMode: Text.NoWrap
                                        textFormat: Text.PlainText
                                        text: (modelData.latestNotification?.summary ?? "").replace(/\s+/g, " ")
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.DemiBold
                                        color: Theme.surfaceText
                                    }

                                    StyledText {
                                        width: parent.width
                                        elide: Text.ElideRight
                                        wrapMode: Text.NoWrap
                                        textFormat: Text.PlainText
                                        text: (modelData.latestNotification?.body ?? "").replace(/\s+/g, " ")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.withAlpha(Theme.surfaceText, 0.7)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Row {
                spacing: dash.gap
                height: 104

                // Media: opens the player
                DashCard {
                    width: 300
                    height: parent.height
                    clickable: true
                    numeral: "VII"
                    glyph: "ocean"
                    label: "Ocean · Now playing"
                    onClicked: dash.view = "music"

                    Row {
                        visible: !!dash.player
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        Cover {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 58
                            height: 58
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 300 - 28 - 58 - 12
                            spacing: 2

                            StyledText {
                                width: parent.width
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                                text: dash.player?.trackTitle || dash.player?.identity || ""
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.DemiBold
                                color: Theme.surfaceText
                            }

                            StyledText {
                                width: parent.width
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                                text: dash.player?.trackArtist || ""
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.withAlpha(Theme.surfaceText, 0.65)
                            }

                            Transport {
                                iconSize: 20
                            }
                        }
                    }

                    StyledText {
                        visible: !dash.player
                        anchors.centerIn: parent
                        text: Form.reaver ? "nothing." : "Nothing playing"
                        font.family: Form.reaver ? Theme.monoFontFamily : Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.withAlpha(Theme.surfaceText, 0.55)
                    }
                }

                // Network: down and up now, the last minute as a line; opens the network view
                DashCard {
                    width: 252
                    height: parent.height
                    clickable: true
                    numeral: "VIII"
                    glyph: "passage"
                    label: "Passage · Network"
                    onClicked: dash.view = "network"

                    StyledText {
                        id: downRate
                        text: Format.formatRate(DgopService.networkRxRate || 0)
                        font.family: Form.phainon ? Theme.fontFamily : Theme.monoFontFamily
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                        color: Form.reaver ? Theme.live : Theme.primary
                    }

                    StyledText {
                        anchors.right: parent.right
                        anchors.baseline: downRate.baseline
                        text: "↑ " + Format.formatRate(DgopService.networkTxRate || 0)
                        font.family: Theme.monoFontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.withAlpha(Theme.surfaceText, 0.65)
                    }

                    DSparkline {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 30
                        values: DgopService.networkHistory.rx
                        secondaryValues: DgopService.networkHistory.tx
                        historyLength: 60
                        lineColor: Form.reaver ? Theme.live : Theme.primary
                        secondaryLineColor: Theme.withAlpha(Theme.surfaceText, 0.45)
                        lineWidth: 1.5
                        fillOpacity: Form.reaver ? 0 : 0.12
                        curved: Form.phainon || !Form.active
                    }
                }

                // Screen time today: opens the wellbeing view
                DashCard {
                    id: screenTime
                    width: dash.panelWidth - 36 - 300 - 252 - 2 * dash.gap
                    height: parent.height
                    clickable: true
                    numeral: "IX"
                    glyph: "time"
                    label: "Time · Wellbeing"
                    onClicked: dash.view = "wellbeing"

                    readonly property bool over: SettingsData.wellbeingDailyLimit > 0 && WellbeingService.today.active >= SettingsData.wellbeingDailyLimit * 60

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        StyledText {
                            text: WellbeingService.formatDuration(WellbeingService.today.active)
                            font.family: Form.phainon ? Theme.fontFamily : Theme.monoFontFamily
                            font.pixelSize: 22
                            font.weight: Font.DemiBold
                            color: screenTime.over ? Theme.error : Theme.surfaceText
                        }

                        StyledText {
                            text: dash.tx(SettingsData.wellbeingDailyLimit > 0 ? "of " + WellbeingService.formatLimit(SettingsData.wellbeingDailyLimit) : "today")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.withAlpha(Theme.surfaceText, 0.55)
                        }
                    }
                }
            }

            // Aedes Elysiae: a line of wheat under the Phainon overview
            CfWheat {
                visible: Form.phainon
                width: parent.width
                height: 22
                spacing: 12
            }
        }
    }

    Component {
        id: fileView

        Loader {
            source: Qt.resolvedUrl(body.files[dash.view] ?? "")
        }
    }

    // ── wallpapers ──
    Component {
        id: wallpaperView

        Column {
            id: walls
            spacing: dash.gap

            readonly property string current: SessionData.wallpaperPath
            readonly property string folder: current.substring(0, current.lastIndexOf("/"))
            readonly property int perPage: 12
            readonly property int pages: Math.max(1, Math.ceil(files.count / perPage))
            property int page: 0

            function turn(by) {
                page = Math.max(0, Math.min(pages - 1, page + by));
            }

            FolderListModel {
                id: files
                folder: walls.folder !== "" ? "file://" + walls.folder : ""
                nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp"]
                showDirs: false
                sortField: FolderListModel.Name
                onStatusChanged: {
                    if (status !== FolderListModel.Ready)
                        return;
                    const at = indexOf("file://" + walls.current);
                    if (at >= 0)
                        walls.page = Math.floor(at / walls.perPage);
                }
            }

            Grid {
                id: wallGrid
                readonly property real cellWidth: Math.floor((dash.panelWidth - 36 - 3 * 10) / 4)
                columns: 4
                spacing: 10
                readonly property int rows: Math.max(1, Math.min(3, Math.ceil(files.count / 4)))
                height: rows * 100 + (rows - 1) * 10

                Repeater {
                    model: Math.max(0, Math.min(walls.perPage, files.count - walls.page * walls.perPage))

                    Item {
                        id: thumb
                        required property int index
                        readonly property int at: walls.page * walls.perPage + index
                        readonly property string path: files.get(at, "filePath") ?? ""
                        readonly property bool current: path === walls.current
                        width: wallGrid.cellWidth
                        height: 100

                        ClippingRectangle {
                            anchors.fill: parent
                            radius: Form.phainon || !Form.active ? 14 : 0
                            color: Theme.surfaceContainerHigh

                            Image {
                                anchors.fill: parent
                                source: files.get(thumb.at, "fileUrl") ?? ""
                                sourceSize: Qt.size(360, 200)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                        }

                        CfSurface {
                            anchors.fill: parent
                            visible: thumb.current || thumbMouse.containsMouse
                            color: "transparent"
                            edgeColor: thumb.current ? Theme.primary : Theme.withAlpha(Theme.primary, 0.5)
                            edgeWidth: thumb.current ? 3 : 2
                            radius: 14
                            shape: Form.phainon || !Form.active ? "round" : "slab"
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: !Form.phainon && Form.active && (thumb.current || thumbMouse.containsMouse)
                            color: "transparent"
                            border.width: thumb.current ? 3 : 2
                            border.color: thumb.current ? Theme.primary : Theme.withAlpha(Theme.primary, 0.5)
                        }

                        MouseArea {
                            id: thumbMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: SessionData.setWallpaper(thumb.path)
                            onWheel: wheel => walls.turn(wheel.angleDelta.y > 0 ? -1 : 1)
                        }
                    }
                }
            }

            Item {
                width: dash.panelWidth - 36
                height: 30

                Row {
                    anchors.centerIn: parent
                    spacing: 16

                    DIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "chevron_left"
                        size: 24
                        color: walls.page > 0 ? Theme.primary : Theme.withAlpha(Theme.surfaceText, 0.25)

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -5
                            cursorShape: Qt.PointingHandCursor
                            onClicked: walls.turn(-1)
                        }
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: dash.tx((walls.page + 1) + " / " + walls.pages + "  ·  " + files.count + " wallpapers")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.withAlpha(Theme.surfaceText, 0.75)
                    }

                    DIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "chevron_right"
                        size: 24
                        color: walls.page < walls.pages - 1 ? Theme.primary : Theme.withAlpha(Theme.surfaceText, 0.25)

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -5
                            cursorShape: Qt.PointingHandCursor
                            onClicked: walls.turn(1)
                        }
                    }
                }
            }
        }
    }
}
