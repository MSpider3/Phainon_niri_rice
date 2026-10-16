pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// One chimera for the whole shell. The corner sprite and the chimera (cat) plugin both read
// their CPU load, sleep/wake state and current step from here, so they always move together.
// Thresholds and poll rate follow the plugin's own settings.
Singleton {
    id: root

    property real load: 0
    // CPU package temperature in °C, read with the same sample (for the Irontomb warning).
    property real temp: 0
    property int step: 0
    property var last: null
    // Anything showing the chimera adds itself here; with nobody watching, nothing is sampled.
    property int watchers: 0
    // Forget the last sample while nobody watches, so the first reading back is not an
    // average over the whole pause.
    onWatchersChanged: {
        if (watchers === 0)
            last = null;
    }

    readonly property int idleBelow: SettingsData.getPluginSetting("catWidget", "idleThreshold", 15)
    readonly property int pollMs: SettingsData.getPluginSetting("catWidget", "updateInterval", 2) * 1000
    readonly property bool asleep: load < idleBelow
    // stand, step, stand, other step
    readonly property var cycle: [1, 2, 1, 3]
    readonly property int frame: asleep ? 21 : cycle[step]

    // Which thermal zone is the CPU package differs per machine: looked up once at start.
    Process {
        running: true
        command: ["sh", "-c", "for z in /sys/class/thermal/thermal_zone*; do [ \"$(cat $z/type 2>/dev/null)\" = x86_pkg_temp ] && echo $z/temp && break; done"]
        stdout: StdioCollector {
            onStreamFinished: thermal.path = text.trim()
        }
    }

    FileView {
        id: thermal
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: stat
        path: "/proc/stat"
        blockLoading: true
        printErrors: false
    }

    function sample() {
        if (thermal.path !== "") {
            thermal.reload();
            temp = (parseInt(thermal.text()) || 0) / 1000;
        }
        stat.reload();
        const parts = (stat.text().split("\n")[0] ?? "").trim().split(/\s+/);
        if (parts.length < 5 || parts[0] !== "cpu")
            return;
        const n = parts.slice(1, 9).map(x => parseInt(x) || 0);
        const idle = n[3] + n[4];
        const total = n.reduce((a, b) => a + b, 0);
        if (last && total > last.total)
            load = Math.round((total - last.total - (idle - last.idle)) / (total - last.total) * 100);
        if (load >= 90)
            Coreflames.earn("strife");
        last = {
            "idle": idle,
            "total": total
        };
    }

    Timer {
        interval: root.pollMs
        repeat: true
        running: root.watchers > 0
        triggeredOnStart: true
        onTriggered: root.sample()
    }

    Timer {
        // The cat widget's curve: about 300 ms a step at 15 %, 180 at 40 %, 90 at 70 %.
        interval: Math.max(60, Math.ceil(5000 / Math.sqrt(root.load + 35) - 400))
        repeat: true
        running: root.watchers > 0 && !root.asleep
        onTriggered: root.step = (root.step + 1) % root.cycle.length
    }
}
