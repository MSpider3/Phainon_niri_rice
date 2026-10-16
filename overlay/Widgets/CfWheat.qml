import QtQuick
import QtQuick.Shapes
import qs.Common

// Aedes Elysiae, his hometown of wheat fields: a faint line of wheat stalks. One static path,
// drawn once; only the width changes it.
Item {
    id: root

    property color color: Theme.withAlpha(Theme.secondary, 0.35)
    property real spacing: 14

    implicitHeight: 30

    // Stalks of slightly different heights and leans, each with a head of four grain pairs.
    readonly property string path: {
        const parts = [];
        const n = Math.max(1, Math.floor(width / spacing));
        for (let i = 0; i < n; i++) {
            const x = i * spacing + spacing / 2;
            const tall = height * (0.62 + ((i * 37) % 10) / 30);
            const lean = (((i * 53) % 7) - 3) * 0.9;
            const top = height - tall;
            parts.push(`M ${x} ${height} Q ${x + lean * 0.4} ${height - tall / 2} ${x + lean} ${top}`);
            for (let g = 0; g < 4; g++) {
                const gy = top + 2 + g * 3.2;
                const gx = x + lean * (1 - (gy - top) / tall);
                parts.push(`M ${gx} ${gy} l -2.6 -2.2 M ${gx} ${gy} l 2.6 -2.2`);
            }
        }
        return parts.join(" ");
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.color
            strokeWidth: 1.2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathSvg {
                path: root.path
            }
        }
    }
}
