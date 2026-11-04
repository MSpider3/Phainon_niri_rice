import QtQuick
import QtQuick.Shapes
import qs.Common
import qs.Modals.Common
import qs.DCommon.Widgets
import qs.Widgets

DModal {
    id: root

    property string outputName: ""
    property var changes: []
    property int countdown: 10

    signal confirmed
    signal reverted

    shouldBeVisible: false
    allowStacking: true
    useOverlayLayer: true
    modalWidth: 420
    modalHeight: contentLoader.item ? contentLoader.item.implicitHeight + (Form.active ? 44 : Theme.spacingM * 2) : 200

    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        running: root.shouldBeVisible
        onTriggered: {
            root.countdown--;
            if (root.countdown <= 0) {
                root.reverted();
                root.close();
            }
        }
    }

    onOpened: {
        countdown = 10;
        countdownTimer.start();
    }

    onDialogClosed: {
        countdownTimer.stop();
    }

    onBackgroundClicked: {
        root.reverted();
        root.close();
    }

    function revert() {
        root.reverted();
        root.close();
    }

    function keep() {
        root.confirmed();
        root.close();
    }

    content: Component {
        FocusScope {
            id: confirmContent

            anchors.fill: parent
            focus: true
            implicitHeight: mainColumn.implicitHeight
            // Coreflame: the sentence with the countdown (Phainon beside the ring, Khaslana under the blocks)
            readonly property string cfCountdownText: I18n.tr("Going back to the old layout in %1 seconds unless you keep it.").arg(root.countdown)

            Keys.onEscapePressed: event => {
                root.reverted();
                root.close();
                event.accepted = true;
            }

            Keys.onReturnPressed: event => {
                root.confirmed();
                root.close();
                event.accepted = true;
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
                spacing: Theme.spacingM

                CfDialogHead {
                    width: parent.width - 40
                    visible: Form.active
                    glyph: "time"
                    kind: I18n.tr("Displays")
                    title: I18n.tr("Confirm Display Changes")
                }

                // Coreflame: the countdown in the form's own way, built only for the form showing
                Loader {
                    width: parent.width
                    active: Form.active
                    visible: active
                    sourceComponent: Form.phainon ? ringCountdown : blockCountdown
                }

                CfDialogText {
                    width: parent.width
                    visible: Form.khaslana
                    text: confirmContent.cfCountdownText
                }

                StyledText {
                    visible: !Form.active
                    text: I18n.tr("Confirm Display Changes")
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.surfaceText
                    font.weight: Theme.fontWeightMedium
                }

                Rectangle {
                    visible: !Form.active
                    width: parent.width
                    height: 70
                    radius: Theme.cornerRadius
                    color: Theme.foregroundColor(Theme.cardSurface, Theme.isFloatingWindow(root))
                    border.width: Theme.layerOutlineWidth
                    border.color: Theme.outlineMedium

                    StyledText {
                        anchors.centerIn: parent
                        text: root.countdown + "s"
                        font.pixelSize: Theme.fontSizeXLarge * 1.5
                        color: Theme.primary
                        font.weight: Theme.fontWeightMedium
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingXS
                    visible: root.changes.length > 0

                    Repeater {
                        model: root.changes

                        StyledText {
                            required property var modelData
                            text: modelData
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
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
                            text: I18n.tr("Revert", "verb, undo display changes in confirmation dialog")
                            backgroundColor: "transparent"
                            textColor: Theme.primary
                            onClicked: root.revert()
                        }

                        DButton {
                            text: I18n.tr("Keep Changes")
                            onClicked: root.keep()
                        }
                    }

                    CfKeyHints {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Form.reaver
                        model: [
                            {
                                "key": "esc",
                                "text": I18n.tr("Revert", "verb, undo display changes in confirmation dialog"),
                                "act": () => root.revert()
                            },
                            {
                                "key": "↵",
                                "text": I18n.tr("Keep Changes"),
                                "act": () => root.keep()
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
                            width: Math.max(70, revertText.contentWidth + Theme.spacingM * 2)
                            height: 36
                            radius: Theme.cornerRadius
                            color: revertArea.containsMouse ? Theme.surfaceTextHover : Theme.withAlpha(Theme.surfaceTextHover, 0)
                            border.color: Theme.surfaceVariantAlpha
                            border.width: 1

                            StyledText {
                                id: revertText

                                anchors.centerIn: parent
                                text: I18n.tr("Revert", "verb, undo display changes in confirmation dialog")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                font.weight: Theme.fontWeightMedium
                            }

                            MouseArea {
                                id: revertArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.reverted();
                                    root.close();
                                }
                            }
                        }

                        Rectangle {
                            width: Math.max(80, confirmText.contentWidth + Theme.spacingM * 2)
                            height: 36
                            radius: Theme.cornerRadius
                            color: confirmArea.containsMouse ? Qt.darker(Theme.primary, 1.1) : Theme.primary

                            StyledText {
                                id: confirmText

                                anchors.centerIn: parent
                                text: I18n.tr("Keep Changes")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.background
                                font.weight: Theme.fontWeightMedium
                            }

                            MouseArea {
                                id: confirmArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.confirmed();
                                    root.close();
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

            // Phainon: a gold ring that empties as the seconds run out, the number inside
            Component {
                id: ringCountdown

                Row {
                    spacing: 14

                    Item {
                        width: 54
                        height: 54

                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                fillColor: "transparent"
                                strokeColor: "#E4DAC0"
                                strokeWidth: 6
                                PathAngleArc {
                                    centerX: 27
                                    centerY: 27
                                    radiusX: 24
                                    radiusY: 24
                                    startAngle: 0
                                    sweepAngle: 360
                                }
                            }

                            ShapePath {
                                fillColor: "transparent"
                                strokeColor: "#F2C75C"
                                strokeWidth: 6
                                capStyle: ShapePath.FlatCap
                                PathAngleArc {
                                    centerX: 27
                                    centerY: 27
                                    radiusX: 24
                                    radiusY: 24
                                    startAngle: -90
                                    sweepAngle: 360 * Math.max(0, root.countdown) / 10
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: root.countdown
                            font.family: "Marcellus"
                            font.pixelSize: 18
                            color: "#334786"
                        }
                    }

                    CfDialogText {
                        width: mainColumn.width - 68
                        anchors.verticalCenter: parent.verticalCenter
                        text: confirmContent.cfCountdownText
                    }
                }
            }

            // Khaslana: ten red blocks burning down beside a Roman number; the Reaver: ten skewed violet bars and two digits
            Component {
                id: blockCountdown

                Row {
                    spacing: 14

                    Shape {
                        id: bars
                        readonly property real cell: 22
                        width: 220
                        height: 10
                        anchors.verticalCenter: parent.verticalCenter
                        preferredRendererType: Shape.CurveRenderer

                        // Block i of ten as a polygon; the Reaver's lean 3 px like skewX(-20deg)
                        function block(i) {
                            const x = i * bars.cell, w = bars.cell - (Form.reaver ? 3 : 2), h = Form.reaver ? 9 : 10, k = Form.reaver ? 3 : 0;
                            return `M${x + k} 0H${x + w + k}L${x + w} ${h}H${x}Z`;
                        }
                        function blocks(from, to) {
                            let d = "";
                            for (let i = from; i < to; i++)
                                d += block(i);
                            return d;
                        }
                        readonly property int lit: Math.max(0, Math.min(10, root.countdown))

                        ShapePath {
                            fillColor: Form.reaver ? "#2C2840" : "#2A1015"
                            strokeColor: "transparent"
                            PathSvg {
                                path: bars.blocks(bars.lit, 10)
                            }
                        }
                        ShapePath {
                            fillColor: Form.reaver ? "#8F7BE0" : "#C2252F"
                            strokeColor: "transparent"
                            PathSvg {
                                path: bars.blocks(0, Form.reaver ? bars.lit : bars.lit - 1)
                            }
                        }
                        // Khaslana: the block burning now is gold
                        ShapePath {
                            fillColor: "#F2C75C"
                            strokeColor: "transparent"
                            PathSvg {
                                path: !Form.reaver && bars.lit > 0 ? bars.block(bars.lit - 1) : ""
                            }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Form.reaver ? String(Math.max(0, root.countdown)).padStart(2, "0") : ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"][Math.max(0, Math.min(10, root.countdown))]
                        font.family: Form.reaver ? "Chakra Petch" : "Cinzel"
                        font.pixelSize: Form.reaver ? 15 : 18
                        font.weight: Font.DemiBold
                        color: Form.reaver ? "#B9A8FF" : "#F5D27A"
                    }
                }
            }

            DActionButton {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: Theme.spacingM
                anchors.rightMargin: Theme.spacingM
                iconName: "close"
                Accessible.name: I18n.tr("Close")
                iconSize: Theme.iconSize - 4
                iconColor: Theme.surfaceText
                onClicked: {
                    root.reverted();
                    root.close();
                }
            }
        }
    }
}
