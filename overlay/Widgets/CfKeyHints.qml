import QtQuick

// The Flame Reaver's answers: plain words with their key in bold violet ("esc cancel   ↵ connect")
// instead of boxed buttons. Each word still clicks. model: [{ key, text, act, danger, enabled, selected }]
Row {
    id: hints

    property var model: []

    spacing: 18

    Repeater {
        model: hints.model

        Item {
            id: hint

            required property var modelData
            readonly property bool on: modelData.enabled !== false

            width: words.implicitWidth + 12
            height: 28
            opacity: on ? 1 : 0.4
            Accessible.role: Accessible.Button
            Accessible.name: modelData.text

            // The keyboard's current pick, as the Reaver marks a selection
            Rectangle {
                anchors.fill: parent
                visible: !!hint.modelData.selected
                color: "#2E2650"
                border.width: 1
                border.color: "#B9A8FF"
            }

            Row {
                id: words
                anchors.centerIn: parent
                spacing: 6

                Text {
                    visible: text !== ""
                    text: hint.modelData.key ?? ""
                    font.family: "Chakra Petch"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: hint.modelData.danger ? "#F07A85" : "#B9A8FF"
                }

                Text {
                    text: String(hint.modelData.text ?? "").toLowerCase()
                    font.family: "Chakra Petch"
                    font.pixelSize: 14
                    color: "#A8A4BC"
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: hint.on
                cursorShape: Qt.PointingHandCursor
                onClicked: hint.modelData.act()
            }
        }
    }
}
