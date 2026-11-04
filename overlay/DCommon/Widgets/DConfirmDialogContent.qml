import QtQuick
import qs.DCommon.Common
import qs.Common as Shell
import qs.Widgets as Cf

Column {
    id: root

    property string confirmTitle: ""
    property string confirmMessage: ""
    property string confirmButtonText: I18n.tr("Confirm")
    property string cancelButtonText: I18n.tr("Cancel")
    property color confirmButtonColor: Style.primary
    property string reviewUrl: ""
    property int selectedButton: 0
    property bool keyboardNavigation: false

    // Coreflame: "Law · Confirm" over the caller's own title, the answers right-aligned, a risky
    // answer in the form's red, and the Flame Reaver's answers as words with keys.
    readonly property bool cf: Shell.Form.active
    readonly property bool cfRisky: confirmButtonColor === Style.error

    signal buttonActivated(int button)
    signal cancelled

    spacing: Style.spacingL
    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true
    Accessible.role: Accessible.Dialog
    Accessible.name: confirmTitle
    Accessible.description: confirmMessage

    onSelectedButtonChanged: {
        if (keyboardNavigation)
            focusSelection();
    }

    function focusSelection() {
        const button = selectedButton === 1 ? confirmButton : cancelButton;
        if (button.activeFocus && !button.visualFocus)
            button.focus = false;
        button.forceActiveFocus(Qt.TabFocusReason);
    }

    function reset() {
        keyboardNavigation = true;
        selectedButton = 0;
        focusSelection();
    }

    function handleKey(event) {
        switch (event.key) {
        case Qt.Key_Escape:
            cancelled();
            break;
        case Qt.Key_Left:
        case Qt.Key_Right:
            keyboardNavigation = true;
            selectedButton = event.key === (I18n.isRtl ? Qt.Key_Left : Qt.Key_Right) ? 1 : 0;
            focusSelection();
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (!event.isAutoRepeat)
                buttonActivated(selectedButton === 1 ? 1 : 0);
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    Cf.CfDialogHead {
        width: parent.width
        visible: root.cf
        glyph: "law"
        kind: I18n.tr("Confirm")
        title: root.confirmTitle
    }

    StyledText {
        width: parent.width
        visible: !root.cf
        text: root.confirmTitle
        textFormat: Text.PlainText
        font.pixelSize: Style.fontSizeLarge
        font.weight: Style.fontWeightMedium
        color: Style.onSurface
        wrapMode: Text.Wrap
    }

    StyledText {
        width: parent.width
        visible: !root.cf
        text: root.confirmMessage
        textFormat: Text.PlainText
        font.pixelSize: Style.fontSizeMedium
        color: Style.onSurfaceVariant
        wrapMode: Text.Wrap
    }

    Cf.CfDialogText {
        width: parent.width
        visible: root.cf && text !== ""
        text: root.confirmMessage
    }

    DButton {
        id: reviewButton
        KeyNavigation.tab: cancelButton
        KeyNavigation.backtab: confirmButton
        visible: root.reviewUrl !== ""
        text: I18n.tr("Review changes", "open plugin changes before updating")
        iconName: "open_in_new"
        maximumWidth: root.width
        wrapText: true
        backgroundColor: Style.secondaryContainer
        textColor: Style.onSecondaryContainer
        onClicked: Qt.openUrlExternally(root.reviewUrl)
    }

    Item {
        width: parent.width
        height: answers.height

        Row {
            id: answers
            x: root.cf ? parent.width - width : 0
            width: root.cf ? implicitWidth : parent.width
            spacing: Style.spacingS
            // The Reaver shows words instead; the buttons stay for keyboard focus
            opacity: cfHints.visible ? 0 : 1

            DButton {
                id: cancelButton
                KeyNavigation.tab: confirmButton
                KeyNavigation.backtab: reviewButton.visible ? reviewButton : confirmButton
                width: root.cf ? implicitWidth : (parent.width - parent.spacing) / 2
                maximumWidth: root.cf ? root.width / 2 : width
                wrapText: true
                text: root.cancelButtonText
                backgroundColor: Style.secondaryContainer
                textColor: Style.onSecondaryContainer
                onActiveFocusChanged: {
                    if (activeFocus)
                        root.selectedButton = 0;
                }
                onClicked: root.buttonActivated(0)
            }

            DButton {
                id: confirmButton
                KeyNavigation.tab: reviewButton.visible ? reviewButton : cancelButton
                KeyNavigation.backtab: cancelButton
                width: root.cf ? implicitWidth : (parent.width - parent.spacing) / 2
                maximumWidth: root.cf ? root.width / 2 : width
                wrapText: true
                text: root.confirmButtonText
                backgroundColor: root.cf && root.cfRisky ? (Shell.Form.khaslana ? "#C2252F" : "#A3343A") : root.confirmButtonColor === Style.error ? Style.errorContainer : root.confirmButtonColor
                textColor: root.cf && root.cfRisky ? (Shell.Form.khaslana ? "#F5D27A" : "#F7F3E8") : root.confirmButtonColor === Style.error ? Style.onErrorContainer : Style.onPrimary
                onActiveFocusChanged: {
                    if (activeFocus)
                        root.selectedButton = 1;
                }
                onClicked: root.buttonActivated(1)
            }
        }

        Cf.CfKeyHints {
            id: cfHints
            anchors.right: parent.right
            anchors.verticalCenter: answers.verticalCenter
            visible: root.cf && Shell.Form.reaver
            // Esc always cancels; Enter answers whichever word is picked (left / right moves it)
            model: [
                {
                    "key": root.selectedButton === 0 ? "esc ↵" : "esc",
                    "text": root.cancelButtonText,
                    "selected": root.keyboardNavigation && root.selectedButton === 0,
                    "act": () => root.buttonActivated(0)
                },
                {
                    "key": root.selectedButton === 1 ? "↵" : "→",
                    "text": root.confirmButtonText,
                    "danger": root.cfRisky,
                    "selected": root.keyboardNavigation && root.selectedButton === 1,
                    "act": () => root.buttonActivated(1)
                }
            ]
        }
    }
}
