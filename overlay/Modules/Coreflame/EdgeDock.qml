import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

// A small dock at the bottom edge for the workspace you are on: one icon per window, in the
// order niri lays them out (column by column, top to bottom), so an app with two windows shows
// twice. Hidden until the pointer touches the bottom edge. Click focuses a window; the wheel
// walks the columns left and right, the sideways partner of the island's workspace scroll.
PanelWindow {
    id: dock

    required property var targetScreen

    readonly property var workspace: NiriService.allWorkspaces.find(w => w.output === targetScreen?.name && w.is_active) ?? null
    // NiriService keeps its window list sorted by column, then row.
    readonly property var windowsHere: workspace ? NiriService.windows.filter(w => w.workspace_id === workspace.id) : []
    readonly property int iconSize: 30
    readonly property real barWidth: Math.max(1, windowsHere.length) * (iconSize + 14) + 22
    readonly property real barHeight: iconSize + 18
    // Slid out while the pointer is on the edge strip or the dock itself
    readonly property bool open: (edgeHover.hovered || barHover.hovered) && windowsHere.length > 0
    property real reveal: open ? 1 : 0

    Behavior on reveal {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Easing.OutCubic
        }
    }

    screen: targetScreen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "coreflame:dock"
    WlrLayershell.layer: WlrLayer.Top
    anchors {
        bottom: true
    }
    implicitWidth: barWidth + 40
    implicitHeight: barHeight + 10
    // Only the edge strip takes the pointer while hidden; the whole dock once shown.
    mask: Region {
        item: dock.open ? bar : edge
    }

    Item {
        id: edge
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: dock.barWidth
        height: 4

        HoverHandler {
            id: edgeHover
        }
    }

    Item {
        id: bar
        anchors.horizontalCenter: parent.horizontalCenter
        width: dock.barWidth
        height: dock.barHeight
        y: Math.round(parent.height - dock.reveal * height)
        visible: dock.reveal > 0.001

        HoverHandler {
            id: barHover
        }

        // The island's tab shape, turned over so it rises from the bottom edge
        CfTab {
            anchors.fill: parent
            side: "center"
            transform: Scale {
                origin.y: dock.barHeight / 2
                yScale: -1
            }
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                if (delta !== 0)
                    NiriService.send({
                        "Action": delta > 0 ? {
                            "FocusColumnLeft": {}
                        } : {
                            "FocusColumnRight": {}
                        }
                    });
            }
        }

        Row {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 2
            spacing: 14

            Repeater {
                model: dock.windowsHere

                Item {
                    id: slot
                    required property var modelData
                    width: dock.iconSize
                    height: dock.iconSize

                    IconImage {
                        anchors.fill: parent
                        source: Paths.getAppIcon(slot.modelData.app_id ?? "", DesktopEntries.heuristicLookup(Paths.moddedAppId(slot.modelData.app_id ?? "")))
                        opacity: slot.modelData.is_focused ? 1 : 0.7
                    }

                    // The focused window's mark
                    Rectangle {
                        visible: slot.modelData.is_focused
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.bottom
                        anchors.topMargin: 2
                        width: Form.phainon || !Form.active ? 6 : 10
                        height: Form.phainon || !Form.active ? 6 : 2
                        radius: Form.phainon || !Form.active ? 3 : 0
                        color: Theme.primary
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -5
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NiriService.focusWindow(slot.modelData.id)
                    }
                }
            }
        }
    }
}
