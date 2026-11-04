pragma ComponentBehavior: Bound

import QtQuick
import qs.DCommon.Common
import qs.DCommon.Widgets
import qs.Common as Shell
import qs.Widgets as Cf

Column {
    id: section

    property string title: ""
    property string emptyText: ""
    property bool showEmpty: false

    default property alias rows: body.data

    spacing: FileBrowserMetrics.sidebarRowGap

    // Coreflame: the section name as the form's small header
    StyledText {
        text: Shell.Form.active ? ink.header(section.title) : section.title
        color: Shell.Form.active ? ink.head : Style.primary
        font.family: Shell.Form.active ? ink.headFont : resolvedFontFamily
        font.pixelSize: Shell.Form.active ? ink.headSize : Style.fontSizeMedium
        font.weight: Shell.Form.active ? Font.DemiBold : Style.fontWeightMedium
        font.letterSpacing: Shell.Form.active ? ink.headSpacing : 0
        leftPadding: Style.spacingM
        topPadding: Shell.Form.active ? Style.spacingS : 0
        bottomPadding: Style.spacingXXS
    }

    Cf.CfInk {
        id: ink
    }

    Column {
        id: body

        width: section.width
        spacing: FileBrowserMetrics.sidebarRowGap
    }

    StyledText {
        width: section.width
        visible: section.showEmpty && section.emptyText !== ""
        text: section.emptyText
        color: Style.surfaceVariantText
        font.pixelSize: Style.fontSizeSmall
        leftPadding: Style.spacingM
        rightPadding: Style.spacingM
        wrapMode: Text.Wrap
    }
}
