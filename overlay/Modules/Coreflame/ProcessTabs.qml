import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Widgets

// The system monitor's four tabs, one look per form: soft paper pills (Phainon), cut gold plates
// (Khaslana), plain lowercase words with a violet underline and an ember on change (Flame Reaver).
Row {
    id: root

    property var tabs: []
    property int current: 0
    readonly property var icons: ["list_alt", "monitoring", "storage", "computer"]

    signal picked(int index)

    height: 34
    spacing: Form.reaver ? 2 : 6

    Repeater {
        model: root.tabs

        Item {
            id: tab
            required property string modelData
            required property int index
            readonly property bool selected: root.current === index

            width: (root.width - root.spacing * (root.tabs.length - 1)) / root.tabs.length
            height: root.height

            onSelectedChanged: {
                if (selected && Form.reaver)
                    ember.flare();
            }

            CfSurface {
                anchors.fill: parent
                visible: !Form.reaver && (tab.selected || hover.hovered)
                color: tab.selected ? Theme.withAlpha(Theme.primary, Form.khaslana ? 0.22 : 0.16) : Theme.withAlpha(Theme.surfaceText, 0.06)
                edgeColor: Theme.withAlpha(Theme.primary, tab.selected ? 0.9 : 0.3)
                edgeWidth: Form.khaslana && tab.selected ? 1 : 0
                radius: height / 2
                cut: 8
            }

            Row {
                anchors.centerIn: parent
                spacing: 6

                DIcon {
                    visible: !Form.reaver
                    anchors.verticalCenter: parent.verticalCenter
                    name: root.icons[tab.index] ?? ""
                    size: 16
                    color: tab.selected ? Theme.primary : Theme.surfaceVariantText
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Form.reaver ? tab.modelData.toLowerCase() : tab.modelData
                    font.family: Form.display(Theme.fontFamily)
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: tab.selected ? Font.DemiBold : Font.Medium
                    font.letterSpacing: Form.khaslana ? 0.8 : 0
                    color: tab.selected ? (Form.reaver ? Theme.surfaceText : Theme.primary) : Theme.surfaceVariantText
                }
            }

            // Flame Reaver: the chosen word is underlined in his lining violet.
            Rectangle {
                visible: Form.reaver && tab.selected
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 3
                width: parent.width * 0.5
                height: 1.5
                color: Theme.live
            }

            CfEmber {
                id: ember
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.bottom
                anchors.verticalCenterOffset: -3
                size: 10
            }

            HoverHandler {
                id: hover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: root.picked(tab.index)
            }
        }
    }
}
