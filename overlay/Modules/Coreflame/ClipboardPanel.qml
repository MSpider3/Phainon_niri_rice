import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets as DW
import Quickshell.Widgets
import "Numerals.js" as Numerals

// Trickery: the clipboard history, opening out of the island like the launcher, in the form's
// window frame (CfSheet).
// Type to filter. Enter copies, Shift+Enter pastes, Delete removes, Ctrl+P pins.
PanelWindow {
    id: board

    required property var targetScreen
    property int strip: 40
    property bool shown: false
    property real opening: shown ? 1 : 0
    readonly property real reveal: Motion.step(opening)

    readonly property var entries: ClipboardService.clipboardEntries ?? []
    readonly property int visibleRows: 9
    // Sizes from the v3 mockup's clipboard per form
    readonly property real panelWidth: Form.khaslana ? 720 : (Form.reaver ? 740 : 760)
    readonly property real rowHeight: Form.reaver ? 34 : (Form.khaslana ? 46 : 44)
    readonly property real imageRowHeight: Form.reaver ? 86 : 108
    // Ids of pictures Qt could not decode: they get a text row and are not fetched again.
    property var badImages: ({})
    function showsImage(entry) {
        return entry.isImage && !badImages[entry.id];
    }

    function open() {
        if (NiriService.inOverview)
            NiriService.closeOverview();
        input.text = "";
        ClipboardService.searchText = "";
        shown = true;
        list.currentIndex = 0;
        input.forceActiveFocus();
    }

    function close() {
        shown = false;
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

    function current() {
        return entries[list.currentIndex] ?? null;
    }

    // Destroyed while open (a screen unplugged, another theme picked): release what opening took.
    Component.onDestruction: {
        if (shown)
            shown = false;
    }

    onShownChanged: {
        if (shown) {
            ClipboardService.refCount++;
            ClipboardService.refresh();
        } else {
            ClipboardService.refCount = Math.max(0, ClipboardService.refCount - 1);
        }
    }

    onEntriesChanged: list.currentIndex = Math.max(0, Math.min(list.currentIndex, entries.length - 1))

    screen: targetScreen
    visible: reveal > 0.001
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "coreflame:clipboard"
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
        color: Theme.withAlpha(Theme.background, 0.35 * board.reveal)

        MouseArea {
            anchors.fill: parent
            onClicked: board.close()
        }
    }

    Item {
        id: panel

        // Picture rows are taller, so the list is sized by what it holds, up to nine text rows.
        readonly property real listHeight: {
            const cap = board.visibleRows * board.rowHeight;
            let h = 0;
            for (let i = 0; i < board.entries.length && h < cap; i++)
                h += board.showsImage(board.entries[i]) ? board.imageRowHeight : board.rowHeight;
            return Math.max(board.rowHeight, Math.min(cap, h));
        }
        readonly property real searchHeight: Form.khaslana ? 50 : 46
        readonly property real fullHeight: sheet.headerHeight + searchHeight + 10 + listHeight + sheet.footerHeight

        x: Math.round((board.width - width) / 2)
        y: sheet.topFor(board.strip)
        width: Math.round(420 + (board.panelWidth - 420) * board.reveal)
        height: Math.round(60 + (fullHeight - 60) * board.reveal)

        // Swallow clicks on the whole sheet (header and hint too) so they don't close the window
        MouseArea {
            anchors.fill: parent
        }

        // Khaslana: the Black Tide's cubes falling from the plate's foot
        CfTide {
            visible: Form.khaslana
            y: parent.height + 8
            width: parent.width
            height: 150
            opacity: board.reveal
            seed: 21
            liquid: 0
            cubes: Form.khaslana ? 18 : 0
        }

        CfSheet {
            id: sheet
            anchors.fill: parent
            // Only while it opens: at rest Khaslana's red offset hangs outside the plate
            clip: board.reveal < 1
            title: Form.khaslana ? "Trickery" : "Trickery · Clipboard"
            glyph: "trickery"
            count: board.entries.length > 0 ? (list.currentIndex + 1) + " / " + board.entries.length : "0"
            hint: "↵ copy   Shift+↵ paste   Del remove   Ctrl+P pin   Esc close"

            // ── the search field ──
            Item {
                width: parent.width
                height: panel.searchHeight

                // Khaslana: a gold-edged box with a red offset
                Rectangle {
                    visible: Form.khaslana
                    x: 3
                    y: 3
                    width: parent.width
                    height: parent.height - 6
                    color: "#8E1424"
                }
                Rectangle {
                    visible: Form.khaslana
                    width: parent.width
                    height: parent.height - 6
                    color: "#160D10"
                    border.width: 1
                    border.color: "#E0B04A"
                }
                // Phainon: a gold underline; the Flame Reaver: a violet one
                Rectangle {
                    visible: !Form.khaslana
                    y: parent.height - height - 4
                    width: parent.width
                    height: Form.reaver ? 2 : 1.5
                    color: Form.reaver ? "#8F7BE0" : "#A87A22"
                }

                Row {
                    x: Form.khaslana ? 14 : 6
                    width: parent.width - 2 * x
                    height: parent.height - 6
                    spacing: 12

                    DW.DIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "search"
                        size: Form.reaver ? 17 : 20
                        color: Form.khaslana ? "#E0B04A" : (Form.reaver ? "#B9A8FF" : "#A87A22")
                    }

                    TextInput {
                        id: input
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 34
                        clip: true
                        font.family: Form.phainon ? "Marcellus" : (Form.active ? "Chakra Petch" : Theme.fontFamily)
                        font.pixelSize: Form.reaver ? 16 : 19
                        color: Theme.surfaceText
                        selectionColor: Theme.primary
                        selectedTextColor: Theme.primaryText
                        // The Flame Reaver's block cursor
                        cursorDelegate: Rectangle {
                            width: Form.reaver ? 9 : 2
                            color: Form.reaver ? "#B9A8FF" : (Form.khaslana ? "#F5D27A" : Theme.primary)
                            visible: input.cursorVisible
                        }
                        onTextChanged: {
                            ClipboardService.searchText = text;
                            ClipboardService.updateFilteredModel();
                            list.currentIndex = 0;
                        }

                        Keys.onEscapePressed: board.close()
                        Keys.onDownPressed: list.currentIndex = Math.min(board.entries.length - 1, list.currentIndex + 1)
                        Keys.onUpPressed: list.currentIndex = Math.max(0, list.currentIndex - 1)
                        Keys.onPressed: event => {
                            const entry = board.current();
                            if (!entry)
                                return;
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (event.modifiers & Qt.ShiftModifier)
                                    ClipboardService.pasteEntry(entry, () => board.close());
                                else
                                    ClipboardService.copyEntry(entry, () => board.close());
                                Coreflames.earn("trickery");
                            } else if (event.key === Qt.Key_Delete) {
                                ClipboardService.deleteEntry(entry);
                            } else if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
                                if (entry.pinned)
                                    ClipboardService.unpinEntry(entry);
                                else
                                    ClipboardService.pinEntry(entry);
                            } else {
                                return;
                            }
                            event.accepted = true;
                        }

                        Text {
                            visible: input.text === ""
                            // after the Flame Reaver's block cursor, not under it
                            x: Form.reaver ? 13 : 0
                            anchors.verticalCenter: parent.verticalCenter
                            text: board.tx("Search what you copied…")
                            font.family: Form.phainon ? "Cormorant Garamond" : input.font.family
                            font.italic: Form.phainon
                            font.pixelSize: Form.phainon ? 21 : input.font.pixelSize
                            color: Theme.withAlpha(Theme.surfaceText, 0.5)
                        }
                    }
                }
            }

            ListView {
                id: list
                x: -8
                y: panel.searchHeight + 10
                width: parent.width + 16
                height: panel.listHeight
                opacity: board.reveal
                clip: true
                model: board.entries
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0

                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool current: list.currentIndex === index
                    readonly property real gap: Form.khaslana ? 7 : (Form.reaver ? 0 : 4)
                    readonly property color ink: Form.khaslana ? (current ? "#F5D27A" : "#F3E6CC") : (Form.reaver ? "#E9E7F2" : Theme.surfaceText)
                    width: list.width
                    height: board.showsImage(modelData) ? board.imageRowHeight : board.rowHeight

                    // ── the row's ground, one per form ──
                    // Phainon: a capsule; the picked one glows gold
                    Rectangle {
                        visible: !Form.khaslana && !Form.reaver
                        x: 8
                        y: row.gap / 2
                        width: parent.width - 16
                        height: parent.height - row.gap
                        radius: thumb.visible ? 18 : height / 2
                        color: Theme.surfaceContainer
                        border.width: 1
                        border.color: row.current ? "#A87A22" : Theme.withAlpha(Theme.outline, 0.3)
                        gradient: row.current ? glow : null
                    }

                    // Khaslana: a cut slip; the picked one bleeds red with a gold bar
                    Shape {
                        id: slip
                        visible: Form.khaslana
                        x: 8
                        y: row.gap / 2
                        width: parent.width - 16
                        height: parent.height - row.gap
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            strokeColor: row.current ? "#F2C75C" : "#3A1A1E"
                            strokeWidth: 1
                            joinStyle: ShapePath.MiterJoin
                            fillGradient: LinearGradient {
                                x1: 0
                                x2: slip.width * 0.75
                                GradientStop {
                                    position: 0
                                    color: row.current ? "#8E1424" : "#140C0F"
                                }
                                GradientStop {
                                    position: 1
                                    color: row.current ? "#3A0A12" : "#140C0F"
                                }
                            }
                            PathPolyline {
                                path: Form.khaslana ? [Qt.point(0, 0), Qt.point(slip.width, 0), Qt.point(slip.width, slip.height - 9), Qt.point(slip.width - 9, slip.height), Qt.point(0, slip.height), Qt.point(0, 0)] : []
                            }
                        }
                    }
                    Rectangle {
                        visible: Form.khaslana && row.current
                        x: 9
                        y: row.gap / 2 + 1
                        width: 3
                        height: parent.height - row.gap - 2
                        color: "#F2C75C"
                    }

                    // Flame Reaver: a divider; the picked row a violet-edged plate
                    Rectangle {
                        visible: Form.reaver
                        x: 8
                        width: parent.width - 16
                        height: parent.height
                        color: row.current ? "#2E2650" : "transparent"
                        border.width: row.current ? 1 : 0
                        border.color: "#B9A8FF"

                        Rectangle {
                            visible: !row.current
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: "#2C2840"
                        }
                    }

                    // ── the number: a medallion, an act in Roman, two digits ──
                    Rectangle {
                        visible: !Form.khaslana && !Form.reaver
                        x: 18
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 28
                        radius: 14
                        color: row.current ? "#A87A22" : "transparent"
                        border.width: 1
                        border.color: row.current ? "#A87A22" : Theme.withAlpha(Theme.outline, 0.8)
                    }

                    Text {
                        x: Form.reaver ? 16 : 18
                        anchors.verticalCenter: parent.verticalCenter
                        width: Form.reaver ? 22 : 28
                        horizontalAlignment: Form.reaver ? Text.AlignRight : Text.AlignHCenter
                        text: Form.khaslana ? Numerals.roman(row.index + 1) : Numerals.two(row.index + 1)
                        font.family: Form.khaslana ? "Cinzel" : "Chakra Petch"
                        font.weight: Form.khaslana ? Font.DemiBold : Font.Normal
                        font.pixelSize: 12
                        color: Form.khaslana ? (row.current ? "#F5D27A" : "#B0824A") : (Form.reaver ? "#6E6A84" : (row.current ? "#FFFFFF" : "#8A6418"))
                    }

                    // Copied pictures show themselves, fitted whole: in a gold-rimmed frame (Phainon),
                    // gold-edged with a red offset (Khaslana), bare (Flame Reaver). Fetched a moment after
                    // the row appears, so scrolling past does not ask the backend for every image.
                    Item {
                        id: shot
                        readonly property real pad: Form.phainon ? 3 : 0
                        visible: board.showsImage(row.modelData)
                        x: 58
                        y: 8
                        width: Form.reaver ? 132 : 160
                        height: parent.height - 16

                        Rectangle {
                            visible: Form.khaslana && thumb.visible
                            x: 3
                            y: frame.y + 3
                            width: frame.width
                            height: frame.height
                            color: "#8E1424"
                        }

                        Rectangle {
                            id: frame
                            visible: !Form.reaver && thumb.visible
                            x: -shot.pad - 1
                            y: thumb.y + Math.round((thumb.height - thumb.paintedHeight) / 2) - shot.pad - 1
                            width: thumb.paintedWidth + 2 * shot.pad + 2
                            height: thumb.paintedHeight + 2 * shot.pad + 2
                            radius: Form.phainon ? 12 : 0
                            color: Form.phainon ? Theme.surfaceContainer : "transparent"
                            border.width: 1
                            border.color: Form.phainon ? "#A87A22" : "#E0B04A"
                            z: 1
                        }

                        Image {
                            id: thumb
                            property string encoded: ""
                            z: 2
                            x: 0
                            y: 0
                            width: shot.width
                            height: shot.height
                            visible: status === Image.Ready
                            source: encoded ? "data:image/png;base64," + encoded : ""
                            sourceSize: Qt.size(Math.round(width), Math.round(height))
                            fillMode: Image.PreserveAspectFit
                            horizontalAlignment: Image.AlignLeft
                            asynchronous: true
                            cache: false
                            onStatusChanged: {
                                if (status === Image.Error)
                                    board.badImages = Object.assign({}, board.badImages, {
                                        [row.modelData.id]: true
                                    });
                            }

                            Timer {
                                interval: 180
                                running: board.showsImage(row.modelData) && thumb.encoded === "" && board.shown
                                onTriggered: {
                                    const wanted = row.modelData.id;
                                    DMSService.sendRequest("clipboard.getEntry", {
                                        "id": wanted
                                    }, response => {
                                        if (row?.modelData?.id === wanted && response?.result?.data)
                                            thumb.encoded = response.result.data;
                                    });
                                }
                            }
                        }
                    }

                    // The picked row's key, or a pinned entry's mark: a laurel, a red ◆
                    Item {
                        id: mark
                        anchors.right: parent.right
                        anchors.rightMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                        width: row.current ? keyText.implicitWidth : (row.modelData.pinned && !Form.reaver ? (Form.khaslana ? pinText.implicitWidth : 20) : 0)
                        height: 20

                        Text {
                            id: keyText
                            visible: row.current
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: Form.phainon || !Form.active ? "↵ copy" : "↵"
                            font.family: "Chakra Petch"
                            font.pixelSize: 12
                            color: Theme.withAlpha(row.ink, 0.65)
                        }

                        Text {
                            id: pinText
                            visible: !row.current && row.modelData.pinned && Form.khaslana
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "◆ pinned"
                            font.family: "Chakra Petch"
                            font.pixelSize: 12
                            color: "#E5484D"
                        }

                        Shape {
                            visible: !row.current && row.modelData.pinned && !Form.khaslana && !Form.reaver
                            width: 20
                            height: 20
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                fillColor: "#A87A22"
                                strokeColor: "transparent"
                                scale: Qt.size(20 / 32, 20 / 32)
                                // The mockup's laurel, on a 32 grid
                                PathSvg {
                                    path: "M16 29C9 25 6 18 7 9M9 12c-3 0-4-2-4-4 3 0 4 2 4 4zM8 17c-3 1-5-1-5-3 3-1 5 1 5 3zM9.5 21.5c-2 2-5 1-6-1 3-1 5 0 6 1zM12.5 25c-1 2.5-4 3-5.5 1.5 2-2 4-2 5.5-1.5zM8 12c0-3 1.5-4.5 3.5-4.5 0 2.5-1.5 4.5-3.5 4.5zM8.5 17c.5-3 2.5-4 4.5-3.5-.5 2.5-2.5 4-4.5 3.5z"
                                }
                            }
                        }
                    }

                    Item {
                        id: textBox
                        x: thumb.visible ? shot.x + thumb.paintedWidth + 2 * shot.pad + 16 : 58
                        anchors.verticalCenter: parent.verticalCenter
                        width: mark.x - x - 12
                        height: label.implicitHeight

                        // The Flame Reaver's glitch echo on the picked row, as in the launcher
                        Repeater {
                            model: row.current && Form.reaver ? [[2, Qt.rgba(143 / 255, 123 / 255, 224 / 255, 0.85)], [-2, Qt.rgba(79 / 255, 209 / 255, 197 / 255, 0.55)]] : []

                            Text {
                                required property var modelData
                                x: modelData[0]
                                width: label.width
                                elide: Text.ElideRight
                                text: label.text
                                font: label.font
                                color: modelData[1]
                            }
                        }

                        Text {
                            id: label
                            width: parent.width
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                            maximumLineCount: 1
                            textFormat: Text.PlainText
                            text: {
                                const preview = String(ClipboardService.getEntryPreview(row.modelData)).replace(/\s+/g, " ").trim();
                                // The backend describes pictures as "[[ image 491 KiB png 919x986 ]]".
                                const picture = preview.match(/^\[\[\s*image\s+(.+?)\s+(\w+)\s+(\d+)x(\d+)\s*\]\]$/);
                                const shown = picture ? board.tx("Image") + " · " + picture[3] + " × " + picture[4] + " · " + picture[1] : (row.modelData.isImage && preview === "" ? board.tx("Image") : preview);
                                return (Form.reaver && row.modelData.pinned ? "* " : "") + (Form.reaver ? shown.toLowerCase() : shown);
                            }
                            font.family: Form.active ? "Chakra Petch" : Theme.fontFamily
                            font.pixelSize: Form.reaver ? 14 : 15
                            color: thumb.visible ? Theme.withAlpha(row.ink, 0.7) : row.ink
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: list.currentIndex = row.index
                        onClicked: {
                            ClipboardService.copyEntry(row.modelData, () => board.close());
                            Coreflames.earn("trickery");
                        }
                    }
                }
            }

            Text {
                visible: board.entries.length === 0
                x: 6
                y: panel.searchHeight + 10
                height: board.rowHeight
                verticalAlignment: Text.AlignVCenter
                text: board.tx(ClipboardService.searchText === "" ? "Nothing has been copied yet." : "Nothing matches.")
                font.family: Form.active ? "Chakra Petch" : Theme.fontFamily
                font.pixelSize: 15
                color: Theme.withAlpha(Theme.surfaceText, 0.55)
            }
        }

        // Khaslana: a run of golden blood breaking off the plate's right edge
        CfSliver {
            visible: Form.khaslana
            x: parent.width - 260
            y: Math.round(parent.height * 0.44)
            width: 300
            height: 150
            opacity: board.reveal
        }
    }

    // Phainon's picked row: gold fading to the right
    Gradient {
        id: glow
        orientation: Gradient.Horizontal
        GradientStop {
            position: 0
            color: Qt.rgba(241 / 255, 218 / 255, 79 / 255, 0.45)
        }
        GradientStop {
            position: 1
            color: Qt.rgba(241 / 255, 218 / 255, 79 / 255, 0.1)
        }
    }
}
