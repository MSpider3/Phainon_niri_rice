import QtQuick
import QtMultimedia
import qs.Common
import qs.Services

// The lock-screen video: after 15 s locked with no input, while plugged in or at 50 % battery or
// more, cinematics/lock.mp4 plays full screen, muted, on a loop. Any key or pointer movement ends
// it at once (that key is not typed), and so does unplugging below 50 %. A missing or broken file
// just means no video. It sits above the lock screen and never touches authentication.
Item {
    id: root

    // false while a password is being typed or checked
    property bool armed: true
    property bool playing: false
    property bool failed: false
    readonly property bool powerOk: !BatteryService.batteryAvailable || BatteryService.isPluggedIn || BatteryService.batteryLevel >= 50

    signal dismissed

    // Input seen on any screen: end the video and count the 15 s again everywhere.
    function poke() {
        Form.lockInput++;
    }

    Connections {
        target: Form
        function onLockInputChanged() {
            root.playing = false;
            if (idle.running)
                idle.restart();
        }
    }

    onPowerOkChanged: if (!powerOk)
        playing = false
    onArmedChanged: if (!armed)
        playing = false
    onPlayingChanged: {
        if (playing) {
            player.source = "file://" + Form.stateDir + "/cinematics/lock.mp4";
            player.play();
        } else {
            player.stop();
            player.source = "";
            dismissed();
        }
    }

    Timer {
        id: idle
        interval: 15000
        running: Form.active && root.armed && root.powerOk && !root.playing && !root.failed
        onTriggered: root.playing = root.armed && root.powerOk
    }

    // Passive: sees pointer movement anywhere on the lock screen without taking it from the widgets.
    // Qt also sends hover events for a still cursor when items appear under it, so only real moves count.
    HoverHandler {
        property point last: Qt.point(-1, -1)
        onPointChanged: {
            const p = point.scenePosition;
            if (Math.abs(p.x - last.x) + Math.abs(p.y - last.y) > 2)
                root.poke();
            last = p;
        }
    }

    MediaPlayer {
        id: player
        videoOutput: video
        loops: MediaPlayer.Infinite
        // Take the keyboard only once a frame can show, so a missing file never blanks the lock screen.
        onHasVideoChanged: if (hasVideo && root.playing)
            catcher.forceActiveFocus()
        onErrorOccurred: (error, text) => {
            console.warn("Coreflame lock video: off,", text);
            root.failed = true;
            root.playing = false;
        }
    }

    Item {
        anchors.fill: parent
        visible: root.playing && player.hasVideo

        VideoOutput {
            id: video
            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectCrop
        }

        MouseArea {
            anchors.fill: parent
            onPressed: root.poke()
        }

        Item {
            id: catcher
            Keys.onPressed: event => {
                event.accepted = true;
                root.poke();
            }
        }
    }
}
