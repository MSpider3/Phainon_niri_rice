import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

// "Let There Be Light": the launcher, dropping out of the island.
// Tabs: All, Apps, Files, Plugins (emoji and other launcher plugins). Apps you open most come
// first. List or grid. Right arrow on an app shows its own actions.
// Each form lays the rows out differently: Phainon two lines with a round icon plate, Khaslana
// two lines with an index numeral, the Flame Reaver one plain line with no icon.
PanelWindow {
    id: launcher

    required property var targetScreen
    property int strip: 40
    property bool shown: false
    property real reveal: shown ? 1 : 0
    property string query: ""
    // "all", "apps", "files" or "plugins"
    property string mode: "all"
    property bool grid: false
    property var fileHits: []
    // The app whose own actions are being listed, or null
    property var actionsFor: null

    readonly property bool ledger: Form.reaver
    readonly property bool gridShown: grid && !ledger && mode !== "files" && actionsFor === null
    readonly property int visibleRows: ledger ? 11 : 8
    readonly property real panelWidth: 660
    readonly property real rowHeight: ledger ? 34 : 54
    readonly property int gridColumns: 5
    readonly property real cellWidth: Math.floor((panelWidth - 28) / gridColumns)
    readonly property real cellHeight: 104
    readonly property bool filesAvailable: DSearchService.dsearchAvailable
    readonly property var launcherPlugins: Object.keys(PluginService.getLauncherPlugins() ?? {})
    readonly property var modes: {
        const list = ["all", "apps"];
        if (filesAvailable)
            list.push("files");
        if (launcherPlugins.length > 0)
            list.push("plugins");
        return list;
    }

    // Apps, with the ones you open most first when nothing is typed
    readonly property var apps: {
        if (!shown || mode === "files" || mode === "plugins")
            return [];
        const found = AppSearchService.searchApplications(query);
        if (query !== "")
            return found;
        const rank = {};
        AppUsageHistoryData.getRankedApps().forEach((app, i) => rank[app.id] = i);
        return found.slice().sort((a, b) => (rank[a.id] ?? 1e6) - (rank[b.id] ?? 1e6));
    }
    readonly property var pluginItems: {
        if (!shown || mode !== "plugins")
            return [];
        let items = [];
        for (const id of launcherPlugins) {
            const got = AppSearchService.getPluginItemsForPlugin(id, query) ?? [];
            items = items.concat(got.slice(0, 120).map(item => ({
                            "plugin": id,
                            "item": item,
                            "name": item.name ?? "",
                            "comment": item.comment ?? "",
                            "icon": item.icon ?? ""
                        })));
        }
        return items;
    }
    readonly property var results: {
        if (actionsFor !== null)
            return (actionsFor.actions ?? []).map(action => ({
                        "action": action,
                        "name": action.name ?? "",
                        "comment": actionsFor.name ?? ""
                    }));
        if (mode === "apps")
            return apps;
        if (mode === "files")
            return fileHits;
        if (mode === "plugins")
            return pluginItems;
        return apps.concat(fileHits);
    }

    // `typed` is what the user already typed in niri's overview, if the launcher was opened from there.
    function open(typed) {
        // The overview keeps the keyboard (arrows move between its windows), so step out of it first.
        if (NiriService.inOverview)
            NiriService.closeOverview();
        mode = "all";
        actionsFor = null;
        query = "";
        input.text = "";
        input.text = typed ?? "";
        fileHits = [];
        shown = true;
        view.currentIndex = 0;
        input.forceActiveFocus();
    }

    function close() {
        shown = false;
        actionsFor = null;
    }

    function toggle() {
        if (shown)
            close();
        else
            open();
    }

    function setMode(next) {
        mode = next;
        actionsFor = null;
        view.currentIndex = 0;
        if (mode === "apps" || mode === "plugins")
            fileHits = [];
        else
            searchFiles.restart();
        input.forceActiveFocus();
    }

    function nextMode() {
        setMode(modes[(modes.indexOf(mode) + 1) % modes.length]);
    }

    function move(by) {
        if (results.length === 0)
            return;
        view.currentIndex = Math.max(0, Math.min(results.length - 1, view.currentIndex + by));
    }

    function isApp(item) {
        return !!item && !item.path && !item.plugin && !item.action;
    }

    function showActions() {
        const item = results[view.currentIndex];
        if (actionsFor !== null || !isApp(item) || (item.actions ?? []).length === 0)
            return;
        actionsFor = item;
        view.currentIndex = 0;
    }

    function activate(index) {
        const item = results[index];
        if (!item)
            return;
        close();
        if (item.action)
            item.action.execute();
        else if (item.plugin)
            AppSearchService.executePluginItem(item.item, item.plugin);
        else if (item.path)
            Quickshell.execDetached(["xdg-open", item.path]);
        else {
            AppUsageHistoryData.addAppUsage(item);
            SessionService.launchDesktopEntry(item);
            Coreflames.earn("reason");
        }
    }

    function tx(text) {
        return Form.reaver ? String(text).toLowerCase() : text;
    }

    function tabName(which) {
        return which === "all" ? "All" : (which === "apps" ? "Apps" : (which === "files" ? "Files" : "Plugins"));
    }

    onResultsChanged: view.currentIndex = Math.max(0, Math.min(view.currentIndex, results.length - 1))

    // File search waits for a pause in typing before asking the indexer.
    Timer {
        id: searchFiles
        interval: 220
        onTriggered: {
            const asked = launcher.query;
            if (asked.length < 2 || launcher.mode === "apps" || launcher.mode === "plugins") {
                launcher.fileHits = [];
                return;
            }
            DSearchService.search(asked, {
                "limit": launcher.mode === "files" ? 80 : 12
            }, response => {
                if (asked !== launcher.query || launcher.mode === "apps" || launcher.mode === "plugins")
                    return;
                const hits = response?.result?.hits ?? response?.hits ?? [];
                launcher.fileHits = hits.map(hit => {
                    const path = String(hit.id ?? "");
                    const cut = path.lastIndexOf("/");
                    return {
                        "path": path,
                        "name": path.substring(cut + 1),
                        "comment": path.substring(0, cut).replace(Quickshell.env("HOME"), "~")
                    };
                });
            });
        }
    }

    screen: targetScreen
    visible: reveal > 0.001
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "coreflame:launcher"
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
        color: Theme.withAlpha(Theme.background, 0.35 * launcher.reveal)

        MouseArea {
            anchors.fill: parent
            onClicked: launcher.close()
        }
    }

    // The picture for one result: app icon, file glyph, emoji, or a symbol
    component ResultIcon: Item {
        id: resultIcon
        property var entry: null
        property real size: 34
        property bool current: false
        readonly property string raw: String(entry?.icon ?? "")
        readonly property bool emoji: raw.startsWith("unicode:")
        readonly property bool symbol: raw.startsWith("material:") || !!entry?.path || !!entry?.action
        width: size
        height: size

        // Phainon sets app icons on a round plate
        Rectangle {
            visible: Form.phainon && !resultIcon.emoji && !resultIcon.symbol
            anchors.centerIn: parent
            width: parent.width + 8
            height: width
            radius: width / 2
            color: Theme.withAlpha(Theme.surfaceText, 0.06)
        }

        IconImage {
            visible: !resultIcon.emoji && !resultIcon.symbol
            anchors.centerIn: parent
            implicitSize: resultIcon.size
            source: visible ? Quickshell.iconPath(resultIcon.raw, "application-x-executable") : ""
        }

        Text {
            visible: resultIcon.emoji
            anchors.centerIn: parent
            text: resultIcon.emoji ? resultIcon.raw.substring(8) : ""
            font.pixelSize: resultIcon.size * 0.8
        }

        DankIcon {
            visible: resultIcon.symbol
            anchors.centerIn: parent
            name: resultIcon.entry?.path ? "description" : (resultIcon.entry?.action ? "bolt" : resultIcon.raw.substring(9))
            size: resultIcon.size * 0.75
            color: resultIcon.current ? Theme.primaryText : Theme.primary
        }
    }

    Item {
        id: panel

        readonly property int rows: Math.max(1, Math.min(launcher.visibleRows, launcher.results.length))
        readonly property real listTop: launcher.strip + 46
        readonly property real viewHeight: launcher.gridShown ? Math.min(4, Math.max(1, Math.ceil(launcher.results.length / launcher.gridColumns))) * launcher.cellHeight : rows * launcher.rowHeight
        readonly property real fullHeight: listTop + viewHeight + 58

        x: Math.round((launcher.width - width) / 2)
        width: Math.round(420 + (launcher.panelWidth - 420) * launcher.reveal)
        height: Math.round(launcher.strip + (fullHeight - launcher.strip) * launcher.reveal)
        clip: true

        Behavior on height {
            enabled: launcher.reveal > 0.99
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
            target: launcher

            function onShownChanged() {
                if (launcher.shown)
                    ornament.play();
            }
        }

        MouseArea {
            anchors.fill: parent
        }

        // Search line
        Row {
            x: 22
            width: launcher.panelWidth - 44
            height: launcher.strip + 6
            spacing: 10

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "search"
                size: 20
                color: Theme.primary
            }

            TextInput {
                id: input
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 30
                clip: true
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLarge
                color: Theme.surfaceText
                selectionColor: Theme.primary
                selectedTextColor: Theme.primaryText
                onTextChanged: {
                    launcher.actionsFor = null;
                    launcher.query = text;
                    view.currentIndex = 0;
                    if (launcher.mode === "all" || launcher.mode === "files")
                        searchFiles.restart();
                }

                Keys.onEscapePressed: {
                    if (launcher.actionsFor !== null)
                        launcher.actionsFor = null;
                    else
                        launcher.close();
                }
                Keys.onDownPressed: launcher.move(launcher.gridShown ? launcher.gridColumns : 1)
                Keys.onUpPressed: launcher.move(launcher.gridShown ? -launcher.gridColumns : -1)
                Keys.onTabPressed: launcher.nextMode()
                Keys.onReturnPressed: launcher.activate(view.currentIndex)
                Keys.onEnterPressed: launcher.activate(view.currentIndex)
                Keys.onPressed: event => {
                    const atEnd = cursorPosition === text.length;
                    if (event.key === Qt.Key_PageDown) {
                        launcher.move(launcher.visibleRows);
                    } else if (event.key === Qt.Key_PageUp) {
                        launcher.move(-launcher.visibleRows);
                    } else if (event.key === Qt.Key_Right && launcher.gridShown && atEnd) {
                        launcher.move(1);
                    } else if (event.key === Qt.Key_Left && launcher.gridShown && text === "") {
                        launcher.move(-1);
                    } else if (event.key === Qt.Key_Right && atEnd) {
                        launcher.showActions();
                    } else if (event.key === Qt.Key_Left && launcher.actionsFor !== null) {
                        launcher.actionsFor = null;
                    } else {
                        return;
                    }
                    event.accepted = true;
                }

                StyledText {
                    visible: input.text === ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: launcher.tx("Let there be light…")
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.withAlpha(Theme.surfaceText, 0.4)
                }
            }
        }

        Rectangle {
            x: 22
            y: launcher.strip + 6
            width: launcher.panelWidth - 44
            height: 1
            color: Theme.withAlpha(Theme.outline, 0.6)
        }

        // What is listed, how many, and the list / grid switch
        Item {
            x: 22
            y: launcher.strip + 14
            width: launcher.panelWidth - 44
            height: 24
            opacity: launcher.reveal

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                CfGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    name: launcher.mode === "files" ? "earth" : "reason"
                    size: 16
                    strokeWidth: 1.9
                    color: Theme.withAlpha(Theme.surfaceText, 0.6)
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        if (launcher.actionsFor !== null)
                            return launcher.tx("Actions · " + (launcher.actionsFor.name ?? ""));
                        const names = {
                            "all": launcher.fileHits.length > 0 ? "Applications and files" : "Applications",
                            "apps": launcher.query === "" ? "Applications · most used first" : "Applications",
                            "files": "Files",
                            "plugins": "Plugins"
                        };
                        return launcher.tx(names[launcher.mode] ?? "");
                    }
                    font.family: Form.display(Theme.fontFamily)
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.withAlpha(Theme.surfaceText, 0.8)
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: launcher.results.length > 0 ? (view.currentIndex + 1) + " / " + launcher.results.length : "0"
                    font.family: Theme.monoFontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.withAlpha(Theme.surfaceText, 0.45)
                }
            }

            Row {
                visible: !launcher.ledger
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Repeater {
                    model: [false, true]

                    DankIcon {
                        required property bool modelData
                        anchors.verticalCenter: parent.verticalCenter
                        name: modelData ? "grid_view" : "view_list"
                        size: 18
                        color: launcher.grid === modelData ? Theme.primary : Theme.withAlpha(Theme.surfaceText, 0.4)

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                launcher.grid = modelData;
                                input.forceActiveFocus();
                            }
                        }
                    }
                }
            }
        }

        GridView {
            id: view
            x: 14
            y: panel.listTop
            width: launcher.panelWidth - 28
            height: panel.viewHeight
            opacity: launcher.reveal
            clip: true
            model: launcher.results
            cellWidth: launcher.gridShown ? launcher.cellWidth : width
            cellHeight: launcher.gridShown ? launcher.cellHeight : launcher.rowHeight
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0
            highlightFollowsCurrentItem: true

            delegate: Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool current: view.currentIndex === index
                width: view.cellWidth
                height: view.cellHeight

                CfSurface {
                    anchors.fill: parent
                    anchors.margins: 2
                    visible: row.current
                    color: Theme.primary
                    edgeWidth: 0
                    radius: 18
                }

                // ── list row ──
                Item {
                    visible: !launcher.gridShown
                    anchors.fill: parent

                    // Khaslana and the Flame Reaver number their rows
                    Text {
                        visible: !Form.phainon && Form.active
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 26
                        text: String(row.index + 1).padStart(2, "0")
                        font.family: Theme.monoFontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: row.current ? Theme.withAlpha(Theme.primaryText, 0.75) : Theme.withAlpha(Theme.surfaceText, 0.4)
                    }

                    ResultIcon {
                        visible: !launcher.ledger
                        x: (!Form.phainon && Form.active) ? 44 : 16
                        anchors.verticalCenter: parent.verticalCenter
                        entry: row.modelData
                        current: row.current
                    }

                    Column {
                        visible: !launcher.ledger
                        x: (!Form.phainon && Form.active) ? 92 : 66
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - x - 40
                        spacing: 1

                        StyledText {
                            width: parent.width
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                            maximumLineCount: 1
                            text: row.modelData.name ?? ""
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.DemiBold
                            color: row.current ? Theme.primaryText : Theme.surfaceText
                        }

                        StyledText {
                            width: parent.width
                            elide: row.modelData.path ? Text.ElideLeft : Text.ElideRight
                            wrapMode: Text.NoWrap
                            maximumLineCount: 1
                            text: row.modelData.comment || row.modelData.genericName || ""
                            font.pixelSize: Theme.fontSizeSmall
                            color: row.current ? Theme.withAlpha(Theme.primaryText, 0.8) : Theme.withAlpha(Theme.surfaceText, 0.55)
                        }
                    }

                    // The Flame Reaver: one plain line
                    Text {
                        visible: launcher.ledger
                        x: 46
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 60
                        elide: Text.ElideRight
                        text: String(row.modelData.name ?? "").toLowerCase() + ((row.modelData.comment || row.modelData.genericName) ? "   ·   " + String(row.modelData.comment || row.modelData.genericName).toLowerCase() : "")
                        font.family: Theme.monoFontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        color: row.current ? Theme.primaryText : Theme.surfaceText
                    }

                    // This app has actions of its own
                    DankIcon {
                        visible: row.current && launcher.actionsFor === null && launcher.isApp(row.modelData) && (row.modelData.actions ?? []).length > 0
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        name: "chevron_right"
                        size: 20
                        color: Theme.primaryText
                    }
                }

                // ── grid cell ──
                Column {
                    visible: launcher.gridShown
                    anchors.centerIn: parent
                    width: parent.width - 12
                    spacing: 6

                    ResultIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        size: 44
                        entry: row.modelData
                        current: row.current
                    }

                    StyledText {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                        maximumLineCount: 1
                        text: row.modelData.name ?? ""
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: row.current ? Theme.primaryText : Theme.surfaceText
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: view.currentIndex = row.index
                    onClicked: mouse => {
                        view.currentIndex = row.index;
                        if (mouse.button === Qt.RightButton)
                            launcher.showActions();
                        else
                            launcher.activate(row.index);
                    }
                }
            }
        }

        StyledText {
            visible: launcher.results.length === 0
            x: 26
            y: panel.listTop
            height: launcher.rowHeight
            verticalAlignment: Text.AlignVCenter
            text: launcher.tx(launcher.mode === "files" && launcher.query.length < 2 ? "Type at least two letters." : "Nothing answers to that name.")
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.withAlpha(Theme.surfaceText, 0.5)
        }

        // Tabs along the bottom, and the keys
        Item {
            x: 18
            width: launcher.panelWidth - 36
            height: 34
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Form.reaver ? 16 : 12
            opacity: launcher.reveal

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Repeater {
                    model: launcher.modes

                    Item {
                        id: tab
                        required property string modelData
                        readonly property bool current: launcher.mode === modelData
                        width: tabRow.implicitWidth + 22
                        height: 30

                        CfSurface {
                            anchors.fill: parent
                            visible: tab.current
                            color: Theme.primary
                            edgeWidth: 0
                            radius: 15
                            cut: 6
                        }

                        Row {
                            id: tabRow
                            anchors.centerIn: parent
                            spacing: 5

                            DankIcon {
                                visible: !launcher.ledger
                                anchors.verticalCenter: parent.verticalCenter
                                name: tab.modelData === "all" ? "search" : (tab.modelData === "apps" ? "apps" : (tab.modelData === "files" ? "folder" : "extension"))
                                size: 16
                                color: tab.current ? Theme.primaryText : Theme.withAlpha(Theme.surfaceText, 0.7)
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: launcher.tx(launcher.tabName(tab.modelData))
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: tab.current ? Font.Bold : Font.Medium
                                color: tab.current ? Theme.primaryText : Theme.withAlpha(Theme.surfaceText, 0.8)
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: launcher.setMode(tab.modelData)
                        }
                    }
                }
            }

            StyledText {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: launcher.tx(launcher.actionsFor !== null ? "↵ run   ← back" : "↑↓ nav   ↵ open   → actions   Tab switch")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.withAlpha(Theme.surfaceText, 0.45)
            }
        }
    }
}
