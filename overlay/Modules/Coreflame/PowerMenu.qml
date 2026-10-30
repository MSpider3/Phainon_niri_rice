import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets as DW

// The session menu over a dimmed screen. Log out, Slumber, Rekindle, restart and shut down
// ask for a second press before they act.
PanelWindow {
    id: menu

    required property var targetScreen
    property bool shown: false
    property real reveal: shown ? 1 : 0
    property int selected: 0
    property int armed: -1
    property bool canHibernate: false
    // Seven tiles must still fit on a small screen.
    readonly property real tile: Math.min(132, (width - 48 - 16 * (choices.length - 1)) / choices.length)

    readonly property var allChoices: [
        {
            "id": "lock",
            "icon": "lock",
            "label": "Lock",
            "lore": "Seal",
            "confirm": false
        },
        {
            "id": "suspend",
            "icon": "bedtime",
            "label": "Sleep",
            "lore": "Repose",
            "confirm": false
        },
        {
            "id": "hibernate",
            "icon": "ac_unit",
            "label": "Hibernate",
            "lore": "Slumber",
            "confirm": true
        },
        {
            "id": "logout",
            "icon": "logout",
            "label": "Log out",
            "lore": "Depart",
            "confirm": true
        },
        {
            "id": "restart",
            "icon": "refresh",
            "label": "Restart DMS",
            "lore": "Rekindle",
            "confirm": true
        },
        {
            "id": "reboot",
            "icon": "restart_alt",
            "label": "Restart",
            "lore": "Recurrence",
            "confirm": true
        },
        {
            "id": "poweroff",
            "icon": "power_settings_new",
            "label": "Shut down",
            "lore": "Curtain-Fall",
            "confirm": true
        }
    ]
    // Stock hibernateSupported: the kernel offers "disk" (gone e.g. under Secure Boot lockdown).
    readonly property var choices: allChoices.filter(c => c.id !== "hibernate" || (canHibernate && SessionService.hibernateSupported))
    // Slumber appears after the check finishes on first open; an armed index would then point at another action.
    onChoicesChanged: armed = -1

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
        switch (choices[index].id) {
        case "lock":
            Quickshell.execDetached(["dms", "ipc", "call", "lock", "lock"]);
            break;
        case "suspend":
            SessionService.suspend();
            break;
        case "hibernate":
            SessionService.hibernate();
            break;
        case "logout":
            SessionService.logout();
            break;
        case "restart":
            // Same as stock DMS: restarts the shell only, the session stays.
            Quickshell.execDetached(["dms", "restart"]);
            break;
        case "reboot":
            Form.cinematic("closing", () => SessionService.reboot());
            break;
        case "poweroff":
            Form.cinematic("closing", () => SessionService.poweroff());
            break;
        }
    }

    // Hibernation only works with a resume device and enough real swap to hold RAM;
    // zram lives in RAM, so it does not count. Runs once, when the menu is first loaded.
    Process {
        running: true
        command: ["sh", "-c", "grep -qE '(^| )resume=' /proc/cmdline && awk 'NR==FNR { if ($1 == \"MemTotal:\") m = $2; next } FNR > 1 && $1 !~ /^\\/dev\\/zram/ { s += $3 } END { exit !(m > 0 && s >= m) }' /proc/meminfo /proc/swaps"]
        onExited: code => menu.canHibernate = code === 0
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

        // Phainon's tarot card beside the choices (installed from cinematics/); no file, no card.
        Image {
            visible: Form.phainon && status === Image.Ready
            anchors.verticalCenter: choiceColumn.verticalCenter
            anchors.right: choiceColumn.left
            anchors.rightMargin: 72
            height: Math.round(Math.min(440, parent.height * 0.46))
            fillMode: Image.PreserveAspectFit
            source: Form.phainon ? "file://" + Form.stateDir + "/cinematics/phainon-card.png" : ""
            asynchronous: true
            mipmap: true
        }

        Column {
            id: choiceColumn
            anchors.centerIn: parent
            spacing: 26

            CfGlyph {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "death"
                size: 40
                strokeWidth: 1.7
                color: Theme.primary
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter

                StyledText {
                    id: endLabel
                    text: Form.reaver ? "death · end of cycle " : "Death · End of cycle "
                    font.pixelSize: Theme.fontSizeLarge
                    font.letterSpacing: 2
                    color: Theme.withAlpha(Theme.surfaceText, 0.7)
                }

                StyledText {
                    anchors.baseline: endLabel.baseline
                    text: Form.cycle
                    font.family: Form.numerals
                    font.pixelSize: Theme.fontSizeLarge + 3
                    font.letterSpacing: 1
                    color: endLabel.color
                }
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
                        width: menu.tile
                        height: menu.tile

                        CfSurface {
                            anchors.fill: parent
                            color: option.armed ? Theme.error : (option.current ? Theme.primary : Theme.surfaceContainerHigh)
                            edgeColor: Theme.withAlpha(Theme.outline, Form.khaslana ? 0.9 : 0.5)
                            edgeWidth: Form.reaver ? 0 : 1
                            radius: 28
                            cut: 14
                            torn: true
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 10

                            DW.DIcon {
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
