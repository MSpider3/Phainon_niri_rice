import QtQuick
import qs.Common
import qs.Modals.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Widgets

DModal {
    id: root
    readonly property var log: Log.scoped("BluetoothPairingModal")

    layerNamespace: "dms:bluetooth-pairing"

    property string deviceName: ""
    property string deviceAddress: ""
    property string requestType: ""
    property string token: ""
    property int passkey: 0
    property string pinInput: ""
    property string passkeyInput: ""

    function show(pairingData) {
        log.debug("BluetoothPairingModal.show() called:", JSON.stringify(pairingData));
        token = pairingData.token || "";
        deviceName = pairingData.deviceName || "";
        deviceAddress = pairingData.deviceAddr || "";
        requestType = pairingData.requestType || "";
        passkey = pairingData.passkey || 0;
        pinInput = "";
        passkeyInput = "";

        log.debug("Calling open()");
        open();
        Qt.callLater(() => {
            if (contentLoader.item) {
                if (requestType === "pin" && contentLoader.item.pinInputField) {
                    contentLoader.item.pinInputField.forceActiveFocus();
                } else if (requestType === "passkey" && contentLoader.item.passkeyInputField) {
                    contentLoader.item.passkeyInputField.forceActiveFocus();
                }
            }
        });
    }

    shouldBeVisible: false
    allowStacking: true
    keepPopoutsOpen: true
    modalWidth: 420
    modalHeight: contentLoader.item ? contentLoader.item.implicitHeight + (Form.active ? 44 : Theme.spacingM * 2) : 240

    onShouldBeVisibleChanged: () => {
        if (!shouldBeVisible) {
            pinInput = "";
            passkeyInput = "";
        }
    }

    onOpened: {
        Qt.callLater(() => {
            if (contentLoader.item) {
                if (requestType === "pin" && contentLoader.item.pinInputField) {
                    contentLoader.item.pinInputField.forceActiveFocus();
                } else if (requestType === "passkey" && contentLoader.item.passkeyInputField) {
                    contentLoader.item.passkeyInputField.forceActiveFocus();
                }
            }
        });
    }

    onBackgroundClicked: () => {
        if (token) {
            DMSService.bluetoothCancelPairing(token);
        }
        close();
        token = "";
        pinInput = "";
        passkeyInput = "";
    }

    content: Component {
        FocusScope {
            id: pairingContent

            property alias pinInputField: pinInputField
            property alias passkeyInputField: passkeyInputField
            readonly property bool canPair: {
                if (requestType === "pin")
                    return pinInput.length > 0;
                if (requestType === "passkey")
                    return passkeyInput.length === 6;
                return true;
            }
            readonly property string pairLabel: {
                switch (requestType) {
                case "confirm":
                case "display-passkey":
                    return I18n.tr("Confirm");
                case "authorize":
                    return I18n.tr("Authorize", "verb, bluetooth pairing dialog confirm button");
                default:
                    if (requestType.startsWith("authorize-service"))
                        return I18n.tr("Authorize");
                    return I18n.tr("Pair", "verb, bluetooth device pairing button");
                }
            }
            readonly property string requestText: {
                switch (requestType) {
                case "confirm":
                    return I18n.tr("Confirm passkey for ") + deviceName;
                case "display-passkey":
                    return I18n.tr("Enter this passkey on ") + deviceName;
                case "authorize":
                    return I18n.tr("Authorize pairing with ") + deviceName;
                case "pin":
                    return I18n.tr("Enter PIN for ") + deviceName;
                case "passkey":
                    return I18n.tr("Enter passkey for ") + deviceName;
                default:
                    if (requestType.startsWith("authorize-service"))
                        return I18n.tr("Authorize service for ") + deviceName;
                    return deviceName;
                }
            }

            function cancelPairing() {
                if (token) {
                    DMSService.bluetoothCancelPairing(token);
                }
                close();
                token = "";
                pinInput = "";
                passkeyInput = "";
            }

            anchors.fill: parent
            focus: true
            implicitHeight: mainColumn.implicitHeight

            Keys.onEscapePressed: event => {
                if (token) {
                    DMSService.bluetoothCancelPairing(token);
                }
                close();
                token = "";
                pinInput = "";
                passkeyInput = "";
                event.accepted = true;
            }

            // Coreflame: Enter confirms, as the form's answers say ("↵ confirm")
            Keys.onReturnPressed: event => {
                event.accepted = Form.active && pairingContent.canPair;
                if (event.accepted)
                    submitPairing();
            }

            Column {
                id: mainColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                // Coreflame: the form's frame wants the mockup's wider margins
                anchors.leftMargin: Form.active ? 26 : Theme.spacingM
                anchors.rightMargin: Form.active ? 26 : Theme.spacingM
                anchors.topMargin: Form.active ? 22 : Theme.spacingM
                spacing: requestType === "pin" || requestType === "passkey" ? Theme.spacingM : Theme.spacingS

                CfDialogHead {
                    width: parent.width - 40
                    visible: Form.active
                    glyph: "passage"
                    kind: I18n.tr("Bluetooth")
                    title: I18n.tr("Pair Bluetooth Device")
                }

                CfDialogText {
                    width: parent.width
                    visible: Form.active
                    text: pairingContent.requestText
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingXS
                    visible: !Form.active

                    StyledText {
                        text: I18n.tr("Pair Bluetooth Device")
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Theme.fontWeightMedium
                    }

                    StyledText {
                        text: pairingContent.requestText
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceTextMedium
                        width: parent.width - 40
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 50
                    radius: Theme.cornerRadius
                    color: Theme.floatingWindowFieldColor
                    border.color: pinInputField.activeFocus ? Theme.primary : Theme.outlineStrong
                    border.width: pinInputField.activeFocus ? 2 : 1
                    visible: requestType === "pin"

                    MouseArea {
                        anchors.fill: parent
                        onClicked: () => {
                            pinInputField.forceActiveFocus();
                        }
                    }

                    DTextField {
                        id: pinInputField

                        anchors.fill: parent
                        font.pixelSize: Theme.fontSizeMedium
                        textColor: Theme.surfaceText
                        text: pinInput
                        placeholderText: I18n.tr("Enter PIN")
                        backgroundColor: "transparent"
                        enabled: root.shouldBeVisible
                        onTextEdited: () => {
                            pinInput = text;
                        }
                        onAccepted: () => {
                            submitPairing();
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 50
                    radius: Theme.cornerRadius
                    color: Theme.floatingWindowFieldColor
                    border.color: passkeyInputField.activeFocus ? Theme.primary : Theme.outlineStrong
                    border.width: passkeyInputField.activeFocus ? 2 : 1
                    visible: requestType === "passkey"

                    MouseArea {
                        anchors.fill: parent
                        onClicked: () => {
                            passkeyInputField.forceActiveFocus();
                        }
                    }

                    DTextField {
                        id: passkeyInputField

                        anchors.fill: parent
                        font.pixelSize: Theme.fontSizeMedium
                        textColor: Theme.surfaceText
                        text: passkeyInput
                        placeholderText: I18n.tr("Enter 6-digit passkey")
                        backgroundColor: "transparent"
                        enabled: root.shouldBeVisible
                        onTextEdited: () => {
                            passkeyInput = text;
                        }
                        onAccepted: () => {
                            submitPairing();
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 56
                    radius: Theme.cornerRadius
                    color: Theme.foregroundColor(Theme.cardSurface, Theme.isFloatingWindow(root))
                    border.width: Theme.layerOutlineWidth
                    border.color: Theme.outlineMedium
                    visible: !Form.active && (requestType === "confirm" || requestType === "display-passkey")

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.spacingXXS

                        StyledText {
                            text: I18n.tr("Passkey:", "bluetooth pairing dialog label before the passkey")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceTextMedium
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        StyledText {
                            text: String(passkey).padStart(6, "0")
                            font.pixelSize: Theme.fontSizeXLarge
                            color: Theme.surfaceText
                            font.weight: Theme.fontWeightMedium
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }

                // Coreflame: the passkey as one tile per digit (Phainon coins, Khaslana plates, Reaver shards)
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: Form.active && (requestType === "confirm" || requestType === "display-passkey")
                    spacing: 8
                    Accessible.role: Accessible.StaticText
                    Accessible.name: I18n.tr("Passkey:", "bluetooth pairing dialog label before the passkey") + " " + String(passkey).padStart(6, "0")

                    Repeater {
                        model: String(passkey).padStart(6, "0").split("")

                        Item {
                            id: digit
                            required property string modelData
                            width: 54
                            height: Form.phainon ? 54 : 60

                            Rectangle {
                                visible: Form.khaslana
                                x: 3
                                y: 3
                                width: parent.width
                                height: parent.height
                                color: "#8E1424"
                            }

                            Rectangle {
                                visible: !Form.reaver
                                anchors.fill: parent
                                radius: Form.phainon ? width / 2 : 0
                                color: Form.phainon ? "#FBF9F3" : "#0B080B"
                                border.width: 1
                                border.color: Form.phainon ? "#A87A22" : "#E0B04A"
                            }

                            CfQuad {
                                visible: Form.reaver
                                anchors.fill: parent
                                points: [[0, 0.06], [1, 0], [0.94, 1], [0.04, 0.92]]
                                fill: "#1C1828"
                            }

                            Text {
                                anchors.centerIn: parent
                                text: digit.modelData
                                font.family: Form.phainon ? "Marcellus" : (Form.khaslana ? "Cinzel" : "Chakra Petch")
                                font.pixelSize: 28
                                color: Form.phainon ? "#334786" : (Form.khaslana ? "#F5D27A" : "#E9E7F2")
                            }
                        }
                    }
                }

                // Coreflame: the form's buttons, or the Reaver's words with keys
                Item {
                    width: parent.width
                    height: 36
                    visible: Form.active

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        visible: !Form.reaver

                        DButton {
                            text: I18n.tr("Cancel")
                            backgroundColor: "transparent"
                            textColor: Theme.primary
                            onClicked: pairingContent.cancelPairing()
                        }

                        DButton {
                            text: pairingContent.pairLabel
                            enabled: pairingContent.canPair
                            onClicked: submitPairing()
                        }
                    }

                    CfKeyHints {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Form.reaver
                        model: [
                            {
                                "key": "esc",
                                "text": I18n.tr("Cancel"),
                                "act": () => pairingContent.cancelPairing()
                            },
                            {
                                "key": "↵",
                                "text": pairingContent.pairLabel,
                                "enabled": pairingContent.canPair,
                                "act": () => submitPairing()
                            }
                        ]
                    }
                }

                Item {
                    width: parent.width
                    height: 36
                    visible: !Form.active

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        Rectangle {
                            width: Math.max(70, cancelText.contentWidth + Theme.spacingM * 2)
                            height: 36
                            radius: Theme.cornerRadius
                            color: cancelArea.containsMouse ? Theme.surfaceTextHover : Theme.withAlpha(Theme.surfaceTextHover, 0)
                            border.color: Theme.surfaceVariantAlpha
                            border.width: 1

                            StyledText {
                                id: cancelText

                                anchors.centerIn: parent
                                text: I18n.tr("Cancel")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                font.weight: Theme.fontWeightMedium
                            }

                            MouseArea {
                                id: cancelArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: () => {
                                    if (token) {
                                        DMSService.bluetoothCancelPairing(token);
                                    }
                                    close();
                                    token = "";
                                    pinInput = "";
                                    passkeyInput = "";
                                }
                            }
                        }

                        Rectangle {
                            width: Math.max(80, pairText.contentWidth + Theme.spacingM * 2)
                            height: 36
                            radius: Theme.cornerRadius
                            color: pairArea.containsMouse ? Qt.darker(Theme.primary, 1.1) : Theme.primary
                            enabled: {
                                if (requestType === "pin")
                                    return pinInput.length > 0;
                                if (requestType === "passkey")
                                    return passkeyInput.length === 6;
                                return true;
                            }
                            opacity: enabled ? 1 : 0.5

                            StyledText {
                                id: pairText

                                anchors.centerIn: parent
                                text: {
                                    switch (requestType) {
                                    case "confirm":
                                    case "display-passkey":
                                        return I18n.tr("Confirm");
                                    case "authorize":
                                        return I18n.tr("Authorize", "verb, bluetooth pairing dialog confirm button");
                                    default:
                                        if (requestType.startsWith("authorize-service"))
                                            return I18n.tr("Authorize");
                                        return I18n.tr("Pair", "verb, bluetooth device pairing button");
                                    }
                                }
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.background
                                font.weight: Theme.fontWeightMedium
                            }

                            MouseArea {
                                id: pairArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: parent.enabled
                                onClicked: () => {
                                    submitPairing();
                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }
                        }
                    }
                }
            }

            DActionButton {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: Theme.spacingM
                anchors.rightMargin: Theme.spacingM
                iconName: "close"
                Accessible.name: I18n.tr("Cancel")
                iconSize: Theme.iconSize - 4
                iconColor: Theme.surfaceText
                onClicked: () => {
                    if (token) {
                        DMSService.bluetoothCancelPairing(token);
                    }
                    close();
                    token = "";
                    pinInput = "";
                    passkeyInput = "";
                }
            }
        }
    }

    function submitPairing() {
        const secrets = {};

        switch (requestType) {
        case "pin":
            secrets["pin"] = pinInput;
            break;
        case "passkey":
            secrets["passkey"] = passkeyInput;
            break;
        case "confirm":
        case "display-passkey":
        case "authorize":
            secrets["decision"] = "yes";
            break;
        default:
            if (requestType.startsWith("authorize-service")) {
                secrets["decision"] = "yes";
            }
            break;
        }

        DMSService.bluetoothSubmitPairing(token, secrets, true, response => {
            if (response.error) {
                ToastService.showError(I18n.tr("Pairing failed"), response.error);
            }
        });

        close();
        token = "";
        pinInput = "";
        passkeyInput = "";
    }
}
