import QtQuick
import qs.Common
import qs.DCommon.Widgets as DW

// A numbered row: Phainon a capsule, Khaslana a plate numbered in Roman, the Flame Reaver a
// ruled line; the picked one on the form's picked row with a return mark.
Item {
    id: cfRow

    required property var model
    required property int index
    property bool isSelected: false

    signal clicked
    signal pointerMoved

    readonly property bool lit: isSelected || rowArea.containsMouse

    CfInk {
        id: rowInk
    }

    Rectangle {
        anchors.fill: parent
        visible: !Form.reaver
        radius: Form.phainon ? height / 2 : 0
        color: Form.phainon ? "#FBF9F3" : "#140C0F"
        border.width: 1
        border.color: Form.phainon ? "#ECE3CC" : "#3A1A1E"
    }

    Rectangle {
        visible: Form.reaver
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: "#2C2840"
    }

    CfPick {
        anchors.fill: parent
        kind: Form.phainon ? "side" : "menu"
        visible: cfRow.lit
        opacity: cfRow.isSelected ? 1 : 0.5
    }

    Rectangle {
        anchors.fill: parent
        visible: Form.khaslana && cfRow.isSelected
        color: "transparent"
        border.width: 1
        border.color: "#F2C75C"
    }

    DW.StyledText {
        id: rowNumber
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 34
        horizontalAlignment: Text.AlignRight
        text: {
            const n = cfRow.index + 1;
            if (Form.khaslana && n <= 12)
                return ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"][n - 1];
            return n < 10 ? "0" + n : String(n);
        }
        color: Form.khaslana ? "#B0824A" : rowInk.head
        font.family: Form.khaslana ? "Cinzel" : "Chakra Petch"
        font.pixelSize: 12
    }

    DW.StyledText {
        anchors.left: rowNumber.right
        anchors.leftMargin: 12
        anchors.right: rowMark.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: rowInk.tx(cfRow.model.name || "")
        color: cfRow.isSelected ? rowInk.selText : rowInk.text
        font.family: rowInk.font
        font.pixelSize: Form.reaver ? 14 : 15
        elide: Text.ElideRight
    }

    DW.StyledText {
        id: rowMark
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        visible: cfRow.isSelected
        text: "↵"
        color: Form.phainon ? rowInk.muted : rowInk.accent
        font.pixelSize: 12
    }

    MouseArea {
        id: rowArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: cfRow.clicked()
        onPositionChanged: cfRow.pointerMoved()
    }
}
