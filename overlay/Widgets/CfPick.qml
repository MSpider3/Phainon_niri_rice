import QtQuick
import qs.Common

// The picked / hovered row or tile, per form as the v3 mockup draws it.
// kind "menu": Phainon a gold-washed pill; Khaslana a red bleed with a gold bar on the left;
//              the Flame Reaver a violet slab with a thin violet outline.
// kind "side": as "menu", but Phainon's wash fades to the right inside a gold outline.
// kind "tile": Phainon a gold-washed rounded tile in a gold outline; Khaslana a red bleed falling
//              downwards in a gold outline; the Flame Reaver as "menu".
Item {
    id: pick

    property string kind: "menu"

    readonly property bool kh: Form.khaslana
    readonly property bool rv: Form.reaver
    readonly property bool ph: !kh && !rv
    readonly property bool tile: kind === "tile"

    // Phainon's flat wash, Khaslana's and the Reaver's outlines
    Rectangle {
        anchors.fill: parent
        visible: !pick.kh || pick.tile
        radius: pick.ph ? (pick.tile ? 16 : height / 2) : 0
        color: pick.rv ? "#2E2650" : (pick.ph && pick.kind !== "side" ? (pick.tile ? "#59F1DA4F" : "#66F1DA4F") : "transparent")
        border.width: pick.ph && pick.kind === "menu" ? 0 : 1
        border.color: pick.ph ? "#A87A22" : (pick.kh ? "#F2C75C" : "#B9A8FF")
        z: 1
    }

    // Phainon's side row: the wash fading to the right
    Rectangle {
        anchors.fill: parent
        visible: pick.ph && pick.kind === "side"
        radius: height / 2
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: "#73F1DA4F"
            }
            GradientStop {
                position: 1
                color: "#1AF1DA4F"
            }
        }
    }

    // Khaslana: the red bleed, sideways for rows, downwards for tiles
    Rectangle {
        anchors.fill: parent
        visible: pick.kh
        gradient: Gradient {
            orientation: pick.tile ? Gradient.Vertical : Gradient.Horizontal
            GradientStop {
                position: 0
                color: "#8E1424"
            }
            GradientStop {
                position: pick.tile ? 1 : 0.75
                color: "#3A0A12"
            }
        }
    }

    Rectangle {
        visible: pick.kh && !pick.tile
        width: 3
        height: parent.height
        color: "#F2C75C"
        z: 1
    }
}
