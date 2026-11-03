import QtQuick
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets as DW

// A control-centre menu, opened beneath the switch it belongs to. `key` picks the body:
// wifi, bt, out, mic, battery, profile, hours, plugins, apps. `bare` drops the frame (Khaslana's
// battery section and the power profile drawn on the page).
Item {
    id: menu

    required property var cc
    property string key: ""
    property bool bare: false
    // Battery: also show the power profile under the readings
    property bool withProfile: true

    readonly property var pal: cc.pal
    readonly property string lay: cc.lay
    readonly property real pad: bare ? 0 : (lay === "khaslana" ? 14 : 12)
    readonly property real indent: !bare && lay === "reaver" ? 18 : 0

    implicitHeight: body.implicitHeight + (bare ? 0 : (lay === "phainon" ? 20 : pad * 2))

    // Clicks inside a menu never reach the panel's close-on-click backdrop
    MouseArea {
        anchors.fill: parent
    }

    // Khaslana: a gold-edged plate with a red offset
    Rectangle {
        visible: !menu.bare && menu.lay === "khaslana"
        x: 4
        y: 4
        width: parent.width
        height: parent.height
        color: "#8E1424"
    }

    Rectangle {
        visible: !menu.bare
        x: menu.indent
        width: parent.width - menu.indent
        height: parent.height
        color: menu.pal.sub
        radius: menu.lay === "phainon" ? 12 : 0
        topLeftRadius: 0
        topRightRadius: 0
        border.width: menu.lay === "reaver" ? 0 : 1
        border.color: menu.pal.edge

        // Phainon's menu hangs from its row: hide the shared top edge
        Rectangle {
            visible: menu.lay === "phainon"
            x: 1
            width: parent.width - 2
            height: 1
            color: parent.color
        }

        // The Reaver's dashed left rule
        Column {
            visible: menu.lay === "reaver"
            spacing: 3
            Repeater {
                model: Math.ceil(menu.height / 7)
                Rectangle {
                    width: 2
                    height: 4
                    color: "#8F7BE0"
                }
            }
        }
    }

    Column {
        id: body
        x: menu.indent + menu.pad
        y: menu.bare ? 0 : (menu.lay === "phainon" ? 8 : menu.pad)
        width: menu.width - x - menu.pad
        spacing: 6

        Loader {
            width: parent.width
            sourceComponent: ({
                    "wifi": wifiBody,
                    "bt": btBody,
                    "out": outBody,
                    "mic": micBody,
                    "battery": batteryBody,
                    "profile": profileBody,
                    "hours": hoursBody,
                    "plugins": pluginsBody,
                    "apps": appsBody
                })[menu.key] ?? null
        }
    }

    // ---- parts ----

    component Cap: Text {
        font.family: menu.cc.capFont
        font.pixelSize: menu.lay === "khaslana" ? 10 : 11
        font.weight: Font.DemiBold
        font.letterSpacing: menu.lay === "khaslana" ? 2.2 : 1.6
        font.capitalization: Font.AllUppercase
        color: menu.pal.cap
    }

    component Note: Text {
        width: parent ? parent.width : 0
        wrapMode: Text.WordWrap
        font.family: menu.cc.body
        font.pixelSize: 13
        color: menu.pal.mut
    }

    // One line in a menu: icon, name, a note on the right
    component Li: Item {
        id: li
        property string icon: ""
        property string label: ""
        property string note: ""
        property bool current: false
        signal clicked

        width: parent ? parent.width : 0
        height: menu.lay === "khaslana" ? 32 : 30

        Rectangle {
            anchors.fill: parent
            radius: menu.lay === "phainon" ? 8 : 0
            color: li.current ? menu.pal.liOn : (liMouse.containsMouse ? menu.pal.hover : menu.pal.li)
            border.width: li.current && menu.lay === "khaslana" ? 1 : 0
            border.color: "#C2252F"
        }

        DW.DIcon {
            visible: !(menu.lay === "reaver" && li.current)
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            name: li.icon
            size: 16
            color: menu.pal.accent
        }

        // The Flame Reaver marks the chosen one with his crossed blades.
        CfCrossToggle {
            visible: menu.lay === "reaver" && li.current
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            checked: true
            color: Theme.live
        }

        Text {
            x: 34
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - liNote.implicitWidth - 18
            elide: Text.ElideRight
            text: menu.cc.tx(li.label)
            font.family: menu.cc.body
            font.pixelSize: 14
            font.weight: li.current ? Font.DemiBold : Font.Normal
            color: menu.pal.ink
        }

        Text {
            id: liNote
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: menu.cc.tx(li.note)
            font.family: menu.cc.body
            font.pixelSize: 13
            color: menu.pal.mut
        }

        MouseArea {
            id: liMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: li.clicked()
        }
    }

    // A small labelled reading (battery health and the like)
    component Kv: Rectangle {
        property string label: ""
        property string value: ""
        height: 44
        color: menu.pal.li.a === 0 ? menu.pal.plate : menu.pal.li
        radius: menu.lay === "phainon" ? 8 : 0

        Column {
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            Text {
                text: menu.cc.tx(parent.parent.label)
                font.family: menu.cc.body
                font.pixelSize: 13
                color: menu.pal.mut
            }
            Text {
                text: menu.cc.tx(parent.parent.value)
                font.family: menu.cc.body
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: menu.pal.hi
            }
        }
    }

    // A pill or step button
    component Step: Rectangle {
        id: step
        property string text: ""
        property bool on: false
        property bool usable: true
        signal clicked
        height: 28
        radius: menu.lay === "phainon" ? 14 : 0
        opacity: usable ? 1 : 0.4
        color: on ? menu.pal.segOn : (stepMouse.containsMouse ? menu.pal.hover : menu.pal.seg)
        border.width: menu.lay === "khaslana" || menu.lay === "phainon" ? 1 : 0
        border.color: on ? menu.pal.edge : menu.pal.rim2

        Text {
            anchors.centerIn: parent
            text: menu.cc.tx(step.text)
            font.family: menu.cc.body
            font.pixelSize: 13
            font.weight: step.on ? Font.DemiBold : Font.Normal
            color: step.on ? menu.pal.segInk : menu.pal.ink
        }

        MouseArea {
            id: stepMouse
            anchors.fill: parent
            enabled: step.usable
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: step.clicked()
        }
    }

    // ---- bodies ----

    Component {
        id: wifiBody

        Column {
            id: wifiCol
            spacing: 4

            Li {
                icon: NetworkService.wifiEnabled ? "wifi" : "wifi_off"
                label: NetworkService.wifiEnabled ? "Wi-Fi on" : "Wi-Fi off"
                note: NetworkService.wifiEnabled ? "turn off" : "turn on"
                onClicked: NetworkService.toggleWifiRadio()
            }

            Repeater {
                model: NetworkService.wifiEnabled ? (NetworkService.wifiNetworks ?? []).slice().sort((x, y) => (y.connected ? 1000 : y.signal) - (x.connected ? 1000 : x.signal)).slice(0, 8) : []

                Li {
                    required property var modelData
                    icon: modelData.secured ? "lock" : "wifi"
                    label: modelData.ssid
                    note: modelData.connected ? "connected" : (modelData.signal + "%" + (modelData.saved ? " · saved" : ""))
                    current: modelData.connected
                    onClicked: {
                        if (modelData.connected)
                            NetworkService.disconnectWifi();
                        else if (modelData.saved || !modelData.secured)
                            NetworkService.connectToWifi(modelData.ssid);
                        else
                            menu.cc.askSsid = modelData.ssid;
                    }
                }
            }

            Note {
                visible: !NetworkService.wifiEnabled
                leftPadding: 8
                text: menu.cc.tx("Wi-Fi is off.")
            }

            Note {
                visible: NetworkService.wifiEnabled && (NetworkService.wifiNetworks ?? []).length === 0
                leftPadding: 8
                text: menu.cc.tx("Looking for networks…")
            }

            // Password for a new secured network
            Item {
                visible: menu.cc.askSsid !== ""
                width: parent.width
                height: 34

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1.5
                    color: menu.pal.lapis
                }

                TextInput {
                    id: wifiPassword
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 16
                    clip: true
                    echoMode: TextInput.Password
                    font.family: menu.cc.body
                    font.pixelSize: 14
                    color: menu.pal.ink
                    onVisibleChanged: {
                        text = "";
                        if (visible)
                            forceActiveFocus();
                    }

                    // Picking another network while the field is open starts a fresh password
                    Connections {
                        target: menu.cc
                        function onAskSsidChanged() {
                            wifiPassword.text = "";
                            if (menu.cc.askSsid !== "")
                                wifiPassword.forceActiveFocus();
                        }
                    }
                    onAccepted: {
                        if (text.length > 0)
                            NetworkService.connectToWifi(menu.cc.askSsid, text);
                        menu.cc.askSsid = "";
                    }

                    Text {
                        visible: wifiPassword.text === ""
                        text: menu.cc.tx("Password for " + menu.cc.askSsid + ", then Enter")
                        font: wifiPassword.font
                        color: menu.pal.mut
                    }
                }
            }

            Note {
                leftPadding: 8
                text: {
                    const eth = NetworkService.networkStatus === "ethernet";
                    const parts = ["Connection " + (eth ? "Ethernet" : (NetworkService.currentWifiSSID || "none"))];
                    const ifc = eth ? NetworkService.ethernetInterface : NetworkService.wifiInterface;
                    const ip = eth ? NetworkService.ethernetIP : NetworkService.wifiIP;
                    if (ifc)
                        parts.push("interface " + ifc);
                    if (ip)
                        parts.push("IP " + ip);
                    return menu.cc.tx(parts.join(" · "));
                }
            }
        }
    }

    Component {
        id: btBody

        Column {
            spacing: 4

            Li {
                icon: BluetoothService.enabled ? "bluetooth" : "bluetooth_disabled"
                label: BluetoothService.enabled ? "Bluetooth on" : "Bluetooth off"
                note: BluetoothService.enabled ? "turn off" : "turn on"
                onClicked: {
                    if (BluetoothService.adapter)
                        BluetoothService.adapter.enabled = !BluetoothService.adapter.enabled;
                }
            }

            Cap {
                visible: BluetoothService.enabled
                leftPadding: 8
                text: "Paired"
            }

            Repeater {
                model: BluetoothService.enabled ? (BluetoothService.adapter?.devices?.values ?? []).filter(d => d && d.paired).sort((x, y) => (y.connected ? 1 : 0) - (x.connected ? 1 : 0)).slice(0, 8) : []

                Li {
                    required property var modelData
                    icon: BluetoothService.getDeviceIcon(modelData)
                    label: modelData.name || modelData.deviceName || "Unknown device"
                    note: modelData.connected ? ("connected" + (modelData.batteryAvailable ? " · " + Math.round(modelData.battery * 100) + "%" : "")) : (modelData.pairing ? "pairing…" : "paired")
                    current: modelData.connected
                    onClicked: {
                        if (modelData.connected)
                            modelData.disconnect();
                        else
                            BluetoothService.connectDeviceWithTrust(modelData);
                    }
                }
            }

            // Nearby devices not paired yet, listed only while searching (same filter as stock DMS).
            Repeater {
                model: BluetoothService.discovering ? BluetoothService.sortDevices((BluetoothService.adapter?.devices?.values ?? []).filter(d => d && !d.paired && !d.blocked && (d.signalStrength === undefined || d.signalStrength > 0))).slice(0, 8) : []

                Li {
                    required property var modelData
                    icon: BluetoothService.getDeviceIcon(modelData)
                    label: modelData.name || modelData.deviceName || modelData.address
                    note: modelData.pairing ? "pairing…" : "tap to pair"
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

            Li {
                visible: BluetoothService.enabled
                icon: BluetoothService.discovering ? "stop" : "search"
                label: BluetoothService.discovering ? "Searching for devices…" : "Search for new devices"
                note: BluetoothService.discovering ? "tap to stop" : ""
                onClicked: BluetoothService.adapter.discovering = !BluetoothService.discovering
            }
        }
    }

    Component {
        id: outBody

        Column {
            spacing: 4

            Li {
                icon: AudioService.sink?.audio?.muted ? "volume_off" : "volume_up"
                label: AudioService.sink?.audio?.muted ? "Muted" : "Sound on"
                note: AudioService.sink?.audio?.muted ? "unmute" : "mute"
                onClicked: AudioService.toggleMute()
            }

            Repeater {
                model: Pipewire.nodes.values.filter(node => node.audio && node.isSink && !node.isStream)

                Li {
                    required property var modelData
                    icon: "speaker"
                    label: AudioService.displayName(modelData)
                    note: modelData === AudioService.sink ? "in use" : ""
                    current: modelData === AudioService.sink
                    onClicked: Pipewire.preferredDefaultAudioSink = modelData
                }
            }
        }
    }

    Component {
        id: micBody

        Column {
            spacing: 4

            Li {
                icon: AudioService.source?.audio?.muted ? "mic_off" : "mic"
                label: AudioService.source?.audio?.muted ? "Microphone muted" : "Microphone on"
                note: AudioService.source?.audio?.muted ? "unmute" : "mute"
                onClicked: AudioService.toggleMicMute()
            }

            // Pick which one apps record from
            Repeater {
                model: Pipewire.nodes.values.filter(node => node.audio && !node.isSink && !node.isStream)

                Li {
                    required property var modelData
                    icon: "mic"
                    label: AudioService.displayName(modelData)
                    note: modelData === AudioService.source ? "in use" : ""
                    current: modelData === AudioService.source
                    onClicked: Pipewire.preferredDefaultAudioSource = modelData
                }
            }
        }
    }

    Component {
        id: batteryBody

        Column {
            id: batCol
            spacing: 8

            Row {
                visible: BatteryService.batteryAvailable
                width: parent.width
                spacing: 6

                Repeater {
                    model: [["Health", BatteryService.batteryHealth || "--"], ["Capacity", BatteryService.batteryCapacity > 0 ? BatteryService.batteryCapacity.toFixed(2) + " Wh" : "--"], [BatteryService.isCharging ? "Until full" : "Remaining", BatteryService.formatTimeRemaining() || BatteryService.formatPowerRate(true) || "--"]]

                    Kv {
                        required property var modelData
                        width: (batCol.width - 12) / 3
                        label: modelData[0]
                        value: String(modelData[1])
                    }
                }
            }

            Note {
                visible: !BatteryService.batteryAvailable
                text: menu.cc.tx("No battery: on mains power.")
            }

            Cap {
                visible: menu.withProfile && menu.bare
                text: "Strife · power profile"
            }

            Loader {
                active: menu.withProfile
                visible: active
                width: parent.width
                sourceComponent: profileBody
            }
        }
    }

    Component {
        id: profileBody

        Row {
            id: profiles
            spacing: menu.lay === "phainon" ? 0 : 4

            Repeater {
                model: [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]

                Step {
                    required property var modelData
                    width: (profiles.width - profiles.spacing * 2) / 3
                    text: menu.cc.profileName(modelData)
                    on: PowerProfiles.profile === modelData
                    usable: modelData !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile
                    onClicked: PowerProfiles.profile = modelData
                }
            }
        }
    }

    Component {
        id: hoursBody

        Column {
            id: hoursCol
            spacing: 6
            Component.onCompleted: Form.checkSunDay()

            Li {
                icon: "schedule"
                label: Form.schedule.enabled ? "Changing form by the hour" : "Change form by the hour"
                note: Form.schedule.enabled ? "turn off" : "turn on"
                current: Form.schedule.enabled
                // A double click (or a doubled touchpad tap) turned it on and straight back off.
                property real flippedAt: 0
                onClicked: {
                    if (Date.now() - flippedAt < 1500)
                        return;
                    flippedAt = Date.now();
                    Form.setScheduleEnabled(!Form.schedule.enabled);
                }
            }

            Cap {
                leftPadding: 8
                text: "Time · each form starts at"
            }

            Repeater {
                model: [["phainon", "Phainon"], ["khaslana", "Khaslana"], ["reaver", "Flame Reaver"]]

                Item {
                    id: hourRow
                    required property var modelData
                    // Set by the sun today, so the fixed time's steps are put away.
                    readonly property bool bySun: Form.schedule.sun && Form.sunTimes !== null && modelData[0] !== "reaver"
                    width: hoursCol.width
                    height: 30

                    Text {
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: menu.cc.tx(hourRow.modelData[1])
                        font.family: menu.cc.body
                        font.pixelSize: 14
                        font.weight: Form.lastScheduled === hourRow.modelData[0] && Form.schedule.enabled ? Font.DemiBold : Font.Normal
                        color: menu.pal.ink
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Repeater {
                            model: [["−1h", -60], ["−15", -15], ["", 0], ["+15", 15], ["+1h", 60]]

                            Step {
                                required property var modelData
                                visible: modelData[1] === 0 || !hourRow.bySun
                                width: modelData[1] === 0 ? 58 : 40
                                height: 24
                                text: modelData[1] === 0 ? Form.startOf(hourRow.modelData[0]) : modelData[0]
                                on: modelData[1] === 0
                                usable: true
                                onClicked: if (modelData[1] !== 0)
                                    Form.shiftStart(hourRow.modelData[0], modelData[1])
                            }
                        }
                    }
                }
            }

            // Follow the sun: Phainon at sunrise, Khaslana at sunset.
            Li {
                icon: "wb_twilight"
                label: "Follow the sun"
                note: Form.schedule.sun ? "on" : "off"
                current: Form.schedule.sun
                onClicked: Form.setSunEnabled(!Form.schedule.sun)
            }

            Note {
                leftPadding: 8
                text: menu.cc.tx((Form.sunTimes ? "Sunrise " + Form.sunTimes.sunrise + " · sunset " + Form.sunTimes.sunset : Form.sunPolar ? "No sunrise or sunset today: the set times are used" : "No location known: the set times are used") + ". A form you pick by hand stays until the next start time.")
            }
        }
    }

    Component {
        id: pluginsBody

        Column {
            id: plugCol
            spacing: 4

            Note {
                visible: menu.cc.plugins.length === 0
                leftPadding: 8
                text: menu.cc.tx("No plugins with a control.")
            }

            // Plugin tiles: a plugin that offers a control-centre tile toggles or opens its page.
            Repeater {
                model: menu.cc.plugins.filter(p => (p.item.ccWidgetPrimaryText ?? "") !== "")

                Li {
                    required property var modelData
                    readonly property var plugin: modelData.item
                    icon: plugin.ccWidgetIcon || "extension"
                    label: plugin.ccWidgetPrimaryText
                    note: (plugin.ccWidgetSecondaryText ?? "") + (plugin.ccDetailContent ? (menu.cc.openList === "plugin:" + modelData.id ? " ▴" : " ▾") : "")
                    current: plugin.ccWidgetIsActive ?? false
                    onClicked: {
                        if ((plugin.ccWidgetIsToggle ?? true) && !plugin.ccDetailContent)
                            plugin.ccWidgetToggled();
                        else
                            menu.cc.toggleList("plugin:" + modelData.id);
                    }
                }
            }

            // Plugins that only draw a bar widget have no bar to sit on here, so they live on
            // this shelf. Clicking one runs its own action or opens its panel below.
            Flow {
                width: parent.width
                spacing: 8

                Repeater {
                    model: menu.cc.plugins.filter(p => (p.item.ccWidgetPrimaryText ?? "") === "" && !!p.item.horizontalBarPill)

                    Rectangle {
                        id: shelfItem
                        required property var modelData
                        width: Math.max(40, pill.implicitWidth + 24)
                        height: 36
                        radius: menu.lay === "phainon" ? 18 : 0
                        color: menu.pal.li.a === 0 ? menu.pal.plate : menu.pal.li
                        border.width: 1
                        border.color: menu.pal.rim

                        Loader {
                            id: pill
                            anchors.centerIn: parent
                            sourceComponent: shelfItem.modelData.item.horizontalBarPill
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const p = shelfItem.modelData.item;
                                if (typeof p.pillClickAction === "function")
                                    p.pillClickAction();
                                else if (p.popoutContent)
                                    menu.cc.toggleList("plugin:" + shelfItem.modelData.id);
                            }
                        }
                    }
                }
            }

            // A plugin's own detail page
            Loader {
                readonly property string wanted: menu.cc.openList.startsWith("plugin:") ? menu.cc.openList.substring(7) : ""
                readonly property var plugin: menu.cc.plugins.find(p => p.id === wanted)?.item ?? null
                visible: wanted !== "" && !!plugin
                width: parent.width
                height: visible ? Math.max(120, plugin.ccDetailContent ? (plugin.ccDetailHeight ?? 250) : (plugin.popoutHeight || 300)) : 0
                sourceComponent: visible ? (plugin.ccDetailContent ?? plugin.popoutContent) : null
            }
        }
    }

    Component {
        id: appsBody

        Column {
            spacing: 4

            Note {
                visible: menu.cc.toplevels.length === 0
                leftPadding: 8
                text: menu.cc.tx("No windows open.")
            }

            // Click one to bring it forward.
            Repeater {
                model: menu.cc.toplevels

                Li {
                    required property var modelData
                    icon: "web_asset"
                    label: modelData?.title || modelData?.appId || ""
                    note: Paths.getAppName(modelData?.appId ?? "", DesktopEntries.heuristicLookup(modelData?.appId ?? ""))
                    current: !!modelData?.activated
                    onClicked: {
                        modelData?.activate();
                        menu.cc.close();
                    }
                }
            }
        }
    }
}
