import QtQuick
import qs.Common
import qs.Widgets

// A dashboard card in the current form's shape, with an optional small-caps label in its corner:
// which Titan's domain the card is and what it shows. The Flame Reaver marks it with his mask.
Item {
    id: card

    property bool clickable: false
    property string label: ""
    // Khaslana indexes every plate with a Roman numeral.
    property string numeral: ""
    // The Titan's sigil for this card's domain
    property string glyph: ""
    property bool highlighted: false
    default property alias content: inner.data
    signal clicked

    CfSurface {
        anchors.fill: parent
        color: (cardMouse.containsMouse && card.clickable) || card.highlighted ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
        edgeColor: card.highlighted ? Theme.primary : Theme.withAlpha(Theme.outline, Form.khaslana ? 0.9 : 0.45)
        edgeWidth: Form.reaver ? 0 : 1
        radius: 16
    }

    MouseArea {
        id: cardMouse
        anchors.fill: parent
        hoverEnabled: card.clickable
        cursorShape: card.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (card.clickable)
            card.clicked()
    }

    CfGlyph {
        visible: (Form.reaver || card.glyph !== "") && card.label !== ""
        x: 13
        y: 7
        name: Form.reaver ? "mask" : card.glyph
        size: 15
        strokeWidth: Form.reaver ? 1.6 : 1.9
        color: Form.reaver ? Theme.withAlpha(Theme.live, 0.9) : Theme.withAlpha(Theme.surfaceText, 0.6)
    }

    Text {
        visible: card.label !== ""
        x: Form.reaver || card.glyph !== "" ? 34 : 14
        y: 9
        width: card.width - x - 12
        elide: Text.ElideRight
        text: Form.reaver ? card.label.toLowerCase() : ((Form.khaslana && card.numeral !== "" ? card.numeral + "  ·  " : "") + card.label.toUpperCase())
        font.family: Form.reaver ? Theme.monoFontFamily : Form.display(Theme.fontFamily)
        font.pixelSize: 10
        // Long headings on narrow cards shrink a little before they elide.
        fontSizeMode: Text.HorizontalFit
        minimumPixelSize: 8
        font.weight: Font.Medium
        font.letterSpacing: Form.reaver ? 0.5 : 1.4
        color: Theme.withAlpha(Theme.surfaceText, 0.5)
    }

    Item {
        id: inner
        anchors.fill: parent
        anchors.margins: 14
        anchors.topMargin: card.label !== "" ? 24 : 14
    }
}
