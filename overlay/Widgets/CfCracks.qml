import QtQuick
import QtQuick.Shapes

// Static cracks stretched over this item. Points are scaled to the item's size; strokes keep their
// pixel width at any size. Drawn once: no timers, no layer.
//   kind "gold"   Khaslana's golden blood: a dark rim, gold, and a light core (pattern "veins")
//   kind "violet" the Flame Reaver's fractures from a point of impact (pattern "impact")
Item {
    id: root

    property string kind: "gold"
    property string pattern: kind === "gold" ? "veins" : "impact"
    property real trunk: 1     // width multiplier for trunks
    property real branch: 1    // width multiplier for branches

    // On a 1000 x 1000 grid, from the v3 mockup's #veins and #crk symbols
    readonly property var trunks: pattern === "veins" ? ["M0 310 70 296 130 330 210 312 262 350 330 322 410 340 470 300 540 318 610 290 690 334 760 318 830 350 900 326 1000 340", "M262 350 300 420 276 500 330 560 310 640 372 700 350 790 400 860 380 1000", "M690 334 720 420 700 500 760 580 740 660 800 720 860 700 920 760 1000 740"] : ["M500 500 380 420 300 430 180 330 60 300 0 240M300 430 280 520 200 560", "M500 500 560 380 540 300 620 160 600 60 660 0M620 160 720 140 800 60", "M500 500 640 520 760 470 880 520 1000 480M760 470 800 380", "M500 500 470 640 520 760 460 880 490 1000M520 760 620 800", "M500 500 380 590 250 600 120 720 0 760M250 600 230 700", "M500 500 610 640 700 700 760 850 900 1000", "M462 470 535 455 552 522 488 548 450 510z"]
    readonly property var branches: pattern === "veins" ? ["M470 300 490 220 460 150 500 80 480 0", "M330 560 420 590 470 650 560 640 620 700", "M760 580 840 560 900 600", "M130 330 120 420 60 480 0 470", "M372 700 300 760 220 750 150 820", "M830 350 850 250 920 200 1000 210", "M560 640 580 760 540 860 560 1000"] : []

    // Rescale "M x y x y ... z" polylines from the 1000 grid to this item's size.
    function fit(list) {
        const sx = width / 1000, sy = height / 1000;
        return list.map(d => {
            let i = 0;
            return d.replace(/-?\d+(\.\d+)?/g, n => ((i++ % 2 === 0) ? n * sx : n * sy).toFixed(1));
        }).join(" ");
    }
    readonly property string trunkPath: width > 0 && height > 0 ? fit(trunks) : ""
    readonly property string branchPath: width > 0 && height > 0 && branches.length ? fit(branches) : ""

    // [colour, trunk width, branch width] from the bottom layer up
    readonly property var layers: kind === "gold" ? [["#1A0306", 24, 13], ["#E2A63A", 13, 7], ["#FFF0B5", 4, 2]] : [[Qt.rgba(5 / 255, 4 / 255, 10 / 255, 0.85), 5, 5], ["#D6CCFF", 1.6, 1.6]]

    Repeater {
        model: root.layers

        Shape {
            id: crackLayer
            required property var modelData
            anchors.fill: parent

            ShapePath {
                strokeColor: crackLayer.modelData[0]
                strokeWidth: crackLayer.modelData[1] * root.trunk
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg {
                    path: root.trunkPath
                }
            }
            ShapePath {
                strokeColor: crackLayer.modelData[0]
                strokeWidth: root.branchPath ? crackLayer.modelData[2] * root.branch : 0
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg {
                    path: root.branchPath
                }
            }
        }
    }
}
