pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets as DW
import qs.Modals.DLauncherV2
import "../../Common/LauncherKeybinds.js" as LauncherKeybinds

// "Let There Be Light": the launcher, dropping out of the island.
// The brain is stock DMS 2.0's launcher Controller (modes, frecency, file search, plugins,
// settings and clipboard results, launcher history), with its ActionPanel (Tab), AppEditView and
// right-click menu. Only the face is Coreflame: Phainon two lines on a round icon plate,
// Khaslana numbered two-line rows, the Flame Reaver one numbered lowercase line with no icon.
PanelWindow {
    id: launcher

    required property var targetScreen
    property int strip: 40
    property bool shown: false
    property real reveal: shown ? 1 : 0
    property bool editMode: false
    property var editingApp: null
    property string editAppId: ""
    // Set while the field is filled programmatically, so it does not start a second search
    property bool quiet: false
    // Last pointer position over the list (scene coordinates), null until it is first seen this session
    property var pointer: null

    readonly property bool ledger: Form.reaver
    readonly property real panelWidth: 660
    readonly property real rowHeight: ledger ? 34 : 54
    readonly property real headerHeight: 28
    readonly property int visibleRows: ledger ? 11 : 8
    readonly property var flat: controller.flatModel ?? []
    readonly property int itemCount: flat.length - (controller.sections?.length ?? 0)
    readonly property var modes: ["all", "apps", "files", "plugins"]

    // `typed` is what the user already typed in niri's overview, if the launcher was opened from there.
    function open(typed) {
        // The overview keeps the keyboard (arrows move between its windows), so step out of it first.
        if (NiriService.inOverview)
            NiriService.closeOverview();
        closeTransient();
        editMode = false;
        pointer = null;
        const query = typed || (SettingsData.rememberLastQuery ? (SessionData.launcherLastQuery || "") : "");
        shown = true;
        quiet = true;
        input.text = query;
        quiet = false;
        controller.openSession(query, !!typed, SessionData.getLauncherRestoreMode(), true);
        list.positionViewAtBeginning();
        input.forceActiveFocus();
        if (typed)
            input.cursorPosition = input.text.length;
        else
            input.selectAll();
    }

    function close() {
        closeTransient();
        editMode = false;
        shown = false;
    }

    function toggle() {
        if (shown)
            close();
        else
            open();
    }

    function closeTransient() {
        transientSurfaces.closeAll();
        actionPanel.hide();
        panel.enabled = true;
    }

    function openEditMode(app) {
        if (!app)
            return;
        editingApp = app;
        editAppId = app.id || app.execString || app.exec || "";
        editMode = true;
    }

    function closeEditMode() {
        editMode = false;
        editingApp = null;
        editAppId = "";
        Qt.callLater(() => input.forceActiveFocus());
    }

    function showContextMenu(item, x, y, fromKeyboard) {
        if (item && contextMenu.hasContextMenuActions(item))
            contextMenu.show(x, y, item, fromKeyboard);
    }

    function tx(text) {
        return Form.reaver ? String(text).toLowerCase() : text;
    }

    function tabName(which) {
        return which === "all" ? "All" : (which === "apps" ? "Apps" : (which === "files" ? "Files" : "Plugins"));
    }

    // The icon string AppIconRenderer understands, as stock's LauncherRow builds it
    function iconValue(item) {
        if (!item)
            return "";
        switch (item.iconType) {
        case "material":
        case "nerd":
            return "material:" + (item.icon || "apps");
        case "unicode":
            return "unicode:" + (item.icon || "");
        case "composite":
            return item.iconFull || "";
        default:
            return item.icon || "";
        }
    }

    function badge(item) {
        if (!item || item.type === "app" || item.type === "plugin_browse")
            return "";
        if ((item.badgeLabel ?? "").length > 0)
            return item.badgeLabel;
        if (controller.activePluginName)
            return "";
        switch (item.type) {
        case "plugin":
            return "Plugin";
        case "setting":
            return "Setting";
        case "clipboard":
            return "Clipboard";
        case "file":
            return item.data?.is_dir ? "Folder" : "File";
        default:
            return "";
        }
    }

    function emptyText() {
        const mode = controller.searchMode;
        const query = controller.searchQuery ?? "";
        if (mode === "files") {
            if (!DSearchService.dsearchAvailable)
                return "File search needs dsearch.";
            if (query.length < 2)
                return "Type at least two letters.";
        }
        if (mode === "plugins" && query === "")
            return "Browse or search plugins.";
        return "Nothing answers to that name.";
    }

    Controller {
        id: controller
        active: launcher.shown
        retainResultsOnClose: !SettingsData.dankLauncherV2UnloadOnClose
        viewModeContext: "spotlight"
        // Coreflame draws every section as a list, as stock's own island launcher does.
        forceLinearNavigation: true

        onItemExecuted: {
            if (selectedItem?.type === "app")
                Coreflames.earn("reason");
            launcher.close();
        }
        onSearchQueryRequested: query => input.text = query
        onModeChanged: (mode, userInitiated) => {
            extField.text = "";
            if (userInitiated && SettingsData.rememberLastMode)
                SessionData.setLauncherLastMode(mode);
        }
        onSelectedFlatIndexChanged: {
            if (!keyboardNavigationActive)
                return;
            if (selectedFlatIndex <= 1)
                list.positionViewAtBeginning();
            else
                list.positionViewAtIndex(selectedFlatIndex, ListView.Contain);
        }
        onSelectedItemChanged: {
            if (actionPanel.expanded)
                actionPanel.hide();
        }
    }

    TransientSurfaceTracker {
        id: transientSurfaces
    }

    LauncherContextMenu {
        id: contextMenu
        parent: panel
        controller: controller
        searchField: input
        parentHandler: panel
        transientSurfaceTracker: transientSurfaces
        onEditAppRequested: app => launcher.openEditMode(app)
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

    Item {
        id: panel

        readonly property real listTop: launcher.strip + 46
        readonly property real listHeight: {
            let h = 0;
            for (const entry of launcher.flat)
                h += entry.isHeader ? launcher.headerHeight : launcher.rowHeight;
            return Math.max(launcher.rowHeight, Math.min(h, launcher.visibleRows * launcher.rowHeight + launcher.headerHeight));
        }
        readonly property real fullHeight: listTop + (launcher.editMode ? editLoader.height : body.implicitHeight) + 58

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

            DW.DIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "search"
                size: 20
                color: Theme.primary
            }

            // The plugin a trigger switched to, as stock shows it in its search field
            StyledText {
                id: pluginTag
                visible: text !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: controller.activePluginName ? launcher.tx(controller.activePluginName) + "  ›" : ""
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.DemiBold
                color: Theme.primary
            }

            TextInput {
                id: input
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 30 - (pluginTag.visible ? pluginTag.width + 10 : 0)
                clip: true
                focus: true
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLarge
                color: Theme.surfaceText
                selectionColor: Theme.primary
                selectedTextColor: Theme.primaryText
                onTextChanged: {
                    if (launcher.quiet)
                        return;
                    controller.setSearchQuery(text);
                    actionPanel.hide();
                }

                // Stock LauncherContent's keys, minus dmenu (dmenu still opens the stock launcher)
                Keys.onPressed: event => {
                    const ctrl = event.modifiers & Qt.ControlModifier;
                    event.accepted = true;

                    const bound = LauncherKeybinds.actionForEvent(event, SettingsData.launcherKeybinds);
                    if (bound) {
                        actionPanel.hide();
                        if (bound.mode)
                            controller.setMode(bound.mode);
                        else
                            controller.cycleMode(bound.id === "previousMode");
                        return;
                    }

                    switch (event.key) {
                    case Qt.Key_Escape:
                        if (actionPanel.expanded)
                            actionPanel.hide();
                        else if (!controller.clearPluginFilter())
                            launcher.close();
                        return;
                    case Qt.Key_Backspace:
                        if (text.length === 0) {
                            if (controller.clearPluginFilter())
                                return;
                            if (controller.autoSwitchedToFiles) {
                                controller.restorePreviousMode();
                                return;
                            }
                        }
                        event.accepted = false;
                        return;
                    case Qt.Key_Down:
                        controller.selectNext();
                        return;
                    case Qt.Key_Up:
                        controller.selectPrevious();
                        return;
                    case Qt.Key_PageDown:
                        controller.selectPageDown(launcher.visibleRows);
                        return;
                    case Qt.Key_PageUp:
                        controller.selectPageUp(launcher.visibleRows);
                        return;
                    case Qt.Key_J:
                    case Qt.Key_N:
                        if (ctrl) {
                            event.key === Qt.Key_J ? controller.selectNext() : controller.selectNextSection();
                            return;
                        }
                        event.accepted = false;
                        return;
                    case Qt.Key_K:
                    case Qt.Key_P:
                        if (ctrl) {
                            event.key === Qt.Key_K ? controller.selectPrevious() : controller.selectPreviousSection();
                            return;
                        }
                        event.accepted = false;
                        return;
                    case Qt.Key_Tab:
                    case Qt.Key_Backtab:
                        if (!ctrl && actionPanel.hasActions) {
                            if (actionPanel.expanded)
                                actionPanel.cycleAction(event.key === Qt.Key_Backtab);
                            else
                                actionPanel.show();
                        }
                        return;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        if (event.modifiers & Qt.ShiftModifier)
                            controller.pasteSelected();
                        else if (actionPanel.expanded && actionPanel.selectedActionIndex > 0)
                            actionPanel.executeSelectedAction();
                        else
                            controller.executeSelected(!!ctrl);
                        return;
                    case Qt.Key_Menu:
                    case Qt.Key_F10:
                        {
                            const at = list.itemAtIndex(controller.selectedFlatIndex);
                            const pos = at ? at.mapToItem(panel, 60, at.height / 2) : Qt.point(panel.width / 2, panel.listTop);
                            launcher.showContextMenu(controller.selectedItem, pos.x, pos.y, true);
                            return;
                        }
                    default:
                        event.accepted = false;
                    }
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

        // Heading and position
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
                    name: Form.reaver ? "mask" : "reason"
                    size: 16
                    strokeWidth: 1.9
                    color: Theme.withAlpha(Theme.surfaceText, 0.6)
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: launcher.tx("Reason · Launcher")
                    font.family: Form.display(Theme.fontFamily)
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.withAlpha(Theme.surfaceText, 0.8)
                }
            }

            StyledText {
                visible: !launcher.editMode
                anchors.right: parent.right
                // clear of Khaslana's corner ornament
                anchors.rightMargin: Form.khaslana ? 22 : 0
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    const at = controller.selectedFlatIndex;
                    const entry = launcher.flat[at];
                    if (!entry || entry.isHeader)
                        return String(launcher.itemCount);
                    return (at - entry.sectionIndex) + " / " + launcher.itemCount;
                }
                font.family: Theme.monoFontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.withAlpha(Theme.surfaceText, 0.45)
            }
        }

        Column {
            id: body
            x: 14
            y: panel.listTop
            width: launcher.panelWidth - 28
            spacing: 8
            visible: !launcher.editMode
            opacity: launcher.reveal

            // Plugin categories, as stock shows them for plugins that have some
            DW.DDropdown {
                visible: controller.activePluginCategories.length > 0
                x: 8
                width: Math.min(Theme.fieldDefaultWidth, parent.width - 16)
                compactMode: true
                transientSurfaceTracker: transientSurfaces
                focusPolicy: Qt.NoFocus
                focusReturnTarget: input
                dropdownWidth: Theme.fieldDefaultWidth
                popupWidth: Theme.fieldDefaultWidth + Theme.spacingXL * 2
                maxPopupHeight: Theme.menuMaxHeight
                enableFuzzySearch: controller.activePluginCategories.length > 8
                currentValue: {
                    const cats = controller.activePluginCategories;
                    const found = cats.find(cat => cat.id === controller.activePluginCategory);
                    return found ? found.name : (cats.length > 0 ? cats[0].name : "");
                }
                options: controller.activePluginCategories.map(cat => cat.name)
                onValueChanged: value => {
                    const found = controller.activePluginCategories.find(cat => cat.name === value);
                    if (found)
                        controller.setActivePluginCategory(found.id);
                }
            }

            // File search filters: type, sort, extension
            RowLayout {
                visible: controller.searchMode === "files"
                x: 8
                width: parent.width - 16
                height: Theme.buttonHeightS
                spacing: Theme.spacingS

                DW.DDropdown {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    visible: DSearchService.supportsTypeFilter
                    triggerHeight: Theme.buttonHeightS
                    compactMode: true
                    dropdownWidth: width
                    maxPopupHeight: Theme.menuMaxHeight
                    transientSurfaceTracker: transientSurfaces
                    focusPolicy: Qt.NoFocus
                    focusReturnTarget: input
                    readonly property var types: ["all", "file", "dir"]
                    currentValue: options[Math.max(0, types.indexOf(controller.fileSearchType))]
                    options: [launcher.tx("All"), launcher.tx("Files"), launcher.tx("Folders")]
                    onValueChanged: value => controller.setFileSearchType(types[Math.max(0, options.indexOf(value))])
                }

                DW.DDropdown {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    triggerHeight: Theme.buttonHeightS
                    compactMode: true
                    dropdownWidth: width
                    maxPopupHeight: Theme.menuMaxHeight
                    transientSurfaceTracker: transientSurfaces
                    focusPolicy: Qt.NoFocus
                    focusReturnTarget: input
                    readonly property var sorts: ["score", "name", "modified", "size"]
                    currentValue: options[Math.max(0, sorts.indexOf(controller.fileSearchSort))]
                    options: [launcher.tx("Score"), launcher.tx("Name"), launcher.tx("Modified"), launcher.tx("Size")]
                    onValueChanged: value => controller.setFileSearchSort(sorts[Math.max(0, options.indexOf(value))])
                }

                DW.DTextField {
                    id: extField
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: Theme.buttonHeightS
                    placeholderText: launcher.tx("ext")
                    font.pixelSize: Theme.fontSizeMedium
                    showClearButton: text.length > 0
                    onTextChanged: controller.setFileSearchExt(text.trim())
                }
            }

            Item {
                width: parent.width
                height: panel.listHeight

                ListView {
                    id: list
                    anchors.fill: parent
                    clip: true
                    model: launcher.flat
                    boundsBehavior: Flickable.StopAtBounds
                    currentIndex: controller.selectedFlatIndex

                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property var item: modelData.item ?? null
                        readonly property bool header: !!modelData.isHeader
                        readonly property bool current: !header && controller.selectedFlatIndex === index
                        readonly property string sub: String(item?.subtitle ?? "")
                        readonly property string preview: {
                            const raw = item?.data?.imageUrl || item?.data?.imagePath || "";
                            return raw.startsWith("/") ? "file://" + raw : raw;
                        }
                        width: ListView.view.width
                        height: header ? launcher.headerHeight : launcher.rowHeight

                        // ── section header: mark, title, count; click folds it when stock allows ──
                        Row {
                            visible: row.header
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 7

                            CfGlyph {
                                visible: Form.reaver
                                anchors.verticalCenter: parent.verticalCenter
                                name: "mask"
                                size: 13
                                strokeWidth: 1.6
                                color: Theme.withAlpha(Theme.surfaceText, 0.55)
                            }

                            DW.DIcon {
                                visible: !Form.reaver
                                anchors.verticalCenter: parent.verticalCenter
                                name: row.modelData.section?.icon || "apps"
                                size: 14
                                color: Theme.primary
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: launcher.tx(row.modelData.section?.title ?? "")
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.DemiBold
                                font.letterSpacing: Form.khaslana ? 1.2 : 0
                                font.capitalization: Form.khaslana ? Font.AllUppercase : Font.MixedCase
                                color: Theme.withAlpha(Theme.surfaceText, 0.7)
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: String(row.modelData.section?.items?.length ?? 0)
                                font.family: Theme.monoFontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.withAlpha(Theme.surfaceText, 0.4)
                            }
                        }

                        DW.DIcon {
                            visible: row.header && controller.canCollapseSection(row.modelData.sectionId)
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            name: row.modelData.section?.collapsed ? "expand_more" : "expand_less"
                            size: 16
                            color: Theme.withAlpha(Theme.surfaceText, 0.5)
                        }

                        // ── result row ──
                        CfSurface {
                            anchors.fill: parent
                            anchors.margins: 2
                            visible: row.current
                            color: Theme.primary
                            edgeWidth: 0
                            radius: 18
                        }

                        Item {
                            visible: !row.header
                            anchors.fill: parent
                            opacity: (row.item?.type === "dmenu" && row.item?.data?.nonSelectable) ? 0.5 : 1

                            // Khaslana and the Flame Reaver number their rows
                            Text {
                                visible: !Form.phainon && Form.active
                                x: 12
                                anchors.verticalCenter: parent.verticalCenter
                                width: 26
                                text: String(row.index - row.modelData.sectionIndex).padStart(2, "0")
                                font.family: Theme.monoFontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                color: row.current ? Theme.withAlpha(Theme.primaryText, 0.75) : Theme.withAlpha(Theme.surfaceText, 0.4)
                            }

                            Item {
                                id: iconBox
                                visible: !launcher.ledger
                                x: (!Form.phainon && Form.active) ? 44 : 16
                                anchors.verticalCenter: parent.verticalCenter
                                width: 34
                                height: 34

                                // Phainon sets app icons on a round plate
                                Rectangle {
                                    visible: Form.phainon && row.item?.type === "app"
                                    anchors.centerIn: parent
                                    width: parent.width + 8
                                    height: width
                                    radius: width / 2
                                    color: Theme.withAlpha(Theme.surfaceText, 0.06)
                                }

                                DW.AppIconRenderer {
                                    anchors.fill: parent
                                    iconValue: iconBox.visible ? launcher.iconValue(row.item) : ""
                                    iconSize: 34
                                    iconColor: row.current ? Theme.primaryText : Theme.primary
                                    fallbackText: (row.item?.name?.length > 0) ? row.item.name.charAt(0).toUpperCase() : "?"
                                    fallbackRadius: 17
                                    fallbackBackgroundColor: Theme.withAlpha(Theme.primary, 0.18)
                                    fallbackTextColor: Theme.primary
                                }
                            }

                            Column {
                                visible: !launcher.ledger
                                x: iconBox.x + 50
                                anchors.verticalCenter: parent.verticalCenter
                                width: trail.x - x - 10
                                spacing: 1

                                StyledText {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    wrapMode: Text.NoWrap
                                    maximumLineCount: 1
                                    text: row.item?.name ?? ""
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.DemiBold
                                    color: row.current ? Theme.primaryText : (row.item?.data?.urgent ? Theme.error : Theme.surfaceText)
                                }

                                StyledText {
                                    visible: row.sub !== ""
                                    width: parent.width
                                    elide: row.item?.type === "file" ? Text.ElideLeft : Text.ElideRight
                                    wrapMode: Text.NoWrap
                                    maximumLineCount: 1
                                    text: row.sub
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: row.current ? Theme.withAlpha(Theme.primaryText, 0.8) : Theme.withAlpha(Theme.surfaceText, 0.55)
                                }
                            }

                            // The Flame Reaver: one plain line
                            Text {
                                visible: launcher.ledger
                                x: 46
                                anchors.verticalCenter: parent.verticalCenter
                                width: trail.x - x - 10
                                elide: Text.ElideRight
                                text: String(row.item?.name ?? "").trim().toLowerCase() + (row.sub ? "  ·  " + row.sub.trim().toLowerCase() : "")
                                font.family: Theme.monoFontFamily
                                font.pixelSize: Theme.fontSizeMedium
                                color: row.current ? Theme.primaryText : Theme.surfaceText
                            }

                            // Pinned mark, picture preview, kind of result, and his crossed blades on the chosen row
                            Row {
                                id: trail
                                x: parent.width - width - 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                DW.DIcon {
                                    visible: row.item?.pinned === true
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "push_pin"
                                    size: 16
                                    color: row.current ? Theme.primaryText : Theme.withAlpha(Theme.surfaceText, 0.6)
                                }

                                Image {
                                    visible: row.preview !== "" && row.item?.type !== "clipboard"
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: launcher.rowHeight
                                    height: launcher.rowHeight - 14
                                    source: visible ? row.preview : ""
                                    asynchronous: true
                                    sourceSize.width: width * 2
                                    sourceSize.height: height * 2
                                    fillMode: Image.PreserveAspectFit
                                }

                                Loader {
                                    active: row.item?.type === "clipboard" && !!row.item?.data?.isImage
                                    visible: active
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: active ? launcher.rowHeight : 0
                                    height: launcher.rowHeight - 14
                                    sourceComponent: ClipboardLauncherPreview {
                                        entry: row.item?.data ?? null
                                    }
                                }

                                StyledText {
                                    readonly property string kind: launcher.badge(row.item)
                                    visible: kind !== ""
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: launcher.tx(kind)
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: Form.reaver ? Theme.monoFontFamily : Theme.fontFamily
                                    color: row.current ? Theme.withAlpha(Theme.primaryText, 0.75) : Theme.withAlpha(Theme.surfaceText, 0.45)
                                }

                                CfCrossToggle {
                                    visible: Form.reaver && row.current
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: true
                                    color: Theme.primaryText
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: !row.header
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            // Qt re-sends hover when results move under a still pointer; only a real move selects,
                            // so Enter keeps launching the top match while the mouse rests on the list.
                            onPositionChanged: mouse => {
                                const at = mapToItem(null, mouse.x, mouse.y);
                                const moved = launcher.pointer !== null && (at.x !== launcher.pointer.x || at.y !== launcher.pointer.y);
                                launcher.pointer = at;
                                if (moved && !row.header && !row.current)
                                    controller.selectIndex(row.index);
                            }
                            onClicked: mouse => {
                                if (row.header) {
                                    if (controller.canCollapseSection(row.modelData.sectionId))
                                        controller.toggleSection(row.modelData.sectionId);
                                    return;
                                }
                                controller.selectIndex(row.index);
                                if (mouse.button === Qt.RightButton) {
                                    const pos = mapToItem(panel, mouse.x, mouse.y);
                                    launcher.showContextMenu(row.item, pos.x, pos.y, false);
                                } else {
                                    controller.executeItem(row.item);
                                }
                                input.forceActiveFocus();
                            }
                        }
                    }
                }

                StyledText {
                    visible: launcher.itemCount <= 0
                    x: 12
                    height: launcher.rowHeight
                    verticalAlignment: Text.AlignVCenter
                    text: launcher.tx(controller.isFileSearching ? "Searching…" : launcher.emptyText())
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.withAlpha(Theme.surfaceText, 0.5)
                }
            }

            // Stock's action bar for the chosen result (Tab), framed per form
            ActionPanel {
                id: actionPanel
                width: parent.width
                selectedItem: controller.selectedItem
                controller: controller
                color: Form.reaver ? "transparent" : Theme.withAlpha(Theme.surfaceText, 0.05)
                border.width: Form.khaslana ? 1 : 0
                border.color: Theme.primary
                radius: Form.phainon ? 16 : 0
            }
        }

        // Stock's app editor (rename, icon, comment, env, flags) in place of the list
        Loader {
            id: editLoader
            x: 22
            y: panel.listTop
            width: launcher.panelWidth - 44
            height: item ? item.implicitHeight : 0
            active: launcher.editMode
            visible: active
            focus: launcher.editMode
            Keys.onEscapePressed: launcher.closeEditMode()

            sourceComponent: AppEditView {
                focus: true
                editingApp: launcher.editingApp
                editAppId: launcher.editAppId
                onCloseRequested: launcher.closeEditMode()
            }

            onLoaded: item.loadOverride()
        }

        // Modes along the bottom, and the keys
        Item {
            visible: !launcher.editMode
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
                        readonly property bool current: controller.searchMode === modelData
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

                            DW.DIcon {
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
                            onClicked: {
                                actionPanel.hide();
                                controller.setMode(tab.modelData);
                                input.forceActiveFocus();
                            }
                        }
                    }
                }
            }

            StyledText {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: launcher.tx("↑↓ nav   ↵ open" + (actionPanel.hasActions ? "   Tab actions" : "") + "   Ctrl+Tab mode")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.withAlpha(Theme.surfaceText, 0.45)
            }
        }
    }
}
