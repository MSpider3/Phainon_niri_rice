import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: card

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property int pad: Theme.spacingM

    radius: Theme.cornerRadius
    readonly property bool cfCut: Form.shape === "cut"

    color: cfCut ? "transparent" : Theme.nestedSurface
    border.color: Theme.outlineMedium
    border.width: cfCut ? 0 : 1

    CfSurface {
        anchors.fill: parent
        z: -1
        visible: card.cfCut
        shape: "cut"
        color: Theme.nestedSurface
        edgeColor: Theme.withAlpha(Theme.outline, 0.7)
        edgeWidth: 1
    }

    default property alias content: contentItem.data

    Item {
        id: contentItem
        anchors.fill: parent
        anchors.margins: card.pad
    }
}
