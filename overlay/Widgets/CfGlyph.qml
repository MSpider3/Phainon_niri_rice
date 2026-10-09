import QtQuick
import QtQuick.Shapes

// Line-drawn sigils for the twelve Titans of Amphoreus and the thirteenth, used in place of generic
// icons on panel headers and tiles. Each glyph is stroked SVG path data on a 24x24 grid, scaled to
// `size`; `strokeWidth` is in grid units, so it scales with the glyph. An unknown name draws nothing.
Item {
    id: root

    property string name: ""
    property real size: 20
    property color color: "white"
    property real strokeWidth: 1.6

    readonly property var glyphs: ({
        // Janus, Gate of Infinity: a gate within a gate, barbed at the springing
        "passage": "M4 21.5 V10.5 Q4 5 12 2.5 Q20 5 20 10.5 V21.5 M8.5 21.5 V13 Q8.5 9.5 12 8 Q15.5 9.5 15.5 13 V21.5 M4 10.5 L2 8.5 M20 10.5 L22 8.5",
        // Talanton, Scale of Justice: a post, a drooping beam and two hanging pans
        "law": "M12 2.5 V21 M7.5 21 H16.5 M4.5 7.5 L12 5.5 L19.5 7.5 M4.5 7.5 L2 14.5 H7 Z M2 14.5 Q4.5 18.5 7 14.5 M19.5 7.5 L17 14.5 H22 Z M17 14.5 Q19.5 18.5 22 14.5",
        // Oronyx, Veil of Evernight: an open-sided square crossed like an hourglass
        "time": "M3.5 3.5 H20.5 M3.5 20.5 H20.5 M3.5 3.5 V9 M3.5 20.5 V15 M20.5 3.5 V9 M20.5 20.5 V15 M7 3.5 L17 20.5 M17 3.5 L7 20.5",
        // Georios, Pillar of Stone: a braced pillar standing under an arc
        "earth": "M2 14 L3 11.5 A9 9 0 0 1 21 11.5 L22 14 M7 8.5 H17 M6.5 21.5 H17.5 M9 8.5 V21.5 M15 8.5 V21.5 M9 9 L15 15 L9 21",
        // Phagousa, Chalice of Plenty: a cup with a wave in it, on a flared foot
        "ocean": "M3.5 4 H20.5 M5.5 4 C5.5 10 8 13 12 13 C16 13 18.5 10 18.5 4 M8 8 Q10 6.5 12 8 T16 8 M12 13 V17 M7 21 L12 17 L17 21 Z",
        // Aquila, Eye of Twilight: an almond eye with a small pupil, spiked above and below
        "sky": "M2 12 Q12 2 22 12 Q12 22 2 12 Z M9.6 12 a2.4 2.4 0 1 0 4.8 0 a2.4 2.4 0 1 0 -4.8 0 M12 2 V4.5 M12 19.5 V22",
        // Kephale, Throne of Worlds: a ring of twelve thorns around a four-point diamond
        "worldbearing": "M5.5 12 a6.5 6.5 0 1 0 13 0 a6.5 6.5 0 1 0 -13 0 M12 5.5 L12 1.8 M15.25 6.37 L16.65 3.95 M17.63 8.75 L20.05 7.35 M18.5 12 L22.2 12 M17.63 15.25 L20.05 16.65 M15.25 17.63 L16.65 20.05 M12 18.5 L12 22.2 M8.75 17.63 L7.35 20.05 M6.37 15.25 L3.95 16.65 M5.5 12 L1.8 12 M6.37 8.75 L3.95 7.35 M8.75 6.37 L7.35 3.95 M12 8.5 L14.6 12 L12 15.5 L9.4 12 Z",
        // Cerces, Bough of Rift: a stem forking into three pairs of rising branches
        "reason": "M12 22 V2 M12 18.5 L4.5 13 V10 M12 18.5 L19.5 13 V10 M12 12.5 L7 8 M12 12.5 L17 8 M12 7 L9.5 4.5 M12 7 L14.5 4.5",
        // Mnestia, Chrysalis of Gold: two rings linked over and under, a thread end above and below
        "romance": "M10.4 16.6 A5.5 5.5 0 1 1 13.2 14.3 M13.6 7.4 A5.5 5.5 0 1 1 10.8 9.7 M12 2 V4.5 M12 19.5 V22",
        // Nikador, Lance of Fury: a spear with two barbed side prongs and a guard
        "strife": "M12 2 V22 M9 7 L12 2 L15 7 M5 4 Q4.5 13 12 14 Q19.5 13 19 4 M3 6.5 L5 4 M21 6.5 L19 4 M8.5 18 H15.5",
        // Thanatos, Hand of Shadow: three hooked talons raking down from the back of the hand
        "death": "M3.5 6.5 Q12 2 20.5 5.5 M6.5 5 C8.5 10 8.5 16 3.5 20.5 M12.5 4 C15 10 14.5 17 8.5 22 M18.5 5 C20.5 10 20.5 16 15.5 20.5",
        // Zagreus, Coin of Whimsy: a slanted S-curl with a small coin in each curl
        "trickery": "M4.5 12 A5.303 5.303 0 1 1 12 12 A5.303 5.303 0 1 0 19.5 12 M6.65 8.25 a1.6 1.6 0 1 0 3.2 0 a1.6 1.6 0 1 0 -3.2 0 M14.15 15.75 a1.6 1.6 0 1 0 3.2 0 a1.6 1.6 0 1 0 -3.2 0",
        // Cyrene, the thirteenth: a figure-eight with six thorns
        "genesis": "M12 12 C5.5 8.5 7 4.5 12 4.5 C17 4.5 18.5 8.5 12 12 C5.5 15.5 7 19.5 12 19.5 C17 19.5 18.5 15.5 12 12 Z M12 4.5 V2 M12 19.5 V22 M7.7 7 L4.5 5.2 M16.3 7 L19.5 5.2 M7.7 17 L4.5 18.8 M16.3 17 L19.5 18.8"
    })
    readonly property string pathData: glyphs.hasOwnProperty(name) ? glyphs[name] : ""

    implicitWidth: size
    implicitHeight: size

    Shape {
        width: 24
        height: 24
        scale: root.size / 24
        transformOrigin: Item.TopLeft
        visible: root.pathData !== ""
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.color
            strokeWidth: root.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathSvg {
                path: root.pathData
            }
        }
    }
}
