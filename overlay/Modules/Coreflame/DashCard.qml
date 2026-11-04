import QtQuick
import QtQuick.Shapes
import qs.Common
import qs.Widgets

// A dashboard card in the current form's shape, with a caption in its corner naming which Titan's
// domain the card is and what it shows (the v3 mockup's caption styles).
//   Phainon: a parchment card with a fluted top.  Khaslana: a plain plate (`bare` when the
//   obsidian mosaic draws the blocks itself).  Flame Reaver: a shard when `poly` is given.
Item {
    id: card

    property bool clickable: false
    property string label: ""
    // Kept for callers; the v3 captions no longer number the plates.
    property string numeral: ""
    // The Titan's sigil for this card's domain
    property string glyph: ""
    property bool highlighted: false
    // No background: something behind the card draws it (Khaslana's mosaic)
    property bool bare: false
    // Phainon: the fluted band along the top (the overview's columns); views use plain paper cards
    property bool flute: true
    // Flame Reaver shard: four corners as [x, y] fractions of the card, clockwise from top-left
    property var poly: null
    property color capColor: Form.khaslana ? "#E0B04A" : (Form.reaver ? "#B9A8FF" : (Theme.isLightMode ? "#8A6418" : Theme.primary))
    property bool capCentered: false
    default property alias content: inner.data
    signal clicked

    readonly property bool shard: Form.reaver && !!poly
    readonly property bool fluted: Form.phainon && !bare

    function corners(inset) {
        const w = width, h = height, cx = w / 2, cy = h / 2;
        return (poly ?? []).map(p => {
            const x = p[0] * w, y = p[1] * h;
            return Qt.point(x + (cx - x) * 2 * inset / w, y + (cy - y) * 2 * inset / h);
        });
    }

    // Khaslana: an obsidian block; Flame Reaver without a shard: dark glass with a rule
    Rectangle {
        visible: !card.bare && !card.shard && !card.fluted
        anchors.fill: parent
        color: Form.khaslana ? ((cardMouse.containsMouse && card.clickable) || card.highlighted ? "#160D10" : "#0B080B") : ((cardMouse.containsMouse && card.clickable) || card.highlighted ? "#F21C1828" : "#F20D0B14")
        border.width: 1
        border.color: card.highlighted ? (Form.khaslana ? "#E0B04A" : "#8F7BE0") : (Form.khaslana ? "#3A1A1E" : "#2C2840")
    }

    // Phainon: parchment with a fluted band along the top, like the head of a column
    Rectangle {
        visible: card.fluted
        anchors.fill: parent
        radius: 12
        color: Theme.isLightMode ? (cardMouse.containsMouse && card.clickable ? "#FFFDF7" : "#FBF9F3") : (cardMouse.containsMouse && card.clickable ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)
        border.width: 1
        border.color: card.highlighted ? Theme.primary : (Theme.isLightMode ? "#DCCDA6" : Theme.withAlpha(Theme.outline, 0.45))
        clip: true

        Shape {
            visible: card.flute
            width: parent.width
            height: 8
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: -1
                fillColor: Theme.isLightMode ? "#EFE6CC" : Theme.withAlpha(Theme.outline, 0.25)
                PathSvg {
                    path: {
                        let d = "";
                        for (let x = 0; x < card.width; x += 10)
                            d += `M${x} 0h7v8h-7z`;
                        return d;
                    }
                }
            }
        }

        Rectangle {
            visible: card.flute
            y: 8
            width: parent.width
            height: 1
            color: Theme.isLightMode ? "#DCCDA6" : Theme.withAlpha(Theme.outline, 0.45)
        }
    }

    // Flame Reaver: a shard of glass, a violet rim around dark glass
    Shape {
        visible: card.shard
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            fillGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: card.width
                y2: card.height
                GradientStop {
                    position: 0
                    color: "#B9A8FF"
                }
                GradientStop {
                    position: 0.5
                    color: "#5C5478"
                }
                GradientStop {
                    position: 1
                    color: "#8F7BE0"
                }
            }
            PathPolyline {
                path: card.shard ? card.corners(0).concat([card.corners(0)[0]]) : []
            }
        }

        ShapePath {
            strokeWidth: -1
            fillColor: cardMouse.containsMouse && card.clickable ? "#F2181424" : "#F20D0B14"
            PathPolyline {
                path: card.shard ? card.corners(2).concat([card.corners(2)[0]]) : []
            }
        }
    }

    MouseArea {
        id: cardMouse
        anchors.fill: parent
        hoverEnabled: card.clickable
        cursorShape: card.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (card.clickable)
            card.clicked()
    }

    Row {
        id: caption
        visible: card.label !== ""
        x: card.capCentered ? Math.round((card.width - width) / 2) : (card.shard ? 26 : 15)
        y: card.shard ? 18 : (card.fluted ? (card.flute ? 18 : 12) : 9)
        spacing: 8

        CfGlyph {
            visible: Form.reaver && card.glyph !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: card.glyph
            size: 15
            strokeWidth: 1.6
            color: card.capColor
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, card.width - 40)
            elide: Text.ElideRight
            text: Form.reaver && !card.shard ? card.label.toLowerCase() : card.label.toUpperCase()
            font.family: Form.khaslana ? "Cinzel" : "Chakra Petch"
            font.pixelSize: Form.phainon ? 11 : 12
            font.weight: Font.DemiBold
            font.letterSpacing: Form.khaslana ? 2.6 : (Form.reaver ? 1.7 : 1.8)
            color: card.capColor
            style: Form.khaslana ? Text.Outline : Text.Normal
            styleColor: "#0B080B"
        }
    }

    Item {
        id: inner
        anchors.fill: parent
        anchors.margins: card.shard ? 26 : 15
        anchors.topMargin: card.label !== "" ? caption.y + 16 : (card.fluted && card.flute ? 18 : 14)
        anchors.bottomMargin: card.shard ? 18 : 12
    }
}
