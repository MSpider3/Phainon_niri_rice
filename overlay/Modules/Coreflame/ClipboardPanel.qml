import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

// Trickery: the clipboard history, dropping out of the island like the launcher.
// Type to filter. Enter copies, Shift+Enter pastes, Delete removes, Ctrl+P pins.
PanelWindow {
    id: board

    required property var targetScreen
    property int strip: 40
    property bool shown: false
    property real reveal: shown ? 1 : 0

    readonly property var entries: ClipboardService.clipboardEntries ?? []
    readonly property int visibleRows: 9
    readonly property real panelWidth: 640
    readonly property real rowHeight: Form.reaver ? 34 : 44

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

    Behavior on reveal {
        NumberAnimation {
            duration: Theme.mediumDuration
            easing.type: Form.phainon ? Easing.OutBack : (Form.khaslana ? Easing.InOutCubic : Easing.OutCubic)
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

        readonly property int rows: Math.max(1, Math.min(board.visibleRows, board.entries.length))
        readonly property real listTop: board.strip + 46
        readonly property real fullHeight: listTop + rows * board.rowHeight + 50

        x: Math.round((board.width - width) / 2)
        width: Math.round(420 + (board.panelWidth - 420) * board.reveal)
        height: Math.round(board.strip + (fullHeight - board.strip) * board.reveal)
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
            target: board

            function onShownChanged() {
                if (board.shown)
                    ornament.play();
            }
        }

        MouseArea {
            anchors.fill: parent
        }

        Row {
            x: 22
            width: board.panelWidth - 44
            height: board.strip + 6
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

                StyledText {
                    visible: input.text === ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: board.tx("Search what you copied…")
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.withAlpha(Theme.surfaceText, 0.4)
                }
            }
        }

        Rectangle {
            x: 22
            y: board.strip + 6
            width: board.panelWidth - 44
            height: 1
            color: Theme.withAlpha(Theme.outline, 0.6)
        }

        Row {
            x: 22
            y: board.strip + 14
            height: 24
            spacing: 8
            opacity: board.reveal

            CfGlyph {
                anchors.verticalCenter: parent.verticalCenter
                name: "trickery"
                size: 16
                strokeWidth: 1.9
                color: Theme.withAlpha(Theme.surfaceText, 0.6)
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: board.tx("Trickery · Clipboard")
                font.family: Form.display(Theme.fontFamily)
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.withAlpha(Theme.surfaceText, 0.8)
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: board.entries.length > 0 ? (list.currentIndex + 1) + " / " + board.entries.length : "0"
                font.family: Theme.monoFontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.withAlpha(Theme.surfaceText, 0.45)
            }
        }

        ListView {
            id: list
            x: 14
            y: panel.listTop
            width: board.panelWidth - 28
            height: panel.rows * board.rowHeight
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
                width: list.width
                height: board.rowHeight

                CfSurface {
                    anchors.fill: parent
                    anchors.margins: 2
                    visible: row.current
                    color: Theme.primary
                    edgeWidth: 0
                    radius: 16
                }

                Text {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26
                    text: String(row.index + 1).padStart(2, "0")
                    font.family: Theme.monoFontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: row.current ? Theme.withAlpha(Theme.primaryText, 0.75) : Theme.withAlpha(Theme.surfaceText, 0.4)
                }

                DankIcon {
                    visible: !Form.reaver && !thumb.visible
                    x: 44
                    anchors.verticalCenter: parent.verticalCenter
                    name: row.modelData.isImage ? "image" : (row.modelData.pinned ? "push_pin" : "notes")
                    size: 18
                    color: row.current ? Theme.primaryText : Theme.primary
                }

                // Copied pictures show themselves. Fetched a moment after the row appears, so
                // scrolling past does not ask the backend for every image on the way.
                Image {
                    id: thumb
                    property string encoded: ""
                    x: 40
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(height * 1.5)
                    height: board.rowHeight - 8
                    visible: status === Image.Ready
                    source: encoded ? "data:image/png;base64," + encoded : ""
                    sourceSize.width: 96
                    sourceSize.height: 96
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false

                    Timer {
                        interval: 180
                        running: row.modelData.isImage && thumb.encoded === "" && board.shown
                        onTriggered: {
                            const wanted = row.modelData.id;
                            DMSService.sendRequest("clipboard.getEntry", {
                                "id": wanted
                            }, response => {
                                if (row.modelData?.id === wanted && response?.result?.data)
                                    thumb.encoded = response.result.data;
                            });
                        }
                    }
                }

                StyledText {
                    x: thumb.visible ? 40 + thumb.width + 12 : (Form.reaver ? 46 : 74)
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x - 16
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    maximumLineCount: 1
                    textFormat: Text.PlainText
                    text: {
                        const preview = String(ClipboardService.getEntryPreview(row.modelData)).replace(/\s+/g, " ").trim();
                        // The backend describes pictures as "[[ image 491 KiB png 919x986 ]]".
                        const picture = preview.match(/^\[\[\s*image\s+(.+?)\s+(\w+)\s+(\d+)x(\d+)\s*\]\]$/);
                        const shown = picture ? "Image · " + picture[3] + " × " + picture[4] + " · " + picture[1] : (row.modelData.isImage && preview === "" ? "Image" : preview);
                        return (Form.reaver && row.modelData.pinned ? "* " : "") + shown;
                    }
                    font.pixelSize: Theme.fontSizeMedium
                    color: row.current ? Theme.primaryText : Theme.surfaceText
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: list.currentIndex = row.index
                    onClicked: ClipboardService.copyEntry(row.modelData, () => board.close())
                }
            }
        }

        StyledText {
            visible: board.entries.length === 0
            x: 26
            y: panel.listTop
            height: board.rowHeight
            verticalAlignment: Text.AlignVCenter
            text: board.tx("Nothing has been copied yet.")
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.withAlpha(Theme.surfaceText, 0.5)
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Form.reaver ? 18 : 14
            text: board.tx("↵ copy   Shift+↵ paste   Del remove   Ctrl+P pin   Esc close")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.withAlpha(Theme.surfaceText, 0.45)
        }
    }
}
