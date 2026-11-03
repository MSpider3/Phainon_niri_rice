import QtQuick
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets as DW

// One control-centre switch in the form's shape. A switch with a menu opens it beneath itself
// (the layout places the menu); `expand` asks for that, `clicked` flips the switch or runs it.
//   Khaslana: a block tile, red when on.  Flame Reaver: a ledger row closed by his crossed
//   blades (one blade when off).  Phainon: a paper row, or a medallion (`medal`).
Item {
    id: sw

    required property var cc
    property string icon: ""
    property string label: ""
    property string sub: ""
    property bool on: false
    // Flips something (wifi, mute, night mode...). Without it a click opens the menu or runs it.
    property bool toggle: false
    property bool menu: false
    property bool open: false
    property bool medal: false
    // A plain row even in Khaslana (the schedule, plugins, tray, running apps)
    property bool line: false
    property color tint: "transparent"
    property color labelColor: pal.ink
    property color iconColor: pal.accent
    property color rimColor: pal.rim
    signal clicked
    signal expand

    readonly property string look: medal ? "medal" : (cc.lay === "khaslana" && !line ? "tile" : "row")
    readonly property var pal: cc.pal

    function press() {
        if (look === "tile" ? (toggle || !menu) : !menu)
            clicked();
        else
            expand();
    }

    implicitHeight: look === "tile" ? 104 : (look === "medal" ? 78 : (cc.lay === "reaver" ? 34 : 40))

    // Khaslana's red offset under a lit block
    Rectangle {
        visible: sw.look === "tile" && sw.on
        x: 4
        y: 4
        width: parent.width
        height: parent.height
        color: "#3A0A12"
    }

    Rectangle {
        visible: sw.look !== "medal"
        anchors.fill: parent
        radius: sw.look === "row" && sw.cc.lay === "phainon" ? 12 : 0
        bottomLeftRadius: sw.open && sw.cc.lay === "phainon" ? 0 : radius
        bottomRightRadius: bottomLeftRadius
        gradient: sw.look === "tile" && sw.on ? lit : null
        color: sw.open ? sw.pal.openBg : (mouse.containsMouse ? sw.pal.hover : sw.pal.plate)
        border.width: sw.cc.lay === "reaver" && !sw.open ? 0 : 1
        border.color: sw.open || (sw.look === "tile" && sw.on) ? sw.pal.edge : sw.rimColor

        Gradient {
            id: lit
            orientation: Gradient.Vertical
            GradientStop {
                position: 0
                color: "#8E1424"
            }
            GradientStop {
                position: 1
                color: "#3A0A12"
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.press()
    }

    // Khaslana: icon top left, chevron top right, name and state at the foot
    Item {
        visible: sw.look === "tile"
        anchors.fill: parent
        anchors.margins: 12

        DW.DIcon {
            name: sw.icon
            size: 24
            color: sw.on ? "#F5D27A" : "#E0B04A"
        }

        DW.DIcon {
            visible: sw.menu
            anchors.right: parent.right
            name: sw.open ? "expand_less" : "expand_more"
            size: 18
            color: "#C9B89E"

            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                onClicked: sw.expand()
            }
        }

        Column {
            anchors.bottom: parent.bottom
            width: parent.width
            spacing: 1

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: sw.label
                font.family: "Chakra Petch"
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: sw.on ? "#F5D27A" : "#F3E6CC"
            }

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: sw.sub
                font.family: "Chakra Petch"
                font.pixelSize: 13
                color: sw.on ? "#F2C75C" : "#C9B89E"
            }
        }
    }

    // Reaver and Phainon rows: icon, name, state, then the toggle or chevron
    DW.DIcon {
        id: rowIcon
        visible: sw.look === "row"
        x: sw.cc.lay === "reaver" ? 8 : 12
        anchors.verticalCenter: parent.verticalCenter
        name: sw.icon
        size: 18
        color: sw.iconColor
    }

    Text {
        visible: sw.look === "row"
        x: rowIcon.x + 28
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, parent.width - x - rowNote.implicitWidth - tail.width - 24)
        elide: Text.ElideRight
        text: sw.cc.tx(sw.label)
        font.family: sw.cc.body
        font.pixelSize: 14
        font.weight: sw.open ? Font.DemiBold : Font.Normal
        color: sw.labelColor
    }

    Text {
        id: rowNote
        visible: sw.look === "row"
        anchors.right: tail.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, parent.width * 0.45)
        elide: Text.ElideRight
        text: sw.cc.tx(sw.sub) + (sw.cc.lay === "reaver" && sw.menu ? (sw.open ? " ▴" : " ›") : "")
        font.family: sw.cc.body
        font.pixelSize: 13
        color: sw.tint.a > 0 ? sw.tint : sw.pal.mut
    }

    Item {
        id: tail
        visible: sw.look === "row"
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: sw.cc.lay === "reaver" ? (sw.toggle ? 22 : 0) : (sw.menu ? 18 : 0)
        height: 20

        // The Flame Reaver's toggle: crossed blades when on, a single blade when off
        CfCrossToggle {
            visible: sw.cc.lay === "reaver" && sw.toggle
            anchors.centerIn: parent
            width: 18
            height: 18
            checked: sw.on
            color: "#CFC6A8"
            onClicked: sw.clicked()
        }

        DW.DIcon {
            visible: sw.cc.lay !== "reaver" && sw.menu
            anchors.centerIn: parent
            name: sw.open ? "expand_less" : "expand_more"
            size: 18
            color: sw.pal.edge
        }
    }

    // Phainon's medallion with its name beneath
    Rectangle {
        id: med
        visible: sw.look === "medal"
        anchors.horizontalCenter: parent.horizontalCenter
        width: 46
        height: 46
        radius: 23
        color: sw.on ? sw.pal.lapis : sw.pal.plate
        border.width: sw.on ? 3 : 1
        border.color: sw.on ? Qt.rgba(168 / 255, 122 / 255, 34 / 255, 0.35) : sw.pal.rim2

        DW.DIcon {
            anchors.centerIn: parent
            name: sw.icon
            size: 20
            color: sw.on ? (sw.cc.parch ? "#F7F3E8" : Theme.primaryText) : sw.pal.lapis
        }
    }

    Text {
        visible: sw.look === "medal"
        anchors.top: med.bottom
        anchors.topMargin: 4
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        text: sw.label
        font.family: sw.cc.body
        font.pixelSize: 12
        lineHeight: 0.95
        color: sw.pal.ink
    }
}
