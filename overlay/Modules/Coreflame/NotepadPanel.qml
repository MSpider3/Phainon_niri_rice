import QtQuick
import QtQuick.Shapes
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
    property real opening: shown ? 1 : 0
    readonly property real reveal: Motion.step(opening)

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

    onShownChanged: {
        if (!shown)
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

        x: Math.round((board.width - width) / 2)
        y: sheet.topFor(board.strip)
        width: Math.round(420 + (board.panelWidth - 420) * board.reveal)
        height: Math.round(60 + (board.fullHeight - 60) * board.reveal)

        // Swallow clicks on the whole sheet so they don't close the window
        MouseArea {
            anchors.fill: parent
        }

        // Khaslana: the Black Tide's cubes and a run of golden blood breaking off the right edge
        CfTide {
            visible: Form.khaslana
            y: parent.height + 8
            width: parent.width
            height: 120
            opacity: board.reveal
            seed: 47
            liquid: 0
            cubes: Form.khaslana ? 14 : 0
        }

        CfSliver {
            visible: Form.khaslana
            x: parent.width - 200
            y: Math.round(parent.height * 0.3)
            width: 260
            height: 130
            opacity: board.reveal
        }

        // The v3 mockup's codex (Phainon), script (Khaslana) or torn slab (Flame Reaver)
        CfSheet {
            id: sheet
            anchors.fill: parent
            // Only while it opens: at rest Khaslana's red offset hangs outside the plate
            clip: board.reveal < 1
            title: "Reason · Notes"
            glyph: "reason"

            // Laid out at full size from the start so the editor does not reflow while the panel grows.
            Notepad {
                id: notepad
                width: parent.width
                height: board.fullHeight - sheet.headerHeight - sheet.footerHeight
                opacity: board.reveal
                surfaceVisible: board.shown
                onHideRequested: board.close()
                onPopoutRequested: {
                    board.close();
                    PopoutService.openNotepadPopout();
                }
            }
        }

        // Phainon: a gold ribbon marking the place, hanging over the top edge
        Shape {
            visible: Form.phainon
            x: parent.width - 54 - width
            y: -1
            width: 22
            height: 86
            opacity: board.reveal
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: "transparent"
                fillGradient: LinearGradient {
                    x1: 0
                    x2: 22
                    GradientStop {
                        position: 0
                        color: "#A87A22"
                    }
                    GradientStop {
                        position: 0.5
                        color: "#E2B84A"
                    }
                    GradientStop {
                        position: 1
                        color: "#A87A22"
                    }
                }
                PathPolyline {
                    path: [Qt.point(0, 0), Qt.point(22, 0), Qt.point(22, 86), Qt.point(11, 70.5), Qt.point(0, 86), Qt.point(0, 0)]
                }
            }
        }
    }
}
