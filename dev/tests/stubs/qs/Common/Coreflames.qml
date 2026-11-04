pragma Singleton
import QtQuick

// Test stub: two Titans, the second earned
QtObject {
    readonly property var order: ["janus", "kephale"]
    readonly property var titans: ({
            "janus": ["Janus", "Walk all three forms"],
            "kephale": ["Kephale", "Open the dashboard"]
        })
    readonly property int count: 1
    function has(name) {
        return name === "kephale";
    }
}
