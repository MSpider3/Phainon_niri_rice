import QtQuick
import QtQuick.Shapes
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets

// "Ocean · Now playing" (v3 mockup): cover, the two choosers (player and sound output), the title,
// the controls and the seek bar, in the form's frame. The dashboard keeps the position ticking.
//   Phainon: a round paper cover, plain paper cards, a lapis play disc, a sun on the seek line.
//   Khaslana: a gold-edged red cover block, cut plates, a solid gold play plate, his blade.
//   Flame Reaver: a lined slab cover, slab chips, crossed blades, a hexagon plate, a scorched line.
DashSheet {
    id: view

    readonly property CfInk ink: CfInk {}
    readonly property MprisPlayer player: MprisController.activePlayer
    readonly property bool playing: !!player && player.playbackState === MprisPlaybackState.Playing
    readonly property real length: player?.length > 0 ? player.length : MprisController.activePlayerStableLength
    readonly property real progress: length > 0 ? Math.max(0, Math.min(1, (player?.position ?? 0) / length)) : 0
    property bool sinksOpen: false
    readonly property var sinks: sinksOpen ? AudioService.getAvailableSinks() : []
    readonly property string sinkName: AudioService.displayName(AudioService.sink) || "No output"

    // Layout: the listening card, the song card (grows with a two-line title) and the transport
    readonly property real listenH: ph ? 102 : (kh ? 80 : 104)
    readonly property real songH: kh ? Math.max(115, songCol.implicitHeight + 37) : songCol.implicitHeight + 40
    readonly property real topH: Math.max(220, listenH + 12 + songH)
    readonly property real transportY: ph ? topH + 12 : (kh ? listenH + 10 + songH : 254)

    function seek(to) {
        if (player?.canSeek && length > 0)
            player.position = to * length;
    }

    function cycleLoop() {
        if (!player?.canControl || !player.loopSupported)
            return;
        player.loopState = player.loopState === MprisLoopState.None ? MprisLoopState.Playlist : (player.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None);
    }

    // The Reaver's clock reads 01:42
    function time(seconds) {
        const t = Chrono.format(Math.floor(seconds));
        return rv && t.length < 5 ? "0" + t : t;
    }

    title: "Ocean · Now playing"
    glyph: "ocean"
    bodyHeight: ph ? transportY + 122 : (kh ? transportY + 116 : 404)
    blocks: kh ? [[0, 0, spanW(1), listenH + 5 + songH, true], [colX(1), 0, spanW(3), listenH, false], [colX(1), listenH + 5, spanW(3), songH, true], [0, transportY, bodyWidth, 116, false]] : []

    // The device list is only read while it is open, as the stock media tab does.
    onSinksOpenChanged: sinksOpen ? AudioService.addRef() : AudioService.removeRef()
    Component.onDestruction: if (sinksOpen)
        AudioService.removeRef()

    // A choice: a paper pill in Phainon, a cut gold plate in Khaslana, a slab with a left edge in
    // the Reaver.
    component Chip: Item {
        id: chip

        property string text: ""
        property bool on: false
        property real maxWidth: 160
        signal clicked

        implicitWidth: Math.min(maxWidth, chipText.implicitWidth + 28)
        implicitHeight: view.ph ? 26 : 24

        Rectangle {
            visible: view.ph
            anchors.fill: parent
            radius: height / 2
            color: chip.on ? "#334786" : (chipMouse.containsMouse ? "#FFFDF7" : "#FBF9F3")
            border.width: 1
            border.color: chip.on ? "#334786" : "#C8B27E"
        }

        Shape {
            visible: view.kh
            anchors.fill: parent

            ShapePath {
                fillColor: chip.on ? "#E0B04A" : (chipMouse.containsMouse ? "#2A1015" : "transparent")
                strokeColor: "#E0B04A"
                strokeWidth: 1
                joinStyle: ShapePath.MiterJoin
                PathSvg {
                    path: `M0.5 0.5 H${chip.width - 0.5} V${Math.round(chip.height * 0.68)} L${chip.width - 8} ${chip.height - 0.5} H0.5 Z`
                }
            }
        }

        Rectangle {
            visible: view.rv
            anchors.fill: parent
            color: chipMouse.containsMouse ? "#1A1528" : "transparent"
            border.width: 1
            border.color: chip.on ? "#8F7BE0" : "#5C5478"

            Rectangle {
                width: 3
                height: parent.height
                color: parent.border.color
            }
        }

        Text {
            id: chipText
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: view.rv ? 1 : 0
            width: Math.min(implicitWidth, chip.maxWidth - 28)
            elide: Text.ElideRight
            text: view.rv ? (chip.on ? "> " : "") + chip.text.toLowerCase() : (view.kh ? chip.text.toUpperCase() : chip.text)
            font.family: view.kh ? "Cinzel" : view.ink.font
            font.pixelSize: view.kh ? 12 : (view.ph ? 13 : 14)
            font.weight: view.kh ? Font.DemiBold : Font.Normal
            font.letterSpacing: view.kh ? 1.7 : 0
            color: view.ph ? (chip.on ? "#F7F3E8" : "#334786") : (view.kh ? (chip.on ? "#0B080B" : "#F5D27A") : (chip.on ? "#E9E7F2" : "#A8A4BC"))
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    // One transport button. `kind` is shuffle, previous, play, next or repeat; it is faint and
    // inert when the player doesn't offer it, half-faint when a toggle is off.
    component Control: Item {
        id: ctl

        required property string kind
        readonly property MprisPlayer p: view.player
        readonly property bool main: kind === "play"
        readonly property bool toggle: kind === "shuffle" || kind === "repeat"
        readonly property bool blade: view.rv && (kind === "previous" || kind === "next")
        readonly property bool able: {
            switch (kind) {
            case "shuffle":
                return !!p?.shuffleSupported && !!p?.canControl;
            case "previous":
                return !!p?.canGoPrevious || !!p?.canSeek;
            case "play":
                return !!p?.canTogglePlaying;
            case "next":
                return !!p?.canGoNext;
            case "repeat":
                return !!p?.loopSupported && !!p?.canControl;
            }
            return false;
        }
        readonly property bool on: kind === "shuffle" ? !!p?.shuffle : (kind === "repeat" ? !!p && p.loopState !== MprisLoopState.None : true)
        readonly property string icon: {
            switch (kind) {
            case "shuffle":
                return "shuffle";
            case "previous":
                return "skip_previous";
            case "play":
                return view.playing ? "pause" : "play_arrow";
            case "next":
                return "skip_next";
            }
            return p?.loopState === MprisLoopState.Track ? "repeat_one" : "repeat";
        }
        readonly property color tone: view.ph ? (main ? "#F7F3E8" : "#334786") : (view.kh ? (main ? "#0B080B" : "#E0B04A") : "#B9A8FF")
        readonly property bool hot: ctlMouse.containsMouse && able

        implicitWidth: view.ph ? (main ? 52 : 34) : (view.kh ? (main ? 60 : 46) : (main ? 54 : 34))
        implicitHeight: view.ph ? (main ? 52 : 34) : (view.kh ? (main ? 46 : 38) : (main ? 44 : 34))
        opacity: !able ? 0.2 : (toggle && !on ? 0.35 : 1)

        // Phainon: the play button is a full lapis disc
        Rectangle {
            visible: view.ph && ctl.main
            anchors.fill: parent
            radius: width / 2
            color: ctl.hot ? "#3D5396" : "#334786"
        }

        // Khaslana: cut plates edged in gold; the play plate solid gold over a red offset
        Repeater {
            model: view.kh ? (ctl.main ? [["#8E1424", 4, 3], ["#E0B04A", 0, 0]] : [[ctl.hot ? "#2A1015" : "transparent", 0, 0]]) : []

            Shape {
                required property var modelData
                x: modelData[1]
                y: modelData[2]
                width: ctl.width
                height: ctl.height

                ShapePath {
                    fillColor: modelData[0]
                    strokeColor: ctl.main ? "transparent" : "#E0B04A"
                    strokeWidth: 1
                    joinStyle: ShapePath.MiterJoin
                    PathSvg {
                        path: `M0.5 0.5 H${ctl.width - 0.5} V${Math.round(ctl.height * 0.72)} L${ctl.width - 10} ${ctl.height - 0.5} H0.5 Z`
                    }
                }
            }
        }

        // Reaver: play sits in a hexagon plate shaped like his mask, edged in violet
        Shape {
            visible: view.rv && ctl.main
            anchors.fill: parent

            ShapePath {
                fillColor: ctl.hot ? "#241D38" : "#1A1528"
                strokeColor: "#8F7BE0"
                strokeWidth: 1
                joinStyle: ShapePath.MiterJoin
                PathPolyline {
                    path: {
                        const w = ctl.width - 1, h = ctl.height - 1;
                        return [Qt.point(0.5 + 0.1 * w, 0.5), Qt.point(0.5 + 0.9 * w, 0.5), Qt.point(0.5 + w, 0.5 + 0.4 * h), Qt.point(0.5 + 0.7 * w, 0.5 + h), Qt.point(0.5 + 0.3 * w, 0.5 + h), Qt.point(0.5, 0.5 + 0.4 * h), Qt.point(0.5 + 0.1 * w, 0.5)];
                    }
                }
            }
        }

        // Reaver: previous and next are crossed blades; the short bars are the guards, on the
        // side it skips to.
        Shape {
            visible: ctl.blade
            anchors.centerIn: parent
            width: 24
            height: 24
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: ctl.tone
                strokeWidth: 1.5
                capStyle: ShapePath.FlatCap
                PathSvg {
                    path: ctl.kind === "next" ? "M5 5 L19 19 M5 19 L19 5 M15.5 21 L21 15.5 M15.5 3 L21 8.5 M22 9 V15" : "M19 5 L5 19 M19 19 L5 5 M8.5 21 L3 15.5 M8.5 3 L3 8.5 M2 9 V15"
                }
            }
        }

        DIcon {
            visible: !ctl.blade
            anchors.centerIn: parent
            name: ctl.icon
            size: view.ph && ctl.main ? 26 : 22
            color: ctl.tone
        }

        CfEmber {
            id: ctlEmber
            anchors.centerIn: parent
            size: 14
        }

        MouseArea {
            id: ctlMouse
            anchors.fill: parent
            enabled: ctl.able
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (view.rv)
                    ctlEmber.flare();
                switch (ctl.kind) {
                case "shuffle":
                    ctl.p.shuffle = !ctl.p.shuffle;
                    break;
                case "previous":
                    MprisController.previousOrRewind();
                    break;
                case "play":
                    ctl.p.togglePlaying();
                    break;
                case "next":
                    MprisController.next();
                    break;
                case "repeat":
                    view.cycleLoop();
                    break;
                }
            }
        }
    }

    // ── the cover: a paper disc, the red block inside a gold line, a lined slab ──
    Item {
        id: cover
        readonly property string art: view.player?.trackArtUrl ?? ""
        width: view.ph ? 220 : (view.kh ? view.spanW(1) : 236)
        height: view.ph ? 220 : (view.kh ? view.listenH + 5 + view.songH : 236)

        Shape {
            visible: view.ph
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: "#C8B27E"
                strokeWidth: 1
                fillGradient: RadialGradient {
                    centerX: 110
                    centerY: 84
                    centerRadius: 175
                    focalX: 110
                    focalY: 84
                    GradientStop {
                        position: 0
                        color: "#FBF9F3"
                    }
                    GradientStop {
                        position: 0.58
                        color: "#E7DFC8"
                    }
                    GradientStop {
                        position: 1
                        color: "#C8B27E"
                    }
                }
                PathAngleArc {
                    centerX: 110
                    centerY: 110
                    radiusX: 109.5
                    radiusY: 109.5
                    sweepAngle: 360
                }
            }
        }

        DashCard {
            visible: view.rv
            anchors.fill: parent
            poly: [[0, 0], [1, 0.03], [0.97, 1], [0.02, 0.94]]
        }

        // The slab's lines and the art keep inside the shard's slant
        Item {
            id: face
            x: view.rv ? 8 : 0
            y: view.rv ? 9 : 0
            width: parent.width - (view.rv ? 17 : 0)
            height: parent.height - (view.rv ? 25 : 0)

            Repeater {
                model: view.rv ? Math.floor(face.height / 7) : 0

                Rectangle {
                    required property int index
                    y: index * 7 + 6
                    width: face.width
                    height: 1
                    color: "#16121F"
                }
            }

            ClippingRectangle {
                anchors.fill: parent
                radius: view.ph ? width / 2 : 0
                color: "transparent"
                visible: coverImage.status === Image.Ready

                Image {
                    id: coverImage
                    anchors.fill: parent
                    source: cover.art
                    sourceSize: Qt.size(cover.width * 2, cover.height * 2)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            CfGlyph {
                visible: coverImage.status !== Image.Ready
                anchors.centerIn: parent
                name: "ocean"
                size: view.ph ? 96 : 90
                strokeWidth: view.ph ? 1 : 1.2
                color: view.ph ? "#334786" : (view.kh ? "#E0B04A" : "#B9A8FF")
            }
        }

        Rectangle {
            visible: view.kh
            anchors.fill: parent
            anchors.margins: 8
            color: "transparent"
            border.width: 1
            border.color: "#E0B04A"
        }
    }

    // ── which player is heard, and through what ──
    DashCard {
        id: listen
        x: view.ph ? 234 : (view.kh ? view.colX(1) : 250)
        width: view.ph ? 514 : (view.kh ? view.spanW(3) : 530)
        height: view.listenH
        z: view.sinksOpen ? 3 : 0
        bare: view.kh
        flute: false
        poly: [[0.04, 0], [1, 0], [0.96, 1], [0, 0.88]]
        label: "Listening from"

        Row {
            id: chips
            readonly property int count: MprisController.availablePlayers.length
            readonly property real room: parent.width - (view.ph ? 0 : outRow.width + 16)
            spacing: 8

            Repeater {
                model: MprisController.availablePlayers

                Chip {
                    required property var modelData
                    maxWidth: Math.min(160, chips.room / Math.max(1, chips.count) - 8)
                    text: modelData.identity || "Player"
                    on: modelData === view.player
                    onClicked: MprisController.setActivePlayer(modelData)
                }
            }

            Text {
                visible: chips.count === 0
                height: 24
                verticalAlignment: Text.AlignVCenter
                text: view.rv ? "nothing." : "—"
                font.family: view.ink.font
                font.pixelSize: 13
                color: view.ink.muted
            }
        }

        // Phainon: its own line, "Sound output" and a chip
        Text {
            visible: view.ph
            y: 36
            height: 26
            verticalAlignment: Text.AlignVCenter
            text: "Sound output"
            font.family: view.ink.font
            font.pixelSize: 13
            color: view.ink.muted
        }

        Chip {
            visible: view.ph
            anchors.right: parent.right
            y: 36
            maxWidth: 260
            text: view.sinkName + " ▾"
            on: view.sinksOpen
            onClicked: view.sinksOpen = !view.sinksOpen
        }

        // Khaslana and the Reaver: "output · Speakers" at the end of the chips' line
        Row {
            id: outRow
            visible: !view.ph
            anchors.right: parent.right
            height: 24

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "output · "
                font.family: view.ink.font
                font.pixelSize: 13
                color: view.ink.muted
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 200)
                elide: Text.ElideRight
                text: view.kh ? view.sinkName + " ▾" : view.sinkName.toLowerCase()
                font.family: view.ink.font
                font.pixelSize: 13
                color: view.kh ? "#F5D27A" : (view.sinksOpen || outMouse.containsMouse ? "#E9E7F2" : view.ink.muted)
            }
        }

        MouseArea {
            id: outMouse
            visible: !view.ph
            anchors.fill: outRow
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: view.sinksOpen = !view.sinksOpen
        }

        // The sound outputs, dropped over the cards below
        Item {
            visible: view.sinksOpen
            anchors.right: parent.right
            y: view.ph ? 66 : 28
            width: 300
            height: sinkList.implicitHeight + 8

            Rectangle {
                anchors.fill: parent
                radius: view.ph ? 12 : 0
                color: view.ph ? "#FBF9F3" : (view.kh ? "#0B080B" : "#0D0B14")
                border.width: 1
                border.color: view.ph ? "#C8B27E" : (view.kh ? "#E0B04A" : "#5C5478")

                Rectangle {
                    visible: view.rv
                    width: 3
                    height: parent.height
                    color: "#8F7BE0"
                }
            }

            Column {
                id: sinkList
                y: 4
                width: parent.width

                Repeater {
                    model: view.sinks

                    Item {
                        id: sinkRow
                        required property var modelData
                        readonly property bool current: modelData === AudioService.sink
                        width: sinkList.width
                        height: 30

                        Rectangle {
                            visible: sinkMouse.containsMouse
                            anchors.fill: parent
                            anchors.leftMargin: 4
                            anchors.rightMargin: 4
                            radius: view.ph ? 8 : 0
                            color: view.ph ? "#EFE6CC" : (view.kh ? "#2A1015" : "#1A1528")
                        }

                        Text {
                            x: 14
                            width: parent.width - 28
                            height: parent.height
                            verticalAlignment: Text.AlignVCenter
                            // Outputs of one card differ only at the end ("… (HDMI 2)")
                            elide: Text.ElideMiddle
                            text: (view.rv && sinkRow.current ? "> " : "") + view.ink.tx(AudioService.displayName(sinkRow.modelData))
                            font.family: view.ink.font
                            font.pixelSize: 13
                            font.weight: sinkRow.current ? Font.DemiBold : Font.Normal
                            color: sinkRow.current ? view.ink.accent : view.ink.text
                        }

                        MouseArea {
                            id: sinkMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                AudioService.setSink(sinkRow.modelData);
                                view.sinksOpen = false;
                            }
                        }
                    }
                }
            }
        }
    }

    // ── the song ──
    DashCard {
        x: listen.x
        y: view.ph ? view.listenH + 12 : (view.kh ? view.listenH + 5 : 116)
        width: listen.width
        height: view.rv ? 130 : view.songH
        bare: view.kh
        flute: false
        poly: [[0, 0.06], [1, 0], [0.98, 1], [0.03, 0.95]]
        label: "I · Song"

        Column {
            id: songCol
            width: parent.width
            spacing: 4

            Item {
                width: parent.width
                height: songTitle.height

                // The Reaver's title splits like a cracked screen: violet and teal copies behind
                Repeater {
                    model: view.rv ? [["#D98F7BE0", 2], ["#8C4FD1C5", -2]] : []

                    Text {
                        required property var modelData
                        x: modelData[1]
                        width: songTitle.width
                        elide: Text.ElideRight
                        text: songTitle.text
                        font: songTitle.font
                        color: modelData[0]
                    }
                }

                Text {
                    id: songTitle
                    width: parent.width
                    wrapMode: Text.WordWrap
                    maximumLineCount: view.rv ? 1 : 2
                    elide: Text.ElideRight
                    text: view.player?.trackTitle ? (view.kh ? view.player.trackTitle.toUpperCase() : view.ink.tx(view.player.trackTitle)) : (view.rv ? "nothing." : "Nothing playing")
                    font.family: view.ph ? "Marcellus" : (view.kh ? "Cinzel" : "Chakra Petch")
                    font.pixelSize: 26
                    font.weight: view.ph ? Font.Normal : (view.kh ? Font.Bold : Font.DemiBold)
                    font.letterSpacing: view.kh ? 2.6 : 0
                    color: view.ph ? view.ink.text : (view.kh ? "#F5D27A" : "#E9E7F2")
                }
            }

            Text {
                visible: text !== ""
                width: parent.width
                elide: Text.ElideRight
                text: view.ink.tx([view.player?.trackArtist, view.player?.trackAlbum].filter(t => !!t).join(" · "))
                font.family: view.ink.font
                font.pixelSize: 14
                color: view.ink.muted
            }
        }
    }

    // ── the controls and the seek bar ──
    DashCard {
        y: view.transportY
        width: view.bodyWidth
        height: view.ph ? 122 : (view.kh ? 116 : 150)
        bare: view.kh
        flute: false
        poly: [[0.02, 0.04], [1, 0], [0.97, 0.96], [0, 1]]

        Column {
            width: parent.width
            topPadding: view.rv ? 22 : 12
            spacing: 14

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: view.kh ? 24 : 12

                Repeater {
                    model: ["shuffle", "previous", "play", "next", "repeat"]

                    Control {
                        required property string modelData
                        anchors.verticalCenter: parent.verticalCenter
                        kind: modelData
                    }
                }
            }

            Item {
                width: parent.width
                height: 18

                Text {
                    width: 48
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    text: view.time(view.player?.position ?? 0)
                    font.family: Form.numerals
                    font.pixelSize: 13
                    color: view.ph ? view.ink.muted : (view.kh ? "#F5D27A" : "#CFC6A8")
                }

                Text {
                    anchors.right: parent.right
                    width: 48
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignRight
                    text: view.time(view.length)
                    font.family: Form.numerals
                    font.pixelSize: 13
                    color: view.ink.muted
                }

                Item {
                    id: track
                    readonly property real at: Math.round(width * view.progress)
                    x: 60
                    width: parent.width - 120
                    height: parent.height

                    // The line not yet played
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: view.ph ? 3 : 2
                        radius: view.ph ? 1.5 : 0
                        color: view.ph ? "#E4DAC0" : (view.kh ? "#3A1A1E" : "#2C2840")
                    }

                    // Played: lapis in Phainon, his golden blade in Khaslana
                    Rectangle {
                        visible: !view.rv
                        anchors.verticalCenter: parent.verticalCenter
                        width: track.at
                        height: view.ph ? 3 : 4
                        radius: view.ph ? 1.5 : 0
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop {
                                position: 0
                                color: view.ph ? "#334786" : "#9C6A18"
                            }
                            GradientStop {
                                position: 1
                                color: view.ph ? "#334786" : "#F2C75C"
                            }
                        }
                    }

                    // Played, in the Reaver: a dashed scorch
                    Item {
                        visible: view.rv
                        anchors.verticalCenter: parent.verticalCenter
                        width: track.at
                        height: 2
                        clip: true

                        Row {
                            spacing: 3

                            Repeater {
                                model: view.rv ? Math.ceil(track.width / 12) : 0

                                Rectangle {
                                    width: 9
                                    height: 2
                                    color: "#5C5478"
                                }
                            }
                        }
                    }

                    // The head: a small sun, a diamond point with a red offset, one ember
                    Item {
                        x: track.at - width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22
                        height: 22

                        Repeater {
                            model: view.ph ? [[22, "#4DF1DA4F", "transparent"], [14, "#F1DA4F", "#A87A22"]] : (view.rv ? [[22, "#26F07A85", "transparent"], [14, "#59F07A85", "transparent"], [8, "#F07A85", "transparent"]] : [])

                            Rectangle {
                                required property var modelData
                                anchors.centerIn: parent
                                width: modelData[0]
                                height: width
                                radius: width / 2
                                color: modelData[1]
                                border.width: modelData[2] === "transparent" ? 0 : 1
                                border.color: modelData[2]
                            }
                        }

                        Repeater {
                            model: view.kh ? [["#8E1424", 3], ["#F5D27A", 0]] : []

                            Rectangle {
                                required property var modelData
                                anchors.centerIn: parent
                                anchors.horizontalCenterOffset: modelData[1]
                                width: 12
                                height: 12
                                rotation: 45
                                color: modelData[0]
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: view.player?.canSeek ?? false
                        cursorShape: Qt.PointingHandCursor
                        function report(mouse) {
                            view.seek(Math.max(0, Math.min(1, mouse.x / width)));
                        }
                        onPressed: mouse => report(mouse)
                        onPositionChanged: mouse => {
                            if (pressed)
                                report(mouse);
                        }
                    }
                }
            }
        }
    }
}
