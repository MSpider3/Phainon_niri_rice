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

        // A full view hangs from the island as one tab. The overview has no header of its own: the
        // island stays in sight above it and the form's layout below draws its own frame.
        CfTab {
            visible: dash.view !== ""
            anchors.fill: parent
            side: "center"
        }

        CfOrnament {
            id: ornament
            visible: dash.view !== ""
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

        // Header of a full view: back, and the view's name
        Row {
            id: header
            visible: dash.view !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            height: dash.strip
            spacing: 10

            DIcon {
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
