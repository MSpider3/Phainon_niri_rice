import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Widgets
import qs.Modules.ProcessList
import "../../Common/Format.js" as Format

// Law: the stock DMS 2.0 system monitor (Processes, Performance, Disks, System, with the same
// views, search, filters, context menu and keys) in a Coreflame panel dropping out of the island.
// Keys as stock: 1-4 pick a tab, Ctrl+F searches, Esc closes; the process list keeps its own keys.
PanelWindow {
    id: mon

    required property var targetScreen
    property int strip: 40
    property bool shown: false
    property real reveal: shown ? 1 : 0

    property int currentTab: 0
    property string searchText: ""
    property string expandedPid: ""

    readonly property var tabs: ["Processes", "Performance", "Disks", "System"]
    readonly property real panelWidth: Math.min(860, width - 48)
    readonly property real fullHeight: Math.min(880, height - 48)

    function open() {
        if (NiriService.inOverview)
            NiriService.closeOverview();
        Coreflames.earn("law");
        shown = true;
        Qt.callLater(focusContent);
    }

    function close() {
        shown = false;
        contextMenu.dismiss();
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

    function focusContent() {
        if (currentTab === 0 && searchField.visible)
            searchField.forceActiveFocus();
        else
            scope.forceActiveFocus();
    }

    onCurrentTabChanged: {
        if (shown)
            focusContent();
    }

    onShownChanged: {
        if (shown)
            return;
        searchText = "";
        expandedPid = "";
        processesLoader.item?.reset();
    }

    // Header and footer readouts; each tab view holds its own modules while it is showing.
    // "gpu" as stock: the System tab's per-GPU temperature switch needs it (polls only once switched on).
    Ref {
        service: DgopService
        modules: ["cpu", "memory", "network", "disk", "system", "gpu"]
        active: mon.shown
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

        // Grows out of the island: from its width and strip height to the full panel.
        x: Math.round((mon.width - width) / 2)
        width: Math.round(420 + (mon.panelWidth - 420) * mon.reveal)
        height: Math.round(mon.strip + (mon.fullHeight - mon.strip) * mon.reveal)
        clip: true

        CfTab {
            id: plate
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
            onClicked: contextMenu.dismiss()
        }

        // Title
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            height: mon.strip
            spacing: 8

            CfGlyph {
                anchors.verticalCenter: parent.verticalCenter
                name: Form.reaver ? "mask" : "law"
                size: Form.reaver ? 15 : 18
                strokeWidth: Form.reaver ? 1.6 : 1.9
                color: Form.reaver ? Theme.live : Theme.primary
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

        FocusScope {
            id: scope

            x: 18
            y: mon.strip + 4
            width: mon.panelWidth - 36
            // Stays above the Flame Reaver's torn hem.
            height: mon.fullHeight - y - plate.hem - 8
            opacity: mon.reveal
            focus: true

            Keys.onPressed: event => {
                if (contextMenu.visible || contextMenu.confirmationOpen)
                    return;
                switch (event.key) {
                case Qt.Key_1:
                case Qt.Key_2:
                case Qt.Key_3:
                case Qt.Key_4:
                    if (searchField.getActiveFocus())
                        return;
                    mon.currentTab = event.key - Qt.Key_1;
                    event.accepted = true;
                    return;
                case Qt.Key_Escape:
                    mon.close();
                    event.accepted = true;
                    return;
                case Qt.Key_F:
                    if (event.modifiers & Qt.ControlModifier) {
                        mon.currentTab = 0;
                        searchField.forceActiveFocus();
                        event.accepted = true;
                        return;
                    }
                    break;
                }
                if (mon.currentTab === 0 && processesLoader.item)
                    processesLoader.item.handleKey(event);
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: Theme.spacingS
                visible: DgopService.dgopAvailable

                ProcessTabs {
                    Layout.fillWidth: true
                    // Clear of Khaslana's corner blocks and Phainon's wing.
                    Layout.leftMargin: 24
                    Layout.rightMargin: 24
                    tabs: mon.tabs
                    current: mon.currentTab
                    onPicked: index => mon.currentTab = index
                }

                ProcessSystemHeader {
                    Layout.fillWidth: true
                    visible: mon.currentTab === 0
                }

                ProcessSummary {
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    visible: mon.currentTab === 0
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingM
                    visible: mon.currentTab === 0

                    DSearchField {
                        id: searchField
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.buttonHeightS
                        placeholderText: mon.tx("Search processes...")
                        text: mon.searchText
                        onTextChanged: mon.searchText = text
                        ignoreUpDownKeys: true
                        keyForwardTargets: [scope]
                    }

                    ProcessFilterChips {
                        Layout.preferredWidth: singleRowWidth
                    }
                }

                Item {
                    id: views
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    Loader {
                        id: processesLoader
                        anchors.fill: parent
                        active: mon.visible
                        visible: mon.currentTab === 0
                        sourceComponent: ProcessesView {
                            active: mon.shown && mon.currentTab === 0
                            searchText: mon.searchText
                            expandedPid: mon.expandedPid
                            contextMenu: contextMenu
                            onExpandedPidChanged: mon.expandedPid = expandedPid
                        }
                    }

                    Loader {
                        anchors.fill: parent
                        active: mon.visible
                        visible: mon.currentTab === 1
                        sourceComponent: PerformanceView {}
                    }

                    Loader {
                        anchors.fill: parent
                        active: mon.visible
                        visible: mon.currentTab === 2
                        sourceComponent: DisksView {}
                    }

                    Loader {
                        anchors.fill: parent
                        active: mon.visible
                        visible: mon.currentTab === 3
                        sourceComponent: SystemView {}
                    }
                }

                // Stock footer readouts: network, disk, CPU, memory.
                StyledText {
                    Layout.alignment: Qt.AlignRight
                    text: "↓" + Format.formatRate(DgopService.networkRxRate) + " ↑" + Format.formatRate(DgopService.networkTxRate) + "   " + mon.tx("disk") + " ↓" + Format.formatRate(DgopService.diskReadRate) + " ↑" + Format.formatRate(DgopService.diskWriteRate) + "   " + mon.tx("CPU") + " " + DgopService.cpuUsage.toFixed(1) + "%   " + DgopService.formatSystemMemory(DgopService.usedMemoryKB) + " / " + DgopService.formatSystemMemory(DgopService.totalMemoryKB)
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.monoFontFamily
                    color: Theme.surfaceVariantText
                }
            }

            StyledText {
                anchors.centerIn: parent
                visible: !DgopService.dgopAvailable
                text: mon.tx("The system monitor needs the DMS service (dgop), which is not running.")
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.error
            }
        }

        ProcessContextMenu {
            id: contextMenu
            parentFocusItem: scope
            // Stock fills it with the user's foreground-layer alpha (0.18 here); over the rows that is unreadable.
            Component.onCompleted: contentItem.color = Qt.binding(() => Theme.surfaceContainer)
        }
    }
}
