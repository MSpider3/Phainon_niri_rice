import QtQuick
import qs.Common

// The v3 mockup's ink for menus, pickers and the file browser, per form: text, icons, rules,
// headers and danger. Instantiate one where needed (`CfInk { id: ink }`); it holds no state.
QtObject {
    readonly property bool kh: Form.khaslana
    readonly property bool rv: Form.reaver
    readonly property bool ph: !kh && !rv

    readonly property string font: ph ? Form.numerals : "Chakra Petch"
    readonly property color text: ph ? "#1E2752" : (kh ? "#F3E6CC" : "#E9E7F2")
    readonly property color selText: kh ? "#F5D27A" : text
    readonly property color muted: ph ? "#4A5484" : (kh ? "#C9B89E" : "#A8A4BC")
    readonly property color icon: ph ? "#A87A22" : (kh ? "#E0B04A" : "#6E6A84")
    readonly property color selIcon: rv ? "#B9A8FF" : icon
    readonly property color accent: ph ? "#334786" : (kh ? "#F5D27A" : "#B9A8FF")
    readonly property color rule: ph ? "#DCCDA6" : (kh ? "#5A3A1E" : "#2C2840")
    readonly property color head: ph ? "#8A6418" : (kh ? "#E0B04A" : "#6E6A84")
    readonly property string headFont: kh ? "Cinzel" : "Chakra Petch"
    readonly property int headSize: rv ? 13 : 11
    readonly property real headSpacing: rv ? 0 : 1.8
    readonly property color danger: ph ? "#A3343A" : (kh ? "#E2434E" : "#F07A85")

    // The Flame Reaver writes everything in lower case
    function tx(s) {
        return rv ? String(s).toLowerCase() : s;
    }

    // Section headers: small caps for Phainon and Khaslana, "// name" for the Flame Reaver
    function header(s) {
        return rv ? "// " + String(s).toLowerCase() : String(s).toUpperCase();
    }
}
