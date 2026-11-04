import QtQml
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Widgets as Cf
import "../Common/KeyUtils.js" as KeyUtils
import "../Common/KeybindActions.js" as Actions

FocusScope {
    id: content
    focus: true

    function getBindLabel(bind) {
        if (!bind)
            return "";
        var label = bind.desc || "";
        if (!label && bind.action) {
            label = Actions.getActionLabel(bind.action, KeybindsService.currentProvider) || bind.action;
        }
        if (!label)
            return "";
        if (label.includes("(by index)") && bind.action) {
            var parts = bind.action.trim().split(/\s+/);
            if (parts.length > 1) {
                var arg = parts[parts.length - 1];
                label = label.replace("(by index)", arg).trim();
            }
        }
        if ((bind.action === "next-window" || bind.action === "previous-window") && (bind.key || "").toLowerCase().includes("grave")) {
            if (label === "Next Window")
                label = "Next Window (Same Application)";
            else if (label === "Previous Window")
                label = "Previous Window (Same Application)";
        }
        if (label.startsWith("Media: "))
            label = label.slice(7).trim();
        return label;
    }

    Component {
        id: keybindItemDelegate

        DListItem {
            id: keybindRow
            required property var modelData
            readonly property bool canExecute: !keybindRow.modelData.isRange && KeybindsService.canExecuteAction(keybindRow.modelData.action, keybindRow.modelData.luaAction)

            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            implicitHeight: Math.max(Theme.menuItemHeight, keycapsCol.implicitHeight + Theme.spacingS * 2)
            firstInGroup: true
            lastInGroup: true
            radius: Theme.groupedListOuterRadius
            Accessible.name: keybindRow.modelData.label || content.getBindLabel(keybindRow.modelData)
            Accessible.description: (keybindRow.modelData.allKeys ? keybindRow.modelData.allKeys.join(", ") : (keybindRow.modelData.key || "")) + " • " + (keybindRow.modelData.action || "")
            onClicked: {
                if (keybindRow.canExecute && KeybindsService.executeAction(keybindRow.modelData.action, keybindRow.modelData.luaAction))
                    content.closeRequested();
            }

            RowLayout {
                id: rowLayout
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingM
                anchors.rightMargin: Theme.spacingS
                anchors.topMargin: Theme.spacingXS
                anchors.bottomMargin: Theme.spacingXS
                spacing: Theme.spacingS

                // Description / Action (Leading)
                StyledText {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: keybindRow.modelData.label || content.getBindLabel(keybindRow.modelData)
                    font.pixelSize: Theme.fontSizeSmall
                    color: keybindRow.contentColor
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }

                // DKeycap items (Trailing - stacked vertically if multiple combos)
                Column {
                    id: keycapsCol
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                    spacing: Theme.spacingXS

                    Repeater {
                        model: keybindRow.modelData.keyCombos || (keybindRow.modelData.key ? [KeyUtils.formatKeyTokens(keybindRow.modelData.key, KeybindsService.modKey, KeybindsService.modSymbol)] : [])

                        Row {
                            anchors.right: parent ? parent.right : undefined
                            spacing: Theme.spacingXXS

                            Repeater {
                                model: modelData

                                DKeycap {
                                    text: modelData
                                    textColor: Theme.primary
                                }
                            }
                        }
                    }
                }
            }

            MouseArea {
                id: rowHoverArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                cursorShape: keybindRow.canExecute ? Qt.PointingHandCursor : Qt.ArrowCursor
            }

            DTooltipHost {
                text: keybindRow.canExecute ? ((keybindRow.modelData.action || keybindRow.modelData.desc || "") + " • " + I18n.tr("Click to run", "cheatsheet action tooltip suffix")) : (keybindRow.modelData.label || keybindRow.modelData.action || keybindRow.modelData.desc || "")
                target: keybindRow
                hoverArea: rowHoverArea
            }
        }
    }

    // ── Coreflame: tabs, three columns, one ruled row per bind ──
    function cfRoman(n) {
        let out = "";
        for (const [glyph, value] of [["X", 10], ["IX", 9], ["V", 5], ["IV", 4], ["I", 1]]) {
            for (; n >= value; n -= value)
                out += glyph;
        }
        return out;
    }

    // Three columns of captions and binds. "All" keeps each category whole, in the shortest
    // column so far; one category is cut into three runs.
    readonly property var cfColumnEntries: {
        if (!cf)
            return [[], [], []];
        const model = dataModel;
        const entriesOf = name => {
            const info = model.byCategory[name];
            let out = [
                {
                    "kind": "cap",
                    "text": I18n.tr(name)
                }
            ];
            for (const sub of info.subcatKeys) {
                if (sub !== "_root")
                    out = out.concat([
                        {
                            "kind": "sub",
                            "text": I18n.tr(sub)
                        }
                    ]);
                out = out.concat(info.subcats[sub].map(bind => ({
                            "kind": "bind",
                            "bind": bind
                        })));
            }
            return out;
        };
        if (selectedCategory === "All") {
            return model.sortedKeys.reduce((cols, name) => {
                const shortest = cols.reduce((best, col, i) => col.length < cols[best].length ? i : best, 0);
                return cols.map((col, i) => i === shortest ? col.concat(entriesOf(name)) : col);
            }, [[], [], []]);
        }
        if (!model.byCategory[selectedCategory])
            return [[], [], []];
        const entries = entriesOf(selectedCategory);
        const per = Math.ceil(entries.length / 3);
        return [entries.slice(0, per), entries.slice(per, per * 2), entries.slice(per * 2)];
    }

    // The categories as the form's tabs: Phainon capsules, Khaslana numbered plates, Reaver numbered slips
    Component {
        id: cfTabs

        Flickable {
            contentWidth: tabRow.implicitWidth
            contentHeight: height
            clip: true
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds

            Row {
                id: tabRow
                height: parent.height
                spacing: 6

                Repeater {
                    model: ["All"].concat(content.dataModel.sortedKeys)

                    Item {
                        id: tab
                        required property string modelData
                        required property int index
                        readonly property bool on: content.selectedCategory === modelData

                        width: tabWords.implicitWidth + 28
                        height: 28
                        anchors.verticalCenter: parent.verticalCenter
                        Accessible.role: Accessible.PageTab
                        Accessible.name: I18n.tr(modelData)

                        Rectangle {
                            visible: Form.phainon
                            anchors.fill: parent
                            radius: height / 2
                            color: tab.on ? "#334786" : "#FBF9F3"
                            border.width: 1
                            border.color: tab.on ? "#334786" : "#DCCDA6"
                        }

                        Rectangle {
                            visible: Form.khaslana && tab.on
                            x: 3
                            y: 3
                            width: parent.width
                            height: parent.height
                            color: "#3A0A12"
                        }

                        Rectangle {
                            visible: Form.khaslana
                            anchors.fill: parent
                            color: tab.on ? "#8E1424" : "transparent"
                            border.width: 1
                            border.color: tab.on ? "#F2C75C" : "#8A5A2B"
                        }

                        Cf.CfQuad {
                            visible: Form.reaver
                            anchors.fill: parent
                            points: [[0, 0], [1, 0.1], [0.96, 1], [0.03, 0.9]]
                            fill: tab.on ? "#8F7BE0" : "#1C1828"
                        }

                        Row {
                            id: tabWords
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                visible: Form.khaslana
                                anchors.verticalCenter: parent.verticalCenter
                                text: content.cfRoman(tab.index + 1)
                                font.family: "Cinzel"
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                color: tab.on ? "#F5D27A" : "#B0824A"
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: (Form.reaver ? (tab.index + 1) + " " : "") + I18n.tr(tab.modelData)
                                font.family: Form.phainon ? "Marcellus" : (Form.khaslana ? "Cinzel" : "Chakra Petch")
                                font.pixelSize: Form.khaslana ? 11 : 13
                                font.weight: Form.khaslana || (Form.reaver && tab.on) ? Font.DemiBold : Font.Normal
                                font.letterSpacing: Form.khaslana ? 1.3 : 0
                                font.capitalization: Form.khaslana ? Font.AllUppercase : (Form.reaver ? Font.AllLowercase : Font.MixedCase)
                                color: Form.phainon ? (tab.on ? "#F7F3E8" : "#1E2752") : (Form.khaslana ? (tab.on ? "#F5D27A" : "#F3E6CC") : (tab.on ? "#0D0B14" : "#E9E7F2"))
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: content.selectedCategory = tab.modelData
                        }
                    }
                }
            }
        }
    }

    Component {
        id: cfKeyColumns

        Row {
            id: cols
            readonly property real colWidth: (width - spacing * 2) / 3
            spacing: 28

            Repeater {
                model: content.cfColumnEntries

                Column {
                    id: col
                    required property var modelData
                    width: cols.colWidth

                    Repeater {
                        model: col.modelData
                        delegate: cfEntry
                    }
                }
            }
        }
    }

    // One line of a column: a category caption, a subcategory label, or a bind over its rule
    Component {
        id: cfEntry

        Item {
            id: entry
            required property var modelData
            readonly property bool isBind: modelData.kind === "bind"
            readonly property var bind: modelData.bind ?? ({})
            readonly property bool canExecute: isBind && !bind.isRange && KeybindsService.canExecuteAction(bind.action, bind.luaAction)
            readonly property string label: isBind ? (bind.label || content.getBindLabel(bind)) : ""

            width: parent ? parent.width : 0
            height: isBind ? Math.max(32, keys.implicitHeight + 12) : caption.implicitHeight + (modelData.kind === "cap" ? 18 : 10)
            Accessible.role: isBind ? Accessible.Button : Accessible.Heading
            Accessible.name: isBind ? label : modelData.text
            Accessible.description: isBind ? (bind.allKeys ? bind.allKeys.join(", ") : (bind.key || "")) : ""

            Text {
                id: caption
                visible: !entry.isBind
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6
                width: parent.width
                elide: Text.ElideRight
                text: (Form.reaver && entry.modelData.kind === "cap" ? "// " : "") + (entry.modelData.text ?? "")
                font.family: Form.khaslana ? "Cinzel" : "Chakra Petch"
                font.pixelSize: entry.modelData.kind === "cap" && !Form.phainon ? 12 : 11
                font.weight: Font.DemiBold
                font.letterSpacing: Form.khaslana ? 2.6 : (Form.reaver ? 1.7 : 1.76)
                font.capitalization: Font.AllUppercase
                color: Form.khaslana ? "#E0B04A" : (Form.reaver ? (entry.modelData.kind === "cap" ? "#B9A8FF" : "#6E6A84") : "#8A6418")
            }

            Column {
                id: keys
                visible: entry.isBind
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Repeater {
                    model: entry.isBind ? (entry.bind.keyCombos || (entry.bind.key ? [KeyUtils.formatKeyTokens(entry.bind.key, KeybindsService.modKey, KeybindsService.modSymbol)] : [])) : []

                    Row {
                        id: combo
                        required property var modelData
                        spacing: 4

                        Repeater {
                            model: combo.modelData

                            Row {
                                id: token
                                required property var modelData
                                required property int index
                                spacing: 4

                                Text {
                                    visible: token.index > 0
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "+"
                                    font.family: "Chakra Petch"
                                    font.pixelSize: 12
                                    color: Form.phainon ? "#4A5484" : (Form.khaslana ? "#C9B89E" : "#6E6A84")
                                }

                                DKeycap {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Form.reaver ? String(token.modelData).toLowerCase() : token.modelData
                                    textColor: Theme.primary
                                }
                            }
                        }
                    }
                }
            }

            Text {
                visible: entry.isBind
                anchors.left: keys.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                text: entry.label
                font.family: Form.phainon ? Form.numerals : "Chakra Petch"
                font.pixelSize: 14
                font.capitalization: Form.reaver ? Font.AllLowercase : Font.MixedCase
                color: Form.phainon ? "#1E2752" : (Form.khaslana ? "#F3E6CC" : "#E9E7F2")
            }

            Rectangle {
                visible: entry.isBind
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Form.phainon ? "#ECE3CC" : (Form.khaslana ? "#2E1A1A" : "#2C2840")
            }

            MouseArea {
                id: entryArea
                anchors.fill: parent
                enabled: entry.isBind
                hoverEnabled: true
                cursorShape: entry.canExecute ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (entry.canExecute && KeybindsService.executeAction(entry.bind.action, entry.bind.luaAction))
                        content.closeRequested();
                }
            }

            DTooltipHost {
                text: entry.canExecute ? ((entry.bind.action || entry.bind.desc || "") + " • " + I18n.tr("Click to run", "cheatsheet action tooltip suffix")) : (entry.label || entry.bind.action || entry.bind.desc || "")
                target: entry
                hoverArea: entryArea
            }
        }
    }

    property real scrollStep: 60
    property var activeFlickable: rightFlickable
    property bool showFloatingToggle: true
    property bool floating: false
    property alias searchField: searchField
    property string selectedCategory: "All"
    property bool searchFocused: false
    // Coreflame: "Law · Keys" on top, the categories as the form's tabs beside the search, the
    // binds in three columns over thin rules under each category's caption.
    readonly property bool cf: Form.active

    signal closeRequested
    signal floatingToggleRequested

    function scrollDown() {
        if (!activeFlickable)
            return;
        let newY = activeFlickable.contentY + scrollStep;
        newY = Math.min(newY, Math.max(0, activeFlickable.contentHeight - activeFlickable.height));
        activeFlickable.contentY = newY;
    }

    function scrollUp() {
        if (!activeFlickable)
            return;
        let newY = activeFlickable.contentY - scrollStep;
        newY = Math.max(0, newY);
        activeFlickable.contentY = newY;
    }

    function focusSearch() {
        if (searchField) {
            searchField.forceActiveFocus();
            searchField.selectAll();
        }
    }

    function captureShortcut(event) {
        if (!searchFocused)
            return false;
        const chord = KeyUtils.shortcutFromSearchKey(event, KeybindsService.modKey, KeybindsService.modSymbol);
        if (!chord)
            return false;
        if (ownToggleCombos().includes(KeyUtils.normalizeKeyCombo(chord, KeybindsService.modKey, KeybindsService.modSymbol))) {
            closeRequested();
            return true;
        }
        searchField.text = chord;
        return true;
    }

    // the bind that opened the cheatsheet keeps closing it instead of becoming a search
    function ownToggleCombos() {
        const combos = [];
        for (const cat in rawBinds) {
            const binds = rawBinds[cat];
            if (!Array.isArray(binds))
                continue;
            for (let i = 0; i < binds.length; i++) {
                if (/\bkeybinds (toggle|close)\b/.test(binds[i].action || ""))
                    combos.push(KeyUtils.normalizeKeyCombo(binds[i].key, KeybindsService.modKey, KeybindsService.modSymbol));
            }
        }
        return combos;
    }

    ShortcutInhibitor {
        id: searchInhibitor
        window: content.QsWindow.window
        enabled: content.searchFocused
    }

    Shortcut {
        sequence: "Ctrl+F"
        onActivated: content.focusSearch()
    }

    Keys.onPressed: event => {
        if (captureShortcut(event)) {
            event.accepted = true;
            return;
        }
        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_F) {
            focusSearch();
            event.accepted = true;
            return;
        }
        switch (event.key) {
        case Qt.Key_J:
            if (event.modifiers & Qt.ControlModifier) {
                scrollDown();
                event.accepted = true;
            }
            return;
        case Qt.Key_K:
            if (event.modifiers & Qt.ControlModifier) {
                scrollUp();
                event.accepted = true;
            }
            return;
        case Qt.Key_Down:
            scrollDown();
            event.accepted = true;
            return;
        case Qt.Key_Up:
            scrollUp();
            event.accepted = true;
            return;
        }
    }

    readonly property var categoryPriority: ({
            "window": 1,
            "windows": 1,
            "window management": 1,
            "workspace": 2,
            "workspaces": 2,
            "applications": 3,
            "apps": 3,
            "audio": 4,
            "sound": 4,
            "media": 5,
            "brightness": 6,
            "dms": 7,
            "compositor": 8,
            "custom": 9,
            "system": 10
        })

    function getCategoryIcon(catName) {
        if (!catName)
            return "keyboard";
        const lower = catName.toLowerCase();
        if (lower === "all")
            return "apps";
        if (lower.includes("window"))
            return "desktop_windows";
        if (lower.includes("workspace"))
            return "grid_view";
        if (lower.includes("alt-tab") || lower.includes("alt_tab") || lower.includes("switcher"))
            return "swap_horiz";
        if (lower.includes("screenshot") || lower.includes("capture"))
            return "screenshot_region";
        if (lower.includes("overview"))
            return "overview";
        if (lower.includes("monitor") || lower.includes("display"))
            return "monitor";
        if (lower.includes("exec") || lower.includes("terminal") || lower.includes("spawn") || lower.includes("command"))
            return "terminal";
        if (lower.includes("scratchpad"))
            return "sticky_note_2";
        if (lower.includes("layout"))
            return "view_quilt";
        if (lower.includes("gap"))
            return "border_inner";
        if (lower.includes("tag"))
            return "tag";
        if (lower.includes("app"))
            return "open_in_new";
        if (lower.includes("audio") || lower.includes("sound") || lower.includes("media"))
            return "volume_up";
        if (lower.includes("bright"))
            return "brightness_6";
        if (lower.includes("dms"))
            return "widgets";
        if (lower.includes("system") || lower.includes("power"))
            return "power_settings_new";
        if (lower.includes("compositor"))
            return "tune";
        if (lower.includes("custom"))
            return "edit";
        if (lower.includes("other"))
            return "more_horiz";
        return "keyboard";
    }

    property var rawBinds: KeybindsService.cheatsheet.binds || ({})

    function collapseSequentialBinds(list) {
        if (!list || list.length < 3)
            return list || [];
        const numberPattern = /^(.*?)(\s+)(\d+)$/;
        const clusters = {};

        for (let i = 0; i < list.length; i++) {
            const item = list[i];
            const match = (item.label || "").match(numberPattern);
            const combo = item.keyCombos && item.keyCombos[0];
            if (match && combo && combo.length > 0) {
                const lastToken = combo[combo.length - 1];
                const num = parseInt(match[3], 10);
                if (!isNaN(num) && lastToken === String(num)) {
                    const baseLabel = match[1];
                    const mods = combo.slice(0, -1);
                    const modSig = mods.join("+");
                    const clusterKey = (baseLabel + "||" + modSig).toLowerCase();
                    if (!clusters[clusterKey])
                        clusters[clusterKey] = [];
                    clusters[clusterKey].push({
                        item: item,
                        num: num,
                        baseLabel: baseLabel,
                        mods: mods,
                        index: i
                    });
                }
            }
        }

        const collapsedMap = {};
        const skipIndices = {};

        for (const cKey in clusters) {
            const cluster = clusters[cKey];
            if (cluster.length >= 3) {
                cluster.sort((a, b) => a.num - b.num);
                let isSeq = true;
                for (let k = 1; k < cluster.length; k++) {
                    if (cluster[k].num !== cluster[k - 1].num + 1) {
                        isSeq = false;
                        break;
                    }
                }
                if (isSeq) {
                    const first = cluster[0];
                    const last = cluster[cluster.length - 1];
                    const rangeStr = first.num + "–" + last.num;
                    const combinedLabel = first.baseLabel + " " + rangeStr;
                    const allKeys = [];
                    for (let k = 0; k < cluster.length; k++) {
                        if (cluster[k].item.allKeys) {
                            for (let ak = 0; ak < cluster[k].item.allKeys.length; ak++) {
                                allKeys.push(cluster[k].item.allKeys[ak]);
                            }
                        } else if (cluster[k].item.key) {
                            allKeys.push(cluster[k].item.key);
                        }
                        if (k > 0) {
                            skipIndices[cluster[k].index] = true;
                        }
                    }
                    collapsedMap[first.index] = {
                        action: "",
                        desc: combinedLabel,
                        label: combinedLabel,
                        key: first.item.key,
                        allKeys: allKeys,
                        tokenSigs: {},
                        keyCombos: [[...first.mods, rangeStr]],
                        isRange: true
                    };
                }
            }
        }

        const result = [];
        for (let i = 0; i < list.length; i++) {
            if (collapsedMap[i]) {
                result.push(collapsedMap[i]);
            } else if (!skipIndices[i]) {
                result.push(list[i]);
            }
        }
        return result;
    }

    function generateCategories(query) {
        const lowerQuery = query ? query.toLowerCase().trim() : "";
        const lowerQueryWords = lowerQuery ? lowerQuery.split(/\s+/) : [];
        const processed = {};
        let totalCount = 0;

        for (const cat in rawBinds) {
            const binds = rawBinds[cat];
            if (!Array.isArray(binds))
                continue;
            const catLower = cat.toLowerCase();
            const subcatMap = {};
            let hasBinds = false;

            for (let i = 0; i < binds.length; i++) {
                const bind = binds[i];
                if (bind.hideOnOverlay)
                    continue;

                const label = content.getBindLabel(bind);
                const labelLower = label.toLowerCase();
                const keyTokens = KeyUtils.formatKeyTokens(bind.key, KeybindsService.modKey, KeybindsService.modSymbol);
                const tokenSig = keyTokens.join("+");
                const keyLower = (bind.key || "").toLowerCase();
                const keyCombo = KeyUtils.normalizeKeyCombo(bind.key, KeybindsService.modKey, KeybindsService.modSymbol);
                const descLower = (bind.desc || "").toLowerCase();
                const actionLower = (bind.action || "").toLowerCase();

                let matched = true;
                for (let j = 0; j < lowerQueryWords.length; j++) {
                    const word = lowerQueryWords[j];
                    if (!word)
                        continue;
                    if (!keyLower.includes(word) && !keyCombo.includes(KeyUtils.normalizeKeyCombo(word, KeybindsService.modKey, KeybindsService.modSymbol)) && !labelLower.includes(word) && !descLower.includes(word) && !catLower.includes(word) && !actionLower.includes(word) && !tokenSig.toLowerCase().includes(word)) {
                        matched = false;
                        break;
                    }
                }
                if (!matched)
                    continue;

                const subcatName = bind.subcat || "_root";
                if (!subcatMap[subcatName])
                    subcatMap[subcatName] = {};

                const isGraveAltTab = (bind.action === "next-window" || bind.action === "previous-window") && (bind.key || "").toLowerCase().includes("grave") && !bind.action.includes("filter=");
                const bindAction = isGraveAltTab ? (bind.action + ' filter="app-id"') : (bind.action || "");
                const groupKey = (label + "||" + bindAction).toLowerCase();
                if (subcatMap[subcatName][groupKey]) {
                    const existing = subcatMap[subcatName][groupKey];
                    if (tokenSig && !existing.tokenSigs[tokenSig] && keyTokens.length > 0) {
                        existing.tokenSigs[tokenSig] = true;
                        existing.keyCombos.push(keyTokens);
                        existing.allKeys.push(bind.key);
                    }
                } else {
                    const sigs = {};
                    if (tokenSig && keyTokens.length > 0)
                        sigs[tokenSig] = true;
                    subcatMap[subcatName][groupKey] = {
                        action: bindAction,
                        luaAction: bind.luaAction || "",
                        desc: bind.desc,
                        label: label,
                        key: bind.key,
                        allKeys: [bind.key],
                        tokenSigs: sigs,
                        keyCombos: keyTokens.length > 0 ? [keyTokens] : []
                    };
                    hasBinds = true;
                }
            }

            if (hasBinds) {
                const subcats = {};
                let catBindCount = 0;
                for (const subcatName in subcatMap) {
                    const groups = subcatMap[subcatName];
                    const rawList = [];
                    for (const gKey in groups) {
                        rawList.push(groups[gKey]);
                    }
                    const collapsedList = content.collapseSequentialBinds(rawList);
                    subcats[subcatName] = collapsedList;
                    catBindCount += collapsedList.length;
                }
                if (catBindCount > 0) {
                    processed[cat] = {
                        name: cat,
                        count: catBindCount,
                        subcats: subcats,
                        subcatKeys: Object.keys(subcats)
                    };
                    totalCount += catBindCount;
                }
            }
        }

        const keys = Object.keys(processed).sort((a, b) => {
            const pA = categoryPriority[a.toLowerCase()] || 99;
            const pB = categoryPriority[b.toLowerCase()] || 99;
            if (pA !== pB)
                return pA - pB;
            return a.localeCompare(b);
        });

        return {
            byCategory: processed,
            sortedKeys: keys,
            totalCount: totalCount
        };
    }

    property string activeSearchQuery: ""
    property var dataModel: generateCategories("")

    Connections {
        target: KeybindsService
        function onCheatsheetLoaded() {
            content.dataModel = content.generateCategories(content.activeSearchQuery);
        }
    }

    Timer {
        id: searchDebounce
        interval: 120
        repeat: false
        onTriggered: {
            content.activeSearchQuery = searchField.text;
            content.dataModel = content.generateCategories(searchField.text);
            if (searchField.text.trim() !== "" && content.selectedCategory !== "All") {
                if (!content.dataModel.byCategory[content.selectedCategory])
                    content.selectedCategory = "All";
            }
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: content.cf ? 24 : Theme.windowInset
        anchors.topMargin: content.floating ? 0 : (content.cf ? 20 : Theme.windowInset)

        Cf.CfDialogHead {
            id: cfHead
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            visible: content.cf
            glyph: "law"
            kind: I18n.tr("Keys")
            closable: true
            onCloseClicked: content.closeRequested()
        }

        // Sidebar (Coreflame: a bar of tabs and the search across the top)
        Item {
            id: sidebar
            anchors.left: parent.left
            anchors.top: content.cf ? cfHead.bottom : parent.top
            anchors.topMargin: content.cf ? 14 : 0
            anchors.bottom: content.cf ? undefined : parent.bottom
            width: content.cf ? parent.width : 260
            height: searchRow.height

            // Search Bar + Float Window Toggle at top of sidebar
            RowLayout {
                id: searchRow
                anchors.left: content.cf ? undefined : parent.left
                anchors.right: parent.right
                width: 280
                anchors.top: parent.top
                spacing: Theme.spacingS

                DSearchField {
                    id: searchField
                    Layout.fillWidth: true
                    placeholderText: I18n.tr("Search")
                    keyForwardTargets: [content]
                    onFocusStateChanged: hasFocus => content.searchFocused = hasFocus
                    onTextChanged: {
                        if (text.trim() === "") {
                            searchDebounce.stop();
                            content.activeSearchQuery = "";
                            content.dataModel = content.generateCategories("");
                        } else {
                            searchDebounce.restart();
                        }
                    }
                    Keys.onEscapePressed: event => {
                        content.closeRequested();
                        event.accepted = true;
                    }
                }

                DActionButton {
                    visible: content.showFloatingToggle
                    buttonSize: Theme.iconButtonSize
                    iconName: content.floating ? "close_fullscreen" : "open_in_new"
                    tooltipText: content.floating ? I18n.tr("Dock window") : I18n.tr("Open as window")
                    onClicked: content.floatingToggleRequested()
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            Loader {
                anchors.left: parent.left
                anchors.right: searchRow.left
                anchors.rightMargin: 16
                anchors.verticalCenter: searchRow.verticalCenter
                height: 30
                active: content.cf
                sourceComponent: cfTabs
            }

            DFlickable {
                id: sidebarFlickable
                visible: !content.cf
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: searchRow.bottom
                anchors.bottom: parent.bottom
                anchors.topMargin: Theme.spacingM
                contentWidth: width
                contentHeight: sidebarCol.implicitHeight
                clip: true

                Column {
                    id: sidebarCol
                    width: parent.width
                    spacing: Theme.spacingXXS

                    // "All" Category Tab
                    DListItem {
                        id: allTab
                        width: sidebarCol.width
                        implicitHeight: Theme.menuItemHeight
                        isSelected: content.selectedCategory === "All"
                        surfaceColor: "transparent"
                        border.width: 0
                        radius: Theme.cornerRadiusFull
                        topLeftRadius: Theme.cornerRadiusFull
                        topRightRadius: Theme.cornerRadiusFull
                        bottomLeftRadius: Theme.cornerRadiusFull
                        bottomRightRadius: Theme.cornerRadiusFull
                        Accessible.name: I18n.tr("All")
                        onClicked: content.selectedCategory = "All"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingL
                            anchors.rightMargin: Theme.spacingL
                            spacing: Theme.spacingS

                            DIcon {
                                name: "apps"
                                size: Theme.iconSizeSmall
                                color: allTab.contentColor
                            }

                            StyledText {
                                text: I18n.tr("All")
                                color: allTab.contentColor
                                font.weight: allTab.isSelected ? Theme.fontWeightMedium : Theme.fontWeight
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            DBadge {
                                text: content.dataModel.totalCount.toString()
                                color: allTab.isSelected ? Theme.primary : Theme.surfaceVariant
                                textColor: allTab.isSelected ? Theme.onPrimary : Theme.surfaceVariantText
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }
                    }

                    // Category Tabs
                    Repeater {
                        model: content.dataModel.sortedKeys

                        DListItem {
                            id: catTab
                            required property var modelData

                            readonly property string catName: modelData
                            readonly property var catInfo: content.dataModel.byCategory[catName]

                            width: sidebarCol.width
                            implicitHeight: Theme.menuItemHeight
                            isSelected: content.selectedCategory === catTab.catName
                            surfaceColor: "transparent"
                            border.width: 0
                            radius: Theme.cornerRadiusFull
                            topLeftRadius: Theme.cornerRadiusFull
                            topRightRadius: Theme.cornerRadiusFull
                            bottomLeftRadius: Theme.cornerRadiusFull
                            bottomRightRadius: Theme.cornerRadiusFull
                            Accessible.name: I18n.tr(catTab.catName)
                            onClicked: content.selectedCategory = catTab.catName

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingL
                                anchors.rightMargin: Theme.spacingL
                                spacing: Theme.spacingS

                                DIcon {
                                    name: content.getCategoryIcon(catTab.catName)
                                    size: Theme.iconSizeSmall
                                    color: catTab.contentColor
                                }

                                StyledText {
                                    text: I18n.tr(catTab.catName)
                                    color: catTab.contentColor
                                    font.weight: catTab.isSelected ? Theme.fontWeightMedium : Theme.fontWeight
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                DBadge {
                                    text: (catTab.catInfo?.count || 0).toString()
                                    color: catTab.isSelected ? Theme.primary : Theme.surfaceVariant
                                    textColor: catTab.isSelected ? Theme.onPrimary : Theme.surfaceVariantText
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }
                        }
                    }
                }
            }
        }

        // Main Content Area
        Item {
            id: mainArea
            anchors.left: content.cf ? parent.left : sidebar.right
            anchors.leftMargin: content.cf ? 0 : Theme.spacingL
            anchors.right: parent.right
            anchors.top: content.cf ? sidebar.bottom : parent.top
            anchors.topMargin: content.cf ? 16 : 0
            anchors.bottom: parent.bottom

            DFlickable {
                id: rightFlickable
                anchors.fill: parent
                contentWidth: width
                contentHeight: content.cf ? (cfColumns.item?.implicitHeight ?? 0) : contentCol.implicitHeight
                clip: true

                Loader {
                    id: cfColumns
                    width: rightFlickable.width - Theme.spacingS
                    active: content.cf
                    sourceComponent: cfKeyColumns
                }

                Column {
                    id: contentCol
                    visible: !content.cf
                    width: rightFlickable.width - Theme.spacingS
                    spacing: Theme.spacingL

                    // Categories Renderer
                    Repeater {
                        model: content.selectedCategory === "All" ? content.dataModel.sortedKeys : (content.dataModel.byCategory[content.selectedCategory] ? [content.selectedCategory] : [])

                        Column {
                            id: sectionCol
                            width: contentCol.width
                            spacing: Theme.spacingM

                            readonly property string sectionCatName: modelData
                            readonly property var sectionCatInfo: content.dataModel.byCategory[sectionCatName]

                            // Section Header
                            RowLayout {
                                width: parent.width
                                spacing: Theme.spacingS

                                DIcon {
                                    name: content.getCategoryIcon(sectionCol.sectionCatName)
                                    size: Theme.iconSizeMedium
                                    color: Theme.primary
                                }

                                StyledText {
                                    text: I18n.tr(sectionCol.sectionCatName)
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Theme.fontWeightMedium
                                    color: Theme.primary
                                }
                            }

                            // Subcategories Repeater
                            Repeater {
                                model: sectionCol.sectionCatInfo?.subcatKeys || []

                                Column {
                                    id: subcatCol
                                    width: sectionCol.width
                                    spacing: Theme.spacingXS

                                    readonly property string subcatName: modelData
                                    readonly property var subcatBinds: sectionCol.sectionCatInfo?.subcats?.[subcatName] || []

                                    // Subcategory Title (if not _root)
                                    StyledText {
                                        visible: subcatCol.subcatName !== "_root"
                                        text: I18n.tr(subcatCol.subcatName)
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Theme.fontWeightMedium
                                        color: Theme.surfaceVariantText
                                    }

                                    readonly property bool isTwoColumn: rightFlickable.width > 550

                                    // 2-Column Responsive Masonry Layout
                                    RowLayout {
                                        id: keybindsMasonry
                                        width: parent.width
                                        spacing: Theme.spacingM

                                        // Left Column
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignTop
                                            spacing: Theme.spacingXS

                                            Repeater {
                                                model: subcatCol.subcatBinds ? subcatCol.subcatBinds.filter((_, idx) => !subcatCol.isTwoColumn || idx % 2 === 0) : []
                                                delegate: keybindItemDelegate
                                            }
                                        }

                                        // Right Column
                                        ColumnLayout {
                                            visible: subcatCol.isTwoColumn
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignTop
                                            spacing: Theme.spacingXS

                                            Repeater {
                                                model: subcatCol.isTwoColumn && subcatCol.subcatBinds ? subcatCol.subcatBinds.filter((_, idx) => idx % 2 === 1) : []
                                                delegate: keybindItemDelegate
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Empty State
            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingM
                visible: content.dataModel.totalCount === 0

                DIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: content.activeSearchQuery.trim() !== "" ? "search_off" : "keyboard"
                    size: Theme.iconSizeLarge + Theme.spacingL
                    color: Theme.surfaceVariantText
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: content.activeSearchQuery.trim() !== "" ? I18n.tr("No results found") : I18n.tr("No keybinds found")
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Theme.fontWeightMedium
                    color: Theme.surfaceText
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: I18n.tr("Try a different search")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    visible: content.activeSearchQuery.trim() !== ""
                }
            }
        }
    }
}
