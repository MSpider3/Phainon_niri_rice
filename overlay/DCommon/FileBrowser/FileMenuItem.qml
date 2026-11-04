pragma ComponentBehavior: Bound

import QtQuick
import qs.DCommon.Common
import qs.DCommon.Widgets
import qs.Common as Shell
import qs.Widgets as Cf

StyledButton {
    id: root

    property string iconName: ""
    property bool submenu: false
    property bool danger: false
    property bool highlighted: false

    // Coreflame: the form's ink and picked row
    readonly property bool cf: Shell.Form.active
    readonly property bool lit: enabled && (hovered || highlighted)
    readonly property color contentColor: {
        if (!enabled)
            return cf ? Shell.Theme.withAlpha(ink.muted, 0.5) : Style.onSurface_38;
        if (cf)
            return danger ? ink.danger : lit ? ink.selText : ink.text;
        return danger ? Style.error : Style.surfaceText;
    }
    readonly property color iconColor: {
        if (cf && enabled && !danger)
            return lit ? ink.selIcon : ink.icon;
        if (cf)
            return contentColor;
        if (!enabled)
            return Style.onSurface_38;
        return danger ? Style.error : Style.surfaceVariantText;
    }

    Cf.CfInk {
        id: ink
    }

    width: parent?.width ?? 0
    implicitHeight: Style.menuItemHeight
    radius: cf ? (Shell.Form.phainon ? height / 2 : 0) : Style.cornerRadiusS
    color: "transparent"

    Cf.CfPick {
        anchors.fill: parent
        visible: root.cf && root.lit
    }

    StateLayer {
        control: root
        disabled: !root.enabled
        hovered: root.hovered || root.highlighted
        stateColor: root.cf ? "transparent" : root.contentColor
    }

    FocusRing {
        visible: root.visualFocus
        anchors.margins: Style.focusRingWidth / 2
        radius: Math.max(0, root.radius - Style.focusRingWidth / 2)
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: Style.spacingM
        anchors.rightMargin: Style.spacingM
        spacing: Style.spacingM

        DIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.iconName !== ""
            name: root.iconName
            size: Style.iconSizeMedium
            color: root.iconColor
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - (root.iconName !== "" ? Style.iconSizeMedium + parent.spacing : 0) - (root.submenu || root.checked ? Style.iconSizeMedium + Style.spacingM : 0)
            text: root.cf ? ink.tx(root.text) : root.text
            color: root.contentColor
            font.family: root.cf ? ink.font : resolvedFontFamily
            font.pixelSize: root.cf ? 14 : Style.fontSizeMedium
            horizontalAlignment: Text.AlignLeft
            wrapMode: Text.NoWrap
            elide: Text.ElideRight
        }
    }

    DIcon {
        anchors.right: parent.right
        anchors.rightMargin: Style.spacingM
        anchors.verticalCenter: parent.verticalCenter
        visible: root.submenu || root.checked
        name: root.submenu ? "chevron_right" : "check"
        size: Style.iconSizeMedium
        color: root.cf ? root.iconColor : root.submenu ? Style.surfaceVariantText : Style.primary
    }
}
