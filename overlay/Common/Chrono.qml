pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Countdown timer and stopwatch shared by the dashboard and the island.
// Both keep wall-clock times (an end time, a start time) rather than counting ticks, so a busy
// CPU, a suspend or a shell restart cannot make them drift or lose their place. The ticks only
// refresh the numbers on screen, once a second, and only while something runs.
// State is kept in ~/.config/coreflame/chrono.json.
Singleton {
    id: root

    property int timerTotal: 0
    property int timerLeft: 0
    property bool timerRunning: false
    readonly property bool timerActive: timerLeft > 0
    // While running: when it ends (ms since epoch). While paused: unused.
    property real timerEnd: 0

    property int stopwatchSeconds: 0
    property bool stopwatchRunning: false
    // While running: when it would have started had it never paused (ms since epoch).
    property real stopwatchStart: 0

    signal timerFinished

    function now() {
        return Date.now();
    }

    function startTimer(seconds) {
        if (seconds <= 0)
            return;
        timerTotal = seconds;
        timerLeft = seconds;
        timerEnd = now() + seconds * 1000;
        timerRunning = true;
        save();
    }

    function toggleTimer() {
        if (timerLeft <= 0)
            return;
        if (timerRunning) {
            tickTimer();
            timerRunning = false;
        } else {
            timerEnd = now() + timerLeft * 1000;
            timerRunning = true;
        }
        save();
    }

    function resetTimer() {
        timerRunning = false;
        timerLeft = 0;
        timerTotal = 0;
        save();
    }

    function tickTimer() {
        timerLeft = Math.max(0, Math.ceil((timerEnd - now()) / 1000));
        if (timerLeft > 0)
            return;
        timerRunning = false;
        save();
        timerFinished();
    }

    function toggleStopwatch() {
        if (stopwatchRunning) {
            tickStopwatch();
            stopwatchRunning = false;
        } else {
            stopwatchStart = now() - stopwatchSeconds * 1000;
            stopwatchRunning = true;
        }
        save();
    }

    function resetStopwatch() {
        stopwatchRunning = false;
        stopwatchSeconds = 0;
        save();
    }

    function tickStopwatch() {
        stopwatchSeconds = Math.floor((now() - stopwatchStart) / 1000);
    }

    function format(seconds) {
        const m = Math.floor(seconds / 60);
        const h = Math.floor(m / 60);
        const head = h > 0 ? h + ":" + String(m % 60).padStart(2, "0") : String(m);
        return head + ":" + String(seconds % 60).padStart(2, "0");
    }

    function save() {
        file.setText(JSON.stringify({
            "timerTotal": timerTotal,
            "timerLeft": timerLeft,
            "timerRunning": timerRunning,
            "timerEnd": timerEnd,
            "stopwatchSeconds": stopwatchSeconds,
            "stopwatchRunning": stopwatchRunning,
            "stopwatchStart": stopwatchStart
        }) + "\n");
    }

    FileView {
        id: file
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/coreflame/chrono.json"
        blockLoading: true
        printErrors: false
    }

    // Pick up where a previous shell left off. A countdown that ended while the shell was gone
    // still reports that it finished.
    Component.onCompleted: {
        let saved = null;
        try {
            saved = JSON.parse(file.text());
        } catch (e) {
            return;
        }
        timerTotal = saved.timerTotal ?? 0;
        timerLeft = saved.timerLeft ?? 0;
        timerEnd = saved.timerEnd ?? 0;
        stopwatchSeconds = saved.stopwatchSeconds ?? 0;
        stopwatchStart = saved.stopwatchStart ?? 0;
        stopwatchRunning = saved.stopwatchRunning ?? false;
        timerRunning = saved.timerRunning ?? false;
        if (stopwatchRunning)
            tickStopwatch();
    }

    // The island needs a few seconds after start before it can announce "timer finished".
    property bool ready: false

    Timer {
        interval: 4000
        running: true
        onTriggered: root.ready = true
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.timerRunning && root.ready
        triggeredOnStart: true
        onTriggered: root.tickTimer()
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.stopwatchRunning
        onTriggered: root.tickStopwatch()
    }
}
