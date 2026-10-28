import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Notepad

// Reason: the stock notepad, dropping out of the island like the clipboard. Notes stay in the
// stock NotepadStorageService; only the frame around them is Coreflame's.
PanelWindow {
    id: board

    required property var targetScreen
    property int strip: 40
    property bool shown: false
    property real reveal: shown ? 1 : 0

    readonly property real panelWidth: 680
    readonly property real fullHeight: Math.min(720, Math.round((targetScreen?.height ?? 900) * 0.72))

    function open() {
        if (NiriService.inOverview)
            NiriService.closeOverview();
        shown = true;
        Qt.callLater(notepad.externalSync);
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

    function openFile(path) {
        open();
        notepad.openExternalFile(path);
    }

    function tx(text) {
        return Form.reaver ? String(text).toLowerCase() : text;
    }

    onShownChanged: {
        if (shown)
            ornament.play();
        else
            notepad.flushAutoSave();
    }

    // Destroyed while open (a screen unplugged, another theme picked): keep what was typed.
    Component.onDestruction: {
        if (shown)
            notepad.flushAutoSave();
    }

    screen: targetScreen
    visible: reveal > 0.001
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "coreflame:notepad"
    // The notepad's file browser and confirm dialogs are windows of their own: step down and let go
    // of the keyboard while one is open, or it would open underneath.
    WlrLayershell.layer: notepad.anyModalOpen ? WlrLayer.Top : WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown && !notepad.anyModalOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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

        x: Math.round((board.width - width) / 2)
        width: Math.round(420 + (board.panelWidth - 420) * board.reveal)
        height: Math.round(board.strip + (board.fullHeight - board.strip) * board.reveal)
        clip: true

        CfTab {
            id: tab
            anchors.fill: parent
            side: "center"
        }

        CfOrnament {
            id: ornament
            anchors.fill: parent
        }

        MouseArea {
            anchors.fill: parent
        }

        Row {
            x: 22
            height: board.strip + 6
            spacing: 8
            opacity: board.reveal

            CfGlyph {
                anchors.verticalCenter: parent.verticalCenter
                name: Form.reaver ? "mask" : "reason"
                size: 16
                strokeWidth: 1.9
                color: Form.reaver ? Theme.live : Theme.withAlpha(Theme.surfaceText, 0.6)
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: board.tx("Reason · Notes")
                font.family: Form.display(Theme.fontFamily)
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.withAlpha(Theme.surfaceText, 0.8)
            }
        }

        Rectangle {
            x: 22
            y: board.strip + 6
            width: board.panelWidth - 44
            height: 1
            color: Form.reaver ? Theme.withAlpha(Theme.live, 0.5) : Theme.withAlpha(Theme.outline, 0.6)
        }

        // Laid out at full size from the start so the editor does not reflow while the panel grows.
        Notepad {
            id: notepad
            x: 16
            y: board.strip + 14
            width: board.panelWidth - 32
            height: board.fullHeight - y - (Form.reaver ? tab.hem : 0) - 24
            opacity: board.reveal
            surfaceVisible: board.shown
            onHideRequested: board.close()
            onPopoutRequested: {
                board.close();
                PopoutService.openNotepadPopout();
            }
        }
    }
}
