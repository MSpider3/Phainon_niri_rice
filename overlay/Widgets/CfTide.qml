import QtQuick
import QtQuick.Shapes

// The Black Tide (Khaslana): black liquid with drips along one edge, a red copy displaced behind it,
// a red block tide, and the flickering cubes held still. Seeded (Park-Miller, as in the v3 mockup),
// so every open draws the same picture. Computed once; no timers, no layer.
Item {
    id: root

    property string edge: "top"     // the edge the tide hangs from ("top") or rises from ("bottom")
    property int seed: 7
    property real base: 0.3         // share of the liquid band that is solid
    property real liquid: height    // height of the liquid band in px
    property int blocks: 0          // red block tide along the edge
    property real blockMax: 40      // tallest block in px
    property int cubes: 0
    property real cubeDepth: height // how far from the edge the cubes reach, in px

    readonly property bool rising: edge === "bottom"

    function rng(s) {
        let v = s % 2147483646 + 1;
        return () => (v = v * 16807 % 2147483647) / 2147483647;
    }

    // The liquid edge on a 1000 x 100 grid, hanging from y = 0 (flipped for "bottom").
    readonly property string ooze: {
        const r = rng(seed), b = 100 * base;
        let d = `M0 0L0 ${b}`, x = 0;
        while (x < 1000) {
            const nx = Math.min(1000, x + 16 + r() * 40), y = b + r() * 10;
            if (r() < 0.45 && nx - x > 22) {
                const cx = (x + nx) / 2, w = 2.5 + r() * 6, L = (100 - y) * (0.2 + r() * 0.8);
                d += `Q${x + 3} ${y + 4} ${cx - w} ${y}C${cx - w * 0.5} ${y + L * 0.6} ${cx - w * 1.4} ${y + L} ${cx} ${y + L}C${cx + w * 1.4} ${y + L} ${cx + w * 0.5} ${y + L * 0.6} ${cx + w} ${y}`;
            }
            d += `Q${(x + nx) / 2} ${y + 3 + r() * 6} ${nx} ${b + r() * 10}`;
            x = nx;
        }
        return d + "L1000 0Z";
    }

    // Block heights: the mockup's fixed sequence, so every render matches
    readonly property var blockHeights: {
        const out = [];
        let x = 7 + seed * 13;
        for (let i = 0; i < blocks; i++) {
            x = (x * 73 + 19) % 101;
            out.push(6 + x % blockMax);
        }
        return out;
    }

    // [u, depth, size px, colour, opacity, echo] with u and depth as shares of width / cubeDepth
    readonly property var cubeList: {
        const r = rng(seed * 31 + 3), ink = ["#C2252F", "#C2252F", "#3A0A12", "#E0B04A", "#6B6468", "#8E1424"], out = [];
        for (let i = 0; i < cubes; i++) {
            const u = r(), d = Math.pow(r(), 1.7), z = 5 + Math.floor(r() * 20);
            out.push([u, d, z, ink[Math.floor(r() * ink.length)], 0.55 + r() * 0.45, r() < 0.35]);
        }
        return out;
    }

    // Liquid: red echo 6/3 px behind, then the black body. Fill only, so scaling the grid is safe.
    Repeater {
        model: [["#8E1424", 0.9, 6, 3], ["#030102", 1, 0, 0]]

        Shape {
            id: band
            required property var modelData
            x: modelData[2]
            // "bottom" mirrors the grid upwards from the bottom edge (the mockup's scaleY(-1))
            y: root.rising ? root.height - modelData[3] : modelData[3]
            width: 1000
            height: 100
            opacity: modelData[1]
            transform: Scale {
                xScale: root.width / 1000
                yScale: (root.rising ? -1 : 1) * root.liquid / 100
            }

            ShapePath {
                strokeWidth: -1
                fillColor: band.modelData[0]
                PathSvg {
                    path: root.ooze
                }
            }
        }
    }

    // The red block tide along the edge
    Row {
        visible: root.blocks > 0
        width: parent.width
        y: root.rising ? parent.height - root.blockMax - 6 : 0
        spacing: 3

        Repeater {
            model: root.blockHeights

            Rectangle {
                required property int index
                required property var modelData
                width: (root.width - 3 * (root.blocks - 1)) / root.blocks
                height: modelData
                y: root.rising ? root.blockMax + 6 - height : 0
                color: (index + 1) % 11 === 0 ? "#E0B04A" : (index + 1) % 7 === 0 ? "#3A0A12" : (index + 1) % 3 === 0 ? "#C2252F" : "#8E1424"
            }
        }
    }

    // The cubes, some with a red displaced echo
    Repeater {
        model: root.cubeList

        Item {
            required property var modelData
            x: Math.round(modelData[0] * root.width)
            y: Math.round(root.rising ? root.height - modelData[1] * root.cubeDepth - modelData[2] : modelData[1] * root.cubeDepth)
            width: modelData[2]
            height: modelData[2]
            opacity: modelData[4]

            Rectangle {
                visible: parent.modelData[5]
                x: 4
                width: parent.width
                height: parent.height
                color: Qt.rgba(194 / 255, 37 / 255, 47 / 255, 0.75)
            }
            Rectangle {
                anchors.fill: parent
                color: parent.modelData[3]
            }
        }
    }
}
