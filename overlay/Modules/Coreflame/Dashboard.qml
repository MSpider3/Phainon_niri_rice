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
import Qt.labs.folderlistmodel

// The dashboard the island grows into. One summary page; a card opens in place into its full view.
PanelWindow {
    id: dash

    required property var targetScreen
    property int strip: 40

    // "" is the summary; otherwise "music", "weather", "wallpaper" or "time"
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
    // The bottom row holds four buttons across the same width.
    readonly property real quarter: (panelWidth - 36 - 3 * gap) / 4

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
            DgopService.addRef(["cpu", "memory", "system"]);
            WeatherService.addRef();
            panel.forceActiveFocus();
        } else {
            DgopService.removeRef(["cpu", "memory", "system"]);
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

    component Card: Item {
        id: card

        property bool clickable: false
        // Small caps label in the corner: which Titan's domain this card is, and what it shows.
        property string label: ""
        // Khaslana indexes every plate with a Roman numeral.
        property string numeral: ""
        // The Titan's sigil for this card's domain
        property string glyph: ""
        default property alias content: inner.data
        signal clicked

        CfSurface {
            anchors.fill: parent
            color: cardMouse.containsMouse && card.clickable ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
            edgeColor: Theme.withAlpha(Theme.outline, Form.khaslana ? 0.9 : 0.45)
            edgeWidth: Form.reaver ? 0 : 1
            radius: 16
        }

        MouseArea {
            id: cardMouse
            anchors.fill: parent
            hoverEnabled: card.clickable
            cursorShape: card.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (card.clickable)
                card.clicked()
        }

        CfGlyph {
            visible: card.glyph !== "" && card.label !== ""
            x: 13
            y: 7
            name: card.glyph
            size: 15
            strokeWidth: 1.9
            color: Theme.withAlpha(Theme.surfaceText, 0.6)
        }

        Text {
            visible: card.label !== ""
            x: card.glyph !== "" ? 34 : 14
            y: 9
            text: Form.reaver ? "// " + card.label.toLowerCase() : ((Form.khaslana && card.numeral !== "" ? card.numeral + "  ·  " : "") + card.label.toUpperCase())
            font.family: Form.reaver ? Theme.monoFontFamily : Form.display(Theme.fontFamily)
            font.pixelSize: 10
            font.weight: Font.Medium
            font.letterSpacing: Form.reaver ? 0.5 : 1.4
            color: Theme.withAlpha(Theme.surfaceText, 0.5)
        }

        Item {
            id: inner
            anchors.fill: parent
            anchors.margins: 14
            anchors.topMargin: card.label !== "" ? 24 : 14
        }
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

            DankIcon {
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

            DankIcon {
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

        DankIcon {
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

            DankIcon {
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
                        "time": "Time · Timer and stopwatch"
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
            x: 18
            y: dash.strip + 8
            width: dash.panelWidth - 36
            opacity: dash.reveal
            sourceComponent: dash.view === "music" ? musicView : dash.view === "weather" ? weatherView : dash.view === "wallpaper" ? wallpaperView : dash.view === "time" ? timeView : (Form.reaver ? ledgerView : summaryView)
        }
    }

    // ── summary ──
    Component {
        id: summaryView

        Column {
            spacing: 12

            Row {
                spacing: 12
                height: 132

                Card {
                    width: Form.phainon ? dash.col * 2 + dash.gap : dash.col
                    height: parent.height
                    numeral: "I"
                    glyph: "time"
                    label: "Time · " + Form.dawnPeriod(clock.date?.getHours() ?? 0)

                    Row {
                        anchors.centerIn: parent
                        spacing: Form.phainon ? 22 : 14

                        CfSigil {
                            anchors.verticalCenter: parent.verticalCenter
                            size: 74
                            lit: ((clock.date?.getHours() ?? 0) % 12) || 12
                            dimColor: Theme.withAlpha(Theme.surfaceText, 0.22)
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0

                            StyledText {
                                text: clock.date?.toLocaleTimeString(I18n.locale(), SettingsData.use24HourClock ? "HH:mm" : "h:mm") ?? ""
                                font.family: Form.display(Theme.fontFamily)
                                font.pixelSize: 40
                                font.weight: Font.Bold
                                color: Theme.primary
                            }

                            StyledText {
                                text: dash.tx(clock.date?.toLocaleDateString(I18n.locale(), "ddd, d MMM") ?? "")
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.withAlpha(Theme.surfaceText, 0.75)
                            }

                            // Phainon keeps the machine's strain to one quiet line.
                            StyledText {
                                visible: Form.phainon
                                text: "CPU " + Math.round(DgopService.cpuUsage || 0) + "%  ·  " + Math.round(DgopService.cpuTemperature || 0) + "°  ·  Mem " + Math.round(DgopService.memoryUsage || 0) + "%"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.withAlpha(Theme.surfaceText, 0.5)
                            }
                        }

                        // The sun's path today: sunrise on the left, sunset on the right
                        Item {
                            visible: Form.phainon
                            anchors.verticalCenter: parent.verticalCenter
                            width: 200
                            height: 92

                            Shape {
                                anchors.fill: parent
                                preferredRendererType: Shape.CurveRenderer

                                ShapePath {
                                    fillColor: "transparent"
                                    strokeColor: Theme.withAlpha(Theme.outline, 0.8)
                                    strokeWidth: 1.5

                                    PathAngleArc {
                                        centerX: 100
                                        centerY: 72
                                        radiusX: 88
                                        radiusY: 60
                                        startAngle: 180
                                        sweepAngle: 180
                                    }
                                }
                            }

                            Rectangle {
                                x: 6
                                y: 72
                                width: 188
                                height: 1
                                color: Theme.withAlpha(Theme.outline, 0.5)
                            }

                            Rectangle {
                                readonly property real angle: Math.PI * (1 - dash.dayFraction)
                                x: 100 + 88 * Math.cos(angle) - 9
                                y: 72 - 60 * Math.sin(angle) - 9
                                width: 18
                                height: 18
                                radius: 9
                                color: "#E9B92E"
                                border.width: 3
                                border.color: Theme.withAlpha("#E9B92E", 0.3)
                            }

                            StyledText {
                                x: 0
                                y: 76
                                text: WeatherService.weather.sunrise ?? ""
                                font.pixelSize: 10
                                color: Theme.withAlpha(Theme.surfaceText, 0.55)
                            }

                            StyledText {
                                anchors.right: parent.right
                                y: 76
                                text: WeatherService.weather.sunset ?? ""
                                font.pixelSize: 10
                                color: Theme.withAlpha(Theme.surfaceText, 0.55)
                            }
                        }
                    }
                }

                Card {
                    width: dash.col
                    height: parent.height
                    clickable: true
                    numeral: "II"
                    glyph: "sky"
                    label: "Sky · Weather"
                    onClicked: dash.view = "weather"

                    Row {
                        anchors.centerIn: parent
                        spacing: 14

                        DankIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: WeatherService.weather.available ? WeatherService.getWeatherIcon(WeatherService.weather.wCode) : "cloud_off"
                            size: 54
                            color: Theme.primary
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            StyledText {
                                text: WeatherService.weather.available ? WeatherService.currentTempText(false) : "--"
                                font.pixelSize: 28
                                font.weight: Font.DemiBold
                                color: Theme.surfaceText
                            }

                            StyledText {
                                width: 120
                                elide: Text.ElideRight
                                text: dash.tx(WeatherService.weather.available ? WeatherService.getWeatherCondition(WeatherService.weather.wCode) : "No weather data")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.withAlpha(Theme.surfaceText, 0.75)
                            }
                        }
                    }
                }

                Card {
                    width: dash.col
                    height: parent.height
                    visible: !Form.phainon
                    numeral: "III"
                    glyph: "law"
                    label: "Law · System"

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        spacing: 9

                        Repeater {
                            model: [
                                {
                                    "name": "CPU",
                                    "value": (DgopService.cpuUsage || 0) / 100,
                                    "text": Math.round(DgopService.cpuUsage || 0) + "%",
                                    "alarm": (DgopService.cpuUsage || 0) > 90
                                },
                                {
                                    "name": "Heat",
                                    "value": (DgopService.cpuTemperature || 0) / 100,
                                    "text": Math.round(DgopService.cpuTemperature || 0) + "°",
                                    "alarm": (DgopService.cpuTemperature || 0) > 85
                                },
                                {
                                    "name": "Memory",
                                    "value": (DgopService.memoryUsage || 0) / 100,
                                    "text": Math.round(DgopService.memoryUsage || 0) + "%",
                                    "alarm": (DgopService.memoryUsage || 0) > 90
                                }
                            ]

                            Row {
                                required property var modelData
                                width: parent.width
                                spacing: 8

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 56
                                    text: dash.tx(modelData.name)
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    color: Theme.withAlpha(Theme.surfaceText, 0.65)
                                }

                                CfBlade {
                                    anchors.verticalCenter: parent.verticalCenter
                                    meter: true
                                    width: parent.width - 56 - 44 - 16
                                    value: modelData.value
                                    tide: modelData.name === "Memory"
                                    tone: modelData.alarm ? Theme.error : Theme.primary
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 44
                                    horizontalAlignment: Text.AlignRight
                                    text: modelData.text
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Bold
                                    color: modelData.alarm ? Theme.error : Theme.surfaceText
                                }
                            }
                        }
                    }
                }
            }

            Row {
                spacing: 12
                height: 274

                // Calendar
                Card {
                    id: calendar

                    property date month: new Date(new Date().getFullYear(), new Date().getMonth(), 1)
                    readonly property int offset: month.getDay()

                    width: dash.col * 2 + dash.gap
                    height: parent.height
                    numeral: "IV"
                    glyph: "time"
                    label: "Time · Calendar"

                    function shift(by) {
                        month = new Date(month.getFullYear(), month.getMonth() + by, 1);
                    }

                    Column {
                        anchors.fill: parent
                        spacing: 6

                        Item {
                            width: parent.width
                            height: 24

                            StyledText {
                                anchors.centerIn: parent
                                text: dash.tx(calendar.month.toLocaleDateString(I18n.locale(), "MMMM yyyy"))
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.DemiBold
                                color: Theme.surfaceText
                            }

                            DankIcon {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                name: "chevron_left"
                                size: 22
                                color: Theme.primary

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: calendar.shift(-1)
                                }
                            }

                            DankIcon {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                name: "chevron_right"
                                size: 22
                                color: Theme.primary

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: calendar.shift(1)
                                }
                            }
                        }

                        Grid {
                            id: days
                            readonly property real cell: Math.floor(parent.width / 7)
                            anchors.horizontalCenter: parent.horizontalCenter
                            columns: 7

                            Repeater {
                                model: 7

                                StyledText {
                                    required property int index
                                    width: days.cell
                                    height: 22
                                    horizontalAlignment: Text.AlignHCenter
                                    text: dash.tx(new Date(2023, 0, 1 + index).toLocaleDateString(I18n.locale(), "ddd"))
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.withAlpha(Theme.surfaceText, 0.55)
                                }
                            }

                            Repeater {
                                model: 42

                                Item {
                                    id: day
                                    required property int index
                                    readonly property date when: new Date(calendar.month.getFullYear(), calendar.month.getMonth(), 1 - calendar.offset + index)
                                    readonly property bool inMonth: when.getMonth() === calendar.month.getMonth()
                                    readonly property bool today: when.toDateString() === (clock.date ?? new Date()).toDateString()
                                    width: days.cell
                                    height: 30

                                    Rectangle {
                                        visible: day.today
                                        anchors.centerIn: parent
                                        width: 26
                                        height: 26
                                        radius: Form.phainon || !Form.active ? 13 : 0
                                        rotation: Form.khaslana ? 45 : 0
                                        color: Form.phainon ? "#E9B92E" : Theme.primary
                                    }

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: day.when.getDate()
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: day.today ? Font.DemiBold : Font.Normal
                                        color: day.today ? Theme.primaryText : Theme.withAlpha(Theme.surfaceText, day.inMonth ? 0.95 : 0.3)
                                    }
                                }
                            }
                        }
                    }
                }

                // Music
                Card {
                    width: dash.col
                    height: parent.height
                    clickable: !!dash.player
                    numeral: "V"
                    glyph: "ocean"
                    label: "Ocean · Now playing"
                    onClicked: dash.view = "music"

                    Column {
                        visible: !!dash.player
                        anchors.fill: parent
                        spacing: 8

                        Cover {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 96
                            height: 96
                        }

                        StyledText {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: dash.player?.trackTitle || dash.player?.identity || ""
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.DemiBold
                            color: Theme.surfaceText
                        }

                        StyledText {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: dash.player?.trackArtist || ""
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.withAlpha(Theme.surfaceText, 0.65)
                        }

                        CfBlade {
                            width: parent.width
                            interactive: dash.player?.canSeek ?? false
                            value: dash.player && dash.player.length > 0 ? dash.player.position / dash.player.length : 0
                            onMoved: to => dash.player.position = to * dash.player.length
                        }

                        Transport {
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    StyledText {
                        visible: !dash.player
                        anchors.centerIn: parent
                        text: dash.tx("Nothing playing")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.withAlpha(Theme.surfaceText, 0.55)
                    }
                }
            }

            // The Flame-Chase: twelve Titans' Coreflames, lit as they are gathered
            Item {
                width: parent.width
                height: 34

                Row {
                    anchors.centerIn: parent
                    spacing: 14

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: dash.tx("FLAME-CHASE") + "  " + Coreflames.count + " / 12"
                        font.pixelSize: Theme.fontSizeSmall
                        font.letterSpacing: 1.4
                        color: Theme.withAlpha(Theme.surfaceText, 0.6)
                    }

                    Repeater {
                        model: Coreflames.order

                        CfGlyph {
                            required property string modelData
                            readonly property bool lit: Coreflames.has(modelData) && Coreflames.count >= 0
                            anchors.verticalCenter: parent.verticalCenter
                            name: modelData
                            size: 18
                            strokeWidth: lit ? 1.9 : 1.3
                            color: lit ? Theme.primary : Theme.withAlpha(Theme.surfaceText, 0.22)

                            HoverHandler {
                                id: titanHover
                            }

                            ToolTip.visible: titanHover.hovered
                            ToolTip.text: Coreflames.titans[modelData][0] + " · " + Coreflames.titans[modelData][1]
                        }
                    }
                }
            }

            Row {
                spacing: dash.gap

                Chip {
                    width: dash.quarter
                    icon: "wallpaper"
                    label: "Wallpapers"
                    onClicked: dash.view = "wallpaper"
                }

                Chip {
                    width: dash.quarter
                    icon: "music_note"
                    label: "Music"
                    on: dash.playing
                    onClicked: dash.view = "music"
                }

                Chip {
                    width: dash.quarter
                    icon: "timer"
                    label: Chrono.timerActive ? "Timer " + Chrono.format(Chrono.timerLeft) : "Timer"
                    on: Chrono.timerActive
                    onClicked: dash.view = "time"
                }

                Chip {
                    width: dash.quarter
                    icon: "partly_cloudy_day"
                    label: "Forecast"
                    onClicked: dash.view = "weather"
                }
            }

            // Aedes Elysiae: a line of wheat under the Phainon summary
            CfWheat {
                visible: Form.phainon
                width: parent.width
                height: 22
                spacing: 12
            }
        }
    }

    // ── the Flame Reaver's summary: a ledger. No cards, no icons, everything flush left. ──
    Component {
        id: ledgerView

        Column {
            id: ledger
            spacing: 14

            readonly property MprisPlayer player: MprisController.activePlayer
            readonly property var lines: [["time", (clock.date?.toLocaleTimeString(I18n.locale(), SettingsData.use24HourClock ? "HH:mm" : "h:mm ap") ?? "") + "  ·  " + (clock.date?.toLocaleDateString(I18n.locale(), "dddd d MMMM") ?? "") + "  ·  " + Form.dawnPeriod(clock.date?.getHours() ?? 0)], ["sky", WeatherService.weather.available ? WeatherService.currentTempText(false) + "  ·  " + WeatherService.getWeatherCondition(WeatherService.weather.wCode) + "  ·  " + (WeatherService.weather.city ?? "") : "nothing."], ["law", "cpu " + Math.round(DgopService.cpuUsage || 0) + "  ·  heat " + Math.round(DgopService.cpuTemperature || 0) + "°  ·  mem " + Math.round(DgopService.memoryUsage || 0)], ["ocean", player ? (player.trackTitle || player.identity || "") + (player.trackArtist ? "  ·  " + player.trackArtist : "") : "nothing."], ["coreflames", Coreflames.count + " of 12 gathered  ·  " + Coreflames.order.filter(n => Coreflames.has(n)).map(n => Coreflames.titans[n][0].toLowerCase()).join(", ")], ["cycle", Form.cycleText + "  ·  all is futility."]]

            // Label column as wide as the longest label, so every value starts on the same line.
            TextMetrics {
                id: labelWidth
                font.family: Theme.monoFontFamily
                font.pixelSize: Theme.fontSizeMedium
                text: "// coreflames"
            }

            Column {
                spacing: 7

                Repeater {
                    model: ledger.lines

                    Row {
                        required property var modelData
                        spacing: 0

                        Text {
                            width: Math.ceil(labelWidth.advanceWidth) + 18
                            text: "// " + modelData[0]
                            font.family: Theme.monoFontFamily
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.withAlpha(Theme.surfaceText, 0.45)
                        }

                        Text {
                            width: dash.panelWidth - 36 - Math.ceil(labelWidth.advanceWidth) - 18
                            elide: Text.ElideRight
                            text: String(modelData[1]).toLowerCase()
                            font.family: Theme.monoFontFamily
                            font.pixelSize: Theme.fontSizeMedium
                            color: modelData[0] === "cycle" ? Theme.live : Theme.surfaceText
                        }
                    }
                }
            }

            Rectangle {
                width: dash.panelWidth - 36
                height: 1
                color: Theme.withAlpha(Theme.surfaceText, 0.15)
            }

            Row {
                spacing: 40

                // The month, as plain figures
                Column {
                    id: month
                    readonly property date first: new Date((clock.date ?? new Date()).getFullYear(), (clock.date ?? new Date()).getMonth(), 1)
                    spacing: 4

                    Text {
                        text: "// " + month.first.toLocaleDateString(I18n.locale(), "MMMM yyyy").toLowerCase()
                        font.family: Theme.monoFontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.withAlpha(Theme.surfaceText, 0.45)
                    }

                    // Cells exactly two digits wide, so the grid starts under its heading and a struck-out
                    // single digit does not strike a padding space too.
                    TextMetrics {
                        id: twoDigits
                        font.family: Theme.monoFontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        text: "00"
                    }

                    Grid {
                        columns: 7
                        columnSpacing: 38 - cellWidth
                        readonly property real cellWidth: Math.ceil(twoDigits.advanceWidth)

                        Repeater {
                            model: 42

                            Text {
                                required property int index
                                readonly property date when: new Date(month.first.getFullYear(), month.first.getMonth(), 1 - month.first.getDay() + index)
                                readonly property bool today: when.toDateString() === (clock.date ?? new Date()).toDateString()
                                width: parent.cellWidth
                                height: 24
                                horizontalAlignment: Text.AlignRight
                                text: when.getDate()
                                font.family: Theme.monoFontFamily
                                font.pixelSize: Theme.fontSizeMedium
                                font.underline: today
                                font.strikeout: when.getMonth() === month.first.getMonth() && when < (clock.date ?? new Date()) && !today
                                color: today ? Theme.live : Theme.withAlpha(Theme.surfaceText, when.getMonth() === month.first.getMonth() ? 0.8 : 0.2)
                            }
                        }
                    }
                }

                Column {
                    spacing: 4

                    Text {
                        text: "// ocean"
                        font.family: Theme.monoFontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.withAlpha(Theme.surfaceText, 0.45)
                    }

                    Column {
                        visible: !!ledger.player
                        spacing: 10

                        Transport {}

                        CfBlade {
                            width: 300
                            interactive: ledger.player?.canSeek ?? false
                            value: ledger.player && ledger.player.length > 0 ? ledger.player.position / ledger.player.length : 0
                            onMoved: to => ledger.player.position = to * ledger.player.length
                        }
                    }

                    Text {
                        visible: !ledger.player
                        text: "nothing."
                        font.family: Theme.monoFontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.withAlpha(Theme.surfaceText, 0.5)
                    }
                }
            }

            Row {
                spacing: dash.gap

                Chip {
                    width: dash.quarter
                    label: "wallpapers"
                    onClicked: dash.view = "wallpaper"
                }

                Chip {
                    width: dash.quarter
                    label: "music"
                    on: dash.playing
                    onClicked: dash.view = "music"
                }

                Chip {
                    width: dash.quarter
                    label: Chrono.timerActive ? "timer " + Chrono.format(Chrono.timerLeft) : "timer"
                    on: Chrono.timerActive
                    onClicked: dash.view = "time"
                }

                Chip {
                    width: dash.quarter
                    label: "forecast"
                    onClicked: dash.view = "weather"
                }
            }
        }
    }

    // ── full player ──
    Component {
        id: musicView

        Row {
            spacing: 28
            height: 240

            Cover {
                anchors.verticalCenter: parent.verticalCenter
                width: 240
                height: 240
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 240 - 28
                spacing: 12

                StyledText {
                    width: parent.width
                    elide: Text.ElideRight
                    text: dash.player?.trackTitle || dash.tx("Nothing playing")
                    font.pixelSize: 26
                    font.weight: Font.DemiBold
                    color: Theme.surfaceText
                }

                StyledText {
                    width: parent.width
                    elide: Text.ElideRight
                    text: [dash.player?.trackArtist, dash.player?.trackAlbum].filter(t => !!t).join(" · ")
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.withAlpha(Theme.surfaceText, 0.7)
                }

                CfBlade {
                    width: parent.width
                    interactive: dash.player?.canSeek ?? false
                    value: dash.player && dash.player.length > 0 ? dash.player.position / dash.player.length : 0
                    onMoved: to => dash.player.position = to * dash.player.length
                }

                Item {
                    width: parent.width
                    height: 20

                    StyledText {
                        text: Chrono.format(Math.floor(dash.player?.position ?? 0))
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.withAlpha(Theme.surfaceText, 0.6)
                    }

                    StyledText {
                        anchors.right: parent.right
                        text: Chrono.format(Math.floor(dash.player?.length ?? 0))
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.withAlpha(Theme.surfaceText, 0.6)
                    }
                }

                Transport {
                    iconSize: 32
                }

                // Which player this is; with more than one open, pick between them here.
                StyledText {
                    visible: MprisController.availablePlayers.length <= 1
                    text: dash.tx(dash.player?.identity ?? "")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.withAlpha(Theme.surfaceText, 0.5)
                }

                Row {
                    visible: MprisController.availablePlayers.length > 1
                    spacing: 8

                    Repeater {
                        model: MprisController.availablePlayers

                        Chip {
                            required property var modelData
                            icon: "graphic_eq"
                            label: modelData.identity ?? "Player"
                            on: modelData === dash.player
                            onClicked: MprisController.setActivePlayer(modelData)
                        }
                    }
                }
            }
        }
    }

    // ── timer and stopwatch ──
    Component {
        id: timeView

        Row {
            spacing: 12
            height: 266

            Card {
                width: (parent.width - 12) / 2
                height: parent.height

                // Both cards start their figures at the same height, so the two clocks line up.
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 28
                    spacing: 14

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Chrono.format(Chrono.timerLeft)
                        font.pixelSize: 52
                        font.weight: Font.DemiBold
                        color: Chrono.timerActive ? Theme.primary : Theme.withAlpha(Theme.surfaceText, 0.5)
                    }

                    CfBlade {
                        anchors.horizontalCenter: parent.horizontalCenter
                        meter: true
                        width: 300
                        value: Chrono.timerTotal > 0 ? Chrono.timerLeft / Chrono.timerTotal : 0
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8

                        Repeater {
                            model: [5, 15, 25, 45]

                            Chip {
                                required property int modelData
                                label: modelData + " min"
                                onClicked: Chrono.startTimer(modelData * 60)
                            }
                        }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8

                        Chip {
                            icon: Chrono.timerRunning ? "pause" : "play_arrow"
                            label: Chrono.timerRunning ? "Pause" : "Resume"
                            on: Chrono.timerRunning
                            onClicked: Chrono.toggleTimer()
                        }

                        Chip {
                            icon: "restart_alt"
                            label: "Clear"
                            onClicked: Chrono.resetTimer()
                        }
                    }
                }
            }

            Card {
                width: (parent.width - 12) / 2
                height: parent.height

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 28
                    spacing: 14

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Chrono.format(Chrono.stopwatchSeconds)
                        font.pixelSize: 52
                        font.weight: Font.DemiBold
                        color: Chrono.stopwatchRunning ? Theme.primary : Theme.surfaceText
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: dash.tx("Stopwatch")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.withAlpha(Theme.surfaceText, 0.6)
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8

                        Chip {
                            icon: Chrono.stopwatchRunning ? "pause" : "play_arrow"
                            label: Chrono.stopwatchRunning ? "Stop" : "Start"
                            on: Chrono.stopwatchRunning
                            onClicked: Chrono.toggleStopwatch()
                        }

                        Chip {
                            icon: "restart_alt"
                            label: "Reset"
                            onClicked: Chrono.resetStopwatch()
                        }
                    }
                }
            }
        }
    }

    // ── forecast ──
    Component {
        id: weatherView

        Column {
            id: forecast
            spacing: dash.gap

            readonly property var weather: WeatherService.weather
            readonly property var days: (weather.forecast ?? []).slice(0, 7)
            readonly property var hours: (weather.hourlyForecast ?? []).slice(0, 9)

            function degrees(celsius) {
                if (celsius === undefined || celsius === null)
                    return "--";
                return Math.round(SettingsData.useFahrenheit ? celsius * 9 / 5 + 32 : celsius) + "°";
            }

            Row {
                spacing: dash.gap
                height: 120

                Card {
                    width: dash.col * 2 + dash.gap
                    height: parent.height

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 18

                        DankIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: forecast.weather.available ? WeatherService.getWeatherIcon(forecast.weather.wCode) : "cloud_off"
                            size: 64
                            color: Theme.primary
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            StyledText {
                                text: forecast.weather.available ? WeatherService.currentTempText(false) : "--"
                                font.pixelSize: 34
                                font.weight: Font.DemiBold
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: dash.tx(forecast.weather.available ? WeatherService.getWeatherCondition(forecast.weather.wCode) : "No weather data")
                                font.pixelSize: Theme.fontSizeLarge
                                color: Theme.withAlpha(Theme.surfaceText, 0.8)
                            }

                            StyledText {
                                text: dash.tx(forecast.weather.city ?? "")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.withAlpha(Theme.surfaceText, 0.55)
                            }
                        }
                    }
                }

                Card {
                    width: dash.col
                    height: parent.height

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: [
                                {
                                    "icon": "humidity_percentage",
                                    "label": "Humidity",
                                    "value": forecast.weather.humidity !== undefined ? forecast.weather.humidity + "%" : "--"
                                },
                                {
                                    "icon": "air",
                                    "label": "Wind",
                                    "value": forecast.weather.wind ?? "--"
                                },
                                {
                                    "icon": "wb_twilight",
                                    "label": "Sunrise",
                                    "value": forecast.weather.sunrise ?? "--"
                                },
                                {
                                    "icon": "nights_stay",
                                    "label": "Sunset",
                                    "value": forecast.weather.sunset ?? "--"
                                }
                            ]

                            Item {
                                required property var modelData
                                width: parent.width
                                height: 18

                                Row {
                                    spacing: 6

                                    DankIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: modelData.icon
                                        size: 15
                                        color: Theme.primary
                                    }

                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: dash.tx(modelData.label)
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.withAlpha(Theme.surfaceText, 0.65)
                                    }
                                }

                                StyledText {
                                    anchors.right: parent.right
                                    text: dash.tx(String(modelData.value))
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.DemiBold
                                    color: Theme.surfaceText
                                }
                            }
                        }
                    }
                }
            }

            // The week
            Row {
                id: week
                readonly property real cardWidth: Math.floor((dash.panelWidth - 36 - 6 * 8) / 7)
                spacing: 8
                height: 124

                Repeater {
                    model: forecast.days

                    Card {
                        required property var modelData
                        required property int index
                        width: week.cardWidth
                        height: parent.height

                        Column {
                            anchors.centerIn: parent
                            spacing: 6

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: dash.tx(index === 0 ? "Today" : String(modelData.day ?? "").substring(0, 3))
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.DemiBold
                                color: index === 0 ? Theme.primary : Theme.withAlpha(Theme.surfaceText, 0.7)
                            }

                            DankIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                name: WeatherService.getWeatherIcon(modelData.wCode)
                                size: 28
                                color: Theme.primary
                            }

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: forecast.degrees(modelData.tempMax)
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.DemiBold
                                color: Theme.surfaceText
                            }

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: forecast.degrees(modelData.tempMin)
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.withAlpha(Theme.surfaceText, 0.55)
                            }
                        }
                    }
                }
            }

            // The next hours
            Card {
                visible: forecast.hours.length > 0
                width: dash.panelWidth - 36
                height: 86

                Row {
                    anchors.centerIn: parent
                    spacing: 0

                    Repeater {
                        model: forecast.hours

                        Column {
                            required property var modelData
                            width: Math.floor((dash.panelWidth - 36 - 28) / 9)
                            spacing: 3

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: dash.tx(String(modelData.time ?? ""))
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.withAlpha(Theme.surfaceText, 0.55)
                            }

                            DankIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                name: WeatherService.getWeatherIcon(modelData.wCode)
                                size: 20
                                color: Theme.primary
                            }

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: forecast.degrees(modelData.temp)
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.DemiBold
                                color: Theme.surfaceText
                            }
                        }
                    }
                }
            }
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

                    DankIcon {
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

                    DankIcon {
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
