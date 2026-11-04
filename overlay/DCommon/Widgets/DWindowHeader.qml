import QtQuick
import qs.DCommon.Common
import qs.Common as Shell

Item {
    id: root

    required property var controls
    property string title: ""
    property real titleFontSize: Style.fontSizeLarge
    property int titleWeight: Style.fontWeightMedium
    property int titleAlignment: Text.AlignHCenter
    property bool wrapTitle: false
    property real horizontalPadding: -1
    property real verticalPadding: Style.windowInset
    property bool showDivider: false // !TODO: plugin compat, the header no longer draws a divider
    property string subtitle: ""
    property string iconName: "" // !TODO: plugin compat, the header no longer draws an icon
    property bool closeEnabled: true
    property string closeTooltipText: ""
    default property alias actions: extraActions.data

    readonly property bool compositorDecorated: controls !== null && !Host.ownWindowDecorations
    readonly property bool hasActions: extraActions.children.length > 0
    readonly property bool collapsed: compositorDecorated && !hasActions
    readonly property bool centered: titleAlignment === Text.AlignHCenter
    readonly property real edgeInset: horizontalPadding >= 0 ? horizontalPadding : Style.windowInset
    readonly property real titleGap: horizontalPadding >= 0 ? horizontalPadding : Style.spacingM
    readonly property real buttonsReserve: buttons.width + edgeInset + titleGap

    signal closeRequested

    // Coreflame: Phainon a Marcellus title, Khaslana a spaced Cinzel title over a gold rule and red echo,
    // Reaver a "// " prefix and a lower-case title over a thin rule.
    readonly property bool cf: Shell.Form.active

    function cfEscape(t) {
        return String(t).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    implicitHeight: collapsed ? verticalPadding : Math.max(buttons.implicitHeight, titleColumn.implicitHeight) + verticalPadding * 2
    height: implicitHeight
    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    component WindowButton: DActionButton {
        buttonSize: Style.buttonHeightXS
        iconSize: Style.iconSizeSmall
        iconColor: Style.onSurfaceVariant
    }

    MouseArea {
        anchors.left: parent.left
        anchors.right: buttons.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.rightMargin: Style.spacingM
        enabled: root.controls !== null && !root.compositorDecorated
        onPressed: root.controls.tryStartMove()
        onDoubleClicked: root.controls.tryToggleMaximize()
    }

    Column {
        id: titleColumn
        width: root.centered ? Math.max(0, root.width - 2 * Math.max(root.edgeInset, root.buttonsReserve)) : Math.max(0, root.width - root.edgeInset - root.buttonsReserve)
        x: root.centered ? (root.width - width) / 2 : (LayoutMirroring.enabled ? root.buttonsReserve : root.edgeInset)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.spacingXS
        visible: !root.compositorDecorated

        StyledText {
            width: parent.width
            text: root.cf && Shell.Form.reaver && root.title !== "" ? "<font color=\"#B9A8FF\">// </font>" + root.cfEscape(root.title.toLowerCase()) : root.title
            textFormat: root.cf && Shell.Form.reaver ? Text.StyledText : Text.PlainText
            font.pixelSize: !root.cf ? root.titleFontSize : (Shell.Form.reaver ? 15 : 17)
            font.weight: !root.cf ? root.titleWeight : (Shell.Form.khaslana ? Font.Bold : Font.Normal)
            font.family: !root.cf ? resolvedFontFamily : (Shell.Form.phainon ? "Marcellus" : (Shell.Form.khaslana ? "Cinzel" : "Chakra Petch"))
            font.capitalization: root.cf && !Shell.Form.reaver ? Font.AllUppercase : Font.MixedCase
            font.letterSpacing: !root.cf ? 0 : (Shell.Form.phainon ? 17 * 0.14 : (Shell.Form.khaslana ? 17 * 0.3 : 0))
            color: !root.cf ? Style.surfaceText : (Shell.Form.phainon ? "#334786" : (Shell.Form.khaslana ? "#F5D27A" : "#CFC6A8"))
            horizontalAlignment: root.titleAlignment
            elide: root.wrapTitle ? Text.ElideNone : Text.ElideRight
            wrapMode: root.wrapTitle ? Text.Wrap : Text.NoWrap
        }

        StyledText {
            width: parent.width
            text: root.cf && Shell.Form.reaver ? root.subtitle.toLowerCase() : root.subtitle
            font.pixelSize: Style.fontSizeSmall
            color: !root.cf ? Style.surfaceTextMedium : (Shell.Form.phainon ? "#4A5484" : (Shell.Form.khaslana ? "#C9B89E" : "#A8A4BC"))
            horizontalAlignment: root.titleAlignment
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
            visible: text !== ""
        }
    }

    Loader {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.edgeInset
        anchors.rightMargin: root.edgeInset
        active: root.cf && !Shell.Form.phainon && titleColumn.visible && root.title !== ""
        sourceComponent: Shell.Form.khaslana ? khRule : rvRule
    }

    Component {
        id: khRule

        Column {
            Rectangle {
                width: parent.width
                height: 2
                color: "#E0B04A"
            }
            Rectangle {
                width: parent.width
                height: 3
                color: "#8E1424"
            }
        }
    }

    Component {
        id: rvRule

        Rectangle {
            height: 1
            color: "#2C2840"
        }
    }

    Row {
        id: buttons
        anchors.right: parent.right
        anchors.rightMargin: root.edgeInset
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.windowInset

        Row {
            id: extraActions
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.windowInset
        }

        WindowButton {
            objectName: "minimizeWindow"
            visible: !root.compositorDecorated && (root.controls?.canMinimize ?? false)
            iconName: "minimize"
            Accessible.name: I18n.tr("Minimize")
            onClicked: root.controls.tryMinimize()
        }

        WindowButton {
            objectName: "maximizeWindow"
            visible: !root.compositorDecorated && (root.controls?.canMaximize ?? false)
            iconName: root.controls?.targetWindow?.maximized ? "fullscreen_exit" : "fullscreen"
            Accessible.name: root.controls?.targetWindow?.maximized ? I18n.tr("Restore") : I18n.tr("Maximize")
            onClicked: root.controls.tryToggleMaximize()
        }

        WindowButton {
            objectName: "closeWindow"
            visible: !root.compositorDecorated
            enabled: root.closeEnabled
            iconName: "close"
            backgroundColor: Style.secondaryContainer
            iconColor: Style.onSecondaryContainer
            tooltipText: root.closeTooltipText || null
            Accessible.name: root.closeTooltipText || I18n.tr("Close")
            onClicked: root.closeRequested()
        }
    }
}
