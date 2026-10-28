import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Wayland
import qs.Common

// A full-screen cinematic above everything: the opening at the first shell start of a boot,
// the closing before restart or shut down. Esc or a click skips it. Whatever happens (missing
// file, decode error, a stuck player) `done` runs, at the latest after 15 s, so a shut down
// never waits on a video.
PanelWindow {
    id: cine

    required property var targetScreen
    property var done: null
    property bool playing: false

    function play(file, then) {
        finish();
        done = then ?? null;
        playing = true;
        player.source = "file://" + file;
        guard.restart();
        player.play();
    }

    // `cut` is true when the window is torn down mid-play (not a skip by the user).
    function finish(cut) {
        guard.stop();
        player.stop();
        player.source = "";
        playing = false;
        const then = done;
        done = null;
        if (then)
            then(cut === true);
    }

    // A rebuilt chrome takes this window with it; still hand back so restart/shut down go ahead.
    Component.onDestruction: {
        if (playing)
            finish(true);
    }

    screen: targetScreen
    visible: playing
    color: "black"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "coreflame:cinematic"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    onVisibleChanged: if (visible)
        keys.forceActiveFocus()

    MediaPlayer {
        id: player
        videoOutput: video
        audioOutput: AudioOutput {}
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.EndOfMedia || mediaStatus === MediaPlayer.InvalidMedia)
                cine.finish();
        }
        onErrorOccurred: (error, text) => {
            console.warn("Coreflame cinematic: error", error, text);
            cine.finish();
        }
    }

    VideoOutput {
        id: video
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectFit
        // Same as mpv's --video-zoom=0.2 (2^0.2 ≈ 1.15×): the clips carry black side bars, this pushes them off screen.
        scale: Math.pow(2, 0.2)
    }

    Timer {
        id: guard
        interval: 15000
        onTriggered: cine.finish()
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: cine.finish()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: cine.finish()
    }
}
