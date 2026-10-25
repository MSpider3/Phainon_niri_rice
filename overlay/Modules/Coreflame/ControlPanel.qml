import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import qs.Widgets

// The control centre: one tall panel dropping from the right corner. Forms, sliders, toggles,
// system readings, tray, and a collapsible notification list.
PanelWindow {
    id: panelWin

    required property var targetScreen
    property int strip: 40
    property bool shown: false
    property real reveal: shown ? 1 : 0
    property bool notificationsOpen: true
    property bool batteryOpen: false
    // Which list is open under the tiles: "", "wifi", "bluetooth", "output", or "plugin:<id>"
    property string openList: ""
    // The secured network waiting for a password
    property string askSsid: ""
    property bool leaveArmed: false

    function toggleList(name) {
        openList = openList === name ? "" : name;
        askSsid = "";
        if (openList === "wifi" && NetworkService.wifiEnabled)
            NetworkService.scanWifi();
    }

    // Plugin widgets that offer a control-centre tile (KDE Connect and the like)
    readonly property var pluginIds: Object.keys(PluginService.pluginWidgetComponents ?? {}).filter(id => !Form.heldPlugins.includes(id))

    readonly property real panelWidth: 420
    readonly property real tileWidth: Form.reaver ? panelWidth - pad * 2 : (panelWidth - pad * 2 - 8) / 2

    // Asks for DMS's own control centre, which has the network, device and output lists.
    signal detailsRequested

    readonly property var btDevice: BluetoothService.adapter?.devices?.values?.find(d => d.connected) ?? null
    readonly property real pad: 16

    function open() {
        shown = true;
    }

    function close() {
        shown = false;
        leaveArmed = false;
        askSsid = "";
        openList = "";
        batteryOpen = false;
        hours.open = false;
    }

    function toggle() {
        if (shown)
            close();
        else
            shown = true;
    }

    function tx(text) {
        return Form.reaver ? String(text).toLowerCase() : text;
    }

    function ipc(target, fn, arg) {
        const cmd = ["dms", "ipc", "call", target, fn];
        if (arg !== undefined)
            cmd.push(arg);
        Quickshell.execDetached(cmd);
    }

    function rate(bytes) {
        if (bytes >= 1048576)
            return (bytes / 1048576).toFixed(1) + " MB/s";
        if (bytes >= 1024)
            return Math.round(bytes / 1024) + " KB/s";
        return Math.round(bytes || 0) + " B/s";
    }

    screen: targetScreen
    visible: reveal > 0.001
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "coreflame:control"
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
            easing.overshoot: 0.6
        }
    }

    // Destroyed while open (a screen unplugged, another theme picked): release what opening took.
    Component.onDestruction: {
        if (shown)
            shown = false;
    }

    onShownChanged: {
        if (shown) {
            DgopService.addRef(["cpu", "memory", "network", "system"]);
            panel.forceActiveFocus();
            if (NetworkService.wifiEnabled)
                NetworkService.scanWifi();
        } else {
            DgopService.removeRef(["cpu", "memory", "network", "system"]);
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: panelWin.close()
    }

    component Tile: Item {
        id: tile

        property string icon: ""
        // A Titan sigil to draw instead of the icon, where the tile belongs to one domain
        property string glyph: ""
        property string label: ""
        property string sub: ""
        property bool on: false
        // A tile that only opens something (no on/off state) is never shown as switched off.
        property bool action: false
        // Shows a chevron that opens a list under the tiles
        property bool expandable: false
        property bool expanded: false
        // Phainon fills an active tile with lapis. Khaslana and the Flame Reaver keep the plate dark
        // and mark it with a bar, so one colour is not doing every job.
        readonly property bool filled: on && (Form.phainon || !Form.active)
        // The Flame Reaver's tiles are single ledger lines.
        readonly property bool line: Form.reaver
        signal clicked
        signal expand

        implicitHeight: line ? 38 : 56

        CfSurface {
            anchors.fill: parent
            color: tile.filled ? Theme.primary : ((tileMouse.containsMouse || tile.on) ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)
            edgeColor: Theme.withAlpha(Theme.outline, Form.khaslana ? (tile.on ? 0.9 : 0.4) : 0.45)
            edgeWidth: Form.reaver ? 0 : 1
            radius: 16
        }

        // Khaslana's bar is molten: gold through orange to red. The Flame Reaver's is the one live colour.
        Rectangle {
            visible: tile.on && !tile.filled
            x: Form.khaslana ? 9 : 0
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: parent.height - (Form.khaslana ? 20 : 0)
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Form.khaslana ? Theme.primary : Theme.live
                }
                GradientStop {
                    position: 0.55
                    color: Form.khaslana ? Theme.secondary : Theme.live
                }
                GradientStop {
                    position: 1
                    color: Form.khaslana ? Theme.error : Theme.live
                }
            }
        }

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.clicked()
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            x: 18
            spacing: 10

            DankIcon {
                visible: !tile.line && tile.glyph === ""
                anchors.verticalCenter: parent.verticalCenter
                name: tile.icon
                size: 22
                color: tile.filled ? Theme.primaryText : (tile.on ? Theme.primary : Theme.withAlpha(Theme.surfaceText, 0.6))
            }

            CfGlyph {
                visible: !tile.line && tile.glyph !== ""
                anchors.verticalCenter: parent.verticalCenter
                name: tile.glyph
                size: 22
                strokeWidth: 1.9
                color: tile.filled ? Theme.primaryText : (tile.on ? Theme.primary : Theme.withAlpha(Theme.surfaceText, 0.6))
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                StyledText {
                    width: tile.width - (tile.line ? 36 : 64) - (tile.expandable ? 30 : 0)
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    text: {
                        const full = tile.line && tile.sub !== "" ? tile.label + "  ·  " + tile.sub.replace(/ · /g, "  ·  ") : tile.label;
                        return Form.reaver ? full.toLowerCase() : full;
                    }
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: tile.on ? Font.Bold : Font.Medium
                    font.strikeout: Form.reaver && !tile.on && !tile.action
                    color: tile.filled ? Theme.primaryText : (tile.on ? Theme.surfaceText : Theme.withAlpha(Theme.surfaceText, 0.8))
                }

                StyledText {
                    visible: tile.sub !== "" && !tile.line
                    width: tile.width - 64 - (tile.expandable ? 30 : 0)
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    text: tile.sub
                    font.pixelSize: Theme.fontSizeSmall
                    color: tile.filled ? Theme.withAlpha(Theme.primaryText, 0.8) : Theme.withAlpha(Theme.surfaceText, 0.55)
                }
            }
        }

        // Opens the list for this tile
        Item {
            visible: tile.expandable
            anchors.right: parent.right
            width: 34
            height: parent.height

            DankIcon {
                anchors.centerIn: parent
                name: tile.expanded ? "expand_less" : "expand_more"
                size: 20
                color: tile.filled ? Theme.primaryText : Theme.primary
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: tile.expand()
            }
        }
    }

    // One line in a list under the tiles
    component ListRow: Item {
        id: listRow

        property string icon: ""
        property string label: ""
        property string note: ""
        property bool current: false
        signal clicked

        height: 36

        Rectangle {
            anchors.fill: parent
            visible: rowMouse.containsMouse
            color: Theme.withAlpha(Theme.surfaceText, 0.07)
        }

        DankIcon {
            visible: !Form.reaver
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            name: listRow.icon
            size: 18
            color: listRow.current ? Theme.live : Theme.withAlpha(Theme.surfaceText, 0.6)
        }

        StyledText {
            x: Form.reaver ? 28 : 36
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - noteText.width - 18
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
            text: Form.reaver ? listRow.label.toLowerCase() : listRow.label
            font.pixelSize: Theme.fontSizeMedium
            font.weight: listRow.current ? Font.Bold : Font.Medium
            color: listRow.current ? Theme.surfaceText : Theme.withAlpha(Theme.surfaceText, 0.85)
        }

        StyledText {
            visible: Form.reaver && listRow.current
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            text: ">"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Bold
            color: Theme.live
        }

        StyledText {
            id: noteText
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: Form.reaver ? listRow.note.toLowerCase() : listRow.note
            font.pixelSize: Theme.fontSizeSmall
            color: listRow.current ? Theme.live : Theme.withAlpha(Theme.surfaceText, 0.55)
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: listRow.clicked()
        }
    }

    component IconButton: DankIcon {
        id: iconButton
        signal clicked
        size: 20
        color: Theme.primary

        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: iconButton.clicked()
        }
    }

    component Heading: StyledText {
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.DemiBold
        font.letterSpacing: 1.2
        color: Theme.withAlpha(Theme.surfaceText, 0.55)
    }

    Item {
        id: panel

        // The panel runs the full height of the screen.
        readonly property real fullHeight: panelWin.height

        width: Math.round(200 + (panelWin.panelWidth - 200) * panelWin.reveal)
        height: Math.round(panelWin.strip + (fullHeight - panelWin.strip) * panelWin.reveal)
        x: panelWin.width - width
        clip: true
        focus: true

        Keys.onEscapePressed: panelWin.close()

        CfTab {
            anchors.fill: parent
            side: "right"
        }

        CfOrnament {
            id: ornament
            anchors.fill: parent
        }

        Connections {
            target: panelWin

            function onShownChanged() {
                if (panelWin.shown)
                    ornament.play();
            }
        }

        MouseArea {
            anchors.fill: parent
        }

        // Who is signed in, and the session buttons
        Item {
            id: userCard
            x: panelWin.pad
            y: 10
            width: panelWin.panelWidth - panelWin.pad * 2
            height: 64
            opacity: panelWin.reveal

            CfSurface {
                anchors.fill: parent
                color: Theme.surfaceContainerHigh
                edgeColor: Theme.withAlpha(Theme.outline, Form.khaslana ? 0.9 : 0.45)
                edgeWidth: Form.reaver ? 0 : 1
                radius: 18
            }

            ClippingRectangle {
                id: avatar
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 44
                radius: Form.phainon || !Form.active ? 22 : 0
                color: Theme.surfaceContainerHighest

                Image {
                    id: face
                    anchors.fill: parent
                    source: {
                        const img = PortalService.profileImage ?? "";
                        return img === "" ? "" : (img.startsWith("/") ? "file://" + img : img);
                    }
                    sourceSize: Qt.size(96, 96)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }

                DankIcon {
                    anchors.centerIn: parent
                    visible: face.status !== Image.Ready
                    name: "person"
                    size: 24
                    color: Theme.primary
                }
            }

            Column {
                x: 64
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                StyledText {
                    text: UserInfoService.fullName || UserInfoService.username || "NeiKos496"
                    font.family: Form.display(Theme.fontFamily)
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.DemiBold
                    color: Theme.surfaceText
                }

                StyledText {
                    width: userCard.width - 64 - 150
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    maximumLineCount: 1
                    text: panelWin.tx(DgopService.uptime || "NeiKos496")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.withAlpha(Theme.surfaceText, 0.6)
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14

                IconButton {
                    name: "lock"
                    onClicked: {
                        panelWin.close();
                        panelWin.ipc("lock", "lock");
                    }
                }

                IconButton {
                    name: "power_settings_new"
                    onClicked: {
                        panelWin.close();
                        panelWin.ipc("powermenu", "toggle");
                    }
                }

                IconButton {
                    name: "settings"
                    onClicked: {
                        panelWin.close();
                        panelWin.ipc("settings", "focusOrToggle");
                    }
                }
            }
        }

        Flickable {
            x: panelWin.pad
            y: 86
            width: panelWin.panelWidth - panelWin.pad * 2
            height: parent.height - y - panelWin.pad - (Form.reaver ? 8 : 0)
            contentHeight: content.implicitHeight
            clip: true
            opacity: panelWin.reveal
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: content
                width: parent.width
                spacing: 12

                // Forms
                Row {
                    id: forms
                    width: parent.width
                    spacing: 8

                    Repeater {
                        model: [
                            {
                                "id": "phainon",
                                "label": "Phainon",
                                "icon": "wb_sunny"
                            },
                            {
                                "id": "khaslana",
                                "label": "Khaslana",
                                "icon": "local_fire_department"
                            },
                            {
                                "id": "reaver",
                                "label": "Reaver",
                                "icon": "dark_mode"
                            }
                        ]

                        Item {
                            id: formButton
                            required property var modelData
                            readonly property bool current: Form.form === modelData.id
                            width: (forms.width - 16) / 3
                            height: 36

                            CfSurface {
                                anchors.fill: parent
                                color: formButton.current ? Theme.primary : Theme.surfaceContainerHigh
                                edgeColor: Theme.withAlpha(Theme.outline, 0.6)
                                edgeWidth: Form.reaver ? 0 : 1
                                radius: 18
                            }

                            Row {
                                anchors.centerIn: parent
                                spacing: 5

                                DankIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: formButton.modelData.icon
                                    size: 16
                                    color: formButton.current ? Theme.primaryText : Theme.primary
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: panelWin.tx(formButton.modelData.label)
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: formButton.current ? Theme.primaryText : Theme.surfaceText
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: panelWin.ipc("form", "set", formButton.modelData.id)
                            }
                        }
                    }
                }

                // Forms by the hour
                Column {
                    id: hours
                    property bool open: false
                    width: parent.width
                    spacing: 6

                    Item {
                        width: parent.width
                        height: 34

                        CfSurface {
                            anchors.fill: parent
                            color: Theme.surfaceContainerHigh
                            edgeColor: Theme.withAlpha(Theme.outline, Form.khaslana ? 0.9 : 0.45)
                            edgeWidth: Form.reaver ? 0 : 1
                            radius: 17
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: hours.open = !hours.open
                        }

                        Row {
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            DankIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "schedule"
                                size: 16
                                color: Form.schedule.enabled ? Theme.live : Theme.withAlpha(Theme.surfaceText, 0.55)
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: panelWin.tx(Form.schedule.enabled ? "By the hour · " + Form.schedule.phainon + " / " + Form.schedule.khaslana + " / " + Form.schedule.reaver : "Change form by the hour")
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Item {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 44
                                height: 22

                                CfSurface {
                                    anchors.fill: parent
                                    color: Form.schedule.enabled ? Theme.primary : Theme.surfaceContainerHighest
                                    edgeWidth: 0
                                    radius: 11
                                    cut: 5
                                }

                                StyledText {
                                    anchors.centerIn: parent
                                    text: panelWin.tx(Form.schedule.enabled ? "On" : "Off")
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Bold
                                    color: Form.schedule.enabled ? Theme.primaryText : Theme.withAlpha(Theme.surfaceText, 0.7)
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Form.setScheduleEnabled(!Form.schedule.enabled)
                                }
                            }

                            DankIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: hours.open ? "expand_less" : "expand_more"
                                size: 18
                                color: Theme.withAlpha(Theme.surfaceText, 0.7)
                            }
                        }
                    }

                    Item {
                        visible: hours.open
                        width: parent.width
                        height: hoursColumn.implicitHeight + 20

                        CfSurface {
                            anchors.fill: parent
                            color: Theme.surfaceContainerHigh
                            edgeColor: Theme.withAlpha(Theme.outline, Form.khaslana ? 0.9 : 0.45)
                            edgeWidth: Form.reaver ? 0 : 1
                            radius: 18
                        }

                        Column {
                            id: hoursColumn
                            x: 14
                            y: 10
                            width: parent.width - 28
                            spacing: 6

                            Heading {
                                text: panelWin.tx("TIME · EACH FORM STARTS AT")
                            }

                            Repeater {
                                model: [
                                    {
                                        "id": "phainon",
                                        "label": "Phainon"
                                    },
                                    {
                                        "id": "khaslana",
                                        "label": "Khaslana"
                                    },
                                    {
                                        "id": "reaver",
                                        "label": "Flame Reaver"
                                    }
                                ]

                                Item {
                                    id: hourRow
                                    required property var modelData
                                    width: hoursColumn.width
                                    height: 30

                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: panelWin.tx(hourRow.modelData.label)
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Form.lastScheduled === hourRow.modelData.id && Form.schedule.enabled ? Font.Bold : Font.Medium
                                        color: Theme.surfaceText
                                    }

                                    Row {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4

                                        Repeater {
                                            model: [
                                                {
                                                    "text": "−1h",
                                                    "by": -60
                                                },
                                                {
                                                    "text": "−15",
                                                    "by": -15
                                                },
                                                {
                                                    "text": "",
                                                    "by": 0
                                                },
                                                {
                                                    "text": "+15",
                                                    "by": 15
                                                },
                                                {
                                                    "text": "+1h",
                                                    "by": 60
                                                }
                                            ]

                                            Item {
                                                id: step
                                                required property var modelData
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: modelData.by === 0 ? 58 : 38
                                                height: 24

                                                CfSurface {
                                                    anchors.fill: parent
                                                    visible: step.modelData.by !== 0
                                                    color: stepMouse.containsMouse ? Theme.withAlpha(Theme.primary, 0.25) : Theme.surfaceContainerHighest
                                                    edgeWidth: 0
                                                    radius: 12
                                                    cut: 5
                                                }

                                                StyledText {
                                                    anchors.centerIn: parent
                                                    text: step.modelData.by === 0 ? Form.schedule[hourRow.modelData.id] : step.modelData.text
                                                    font.family: step.modelData.by === 0 ? Theme.monoFontFamily : Theme.fontFamily
                                                    font.pixelSize: step.modelData.by === 0 ? Theme.fontSizeMedium : Theme.fontSizeSmall
                                                    font.weight: step.modelData.by === 0 ? Font.Bold : Font.Medium
                                                    color: step.modelData.by === 0 ? Theme.live : Theme.surfaceText
                                                }

                                                MouseArea {
                                                    id: stepMouse
                                                    anchors.fill: parent
                                                    enabled: step.modelData.by !== 0
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: Form.shiftStart(hourRow.modelData.id, step.modelData.by)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            StyledText {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: panelWin.tx("A form you pick by hand stays until the next start time.")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.withAlpha(Theme.surfaceText, 0.55)
                            }
                        }
                    }
                }

                // Sliders
                Column {
                    width: parent.width
                    spacing: 10

                    Row {
                        width: parent.width
                        spacing: 10

                        DankIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: AudioService.sinkVolumeIconName
                            size: 20
                            color: Theme.surfaceText

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -5
                                cursorShape: Qt.PointingHandCursor
                                onClicked: AudioService.toggleMute()
                            }
                        }

                        CfBlade {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 20 - 46 - 20
                            interactive: true
                            value: AudioService.sink?.audio?.muted ? 0 : (AudioService.sink?.audio?.volume ?? 0)
                            onMoved: to => {
                                if (!AudioService.sink?.audio)
                                    return;
                                AudioService.sink.audio.muted = false;
                                AudioService.sink.audio.volume = to;
                            }
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 46
                            horizontalAlignment: Text.AlignRight
                            text: Math.round((AudioService.sink?.audio?.volume ?? 0) * 100) + "%"
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                        }
                    }

                    Row {
                        visible: DisplayService.brightnessAvailable
                        width: parent.width
                        spacing: 10

                        DankIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "brightness_6"
                            size: 20
                            color: Theme.surfaceText
                        }

                        CfBlade {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 20 - 46 - 20
                            interactive: true
                            value: DisplayService.brightnessLevel / 100
                            onMoved: to => DisplayService.setBrightness(Math.max(1, Math.round(to * 100)), DisplayService.lastIpcDevice, true)
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 46
                            horizontalAlignment: Text.AlignRight
                            text: DisplayService.brightnessLevel + "%"
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                        }
                    }
                    Row {
                        visible: !!AudioService.source?.audio
                        width: parent.width
                        spacing: 10

                        DankIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: AudioService.source?.audio?.muted ? "mic_off" : "mic"
                            size: 20
                            color: Theme.surfaceText

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -5
                                cursorShape: Qt.PointingHandCursor
                                onClicked: AudioService.toggleMicMute()
                            }
                        }

                        CfBlade {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 20 - 46 - 20
                            interactive: true
                            value: AudioService.source?.audio?.muted ? 0 : (AudioService.source?.audio?.volume ?? 0)
                            onMoved: to => {
                                if (!AudioService.source?.audio)
                                    return;
                                AudioService.source.audio.muted = false;
                                AudioService.source.audio.volume = to;
                            }
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 46
                            horizontalAlignment: Text.AlignRight
                            text: Math.round((AudioService.source?.audio?.volume ?? 0) * 100) + "%"
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                        }
                    }
                }

                // Network speed, the way the bar used to show it
                Item {
                    width: parent.width
                    height: 40

                    CfSurface {
                        anchors.fill: parent
                        color: Theme.surfaceContainerHigh
                        edgeColor: Theme.withAlpha(Theme.outline, Form.khaslana ? 0.9 : 0.45)
                        edgeWidth: Form.reaver ? 0 : 1
                        radius: 20
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 22

                        Row {
                            spacing: 5

                            DankIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "arrow_upward"
                                size: 18
                                color: Theme.error
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: panelWin.rate(DgopService.networkTxRate)
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.DemiBold
                                color: Theme.surfaceText
                            }
                        }

                        Row {
                            spacing: 5

                            DankIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "arrow_downward"
                                size: 18
                                color: Theme.primary
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: panelWin.rate(DgopService.networkRxRate)
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.DemiBold
                                color: Theme.surfaceText
                            }
                        }
                    }
                }

                // The list that opens directly under a tile's row
                Component {
                    id: listBlock

                    Item {
                        width: parent ? parent.width : 0
                        height: listColumn.implicitHeight + 20

                        CfSurface {
                            anchors.fill: parent
                            color: Theme.surfaceContainerHigh
                            edgeColor: Theme.withAlpha(Theme.outline, Form.khaslana ? 0.9 : 0.45)
                            edgeWidth: Form.reaver ? 0 : 1
                            radius: 18
                        }

                        Column {
                            id: listColumn
                            x: 8
                            y: 10
                            width: parent.width - 16
                            spacing: 2

                            Heading {
                                x: 8
                                bottomPadding: 4
                                text: panelWin.tx(panelWin.openList === "wifi" ? "PASSAGE · WI-FI NETWORKS" : (panelWin.openList === "bluetooth" ? "PASSAGE · BLUETOOTH DEVICES" : (panelWin.openList === "output" ? "OCEAN · SOUND OUTPUT" : (panelWin.openList === "input" ? "OCEAN · MICROPHONE" : "PLUGIN"))))
                            }

                            // Wi-Fi
                            Repeater {
                                model: panelWin.openList === "wifi" ? (NetworkService.wifiNetworks ?? []).slice().sort((x, y) => (y.connected ? 1000 : y.signal) - (x.connected ? 1000 : x.signal)).slice(0, 9) : []

                                ListRow {
                                    required property var modelData
                                    width: listColumn.width
                                    icon: modelData.secured ? "lock" : "wifi"
                                    label: modelData.ssid
                                    note: modelData.connected ? "Connected" : (modelData.signal + "%" + (modelData.saved ? " · saved" : ""))
                                    current: modelData.connected
                                    onClicked: {
                                        if (modelData.connected)
                                            NetworkService.disconnectWifi();
                                        else if (modelData.saved || !modelData.secured)
                                            NetworkService.connectToWifi(modelData.ssid);
                                        else
                                            panelWin.askSsid = modelData.ssid;
                                    }
                                }
                            }

                            StyledText {
                                visible: panelWin.openList === "wifi" && (NetworkService.wifiNetworks ?? []).length === 0
                                x: 8
                                text: panelWin.tx(NetworkService.wifiEnabled ? "Looking for networks…" : "Wi-Fi is off.")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.withAlpha(Theme.surfaceText, 0.55)
                            }

                            // Password for a new secured network
                            Item {
                                visible: panelWin.openList === "wifi" && panelWin.askSsid !== ""
                                width: listColumn.width
                                height: 44

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    color: Theme.surfaceContainerHighest
                                    border.width: 1
                                    border.color: Theme.withAlpha(Theme.outline, 0.7)
                                    radius: Form.phainon ? 10 : 0
                                }

                                DankIcon {
                                    x: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "key"
                                    size: 18
                                    color: Theme.primary
                                }

                                TextInput {
                                    id: wifiPassword
                                    x: 42
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 56
                                    clip: true
                                    echoMode: TextInput.Password
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceText
                                    onVisibleChanged: {
                                        text = "";
                                        if (visible)
                                            forceActiveFocus();
                                    }
                                    onAccepted: {
                                        if (text.length > 0)
                                            NetworkService.connectToWifi(panelWin.askSsid, text);
                                        panelWin.askSsid = "";
                                    }

                                    StyledText {
                                        visible: wifiPassword.text === ""
                                        text: panelWin.tx("Password for " + panelWin.askSsid + ", then Enter")
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: Theme.withAlpha(Theme.surfaceText, 0.4)
                                    }
                                }
                            }

                            // Bluetooth
                            Repeater {
                                model: panelWin.openList === "bluetooth" ? (BluetoothService.adapter?.devices?.values ?? []).slice().sort((x, y) => (y.connected ? 1 : 0) - (x.connected ? 1 : 0)).slice(0, 9) : []

                                ListRow {
                                    required property var modelData
                                    width: listColumn.width
                                    icon: BluetoothService.getDeviceIcon(modelData)
                                    label: modelData.name || modelData.deviceName || "Unknown device"
                                    note: modelData.connected ? ("Connected" + (modelData.batteryAvailable ? " · " + Math.round(modelData.battery * 100) + "%" : "")) : (modelData.pairing ? "Pairing…" : "Tap to connect")
                                    current: modelData.connected
                                    onClicked: {
                                        if (modelData.connected)
                                            modelData.disconnect();
                                        else
                                            BluetoothService.connectDeviceWithTrust(modelData);
                                    }
                                }
                            }

                            StyledText {
                                visible: panelWin.openList === "bluetooth" && (BluetoothService.adapter?.devices?.values ?? []).length === 0
                                x: 8
                                text: panelWin.tx(BluetoothService.enabled ? "No known devices. Pair new ones in Settings." : "Bluetooth is off.")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.withAlpha(Theme.surfaceText, 0.55)
                            }

                            // Sound output
                            Repeater {
                                model: panelWin.openList === "output" ? Pipewire.nodes.values.filter(node => node.audio && node.isSink && !node.isStream) : []

                                ListRow {
                                    required property var modelData
                                    width: listColumn.width
                                    icon: "speaker"
                                    label: AudioService.displayName(modelData)
                                    note: modelData === AudioService.sink ? "In use" : ""
                                    current: modelData === AudioService.sink
                                    onClicked: Pipewire.preferredDefaultAudioSink = modelData
                                }
                            }

                            // Microphones: pick which one apps record from
                            Repeater {
                                model: panelWin.openList === "input" ? Pipewire.nodes.values.filter(node => node.audio && !node.isSink && !node.isStream) : []

                                ListRow {
                                    required property var modelData
                                    width: listColumn.width
                                    icon: "mic"
                                    label: AudioService.displayName(modelData)
                                    note: modelData === AudioService.source ? "In use" : ""
                                    current: modelData === AudioService.source
                                    onClicked: Pipewire.preferredDefaultAudioSource = modelData
                                }
                            }

                            // A plugin's own detail page
                            Loader {
                                readonly property string wanted: panelWin.openList.startsWith("plugin:") ? panelWin.openList.substring(7) : ""
                                readonly property var plugin: {
                                    for (let i = 0; i < pluginHost.count; i++) {
                                        if (pluginHost.itemAt(i)?.modelData === wanted)
                                            return pluginHost.itemAt(i).item;
                                    }
                                    return null;
                                }
                                visible: wanted !== ""
                                width: listColumn.width
                                height: visible ? Math.max(120, plugin?.ccDetailContent ? (plugin.ccDetailHeight ?? 250) : (plugin?.popoutHeight || 300)) : 0
                                sourceComponent: wanted !== "" && plugin ? (plugin.ccDetailContent ?? plugin.popoutContent) : null
                            }
                        }
                    }
                }

                // Toggles, in rows; a tile's list opens right under its own row.
                Column {
                width: parent.width
                spacing: 8

                Grid {
                    width: parent.width
                    columns: Form.reaver ? 1 : 2
                    spacing: 8

                    Tile {
                        width: panelWin.tileWidth
                        icon: NetworkService.networkStatus === "ethernet" ? "lan" : NetworkService.wifiSignalIcon
                        label: NetworkService.networkStatus === "ethernet" ? "Ethernet" : (NetworkService.currentWifiSSID || "Wi-Fi")
                        glyph: "passage"
                        sub: NetworkService.networkStatus === "ethernet" ? "Connected" : (NetworkService.currentWifiSSID ? NetworkService.wifiSignalStrength + "%" : (NetworkService.wifiEnabled ? "Not connected" : "Off"))
                        on: NetworkService.wifiEnabled && NetworkService.networkStatus !== "disconnected"
                        expandable: true
                        expanded: panelWin.openList === "wifi"
                        onExpand: panelWin.toggleList("wifi")
                        onClicked: NetworkService.toggleWifiRadio()
                    }

                    // The Flame Reaver stacks its tiles, so the Wi-Fi list belongs between them.
                    Loader {
                        width: panelWin.tileWidth
                        active: Form.reaver && panelWin.openList === "wifi"
                        visible: active
                        sourceComponent: listBlock
                    }

                    Tile {
                        width: panelWin.tileWidth
                        visible: BluetoothService.available
                        icon: BluetoothService.connected ? "bluetooth_connected" : "bluetooth"
                        label: BluetoothService.enabled ? "Bluetooth" : "Bluetooth off"
                        sub: panelWin.btDevice ? (panelWin.btDevice.name + (panelWin.btDevice.batteryAvailable ? " · " + Math.round(panelWin.btDevice.battery * 100) + "%" : "")) : (BluetoothService.enabled ? "No device" : "")
                        on: BluetoothService.enabled
                        expandable: true
                        expanded: panelWin.openList === "bluetooth"
                        onExpand: panelWin.toggleList("bluetooth")
                        onClicked: {
                            if (BluetoothService.adapter)
                                BluetoothService.adapter.enabled = !BluetoothService.adapter.enabled;
                        }
                    }
                }

                Loader {
                    width: parent.width
                    active: (panelWin.openList === "wifi" && !Form.reaver) || panelWin.openList === "bluetooth"
                    visible: active
                    sourceComponent: listBlock
                }

                Grid {
                    width: parent.width
                    columns: Form.reaver ? 1 : 2
                    spacing: 8

                    Tile {
                        width: panelWin.tileWidth
                        icon: AudioService.sinkVolumeIconName
                        label: AudioService.sink ? AudioService.displayName(AudioService.sink) : "No output"
                        glyph: "ocean"
                        sub: AudioService.sink?.audio?.muted ? "Muted" : Math.round((AudioService.sink?.audio?.volume ?? 0) * 100) + "%"
                        on: !!AudioService.sink?.audio && !AudioService.sink.audio.muted
                        expandable: true
                        expanded: panelWin.openList === "output"
                        onExpand: panelWin.toggleList("output")
                        onClicked: AudioService.toggleMute()
                    }

                    // Stacked tiles (Flame Reaver): the output list goes between speaker and mic.
                    Loader {
                        width: panelWin.tileWidth
                        active: Form.reaver && panelWin.openList === "output"
                        visible: active
                        sourceComponent: listBlock
                    }

                    Tile {
                        width: panelWin.tileWidth
                        icon: AudioService.source?.audio?.muted ? "mic_off" : "mic"
                        label: AudioService.source ? AudioService.displayName(AudioService.source) : "No microphone"
                        sub: AudioService.source?.audio?.muted ? "Muted" : Math.round((AudioService.source?.audio?.volume ?? 0) * 100) + "%"
                        on: !!AudioService.source?.audio && !AudioService.source.audio.muted
                        expandable: true
                        expanded: panelWin.openList === "input"
                        onExpand: panelWin.toggleList("input")
                        onClicked: AudioService.toggleMicMute()
                    }

                    // Stacked tiles (Flame Reaver): the microphone list goes right under the mic.
                    Loader {
                        width: panelWin.tileWidth
                        active: Form.reaver && panelWin.openList === "input"
                        visible: active
                        sourceComponent: listBlock
                    }
                }

                Loader {
                    width: parent.width
                    active: (panelWin.openList === "output" || panelWin.openList === "input") && !Form.reaver
                    visible: active
                    sourceComponent: listBlock
                }

                Grid {
                    width: parent.width
                    columns: Form.reaver ? 1 : 2
                    spacing: 8

                    Tile {
                        width: panelWin.tileWidth
                        icon: "nightlight"
                        label: "Night mode"
                        glyph: "sky"
                        sub: DisplayService.nightModeEnabled ? "On" : "Off"
                        on: DisplayService.nightModeEnabled
                        onClicked: DisplayService.toggleNightMode()
                    }

                    Tile {
                        width: panelWin.tileWidth
                        icon: "contrast"
                        label: "Dark mode"
                        sub: SessionData.isLightMode ? "Off" : "On"
                        on: !SessionData.isLightMode
                        onClicked: Theme.toggleLightMode()
                    }

                    Tile {
                        width: panelWin.tileWidth
                        icon: SessionData.doNotDisturb ? "notifications_off" : "do_not_disturb_on"
                        label: "Do not disturb"
                        glyph: "time"
                        sub: SessionData.doNotDisturb ? "On" : "Off"
                        on: SessionData.doNotDisturb
                        onClicked: SessionData.setDoNotDisturb(!SessionData.doNotDisturb)
                    }

                    Tile {
                        width: panelWin.tileWidth
                        visible: BatteryService.batteryAvailable
                        icon: BatteryService.isPluggedIn ? "battery_charging_full" : "battery_5_bar"
                        label: "Battery " + Math.round(BatteryService.batteryLevel) + "%"
                        glyph: "strife"
                        sub: panelWin.batteryOpen ? "Hide details" : (BatteryService.isPluggedIn ? "Plugged in · details" : "Details")
                        on: panelWin.batteryOpen || BatteryService.isPluggedIn
                        onClicked: panelWin.batteryOpen = !panelWin.batteryOpen
                    }
                }

                // Battery: the full reading, and the power profile
                Item {
                    visible: panelWin.batteryOpen && BatteryService.batteryAvailable
                    width: parent.width
                    height: batteryColumn.implicitHeight + 28

                    CfSurface {
                        anchors.fill: parent
                        color: Theme.surfaceContainerHigh
                        edgeColor: Theme.withAlpha(Theme.outline, Form.khaslana ? 0.9 : 0.45)
                        edgeWidth: Form.reaver ? 0 : 1
                        radius: 18
                    }

                    Column {
                        id: batteryColumn
                        x: 14
                        y: 14
                        width: parent.width - 28
                        spacing: 12

                        Row {
                            spacing: 10

                            DankIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: BatteryService.getBatteryIcon()
                                size: 26
                                color: Theme.primary
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Math.round(BatteryService.batteryLevel) + "%"
                                font.family: Form.display(Theme.fontFamily)
                                font.pixelSize: 26
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: panelWin.tx(BatteryService.batteryStatus)
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.withAlpha(Theme.surfaceText, 0.7)
                            }
                        }

                        Row {
                            id: batteryStats
                            width: parent.width
                            spacing: 8

                            Repeater {
                                model: [
                                    {
                                        "label": "Health",
                                        "value": BatteryService.batteryHealth || "--"
                                    },
                                    {
                                        "label": "Capacity",
                                        "value": BatteryService.batteryCapacity > 0 ? BatteryService.batteryCapacity.toFixed(1) + " Wh" : "--"
                                    },
                                    {
                                        "label": BatteryService.isCharging ? "Until full" : "Remaining",
                                        "value": BatteryService.formatTimeRemaining() || BatteryService.formatPowerRate(true) || "--"
                                    }
                                ]

                                Item {
                                    required property var modelData
                                    width: (batteryStats.width - 16) / 3
                                    height: 50

                                    CfSurface {
                                        anchors.fill: parent
                                        color: Theme.surfaceContainerHighest
                                        edgeWidth: 0
                                        radius: 12
                                        cut: 6
                                    }

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 1

                                        Heading {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: panelWin.tx(modelData.label.toUpperCase())
                                        }

                                        StyledText {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: String(modelData.value)
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: Font.Bold
                                            color: Theme.surfaceText
                                        }
                                    }
                                }
                            }
                        }

                        // Strife: the power profile
                        Row {
                            id: profiles
                            width: parent.width
                            spacing: 8

                            Repeater {
                                model: [
                                    {
                                        "label": "Power saver",
                                        "profile": PowerProfile.PowerSaver
                                    },
                                    {
                                        "label": "Balanced",
                                        "profile": PowerProfile.Balanced
                                    },
                                    {
                                        "label": "Performance",
                                        "profile": PowerProfile.Performance
                                    }
                                ]

                                Item {
                                    id: profileButton
                                    required property var modelData
                                    readonly property bool current: PowerProfiles.profile === modelData.profile
                                    readonly property bool usable: modelData.profile !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile
                                    width: (profiles.width - 16) / 3
                                    height: 34
                                    opacity: usable ? 1 : 0.4

                                    CfSurface {
                                        anchors.fill: parent
                                        color: profileButton.current ? Theme.primary : Theme.surfaceContainerHighest
                                        edgeColor: Theme.withAlpha(Theme.outline, 0.6)
                                        edgeWidth: Form.reaver ? 0 : 1
                                        radius: 17
                                        cut: 6
                                    }

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: panelWin.tx(profileButton.modelData.label)
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: profileButton.current ? Font.Bold : Font.Medium
                                        color: profileButton.current ? Theme.primaryText : Theme.surfaceText
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: profileButton.usable
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: PowerProfiles.profile = profileButton.modelData.profile
                                    }
                                }
                            }
                        }
                    }
                }

                Grid {
                    width: parent.width
                    columns: Form.reaver ? 1 : 2
                    spacing: 8

                    Tile {
                        width: panelWin.tileWidth
                        icon: "coffee"
                        label: SessionService.idleInhibited ? "Keeping awake" : "Keep awake"
                        sub: SessionService.idleInhibited ? "Screen stays on" : "Off"
                        on: SessionService.idleInhibited
                        onClicked: SessionService.toggleIdleInhibit()
                    }

                    Tile {
                        width: panelWin.tileWidth
                        icon: "content_paste"
                        label: "Clipboard"
                        glyph: "trickery"
                        action: true
                        sub: "History"
                        onClicked: {
                            panelWin.close();
                            panelWin.ipc("clipboard", "toggle");
                        }
                    }
                }

                }

                // Plugin tiles: every plugin widget that offers a control-centre tile gets one here.
                Item {
                    visible: false

                    Repeater {
                        id: pluginHost
                        model: panelWin.pluginIds

                        Loader {
                            required property string modelData
                            sourceComponent: PluginService.pluginWidgetComponents[modelData] ?? null
                            onLoaded: {
                                if ("pluginId" in item)
                                    item.pluginId = modelData;
                                if ("pluginService" in item)
                                    item.pluginService = PluginService;
                            }
                        }
                    }
                }

                Grid {
                    id: pluginTiles
                    readonly property real tileWidth: Form.reaver ? parent.width : (parent.width - 8) / 2
                    width: parent.width
                    columns: Form.reaver ? 1 : 2
                    spacing: 8

                    Repeater {
                        model: pluginHost.count

                        Tile {
                            required property int index
                            readonly property var plugin: pluginHost.itemAt(index)?.item ?? null
                            readonly property string pluginId: pluginHost.itemAt(index)?.modelData ?? ""
                            visible: !!plugin && (plugin.ccWidgetPrimaryText ?? "") !== ""
                            width: pluginTiles.tileWidth
                            icon: plugin?.ccWidgetIcon || "extension"
                            label: plugin?.ccWidgetPrimaryText ?? ""
                            sub: plugin?.ccWidgetSecondaryText ?? ""
                            on: plugin?.ccWidgetIsActive ?? false
                            expandable: !!plugin?.ccDetailContent
                            expanded: panelWin.openList === "plugin:" + pluginId
                            onExpand: panelWin.toggleList("plugin:" + pluginId)
                            onClicked: {
                                if (plugin?.ccWidgetIsToggle ?? true)
                                    plugin.ccWidgetToggled();
                                else
                                    panelWin.toggleList("plugin:" + pluginId);
                            }
                        }
                    }
                }

                // Plugins that only draw a bar widget (the cat, the network indicator and so on) have no
                // bar to sit on here, so they live on this shelf. Clicking one runs its own action or
                // opens its panel below.
                Column {
                    visible: shelf.children.length > 1 && shelf.implicitHeight > 0
                    width: parent.width
                    spacing: 6

                    Heading {
                        text: panelWin.tx("PLUGINS")
                    }

                    Flow {
                        id: shelf
                        width: parent.width
                        spacing: 8

                        Repeater {
                            model: pluginHost.count

                            Item {
                                id: shelfItem
                                required property int index
                                readonly property var plugin: pluginHost.itemAt(index)?.item ?? null
                                readonly property string pluginId: pluginHost.itemAt(index)?.modelData ?? ""
                                readonly property bool shown: !!plugin && (plugin.ccWidgetPrimaryText ?? "") === "" && !!plugin.horizontalBarPill
                                visible: shown
                                width: shown ? Math.max(40, pillLoader.implicitWidth + 24) : 0
                                height: shown ? 38 : 0

                                CfSurface {
                                    anchors.fill: parent
                                    color: shelfMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                                    edgeColor: Theme.withAlpha(Theme.outline, Form.khaslana ? 0.9 : 0.45)
                                    edgeWidth: Form.reaver ? 0 : 1
                                    radius: 19
                                    cut: 6
                                }

                                MouseArea {
                                    id: shelfMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (typeof shelfItem.plugin.pillClickAction === "function")
                                            shelfItem.plugin.pillClickAction();
                                        else if (shelfItem.plugin.popoutContent)
                                            panelWin.toggleList("plugin:" + shelfItem.pluginId);
                                    }
                                }

                                Loader {
                                    id: pillLoader
                                    anchors.centerIn: parent
                                    sourceComponent: shelfItem.shown ? shelfItem.plugin.horizontalBarPill : null
                                }
                            }
                        }
                    }
                }

                Loader {
                    width: parent.width
                    active: panelWin.openList.startsWith("plugin:")
                    visible: active
                    sourceComponent: listBlock
                }

                // Readings
                Item {
                    width: parent.width
                    height: 40

                    CfSurface {
                        anchors.fill: parent
                        color: Theme.surfaceContainerHigh
                        edgeColor: Theme.withAlpha(Theme.outline, Form.khaslana ? 0.9 : 0.45)
                        edgeWidth: Form.reaver ? 0 : 1
                        radius: 20
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 22

                        Repeater {
                            model: [
                                {
                                    "icon": "memory",
                                    "text": Math.round(DgopService.cpuUsage || 0) + "%"
                                },
                                {
                                    "icon": "device_thermostat",
                                    "text": Math.round(DgopService.cpuTemperature || 0) + "°"
                                },
                                {
                                    "icon": "developer_board",
                                    "text": Math.round(DgopService.memoryUsage || 0) + "%"
                                }
                            ]

                            Row {
                                id: reading
                                required property var modelData
                                // The Black Tide reaches memory past 85 %
                                readonly property bool flooded: modelData.icon === "developer_board" && (DgopService.memoryUsage || 0) >= 85
                                spacing: 5

                                DankIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: modelData.icon
                                    size: 17
                                    color: reading.flooded ? Theme.live : Theme.primary
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.text + (reading.flooded ? panelWin.tx(" · Black Tide") : "")
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: reading.flooded ? Font.Bold : Font.Normal
                                    color: reading.flooded ? Theme.live : Theme.surfaceText

                                    Rectangle {
                                        z: -1
                                        visible: reading.flooded
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        color: "#C005030C"
                                    }
                                }
                            }
                        }
                    }
                }

                // Battery
                Row {
                    visible: BatteryService.batteryAvailable
                    width: parent.width
                    spacing: 10

                    Heading {
                        anchors.verticalCenter: parent.verticalCenter
                        text: panelWin.tx("PYRIC CORPUS")
                    }

                    CfBrazier {
                        anchors.verticalCenter: parent.verticalCenter
                        level: BatteryService.batteryLevel
                        charging: BatteryService.isCharging || BatteryService.isPluggedIn
                        low: BatteryService.batteryLevel < 20 && !charging
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(BatteryService.batteryLevel) + "%" + (BatteryService.isPluggedIn ? panelWin.tx(" · plugged in") : "")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                    }
                }

                // Tray
                Row {
                    visible: trayItems.count > 0
                    width: parent.width
                    spacing: 12

                    Heading {
                        anchors.verticalCenter: parent.verticalCenter
                        text: panelWin.tx("TRAY")
                    }

                    Repeater {
                        id: trayItems
                        model: SystemTray.items

                        IconImage {
                            id: trayIcon
                            required property var modelData
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 22
                            source: modelData.icon

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton && trayIcon.modelData.hasMenu) {
                                        const at = trayIcon.mapToItem(null, 0, trayIcon.height);
                                        trayIcon.modelData.display(panelWin, at.x, at.y);
                                    } else {
                                        trayIcon.modelData.activate();
                                    }
                                }
                            }
                        }
                    }
                }

                // Notifications, collapsible
                Item {
                    width: parent.width
                    height: 30

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        DankIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: panelWin.notificationsOpen ? "expand_more" : "chevron_right"
                            size: 20
                            color: Theme.primary
                        }

                        Heading {
                            anchors.verticalCenter: parent.verticalCenter
                            text: panelWin.tx("ROMANCE · NOTIFICATIONS") + (NotificationService.notifications.length > 0 ? "  " + NotificationService.notifications.length : "")
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panelWin.notificationsOpen = !panelWin.notificationsOpen
                    }

                    IconButton {
                        visible: NotificationService.notifications.length > 0
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        name: "clear_all"
                        onClicked: NotificationService.clearAllNotifications()
                    }
                }

                Column {
                    visible: panelWin.notificationsOpen
                    width: parent.width
                    spacing: 8

                    Row {
                        visible: NotificationService.notifications.length === 0
                        spacing: 10

                        CfSigil {
                            anchors.verticalCenter: parent.verticalCenter
                            size: 26
                            lit: 0
                            litColor: Theme.withAlpha(Theme.surfaceText, 0.3)
                            dimColor: Theme.withAlpha(Theme.surfaceText, 0.3)
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Form.phainon ? "All quiet in Okhema." : (Form.khaslana ? "No threads pull at you." : "nothing.")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.withAlpha(Theme.surfaceText, 0.5)
                        }
                    }

                    Repeater {
                        model: NotificationService.notifications

                        Item {
                            id: note
                            required property var modelData
                            width: parent.width
                            height: noteColumn.implicitHeight + 20

                            CfSurface {
                                anchors.fill: parent
                                color: Theme.surfaceContainerHigh
                                edgeColor: Theme.withAlpha(Theme.outline, Form.khaslana ? 0.9 : 0.45)
                                edgeWidth: Form.reaver ? 0 : 1
                                radius: 14
                            }

                            Column {
                                id: noteColumn
                                x: 12
                                y: 10
                                width: parent.width - 24
                                spacing: 3

                                Item {
                                    width: parent.width
                                    height: 18

                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 30
                                        elide: Text.ElideRight
                                        text: panelWin.tx(note.modelData.appName + " · " + note.modelData.timeStr)
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.withAlpha(Theme.surfaceText, 0.55)
                                    }

                                    IconButton {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: "close"
                                        size: 16
                                        onClicked: NotificationService.dismissNotification(note.modelData)
                                    }
                                }

                                StyledText {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: note.modelData.summary
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.DemiBold
                                    color: Theme.surfaceText
                                }

                                StyledText {
                                    visible: note.modelData.body !== ""
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                    text: note.modelData.body
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.withAlpha(Theme.surfaceText, 0.75)
                                }

                                Row {
                                    visible: note.modelData.actions.length > 0
                                    spacing: 12
                                    topPadding: 4

                                    Repeater {
                                        model: note.modelData.actions

                                        StyledText {
                                            required property var modelData
                                            text: panelWin.tx(modelData.text)
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Font.DemiBold
                                            color: Theme.primary

                                            MouseArea {
                                                anchors.fill: parent
                                                anchors.margins: -4
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: modelData.invoke()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // The way out: stock DMS, with the theme settings you had before Coreflame.
                Item {
                    width: parent.width
                    height: 44

                    Rectangle {
                        anchors.top: parent.top
                        width: parent.width
                        height: 1
                        color: Theme.withAlpha(Theme.outline, 0.4)
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 4
                        spacing: 8

                        DankIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "undo"
                            size: 18
                            color: panelWin.leaveArmed ? Theme.error : Theme.withAlpha(Theme.surfaceText, 0.6)
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: panelWin.tx(panelWin.leaveArmed ? "Click again to leave Coreflame" : "Return to stock DMS")
                            font.pixelSize: Theme.fontSizeMedium
                            color: panelWin.leaveArmed ? Theme.error : Theme.withAlpha(Theme.surfaceText, 0.7)
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!panelWin.leaveArmed) {
                                panelWin.leaveArmed = true;
                                return;
                            }
                            panelWin.close();
                            Quickshell.execDetached(["systemctl", "--user", "start", "coreflame-leave.service"]);
                        }
                    }
                }
            }
        }
    }
}
