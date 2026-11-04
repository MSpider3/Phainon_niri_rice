pragma Singleton
import QtQuick

// Test stub: the form switch and the fonts the widgets read
QtObject {
    property string form: "phainon"
    readonly property bool active: true
    readonly property bool phainon: form === "phainon"
    readonly property bool khaslana: form === "khaslana"
    readonly property bool reaver: form === "reaver"
    readonly property string bodyFont: "Sans"
    function display(fallback) {
        return fallback;
    }
}
