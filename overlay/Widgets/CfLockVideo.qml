import QtQuick
import QtMultimedia
import qs.Common
import qs.Services

// The lock-screen video: after 15 s locked with no input, cinematics/lock.mp4 plays full screen,
// muted, on a loop. On battery it plays the 720p copy (lock-lite.mp4) instead and dims the screen
// to 60 % of its level until the next input, and it does not start below 20 % battery. It pauses
// while the screen is off. Any key or pointer movement ends it at once (that key is not typed).
// A missing or broken file just means no video. It sits above the lock screen and never touches
// authentication.
Item {
    id: root

    // false while a password is being typed or checked
    property bool armed: true
    property bool playing: false
    property bool failed: false
    readonly property bool onBattery: BatteryService.batteryAvailable && !BatteryService.isPluggedIn
    readonly property bool powerOk: !onBattery || BatteryService.batteryLevel >= 20
    readonly property bool screenOn: !IdleService.monitorsOff

    signal dismissed

    // Input seen on any screen: end the video and count the 15 s again everywhere.
    function poke() {
        Form.lockInput++;
    }

    function dim() {
        // The laptop's own panel only: never an external screen or an LED.
        const panel = BrightnessService.internalPanelDevice();
        if (!onBattery || Form.lockDimSaved >= 0 || !panel || panel.class !== "backlight")
            return;
        const level = BrightnessService.getDeviceBrightness(panel.id);
        Form.lockDimSaved = level;
        BrightnessService.setBrightness(Math.max(10, Math.round(level * 0.6)), panel.id, true);
    }

    function undim() {
        if (Form.lockDimSaved < 0)
            return;
        const level = Form.lockDimSaved;
        const panel = BrightnessService.internalPanelDevice();
        Form.lockDimSaved = -1;
        if (panel)
            BrightnessService.setBrightness(level, panel.id, true);
    }

    Connections {
        target: Form
        function onLockInputChanged() {
            root.playing = false;
            if (idle.running)
                idle.restart();
        }
    }

    // Plugging in or unplugging restarts the wait, so the next play uses the right copy.
    onOnBatteryChanged: playing = false
    onPowerOkChanged: if (!powerOk)
        playing = false
    onScreenOnChanged: if (!screenOn)
        playing = false
    onArmedChanged: if (!armed)
        playing = false
    onPlayingChanged: {
        if (playing) {
            player.source = "file://" + Form.stateDir + "/cinematics/" + (onBattery ? "lock-lite.mp4" : "lock.mp4");
            player.play();
            dim();
        } else {
            player.stop();
            player.source = "";
            undim();
            dismissed();
        }
    }
    // Unlocked while it played (fingerprint, or the lock torn down): put the brightness back.
    Component.onDestruction: undim()

    Timer {
        id: idle
        interval: 15000
        running: Form.active && root.armed && root.powerOk && root.screenOn && !root.playing && !root.failed
        onTriggered: root.playing = root.armed && root.powerOk && root.screenOn
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
