import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.DCommon.Widgets

DCard {
    id: root

    pad: Theme.spacingS
    restRadius: Theme.cornerRadiusL

    property string searchText: ""
    property string expandedPid: ""
    property var contextMenu: null
    readonly property var processFilterTypes: CacheData.processFilterTypes
    readonly property real rowHeight: ProcessListMetrics.rowHeight
    property bool active: visible
    readonly property alias listView: processListView
    readonly property alias sortChips: sortChips

    // Coreflame: each process's CPU share under its number, one look per form (the v3 mockup):
    // Phainon a navy line on cream, Khaslana ten red blocks capped in gold, the Flame Reaver ten
    // skewed violet blocks. Nothing outside a Coreflame form.
    component ShareBar: Item {
        id: bar
        property real share: 0
        readonly property real clamped: Math.max(0, Math.min(1, share))
        readonly property int lit: Math.round(clamped * 10)

        visible: Form.active
        height: Form.phainon ? 6 : (Form.khaslana ? 10 : 9)

        Rectangle {
            visible: Form.phainon
            anchors.fill: parent
            radius: 3
            color: "#E4DAC0"

            Rectangle {
                width: parent.width * bar.clamped
                height: parent.height
                radius: 3
                color: "#334786"
            }
        }

        Row {
            id: blocks
            visible: !Form.phainon
            anchors.fill: parent
            spacing: Form.khaslana ? 2 : 3

            Repeater {
                model: bar.visible && !Form.phainon ? 10 : 0

                Rectangle {
                    required property int index
                    width: (bar.width - 9 * blocks.spacing) / 10
                    height: bar.height
                    color: Form.khaslana ? (index < bar.lit - 1 ? "#C2252F" : (index === bar.lit - 1 ? "#F2C75C" : "#2A1015")) : (index < bar.lit ? "#8F7BE0" : "#2C2840")
                    // skewX(-20deg) about the middle
                    transform: Matrix4x4 {
                        matrix: Form.reaver ? Qt.matrix4x4(1, -0.364, 0, 0.182 * bar.height, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) : Qt.matrix4x4()
                    }
                }
            }
        }
    }
    onSelectedIndexChanged: {
        if (keyboardNavigationActive)
            selectionScroll.schedule();
    }
    onActiveChanged: {
        if (active)
            updateProcesses();
    }
    onSearchTextChanged: refreshFilter()

    // A search has to see every process, see DgopService.requestFullProcessList
    readonly property bool needsFullProcessList: active && searchText.length > 0
    property bool holdsFullProcessList: false
    onNeedsFullProcessListChanged: {
        if (needsFullProcessList === holdsFullProcessList)
            return;
        holdsFullProcessList = needsFullProcessList;
        if (needsFullProcessList)
            DgopService.requestFullProcessList();
        else
            DgopService.releaseFullProcessList();
    }
    Component.onDestruction: {
        if (holdsFullProcessList)
            DgopService.releaseFullProcessList();
    }
    onProcessFilterTypesChanged: refreshFilter()

    property int selectedIndex: -1
    property bool keyboardNavigationActive: false
    property int forceRefreshCount: 0

    readonly property bool pauseUpdates: (contextMenu?.visible ?? false) || (contextMenu?.confirmationOpen ?? false) || expandedPid.length > 0
    readonly property bool shouldUpdate: !pauseUpdates || forceRefreshCount > 0
    property var cachedProcesses: []

    onFilteredProcessesChanged: {
        if (!shouldUpdate)
            return;
        updateProcesses();
        if (forceRefreshCount > 0)
            forceRefreshCount--;
    }

    onShouldUpdateChanged: {
        if (shouldUpdate)
            updateProcesses();
    }

    readonly property var filteredProcesses: {
        if (!DgopService.allProcesses || DgopService.allProcesses.length === 0)
            return [];

        let procs = DgopService.allProcesses.slice();

        procs = procs.filter(p => processFilterTypes.includes(p.username === UserInfoService.username ? "user" : "system"));

        if (searchText.length > 0) {
            const search = searchText.toLowerCase();
            procs = procs.filter(p => {
                const cmd = (p.command || "").toLowerCase();
                const fullCmd = (p.fullCommand || "").toLowerCase();
                const pid = p.pid.toString();
                return cmd.includes(search) || fullCmd.includes(search) || pid.includes(search);
            });
        }

        procs.sort(DgopService.compareProcesses);

        return procs;
    }

    DeferredAction {
        id: selectionScroll
        onTriggered: {
            root.ensureVisible();
            if (processListView.activeFocus)
                processListView.currentItem?.forceActiveFocus(Qt.TabFocusReason);
        }
    }

    function refreshFilter() {
        expandedPid = "";
        updateProcesses();
    }

    function updateProcesses() {
        if (!active || DgopService.allProcesses.length === 0)
            return;
        const pid = cachedProcesses[selectedIndex]?.pid;
        cachedProcesses = filteredProcesses;
        selectedIndex = pid === undefined ? -1 : cachedProcesses.findIndex(p => p.pid === pid);
        if (selectedIndex < 0 && keyboardNavigationActive && cachedProcesses.length > 0)
            selectedIndex = 0;
    }

    function requestKill(index) {
        const process = cachedProcesses[index];
        if (!process || !contextMenu)
            return;
        selectedIndex = index;
        keyboardNavigationActive = true;
        contextMenu.parentFocusItem = processListView;
        contextMenu.processData = process;
        contextMenu.killProcess();
    }

    function selectNext() {
        if (cachedProcesses.length === 0)
            return;
        keyboardNavigationActive = true;
        selectedIndex = Math.min(selectedIndex + 1, cachedProcesses.length - 1);
        ensureVisible();
    }

    function selectPrevious() {
        if (cachedProcesses.length === 0)
            return;
        keyboardNavigationActive = true;
        if (selectedIndex <= 0) {
            selectedIndex = -1;
            keyboardNavigationActive = false;
            return;
        }
        selectedIndex = selectedIndex - 1;
        ensureVisible();
    }

    function selectFirst() {
        if (cachedProcesses.length === 0)
            return;
        keyboardNavigationActive = true;
        selectedIndex = 0;
        ensureVisible();
    }

    function selectLast() {
        if (cachedProcesses.length === 0)
            return;
        keyboardNavigationActive = true;
        selectedIndex = cachedProcesses.length - 1;
        ensureVisible();
    }

    function toggleExpand() {
        if (selectedIndex < 0 || selectedIndex >= cachedProcesses.length)
            return;
        const process = cachedProcesses[selectedIndex];
        const pidStr = (process?.pid ?? -1).toString();
        expandedPid = (expandedPid === pidStr) ? "" : pidStr;
    }

    function openContextMenu() {
        if (selectedIndex < 0 || selectedIndex >= cachedProcesses.length)
            return;
        const delegate = processListView.itemAtIndex(selectedIndex);
        if (!delegate)
            return;
        const process = cachedProcesses[selectedIndex];
        if (!process || !contextMenu)
            return;
        contextMenu.processData = process;
        const itemPos = delegate.mapToItem(contextMenu.parent, delegate.width / 2, delegate.height / 2);
        contextMenu.parentFocusItem = processListView;
        contextMenu.show(itemPos.x, itemPos.y, true);
    }

    function reset() {
        selectedIndex = -1;
        keyboardNavigationActive = false;
        expandedPid = "";
    }

    function forceRefresh(count) {
        forceRefreshCount = count || 3;
    }

    function ensureVisible() {
        if (selectedIndex < 0)
            return;
        processListView.revealIndex(selectedIndex);
    }

    function handleKey(event) {
        switch (event.key) {
        case Qt.Key_Down:
            selectNext();
            event.accepted = true;
            return;
        case Qt.Key_Up:
            selectPrevious();
            event.accepted = true;
            return;
        case Qt.Key_J:
            if (event.modifiers & Qt.ControlModifier) {
                selectNext();
                event.accepted = true;
            }
            return;
        case Qt.Key_K:
            if (event.modifiers & Qt.ControlModifier) {
                requestKill(selectedIndex);
                event.accepted = true;
            }
            return;
        case Qt.Key_Delete:
            if (!keyboardNavigationActive)
                return;
            requestKill(selectedIndex);
            event.accepted = true;
            return;
        case Qt.Key_Home:
            selectFirst();
            event.accepted = true;
            return;
        case Qt.Key_End:
            selectLast();
            event.accepted = true;
            return;
        case Qt.Key_Space:
            if (keyboardNavigationActive) {
                toggleExpand();
                event.accepted = true;
            }
            return;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (keyboardNavigationActive) {
                toggleExpand();
                event.accepted = true;
            }
            return;
        case Qt.Key_Menu:
        case Qt.Key_F10:
            if (keyboardNavigationActive && selectedIndex >= 0) {
                openContextMenu();
                event.accepted = true;
            }
            return;
        }
    }

    Item {
        id: processKeys
        Keys.onPressed: event => root.handleKey(event)
    }

    Ref {
        service: DgopService
        modules: ["processes", "cpu", "memory", "system", "gpu"]
        active: root.active
    }

    Component.onCompleted: updateProcesses()

    readonly property string dgopCurrentSort: DgopService.currentSort
    readonly property bool dgopSortAscending: DgopService.sortAscending

    onDgopCurrentSortChanged: {
        refreshFilter();
    }

    onDgopSortAscendingChanged: refreshFilter()

    Connections {
        target: root.contextMenu
        function onProcessKilled() {
            root.expandedPid = "";
            root.forceRefresh(3);
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacingS

        RowLayout {
            readonly property bool ascending: DgopService.sortAscending !== ["name", "pid"].includes(DgopService.currentSort)
            Layout.fillWidth: true
            Layout.preferredHeight: ProcessListMetrics.headerHeight
            spacing: Theme.spacingS

            // Coreflame: one heading per row column, with the same widths and margins as ProcessRow,
            // so each heading sits over its numbers (stock spreads four equal buttons across the row).
            Item {
                Layout.preferredWidth: Theme.spacingL + Theme.iconSize
            }

            Repeater {
                id: sortChips
                readonly property var sortKeys: ["name", "cpu", "memory", "pid"]
                model: [I18n.tr("Name"), I18n.tr("CPU"), I18n.tr("Memory"), I18n.tr("PID")]

                Rectangle {
                    id: chip
                    required property int index
                    required property string modelData
                    readonly property string key: sortChips.sortKeys[index]
                    readonly property bool selected: DgopService.currentSort === key
                    Layout.fillWidth: index === 0
                    Layout.minimumWidth: index === 0 ? 0 : [0, ProcessListMetrics.cpuColumnWidth, ProcessListMetrics.memoryColumnWidth, ProcessListMetrics.pidColumnWidth][index]
                    Layout.maximumWidth: index === 0 ? Number.POSITIVE_INFINITY : Layout.minimumWidth
                    Layout.preferredHeight: ProcessListMetrics.headerHeight
                    radius: Theme.cornerRadiusS
                    color: selected ? Theme.secondaryContainer : (chipMouse.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.06) : "transparent")
                    activeFocusOnTab: index === 0
                    Keys.onReturnPressed: DgopService.toggleSort(key)

                    StyledText {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingS
                        anchors.rightMargin: Theme.spacingS
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: chip.index === 0 ? Text.AlignLeft : Text.AlignRight
                        elide: Text.ElideRight
                        // Coreflame: the mockup's table heads, small caps in each form's ink
                        text: !Form.active ? chip.modelData : (Form.reaver ? chip.modelData.toLowerCase() : chip.modelData.toUpperCase())
                        font.family: Form.active ? (Form.khaslana ? "Cinzel" : "Chakra Petch") : Theme.fontFamily
                        font.pixelSize: Form.active ? (Form.reaver ? 12 : 11) : Theme.fontSizeSmall
                        font.letterSpacing: Form.active ? (Form.reaver ? 1.2 : 1.8) : 0
                        font.weight: Form.active && !Form.reaver ? Font.DemiBold : (chip.selected ? Theme.fontWeightMedium : Font.Normal)
                        color: !Form.active ? (chip.selected ? Theme.onSecondaryContainer : Theme.onSurfaceVariant) : (Form.phainon ? "#8A6418" : (Form.khaslana ? "#E0B04A" : "#B9A8FF"))
                    }

                    MouseArea {
                        id: chipMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: DgopService.toggleSort(chip.key)
                    }
                }
            }

            DActionButton {
                id: sortDirection
                KeyNavigation.tab: processListView.currentItem ?? processListView
                iconName: parent.ascending ? "arrow_upward" : "arrow_downward"
                Accessible.name: parent.ascending ? I18n.tr("Ascending", "sort direction, smallest value first") : I18n.tr("Descending", "sort direction, largest value first")
                onClicked: DgopService.toggleSort(DgopService.currentSort)
            }

            Item {
                Layout.preferredWidth: Theme.spacingL - Theme.spacingS
            }
        }

        DListView {
            id: processListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            reuseItems: true
            highlightSelection: root.keyboardNavigationActive && root.selectedIndex >= 0
            activeFocusOnTab: true
            focus: true
            Keys.onPressed: event => root.handleKey(event)
            onActiveFocusChanged: {
                if (activeFocus && root.selectedIndex < 0)
                    root.selectFirst();
            }
            spacing: Theme.groupedListGap
            currentIndex: root.selectedIndex
            add: null
            remove: null
            displaced: null
            move: null

            model: ScriptModel {
                values: root.cachedProcesses
                objectProp: "pid"
            }

            delegate: ProcessRow {
                required property var modelData
                required property int index
                width: processListView.width
                rowHeight: root.rowHeight
                keyForwardTargets: [processKeys]
                KeyNavigation.backtab: sortDirection
                process: modelData
                firstInGroup: index === 0
                lastInGroup: index === processListView.count - 1
                isExpanded: root.expandedPid === (modelData?.pid ?? -1).toString()
                isSelected: root.keyboardNavigationActive && root.selectedIndex === index
                onClicked: {
                    processListView.forceActiveFocus(Qt.MouseFocusReason);
                    root.keyboardNavigationActive = true;
                    root.selectedIndex = index;
                    root.toggleExpand();
                }
                onKillRequested: root.requestKill(index)

                // Under the CPU number: the row's right margin, then the action, PID and memory columns
                ShareBar {
                    share: (modelData?.cpu ?? 0) / 100
                    x: parent.width - Theme.spacingL - ProcessListMetrics.actionColumnWidth - ProcessListMetrics.pidColumnWidth - ProcessListMetrics.memoryColumnWidth - ProcessListMetrics.cpuColumnWidth - 3 * Theme.spacingS
                    y: parent.rowHeight - height - 5
                    width: ProcessListMetrics.cpuColumnWidth
                }
                onContextMenuRequested: (mouseX, mouseY) => {
                    if (!root.contextMenu)
                        return;
                    root.selectedIndex = index;
                    root.keyboardNavigationActive = true;
                    root.contextMenu.processData = modelData;
                    root.contextMenu.parentFocusItem = processListView;
                    const pos = mapToItem(root.contextMenu.parent, mouseX, mouseY);
                    root.contextMenu.show(pos.x, pos.y, false);
                }
            }

            StyledText {
                anchors.centerIn: parent
                text: root.searchText.length > 0 || root.processFilterTypes.length < 2 || DgopService.allProcesses.length > 0 ? I18n.tr("No matching processes", "empty state in process list") : I18n.tr("Loading...")
                color: Theme.onSurfaceVariant
                visible: processListView.count === 0
            }
        }
    }
}
