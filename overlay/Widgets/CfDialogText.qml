import QtQuick
import qs.Common

// A line of a Coreflame dialog in the v3 mockup's type: "title" (the question), "message" (what it
// is about) or "label" (a field's name above it). The Flame Reaver writes everything lower case.
Text {
    id: line

    property string role: "message"

    readonly property bool kh: Form.khaslana
    readonly property bool rv: Form.reaver
    readonly property bool title: role === "title"
    readonly property bool label: role === "label"

    textFormat: Text.PlainText
    wrapMode: Text.Wrap
    font.family: title ? (kh ? "Cinzel" : (rv ? "Chakra Petch" : "Marcellus")) : (label && kh ? "Cinzel" : (!rv && !kh && !label ? "Cormorant Garamond" : "Chakra Petch"))
    font.pixelSize: title ? (rv || kh ? 18 : 22) : (label ? (rv ? 13 : 11) : (rv || kh ? 15 : 19))
    font.italic: !title && !label && !kh && !rv
    font.weight: (title && kh) ? Font.Bold : ((label && !rv) ? Font.DemiBold : Font.Normal)
    font.letterSpacing: title && kh ? 2.5 : (label && !rv ? (kh ? 2.2 : 1.76) : 0)
    font.capitalization: rv ? Font.AllLowercase : ((kh && title) || (label && !rv) ? Font.AllUppercase : Font.MixedCase)
    color: title ? (kh ? "#F5D27A" : (rv ? "#E9E7F2" : "#334786")) : (label ? (kh ? "#E0B04A" : (rv ? "#6E6A84" : "#8A6418")) : (kh ? "#C9B89E" : (rv ? "#A8A4BC" : "#4A5484")))
}
