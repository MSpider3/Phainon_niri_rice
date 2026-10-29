import QtQuick
import QtQuick.Window
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets as DW

// "Romance · Messages": every notification, grouped by app, with its own buttons; dismiss one,
// a whole app, or all of them; do not disturb at the foot.
Item {
    id: notes

    readonly property var groups: NotificationService.groupedNotifications

    function tx(text) {
        return Form.reaver ? String(text).toLowerCase() : text;
    }

    implicitHeight: 500
    Component.onCompleted: NotificationService.markNotificationsSeen()

    component Close: DW.DIcon {
        signal clicked
        name: "close"
        size: 16
        color: Theme.withAlpha(Theme.surfaceText, 0.55)

        MouseArea {
            anchors.fill: parent
            anchors.margins: -5
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    component Button: Item {
        id: button
        property string label: ""
        property string icon: ""
        property bool on: false
        signal clicked

        implicitWidth: buttonRow.implicitWidth + 28
        height: 34
        opacity: enabled ? 1 : 0.4

        CfSurface {
            anchors.fill: parent
            color: button.on ? Theme.primary : (buttonMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)
            edgeColor: Theme.withAlpha(Theme.outline, 0.5)
            edgeWidth: Form.reaver ? 0 : 1
            radius: 17
        }

        Row {
            id: buttonRow
            anchors.centerIn: parent
            spacing: 6

            DW.DIcon {
                visible: button.icon !== "" && !Form.reaver
                anchors.verticalCenter: parent.verticalCenter
                name: button.icon
                size: 18
                color: button.on ? Theme.primaryText : Theme.primary
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: notes.tx(button.label)
                font.family: Form.reaver ? Theme.monoFontFamily : Theme.fontFamily
                font.pixelSize: Theme.fontSizeMedium
                color: button.on ? Theme.primaryText : Theme.surfaceText
            }
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    // Nothing waiting
    Column {
        visible: notes.groups.length === 0
        anchors.centerIn: list
        spacing: 12

        CfSigil {
            visible: !Form.reaver
            anchors.horizontalCenter: parent.horizontalCenter
            size: 54
            lit: 0
            litColor: Theme.withAlpha(Theme.surfaceText, 0.3)
            dimColor: Theme.withAlpha(Theme.surfaceText, 0.3)
        }

        CfGlyph {
            visible: Form.reaver
            anchors.horizontalCenter: parent.horizontalCenter
            name: "mask"
            size: 44
            strokeWidth: 1.4
            color: Theme.withAlpha(Theme.live, 0.7)
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Form.phainon ? "All quiet in Okhema." : (Form.khaslana ? "No threads pull at you." : "nothing.")
            font.family: Form.reaver ? Theme.monoFontFamily : Theme.fontFamily
            font.pixelSize: Theme.fontSizeLarge
            color: Theme.withAlpha(Theme.surfaceText, 0.55)
        }
    }

    Flickable {
        id: list
        width: parent.width
        height: parent.height - foot.height - 12
        contentHeight: groupColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: groupColumn
            width: list.width
            spacing: 10

            Repeater {
                model: notes.groups

                DashCard {
                    id: group
                    required property var modelData
                    width: groupColumn.width
                    height: groupBody.implicitHeight + 38
                    glyph: "romance"
                    label: (modelData.appName || "Unknown") + (modelData.count > 1 ? "  ·  " + modelData.count : "")

                    // Dismiss the whole app
                    Close {
                        anchors.right: parent.right
                        y: -19
                        name: "clear_all"
                        onClicked: NotificationService.dismissGroup(group.modelData.key)
                    }

                    Column {
                        id: groupBody
                        width: parent.width
                        spacing: 10

                        Repeater {
                            model: group.modelData.notifications

                            Item {
                                id: note
                                required property var modelData
                                required property int index
                                width: groupBody.width
                                height: noteColumn.implicitHeight

                                // Click anywhere on the message to open it (the action labels and × keep their own clicks).
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Form.openNotification(note.modelData);
                                        note.Window.window?.close?.();
                                    }
                                }

                                Rectangle {
                                    visible: note.index > 0
                                    y: -5
                                    width: parent.width
                                    height: 1
                                    color: Form.reaver ? Theme.withAlpha(Theme.live, 0.25) : Theme.withAlpha(Theme.outline, 0.3)
                                }

                                Column {
                                    id: noteColumn
                                    width: parent.width - 26
                                    spacing: 3

                                    Row {
                                        width: parent.width
                                        spacing: 8

                                        StyledText {
                                            width: parent.width - timeText.implicitWidth - 8
                                            elide: Text.ElideRight
                                            text: note.modelData.summary
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: Font.DemiBold
                                            color: Theme.surfaceText
                                        }

                                        StyledText {
                                            id: timeText
                                            text: notes.tx(note.modelData.timeStr)
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.withAlpha(Theme.surfaceText, 0.5)
                                        }
                                    }

                                    StyledText {
                                        visible: note.modelData.body !== ""
                                        width: parent.width
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 4
                                        elide: Text.ElideRight
                                        textFormat: Text.PlainText
                                        text: note.modelData.body
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.withAlpha(Theme.surfaceText, 0.75)
                                    }

                                    Row {
                                        visible: note.modelData.actions.length > 0
                                        spacing: 14
                                        topPadding: 4

                                        Repeater {
                                            model: note.modelData.actions

                                            StyledText {
                                                required property var modelData
                                                text: notes.tx(modelData.text)
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: Font.DemiBold
                                                color: Form.reaver ? Theme.live : Theme.primary

                                                MouseArea {
                                                    anchors.fill: parent
                                                    anchors.margins: -4
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: parent.modelData.invoke()
                                                }
                                            }
                                        }
                                    }
                                }

                                Close {
                                    anchors.right: parent.right
                                    onClicked: NotificationService.dismissNotification(note.modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        id: foot
        anchors.bottom: parent.bottom
        width: parent.width
        height: 34

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            // The Flame Reaver's swords cross when the world is shut out.
            CfCrossToggle {
                visible: Form.reaver
                anchors.verticalCenter: parent.verticalCenter
                checked: SessionData.doNotDisturb
                color: Theme.live
                onToggled: on => SessionData.setDoNotDisturb(on)
            }

            StyledText {
                visible: Form.reaver
                anchors.verticalCenter: parent.verticalCenter
                text: "do not disturb"
                font.family: Theme.monoFontFamily
                font.pixelSize: Theme.fontSizeMedium
                color: SessionData.doNotDisturb ? Theme.surfaceText : Theme.withAlpha(Theme.surfaceText, 0.6)
            }

            Button {
                visible: !Form.reaver
                icon: SessionData.doNotDisturb ? "notifications_off" : "notifications"
                label: "Do not disturb"
                on: SessionData.doNotDisturb
                onClicked: SessionData.setDoNotDisturb(!SessionData.doNotDisturb)
            }
        }

        Button {
            anchors.right: parent.right
            icon: "clear_all"
            label: "Clear all"
            enabled: NotificationService.notifications.length > 0
            onClicked: NotificationService.clearAllNotifications()
        }
    }
}
