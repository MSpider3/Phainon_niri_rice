import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.DCommon.Common as DC
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
    property real opening: shown ? 1 : 0
    readonly property real reveal: Motion.step(opening)

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

    // Coreflame: the search field per form (the v3 mockup): a cream capsule, a square plate in gold,
    // a dark slip in violet
    readonly property var field: Form.phainon ? ({
            "bg": "#FBF9F3",
            "edge": "#DCCDA6",
            "focus": "#A87A22",
            "ink": "#1E2752",
            "hint": "#4A5484",
            "icon": "#A87A22"
        }) : Form.khaslana ? ({
            "bg": "#0B080B",
            "edge": "#8A5A2B",
            "focus": "#F2C75C",
            "ink": "#F5D27A",
            "hint": "#C9B89E",
            "icon": "#E0B04A"
        }) : ({
            "bg": "#1C1828",
            "edge": "transparent",
            "focus": "#8F7BE0",
            "ink": "#B9A8FF",
            "hint": "#A8A4BC",
            "icon": "#B9A8FF"
        })

    readonly property string cpuDetail: DgopService.cpuCores + (DgopService.cpuFrequency > 0 ? " × " + (DgopService.cpuFrequency / 1000).toFixed(1) + " GHz" : " cores")
    readonly property string memoryDetail: DgopService.formatSystemMemory(DgopService.usedMemoryKB) + " / " + DgopService.formatSystemMemory(DgopService.totalMemoryKB)

    // Coreflame: CPU or Memory as the v3 mockup draws it, in place of the stock header and cards:
    // Phainon a cream card with a navy share line, Khaslana a dark block with its value in bold gold,
    // the Flame Reaver a row of ten skewed violet blocks.
    component Meter: Rectangle {
        id: meter

        property string label
        property real share
        property string percent
        property string detail
        property string khText
        property string rvText

        Layout.fillWidth: true
        implicitHeight: Form.phainon ? 60 : (Form.khaslana ? 46 : 22)
        radius: Form.phainon ? 12 : 0
        color: Form.phainon ? "#FBF9F3" : (Form.khaslana ? "#160D10" : "transparent")
        border.width: Form.phainon ? 1 : 0
        border.color: "#DCCDA6"

        Column {
            visible: Form.phainon
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.topMargin: 10
            spacing: 4

            StyledText {
                text: meter.label.toUpperCase()
                font.family: "Chakra Petch"
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.letterSpacing: 1.8
                color: "#8A6418"
            }

            RowLayout {
                width: parent.width
                spacing: 10

                StyledText {
                    Layout.preferredWidth: 44
                    text: meter.percent
                    font.pixelSize: 14
                    color: "#1E2752"
                }

                ShareBar {
                    Layout.fillWidth: true
                    share: meter.share
                }

                StyledText {
                    Layout.preferredWidth: 120
                    text: meter.detail
                    font.pixelSize: 14
                    color: "#4A5484"
                    elide: Text.ElideRight
                }
            }
        }

        Column {
            visible: Form.khaslana
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.topMargin: 6
            spacing: 2

            StyledText {
                text: meter.label
                font.pixelSize: 13
                color: "#F3E6CC"
            }

            StyledText {
                width: parent.width
                text: meter.khText
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: "#F5D27A"
                elide: Text.ElideRight
            }
        }

        RowLayout {
            visible: Form.reaver
            anchors.fill: parent
            spacing: 10

            StyledText {
                Layout.preferredWidth: 70
                text: meter.label.toLowerCase()
                font.pixelSize: 14
                color: "#E9E7F2"
            }

            ShareBar {
                Layout.fillWidth: true
                share: meter.share
            }

            StyledText {
                Layout.preferredWidth: 140
                text: meter.rvText.toLowerCase()
                font.pixelSize: 14
                color: "#A8A4BC"
                elide: Text.ElideRight
            }
        }
    }

    function focusContent() {
        if (currentTab === 0 && searchField.visible)
            searchField.forceActiveFocus();
        else {
            // Else the scope hands focus straight back to the hidden field, which then eats the 1-4 keys
            searchField.setFocus(false);
            scope.forceActiveFocus();
        }
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

    Behavior on opening {
        NumberAnimation {
            duration: Motion.openMs
            easing.type: Motion.openEasing
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

        // Grows out of the island: from its width to the full panel.
        x: Math.round((mon.width - width) / 2)
        y: sheet.topFor(mon.strip)
        width: Math.round(420 + (mon.panelWidth - 420) * mon.reveal)
        height: Math.round(60 + (mon.fullHeight - 60) * mon.reveal)

        MouseArea {
            anchors.fill: parent
            onClicked: contextMenu.dismiss()
        }

        // Khaslana: the red block tide hanging under the plate
        CfTide {
            visible: Form.khaslana
            y: parent.height + 8
            width: parent.width
            height: 150
            opacity: mon.reveal
            seed: 34
            liquid: 0
            cubes: Form.khaslana ? 22 : 0
        }

        // Khaslana: a run of golden blood breaking out from under the plate's left edge
        CfSliver {
            visible: Form.khaslana
            x: -75
            y: Math.round(parent.height * 0.58)
            width: 110
            height: 55
            opacity: mon.reveal
        }

        CfSheet {
            id: sheet
            anchors.fill: parent
            // Only while it opens: at rest Khaslana's red offset hangs outside the plate
            clip: mon.reveal < 1
            title: "Law · System"
            glyph: "law"
            count: mon.tx("↓ " + Format.formatRate(DgopService.networkRxRate) + "  ↑ " + Format.formatRate(DgopService.networkTxRate))

            FocusScope {
                id: scope

                anchors.fill: parent
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
                        tabs: mon.tabs
                        current: mon.currentTab
                        onPicked: index => mon.currentTab = index
                    }

                    ProcessSystemHeader {
                        Layout.fillWidth: true
                        visible: mon.currentTab === 0 && !Form.active
                    }

                    ProcessSummary {
                        Layout.fillWidth: true
                        Layout.fillHeight: false
                        visible: mon.currentTab === 0 && !Form.active
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        visible: mon.currentTab === 0 && Form.active
                        columns: Form.reaver ? 1 : 2
                        columnSpacing: Form.khaslana ? 6 : 12
                        rowSpacing: 6

                        Meter {
                            label: I18n.tr("CPU", "processor label in system monitor")
                            share: DgopService.cpuUsage / 100
                            percent: DgopService.cpuUsage.toFixed(0) + "%"
                            detail: mon.cpuDetail
                            khText: percent + " · " + mon.cpuDetail
                            rvText: percent + " · " + DgopService.cpuCores + " cores"
                        }

                        Meter {
                            label: I18n.tr("Memory")
                            share: DgopService.memoryUsage / 100
                            percent: DgopService.memoryUsage.toFixed(0) + "%"
                            detail: mon.memoryDetail
                            khText: mon.memoryDetail
                            rvText: mon.memoryDetail
                        }
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
                            // Coreflame: per form from mon.field; otherwise the stock DSearchField values
                            cornerRadius: !Form.active ? DC.Style.fullRadius(width, height) : (Form.phainon ? height / 2 : 0)
                            backgroundColor: Form.active ? mon.field.bg : DC.Style.chipSurface
                            normalBorderColor: Form.active ? mon.field.edge : DC.Style.outlineVariant
                            focusedBorderColor: Form.active ? mon.field.focus : (DC.Style.focusRingWidth > 0 ? DC.Style.focusRingColor : searchField.normalBorderColor)
                            borderWidth: Form.active ? 1 : DC.Style.outlineWidth
                            textColor: Form.active ? mon.field.ink : DC.Style.surfaceText
                            placeholderColor: Form.active ? mon.field.hint : DC.Style.surfaceTextSecondary
                            leftIconColor: Form.active ? mon.field.icon : DC.Style.onSurfaceVariant
                            leftIconFocusedColor: Form.active ? mon.field.icon : DC.Style.primary
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
                        text: mon.tx("disk") + " ↓" + Format.formatRate(DgopService.diskReadRate) + " ↑" + Format.formatRate(DgopService.diskWriteRate) + "   " + mon.tx("CPU") + " " + DgopService.cpuUsage.toFixed(1) + "%   " + DgopService.formatSystemMemory(DgopService.usedMemoryKB) + " / " + DgopService.formatSystemMemory(DgopService.totalMemoryKB)
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
        }

        ProcessContextMenu {
            id: contextMenu
            parentFocusItem: scope
            // Stock fills it with the user's foreground-layer alpha (0.18 here); over the rows that is unreadable.
            Component.onCompleted: contentItem.color = Qt.binding(() => Theme.surfaceContainer)
        }
    }
}
