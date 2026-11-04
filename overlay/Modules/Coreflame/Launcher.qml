pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets as DW
import qs.Modals.DLauncherV2
import "../../Common/LauncherKeybinds.js" as LauncherKeybinds
import "Numerals.js" as Numerals

// "Let There Be Light": the launcher, in a fixed frame per form (the v3 mockup).
//   Phainon: the oracle, an arch 720 x 800 hanging from the island on a stem.
//   Khaslana: the programme, a drawer 620 px wide down the left edge, acts numbered in Roman.
//   Flame Reaver: a console along the bottom; results grow upward from the search bar.
// The brain is stock DMS 2.0's launcher Controller (modes, frecency, file search, plugins,
// settings and clipboard results, launcher history), with its ActionPanel (Tab), AppEditView and
// right-click menu. Results scroll inside the frame; long names end in "…".
PanelWindow {
    id: launcher

    required property var targetScreen
    property int strip: 40
    property bool shown: false
    property real opening: shown ? 1 : 0
    readonly property real reveal: Motion.step(opening)
    property bool editMode: false
    property var editingApp: null
    property string editAppId: ""
    // Set while the field is filled programmatically, so it does not start a second search
    property bool quiet: false
    // Last pointer position over the list (scene coordinates), null until it is first seen this session
    property var pointer: null

    // A theme other than Coreflame's gets Phainon's arch in that theme's colours.
    readonly property string lay: !Form.active ? "phainon" : Form.form
    readonly property bool kh: lay === "khaslana"
    readonly property bool rv: lay === "reaver"
    readonly property bool ph: lay === "phainon"
    readonly property bool parch: ph && Form.active && Theme.isLightMode
    readonly property real rowHeight: rv ? 30 : (kh ? 56 : 54)
    readonly property real headerHeight: 28
    readonly property int visibleRows: Math.max(4, Math.floor(listArea.height / rowHeight))
    readonly property var flat: controller.flatModel ?? []
    readonly property int itemCount: flat.length - (controller.sections?.length ?? 0)
    readonly property var modes: ["all", "apps", "files", "plugins"]

    readonly property QtObject pal: QtObject {
        readonly property color ink: launcher.kh ? "#F3E6CC" : (launcher.rv ? "#E9E7F2" : (launcher.parch ? "#1E2752" : Theme.surfaceText))
        readonly property color mut: launcher.kh ? "#C9B89E" : (launcher.rv ? "#A8A4BC" : (launcher.parch ? "#4A5484" : Theme.withAlpha(Theme.surfaceText, 0.6)))
        readonly property color accent: launcher.kh ? "#E0B04A" : (launcher.rv ? "#B9A8FF" : (launcher.parch ? "#A87A22" : Theme.primary))
        readonly property color lapis: launcher.parch ? "#334786" : Theme.primary
        readonly property color paper: launcher.kh ? "#0B080B" : (launcher.parch ? "#F7F3E8" : Theme.surfaceContainer)
        readonly property color rim: launcher.kh ? "#2E1A1A" : (launcher.rv ? "#2C2840" : (launcher.parch ? "#DCCDA6" : Theme.withAlpha(Theme.outline, 0.45)))
        readonly property color rim2: launcher.parch ? "#C8B27E" : Theme.withAlpha(Theme.outline, 0.7)
        readonly property color selInk: launcher.kh ? "#F5D27A" : (launcher.rv ? "#F2EEE0" : (launcher.parch ? "#1E2752" : Theme.surfaceText))
        readonly property color cap: launcher.kh ? "#E0B04A" : (launcher.rv ? "#B9A8FF" : (launcher.parch ? "#8A6418" : Theme.primary))
    }
    readonly property string body: ph ? (Form.active ? Form.numerals : Theme.fontFamily) : "Chakra Petch"

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
        return rv ? String(text).toLowerCase() : text;
    }

    function tabName(which) {
        return which === "all" ? "All" : (which === "apps" ? "Apps" : (which === "files" ? "Files" : "Plugins"));
    }

    // Khaslana's act numbers; plain digits from 40 on
    function roman(n) {
        return Numerals.roman(n);
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

    // "1 / 12": the chosen row's place in its section
    function position() {
        const at = controller.selectedFlatIndex;
        const entry = flat[at];
        if (!entry || entry.isHeader)
            return String(itemCount);
        return (at - entry.sectionIndex) + " / " + itemCount;
    }

    // The first section's title and size, for the heading line
    readonly property string sectionLine: {
        const s = controller.sections?.[0];
        return s ? s.title + " · " + (s.items?.length ?? 0) : "";
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
        headerText: contextMenu.item?.name ?? ""
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

    Behavior on opening {
        NumberAnimation {
            duration: Motion.openMs
            easing.type: Motion.openEasing
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

    // What leads from the island to the frame: Phainon's stem, the Reaver's crack
    Rectangle {
        visible: launcher.ph
        x: Math.round((launcher.width - width) / 2)
        y: launcher.strip - 4
        width: 120
        height: Math.max(0, (panel.y - y + 2) * launcher.reveal)
        color: launcher.pal.paper
        border.width: 1
        border.color: launcher.pal.rim2
    }

    Shape {
        id: link
        visible: launcher.rv
        anchors.fill: parent
        opacity: launcher.reveal
        preferredRendererType: Shape.CurveRenderer
        readonly property var pts: [[960, 40], [936, 120], [978, 210], [940, 320], [972, 420], [950, 528]].map(p => Qt.point(p[0] * width / 1920, Math.min(p[1] * height / 1080, panel.y + 30)))

        ShapePath {
            strokeColor: Qt.rgba(5 / 255, 4 / 255, 10 / 255, 0.85)
            strokeWidth: 5
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            PathPolyline {
                path: link.pts
            }
        }
        ShapePath {
            strokeColor: "#D6CCFF"
            strokeWidth: 1.6
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            PathPolyline {
                path: link.pts
            }
        }
    }

    Item {
        id: panel

        // The frame's final size and place
        readonly property real fullW: launcher.kh ? 620 : (launcher.rv ? launcher.width : Math.min(720, launcher.width - 40))
        readonly property real fullH: launcher.kh ? launcher.height - launcher.strip - 4 : (launcher.rv ? Math.round(Math.min(560, launcher.height * 0.52)) : Math.min(800, launcher.height - launcher.strip - 90))

        x: launcher.kh || launcher.rv ? 0 : Math.round((launcher.width - fullW) / 2)
        // The Reaver's console rises from the bottom edge; the others drop from the top
        y: launcher.rv ? launcher.height - height : (launcher.kh ? launcher.strip + 4 : launcher.strip + 70)
        width: fullW
        height: Math.round(fullH * launcher.reveal)
        clip: true

        MouseArea {
            anchors.fill: parent
        }

        // Everything below is laid out at full size, pinned to the edge the frame grows from.
        Item {
            id: face
            width: panel.fullW
            height: panel.fullH
            y: launcher.rv ? panel.height - height : 0

            // ── frames ──

            // Phainon: an arch of paper
            Loader {
                active: launcher.ph
                anchors.fill: parent
                sourceComponent: Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: launcher.pal.rim2
                        strokeWidth: 1
                        fillColor: launcher.pal.paper
                        PathSvg {
                            path: {
                                const w = face.width, h = face.height;
                                return `M0.5 150 A${w / 2 - 0.5} 149.5 0 0 1 ${w / 2} 0.5 A${w / 2 - 0.5} 149.5 0 0 1 ${w - 0.5} 150 L${w - 0.5} ${h - 22} Q${w - 0.5} ${h - 0.5} ${w - 22} ${h - 0.5} L22 ${h - 0.5} Q0.5 ${h - 0.5} 0.5 ${h - 22} Z`;
                            }
                        }
                    }
                }
            }

            // Khaslana: a black drawer, a gold rule with a red shadow down its edge, and red blocks
            // bleeding from the left
            Loader {
                active: launcher.kh
                sourceComponent: Rectangle {
                    x: face.width - 2
                    width: 7
                    height: face.height
                    color: "#8E1424"
                }
            }

            Loader {
                active: launcher.kh
                sourceComponent: Rectangle {
                    width: face.width
                    height: face.height
                    color: "#0B080B"

                    Rectangle {
                        anchors.right: parent.right
                        width: 2
                        height: parent.height
                        color: "#E0B04A"
                    }

                    Column {
                        id: bleed
                        spacing: 3
                        // The mockup's block sequence (as CfTide), turned to run down the edge
                        readonly property var blocks: {
                            const out = [];
                            let x = 7 + 9 * 13;
                            for (let i = 0; i < 60; i++) {
                                x = (x * 73 + 19) % 101;
                                out.push(6 + x % 14);
                            }
                            return out;
                        }

                        Repeater {
                            model: bleed.blocks

                            Rectangle {
                                required property int index
                                required property var modelData
                                width: modelData
                                height: (face.height - 3 * 59) / 60
                                color: (index + 1) % 11 === 0 ? "#E0B04A" : (index + 1) % 7 === 0 ? "#3A0A12" : (index + 1) % 3 === 0 ? "#C2252F" : "#8E1424"
                            }
                        }
                    }
                }
            }

            // Flame Reaver: a shard with a jagged top, and his fractures
            Loader {
                active: launcher.rv
                anchors.fill: parent
                sourceComponent: Shape {
                    id: console_
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    // The jagged top edge: [x share of width, y in px]
                    readonly property var edgePts: [[0, 34], [0.18, 0], [0.31, 28], [0.5, 0], [0.66, 34], [0.83, 6], [1, 28]]
                    function poly(inset) {
                        const w = face.width, h = face.height;
                        const pts = edgePts.map(p => Qt.point(Math.min(w - inset, Math.max(inset, p[0] * w)), p[1] + inset));
                        pts.push(Qt.point(w - inset, h), Qt.point(inset, h), pts[0]);
                        return pts;
                    }

                    ShapePath {
                        strokeWidth: -1
                        fillGradient: LinearGradient {
                            x1: 0
                            y1: 0
                            x2: face.width
                            y2: face.height
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
                            path: console_.poly(0)
                        }
                    }

                    ShapePath {
                        strokeWidth: -1
                        fillColor: Qt.rgba(13 / 255, 11 / 255, 20 / 255, 0.95)
                        PathPolyline {
                            path: console_.poly(2)
                        }
                    }
                }
            }

            Loader {
                active: launcher.rv
                sourceComponent: CfCracks {
                    y: 40
                    width: face.width
                    height: face.height - 40
                    kind: "violet"
                    opacity: 0.35
                }
            }

            // ── crowns and titles ──

            Column {
                visible: launcher.ph
                y: 34
                width: face.width
                spacing: 8

                DW.DIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "wb_sunny"
                    size: 30
                    color: launcher.pal.accent
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "REASON · LAUNCHER"
                    font.family: "Marcellus"
                    font.pixelSize: 15
                    font.letterSpacing: 3
                    color: launcher.pal.lapis
                }
            }

            Column {
                visible: launcher.kh
                x: 34
                y: 22
                width: face.width - 60
                spacing: 4

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "PROGRAMME"
                    font.family: "Cinzel"
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    font.letterSpacing: 7.2
                    color: "#F5D27A"
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "REASON · LAUNCHER"
                    font.family: "Cinzel"
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    font.letterSpacing: 2.2
                    color: "#C2252F"
                }
            }

            // ── the search field ──

            Item {
                id: searchBox
                readonly property real m: launcher.kh ? 34 : (launcher.rv ? 30 : 26)
                x: m
                y: launcher.ph ? 150 : (launcher.kh ? 76 : face.height - 56)
                width: face.width - m - (launcher.kh ? 26 : m)
                height: launcher.kh ? 48 : (launcher.rv ? 56 : 46)

                // Khaslana: a box with a red offset. Phainon: a gold underline. Reaver: a violet rule above.
                Rectangle {
                    visible: launcher.kh
                    x: 3
                    y: 3
                    width: parent.width
                    height: parent.height
                    color: "#8E1424"
                }

                Rectangle {
                    visible: launcher.kh
                    anchors.fill: parent
                    color: "#160D10"
                    border.width: 1
                    border.color: "#E0B04A"
                }

                Rectangle {
                    visible: !launcher.kh
                    x: launcher.rv ? -searchBox.x : 0
                    y: launcher.rv ? 0 : parent.height - 1.5
                    width: launcher.rv ? face.width : parent.width
                    height: launcher.rv ? 2 : 1.5
                    color: launcher.rv ? "#8F7BE0" : launcher.pal.accent
                }

                Row {
                    x: launcher.kh ? 14 : 6
                    width: parent.width - x - (launcher.kh ? 14 : 6)
                    height: parent.height
                    spacing: 12

                    DW.DIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "search"
                        size: launcher.ph ? 22 : 20
                        color: launcher.pal.accent
                    }

                    // The plugin a trigger switched to, as stock shows it in its search field
                    Text {
                        id: pluginTag
                        visible: text !== ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: controller.activePluginName ? launcher.tx(controller.activePluginName) + "  ›" : ""
                        font.family: launcher.body
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        color: launcher.pal.accent
                    }

                    TextInput {
                        id: input
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 34 - (pluginTag.visible ? pluginTag.width + 12 : 0) - trailing.width - 12
                        clip: true
                        focus: true
                        // A plain bar for a caret, never blinking
                        cursorDelegate: Rectangle {
                            width: 2
                            color: launcher.kh ? "#F5D27A" : launcher.pal.lapis
                            visible: input.activeFocus
                        }
                        font.family: launcher.ph ? "Marcellus" : "Chakra Petch"
                        font.pixelSize: launcher.ph ? 24 : 20
                        color: launcher.pal.ink
                        selectionColor: launcher.pal.accent
                        selectedTextColor: launcher.kh || launcher.rv ? "#0B080B" : "#FFFFFF"
                        onTextChanged: {
                            if (launcher.quiet)
                                return;
                            controller.setSearchQuery(text);
                            actionPanel.hide();
                        }

                        // Stock LauncherContent's keys, minus dmenu (dmenu still opens the stock launcher).
                        // The Reaver's list grows upward, so his arrows are turned round.
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
                                launcher.rv ? controller.selectPrevious() : controller.selectNext();
                                return;
                            case Qt.Key_Up:
                                launcher.rv ? controller.selectNext() : controller.selectPrevious();
                                return;
                            case Qt.Key_PageDown:
                                launcher.rv ? controller.selectPageUp(launcher.visibleRows) : controller.selectPageDown(launcher.visibleRows);
                                return;
                            case Qt.Key_PageUp:
                                launcher.rv ? controller.selectPageDown(launcher.visibleRows) : controller.selectPageUp(launcher.visibleRows);
                                return;
                            case Qt.Key_J:
                            case Qt.Key_N:
                                if (ctrl) {
                                    // The Reaver's list grows upward, so "down" is the previous row there
                                    if (event.key === Qt.Key_J)
                                        launcher.rv ? controller.selectPrevious() : controller.selectNext();
                                    else
                                        launcher.rv ? controller.selectPreviousSection() : controller.selectNextSection();
                                    return;
                                }
                                event.accepted = false;
                                return;
                            case Qt.Key_K:
                            case Qt.Key_P:
                                if (ctrl) {
                                    if (event.key === Qt.Key_K)
                                        launcher.rv ? controller.selectNext() : controller.selectPrevious();
                                    else
                                        launcher.rv ? controller.selectNextSection() : controller.selectPreviousSection();
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
                                    const pos = at ? at.mapToItem(panel, 60, at.height / 2) : Qt.point(panel.width / 2, listArea.y);
                                    launcher.showContextMenu(controller.selectedItem, pos.x, pos.y, true);
                                    return;
                                }
                            default:
                                event.accepted = false;
                            }
                        }

                        Text {
                            visible: input.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: launcher.tx("Let there be light…")
                            font: input.font
                            color: Theme.withAlpha(launcher.pal.ink, 0.4)
                        }
                    }

                    // Where the chosen row stands; the Reaver keeps his keys here instead
                    Text {
                        id: trailing
                        anchors.verticalCenter: parent.verticalCenter
                        text: launcher.rv ? "↑↓ nav · ↵ open" + (actionPanel.hasActions ? " · tab actions" : "") + " · ctrl+tab mode" : launcher.position()
                        font.family: "Chakra Petch"
                        font.pixelSize: launcher.rv ? 12 : 13
                        color: launcher.pal.mut
                    }
                }
            }

            // ── heading: the section and the count ──

            Item {
                id: heading
                x: searchBox.x + (launcher.ph ? 4 : 0)
                y: launcher.rv ? 40 : searchBox.y + searchBox.height + 12
                width: searchBox.width - (launcher.ph ? 8 : 0)
                height: 22

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: launcher.rv ? "reason · launcher" : launcher.sectionLine
                    font.family: launcher.kh ? "Cinzel" : "Chakra Petch"
                    font.pixelSize: launcher.rv ? 14 : 11
                    font.weight: launcher.rv ? Font.Normal : Font.DemiBold
                    font.letterSpacing: launcher.rv ? 0 : 1.8
                    font.capitalization: launcher.rv ? Font.MixedCase : Font.AllUppercase
                    color: launcher.pal.cap
                }

                Text {
                    visible: !launcher.editMode
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: launcher.rv ? launcher.tx(launcher.sectionLine + (launcher.sectionLine ? " · " : "") + launcher.position()) : (controller.canCollapseSection(controller.sections?.[0]?.id ?? "") ? "collapse" : "")
                    font.family: "Chakra Petch"
                    font.pixelSize: 13
                    color: launcher.pal.mut

                    MouseArea {
                        anchors.fill: parent
                        enabled: !launcher.rv
                        cursorShape: Qt.PointingHandCursor
                        onClicked: controller.toggleSection(controller.sections?.[0]?.id ?? "")
                    }
                }
            }

            // ── results ──

            Column {
                id: listArea
                x: launcher.kh ? 28 : (launcher.rv ? 22 : 18)
                y: heading.y + heading.height + 6
                width: face.width - x - (launcher.kh ? 20 : x)
                height: footer.y - y - 6
                spacing: 8
                visible: !launcher.editMode

                // Plugin categories, as stock shows them for plugins that have some
                DW.DDropdown {
                    id: categories
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
                    id: fileFilters
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
                    height: Math.max(launcher.rowHeight, listArea.height - (actionPanel.visible ? actionPanel.height + 8 : 0) - (categories.visible ? categories.height + 8 : 0) - (fileFilters.visible ? fileFilters.height + 8 : 0))

                    ListView {
                        id: list
                        anchors.fill: parent
                        clip: true
                        model: launcher.flat
                        boundsBehavior: Flickable.StopAtBounds
                        currentIndex: controller.selectedFlatIndex
                        verticalLayoutDirection: launcher.rv ? ListView.BottomToTop : ListView.TopToBottom

                        delegate: Item {
                            id: row
                            required property var modelData
                            required property int index
                            readonly property var item: modelData.item ?? null
                            readonly property bool header: !!modelData.isHeader
                            readonly property bool current: !header && controller.selectedFlatIndex === index
                            readonly property int place: index - (modelData.sectionIndex ?? 0)
                            readonly property string sub: String(item?.subtitle ?? "")
                            readonly property string preview: {
                                const raw = item?.data?.imageUrl || item?.data?.imagePath || "";
                                return raw.startsWith("/") ? "file://" + raw : raw;
                            }
                            width: ListView.view.width
                            height: header ? launcher.headerHeight : launcher.rowHeight

                            // ── section header: title and count; click folds it when stock allows ──
                            Row {
                                visible: row.header
                                x: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: launcher.tx(row.modelData.section?.title ?? "")
                                    font.family: launcher.kh ? "Cinzel" : "Chakra Petch"
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: launcher.rv ? 0 : 1.6
                                    font.capitalization: launcher.rv ? Font.MixedCase : Font.AllUppercase
                                    color: launcher.pal.cap
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: String(row.modelData.section?.items?.length ?? 0)
                                    font.family: "Chakra Petch"
                                    font.pixelSize: 11
                                    color: launcher.pal.mut
                                }
                            }

                            DW.DIcon {
                                visible: row.header && controller.canCollapseSection(row.modelData.sectionId)
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                name: row.modelData.section?.collapsed ? "expand_more" : "expand_less"
                                size: 16
                                color: launcher.pal.mut
                            }

                            // ── the chosen row: Phainon's gold wash, Khaslana's red, the Reaver's outline ──
                            Rectangle {
                                visible: row.current
                                anchors.fill: parent
                                anchors.topMargin: 1
                                anchors.bottomMargin: 1
                                radius: launcher.ph ? 12 : 0
                                color: launcher.rv ? "#2E2650" : "transparent"
                                border.width: launcher.rv ? 1 : 0
                                border.color: "#B9A8FF"
                                gradient: launcher.rv ? null : (launcher.kh ? khSel : phSel)

                                Gradient {
                                    id: khSel
                                    orientation: Gradient.Horizontal
                                    GradientStop {
                                        position: 0
                                        color: "#8E1424"
                                    }
                                    GradientStop {
                                        position: 0.7
                                        color: "#3A0A12"
                                    }
                                    GradientStop {
                                        position: 1
                                        color: "transparent"
                                    }
                                }

                                Gradient {
                                    id: phSel
                                    orientation: Gradient.Horizontal
                                    GradientStop {
                                        position: 0
                                        color: launcher.parch ? Qt.rgba(241 / 255, 218 / 255, 79 / 255, 0.42) : Theme.withAlpha(Theme.primary, 0.3)
                                    }
                                    GradientStop {
                                        position: 1
                                        color: launcher.parch ? Qt.rgba(241 / 255, 218 / 255, 79 / 255, 0.08) : Theme.withAlpha(Theme.primary, 0.05)
                                    }
                                }

                                Rectangle {
                                    visible: !launcher.rv
                                    width: 3
                                    height: parent.height
                                    color: launcher.kh ? "#F2C75C" : launcher.pal.accent
                                }
                            }

                            // Khaslana's acts are parted by a thin rule
                            Rectangle {
                                visible: launcher.kh && !row.header
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: 1
                                color: launcher.pal.rim
                            }

                            Item {
                                visible: !row.header
                                anchors.fill: parent
                                opacity: (row.item?.type === "dmenu" && row.item?.data?.nonSelectable) ? 0.5 : 1

                                // Khaslana numbers his acts in Roman, the Flame Reaver in two digits
                                Text {
                                    visible: launcher.kh || launcher.rv
                                    x: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: launcher.kh ? 34 : 28
                                    horizontalAlignment: launcher.kh ? Text.AlignRight : Text.AlignLeft
                                    text: launcher.kh ? launcher.roman(row.place) : String(row.place).padStart(2, "0")
                                    font.family: launcher.kh ? "Cinzel" : "Chakra Petch"
                                    font.pixelSize: launcher.kh ? 12 : 13
                                    font.weight: launcher.kh ? Font.DemiBold : Font.Normal
                                    color: launcher.kh ? "#B0824A" : (row.current ? "#B9A8FF" : launcher.pal.mut)
                                }

                                Item {
                                    id: iconBox
                                    x: launcher.kh ? 50 : (launcher.rv ? 40 : 12)
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: launcher.rv ? 22 : 40
                                    height: width

                                    DW.AppIconRenderer {
                                        anchors.fill: parent
                                        iconValue: launcher.iconValue(row.item)
                                        iconSize: iconBox.width
                                        iconColor: launcher.pal.accent
                                        fallbackText: (row.item?.name?.length > 0) ? row.item.name.charAt(0).toUpperCase() : "?"
                                        fallbackRadius: launcher.ph ? 11 : 2
                                        fallbackBackgroundColor: Theme.withAlpha(launcher.pal.accent, 0.2)
                                        fallbackTextColor: launcher.pal.accent
                                    }
                                }

                                // Phainon and Khaslana: the name over its note
                                Column {
                                    visible: !launcher.rv
                                    x: iconBox.x + iconBox.width + 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: trail.x - x - 10
                                    spacing: 1

                                    Text {
                                        width: parent.width
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        text: row.item?.name ?? ""
                                        font.family: launcher.body
                                        font.pixelSize: 16
                                        color: row.item?.data?.urgent ? Theme.error : (row.current ? launcher.pal.selInk : launcher.pal.ink)
                                    }

                                    Text {
                                        visible: row.sub !== ""
                                        width: parent.width
                                        elide: row.item?.type === "file" ? Text.ElideLeft : Text.ElideRight
                                        maximumLineCount: 1
                                        text: row.sub
                                        font.family: launcher.body
                                        font.pixelSize: 13
                                        color: launcher.pal.mut
                                    }
                                }

                                // The Flame Reaver: name and note on one lowercase line, the chosen name glitched
                                Item {
                                    id: rvNameBox
                                    visible: launcher.rv
                                    x: iconBox.x + iconBox.width + 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(340, (trail.x - x) * 0.5)
                                    height: rvName.implicitHeight

                                    Repeater {
                                        model: row.current && launcher.rv ? [[2, Qt.rgba(143 / 255, 123 / 255, 224 / 255, 0.85)], [-2, Qt.rgba(79 / 255, 209 / 255, 197 / 255, 0.55)]] : []

                                        Text {
                                            required property var modelData
                                            x: modelData[0]
                                            width: rvName.width
                                            elide: Text.ElideRight
                                            text: rvName.text
                                            font: rvName.font
                                            color: modelData[1]
                                        }
                                    }

                                    Text {
                                        id: rvName
                                        width: parent.width
                                        elide: Text.ElideRight
                                        text: String(row.item?.name ?? "").trim().toLowerCase()
                                        font.family: "Chakra Petch"
                                        font.pixelSize: 15
                                        color: row.current ? launcher.pal.selInk : launcher.pal.ink
                                    }
                                }

                                Text {
                                    visible: launcher.rv
                                    x: rvNameBox.x + rvNameBox.width + 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: trail.x - x - 10
                                    elide: Text.ElideRight
                                    text: row.sub.trim().toLowerCase()
                                    font.family: "Chakra Petch"
                                    font.pixelSize: 14
                                    color: launcher.pal.mut
                                }

                                // Pinned mark, picture preview, kind of result, and the open hint on the chosen row
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
                                        color: launcher.pal.mut
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

                                    Text {
                                        readonly property string kind: launcher.badge(row.item)
                                        visible: kind !== ""
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: launcher.tx(kind)
                                        font.family: "Chakra Petch"
                                        font.pixelSize: 12
                                        color: launcher.pal.mut
                                    }

                                    Text {
                                        visible: row.current && !launcher.rv
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: launcher.ph ? "↵ open" : "↵"
                                        font.family: "Chakra Petch"
                                        font.pixelSize: 12
                                        color: launcher.kh ? "#F5D27A" : launcher.pal.cap
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

                    Text {
                        visible: launcher.itemCount <= 0
                        x: 12
                        y: launcher.rv ? parent.height - height : 0
                        height: launcher.rowHeight
                        verticalAlignment: Text.AlignVCenter
                        text: launcher.tx(controller.isFileSearching ? "Searching…" : launcher.emptyText())
                        font.family: launcher.body
                        font.pixelSize: 15
                        color: launcher.pal.mut
                    }
                }

                // Stock's action bar for the chosen result (Tab), framed per form
                ActionPanel {
                    id: actionPanel
                    width: parent.width
                    selectedItem: controller.selectedItem
                    controller: controller
                    color: launcher.rv ? "transparent" : Theme.withAlpha(launcher.pal.ink, 0.05)
                    border.width: launcher.kh ? 1 : 0
                    border.color: launcher.pal.accent
                    radius: launcher.ph ? 16 : 0
                }
            }

            // Stock's app editor (rename, icon, comment, env, flags) in place of the list
            Loader {
                id: editLoader
                x: searchBox.x
                y: listArea.y
                width: searchBox.width
                height: Math.min(item ? item.implicitHeight : 0, footer.y - y)
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

            // ── modes and keys ──

            Item {
                id: footer
                visible: !launcher.editMode
                y: launcher.rv ? searchBox.y - height : face.height - height
                width: face.width
                height: launcher.rv ? 36 : 56

                Rectangle {
                    x: launcher.rv ? 30 : 0
                    width: parent.width - x * 2
                    height: 1
                    color: launcher.kh ? "#E0B04A" : launcher.pal.rim
                }

                Row {
                    x: launcher.kh ? 34 : (launcher.rv ? 30 : 26)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: launcher.rv ? 18 : 6

                    Repeater {
                        model: launcher.modes

                        Item {
                            id: tab
                            required property string modelData
                            readonly property bool current: controller.searchMode === modelData
                            width: tabText.implicitWidth + (launcher.rv ? 0 : 24)
                            height: 26

                            Rectangle {
                                visible: !launcher.rv
                                anchors.fill: parent
                                radius: launcher.ph ? 13 : 0
                                color: tab.current ? (launcher.kh ? "#8E1424" : launcher.pal.lapis) : "transparent"
                                border.width: 1
                                border.color: tab.current ? (launcher.kh ? "#F2C75C" : launcher.pal.lapis) : (launcher.kh ? "#8A5A2B" : launcher.pal.rim)
                            }

                            Text {
                                id: tabText
                                anchors.centerIn: parent
                                text: launcher.rv ? (tab.current ? "[" + tab.modelData + "]" : tab.modelData) : launcher.tabName(tab.modelData)
                                font.family: launcher.kh ? "Cinzel" : (launcher.ph ? launcher.body : "Chakra Petch")
                                font.pixelSize: launcher.kh ? 11 : 13
                                font.weight: launcher.kh ? Font.DemiBold : Font.Normal
                                font.letterSpacing: launcher.kh ? 1.3 : 0
                                font.capitalization: launcher.kh ? Font.AllUppercase : Font.MixedCase
                                color: tab.current ? (launcher.kh ? "#F5D27A" : (launcher.rv ? "#F2EEE0" : (launcher.parch ? "#F7F3E8" : Theme.primaryText))) : (launcher.rv ? launcher.pal.mut : launcher.pal.ink)
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

                Text {
                    visible: !launcher.rv
                    anchors.right: parent.right
                    anchors.rightMargin: 26
                    anchors.verticalCenter: parent.verticalCenter
                    // Khaslana's drawer is narrow: the short form keeps clear of the tabs
                    text: launcher.kh ? "↑↓ · ↵ · Tab · Ctrl+Tab" : "↑↓ nav · ↵ open" + (actionPanel.hasActions ? " · Tab actions" : "") + " · Ctrl+Tab mode"
                    font.family: "Chakra Petch"
                    font.pixelSize: 12
                    color: launcher.pal.mut
                }
            }
        }
    }
}
