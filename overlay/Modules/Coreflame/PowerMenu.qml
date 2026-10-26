import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

// The session menu: five choices over a dimmed screen. Log out, restart and shut down
// ask for a second press before they act.
PanelWindow {
    id: menu

    required property var targetScreen
    property bool shown: false
    property real reveal: shown ? 1 : 0
    property int selected: 0
    property int armed: -1

    readonly property var choices: [
        {
            "icon": "lock",
            "label": "Lock",
            "lore": "Seal",
            "confirm": false
        },
        {
            "icon": "bedtime",
            "label": "Sleep",
            "lore": "Repose",
            "confirm": false
        },
        {
            "icon": "logout",
            "label": "Log out",
            "lore": "Depart",
            "confirm": true
        },
        {
            "icon": "restart_alt",
            "label": "Restart",
            "lore": "Recurrence",
            "confirm": true
        },
        {
            "icon": "power_settings_new",
            "label": "Shut down",
            "lore": "Curtain-Fall",
            "confirm": true
        }
    ]

    function open() {
        selected = 0;
        armed = -1;
        shown = true;
        Coreflames.earn("death");
    }

    function close() {
        shown = false;
        armed = -1;
    }

    function toggle() {
        if (shown)
            close();
        else
            open();
    }

    function choose(index) {
        selected = index;
        if (choices[index].confirm && armed !== index) {
            armed = index;
            return;
        }
        close();
        switch (index) {
        case 0:
            Quickshell.execDetached(["dms", "ipc", "call", "lock", "lock"]);
            break;
        case 1:
            SessionService.suspend();
            break;
        case 2:
            SessionService.logout();
            break;
        case 3:
            Form.cinematic("closing", () => SessionService.reboot());
            break;
        case 4:
            Form.cinematic("closing", () => SessionService.poweroff());
            break;
        }
    }

    screen: targetScreen
    visible: reveal > 0.001
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "coreflame:powermenu"
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
            duration: Theme.shortDuration
            easing.type: Easing.OutCubic
        }
    }

    onShownChanged: if (shown)
        keys.forceActiveFocus()

    Rectangle {
        anchors.fill: parent
        color: Theme.withAlpha(Theme.background, 0.72 * menu.reveal)

        MouseArea {
            anchors.fill: parent
            onClicked: menu.close()
        }
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        opacity: menu.reveal

        Keys.onEscapePressed: menu.close()
        Keys.onLeftPressed: {
            menu.selected = (menu.selected + menu.choices.length - 1) % menu.choices.length;
            menu.armed = -1;
        }
        Keys.onRightPressed: {
            menu.selected = (menu.selected + 1) % menu.choices.length;
            menu.armed = -1;
        }
        Keys.onReturnPressed: menu.choose(menu.selected)
        Keys.onEnterPressed: menu.choose(menu.selected)

        Column {
            anchors.centerIn: parent
            spacing: 26

            CfGlyph {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "death"
                size: 40
                strokeWidth: 1.7
                color: Theme.primary
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: (Form.reaver ? "death · end of cycle " : "Death · End of cycle ") + Form.cycleText
                font.pixelSize: Theme.fontSizeLarge
                font.letterSpacing: 2
                color: Theme.withAlpha(Theme.surfaceText, 0.7)
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16

                Repeater {
                    model: menu.choices

                    Item {
                        id: option
                        required property var modelData
                        required property int index
                        readonly property bool current: menu.selected === index
                        readonly property bool armed: menu.armed === index
                        width: 132
                        height: 132

                        CfSurface {
                            anchors.fill: parent
                            color: option.armed ? Theme.error : (option.current ? Theme.primary : Theme.surfaceContainerHigh)
                            edgeColor: Theme.withAlpha(Theme.outline, Form.khaslana ? 0.9 : 0.5)
                            edgeWidth: Form.reaver ? 0 : 1
                            radius: 28
                            cut: 14
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 10

                            DankIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                name: option.modelData.icon
                                size: 38
                                color: (option.current || option.armed) ? Theme.primaryText : Theme.primary
                            }

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: {
                                    const label = option.armed ? "Press again" : option.modelData.label;
                                    return Form.reaver ? label.toLowerCase() : label;
                                }
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.DemiBold
                                color: (option.current || option.armed) ? Theme.primaryText : Theme.surfaceText
                            }

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Form.reaver ? option.modelData.lore.toLowerCase() : option.modelData.lore
                                font.pixelSize: Theme.fontSizeSmall
                                color: (option.current || option.armed) ? Theme.withAlpha(Theme.primaryText, 0.7) : Theme.withAlpha(Theme.surfaceText, 0.45)
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: {
                                if (menu.selected !== option.index) {
                                    menu.selected = option.index;
                                    menu.armed = -1;
                                }
                            }
                            onClicked: menu.choose(option.index)
                        }
                    }
                }
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Form.reaver ? "arrows to move · enter to choose · esc to close" : "Arrows to move · Enter to choose · Esc to close"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.withAlpha(Theme.surfaceText, 0.75)
            }
        }
    }
}
