import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets as DW

// The control centre, laid out per form (the v3 mockup):
//   Khaslana: the Black Tide over the whole screen; forms and block meters on the left,
//     switches in the middle, battery and system on the right.
//   Flame Reaver: the right half of the screen, a shard with a torn left edge, two columns.
//   Phainon: a scroll unrolled from the island, 1020 px wide, two columns.
// Every menu opens beneath the switch it belongs to (CcMenu) and pushes the rest down; one is
// open at a time. Switches are CcSwitch, levels CcLevel.
PanelWindow {
    id: panelWin

    required property var targetScreen
    property int strip: 40
    property bool shown: false
    property real opening: shown ? 1 : 0
    readonly property real reveal: Motion.step(opening)
    // The open menu: "", wifi, bt, out, mic, battery, hours, plugins or apps
    property string section: ""
    // A plugin's detail page open in the plugins menu: "" or "plugin:<id>"
    property string openList: ""
    // The secured network waiting for a password
    property string askSsid: ""
    property bool leaveArmed: false

    // A theme other than Coreflame's gets Phainon's layout in that theme's colours.
    readonly property string lay: !Form.active ? "phainon" : Form.form
    readonly property bool kh: lay === "khaslana"
    readonly property bool rv: lay === "reaver"
    readonly property bool ph: lay === "phainon"
    // Phainon's parchment only in light mode; in dark mode the theme's own surfaces
    readonly property bool parch: ph && Form.active && Theme.isLightMode
    readonly property string body: ph ? (Form.active ? Form.numerals : Theme.fontFamily) : "Chakra Petch"
    readonly property string capFont: kh ? "Cinzel" : "Chakra Petch"

    readonly property QtObject pal: QtObject {
        readonly property color ink: panelWin.kh ? "#F3E6CC" : (panelWin.rv ? "#E9E7F2" : (panelWin.parch ? "#1E2752" : Theme.surfaceText))
        readonly property color mut: panelWin.kh ? "#C9B89E" : (panelWin.rv ? "#A8A4BC" : (panelWin.parch ? "#4A5484" : Theme.withAlpha(Theme.surfaceText, 0.65)))
        readonly property color hi: panelWin.kh ? "#F5D27A" : (panelWin.rv ? "#F2EEE0" : ink)
        readonly property color accent: panelWin.kh ? "#E0B04A" : (panelWin.rv ? "#B9A8FF" : lapis)
        readonly property color lapis: panelWin.parch ? "#334786" : Theme.primary
        readonly property color cap: panelWin.kh ? "#E0B04A" : (panelWin.rv ? "#B9A8FF" : (panelWin.parch ? "#8A6418" : Theme.primary))
        readonly property color paper: panelWin.parch ? "#F7F3E8" : Theme.surfaceContainer
        readonly property color plate: panelWin.kh ? "#0B080B" : (panelWin.rv ? "#15121F" : (panelWin.parch ? "#FBF9F3" : Theme.surfaceContainerHigh))
        readonly property color hover: panelWin.kh ? "#1A0D10" : (panelWin.rv ? "#1F1A2E" : (panelWin.parch ? "#FFFDF7" : Theme.surfaceContainerHighest))
        readonly property color rim: panelWin.kh ? "#5A3A1E" : (panelWin.rv ? "#3A3452" : (panelWin.parch ? "#DCCDA6" : Theme.withAlpha(Theme.outline, 0.45)))
        readonly property color rim2: panelWin.kh ? "#8A5A2B" : (panelWin.rv ? "#5C5478" : (panelWin.parch ? "#C8B27E" : Theme.withAlpha(Theme.outline, 0.7)))
        readonly property color edge: panelWin.kh ? "#F2C75C" : (panelWin.rv ? "#B9A8FF" : (panelWin.parch ? "#A87A22" : Theme.primary))
        readonly property color openBg: panelWin.kh ? "#0F0A0C" : (panelWin.rv ? "#2E2650" : (panelWin.parch ? "#FFF8E2" : Theme.surfaceContainerHighest))
        readonly property color sub: panelWin.kh ? "#0F0A0C" : (panelWin.rv ? "#120F1C" : plate)
        readonly property color li: panelWin.kh ? "#160D10" : "transparent"
        readonly property color liOn: panelWin.kh ? "#3A0A12" : (panelWin.rv ? "#2E2650" : (panelWin.parch ? Qt.rgba(241 / 255, 218 / 255, 79 / 255, 0.3) : Theme.withAlpha(Theme.primary, 0.2)))
        readonly property color seg: panelWin.rv ? "#1C1828" : "transparent"
        readonly property color segOn: panelWin.kh ? "#8E1424" : (panelWin.rv ? "#8F7BE0" : (panelWin.parch ? "#A87A22" : Theme.primary))
        readonly property color segInk: panelWin.kh ? "#F5D27A" : (panelWin.rv ? "#0D0B14" : (panelWin.parch ? "#FFFFFF" : Theme.primaryText))
    }

    readonly property var btDevice: BluetoothService.adapter?.devices?.values?.find(d => d.connected) ?? null
    readonly property var toplevels: CompositorService.sortedToplevels ?? []
    // Plugin widgets that offer a control-centre tile (KDE Connect and the like)
    readonly property var pluginIds: Object.keys(PluginService.pluginWidgetComponents ?? {}).filter(id => !Form.heldPlugins.includes(id))
    // The loaded plugin widgets as {id, item}
    readonly property var plugins: {
        const out = [];
        for (let i = 0; i < pluginHost.count; i++) {
            const l = pluginHost.itemAt(i);
            if (l?.item)
                out.push({
                    "id": l.modelData,
                    "item": l.item
                });
        }
        return out;
    }

    // [form, name, icon, epithet]; the epithets are Form.epithet's
    readonly property var formList: [["phainon", "Phainon", "wb_sunny", "The Deliverer"], ["khaslana", "Khaslana", "local_fire_department", "Bearer of Chaos"], ["reaver", ph ? "Flame Reaver" : "Reaver", "dark_mode", "of the Deepest Dark"]]

    function toggleSection(name) {
        // Khaslana shows the battery block open on the right; it has no battery menu to toggle
        if (kh && name === "battery")
            return;
        section = section === name ? "" : name;
        askSsid = "";
        openList = "";
        if (section === "wifi" && NetworkService.wifiEnabled)
            NetworkService.scanWifi();
    }

    function toggleList(name) {
        openList = openList === name ? "" : name;
    }

    function open() {
        shown = true;
    }

    function close() {
        shown = false;
        leaveArmed = false;
        askSsid = "";
        openList = "";
        section = "";
    }

    function toggle() {
        if (shown)
            close();
        else
            shown = true;
    }

    function tx(text) {
        return rv ? String(text).toLowerCase() : text;
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

    // What a switch shows: icon, label, sub, on, toggle (flips something), menu (opens one)
    function info(key) {
        const eth = NetworkService.networkStatus === "ethernet";
        switch (key) {
        case "wifi":
            return {
                "icon": eth ? "lan" : NetworkService.wifiSignalIcon,
                "label": eth ? "Ethernet" : "Wi-Fi",
                "sub": eth ? "connected" : (NetworkService.currentWifiSSID ? NetworkService.currentWifiSSID + " · connected" : (NetworkService.wifiEnabled ? "not connected" : "off")),
                "on": NetworkService.wifiEnabled && NetworkService.networkStatus !== "disconnected",
                "toggle": true,
                "menu": true
            };
        case "bt":
            return {
                "icon": BluetoothService.connected ? "bluetooth_connected" : "bluetooth",
                "label": "Bluetooth",
                "sub": btDevice ? btDevice.name + (btDevice.batteryAvailable ? " · " + Math.round(btDevice.battery * 100) + "%" : "") : (BluetoothService.enabled ? (ph ? "on · no device" : "no device") : "off"),
                "on": BluetoothService.enabled,
                "toggle": true,
                "menu": true
            };
        case "out":
            return {
                "icon": AudioService.sinkVolumeIconName,
                "label": AudioService.sink ? AudioService.displayName(AudioService.sink) : "No output",
                "sub": AudioService.sink?.audio?.muted ? "muted" : "output",
                "on": !!AudioService.sink?.audio && !AudioService.sink.audio.muted,
                "toggle": true,
                "menu": true
            };
        case "mic":
            return {
                "icon": AudioService.source?.audio?.muted ? "mic_off" : "mic",
                "label": AudioService.source ? AudioService.displayName(AudioService.source) : "No microphone",
                "sub": AudioService.source?.audio?.muted ? "muted" : "input",
                "on": !!AudioService.source?.audio && !AudioService.source.audio.muted,
                "toggle": true,
                "menu": true
            };
        case "battery":
            {
                const left = BatteryService.isPluggedIn ? "plugged in" : (BatteryService.formatTimeRemaining() || "");
                return {
                    "icon": BatteryService.isPluggedIn ? "battery_charging_full" : "battery_5_bar",
                    "label": BatteryService.batteryAvailable ? "Battery " + Math.round(BatteryService.batteryLevel) + "%" : "Power",
                    "sub": rv ? String(BatteryService.batteryStatus) : profileName(PowerProfiles.profile).toLowerCase() + (left ? " · " + left : ""),
                    "on": BatteryService.isPluggedIn,
                    "toggle": false,
                    "menu": true
                };
            }
        case "dnd":
            return {
                "icon": SessionData.doNotDisturb ? "notifications_off" : "do_not_disturb_on",
                "label": kh ? "Silence" : "Do not disturb",
                "sub": SessionData.doNotDisturb ? "on" : "off",
                "on": SessionData.doNotDisturb,
                "toggle": true,
                "menu": false
            };
        case "awake":
            return {
                "icon": "coffee",
                "label": "Keep awake",
                "sub": SessionService.idleInhibited ? "on" : "off",
                "on": SessionService.idleInhibited,
                "toggle": true,
                "menu": false
            };
        case "night":
            return {
                "icon": "nightlight",
                "label": "Night mode",
                "sub": DisplayService.nightModeEnabled ? "on" : "off",
                "on": DisplayService.nightModeEnabled,
                "toggle": true,
                "menu": false
            };
        case "dark":
            return {
                "icon": "contrast",
                "label": "Dark mode",
                "sub": SessionData.isLightMode ? "off" : "on",
                "on": !SessionData.isLightMode,
                "toggle": true,
                "menu": false
            };
        case "clipboard":
            return {
                "icon": "content_paste",
                "label": "Clipboard",
                "sub": "history",
                "on": false,
                "toggle": false,
                "menu": false
            };
        }
        return {
            "icon": "",
            "label": key,
            "sub": "",
            "on": false,
            "toggle": false,
            "menu": false
        };
    }

    // A switch's own action: flip it, or run it
    function flip(key) {
        switch (key) {
        case "wifi":
            NetworkService.toggleWifiRadio();
            break;
        case "bt":
            if (BluetoothService.adapter)
                BluetoothService.adapter.enabled = !BluetoothService.adapter.enabled;
            break;
        case "out":
            AudioService.toggleMute();
            break;
        case "mic":
            AudioService.toggleMicMute();
            break;
        case "dnd":
            SessionData.setDoNotDisturb(!SessionData.doNotDisturb);
            break;
        case "awake":
            SessionService.toggleIdleInhibit();
            break;
        case "night":
            DisplayService.toggleNightMode();
            break;
        case "dark":
            Theme.toggleLightMode();
            break;
        case "clipboard":
            close();
            ipc("clipboard", "toggle");
            break;
        default:
            toggleSection(key);
        }
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

    Behavior on opening {
        NumberAnimation {
            duration: Motion.openMs
            easing.type: Motion.openEasing
            easing.overshoot: 0.6
        }
    }

    // Destroyed while open (a screen unplugged, another theme picked): release what opening took.
    Component.onDestruction: {
        section = "";
        if (shown)
            shown = false;
    }

    // Stock DMS only fills the Wi-Fi list while someone holds a network ref (DMS Settings does);
    // hold one while the Wi-Fi menu is open. Bluetooth discovery stops when its menu closes.
    readonly property bool netWatch: shown && section === "wifi"
    onNetWatchChanged: {
        if (netWatch)
            NetworkService.addRef();
        else
            NetworkService.removeRef();
    }
    onSectionChanged: {
        if (section !== "bt" && BluetoothService.adapter?.discovering)
            BluetoothService.adapter.discovering = false;
    }
    onShownChanged: {
        if (shown) {
            DgopService.addRef(["system"]);
            panel.forceActiveFocus();
        } else {
            DgopService.removeRef(["system"]);
        }
    }

    // A click outside the panel closes it
    MouseArea {
        anchors.fill: parent
        onClicked: panelWin.close()
    }

    // ---- parts shared by the three layouts ----

    component Cap: Text {
        font.family: panelWin.capFont
        font.pixelSize: panelWin.kh ? 12 : 11
        font.weight: Font.DemiBold
        font.letterSpacing: panelWin.kh ? 2.6 : 1.7
        font.capitalization: Font.AllUppercase
        color: panelWin.pal.cap
    }

    // The menu beneath a switch: slides out from under it, built only while open or closing
    component MenuSlot: CcSlide {
        id: slot
        property var keys: []
        property bool withProfile: true
        readonly property string now: open ? panelWin.section : ""
        // The menu shown here, kept while it slides back in after the section moved on. Moving
        // between keys of one slot (Khaslana's row of tiles) swaps the menu at once, unanimated.
        property string held: now
        onNowChanged: {
            if (now !== "")
                held = now;
        }
        lay: panelWin.lay
        width: parent ? parent.width : 0
        open: keys.includes(panelWin.section)
        sourceComponent: Component {
            CcMenu {
                cc: panelWin
                key: slot.held
                withProfile: slot.withProfile
            }
        }
    }

    // A switch with its menu beneath it
    component SwitchRow: Column {
        id: srow
        property string key: ""
        property bool withProfile: true
        readonly property var d: panelWin.info(key)
        width: parent ? parent.width : 0
        spacing: panelWin.rv ? 2 : 0

        CcSwitch {
            width: parent.width
            cc: panelWin
            icon: srow.d.icon
            label: srow.d.label
            sub: srow.d.sub
            on: srow.d.on
            toggle: srow.d.toggle
            menu: srow.d.menu
            open: panelWin.section === srow.key
            onClicked: panelWin.flip(srow.key)
            onExpand: panelWin.toggleSection(srow.key)
        }

        MenuSlot {
            keys: [srow.key]
            withProfile: srow.withProfile
        }
    }

    // Lock, power, settings
    component IconBtn: Item {
        id: ib
        property string icon: ""
        signal clicked
        width: panelWin.kh ? 44 : (panelWin.rv ? 36 : 38)
        height: width

        Rectangle {
            visible: panelWin.kh
            x: 3
            y: 3
            width: parent.width
            height: parent.height
            color: "#8E1424"
        }

        Rectangle {
            visible: !panelWin.rv
            anchors.fill: parent
            radius: panelWin.ph ? width / 2 : 0
            color: ibMouse.containsMouse ? panelWin.pal.hover : panelWin.pal.plate
            border.width: 1
            border.color: panelWin.kh ? "#E0B04A" : panelWin.pal.rim2
        }

        Shape {
            visible: panelWin.rv
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "#5C5478"
                strokeWidth: 1
                fillColor: ibMouse.containsMouse ? "#1F1A2E" : "#15121F"
                PathPolyline {
                    path: [Qt.point(0, 0), Qt.point(ib.width, ib.height * 0.1), Qt.point(ib.width * 0.92, ib.height), Qt.point(ib.width * 0.06, ib.height * 0.9), Qt.point(0, 0)]
                }
            }
        }

        DW.DIcon {
            anchors.centerIn: parent
            name: ib.icon
            size: panelWin.kh ? 20 : 17
            color: panelWin.pal.accent
        }

        MouseArea {
            id: ibMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ib.clicked()
        }
    }

    // Who is signed in, how long the machine has been up, and the session buttons
    component Header: Item {
        id: hdr
        width: parent ? parent.width : 0
        height: panelWin.rv ? 40 : 58

        ClippingRectangle {
            id: avatar
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: panelWin.rv ? 0 : -6
            width: panelWin.rv ? 32 : (panelWin.kh ? 40 : 46)
            height: width
            radius: panelWin.ph ? width / 2 : 0
            color: panelWin.pal.plate
            border.width: 1
            border.color: panelWin.pal.edge

            Image {
                id: face
                anchors.fill: parent
                anchors.margins: 1
                source: {
                    const img = Quickshell.env("COREFLAME_DEMO") === "1" ? "" : (PortalService.profileImage ?? "");
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
                size: 22
                color: panelWin.pal.accent
            }
        }

        Column {
            anchors.left: avatar.right
            anchors.leftMargin: 14
            anchors.verticalCenter: avatar.verticalCenter
            spacing: 0

            Item {
                width: who.implicitWidth
                height: who.implicitHeight

                // The Flame Reaver's glitch: a violet and a teal copy either side
                Repeater {
                    model: panelWin.rv ? [[2, Qt.rgba(143 / 255, 123 / 255, 224 / 255, 0.85)], [-2, Qt.rgba(79 / 255, 209 / 255, 197 / 255, 0.55)]] : []
                    Text {
                        required property var modelData
                        x: modelData[0]
                        text: who.text
                        font: who.font
                        color: modelData[1]
                    }
                }

                Text {
                    id: who
                    text: {
                        // screenshot sandboxes (COREFLAME_DEMO=1) show the demo name, never the real one
                        const n = Quickshell.env("COREFLAME_DEMO") === "1" ? "NeiKos496" : (UserInfoService.fullName || UserInfoService.username || "NeiKos496");
                        return panelWin.rv ? n.toLowerCase() : n;
                    }
                    font.family: panelWin.kh ? "Cinzel" : (panelWin.ph ? "Marcellus" : "Chakra Petch")
                    font.pixelSize: panelWin.kh ? 20 : (panelWin.rv ? 18 : 19)
                    font.weight: panelWin.kh || panelWin.rv ? Font.DemiBold : Font.Normal
                    font.letterSpacing: panelWin.kh ? 2 : 0
                    font.capitalization: panelWin.kh ? Font.AllUppercase : Font.MixedCase
                    color: panelWin.kh ? "#E0B04A" : panelWin.pal.ink
                }
            }

            Text {
                text: {
                    const up = DgopService.uptime || "";
                    if (panelWin.kh)
                        return "Bearer of Chaos" + (up ? " · " + up : "");
                    if (panelWin.rv)
                        return (up ? up.toLowerCase() + " · " : "") + "cycle " + Form.cycleText;
                    return up;
                }
                font.family: panelWin.ph ? "Cormorant Garamond" : "Chakra Petch"
                font.italic: panelWin.ph
                font.pixelSize: panelWin.ph ? 17 : 13
                color: panelWin.pal.mut
            }
        }

        // Khaslana names the stage
        Text {
            visible: panelWin.kh
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -6
            text: "THE BLACK TIDE"
            font.family: "Cinzel"
            font.pixelSize: 26
            font.weight: Font.Bold
            font.letterSpacing: 7.8
            color: "#F5D27A"
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: avatar.verticalCenter
            spacing: panelWin.kh ? 12 : 8

            IconBtn {
                icon: "lock"
                onClicked: {
                    panelWin.close();
                    panelWin.ipc("lock", "lock");
                }
            }

            IconBtn {
                icon: "power_settings_new"
                onClicked: {
                    panelWin.close();
                    panelWin.ipc("powermenu", "toggle");
                }
            }

            IconBtn {
                icon: "settings"
                onClicked: {
                    panelWin.close();
                    panelWin.ipc("settings", "focusOrToggle");
                }
            }
        }

        // Khaslana: a gold rule with a red shadow; Phainon: a thin line
        Rectangle {
            visible: !panelWin.rv
            anchors.bottom: parent.bottom
            width: parent.width
            height: panelWin.kh ? 2 : 1
            color: panelWin.kh ? "#E0B04A" : panelWin.pal.rim
        }

        Rectangle {
            visible: panelWin.kh
            y: parent.height
            width: parent.width
            height: 3
            color: "#8E1424"
        }
    }

    // The three forms
    component Forms: Row {
        id: forms
        width: parent ? parent.width : 0
        spacing: panelWin.rv ? 6 : 8

        Repeater {
            model: panelWin.formList

            Item {
                id: fb
                required property var modelData
                readonly property bool current: Form.form === modelData[0]
                width: (forms.width - forms.spacing * 2) / 3
                height: panelWin.kh ? 110 : (panelWin.rv ? 76 : 104)

                // Khaslana: a block, red with a dark offset when chosen
                Rectangle {
                    visible: panelWin.kh && fb.current
                    x: 4
                    y: 4
                    width: parent.width
                    height: parent.height
                    color: "#3A0A12"
                }

                Rectangle {
                    visible: panelWin.kh
                    anchors.fill: parent
                    color: fb.current ? "#8E1424" : "#0B080B"
                    border.width: 1
                    border.color: fb.current ? "#F2C75C" : "#8A5A2B"
                }

                // Reaver: a small shard
                Shape {
                    visible: panelWin.rv
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: fb.current ? "#B9A8FF" : "#3A3452"
                        strokeWidth: 1
                        fillColor: fb.current ? "#2E2650" : "#15121F"
                        PathPolyline {
                            path: [Qt.point(0, 0), Qt.point(fb.width, fb.height * 0.08), Qt.point(fb.width * 0.96, fb.height), Qt.point(fb.width * 0.04, fb.height * 0.92), Qt.point(0, 0)]
                        }
                    }
                }

                // Phainon: a medallion, gold when chosen
                Rectangle {
                    visible: panelWin.ph
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 2
                    width: 58
                    height: 58
                    radius: 29
                    color: fb.current ? (panelWin.parch ? "#EDCB6A" : Theme.primary) : panelWin.pal.plate
                    border.width: 1
                    border.color: fb.current ? panelWin.pal.edge : panelWin.pal.rim2

                    Rectangle {
                        visible: fb.current
                        anchors.centerIn: parent
                        width: parent.width + 8
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.width: 4
                        border.color: panelWin.parch ? Qt.rgba(241 / 255, 218 / 255, 79 / 255, 0.3) : Theme.withAlpha(Theme.primary, 0.3)
                    }
                }

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: panelWin.ph ? 0 : Math.round((parent.height - height) / 2)
                    spacing: panelWin.kh ? 6 : 3

                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 26
                        height: panelWin.ph ? 62 : (panelWin.kh ? 26 : 22)

                        DW.DIcon {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: panelWin.ph ? 2 : 0
                            name: fb.modelData[2]
                            size: panelWin.kh ? 26 : (panelWin.rv ? 22 : 24)
                            color: panelWin.ph ? (fb.current && !panelWin.parch ? Theme.primaryText : panelWin.pal.lapis) : (panelWin.kh && fb.current ? "#F5D27A" : panelWin.pal.accent)
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: panelWin.tx(fb.modelData[1])
                        font.family: panelWin.kh ? "Cinzel" : (panelWin.ph ? "Marcellus" : "Chakra Petch")
                        font.pixelSize: panelWin.kh ? 12 : (panelWin.rv ? 13 : 14)
                        font.weight: panelWin.kh ? Font.DemiBold : Font.Normal
                        font.letterSpacing: panelWin.kh ? 1.4 : 0
                        font.capitalization: panelWin.kh ? Font.AllUppercase : Font.MixedCase
                        color: panelWin.kh && fb.current ? "#F5D27A" : (panelWin.rv && fb.current ? "#F2EEE0" : panelWin.pal.ink)
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: panelWin.tx(fb.modelData[3])
                        font.family: panelWin.ph ? "Cormorant Garamond" : "Chakra Petch"
                        font.italic: panelWin.ph
                        font.pixelSize: panelWin.ph ? 14 : 11
                        color: panelWin.kh && fb.current ? "#F5D27A" : panelWin.pal.mut
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: panelWin.ipc("form", "set", fb.modelData[0])
                }
            }
        }
    }

    // The schedule, with its menu beneath
    component Hours: Column {
        width: parent ? parent.width : 0
        spacing: panelWin.rv ? 2 : 0

        CcSwitch {
            width: parent.width
            cc: panelWin
            line: true
            icon: "schedule"
            label: Form.schedule.sun && Form.sunTimes ? "By the sun" : "By the hour"
            sub: Form.startOf("phainon") + " / " + Form.startOf("khaslana") + " / " + Form.schedule.reaver + (panelWin.ph ? "   " + (Form.schedule.enabled ? "On" : "Off") : (Form.schedule.enabled ? "" : " · off"))
            on: Form.schedule.enabled
            menu: true
            open: panelWin.section === "hours"
            onExpand: panelWin.toggleSection("hours")
        }

        MenuSlot {
            keys: ["hours"]
        }
    }

    // Volume, brightness, microphone
    component Levels: Flow {
        id: levels
        readonly property bool meters: panelWin.kh
        readonly property real cell: meters ? (width - spacing * 2) / 3 : width
        width: parent ? parent.width : 0
        spacing: meters ? 14 : (panelWin.rv ? 10 : 12)

        CcLevel {
            width: levels.cell
            cc: panelWin
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

        CcLevel {
            visible: DisplayService.brightnessAvailable
            width: levels.cell
            cc: panelWin
            icon: "brightness_6"
            value: DisplayService.brightnessLevel / 100
            valueText: DisplayService.brightnessLevel + "%"
            onMoved: to => DisplayService.setBrightness(Math.max(1, Math.round(to * 100)), DisplayService.lastIpcDevice, true)
        }

        CcLevel {
            visible: !!AudioService.source?.audio
            width: levels.cell
            cc: panelWin
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

    // Plugins, tray, running apps and the way back to stock DMS
    component SystemRows: Column {
        width: parent ? parent.width : 0
        spacing: panelWin.rv ? 4 : 8

        Column {
            width: parent.width
            spacing: panelWin.rv ? 2 : 0

            CcSwitch {
                width: parent.width
                cc: panelWin
                line: true
                icon: "extension"
                label: "Plugins"
                sub: String(panelWin.plugins.length)
                menu: true
                open: panelWin.section === "plugins"
                onExpand: panelWin.toggleSection("plugins")
            }

            MenuSlot {
                keys: ["plugins"]
            }
        }

        CcSwitch {
            visible: trayItems.count > 0
            width: parent.width
            cc: panelWin
            line: true
            icon: "apps"
            label: "Tray"

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Repeater {
                    id: trayItems
                    model: SystemTray.items

                    IconImage {
                        id: trayIcon
                        required property var modelData
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 20
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
        }

        Column {
            width: parent.width
            spacing: panelWin.rv ? 2 : 0

            CcSwitch {
                width: parent.width
                cc: panelWin
                line: true
                icon: "web_asset"
                label: "Running apps"
                sub: String(panelWin.toplevels.length)
                menu: true
                open: panelWin.section === "apps"
                onExpand: panelWin.toggleSection("apps")
            }

            MenuSlot {
                keys: ["apps"]
            }
        }

        // The way out: stock DMS, with the theme settings you had before Coreflame.
        CcSwitch {
            width: parent.width
            cc: panelWin
            line: true
            icon: "undo"
            label: panelWin.leaveArmed ? "Click again to leave Coreflame" : "Return to stock DMS"
            labelColor: panelWin.leaveArmed ? Theme.error : (panelWin.rv ? "#F07A85" : panelWin.pal.ink)
            iconColor: panelWin.rv ? "#F07A85" : (panelWin.leaveArmed ? Theme.error : panelWin.pal.accent)
            rimColor: panelWin.kh ? "#C2252F" : panelWin.pal.rim
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

    // A column that scrolls once its content outgrows it
    component Pane: Flickable {
        id: pane
        default property alias content: paneColumn.data
        property real spacing: 14
        contentHeight: paneColumn.implicitHeight
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: paneColumn
            width: pane.width
            spacing: pane.spacing
        }
    }

    // The Reaver's group: a dark plate with a violet left rule and a cut corner
    component Group: Item {
        id: grp
        default property alias content: grpCol.data
        width: parent ? parent.width : 0
        implicitHeight: grpCol.implicitHeight + 24
        height: implicitHeight

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                fillColor: Qt.rgba(28 / 255, 24 / 255, 40 / 255, 0.9)
                PathPolyline {
                    path: [Qt.point(0, 0), Qt.point(grp.width, 0), Qt.point(grp.width, grp.height - 10), Qt.point(grp.width - 14, grp.height), Qt.point(0, grp.height), Qt.point(0, 0)]
                }
            }
        }

        Rectangle {
            width: 2
            height: parent.height
            color: "#8F7BE0"
        }

        Column {
            id: grpCol
            x: 14
            y: 12
            width: grp.width - 28
            spacing: 8
        }
    }

    component Heading: Row {
        id: heading
        property string icon: ""
        property alias text: headText.text
        spacing: 8

        DW.DIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: heading.icon
            size: 16
            color: "#B9A8FF"
        }

        Cap {
            id: headText
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 12
        }
    }

    // ---- the panel ----

    Item {
        id: panel

        readonly property real sw: panelWin.width
        readonly property real sh: panelWin.height
        // Phainon's scroll: paper width, and the margin its rods and knobs take each side
        readonly property real paperW: Math.min(1020, sw - 80)
        readonly property real rodM: 32
        readonly property real phMax: sh - panelWin.strip - 40
        // Where the panel ends up
        readonly property rect target: panelWin.kh ? Qt.rect(0, panelWin.strip, sw, sh - panelWin.strip) : (panelWin.rv ? Qt.rect(Math.round(sw / 2), panelWin.strip + 4, sw - Math.round(sw / 2), sh - panelWin.strip - 4) : Qt.rect(Math.round((sw - paperW) / 2) - rodM, panelWin.strip + 6, paperW + rodM * 2, Math.min(phMax, stage.implicitHeight)))
        readonly property real r: panelWin.reveal

        // Khaslana spills out of the island; the Reaver cracks down from his tab; the scroll unrolls.
        x: panelWin.kh ? Math.round((sw - width) / 2) : target.x
        y: target.y
        width: panelWin.kh ? Math.round(420 + (sw - 420) * r) : target.width
        height: panelWin.kh ? Math.round(40 + (target.height - 40) * r) : (panelWin.ph ? Math.round(54 + (target.height - 54) * r) : Math.round(target.height * r))
        clip: true
        focus: true

        Keys.onEscapePressed: panelWin.close()

        // Clicks on the panel stay on it
        MouseArea {
            anchors.fill: parent
        }

        Loader {
            id: stage
            active: panelWin.shown || panelWin.reveal > 0.001
            x: panel.target.x - panel.x
            width: panel.target.width
            height: panelWin.ph ? panel.target.height : panel.target.height
            sourceComponent: panelWin.kh ? khLayout : (panelWin.rv ? rvLayout : phLayout)
        }

        // Phainon's lower rod rides the bottom of the unrolling paper
        Loader {
            active: panelWin.ph
            anchors.bottom: parent.bottom
            width: parent.width
            height: 32
            sourceComponent: rodComp
        }

        // Plugin widgets, loaded once and kept hidden: their tiles, pills and detail pages are
        // drawn in the plugins menu.
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

    // A gold rod with a knob at each end (Phainon's scroll)
    Component {
        id: rodComp

        Item {
            id: rod
            readonly property color hiC: panelWin.parch ? "#F3D98A" : Qt.lighter(Theme.primary, 1.4)
            readonly property color midC: panelWin.parch ? "#A87A22" : Theme.primary
            readonly property color loC: panelWin.parch ? "#7C5814" : Qt.darker(Theme.primary, 1.6)

            Rectangle {
                x: 14
                y: 5
                width: parent.width - 28
                height: 22
                radius: 11
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: rod.hiC
                    }
                    GradientStop {
                        position: 0.6
                        color: rod.midC
                    }
                    GradientStop {
                        position: 1
                        color: rod.loC
                    }
                }
            }

            Repeater {
                model: [0, 1]
                Rectangle {
                    required property int modelData
                    x: modelData === 0 ? 0 : rod.width - 32
                    width: 32
                    height: 32
                    radius: 16
                    color: rod.midC
                    border.width: 1
                    border.color: rod.loC
                    Rectangle {
                        anchors.centerIn: parent
                        width: 14
                        height: 14
                        radius: 7
                        color: rod.hiC
                    }
                }
            }
        }
    }

    // ---- Khaslana: the Black Tide over the whole screen ----
    Component {
        id: khLayout

        Item {
            id: khRoot
            readonly property real avail: width - 120 - 72
            readonly property real leftW: Math.round(avail * 0.22)
            readonly property real rightW: Math.round(avail * 0.31)
            readonly property real midW: avail - leftW - rightW
            readonly property var rows: [["wifi", "bt", "out", "mic"].filter(k => k !== "bt" || BluetoothService.available), ["dnd", "awake", "night", "dark"], ["clipboard"]]

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Qt.rgba(8 / 255, 5 / 255, 7 / 255, 0.72)
                    }
                    GradientStop {
                        position: 0.55
                        color: Qt.rgba(8 / 255, 5 / 255, 7 / 255, 0.86)
                    }
                    GradientStop {
                        position: 1
                        color: Qt.rgba(8 / 255, 5 / 255, 7 / 255, 0.94)
                    }
                }
            }

            // The tide drips from the top and rises from the bottom
            CfTide {
                width: parent.width
                height: 170
                edge: "top"
                seed: 23
                base: 0.16
            }

            CfTide {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 420
                edge: "bottom"
                seed: 11
                base: 0.3
                liquid: 400
                blocks: 140
                blockMax: 80
                cubes: 60
                cubeDepth: 420
            }

            CfCracks {
                anchors.fill: parent
                kind: "gold"
            }

            // The empty stage closes it, like a click outside
            MouseArea {
                anchors.fill: parent
                onClicked: panelWin.close()
            }

            Item {
                id: khBody
                x: 60
                y: 22
                width: parent.width - 120
                height: parent.height - 22 - 100
                opacity: panelWin.reveal

                Header {
                    id: khHead
                }

                Pane {
                    y: khHead.height + 36
                    width: khRoot.leftW
                    height: khBody.height - y

                    Cap {
                        text: "The three forms"
                    }
                    Forms {}
                    Hours {}
                    Cap {
                        text: "Levels"
                    }
                    Levels {}
                }

                Pane {
                    x: khRoot.leftW + 36
                    y: khHead.height + 36
                    width: khRoot.midW
                    height: khBody.height - y

                    Cap {
                        text: "Switches · each opens beneath itself"
                    }

                    Column {
                        width: parent.width
                        spacing: 10

                        Repeater {
                            model: khRoot.rows

                            Column {
                                id: khRow
                                required property var modelData
                                width: parent.width
                                spacing: 10

                                Row {
                                    spacing: 10

                                    Repeater {
                                        model: khRow.modelData

                                        CcSwitch {
                                            required property string modelData
                                            readonly property var d: panelWin.info(modelData)
                                            width: (khRoot.midW - 30) / 4
                                            cc: panelWin
                                            icon: d.icon
                                            label: d.label
                                            sub: d.sub
                                            on: d.on
                                            toggle: d.toggle
                                            menu: d.menu
                                            open: panelWin.section === modelData
                                            onClicked: panelWin.flip(modelData)
                                            onExpand: panelWin.toggleSection(modelData)
                                        }
                                    }
                                }

                                MenuSlot {
                                    keys: khRow.modelData
                                }
                            }
                        }
                    }
                }

                Pane {
                    x: khBody.width - khRoot.rightW
                    y: khHead.height + 36
                    width: khRoot.rightW
                    height: khBody.height - y

                    // Pyric corpus: the battery as a row of blocks
                    Rectangle {
                        width: parent.width
                        height: batCol.implicitHeight + 28
                        color: "#0B080B"
                        border.width: 1
                        border.color: "#8A5A2B"

                        Column {
                            id: batCol
                            x: 14
                            y: 14
                            width: parent.width - 28
                            spacing: 8

                            Cap {
                                text: "Pyric corpus · battery"
                            }

                            Row {
                                visible: BatteryService.batteryAvailable
                                spacing: 12

                                Text {
                                    id: batPct
                                    text: Math.round(BatteryService.batteryLevel) + "%"
                                    font.family: Form.numerals
                                    font.pixelSize: 44
                                    color: "#E0B04A"
                                }

                                Text {
                                    anchors.baseline: batPct.baseline
                                    text: String(BatteryService.batteryStatus).toLowerCase()
                                    font.family: "Chakra Petch"
                                    font.pixelSize: 15
                                    color: "#C9B89E"
                                }
                            }

                            Row {
                                id: batBlocks
                                visible: BatteryService.batteryAvailable
                                readonly property int lit: Math.round(BatteryService.batteryLevel / 100 * 12)
                                width: parent.width
                                height: 34
                                spacing: 3

                                Repeater {
                                    model: 12
                                    Rectangle {
                                        required property int index
                                        width: (batBlocks.width - 33) / 12
                                        height: 34
                                        color: index >= batBlocks.lit ? "#22100F" : (index === batBlocks.lit - 1 ? "#F2C75C" : "#C2252F")
                                    }
                                }
                            }

                            CcMenu {
                                width: parent.width
                                cc: panelWin
                                key: "battery"
                                bare: true
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: sysCol.implicitHeight + 28
                        color: "#0B080B"
                        border.width: 1
                        border.color: "#8A5A2B"

                        Column {
                            id: sysCol
                            x: 14
                            y: 14
                            width: parent.width - 28
                            spacing: 8

                            Cap {
                                text: "System"
                            }
                            SystemRows {}
                        }
                    }
                }
            }
        }
    }

    // ---- Flame Reaver: a shard over the right half ----
    Component {
        id: rvLayout

        Item {
            id: rvRoot
            // The torn left edge, as fractions of the shard
            readonly property var edge: [[0.04, 0], [1, 0], [1, 1], [0.05, 1], [0.09, 0.86], [0.04, 0.72], [0.08, 0.58], [0.03, 0.45], [0.06, 0.31], [0.01, 0.17], [0.04, 0.09]]
            function poly(inset) {
                const pts = edge.map(p => Qt.point(p[0] * width + (p[0] < 0.5 ? inset : -inset), Math.max(inset, Math.min(height - inset, p[1] * height))));
                return pts.concat([pts[0]]);
            }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: -1
                    fillGradient: LinearGradient {
                        x1: 0
                        y1: 0
                        x2: rvRoot.width
                        y2: rvRoot.height
                        GradientStop {
                            position: 0
                            color: "#B9A8FF"
                        }
                        GradientStop {
                            position: 0.5
                            color: "#5C5478"
                        }
                        GradientStop {
                            position: 1
                            color: "#8F7BE0"
                        }
                    }
                    PathPolyline {
                        path: rvRoot.poly(0)
                    }
                }

                ShapePath {
                    strokeWidth: -1
                    fillColor: Qt.rgba(13 / 255, 11 / 255, 20 / 255, 0.95)
                    PathPolyline {
                        path: rvRoot.poly(2)
                    }
                }
            }

            // Fractures from a point of impact, kept inside the torn edge
            CfCracks {
                x: parent.width * 0.1
                width: parent.width * 0.9 - 2
                height: parent.height - 2
                kind: "violet"
                opacity: 0.6
            }

            Item {
                id: rvBody
                x: 70
                y: 22
                width: parent.width - 96
                height: parent.height - 42
                opacity: panelWin.reveal
                readonly property real colW: (width - 22) / 2

                Group {
                    id: rvHead
                    width: parent.width
                    Header {}
                }

                Pane {
                    y: rvHead.height + 14
                    width: rvBody.colW
                    height: rvBody.height - y

                    Group {
                        Heading {
                            icon: "swords"
                            text: "forms"
                        }
                        Forms {}
                        Hours {}
                    }
                    Group {
                        Heading {
                            icon: "volume_up"
                            text: "levels"
                        }
                        Levels {}
                    }
                    Group {
                        Heading {
                            icon: "settings"
                            text: "system"
                        }
                        SystemRows {}
                    }
                }

                Pane {
                    x: rvBody.colW + 22
                    y: rvHead.height + 14
                    width: rvBody.colW
                    height: rvBody.height - y

                    Group {
                        Heading {
                            icon: "close"
                            text: "switches · each opens beneath itself"
                        }

                        Repeater {
                            model: ["wifi", "bt", "out", "mic", "battery", "dnd", "awake", "night", "dark", "clipboard"].filter(k => k !== "bt" || BluetoothService.available)
                            SwitchRow {
                                required property string modelData
                                key: modelData
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- Phainon: a scroll unrolled from the island ----
    Component {
        id: phLayout

        Item {
            id: phRoot
            readonly property real colW: (panel.paperW - 52 - 26) / 2
            readonly property real colH: Math.max(leftCol.implicitHeight, rightCol.implicitHeight)
            readonly property real bodyMax: panel.phMax - 27 * 2 - 18 - 20 - phHead.height - 12
            implicitHeight: 27 + 18 + phHead.height + 12 + Math.min(colH, bodyMax) + 20 + 27

            // Paper between the rods
            Rectangle {
                x: panel.rodM
                y: 27
                width: panel.paperW
                height: phRoot.implicitHeight - 54
                color: panelWin.pal.paper

                Rectangle {
                    width: 1
                    height: parent.height
                    color: panelWin.pal.rim2
                }
                Rectangle {
                    anchors.right: parent.right
                    width: 1
                    height: parent.height
                    color: panelWin.pal.rim2
                }

                // The fold down the middle
                Rectangle {
                    x: parent.width / 2
                    y: phHead.y + phHead.height + 12
                    width: 1
                    height: parent.height - y - 18
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: "transparent"
                        }
                        GradientStop {
                            position: 0.15
                            color: panelWin.pal.rim2
                        }
                        GradientStop {
                            position: 0.85
                            color: panelWin.pal.rim2
                        }
                        GradientStop {
                            position: 1
                            color: "transparent"
                        }
                    }
                }

                Header {
                    id: phHead
                    x: 26
                    y: 18
                    width: parent.width - 52
                }

                Pane {
                    id: leftPane
                    x: 26
                    y: phHead.y + phHead.height + 12
                    width: phRoot.colW
                    height: Math.min(phRoot.colH, phRoot.bodyMax)

                    Column {
                        id: leftCol
                        width: parent.width
                        spacing: 10

                        Cap {
                            text: "The three forms"
                        }
                        Forms {}
                        Hours {}
                        Cap {
                            topPadding: 6
                            text: "Levels"
                        }
                        Levels {}

                        Row {
                            id: meds
                            width: parent.width
                            topPadding: 6

                            Repeater {
                                model: ["dnd", "awake", "night", "dark", "clipboard"]

                                CcSwitch {
                                    required property string modelData
                                    readonly property var d: panelWin.info(modelData)
                                    width: meds.width / 5
                                    cc: panelWin
                                    medal: true
                                    icon: d.icon
                                    label: d.label
                                    on: d.on
                                    toggle: d.toggle
                                    onClicked: panelWin.flip(modelData)
                                }
                            }
                        }

                        Cap {
                            topPadding: 6
                            text: "System"
                        }
                        SystemRows {}
                    }
                }

                Pane {
                    x: parent.width - 26 - phRoot.colW
                    y: leftPane.y
                    width: phRoot.colW
                    height: leftPane.height

                    Column {
                        id: rightCol
                        width: parent.width
                        spacing: 10

                        Cap {
                            text: "Passage · Ocean · Pyric corpus"
                        }

                        Repeater {
                            model: ["wifi", "bt", "out", "mic", "battery"].filter(k => k !== "bt" || BluetoothService.available)
                            SwitchRow {
                                required property string modelData
                                key: modelData
                                withProfile: false
                            }
                        }

                        CcMenu {
                            width: parent.width
                            cc: panelWin
                            key: "profile"
                            bare: true
                        }
                    }
                }
            }

            Loader {
                width: parent.width
                height: 32
                sourceComponent: rodComp
            }
        }
    }
}
