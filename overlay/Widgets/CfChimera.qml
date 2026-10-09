import QtQuick
import Quickshell.Io
import qs.Common

// The Phainon chimera, moving with the CPU the way the cat widget does: asleep while the machine
// idles, then walking, running and sprinting as the load climbs. Same thresholds and the same
// speed curve as the cat. It rests on Power Saver.
Item {
    id: root

    property real size: 30
    property real load: 0
    property int idleBelow: 15
    property var last: null

    readonly property bool asleep: load < idleBelow || Motion.saver
    readonly property string gait: asleep ? "sleeping" : (load < 40 ? "walking" : (load < 70 ? "running" : "sprinting"))
    // stand, step, stand, other step
    readonly property var cycle: [1, 2, 1, 3]
    property int step: 0

    implicitWidth: size
    implicitHeight: size

    FileView {
        id: stat
        path: "/proc/stat"
        blockLoading: true
        printErrors: false
    }

    function sample() {
        stat.reload();
        const parts = (stat.text().split("\n")[0] ?? "").trim().split(/\s+/);
        if (parts.length < 5 || parts[0] !== "cpu")
            return;
        const n = parts.slice(1, 9).map(x => parseInt(x) || 0);
        const idle = n[3] + n[4];
        const total = n.reduce((a, b) => a + b, 0);
        if (last && total > last.total)
            load = Math.round((total - last.total - (idle - last.idle)) / (total - last.total) * 100);
        last = {
            "idle": idle,
            "total": total
        };
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.visible
        triggeredOnStart: true
        onTriggered: root.sample()
    }

    Timer {
        // The cat widget's curve: about 300 ms a step at 15 %, 180 at 40 %, 90 at 70 %.
        interval: Math.max(60, Math.ceil(5000 / Math.sqrt(root.load + 35) - 400))
        repeat: true
        running: !root.asleep && root.visible
        onTriggered: root.step = (root.step + 1) % root.cycle.length
    }

    Image {
        anchors.fill: parent
        source: Qt.resolvedUrl("../assets/coreflame/chimera/shime" + (root.asleep ? 21 : root.cycle[root.step]) + ".png")
        sourceSize: Qt.size(128, 128)
        fillMode: Image.PreserveAspectFit
        smooth: false
    }
}
