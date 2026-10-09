pragma Singleton

import QtQuick
import Quickshell

// Countdown timer and stopwatch shared by the dashboard and the island.
// Both tick once a second, and only while running.
Singleton {
    id: root

    property int timerTotal: 0
    property int timerLeft: 0
    property bool timerRunning: false
    readonly property bool timerActive: timerLeft > 0

    property int stopwatchSeconds: 0
    property bool stopwatchRunning: false

    signal timerFinished

    function startTimer(seconds) {
        timerTotal = seconds;
        timerLeft = seconds;
        timerRunning = true;
    }

    function toggleTimer() {
        if (timerLeft > 0)
            timerRunning = !timerRunning;
    }

    function resetTimer() {
        timerRunning = false;
        timerLeft = 0;
        timerTotal = 0;
    }

    function toggleStopwatch() {
        stopwatchRunning = !stopwatchRunning;
    }

    function resetStopwatch() {
        stopwatchRunning = false;
        stopwatchSeconds = 0;
    }

    function format(seconds) {
        const m = Math.floor(seconds / 60);
        const h = Math.floor(m / 60);
        const head = h > 0 ? h + ":" + String(m % 60).padStart(2, "0") : String(m);
        return head + ":" + String(seconds % 60).padStart(2, "0");
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.timerRunning
        onTriggered: {
            root.timerLeft--;
            if (root.timerLeft > 0)
                return;
            root.timerRunning = false;
            root.timerLeft = 0;
            root.timerFinished();
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.stopwatchRunning
        onTriggered: root.stopwatchSeconds++
    }
}
