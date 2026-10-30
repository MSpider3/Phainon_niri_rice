import QtQuick
import QtQuick.Effects
import QtMultimedia
import Quickshell
import Quickshell.Io
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
    // From an optional <clip>.json beside the clip: where and when to draw the live cycle count
    // (and an optional caption line) over text cut out of the video. {"number": {x, y, cap, pitch,
    // color, glow, show, settle, fade, end, caption, captionY, captionCap, captionColor}}:
    // fractions of the video, seconds.
    property var count: null

    function play(file, then) {
        finish();
        done = then ?? null;
        playing = true;
        sidecar.path = file.replace(/\.[^./]+$/, ".json");
        try {
            count = JSON.parse(sidecar.text()).number ?? null;
        } catch (e) {
            count = null;
        }
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
        count = null;
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

        // The live cycle count, and a line under it, in place of text cut out of the clip.
        Item {
            id: stamp

            readonly property var n: cine.count
            readonly property real t: player.position / 1000
            readonly property real settled: n ? Math.min(1, Math.max(0, (t - n.show) / (n.settle - n.show))) : 0
            readonly property real grow: 0.8 + 0.2 * (1 - Math.pow(1 - settled, 3))

            x: video.contentRect.x
            y: video.contentRect.y
            width: video.contentRect.width
            height: video.contentRect.height
            visible: !!n && t >= n.show && t < n.end
            // Grows in with the camera pull-back, then fades with the scene.
            opacity: n ? Math.max(0, Math.min(1, (t - n.show) / 0.25, (n.end - t) / (n.end - n.fade))) : 0
            transform: Scale {
                origin.x: stamp.width * (stamp.n?.x ?? 0.5)
                origin.y: stamp.height * (stamp.n?.y ?? 0.5)
                xScale: stamp.grow
                yScale: stamp.grow
            }
            layer.enabled: visible
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: cine.count?.glow ?? "transparent"
                shadowBlur: 0.6
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }

            Text {
                readonly property var n: parent.n
                readonly property real px: Math.max(1, parent.height * (n?.cap ?? 0) / 0.7)

                text: Form.cycle
                color: n?.color ?? "white"
                font.family: Form.numerals
                font.pixelSize: px
                // The font's digits are 0.56 em apart; widen to the video's spacing.
                font.letterSpacing: parent.height * (n?.pitch ?? 0) - px * 0.56
                x: parent.width * (n?.x ?? 0) - (contentWidth - font.letterSpacing) / 2
                y: parent.height * ((n?.y ?? 0) + (n?.cap ?? 0) / 2) - baselineOffset
            }

            Text {
                readonly property var n: parent.n
                readonly property real px: Math.max(1, parent.height * (n?.captionCap ?? 0) / 0.7)

                visible: !!n?.caption
                text: n?.caption ?? ""
                color: n?.captionColor ?? n?.color ?? "white"
                font.family: Form.numerals
                font.pixelSize: px
                font.letterSpacing: px * 0.12
                // One or more lines ("\n"), centred under the number; y puts the first baseline.
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.35
                x: parent.width * ((n?.x ?? 0.5) - 0.5)
                y: parent.height * ((n?.captionY ?? 0) + (n?.captionCap ?? 0) / 2) - baselineOffset
            }
        }
    }

    FileView {
        id: sidecar
        blockLoading: true
        printErrors: false
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
