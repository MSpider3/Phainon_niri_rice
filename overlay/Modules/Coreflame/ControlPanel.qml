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
import qs.DCommon.Widgets as DW

// The control centre: one tall panel dropping from the right corner. A short first page (forms,
// sliders, quick tiles), then four sections that expand one at a time: Connectivity, Sound,
// Power, System. Readings and notifications live on the dashboard.
PanelWindow {
    id: panelWin

    required property var targetScreen
    property int strip: 40
    property bool shown: false
    property real reveal: shown ? 1 : 0
    // The open section: "", "connectivity", "sound", "power" or "system"
    property string section: ""
    // A plugin's detail page open in System: "" or "plugin:<id>"
    property string openList: ""
    // The secured network waiting for a password
    property string askSsid: ""
    property bool leaveArmed: false

    function toggleSection(name) {
        section = section === name ? "" : name;
        askSsid = "";
        openList = "";
        if (section === "connectivity" && NetworkService.wifiEnabled)
            NetworkService.scanWifi();
    }

    // Brings an opened section's header to the top of the scroll, so its body is not left below
    // the fold. Positioners lay out lazily, so settle them before measuring.
    function showSection(item) {
        item.forceLayout();
        sections.forceLayout();
        content.forceLayout();
        const y = item.mapToItem(content, 0, 0).y;
        scroller.contentY = Math.max(0, Math.min(y, scroller.contentHeight - scroller.height));
    }

    function toggleList(name) {
        openList = openList === name ? "" : name;
    }

    // Plugin widgets that offer a control-centre tile (KDE Connect and the like)
    readonly property var pluginIds: Object.keys(PluginService.pluginWidgetComponents ?? {}).filter(id => !Form.heldPlugins.includes(id))

    readonly property real panelWidth: 460
    readonly property real pad: 18
    readonly property real contentWidth: panelWidth - pad * 2
    // Phainon breathes, Khaslana packs his plates tight, the Flame Reaver sits between.
    readonly property real gap: Form.khaslana ? 8 : (Form.phainon || !Form.active ? 14 : 10)
    readonly property real tileWidth: Form.reaver ? contentWidth : (contentWidth - gap) / 2

    readonly property var btDevice: BluetoothService.adapter?.devices?.values?.find(d => d.connected) ?? null
    readonly property var toplevels: CompositorService.sortedToplevels ?? []

    function open() {
        shown = true;
    }

    function close() {
        shown = false;
        leaveArmed = false;
        askSsid = "";
        openList = "";
        section = "";
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

    function profileName(profile) {
        return profile === PowerProfile.PowerSaver ? "Power saver" : (profile === PowerProfile.Performance ? "Performance" : "Balanced");
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

    // Stock DMS only fills the Wi-Fi list while someone holds a network ref (DMS Settings does);
    // hold one while Connectivity is open. Bluetooth discovery also stops when it closes.
    readonly property bool netWatch: shown && section === "connectivity"
    onNetWatchChanged: {
        if (netWatch) {
            NetworkService.addRef();
        } else {
            NetworkService.removeRef();
            if (BluetoothService.adapter?.discovering)
                BluetoothService.adapter.discovering = false;
        }
    }
    onShownChanged: {
        if (shown) {
            DgopService.addRef(["system"]);
            scroller.contentY = 0;
            panel.forceActiveFocus();
        } else {
            DgopService.removeRef(["system"]);
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: panelWin.close()
    }

    // A quick tile. Phainon: a paper card with a big round toggle. Khaslana: a cut plate whose
    // edge turns gold when on. Flame Reaver: a ledger row closed by his crossed blades.
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
        // Shows a chevron that opens the tile's section or list
        property bool expandable: false
        property bool expanded: false
        readonly property bool row: Form.reaver
        readonly property bool round: Form.phainon || !Form.active
        readonly property color iconColor: round ? (on && !action ? Theme.primaryText : Theme.primary) : (on ? Theme.primary : Theme.withAlpha(Theme.surfaceText, 0.6))
        signal clicked
        signal expand

        implicitHeight: row ? 42 : (Form.khaslana ? 52 : 66)

        CfSurface {
            visible: !tile.row
            anchors.fill: parent
            color: tileMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
            edgeColor: Form.khaslana && tile.on ? Theme.primary : Theme.withAlpha(Theme.outline, Form.khaslana ? 0.35 : 0.45)
            edgeWidth: Form.khaslana && tile.on ? 1.5 : 1
            radius: 22
        }

        Rectangle {
            visible: tile.row && tileMouse.containsMouse
            anchors.fill: parent
            color: Theme.withAlpha(Theme.surfaceText, 0.06)
        }

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.clicked()
        }

        // Phainon's big round toggle, lapis when on
        Rectangle {
            id: knob
            visible: tile.round
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 42
            height: 42
            radius: 21
            color: tile.on && !tile.action ? Theme.primary : Theme.surfaceContainerHighest
            border.width: 1
            border.color: Theme.withAlpha(Theme.outline, tile.on ? 0 : 0.35)
        }

        Item {
            id: iconBox
            visible: !tile.row
            x: tile.round ? knob.x + (knob.width - width) / 2 : 14
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 22

            DW.DIcon {
                visible: tile.glyph === ""
                anchors.centerIn: parent
                name: tile.icon
                size: 22
                color: tile.iconColor
            }

            CfGlyph {
                visible: tile.glyph !== ""
                anchors.centerIn: parent
                name: tile.glyph
                size: 22
                strokeWidth: 1.9
                color: tile.iconColor
            }
        }

        Column {
            x: tile.row ? 14 : (tile.round ? 66 : 46)
            anchors.verticalCenter: parent.verticalCenter
            width: tile.width - x - (tile.row ? 64 : 8) - (tile.expandable ? 30 : 0)
            spacing: 1

            StyledText {
                width: parent.width
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                text: panelWin.tx(tile.row && tile.sub !== "" ? tile.label + "  ·  " + tile.sub.replace(/ · /g, "  ·  ") : tile.label)
                font.pixelSize: Theme.fontSizeMedium
                font.weight: tile.on ? Font.Bold : Font.Medium
                color: tile.on || tile.action ? Theme.surfaceText : Theme.withAlpha(Theme.surfaceText, 0.75)
            }

            StyledText {
                visible: tile.sub !== "" && !tile.row
                width: parent.width
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                text: tile.sub
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.withAlpha(Theme.surfaceText, 0.55)
            }
        }

        CfCrossToggle {
            visible: tile.row && !tile.action
            anchors.right: parent.right
            anchors.rightMargin: tile.expandable ? 40 : 14
            anchors.verticalCenter: parent.verticalCenter
            checked: tile.on
            color: Theme.live
            onClicked: tile.clicked()
        }

        // Opens the tile's section or list
        Item {
            visible: tile.expandable || (tile.row && tile.action)
            anchors.right: parent.right
            width: 36
            height: parent.height

            DW.DIcon {
                anchors.centerIn: parent
                name: tile.expandable ? (tile.expanded ? "expand_less" : "expand_more") : "chevron_right"
                size: 20
                color: Form.reaver ? Theme.withAlpha(Theme.surfaceText, 0.6) : Theme.primary
            }

            MouseArea {
                anchors.fill: parent
                enabled: tile.expandable
                cursorShape: Qt.PointingHandCursor
                onClicked: tile.expand()
            }
        }
    }

    // One line in a list inside a section
    component ListRow: Item {
        id: listRow

        property string icon: ""
        property string label: ""
        property string note: ""
        property bool current: false
        signal clicked

        height: Form.khaslana ? 34 : 38

        Rectangle {
            anchors.fill: parent
            visible: rowMouse.containsMouse
            radius: Form.phainon ? 10 : 0
            color: Theme.withAlpha(Theme.surfaceText, 0.07)
        }

        DW.DIcon {
            visible: !Form.reaver
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            name: listRow.icon
            size: 18
            color: listRow.current ? Theme.live : Theme.withAlpha(Theme.surfaceText, 0.6)
        }

        // The Flame Reaver marks the chosen one with his crossed blades.
        Item {
            visible: Form.reaver && listRow.current
            x: 9
            anchors.verticalCenter: parent.verticalCenter
            width: 12
            height: 14

            Repeater {
                model: [-1, 1]

                Rectangle {
                    required property int modelData
                    anchors.centerIn: parent
                    width: 1.5
                    height: 14
                    rotation: modelData * 40
                    antialiasing: true
                    color: Theme.live
                }
            }
        }

        StyledText {
            x: Form.reaver ? 30 : 36
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - noteText.width - 18
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
            text: panelWin.tx(listRow.label)
            font.pixelSize: Theme.fontSizeMedium
            font.weight: listRow.current ? Font.Bold : Font.Medium
            color: listRow.current ? Theme.surfaceText : Theme.withAlpha(Theme.surfaceText, 0.85)
        }

        StyledText {
            id: noteText
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: panelWin.tx(listRow.note)
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

    component IconButton: DW.DIcon {
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

    // A label and its value on one line (network details)
    component DetailRow: Item {
        id: detail
        property string label: ""
        property string value: ""
        visible: value !== ""
        width: parent ? parent.width : 0
        height: 26

        StyledText {
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            text: panelWin.tx(detail.label)
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.withAlpha(Theme.surfaceText, 0.6)
        }

        StyledText {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * 0.6
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            text: detail.value
            font.family: Theme.monoFontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
        }
    }

    // A card holding a column; `flat` drops the card and its padding.
    component Card: Item {
        id: card
        property bool flat: false
        property real padding: flat ? 0 : (Form.khaslana ? 10 : 14)
        property alias spacing: cardColumn.spacing
        default property alias content: cardColumn.data

        width: parent ? parent.width : 0
        implicitHeight: cardColumn.implicitHeight + padding * 2

        CfSurface {
            visible: !card.flat
            anchors.fill: parent
            color: Theme.surfaceContainerHigh
            edgeColor: Theme.withAlpha(Theme.outline, Form.khaslana ? 0.6 : 0.45)
            radius: 22
        }

        Column {
            id: cardColumn
            x: card.padding
            y: card.padding
            width: card.width - card.padding * 2
            spacing: 8
        }
    }

    // Volume, brightness, mic: a blade in Phainon and Khaslana, a scorched line in the Flame Reaver
    component SliderRow: Item {
        id: sliderRow
        property string icon: ""
        property real value: 0
        property string valueText: ""
        signal moved(real to)
        signal iconClicked

        width: parent ? parent.width : 0
        height: Form.khaslana ? 30 : 36

        DW.DIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: sliderRow.icon
            size: 20
            color: Theme.surfaceText

            MouseArea {
                anchors.fill: parent
                anchors.margins: -5
                cursorShape: Qt.PointingHandCursor
                onClicked: sliderRow.iconClicked()
            }
        }

        CfBlade {
            visible: !Form.reaver
            x: 34
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 34 - 56
            interactive: true
            value: sliderRow.value
            onMoved: to => sliderRow.moved(to)
        }

        CfScorch {
            visible: Form.reaver
            x: 34
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 34 - 56
            value: sliderRow.value
            onMoved: to => sliderRow.moved(to)
        }

        StyledText {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 46
            horizontalAlignment: Text.AlignRight
            text: sliderRow.valueText
            font.family: Form.reaver ? Theme.monoFontFamily : Theme.fontFamily
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.surfaceText
        }
    }

    // One of the four sections: a single line that opens into its body (built only while open)
    component Section: Column {
        id: sec
        property string key: ""
        property string title: ""
        property string glyph: ""
        property string summary: ""
        property Component body: null
        readonly property bool open: panelWin.section === key

        width: parent ? parent.width : 0
        spacing: panelWin.gap * 0.6
        onOpenChanged: {
            if (open)
                Qt.callLater(panelWin.showSection, sec);
        }

        Item {
            width: parent.width
            height: Form.khaslana ? 44 : (Form.reaver ? 42 : 50)

            CfSurface {
                anchors.fill: parent
                color: headMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                edgeColor: Form.khaslana && sec.open ? Theme.primary : Theme.withAlpha(Theme.outline, Form.khaslana ? 0.35 : 0.45)
                edgeWidth: Form.khaslana && sec.open ? 1.5 : 1
                lining: Form.reaver && sec.open
                radius: 25
            }

            CfGlyph {
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                name: Form.reaver ? "mask" : sec.glyph
                size: Form.reaver ? 15 : 18
                strokeWidth: 1.6
                color: sec.open ? Theme.live : Theme.withAlpha(Theme.surfaceText, 0.65)
            }

            StyledText {
                id: secTitle
                x: 44
                anchors.verticalCenter: parent.verticalCenter
                text: panelWin.tx(Form.khaslana ? sec.title.toUpperCase() : sec.title)
                font.family: Form.reaver ? Theme.fontFamily : Form.display(Theme.fontFamily)
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.DemiBold
                font.letterSpacing: Form.khaslana ? 1.4 : 0
                color: Theme.surfaceText
            }

            StyledText {
                anchors.right: parent.right
                anchors.rightMargin: 42
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, parent.width - secTitle.x - secTitle.implicitWidth - 42 - 16)
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                text: panelWin.tx(sec.summary)
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.withAlpha(Theme.surfaceText, 0.55)
            }

            DW.DIcon {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                name: sec.open ? "expand_less" : "expand_more"
                size: 20
                color: Form.reaver ? Theme.withAlpha(Theme.surfaceText, 0.6) : Theme.primary
            }

            MouseArea {
                id: headMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: panelWin.toggleSection(sec.key)
            }
        }

        Loader {
            width: parent.width
            active: sec.open
            visible: active
            sourceComponent: sec.body
        }
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
            id: tab
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
            y: 12
            width: panelWin.contentWidth
            height: 64
            opacity: panelWin.reveal

            CfSurface {
                anchors.fill: parent
                color: Theme.surfaceContainerHigh
                edgeColor: Theme.withAlpha(Theme.outline, Form.khaslana ? 0.9 : 0.45)
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

                DW.DIcon {
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
            id: scroller
            x: panelWin.pad
            y: userCard.y + userCard.height + panelWin.gap
            width: panelWin.contentWidth
            // The Flame Reaver's torn hem eats into the bottom of the panel.
            height: parent.height - y - panelWin.pad - (Form.reaver ? tab.hem : 0)
            contentHeight: content.implicitHeight
            clip: true
            opacity: panelWin.reveal
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: content
                width: parent.width
                spacing: panelWin.gap

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
                            height: 38

                            CfSurface {
                                anchors.fill: parent
                                color: formButton.current ? Theme.primary : Theme.surfaceContainerHigh
                                edgeColor: Theme.withAlpha(Theme.outline, 0.6)
                                lining: Form.reaver && !formButton.current
                                radius: 19
                            }

                            Row {
                                anchors.centerIn: parent
                                spacing: 5

                                DW.DIcon {
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
                    // The schedule timer only runs while the schedule is on; keep the sun times current anyway.
                    onOpenChanged: if (open)
                        Form.checkSunDay()
                    width: parent.width
                    spacing: 6

                    Item {
                        width: parent.width
                        height: 34

                        CfSurface {
                            anchors.fill: parent
                            color: Theme.surfaceContainerHigh
                            edgeColor: Theme.withAlpha(Theme.outline, Form.khaslana ? 0.9 : 0.45)
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

                            DW.DIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "schedule"
                                size: 16
                                color: Form.schedule.enabled ? Theme.live : Theme.withAlpha(Theme.surfaceText, 0.55)
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: panelWin.tx(Form.schedule.enabled ? (Form.schedule.sun && Form.sunTimes ? "By the sun · " : "By the hour · ") + Form.startOf("phainon") + " / " + Form.startOf("khaslana") + " / " + Form.schedule.reaver : "Change form by the hour")
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
                                    lining: false
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
                                    // A double click (or a doubled touchpad tap) turned it on and straight back off.
                                    property real flippedAt: 0
                                    onDoubleClicked: {}
                                    onClicked: {
                                        if (Date.now() - flippedAt < 1500)
                                            return;
                                        flippedAt = Date.now();
                                        Form.setScheduleEnabled(!Form.schedule.enabled);
                                    }
                                }
                            }

                            DW.DIcon {
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
                                    // Set by the sun today, so the fixed time's steps are put away.
                                    readonly property bool bySun: Form.schedule.sun && Form.sunTimes !== null && modelData.id !== "reaver"
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

                                                visible: step.modelData.by === 0 || !hourRow.bySun

                                                CfSurface {
                                                    anchors.fill: parent
                                                    visible: step.modelData.by !== 0
                                                    color: stepMouse.containsMouse ? Theme.withAlpha(Theme.primary, 0.25) : Theme.surfaceContainerHighest
                                                    edgeWidth: 0
                                                    lining: false
                                                    radius: 12
                                                    cut: 5
                                                }

                                                StyledText {
                                                    anchors.centerIn: parent
                                                    text: step.modelData.by === 0 ? Form.startOf(hourRow.modelData.id) : step.modelData.text
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

                            // Follow the sun: Phainon at sunrise, Khaslana at sunset.
                            Item {
                                width: hoursColumn.width
                                height: sunText.implicitHeight + 8

                                Column {
                                    id: sunText
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 52
                                    spacing: 1

                                    StyledText {
                                        text: panelWin.tx("Follow the sun")
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.Medium
                                        color: Theme.surfaceText
                                    }

                                    StyledText {
                                        width: parent.width
                                        wrapMode: Text.WordWrap
                                        text: panelWin.tx(Form.sunTimes ? "Sunrise " + Form.sunTimes.sunrise + " · sunset " + Form.sunTimes.sunset : Form.sunPolar ? "No sunrise or sunset today: the set times are used" : "No location known: the set times are used")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Form.sunTimes ? Theme.withAlpha(Theme.surfaceText, 0.7) : Theme.live
                                    }
                                }

                                Item {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 44
                                    height: 22

                                    CfSurface {
                                        anchors.fill: parent
                                        color: Form.schedule.sun ? Theme.primary : Theme.surfaceContainerHighest
                                        edgeWidth: 0
                                        lining: false
                                        radius: 11
                                        cut: 5
                                    }

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: panelWin.tx(Form.schedule.sun ? "On" : "Off")
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Bold
                                        color: Form.schedule.sun ? Theme.primaryText : Theme.withAlpha(Theme.surfaceText, 0.7)
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Form.setSunEnabled(!Form.schedule.sun)
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
                Card {
                    spacing: 4

                    SliderRow {
                        icon: AudioService.sinkVolumeIconName
                        value: AudioService.sink?.audio?.muted ? 0 : (AudioService.sink?.audio?.volume ?? 0)
                        valueText: Math.round((AudioService.sink?.audio?.volume ?? 0) * 100) + "%"
                        onIconClicked: AudioService.toggleMute()
                        onMoved: to => {
                            if (!AudioService.sink?.audio)
                                return;
                            AudioService.sink.audio.muted = false;
                            AudioService.sink.audio.volume = to;
                        }
                    }

                    SliderRow {
                        visible: DisplayService.brightnessAvailable
                        icon: "brightness_6"
                        value: DisplayService.brightnessLevel / 100
                        valueText: DisplayService.brightnessLevel + "%"
                        onMoved: to => DisplayService.setBrightness(Math.max(1, Math.round(to * 100)), DisplayService.lastIpcDevice, true)
                    }

                    SliderRow {
                        visible: !!AudioService.source?.audio
                        icon: AudioService.source?.audio?.muted ? "mic_off" : "mic"
                        value: AudioService.source?.audio?.muted ? 0 : (AudioService.source?.audio?.volume ?? 0)
                        valueText: Math.round((AudioService.source?.audio?.volume ?? 0) * 100) + "%"
                        onIconClicked: AudioService.toggleMicMute()
                        onMoved: to => {
                            if (!AudioService.source?.audio)
                                return;
                            AudioService.source.audio.muted = false;
                            AudioService.source.audio.volume = to;
                        }
                    }
                }

                // Quick tiles: their chevrons open the matching section below. The Flame Reaver
                // stacks them as rows on one plate.
                Card {
                    flat: !Form.reaver
                    padding: flat ? 0 : 6

                    Grid {
                        width: parent.width
                        columns: Form.reaver ? 1 : 2
                        spacing: Form.reaver ? 0 : panelWin.gap

                        Tile {
                            width: Form.reaver ? parent.width : panelWin.tileWidth
                            icon: NetworkService.networkStatus === "ethernet" ? "lan" : NetworkService.wifiSignalIcon
                            label: NetworkService.networkStatus === "ethernet" ? "Ethernet" : (NetworkService.currentWifiSSID || "Wi-Fi")
                            glyph: "passage"
                            sub: NetworkService.networkStatus === "ethernet" ? "Connected" : (NetworkService.currentWifiSSID ? NetworkService.wifiSignalStrength + "%" : (NetworkService.wifiEnabled ? "Not connected" : "Off"))
                            on: NetworkService.wifiEnabled && NetworkService.networkStatus !== "disconnected"
                            expandable: true
                            expanded: panelWin.section === "connectivity"
                            onExpand: panelWin.toggleSection("connectivity")
                            onClicked: NetworkService.toggleWifiRadio()
                        }

                        Tile {
                            width: Form.reaver ? parent.width : panelWin.tileWidth
                            visible: BluetoothService.available
                            icon: BluetoothService.connected ? "bluetooth_connected" : "bluetooth"
                            label: BluetoothService.enabled ? "Bluetooth" : "Bluetooth off"
                            sub: panelWin.btDevice ? (panelWin.btDevice.name + (panelWin.btDevice.batteryAvailable ? " · " + Math.round(panelWin.btDevice.battery * 100) + "%" : "")) : (BluetoothService.enabled ? "No device" : "")
                            on: BluetoothService.enabled
                            expandable: true
                            expanded: panelWin.section === "connectivity"
                            onExpand: panelWin.toggleSection("connectivity")
                            onClicked: {
                                if (BluetoothService.adapter)
                                    BluetoothService.adapter.enabled = !BluetoothService.adapter.enabled;
                            }
                        }

                        Tile {
                            width: Form.reaver ? parent.width : panelWin.tileWidth
                            icon: AudioService.sinkVolumeIconName
                            label: AudioService.sink ? AudioService.displayName(AudioService.sink) : "No output"
                            glyph: "ocean"
                            sub: AudioService.sink?.audio?.muted ? "Muted" : Math.round((AudioService.sink?.audio?.volume ?? 0) * 100) + "%"
                            on: !!AudioService.sink?.audio && !AudioService.sink.audio.muted
                            expandable: true
                            expanded: panelWin.section === "sound"
                            onExpand: panelWin.toggleSection("sound")
                            onClicked: AudioService.toggleMute()
                        }

                        Tile {
                            width: Form.reaver ? parent.width : panelWin.tileWidth
                            icon: AudioService.source?.audio?.muted ? "mic_off" : "mic"
                            label: AudioService.source ? AudioService.displayName(AudioService.source) : "No microphone"
                            sub: AudioService.source?.audio?.muted ? "Muted" : Math.round((AudioService.source?.audio?.volume ?? 0) * 100) + "%"
                            on: !!AudioService.source?.audio && !AudioService.source.audio.muted
                            expandable: true
                            expanded: panelWin.section === "sound"
                            onExpand: panelWin.toggleSection("sound")
                            onClicked: AudioService.toggleMicMute()
                        }

                        Tile {
                            width: Form.reaver ? parent.width : panelWin.tileWidth
                            visible: BatteryService.batteryAvailable
                            icon: BatteryService.isPluggedIn ? "battery_charging_full" : "battery_5_bar"
                            label: "Battery " + Math.round(BatteryService.batteryLevel) + "%"
                            glyph: "strife"
                            sub: BatteryService.isPluggedIn ? "Plugged in" : (BatteryService.formatTimeRemaining() || "On battery")
                            on: BatteryService.isPluggedIn
                            action: true
                            expandable: true
                            expanded: panelWin.section === "power"
                            onExpand: panelWin.toggleSection("power")
                            onClicked: panelWin.toggleSection("power")
                        }

                        Tile {
                            width: Form.reaver ? parent.width : panelWin.tileWidth
                            icon: SessionData.doNotDisturb ? "notifications_off" : "do_not_disturb_on"
                            label: "Do not disturb"
                            glyph: "time"
                            sub: SessionData.doNotDisturb ? "On" : "Off"
                            on: SessionData.doNotDisturb
                            onClicked: SessionData.setDoNotDisturb(!SessionData.doNotDisturb)
                        }
                    }
                }

                // The four sections
                Column {
                    id: sections
                    width: parent.width
                    spacing: Form.khaslana ? 6 : 8

                    Section {
                        key: "connectivity"
                        title: "Connectivity"
                        glyph: "passage"
                        summary: (NetworkService.networkStatus === "ethernet" ? "Ethernet" : (NetworkService.currentWifiSSID || (NetworkService.wifiEnabled ? "Not connected" : "Wi-Fi off"))) + (panelWin.btDevice ? " · " + panelWin.btDevice.name : "")
                        body: connectivityBody
                    }

                    Section {
                        key: "sound"
                        title: "Sound"
                        glyph: "ocean"
                        summary: AudioService.sink ? AudioService.displayName(AudioService.sink) : "No output"
                        body: soundBody
                    }

                    Section {
                        key: "power"
                        title: "Power"
                        glyph: "strife"
                        summary: (BatteryService.batteryAvailable ? Math.round(BatteryService.batteryLevel) + "% · " : "") + panelWin.profileName(PowerProfiles.profile)
                        body: powerBody
                    }

                    Section {
                        key: "system"
                        title: "System"
                        glyph: "law"
                        summary: panelWin.toplevels.length === 1 ? "1 window" : panelWin.toplevels.length + " windows"
                        body: systemBody
                    }
                }
            }
        }

        // Plugin widgets, loaded once and kept hidden: their tiles, pills and detail pages are
        // drawn in the System section.
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
    }

    Component {
        id: connectivityBody

        Card {
            id: netCard

            Heading {
                x: 8
                text: panelWin.tx("PASSAGE · WI-FI NETWORKS")
            }

            Repeater {
                model: (NetworkService.wifiNetworks ?? []).slice().sort((x, y) => (y.connected ? 1000 : y.signal) - (x.connected ? 1000 : x.signal)).slice(0, 9)

                ListRow {
                    required property var modelData
                    width: netCard.width - netCard.padding * 2
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
                visible: (NetworkService.wifiNetworks ?? []).length === 0
                x: 8
                text: panelWin.tx(NetworkService.wifiEnabled ? "Looking for networks…" : "Wi-Fi is off.")
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.withAlpha(Theme.surfaceText, 0.55)
            }

            // Password for a new secured network
            Item {
                visible: panelWin.askSsid !== ""
                width: parent.width
                height: 44

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    color: Theme.surfaceContainerHighest
                    border.width: 1
                    border.color: Theme.withAlpha(Form.reaver ? Theme.live : Theme.outline, 0.7)
                    radius: Form.phainon ? 10 : 0
                }

                DW.DIcon {
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

            Heading {
                visible: BluetoothService.available
                x: 8
                topPadding: 6
                text: panelWin.tx("PASSAGE · BLUETOOTH DEVICES")
            }

            Repeater {
                model: BluetoothService.available ? (BluetoothService.adapter?.devices?.values ?? []).slice().sort((x, y) => (y.connected ? 1 : 0) - (x.connected ? 1 : 0)).slice(0, 9) : []

                ListRow {
                    required property var modelData
                    width: netCard.width - netCard.padding * 2
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
                visible: BluetoothService.available && (BluetoothService.adapter?.devices?.values ?? []).length === 0
                x: 8
                text: panelWin.tx(BluetoothService.enabled ? "No known devices." : "Bluetooth is off.")
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.withAlpha(Theme.surfaceText, 0.55)
            }

            // Nearby devices not paired yet, listed only while searching (same filter as stock DMS).
            Repeater {
                model: BluetoothService.discovering ? BluetoothService.sortDevices((BluetoothService.adapter?.devices?.values ?? []).filter(d => d && !d.paired && !d.blocked && (d.signalStrength === undefined || d.signalStrength > 0))).slice(0, 8) : []

                ListRow {
                    required property var modelData
                    width: netCard.width - netCard.padding * 2
                    icon: BluetoothService.getDeviceIcon(modelData)
                    label: modelData.name || modelData.deviceName || modelData.address
                    note: modelData.pairing ? "Pairing…" : "Tap to pair"
                    onClicked: {
                        if (modelData.pairing)
                            return;
                        BluetoothService.pairDevice(modelData, response => {
                            if (response?.error)
                                ToastService.showError("Pairing failed", response.error);
                        });
                    }
                }
            }

            ListRow {
                visible: BluetoothService.enabled
                width: netCard.width - netCard.padding * 2
                icon: BluetoothService.discovering ? "stop" : "bluetooth_searching"
                label: BluetoothService.discovering ? "Searching for devices…" : "Search for new devices"
                note: BluetoothService.discovering ? "Tap to stop" : ""
                onClicked: BluetoothService.adapter.discovering = !BluetoothService.discovering
            }

            Heading {
                x: 8
                topPadding: 6
                text: panelWin.tx("PASSAGE · NETWORK DETAILS")
            }

            DetailRow {
                label: "Connection"
                value: NetworkService.networkStatus === "ethernet" ? "Ethernet" : (NetworkService.currentWifiSSID || "None")
            }

            DetailRow {
                label: "Interface"
                value: NetworkService.networkStatus === "ethernet" ? NetworkService.ethernetInterface : NetworkService.wifiInterface
            }

            DetailRow {
                label: "IP address"
                value: NetworkService.networkStatus === "ethernet" ? NetworkService.ethernetIP : NetworkService.wifiIP
            }
        }
    }

    Component {
        id: soundBody

        Card {
            id: soundCard

            Heading {
                x: 8
                text: panelWin.tx("OCEAN · SOUND OUTPUT")
            }

            Repeater {
                model: Pipewire.nodes.values.filter(node => node.audio && node.isSink && !node.isStream)

                ListRow {
                    required property var modelData
                    width: soundCard.width - soundCard.padding * 2
                    icon: "speaker"
                    label: AudioService.displayName(modelData)
                    note: modelData === AudioService.sink ? "In use" : ""
                    current: modelData === AudioService.sink
                    onClicked: Pipewire.preferredDefaultAudioSink = modelData
                }
            }

            Heading {
                x: 8
                topPadding: 6
                text: panelWin.tx("OCEAN · MICROPHONE")
            }

            // Pick which one apps record from
            Repeater {
                model: Pipewire.nodes.values.filter(node => node.audio && !node.isSink && !node.isStream)

                ListRow {
                    required property var modelData
                    width: soundCard.width - soundCard.padding * 2
                    icon: "mic"
                    label: AudioService.displayName(modelData)
                    note: modelData === AudioService.source ? "In use" : ""
                    current: modelData === AudioService.source
                    onClicked: Pipewire.preferredDefaultAudioSource = modelData
                }
            }
        }
    }

    Component {
        id: powerBody

        Card {
            spacing: 12

            // Pyric corpus: the battery as a brazier
            Row {
                visible: BatteryService.batteryAvailable
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
                    text: Math.round(BatteryService.batteryLevel) + "%"
                    font.family: Form.display(Theme.fontFamily)
                    font.pixelSize: 22
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
                visible: BatteryService.batteryAvailable
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
                            lining: false
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
                                text: panelWin.tx(String(modelData.value))
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
                    model: [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]

                    Item {
                        id: profileButton
                        required property var modelData
                        readonly property bool current: PowerProfiles.profile === modelData
                        readonly property bool usable: modelData !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile
                        width: (profiles.width - 16) / 3
                        height: 36
                        opacity: usable ? 1 : 0.4

                        CfSurface {
                            anchors.fill: parent
                            color: profileButton.current ? Theme.primary : Theme.surfaceContainerHighest
                            edgeColor: Theme.withAlpha(Theme.outline, 0.6)
                            lining: false
                            radius: 18
                            cut: 6
                        }

                        StyledText {
                            anchors.centerIn: parent
                            text: panelWin.tx(panelWin.profileName(profileButton.modelData))
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: profileButton.current ? Font.Bold : Font.Medium
                            color: profileButton.current ? Theme.primaryText : Theme.surfaceText
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: profileButton.usable
                            cursorShape: Qt.PointingHandCursor
                            onClicked: PowerProfiles.profile = profileButton.modelData
                        }
                    }
                }
            }

            Tile {
                width: parent.width
                icon: "coffee"
                label: SessionService.idleInhibited ? "Keeping awake" : "Keep awake"
                sub: SessionService.idleInhibited ? "Screen stays on" : "Off"
                on: SessionService.idleInhibited
                onClicked: SessionService.toggleIdleInhibit()
            }
        }
    }

    Component {
        id: systemBody

        Card {
            id: sysCard
            spacing: 10

            Grid {
                width: parent.width
                columns: Form.reaver ? 1 : 2
                spacing: Form.reaver ? 0 : 8

                Tile {
                    width: Form.reaver ? parent.width : (parent.width - 8) / 2
                    icon: "nightlight"
                    label: "Night mode"
                    glyph: "sky"
                    sub: DisplayService.nightModeEnabled ? "On" : "Off"
                    on: DisplayService.nightModeEnabled
                    onClicked: DisplayService.toggleNightMode()
                }

                Tile {
                    width: Form.reaver ? parent.width : (parent.width - 8) / 2
                    icon: "contrast"
                    label: "Dark mode"
                    sub: SessionData.isLightMode ? "Off" : "On"
                    on: !SessionData.isLightMode
                    onClicked: Theme.toggleLightMode()
                }

                Tile {
                    width: Form.reaver ? parent.width : (parent.width - 8) / 2
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

                // Plugin tiles: every plugin widget that offers a control-centre tile gets one here.
                Repeater {
                    model: pluginHost.count

                    Tile {
                        required property int index
                        readonly property var plugin: pluginHost.itemAt(index)?.item ?? null
                        readonly property string pluginId: pluginHost.itemAt(index)?.modelData ?? ""
                        visible: !!plugin && (plugin.ccWidgetPrimaryText ?? "") !== ""
                        width: Form.reaver ? sysCard.width - sysCard.padding * 2 : (sysCard.width - sysCard.padding * 2 - 8) / 2
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

            // Plugins that only draw a bar widget (the cat, the network indicator and so on) have
            // no bar to sit on here, so they live on this shelf. Clicking one runs its own action
            // or opens its panel below.
            Column {
                visible: shelf.children.length > 1 && shelf.implicitHeight > 0
                width: parent.width
                spacing: 6

                Heading {
                    x: 8
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
                                color: shelfMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHighest
                                edgeColor: Theme.withAlpha(Theme.outline, Form.khaslana ? 0.9 : 0.45)
                                lining: false
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
                width: parent.width
                height: visible ? Math.max(120, plugin?.ccDetailContent ? (plugin.ccDetailHeight ?? 250) : (plugin?.popoutHeight || 300)) : 0
                sourceComponent: wanted !== "" && plugin ? (plugin.ccDetailContent ?? plugin.popoutContent) : null
            }

            // Tray
            Row {
                visible: trayItems.count > 0
                width: parent.width
                leftPadding: 8
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

            // Running apps: click one to bring it forward.
            Heading {
                visible: panelWin.toplevels.length > 0
                x: 8
                topPadding: 4
                text: panelWin.tx("RUNNING APPS") + "  " + panelWin.toplevels.length
            }

            Repeater {
                model: panelWin.toplevels

                ListRow {
                    required property var modelData
                    width: sysCard.width - sysCard.padding * 2
                    icon: "web_asset"
                    label: modelData?.title || modelData?.appId || ""
                    note: Paths.getAppName(modelData?.appId ?? "", DesktopEntries.heuristicLookup(modelData?.appId ?? ""))
                    current: !!modelData?.activated
                    onClicked: {
                        modelData?.activate();
                        panelWin.close();
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
                    color: Theme.withAlpha(Form.reaver ? Theme.live : Theme.outline, 0.4)
                }

                Row {
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 4
                    spacing: 8

                    DW.DIcon {
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
