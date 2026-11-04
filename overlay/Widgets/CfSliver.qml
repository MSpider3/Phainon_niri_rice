import QtQuick
import QtQuick.Shapes

// A short run of Khaslana's golden blood breaking off a window's edge: the v3 mockup's #xx-sliv
// (filled slivers, ember rim, gold, light core) on its 400 x 200 grid, stretched to this item.
// Static: drawn once. `flip` mirrors it for a right-to-left run.
Item {
    id: root

    property bool flip: false

    readonly property var layers: [
        ["#6E2A0C", "M0.0 120.0 L31.3 117.0 L59.2 114.4 L82.3 121.6 L110.0 128.0 L88.3 109.1 L60.6 96.3 L27.5 102.8 Z M110.0 128.0 L145.3 125.3 L170.9 123.5 L191.2 119.9 L220.0 124.0 L202.1 97.2 L169.6 89.9 L133.5 100.2 Z M220.0 124.0 L253.5 117.6 L281.7 113.1 L307.3 114.0 L340.0 112.0 L313.3 91.8 L278.7 83.4 L243.4 95.9 Z M340.0 112.0 L373.7 113.1 L400.0 92.0 L365.5 88.4 Z M170.0 100.0 L180.2 80.9 L191.4 60.5 L185.2 43.6 L182.0 30.8 L186.8 16.1 L194.0 0.0 L181.7 13.0 L173.4 29.7 L175.9 46.7 L182.0 59.7 L174.0 78.4 Z M220.0 124.0 L230.6 145.7 L246.7 165.7 L272.8 176.0 L297.8 174.4 L311.2 188.8 L330.0 200.0 L317.8 182.2 L304.1 161.9 L275.9 160.3 L254.0 153.1 L238.2 139.3 Z"],
        ["#E2A63A", "M0.0 120.0 L31.0 115.6 L59.5 111.5 L83.1 120.0 L110.0 128.0 L87.4 111.1 L60.4 98.5 L28.2 105.3 Z M110.0 128.0 L143.8 122.1 L170.6 116.9 L192.3 117.7 L220.0 124.0 L200.1 101.4 L169.7 92.8 L135.4 104.0 Z M220.0 124.0 L252.5 115.4 L281.2 108.3 L308.1 111.2 L340.0 112.0 L312.4 95.2 L279.1 86.9 L245.3 99.9 Z M340.0 112.0 L372.7 110.0 L400.0 92.0 L366.7 92.2 Z M170.0 100.0 L179.6 80.6 L189.9 60.3 L184.0 44.0 L180.3 30.6 L186.3 15.8 L194.0 0.0 L182.6 13.6 L174.1 29.8 L177.3 46.2 L183.1 59.8 L175.1 78.8 Z M220.0 124.0 L231.8 144.6 L247.6 164.1 L273.4 172.9 L298.4 173.1 L312.3 187.7 L330.0 200.0 L317.0 183.0 L302.9 164.2 L275.7 161.6 L252.9 155.0 L237.3 140.1 Z"],
        ["#FFF0B5", "M0.0 120.0 L30.3 113.3 L59.8 106.7 L84.3 117.5 L110.0 128.0 L85.9 114.2 L60.1 102.0 L29.4 109.6 Z M110.0 128.0 L141.4 116.9 L170.2 106.1 L194.0 114.1 L220.0 124.0 L196.8 108.2 L169.9 97.4 L138.3 110.4 Z M220.0 124.0 L250.9 112.0 L280.4 100.4 L309.3 106.6 L340.0 112.0 L310.8 100.8 L279.7 92.7 L248.3 106.3 Z M340.0 112.0 L371.0 104.9 L400.0 92.0 L368.8 98.5 Z M170.0 100.0 L178.6 80.2 L187.4 60.1 L182.1 44.6 L177.6 30.2 L185.5 15.3 L194.0 0.0 L184.2 14.5 L175.3 29.9 L179.7 45.4 L185.0 59.9 L177.0 79.6 Z M220.0 124.0 L233.9 142.9 L249.2 161.5 L274.4 167.9 L299.4 171.1 L314.0 186.0 L330.0 200.0 L315.7 184.3 L301.1 167.9 L275.2 163.8 L251.0 158.2 L235.8 141.3 Z"]
    ]

    Repeater {
        model: root.layers

        Shape {
            id: layer
            required property var modelData
            x: root.flip ? root.width : 0
            width: 400
            height: 200
            preferredRendererType: Shape.CurveRenderer
            transform: Scale {
                xScale: (root.flip ? -1 : 1) * root.width / 400
                yScale: root.height / 200
            }

            ShapePath {
                fillColor: layer.modelData[0]
                strokeColor: "transparent"
                PathSvg {
                    path: layer.modelData[1]
                }
            }
        }
    }
}
