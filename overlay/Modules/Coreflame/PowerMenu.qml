import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets as DW

// The session menu over a veiled screen. Log out, Slumber, Rekindle, restart and shut down
// ask for a second press before they act.
//   Khaslana: seven black cards with red tide feet over the rising Black Tide.
//   Flame Reaver: seven shards around his point of impact.
//   Phainon: medallions on the sun's path.
PanelWindow {
    id: menu

    required property var targetScreen
    property bool shown: false
    property real opening: shown ? 1 : 0
    readonly property real reveal: Motion.step(opening)
    property int selected: 0
    property int armed: -1
    property bool canHibernate: false

    readonly property string lay: !Form.active ? "phainon" : Form.form
    readonly property bool kh: lay === "khaslana"
    readonly property bool rv: lay === "reaver"
    readonly property bool ph: !kh && !rv
    readonly property bool parch: ph && Form.active && Theme.isLightMode

    readonly property var allChoices: [
        {
            "id": "lock",
            "icon": "lock",
            "label": "Lock",
            "lore": "Seal",
            "confirm": false
        },
        {
            "id": "suspend",
            "icon": "bedtime",
            "label": "Sleep",
            "lore": "Repose",
            "confirm": false
        },
        {
            "id": "hibernate",
            "icon": "ac_unit",
            "label": "Hibernate",
            "lore": "Slumber",
            "confirm": true
        },
        {
            "id": "logout",
            "icon": "logout",
            "label": "Log out",
            "lore": "Depart",
            "confirm": true
        },
        {
            "id": "restart",
            "icon": "refresh",
            "label": "Restart DMS",
            "lore": "Rekindle",
            "confirm": true
        },
        {
            "id": "reboot",
            "icon": "restart_alt",
            "label": "Restart",
            "lore": "Recurrence",
            "confirm": true
        },
        {
            "id": "poweroff",
            "icon": "power_settings_new",
            "label": "Shut down",
            "lore": "Curtain-Fall",
            "confirm": true
        }
    ]
    // Stock hibernateSupported: the kernel offers "disk" (gone e.g. under Secure Boot lockdown).
    readonly property var choices: allChoices.filter(c => c.id !== "hibernate" || (canHibernate && SessionService.hibernateSupported))
    // Slumber appears after the check finishes on first open; an armed index would then point at another action.
    onChoicesChanged: armed = -1

    // The line under the choices: the keys, or the question once a choice is armed
    readonly property string hint: armed < 0 || armed >= choices.length ? "Arrows to move · Enter to choose · Esc to close" : choices[armed].label + "? <b>Enter</b> confirm · <b>Esc</b> cancel"

    function open() {
        selected = 0;
        armed = -1;
        shown = true;
        Coreflames.earn("death");
    }

    function close() {
        shown = false;
        armed = -1;
    }

    function toggle() {
        if (shown)
            close();
        else
            open();
    }

    function hover(index) {
        if (selected !== index) {
            selected = index;
            armed = -1;
        }
    }

    function choose(index) {
        selected = index;
        if (choices[index].confirm && armed !== index) {
            armed = index;
            return;
        }
        close();
        switch (choices[index].id) {
        case "lock":
            Quickshell.execDetached(["dms", "ipc", "call", "lock", "lock"]);
            break;
        case "suspend":
            SessionService.suspend();
            break;
        case "hibernate":
            SessionService.hibernate();
            break;
        case "logout":
            SessionService.logout();
            break;
        case "restart":
            // Same as stock DMS: restarts the shell only, the session stays.
            Quickshell.execDetached(["dms", "restart"]);
            break;
        case "reboot":
            Form.cinematic("closing", () => SessionService.reboot());
            break;
        case "poweroff":
            Form.cinematic("closing", () => SessionService.poweroff());
            break;
        }
    }

    // Hibernation only works with a resume device and enough real swap to hold RAM;
    // zram lives in RAM, so it does not count. Runs once, when the menu is first loaded.
    Process {
        running: true
        command: ["sh", "-c", "grep -qE '(^| )resume=' /proc/cmdline && awk 'NR==FNR { if ($1 == \"MemTotal:\") m = $2; next } FNR > 1 && $1 !~ /^\\/dev\\/zram/ { s += $3 } END { exit !(m > 0 && s >= m) }' /proc/meminfo /proc/swaps"]
        onExited: code => menu.canHibernate = code === 0
    }

    screen: targetScreen
    visible: reveal > 0.001
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "coreflame:powermenu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Behavior on opening {
        NumberAnimation {
            duration: Form.active ? Motion.openMs : Theme.shortDuration
            easing.type: Motion.openEasing
            easing.overshoot: 0.6
        }
    }

    onShownChanged: if (shown)
        keys.forceActiveFocus()

    // The veil
    Rectangle {
        anchors.fill: parent
        opacity: menu.reveal
        color: menu.kh ? Qt.rgba(8 / 255, 5 / 255, 7 / 255, 0.78) : (menu.rv ? Qt.rgba(6 / 255, 5 / 255, 10 / 255, 0.8) : "transparent")
        gradient: menu.ph ? phVeil : null

        Gradient {
            id: phVeil
            GradientStop {
                position: 0
                color: Qt.rgba(15 / 255, 22 / 255, 51 / 255, 0.45)
            }
            GradientStop {
                position: 1
                color: Qt.rgba(15 / 255, 22 / 255, 51 / 255, 0.7)
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: menu.close()
        }
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        opacity: menu.reveal

        Keys.onEscapePressed: menu.close()
        Keys.onLeftPressed: {
            menu.selected = (menu.selected + menu.choices.length - 1) % menu.choices.length;
            menu.armed = -1;
        }
        Keys.onRightPressed: {
            menu.selected = (menu.selected + 1) % menu.choices.length;
            menu.armed = -1;
        }
        Keys.onReturnPressed: menu.choose(menu.selected)
        Keys.onEnterPressed: menu.choose(menu.selected)

        Loader {
            anchors.fill: parent
            active: menu.visible
            sourceComponent: menu.kh ? khLayout : (menu.rv ? rvLayout : phLayout)
        }
    }

    // ── Phainon: medallions on the sun's path ──
    Component {
        id: phLayout

        Item {
            id: phRoot

            readonly property color paper: menu.parch ? "#F7F3E8" : Theme.surfaceContainerHigh
            readonly property color rim: menu.parch ? "#C8B27E" : Theme.withAlpha(Theme.outline, 0.6)
            readonly property color ink: menu.parch ? "#1E2752" : Theme.surfaceText
            readonly property color mut: menu.parch ? "#4A5484" : Theme.withAlpha(Theme.surfaceText, 0.65)
            readonly property color lapis: menu.parch ? "#334786" : Theme.primary
            readonly property color onLapis: menu.parch ? "#F7F3E8" : Theme.primaryText
            readonly property string body: Form.active ? Form.numerals : Theme.fontFamily

            // Phainon's tarot card beside the path (installed from cinematics/); no file, no card.
            Image {
                visible: Form.phainon && status === Image.Ready
                anchors.verticalCenter: sun.verticalCenter
                anchors.right: sun.left
                anchors.rightMargin: 24
                height: Math.round(Math.min(440, phRoot.height * 0.46))
                fillMode: Image.PreserveAspectFit
                source: Form.phainon ? "file://" + Form.stateDir + "/cinematics/phainon-card.png" : ""
                asynchronous: true
                mipmap: true
            }

            // The sun's path: a dashed arc over a horizon, drawn in a 1100 × 560 box
            Item {
                id: sun
                readonly property real k: Math.min(1100, phRoot.width - 120) / 1100
                width: 1100 * k
                height: 560 * k
                x: Math.round((phRoot.width - width) / 2)
                y: Math.round((phRoot.height - height) / 2 - 20 * (1 - menu.reveal))

                // A point on the arc (the cubic below) at t in 0..1
                function at(t) {
                    const u = 1 - t;
                    return Qt.point(k * (u * u * u * 40 + 3 * u * u * t * 200 + 3 * u * t * t * 900 + t * t * t * 1060), k * (u * u * u * 520 + 3 * u * u * t * 20 + 3 * u * t * t * 20 + t * t * t * 520));
                }

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: Qt.rgba(247 / 255, 243 / 255, 232 / 255, 0.7)
                        strokeWidth: 1.5
                        strokeStyle: ShapePath.DashLine
                        dashPattern: [3, 5]
                        PathSvg {
                            path: `M${40 * sun.k} ${520 * sun.k}C${200 * sun.k} ${20 * sun.k} ${900 * sun.k} ${20 * sun.k} ${1060 * sun.k} ${520 * sun.k}`
                        }
                    }

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: Qt.rgba(247 / 255, 243 / 255, 232 / 255, 0.9)
                        strokeWidth: 1
                        PathSvg {
                            path: `M0 ${521 * sun.k}H${sun.width}`
                        }
                    }
                }

                Repeater {
                    model: menu.choices

                    Rectangle {
                        id: pm
                        required property var modelData
                        required property int index
                        readonly property bool current: menu.selected === index
                        readonly property real t: menu.choices.length > 1 ? 0.04 + 0.92 * index / (menu.choices.length - 1) : 0.5
                        readonly property point p: sun.at(t)
                        x: Math.round(p.x - width / 2)
                        y: Math.round(p.y - height / 2 - 30 * Math.sin(Math.PI * t))
                        width: 132
                        height: pmCol.implicitHeight + 20
                        topLeftRadius: 66
                        topRightRadius: 66
                        bottomLeftRadius: 16
                        bottomRightRadius: 16
                        color: phRoot.paper
                        border.width: 1
                        border.color: phRoot.rim

                        Column {
                            id: pmCol
                            y: 10
                            width: parent.width
                            spacing: 2

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 76
                                height: 76
                                radius: 38
                                color: pm.current ? phRoot.lapis : (menu.parch ? "#FBF9F3" : Theme.surfaceContainerHighest)
                                border.width: pm.current ? 6 : 1
                                border.color: pm.current ? Qt.rgba(241 / 255, 218 / 255, 79 / 255, 0.55) : phRoot.rim

                                DW.DIcon {
                                    anchors.centerIn: parent
                                    name: pm.modelData.icon
                                    size: 30
                                    color: pm.current ? phRoot.onLapis : phRoot.lapis
                                }
                            }

                            Item {
                                width: 1
                                height: 4
                            }

                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: pm.modelData.label
                                font.family: "Marcellus"
                                font.pixelSize: 17
                                color: phRoot.ink
                            }

                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: pm.modelData.lore
                                font.family: "Cormorant Garamond"
                                font.italic: true
                                font.pixelSize: 16
                                color: phRoot.mut
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: menu.hover(pm.index)
                            onClicked: menu.choose(pm.index)
                        }
                    }
                }
            }

            // The key line, or the question once a choice is armed
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: sun.y + sun.height + 40
                width: phHint.implicitWidth + 52
                height: phHint.implicitHeight + 28
                radius: height / 2
                color: phRoot.paper
                border.width: 1
                border.color: phRoot.rim

                Text {
                    id: phHint
                    anchors.centerIn: parent
                    text: menu.hint
                    textFormat: Text.StyledText
                    font.family: phRoot.body
                    font.pixelSize: 16
                    color: phRoot.ink
                }
            }
        }
    }

    // ── Khaslana: cards over the rising Black Tide ──
    Component {
        id: khLayout

        Item {
            id: khRoot

            readonly property int n: menu.choices.length
            readonly property real cw: Math.min(160, (width - 96 - 16 * (n - 1)) / n)
            readonly property var roman: ["I", "II", "III", "IV", "V", "VI", "VII"]
            readonly property string vein: `M${width / 2} 40L${width / 2 - 20} 120L${width / 2 + 20} 200L${width / 2 - 10} ${cards.y - 6}`

            // The red tide under a card: fixed pseudo-random heights, the same every time
            function feet(k) {
                let x = 7 + k * 13;
                const out = [];
                for (let i = 0; i < 12; i++) {
                    x = (x * 73 + 19) % 101;
                    out.push(6 + x % 20);
                }
                return out;
            }

            CfTide {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 380
                edge: "bottom"
                seed: 19
                base: 0.28
                liquid: 330
                cubes: 40
                cubeDepth: 380
            }

            // The golden-blood vein from the island down to the cards
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: "#1A0306"
                    strokeWidth: 12
                    joinStyle: ShapePath.MiterJoin
                    PathSvg {
                        path: khRoot.vein
                    }
                }

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: "#E2A63A"
                    strokeWidth: 6
                    joinStyle: ShapePath.MiterJoin
                    PathSvg {
                        path: khRoot.vein
                    }
                }

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: "#FFF0B5"
                    strokeWidth: 2
                    joinStyle: ShapePath.MiterJoin
                    PathSvg {
                        path: khRoot.vein
                    }
                }
            }

            Row {
                id: cards
                x: Math.round((khRoot.width - width) / 2)
                y: Math.round(khRoot.height * 0.28 - 30 * (1 - menu.reveal))
                spacing: 16

                Repeater {
                    model: menu.choices

                    Item {
                        id: card
                        required property var modelData
                        required property int index
                        readonly property bool current: menu.selected === index
                        width: khRoot.cw
                        height: 290

                        // The chosen card lifts, its red shadow left behind
                        Rectangle {
                            visible: card.current
                            x: 6
                            y: -8
                            width: parent.width
                            height: parent.height
                            color: "#3A0A12"
                        }

                        Rectangle {
                            id: face
                            y: card.current ? -14 : 0
                            width: parent.width
                            height: parent.height
                            clip: true
                            color: "#0B080B"
                            gradient: card.current ? lit : null
                            border.width: 1
                            border.color: card.current ? "#F2C75C" : "#8A5A2B"

                            Gradient {
                                id: lit
                                GradientStop {
                                    position: 0
                                    color: "#8E1424"
                                }
                                GradientStop {
                                    position: 1
                                    color: "#3A0A12"
                                }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 18
                                text: khRoot.roman[card.index] ?? ""
                                font.family: "Cinzel"
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                font.letterSpacing: 1.4
                                color: "#B0824A"
                            }

                            DW.DIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 104
                                name: card.modelData.icon
                                size: 40
                                color: card.current ? "#F5D27A" : "#E0B04A"
                            }

                            Column {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 36
                                width: parent.width
                                spacing: 2

                                Text {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    text: card.modelData.label
                                    font.family: "Cinzel"
                                    font.pixelSize: 15
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 1.2
                                    color: "#F3E6CC"
                                }

                                Text {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    text: card.modelData.lore
                                    font.family: "Cormorant Garamond"
                                    font.italic: true
                                    font.pixelSize: 19
                                    color: "#C9B89E"
                                }
                            }

                            // Red tide feet
                            Row {
                                visible: !card.current
                                y: parent.height - 26
                                width: parent.width
                                spacing: 3

                                Repeater {
                                    model: khRoot.feet(card.index)

                                    Rectangle {
                                        required property int modelData
                                        required property int index
                                        readonly property int nth: index + 1
                                        width: (face.width - 33) / 12
                                        height: modelData
                                        color: nth % 11 === 0 ? "#E0B04A" : (nth % 7 === 0 ? "#3A0A12" : (nth % 3 === 0 ? "#C2252F" : "#8E1424"))
                                    }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: menu.hover(card.index)
                            onClicked: menu.choose(card.index)
                        }
                    }
                }
            }

            // The key line, or the question, on a black plate
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                y: cards.y + 290 + 70
                width: khHint.implicitWidth + 40
                height: khHint.implicitHeight + 24

                Rectangle {
                    x: 3
                    y: 3
                    width: parent.width
                    height: parent.height
                    color: "#8E1424"
                }

                Rectangle {
                    anchors.fill: parent
                    color: "#0B080B"
                    border.width: 1
                    border.color: "#E0B04A"
                }

                Text {
                    id: khHint
                    anchors.centerIn: parent
                    text: menu.hint.replace(/<b>/g, "<b><font color=\"#F2C75C\">").replace(/<\/b>/g, "</font></b>")
                    textFormat: Text.StyledText
                    font.family: "Chakra Petch"
                    font.pixelSize: 16
                    color: "#F3E6CC"
                }
            }
        }
    }

    // ── Flame Reaver: shards around the point of impact ──
    Component {
        id: rvLayout

        Item {
            id: rvRoot

            // Each action's shard in the 800 × 640 field: x, y, width, height, outline (shares of the box)
            readonly property var slots: ({
                    "lock": [140, 0, 220, 190, [[0, 0], [1, 0], [0.82, 1], [0.1, 0.8]]],
                    "suspend": [440, 0, 220, 190, [[0.18, 0], [1, 0], [0.9, 0.8], [0, 1]]],
                    "hibernate": [600, 220, 200, 190, [[0, 0.1], [1, 0], [1, 1], [0.14, 0.9]]],
                    "logout": [300, 225, 200, 190, [[0.1, 0], [0.92, 0.06], [1, 1], [0, 0.92]]],
                    "restart": [0, 220, 200, 190, [[0, 0], [1, 0.1], [0.86, 1], [0, 0.9]]],
                    "reboot": [130, 440, 230, 190, [[0.1, 0], [1, 0.2], [0.9, 1], [0, 1]]],
                    "poweroff": [440, 440, 230, 190, [[0, 0.2], [0.9, 0], [1, 1], [0.08, 1]]]
                })

            Item {
                id: field
                width: 800
                height: 640
                anchors.centerIn: parent
                scale: Math.min(1, (rvRoot.width - 40) / 800, (rvRoot.height - 120) / 640) * (0.92 + 0.08 * menu.reveal)

                CfCracks {
                    anchors.fill: parent
                    kind: "violet"
                }

                Repeater {
                    model: menu.choices

                    Item {
                        id: shard
                        required property var modelData
                        required property int index
                        readonly property bool current: menu.selected === index
                        readonly property bool armed: menu.armed === index
                        readonly property var slot: rvRoot.slots[modelData.id]
                        x: slot[0]
                        y: slot[1]
                        width: slot[2]
                        height: slot[3]

                        // The outline on a box inset by `i`, as CSS clip-path on `inset: i` does
                        function outline(i) {
                            const w = width - 2 * i, h = height - 2 * i;
                            const pts = slot[4].map(p => Qt.point(i + p[0] * w, i + p[1] * h));
                            pts.push(pts[0]);
                            return pts;
                        }

                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                strokeWidth: -1
                                fillGradient: LinearGradient {
                                    x1: 0
                                    y1: 0
                                    x2: shard.width
                                    y2: shard.height
                                    GradientStop {
                                        position: 0
                                        color: shard.current ? "#F07A85" : "#B9A8FF"
                                    }
                                    GradientStop {
                                        position: 0.5
                                        color: shard.current ? "#C07AB2" : "#5C5478"
                                    }
                                    GradientStop {
                                        position: 1
                                        color: "#8F7BE0"
                                    }
                                }
                                PathPolyline {
                                    path: shard.outline(0)
                                }
                            }

                            ShapePath {
                                strokeWidth: -1
                                fillColor: shard.current ? "#2A1424" : Qt.rgba(13 / 255, 11 / 255, 20 / 255, 0.95)
                                PathPolyline {
                                    path: shard.outline(2)
                                }
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 6

                            DW.DIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                name: shard.modelData.icon
                                size: 34
                                color: shard.current ? "#F07A85" : "#B9A8FF"
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: shard.modelData.label.toLowerCase()
                                font.family: "Chakra Petch"
                                font.pixelSize: 17
                                font.weight: Font.DemiBold
                                color: shard.armed ? "#F07A85" : "#E9E7F2"
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: shard.armed ? "enter again to confirm" : shard.modelData.lore.toLowerCase()
                                font.family: "Chakra Petch"
                                font.pixelSize: 13
                                color: shard.armed ? "#F7B0B7" : "#A8A4BC"
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: menu.hover(shard.index)
                            onClicked: menu.choose(shard.index)
                        }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: rvRoot.height / 2 + 320 * field.scale + 28
                text: "arrows to move · enter to choose · esc to close"
                font.family: "Chakra Petch"
                font.pixelSize: 13
                color: "#A8A4BC"
            }
        }
    }
}
