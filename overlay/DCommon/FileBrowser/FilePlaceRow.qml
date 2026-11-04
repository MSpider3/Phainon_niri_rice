pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.DCommon.Common
import qs.DCommon.Widgets
import qs.Common as Shell
import qs.Widgets as Cf

StyledButton {
    id: row

    property string label: ""
    property string subtitle: ""
    property string tooltipText: ""
    property string iconName: ""
    property string glyph: ""
    property string actionIcon: ""
    property string actionTooltip: ""
    property real ringValue: -1
    property bool busy: false
    property bool selected: false
    // Coreflame: the row's place in the list, written as a Roman numeral by Khaslana (0: none)
    property int number: 0
    readonly property bool cf: Shell.Form.active
    readonly property string numeral: number > 0 && number <= 12 ? ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"][number - 1] : ""

    property string dropPath: ""
    property bool springLoad: true

    signal actionTriggered
    signal dropped(var drop)
    signal springLoaded
    signal middleClicked

    readonly property bool showAction: actionIcon !== "" && (hovered || actionArea.containsMouse)
    readonly property color contentColor: {
        if (!enabled)
            return Style.onSurface_38;
        if (cf)
            return selected ? ink.selText : ink.text;
        return selected ? Style.onSelectedContainer : Style.surfaceText;
    }
    readonly property color cfIconColor: Shell.Form.phainon ? "#334786" : selected ? ink.selIcon : ink.icon

    Cf.CfInk {
        id: ink
    }

    focusPolicy: Qt.TabFocus
    width: parent?.width ?? 0
    implicitHeight: Math.max(FileBrowserMetrics.sidebarRowHeight, labels.implicitHeight + Style.spacingM)
    radius: cf ? (Shell.Form.phainon ? height / 2 : 0) : FileBrowserMetrics.sidebarRowRadius
    color: dropZone.containsDrag ? Style.primaryContainer : selected && !cf ? Style.selectedContainer : "transparent"
    Accessible.name: label
    Accessible.description: tooltipText

    Cf.CfPick {
        anchors.fill: parent
        visible: row.cf && row.selected && !dropZone.containsDrag
        kind: "side"
    }

    FileDropArea {
        id: dropZone

        anchors.fill: parent
        dropPath: row.dropPath
        enabled: row.dropPath !== ""
        springLoad: row.springLoad && !row.selected
        onDropped: drop => row.dropped(drop)
        onSpringLoaded: row.springLoaded()
    }

    TapHandler {
        acceptedButtons: Qt.MiddleButton
        onTapped: row.middleClicked()
    }

    StateLayer {
        control: row
        tooltipText: actionArea.containsMouse && row.actionTooltip !== "" ? "" : row.tooltipText
        tooltipMultiline: true
        stateColor: row.contentColor
    }

    FocusRing {
        visible: row.visualFocus
        anchors.margins: Style.focusRingWidth / 2
        radius: Math.max(0, row.radius - Style.focusRingWidth / 2)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.spacingS
        anchors.rightMargin: Style.spacingM
        spacing: Style.spacingM

        StyledText {
            visible: row.cf && Shell.Form.khaslana && row.numeral !== ""
            Layout.preferredWidth: 26
            horizontalAlignment: Text.AlignRight
            text: row.numeral
            color: row.selected ? "#F5D27A" : "#B0824A"
            font.family: "Cinzel"
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }

        DRingGauge {
            Layout.preferredWidth: FileBrowserMetrics.sidebarIconSize
            Layout.preferredHeight: FileBrowserMetrics.sidebarIconSize
            value: row.ringValue
            strokeWidth: Style.spinnerStrokeWidth
            ringColor: row.ringValue >= FileBrowserMetrics.usageWarnRatio ? Style.error : Style.primary
            trackColor: Style.surfaceContainerHighest

            Rectangle {
                anchors.fill: parent
                radius: Style.fullRadius(width, height)
                color: row.showAction ? Style.primaryContainer : row.cf ? "transparent" : Style.withAlpha(Style.primary, Style.tonalTintAlpha)

                DSpinner {
                    anchors.centerIn: parent
                    visible: row.busy
                    size: FileBrowserMetrics.sidebarGlyphSize
                    color: Style.primary
                }

                FileIcon {
                    anchors.centerIn: parent
                    visible: !row.busy && !row.showAction
                    iconName: row.iconName
                    glyph: row.glyph
                    size: FileBrowserMetrics.sidebarGlyphSize
                    color: row.cf ? row.cfIconColor : Style.primary
                }

                DIcon {
                    anchors.centerIn: parent
                    visible: !row.busy && row.showAction
                    name: row.actionIcon
                    size: FileBrowserMetrics.sidebarGlyphSize
                    color: Style.onPrimaryContainer
                }

                DTooltipHost {
                    text: row.actionTooltip
                    target: actionArea
                    hoverArea: actionArea
                    enabled: actionArea.enabled
                }

                MouseArea {
                    id: actionArea

                    anchors.fill: parent
                    enabled: row.actionIcon !== "" && !row.busy
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: row.actionTriggered()
                }
            }
        }

        ColumnLayout {
            id: labels

            Layout.fillWidth: true
            spacing: Style.spacingXS

            StyledText {
                Layout.fillWidth: true
                text: row.cf ? ink.tx(row.label) : row.label
                color: row.contentColor
                font.family: row.cf ? ink.font : resolvedFontFamily
                font.pixelSize: row.cf ? 15 : Style.fontSizeMedium
                wrapMode: Text.NoWrap
                elide: Text.ElideMiddle
            }

            StyledText {
                Layout.fillWidth: true
                visible: row.subtitle !== ""
                text: row.subtitle
                color: row.selected || !row.enabled ? row.contentColor : Style.onSurfaceVariant
                font.pixelSize: Style.fontSizeSmall
                wrapMode: Text.NoWrap
                elide: Text.ElideMiddle
            }
        }
    }
}
