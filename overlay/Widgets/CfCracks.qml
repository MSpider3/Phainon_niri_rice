import QtQuick
import QtQuick.Shapes

// Static cracks stretched over this item. Points are scaled to the item's size; widths stay in
// pixels at any size. Drawn once: no timers, no layer.
//   kind "gold"   Khaslana's golden blood, as on his body in the wallpaper: filled slivers that swell
//                 in the middle and taper to points, with jagged edges, chained along each crack
//                 (pattern "veins")
//   kind "violet" the Flame Reaver's fractures from a point of impact (pattern "impact")
Item {
    id: root

    property string kind: "gold"
    property string pattern: kind === "gold" ? "veins" : "impact"
    property real trunk: 1     // width multiplier for trunks
    property real branch: 1    // width multiplier for branches

    // On a 1000 x 1000 grid, from the v3 mockup's #veins and #crk symbols
    readonly property var trunks: pattern === "veins" ? ["M0 310 70 296 130 330 210 312 262 350 330 322 410 340 470 300 540 318 610 290 690 334 760 318 830 350 900 326 1000 340", "M262 350 300 420 276 500 330 560 310 640 372 700 350 790 400 860 380 1000"] : ["M500 500 380 420 300 430 180 330 60 300 0 240M300 430 280 520 200 560", "M500 500 560 380 540 300 620 160 600 60 660 0M620 160 720 140 800 60", "M500 500 640 520 760 470 880 520 1000 480M760 470 800 380", "M500 500 470 640 520 760 460 880 490 1000M520 760 620 800", "M500 500 380 590 250 600 120 720 0 760M250 600 230 700", "M500 500 610 640 700 700 760 850 900 1000", "M462 470 535 455 552 522 488 548 450 510z"]
    readonly property var branches: pattern === "veins" ? ["M470 300 490 220 460 150 500 80 480 0", "M330 560 420 590 470 650 560 640 620 700", "M830 350 850 250 920 200 1000 210"] : []

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

    // [colour, trunk width, branch width] from the bottom layer up (violet only)
    readonly property var layers: [[Qt.rgba(5 / 255, 4 / 255, 10 / 255, 0.85), 5, 5], ["#D6CCFF", 1.6, 1.6]]

    // One sliver along a polyline: half-width swells as sin(pi t) from a point at each end; every
    // vertex pushes one side out and the other in, by a fixed pattern, so the edges are jagged.
    function sliver(pts, half, seed) {
        const p = [pts[0]];
        for (let i = 1; i < pts.length; i++)
            p.push([(pts[i - 1][0] + pts[i][0]) / 2, (pts[i - 1][1] + pts[i][1]) / 2], pts[i]);
        const s = [0];
        for (let i = 1; i < p.length; i++)
            s.push(s[i - 1] + Math.hypot(p[i][0] - p[i - 1][0], p[i][1] - p[i - 1][1]));
        const len = s[s.length - 1] || 1, jag = [0.4, -0.3, 0.15, -0.1], left = [], right = [];
        for (let i = 1; i < p.length - 1; i++) {
            const dx = p[i + 1][0] - p[i - 1][0], dy = p[i + 1][1] - p[i - 1][1], d = Math.hypot(dx, dy) || 1;
            const w = half * Math.pow(Math.sin(Math.PI * s[i] / len), 0.7), j = jag[(i + seed) % 4];
            left.push((p[i][0] - dy / d * w * (1 + j)).toFixed(1) + " " + (p[i][1] + dx / d * w * (1 + j)).toFixed(1));
            right.unshift((p[i][0] + dy / d * w * (1 - j)).toFixed(1) + " " + (p[i][1] - dx / d * w * (1 - j)).toFixed(1));
        }
        const end = q => q[0].toFixed(1) + " " + q[1].toFixed(1);
        return "M" + [end(p[0])].concat(left, [end(p[p.length - 1])], right).join(" L") + " Z";
    }

    // Each polyline cut into slivers of `chunk` segments (0: the whole line is one sliver), each a
    // little wider or narrower than `half`.
    function slivers(list, half, chunk) {
        const sx = width / 1000, sy = height / 1000, out = [];
        list.forEach((d, k) => {
            const n = d.match(/-?\d+(\.\d+)?/g).map(Number), pts = [];
            for (let i = 0; i + 1 < n.length; i += 2)
                pts.push([n[i] * sx, n[i + 1] * sy]);
            const step = chunk || pts.length - 1;
            for (let a = 0; a < pts.length - 1; a += step)
                out.push(sliver(pts.slice(a, a + step + 1), half * (0.7 + 0.15 * ((a * 7 + k * 3) % 5)), a + k));
        });
        return out.join(" ");
    }

    // [colour, share of the full half-width] from the bottom layer up: a dark ember rim, the gold, a light core
    readonly property var goldLayers: [["#6E2A0C", 1], ["#E2A63A", 0.72], ["#FFF0B5", 0.26]]

    Repeater {
        model: root.kind === "gold" && root.width > 0 && root.height > 0 ? root.goldLayers : []

        Shape {
            id: goldLayer
            required property var modelData
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: goldLayer.modelData[0]
                fillRule: ShapePath.WindingFill
                strokeColor: "transparent"
                PathSvg {
                    path: root.slivers(root.trunks, 7 * root.trunk * goldLayer.modelData[1], 2) + " " + root.slivers(root.branches, 4 * root.branch * goldLayer.modelData[1], 0)
                }
            }
        }
    }

    Repeater {
        model: root.kind === "gold" ? [] : root.layers

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
