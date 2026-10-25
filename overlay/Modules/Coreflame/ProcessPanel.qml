import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

// Law: the system monitor, dropping out of the island. Load meters on top, then the busiest
// processes. Tab switches between sorting by CPU and by memory. Right-click a process for its
// menu (details, copy, end, force kill); Delete twice ends the selected one from the keyboard.
PanelWindow {
    id: mon

    required property var targetScreen
    property int strip: 40
    property bool shown: false
    property real reveal: shown ? 1 : 0
    // The selection follows the process, not the row: the list re-sorts on every refresh.
    property int selectedPid: -1
    readonly property int selected: processes.findIndex(p => p.pid === selectedPid)

    // The list is empty for a moment after opening, and a selected process can exit:
    // fall back to the first row then.
    onProcessesChanged: {
        if (shown && selected < 0)
            select(0);
    }

    function select(index) {
        const proc = processes[Math.max(0, Math.min(processes.length - 1, index))];
        if (proc)
            selectedPid = proc.pid;
    }
    property int armed: -1
    // Right-click menu and details card: the process they are about, and where the menu opens.
    property var menuFor: null
    property real menuX: 0
    property real menuY: 0
    property var infoFor: null

    readonly property var modules: ["processes", "cpu", "memory", "system"]
    readonly property var processes: (DgopService.processes ?? []).slice(0, 14)
    readonly property real panelWidth: 700
    readonly property real rowHeight: Form.reaver ? 30 : 34

    function open() {
        if (NiriService.inOverview)
            NiriService.closeOverview();
        Coreflames.earn("law");
        select(0);
        armed = -1;
        shown = true;
        keys.forceActiveFocus();
    }

    function close() {
        shown = false;
        armed = -1;
        menuFor = null;
        infoFor = null;
    }

    function send(proc, name) {
        if (proc)
            Quickshell.execDetached(["kill", "-" + name, String(proc.pid)]);
    }

    function copy(text) {
        Quickshell.execDetached(["dms", "cl", "copy", String(text)]);
    }

    function memory(kb) {
        return kb >= 1048576 ? (kb / 1048576).toFixed(1) + " GB" : Math.round(kb / 1024) + " MB";
    }

    function toggle() {
        if (shown)
            close();
        else
            open();
    }

    function tx(text) {
        return Form.reaver ? String(text).toLowerCase() : text;
    }

    function end(index) {
        const proc = processes[index];
        if (!proc)
            return;
        if (armed !== proc.pid) {
            armed = proc.pid;
            return;
        }
        armed = -1;
        Quickshell.execDetached(["kill", String(proc.pid)]);
    }

    // Destroyed while open (a screen unplugged, another theme picked): release what opening took.
    Component.onDestruction: {
        if (shown)
            shown = false;
    }

    onShownChanged: {
        if (shown)
            DgopService.addRef(modules);
        else
            DgopService.removeRef(modules);
    }

    screen: targetScreen
    visible: reveal > 0.001
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "coreflame:monitor"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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

    Rectangle {
        anchors.fill: parent
        color: Theme.withAlpha(Theme.background, 0.35 * mon.reveal)

        MouseArea {
            anchors.fill: parent
            onClicked: mon.close()
        }
    }

    Item {
        id: panel

        readonly property real listTop: mon.strip + 124
        readonly property real fullHeight: listTop + Math.max(1, mon.processes.length) * mon.rowHeight + 48

        x: Math.round((mon.width - width) / 2)
        width: Math.round(420 + (mon.panelWidth - 420) * mon.reveal)
        height: Math.round(mon.strip + (fullHeight - mon.strip) * mon.reveal)
        clip: true

        CfTab {
            anchors.fill: parent
            side: "center"
        }

        CfOrnament {
            id: ornament
            anchors.fill: parent
        }

        Connections {
            target: mon

            function onShownChanged() {
                if (mon.shown)
                    ornament.play();
            }
        }

        MouseArea {
            anchors.fill: parent
        }

        Item {
            id: keys
            anchors.fill: parent
            focus: true

            Keys.onEscapePressed: {
                if (mon.menuFor)
                    mon.menuFor = null;
                else if (mon.infoFor)
                    mon.infoFor = null;
                else
                    mon.close();
            }
            Keys.onDownPressed: {
                mon.select(mon.selected + 1);
                mon.armed = -1;
            }
            Keys.onUpPressed: {
                mon.select(mon.selected - 1);
                mon.armed = -1;
            }
            Keys.onTabPressed: DgopService.setSortBy(DgopService.currentSort === "cpu" ? "memory" : "cpu")
            Keys.onDeletePressed: mon.end(mon.selected)
        }

        // Title
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            height: mon.strip
            spacing: 8

            CfGlyph {
                anchors.verticalCenter: parent.verticalCenter
                name: "law"
                size: 18
                strokeWidth: 1.9
                color: Theme.primary
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: mon.tx("Law · System")
                font.family: Form.display(Theme.fontFamily)
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.DemiBold
                color: Theme.surfaceText
            }
        }

        // Load
        Column {
            x: 22
            y: mon.strip + 8
            width: mon.panelWidth - 44
            spacing: 8
            opacity: mon.reveal

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
                    spacing: 10

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 64
                        text: mon.tx(modelData.name)
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.withAlpha(Theme.surfaceText, 0.65)
                    }

                    CfBlade {
                        anchors.verticalCenter: parent.verticalCenter
                        meter: true
                        width: parent.width - 64 - 50 - 20
                        value: modelData.value
                        tone: modelData.alarm ? Theme.error : Theme.primary
                        tide: modelData.name === "Memory"
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 50
                        horizontalAlignment: Text.AlignRight
                        text: modelData.text
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Bold
                        color: modelData.alarm ? Theme.error : Theme.surfaceText
                    }
                }
            }
        }

        // Column heads; clicking one sorts by it
        Item {
            x: 22
            y: panel.listTop - 24
            width: mon.panelWidth - 44
            height: 20
            opacity: mon.reveal

            // Over the name column (list x 14 + name x 76, less this row's x 22)
            StyledText {
                x: 68
                text: mon.tx("PROCESS")
                font.pixelSize: 10
                font.letterSpacing: 1.3
                color: Theme.withAlpha(Theme.surfaceText, 0.5)
            }

            Row {
                anchors.right: parent.right
                spacing: 0

                Repeater {
                    model: ["cpu", "memory"]

                    StyledText {
                        required property string modelData
                        width: 80
                        horizontalAlignment: Text.AlignRight
                        text: (DgopService.currentSort === modelData ? "▾ " : "") + mon.tx(modelData === "cpu" ? "CPU" : "MEMORY")
                        font.pixelSize: 10
                        font.letterSpacing: 1.3
                        color: DgopService.currentSort === modelData ? Theme.primary : Theme.withAlpha(Theme.surfaceText, 0.5)

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: DgopService.setSortBy(modelData)
                        }
                    }
                }
            }
        }

        Column {
            x: 14
            y: panel.listTop
            width: mon.panelWidth - 28
            opacity: mon.reveal

            Repeater {
                model: mon.processes

                Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool current: mon.selected === index
                    readonly property bool armed: mon.armed === modelData.pid
                    width: parent.width
                    height: mon.rowHeight

                    CfSurface {
                        anchors.fill: parent
                        anchors.margins: 1
                        visible: row.current
                        color: row.armed ? Theme.error : Theme.primary
                        edgeWidth: 0
                        radius: 14
                        cut: 6
                    }

                    Text {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 60
                        text: row.modelData.pid
                        font.family: Theme.monoFontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: row.current ? Theme.withAlpha(Theme.primaryText, 0.75) : Theme.withAlpha(Theme.surfaceText, 0.4)
                    }

                    StyledText {
                        x: 76
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 76 - 176
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                        maximumLineCount: 1
                        text: row.armed ? mon.tx("Press Delete again to end " + (row.modelData.command ?? "")) : mon.tx(row.modelData.command ?? "")
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: row.current ? Font.Bold : Font.Medium
                        color: row.current ? Theme.primaryText : Theme.surfaceText
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter

                        Repeater {
                            model: [(row.modelData.cpu ?? 0).toFixed(1) + "%", (row.modelData.memoryPercent ?? 0).toFixed(1) + "%"]

                            Text {
                                required property string modelData
                                width: 80
                                horizontalAlignment: Text.AlignRight
                                text: modelData
                                font.family: Theme.monoFontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                color: row.current ? Theme.primaryText : Theme.withAlpha(Theme.surfaceText, 0.8)
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onPositionChanged: {
                            if (mon.selected !== row.index) {
                                mon.selectedPid = row.modelData.pid;
                                mon.armed = -1;
                            }
                        }
                        onClicked: mouse => {
                            mon.selectedPid = row.modelData.pid;
                            mon.armed = -1;
                            if (mouse.button === Qt.RightButton) {
                                const at = mapToItem(panel, mouse.x, mouse.y);
                                mon.menuX = Math.min(at.x, panel.width - 236);
                                mon.menuY = Math.min(at.y, panel.height - 200);
                                mon.menuFor = row.modelData;
                            } else {
                                mon.menuFor = null;
                            }
                            keys.forceActiveFocus();
                        }
                    }
                }
            }
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Form.reaver ? 18 : 14
            text: mon.tx("↑↓ select   Tab sort   Right-click for the menu   Delete twice ends a process   Esc close")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.withAlpha(Theme.surfaceText, 0.45)
        }

        // Details card
        Item {
            id: info
            visible: mon.infoFor !== null
            anchors.centerIn: parent
            width: 460
            height: infoColumn.implicitHeight + 28

            MouseArea {
                anchors.fill: parent
            }

            CfSurface {
                anchors.fill: parent
                color: Theme.surfaceContainerHighest
                edgeColor: Theme.primary
                edgeWidth: 1
                radius: 16
            }

            Column {
                id: infoColumn
                x: 16
                y: 14
                width: parent.width - 32
                spacing: 6

                StyledText {
                    width: parent.width
                    elide: Text.ElideRight
                    text: mon.tx(mon.infoFor?.command ?? "")
                    font.family: Form.display(Theme.fontFamily)
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.DemiBold
                    color: Theme.surfaceText
                }

                Repeater {
                    model: mon.infoFor ? [["PID", mon.infoFor.pid], ["Parent PID", mon.infoFor.ppid || "-"], ["User", mon.infoFor.username || "-"], ["CPU", (mon.infoFor.cpu ?? 0).toFixed(1) + "%"], ["Memory", mon.memory(mon.infoFor.memoryKB ?? 0) + "  (" + (mon.infoFor.memoryPercent ?? 0).toFixed(1) + "%)"]] : []

                    Item {
                        required property var modelData
                        width: infoColumn.width
                        height: 20

                        StyledText {
                            text: mon.tx(modelData[0])
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.withAlpha(Theme.surfaceText, 0.6)
                        }

                        Text {
                            anchors.right: parent.right
                            text: modelData[1]
                            font.family: Theme.monoFontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                        }
                    }
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WrapAnywhere
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    text: mon.infoFor?.fullCommand || mon.infoFor?.command || ""
                    font.family: Theme.monoFontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.withAlpha(Theme.surfaceText, 0.75)
                }

                StyledText {
                    anchors.right: parent.right
                    text: mon.tx("Close")
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Bold
                    color: Theme.primary

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mon.infoFor = null
                    }
                }
            }
        }

        // Right-click menu
        MouseArea {
            anchors.fill: parent
            visible: mon.menuFor !== null
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mon.menuFor = null
        }

        Item {
            visible: mon.menuFor !== null
            x: mon.menuX
            y: mon.menuY
            width: 228
            height: menuColumn.implicitHeight + 12

            CfSurface {
                anchors.fill: parent
                color: Theme.surfaceContainerHighest
                edgeColor: Theme.withAlpha(Theme.outline, 0.9)
                edgeWidth: 1
                radius: 12
                cut: 8
            }

            Column {
                id: menuColumn
                x: 6
                y: 6
                width: parent.width - 12

                Repeater {
                    model: [
                        {
                            "id": "info",
                            "icon": "info",
                            "label": "View details"
                        },
                        {
                            "id": "pid",
                            "icon": "content_copy",
                            "label": "Copy PID"
                        },
                        {
                            "id": "command",
                            "icon": "terminal",
                            "label": "Copy command"
                        },
                        {
                            "id": "stop",
                            "icon": "pause",
                            "label": "Pause (stop)"
                        },
                        {
                            "id": "cont",
                            "icon": "play_arrow",
                            "label": "Resume"
                        },
                        {
                            "id": "term",
                            "icon": "close",
                            "label": "End process"
                        },
                        {
                            "id": "kill",
                            "icon": "dangerous",
                            "label": "Force kill"
                        }
                    ]

                    Item {
                        id: entry
                        required property var modelData
                        readonly property bool danger: modelData.id === "term" || modelData.id === "kill"
                        width: menuColumn.width
                        height: 30

                        Rectangle {
                            anchors.fill: parent
                            visible: entryMouse.containsMouse
                            color: Theme.withAlpha(entry.danger ? Theme.error : Theme.primary, 0.22)
                        }

                        DankIcon {
                            visible: !Form.reaver
                            x: 8
                            anchors.verticalCenter: parent.verticalCenter
                            name: entry.modelData.icon
                            size: 16
                            color: entry.danger ? Theme.error : Theme.primary
                        }

                        StyledText {
                            x: Form.reaver ? 10 : 32
                            anchors.verticalCenter: parent.verticalCenter
                            text: mon.tx(entry.modelData.label)
                            font.pixelSize: Theme.fontSizeMedium
                            color: entry.danger ? Theme.error : Theme.surfaceText
                        }

                        MouseArea {
                            id: entryMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const proc = mon.menuFor;
                                mon.menuFor = null;
                                switch (entry.modelData.id) {
                                case "info":
                                    mon.infoFor = proc;
                                    break;
                                case "pid":
                                    mon.copy(proc.pid);
                                    break;
                                case "command":
                                    mon.copy(proc.fullCommand || proc.command);
                                    break;
                                case "stop":
                                    mon.send(proc, "STOP");
                                    break;
                                case "cont":
                                    mon.send(proc, "CONT");
                                    break;
                                case "term":
                                    mon.send(proc, "TERM");
                                    break;
                                case "kill":
                                    mon.send(proc, "KILL");
                                    break;
                                }
                                keys.forceActiveFocus();
                            }
                        }
                    }
                }
            }
        }
    }
}
