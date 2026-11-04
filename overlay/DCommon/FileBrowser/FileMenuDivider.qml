import QtQuick
import qs.DCommon.Common
import qs.Common as Shell
import qs.Widgets as Cf

Item {
    width: parent?.width ?? 0
    height: FileBrowserMetrics.menuDividerHeight

    Rectangle {
        anchors.centerIn: parent
        width: parent.width - (Shell.Form.active ? 16 : Style.spacingM * 2)
        height: Shell.Form.active ? 1 : Style.dividerWidth
        color: Shell.Form.active ? ink.rule : Style.outlineVariant
    }

    Cf.CfInk {
        id: ink
    }
}
