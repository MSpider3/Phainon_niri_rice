import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common

// "He Who Bears the World Must Burn": the one large animation, played once when the form changes.
//   Phainon      dawn rises from the bottom of the screen and passes.
//   Khaslana     the screen darkens, a ring of gold opens from the island, the world breaks into
//                slabs for a few frames, one white-gold flash, and it is over.
//   Flame Reaver the black tide: blocks of dark fill the screen left to right, then let go.
// It takes no input, loads only for its own duration, and is skipped on Power Saver.
PanelWindow {
    id: fx

    required property var targetScreen
    property string kind: ""
    property real t: 0
    property int step: 0
    readonly property bool lean: Motion.tier === "lean"
    readonly property int q: Math.floor(t * 14)

    signal finished

    function play() {
        kind = Form.form;
        t = 0;
        step = 0;
        run.duration = (kind === "khaslana" ? 950 : 800) * (lean ? 0.55 : 1);
        run.restart();
    }

    screen: targetScreen
    visible: kind !== ""
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "coreflame:transformation"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    NumberAnimation {
        id: run
        target: fx
        property: "t"
        from: 0
        to: 1
        onFinished: {
            fx.kind = "";
            fx.finished();
        }
    }

    Timer {
        interval: 55
        repeat: true
        running: fx.kind === "khaslana"
        onTriggered: fx.step++
    }

    // ── Phainon: dawn ──
    Rectangle {
        visible: fx.kind === "phainon"
        width: parent.width
        height: parent.height * 1.4
        y: parent.height * (1 - fx.t * 2.5)
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "transparent"
            }
            GradientStop {
                position: 0.3
                color: Qt.rgba(0.973, 0.914, 0.671, 0.75)
            }
            GradientStop {
                position: 0.55
                color: Qt.rgba(0.984, 0.976, 0.953, 0.9)
            }
            GradientStop {
                position: 1
                color: "transparent"
            }
        }
    }

    // ── Khaslana: ignition ──
    Item {
        visible: fx.kind === "khaslana"
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: "#05040A"
            opacity: fx.t < 0.15 ? fx.t * 5.3 : (fx.t < 0.72 ? 0.8 : Math.max(0, (1 - fx.t) * 2.8))
        }

        Rectangle {
            readonly property real d: Math.max(0, (fx.t - 0.12) / 0.58) * Math.max(parent.width, parent.height) * 2.3
            visible: fx.t > 0.12 && fx.t < 0.72
            x: parent.width / 2 - d / 2
            y: 20 - d / 2
            width: d
            height: d
            radius: d / 2
            color: "transparent"
            border.width: 5
            border.color: "#FBD865"
        }

        // The world as slabs, for a few frames
        Repeater {
            model: fx.lean ? 0 : 60

            Rectangle {
                required property int index
                readonly property bool lit: fx.step > 4 && fx.step < 12 && ((index * 7 + fx.step * 13) % 11) < 3
                visible: lit
                x: (index % 10) * parent.width / 10 + ((index * 5 + fx.step * 3) % 9) - 4
                y: Math.floor(index / 10) * parent.height / 6
                width: parent.width / 10
                height: parent.height / 6
                color: index % 3 === 0 ? Qt.rgba(0.83, 0.69, 0.29, 0.5) : (index % 3 === 1 ? Qt.rgba(0.79, 0.2, 0.2, 0.42) : Qt.rgba(0.02, 0.02, 0.05, 0.85))
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "#FDFBAF"
            opacity: fx.t > 0.7 ? Math.max(0, (0.86 - fx.t) * 5.5) : 0
        }
    }

    // ── Flame Reaver: the black tide ──
    Repeater {
        model: fx.kind === "reaver" ? 144 : 0

        Rectangle {
            required property int index
            readonly property real edge: (index % 16) / 16 + ((index * 29) % 17) / 17 * 0.22
            readonly property real p: fx.q / 14
            visible: p < 0.5 ? edge < p * 2.5 : edge > (p - 0.5) * 2.5
            x: (index % 16) * fx.width / 16
            y: Math.floor(index / 16) * fx.height / 9
            width: Math.ceil(fx.width / 16)
            height: Math.ceil(fx.height / 9)
            color: "#0A0A0C"
        }
    }
}
