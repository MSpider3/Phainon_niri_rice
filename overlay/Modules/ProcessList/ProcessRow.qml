import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import "../../Common/Format.js" as Format

DListItem {
    id: root

    required property var process
    property real rowHeight: ProcessListMetrics.rowHeight
    property bool isExpanded: false
    readonly property string command: process?.command ?? ""
    readonly property string fullCommand: process?.fullCommand ?? command

    signal killRequested

    // Coreflame: a ruled table row in each form's ink (the v3 mockup), the picked row lit per form
    readonly property color ink: !Form.active ? contentColor : (Form.phainon ? "#1E2752" : (Form.khaslana ? (isSelected ? "#F5D27A" : "#F3E6CC") : "#E9E7F2"))
    readonly property color mutedInk: !Form.active ? supportingContentColor : (isSelected && !Form.phainon ? ink : (Form.phainon ? "#4A5484" : (Form.khaslana ? "#C9B89E" : "#A8A4BC")))

    function tx(text) {
        return Form.reaver ? text.toLowerCase() : text;
    }

    surfaceColor: Theme.foregroundColor(Theme.chipSurface, Theme.isFloatingWindow(root))

    Binding {
        target: root.background
        property: "color"
        value: "transparent"
        when: Form.active
    }

    Binding {
        target: root.border
        property: "width"
        value: 0
        when: Form.active
    }

    Rectangle {
        visible: Form.active && root.isSelected
        anchors.fill: parent
        radius: Form.phainon ? 12 : 0
        color: Form.phainon ? "#4DF1DA4F" : (Form.reaver ? "#2E2650" : "transparent")
        border.width: Form.reaver ? 1 : 0
        border.color: "#B9A8FF"
        gradient: Form.khaslana ? bleed : null

        Gradient {
            id: bleed
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: "#8E1424"
            }
            GradientStop {
                position: 0.7
                color: "#3A0A12"
            }
            GradientStop {
                position: 1
                color: "transparent"
            }
        }

        // Khaslana: the gold inset edge
        Rectangle {
            visible: Form.khaslana
            width: 3
            height: parent.height
            color: "#F2C75C"
        }
    }

    Rectangle {
        visible: Form.active
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Form.phainon ? "#ECE3CC" : (Form.khaslana ? "#2E1A1A" : "#2C2840")
    }

    height: root.rowHeight + (isExpanded ? details.implicitHeight + Theme.spacingM * 2 : 0)
    clip: true
    Accessible.name: command
    Accessible.description: fullCommand

    function processIcon(command) {
        const cmd = command.toLowerCase();
        if (cmd.includes("firefox") || cmd.includes("chrome") || cmd.includes("browser") || cmd.includes("chromium"))
            return "web";
        if (cmd.includes("code") || cmd.includes("editor") || cmd.includes("vim"))
            return "code";
        if (cmd.includes("terminal") || cmd.includes("bash") || cmd.includes("zsh"))
            return "terminal";
        if (cmd.includes("music") || cmd.includes("audio") || cmd.includes("spotify"))
            return "music_note";
        if (cmd.includes("video") || cmd.includes("vlc") || cmd.includes("mpv"))
            return "play_circle";
        if (cmd.includes("systemd") || cmd.includes("elogind") || cmd.includes("kernel") || cmd.includes("kthread") || cmd.includes("kworker"))
            return "settings";
        return "memory";
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Theme.spacingL
        anchors.rightMargin: Theme.spacingL
        height: root.rowHeight
        spacing: Theme.spacingS

        DIcon {
            name: root.processIcon(root.command)
            size: Theme.iconSize
            color: root.ink
        }

        Column {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: 0
            spacing: 0

            StyledText {
                id: nameText
                width: parent.width
                maximumLineCount: 1
                text: root.command
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Theme.fontWeightMedium
                color: root.ink
                textFormat: Text.PlainText
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width
                height: Math.min(implicitHeight, Math.max(0, root.rowHeight - nameText.implicitHeight - Theme.spacingXS * 2))
                maximumLineCount: 2
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                text: root.fullCommand
                font.pixelSize: Theme.fontSizeSmall
                color: root.mutedInk
                textFormat: Text.PlainText
                elide: Text.ElideRight
            }
        }

        NumericText {
            visible: !Form.active
            Layout.minimumWidth: ProcessListMetrics.cpuColumnWidth
            Layout.maximumWidth: ProcessListMetrics.cpuColumnWidth
            elide: Text.ElideRight
            maximumLineCount: 1
            reserveText: "9999.9%"
            text: (root.process?.cpu ?? 0).toFixed(1) + "%"
            isMonospace: false
            horizontalAlignment: Text.AlignRight
            font.pixelSize: Theme.fontSizeSmall
            color: root.ink
        }

        // Coreflame: the CPU column is the process's share, drawn per form, in place of the number
        ShareBar {
            share: (root.process?.cpu ?? 0) / 100
            Layout.minimumWidth: ProcessListMetrics.cpuColumnWidth
            Layout.maximumWidth: ProcessListMetrics.cpuColumnWidth
        }

        NumericText {
            Layout.minimumWidth: ProcessListMetrics.memoryColumnWidth
            Layout.maximumWidth: ProcessListMetrics.memoryColumnWidth
            elide: Text.ElideRight
            maximumLineCount: 1
            reserveText: "999.9 GB"
            text: root.tx(Format.formatBytes((root.process?.memoryKB ?? 0) * 1024))
            isMonospace: false
            horizontalAlignment: Text.AlignRight
            font.pixelSize: Theme.fontSizeSmall
            color: root.ink
        }

        NumericText {
            Layout.minimumWidth: ProcessListMetrics.pidColumnWidth
            Layout.maximumWidth: ProcessListMetrics.pidColumnWidth
            elide: Text.ElideRight
            maximumLineCount: 1
            reserveText: "9999999"
            text: (root.process?.pid ?? 0).toString()
            isMonospace: false
            horizontalAlignment: Text.AlignRight
            font.pixelSize: Theme.fontSizeSmall
            color: root.mutedInk
        }

        Item {
            Layout.minimumWidth: ProcessListMetrics.actionColumnWidth
            Layout.maximumWidth: ProcessListMetrics.actionColumnWidth
            Layout.preferredHeight: Theme.iconButtonSize

            DActionButton {
                anchors.centerIn: parent
                iconName: "close"
                iconColor: root.ink
                tooltipText: root.tx(I18n.tr("Kill Process"))
                focusPolicy: activeFocus || root.isSelected ? Qt.StrongFocus : Qt.ClickFocus
                visible: root.hovered || root.isSelected || activeFocus
                enabled: (root.process?.pid ?? 0) > 0
                onClicked: root.killRequested()
            }
        }
    }

    ColumnLayout {
        id: details
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: root.rowHeight
        anchors.leftMargin: Theme.spacingL
        anchors.rightMargin: Theme.spacingL
        spacing: Theme.spacingXS
        visible: root.isExpanded

        RowLayout {
            Layout.fillWidth: true

            StyledText {
                Layout.fillWidth: true
                text: root.fullCommand
                font.pixelSize: Theme.fontSizeSmall
                color: root.ink
                textFormat: Text.PlainText
                wrapMode: Text.WrapAnywhere
            }

            DActionButton {
                iconName: "content_copy"
                iconColor: root.ink
                tooltipText: root.tx(I18n.tr("Copy Full Command"))
                onClicked: Quickshell.execDetached(["dms", "cl", "copy", root.fullCommand])
            }
        }

        StyledText {
            Layout.fillWidth: true
            elide: Text.ElideRight
            maximumLineCount: 1
            text: root.tx("PPID" + ": " + (root.process?.ppid ?? 0) + " · " + I18n.tr("Memory") + ": " + (root.process?.memoryPercent ?? 0).toFixed(1) + "%")
            font.pixelSize: Theme.fontSizeSmall
            color: root.ink
        }
    }
}
