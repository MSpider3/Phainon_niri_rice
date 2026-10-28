import QtQuick
import QtQuick.Shapes
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets

// "Ocean · Now playing": cover, the two choosers (player and sound output), the full title, the
// controls and the seek bar. The dashboard keeps the position ticking while it is open.
Column {
    id: music

    readonly property MprisPlayer player: MprisController.activePlayer
    readonly property bool playing: !!player && player.playbackState === MprisPlaybackState.Playing
    readonly property real length: player?.length > 0 ? player.length : MprisController.activePlayerStableLength
    readonly property real progress: length > 0 ? Math.max(0, Math.min(1, (player?.position ?? 0) / length)) : 0
    readonly property real coverSize: 272
    readonly property real side: width - coverSize - 12
    property bool sinksOpen: false
    readonly property var sinks: sinksOpen ? AudioService.getAvailableSinks() : []

    function tx(text) {
        return Form.reaver ? String(text).toLowerCase() : text;
    }

    function seek(to) {
        if (player?.canSeek && length > 0)
            player.position = to * length;
    }

    function cycleLoop() {
        if (!player?.canControl || !player.loopSupported)
            return;
        player.loopState = player.loopState === MprisLoopState.None ? MprisLoopState.Playlist : (player.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None);
    }

    // The device list is only read while it is open, as the stock media tab does.
    onSinksOpenChanged: sinksOpen ? AudioService.addRef() : AudioService.removeRef()
    Component.onDestruction: if (sinksOpen)
        AudioService.removeRef()

    spacing: 12

    // A small choice: player or output. Round paper in Phainon, a cut plate in Khaslana, a slab
    // with a violet edge in the Reaver.
    component Pick: Item {
        id: pick

        property string icon: ""
        property string text: ""
        property bool on: false
        property real maxWidth: 220
        signal clicked

        implicitWidth: Math.min(maxWidth, pickRow.implicitWidth + 22)
        implicitHeight: 30

        CfSurface {
            anchors.fill: parent
            color: pick.on ? (Form.reaver ? Theme.surfaceContainerHighest : Theme.primary) : (pickMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)
            edgeColor: Form.reaver && pick.on ? Theme.live : Theme.withAlpha(Theme.outline, 0.5)
            edgeWidth: Form.reaver ? (pick.on ? 1 : 0) : 1
            lining: false
            radius: 15
        }

        Row {
            id: pickRow
            anchors.centerIn: parent
            width: Math.min(implicitWidth, pick.maxWidth - 22)
            spacing: 6

            DIcon {
                visible: pick.icon !== "" && !Form.reaver
                anchors.verticalCenter: parent.verticalCenter
                name: pick.icon
                size: 16
                color: pick.on ? Theme.primaryText : Theme.primary
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, pick.maxWidth - 22 - (pick.icon !== "" && !Form.reaver ? 22 : 0))
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                text: (Form.reaver && pick.on ? "> " : "") + music.tx(pick.text)
                font.family: Form.reaver ? Theme.monoFontFamily : Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: pick.on ? (Form.reaver ? Theme.live : Theme.primaryText) : Theme.surfaceText
            }
        }

        MouseArea {
            id: pickMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pick.clicked()
        }
    }

    // One transport button. `kind` is shuffle, previous, play, next or repeat; it is dimmed and
    // inert when the player doesn't offer it.
    component Control: Item {
        id: ctl

        required property string kind
        readonly property MprisPlayer p: music.player
        readonly property bool main: kind === "play"
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
        readonly property bool on: kind === "shuffle" ? !!p?.shuffle : (kind === "repeat" ? !!p && p.loopState !== MprisLoopState.None : false)
        readonly property string icon: {
            switch (kind) {
            case "shuffle":
                return "shuffle";
            case "previous":
                return "skip_previous";
            case "play":
                return music.playing ? "pause" : "play_arrow";
            case "next":
                return "skip_next";
            }
            return p?.loopState === MprisLoopState.Track ? "repeat_one" : "repeat";
        }
        readonly property color ink: !able ? Theme.withAlpha(Theme.surfaceText, 0.3) : (on ? (Form.reaver ? Theme.live : Theme.primary) : Theme.surfaceText)

        implicitWidth: Form.phainon ? (main ? 64 : 42) : (Form.khaslana ? (main ? 112 : 50) : (main ? 50 : 38))
        implicitHeight: Form.phainon ? (main ? 64 : 42) : (Form.khaslana ? 42 : 50)
        opacity: able ? 1 : 0.55

        // Phainon: round paper; the play button a full lapis disc
        Rectangle {
            visible: Form.phainon || !Form.active
            anchors.fill: parent
            radius: width / 2
            color: ctl.main ? Theme.primary : (ctlMouse.containsMouse && ctl.able ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)
            border.width: ctl.main ? 0 : 1
            border.color: ctl.on ? Theme.primary : Theme.withAlpha(Theme.outline, 0.45)
        }

        // Khaslana: a cut plate edged in gold; the play plate is solid gold
        CfSurface {
            visible: Form.khaslana
            anchors.fill: parent
            color: ctl.main || ctl.on ? Theme.primary : (ctlMouse.containsMouse && ctl.able ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)
            edgeColor: ctl.able ? Theme.primary : Theme.withAlpha(Theme.outline, 0.6)
            edgeWidth: 1
        }

        // Reaver: play is a small plate in the shape of his mask, edged in violet
        Shape {
            visible: Form.reaver && ctl.main
            anchors.centerIn: parent
            width: 24
            height: 24
            scale: ctl.width / 26
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: ctlMouse.containsMouse && ctl.able ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                strokeColor: Theme.live
                strokeWidth: 1.2
                joinStyle: ShapePath.MiterJoin

                PathSvg {
                    path: "M4.5 2.5 H19.5 V11 Q19.5 18 12 21.5 Q4.5 18 4.5 11 Z"
                }
            }
        }

        // Reaver: previous and next are two crossed blades with the hilts towards the direction
        Shape {
            visible: Form.reaver && (ctl.kind === "previous" || ctl.kind === "next")
            anchors.centerIn: parent
            width: 24
            height: 24
            scale: 1.15
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: ctl.ink
                strokeWidth: 1.5
                capStyle: ShapePath.FlatCap

                PathSvg {
                    // Two blades crossing; the short bars are the guards, on the side it skips to.
                    path: ctl.kind === "next" ? "M5 5 L19 19 M5 19 L19 5 M15.5 21 L21 15.5 M15.5 3 L21 8.5 M22 9 V15" : "M19 5 L5 19 M19 19 L5 5 M8.5 21 L3 15.5 M8.5 3 L3 8.5 M2 9 V15"
                }
            }
        }

        DIcon {
            visible: !(Form.reaver && (ctl.kind === "previous" || ctl.kind === "next"))
            anchors.centerIn: parent
            anchors.verticalCenterOffset: Form.reaver && ctl.main ? -3 : 0
            name: ctl.icon
            size: ctl.main ? (Form.reaver ? 18 : 30) : (Form.reaver ? 18 : 22)
            color: ctl.main && !Form.reaver ? Theme.primaryText : (Form.khaslana && ctl.on ? Theme.primaryText : ctl.ink)
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
                if (Form.reaver)
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
                    music.cycleLoop();
                    break;
                }
            }
        }
    }

    Row {
        spacing: 12

        // Cover: round paper in Phainon, a gold-edged plate in Khaslana, a lined slab in the Reaver
        ClippingRectangle {
            id: cover
            readonly property string art: music.player?.trackArtUrl ?? ""
            width: music.coverSize
            height: music.coverSize
            radius: Form.phainon || !Form.active ? 22 : (Form.khaslana ? 2 : 0)
            color: Theme.surfaceContainerHigh

            Image {
                id: coverImage
                anchors.fill: parent
                source: cover.art
                sourceSize: Qt.size(cover.width * 2, cover.height * 2)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }

            CfGlyph {
                visible: coverImage.status !== Image.Ready
                anchors.centerIn: parent
                name: Form.reaver ? "mask" : "ocean"
                size: 96
                strokeWidth: 1.2
                color: Theme.withAlpha(Form.reaver ? Theme.live : Theme.primary, 0.6)
            }

            Rectangle {
                visible: Form.khaslana || Form.reaver
                anchors.fill: parent
                anchors.margins: Form.reaver ? 2 : 0
                color: "transparent"
                border.width: 1
                border.color: Form.reaver ? Theme.withAlpha(Theme.live, 0.8) : Theme.primary
            }
        }

        Column {
            width: music.side
            spacing: 12

            // The two choosers: which player is heard, and through what
            Item {
                width: parent.width
                height: 30

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: music.tx("Listening from")
                        font.family: Form.reaver ? Theme.monoFontFamily : Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.withAlpha(Theme.surfaceText, 0.6)
                    }

                    Repeater {
                        model: MprisController.availablePlayers

                        Pick {
                            required property var modelData
                            anchors.verticalCenter: parent.verticalCenter
                            maxWidth: MprisController.availablePlayers.length > 1 ? 96 : 150
                            text: modelData.identity || "Player"
                            on: modelData === music.player
                            onClicked: MprisController.setActivePlayer(modelData)
                        }
                    }

                    StyledText {
                        visible: MprisController.availablePlayers.length === 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: Form.reaver ? "nothing." : "—"
                        font.family: Form.reaver ? Theme.monoFontFamily : Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.withAlpha(Theme.surfaceText, 0.45)
                    }
                }

                Pick {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    maxWidth: 170
                    icon: AudioService.sinkIcon(AudioService.sink)
                    text: AudioService.displayName(AudioService.sink) || "No output"
                    on: music.sinksOpen
                    onClicked: music.sinksOpen = !music.sinksOpen
                }
            }

            // Sound outputs, opened from the chooser above
            Column {
                visible: music.sinksOpen
                width: parent.width
                spacing: 4

                Repeater {
                    model: music.sinks

                    Item {
                        id: sinkRow
                        required property var modelData
                        readonly property bool current: modelData === AudioService.sink
                        width: parent.width
                        height: 32

                        CfSurface {
                            anchors.fill: parent
                            color: sinkMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                            edgeColor: sinkRow.current ? (Form.reaver ? Theme.live : Theme.primary) : Theme.withAlpha(Theme.outline, 0.4)
                            edgeWidth: Form.reaver && !sinkRow.current ? 0 : 1
                            lining: false
                            radius: 16
                        }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 12
                            spacing: 8

                            CfCrossToggle {
                                visible: Form.reaver
                                anchors.verticalCenter: parent.verticalCenter
                                checked: sinkRow.current
                                color: Theme.live
                                enabled: false
                                opacity: 1
                            }

                            DIcon {
                                visible: !Form.reaver
                                anchors.verticalCenter: parent.verticalCenter
                                name: AudioService.sinkIcon(sinkRow.modelData)
                                size: 16
                                color: sinkRow.current ? Theme.primary : Theme.withAlpha(Theme.surfaceText, 0.6)
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                width: sinkRow.width - 60
                                wrapMode: Text.NoWrap
                                // Outputs of one card differ only at the end ("… (HDMI 2)")
                                elide: Text.ElideMiddle
                                text: music.tx(AudioService.displayName(sinkRow.modelData))
                                font.family: Form.reaver ? Theme.monoFontFamily : Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: sinkRow.current ? Font.DemiBold : Font.Normal
                                color: Theme.surfaceText
                            }
                        }

                        MouseArea {
                            id: sinkMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                AudioService.setSink(sinkRow.modelData);
                                music.sinksOpen = false;
                            }
                        }
                    }
                }
            }

            // The full title, wrapped onto as many lines as it needs
            DashCard {
                width: parent.width
                height: titleColumn.implicitHeight + 38
                numeral: "I"
                glyph: "ocean"
                label: "Song"

                Column {
                    id: titleColumn
                    width: parent.width
                    spacing: 4

                    StyledText {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Form.phainon ? Text.AlignHCenter : Text.AlignLeft
                        text: music.player?.trackTitle || (Form.reaver ? "nothing." : "Nothing playing")
                        font.family: Form.reaver ? Theme.monoFontFamily : Form.display(Theme.fontFamily)
                        font.pixelSize: Form.reaver ? 20 : 24
                        font.weight: Font.DemiBold
                        color: Theme.surfaceText
                    }

                    StyledText {
                        visible: text !== ""
                        width: parent.width
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Form.phainon ? Text.AlignHCenter : Text.AlignLeft
                        text: [music.player?.trackArtist, music.player?.trackAlbum].filter(t => !!t).join(" · ")
                        font.family: Form.reaver ? Theme.monoFontFamily : Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        color: Form.reaver ? Theme.withAlpha(Theme.live, 0.9) : Theme.withAlpha(Theme.surfaceText, 0.7)
                    }
                }
            }

            // Controls and the seek bar
            DashCard {
                width: parent.width
                height: controls.implicitHeight + 28

                Column {
                    id: controls
                    width: parent.width
                    spacing: 14

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Form.phainon ? 14 : (Form.khaslana ? 8 : 16)

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

                        // Phainon: a thin lapis line with a small sun as its handle
                        Item {
                            id: sunSeek
                            visible: Form.phainon || !Form.active
                            anchors.fill: parent

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                x: 7
                                width: parent.width - 14
                                height: 2
                                radius: 1
                                color: Theme.withAlpha(Theme.primary, 0.2)

                                Rectangle {
                                    width: parent.width * music.progress
                                    height: parent.height
                                    radius: 1
                                    color: Theme.primary
                                }
                            }

                            Rectangle {
                                x: 7 + (parent.width - 14) * music.progress - width / 2
                                anchors.verticalCenter: parent.verticalCenter
                                width: 14
                                height: 14
                                radius: 7
                                color: "#E9B92E"
                                border.width: 3
                                border.color: Theme.withAlpha("#E9B92E", 0.3)
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: music.player?.canSeek ?? false
                                cursorShape: Qt.PointingHandCursor
                                function report(mouse) {
                                    music.seek(Math.max(0, Math.min(1, (mouse.x - 7) / (width - 14))));
                                }
                                onPressed: mouse => report(mouse)
                                onPositionChanged: mouse => {
                                    if (pressed)
                                        report(mouse);
                                }
                            }
                        }

                        // Khaslana: his blade
                        CfBlade {
                            visible: Form.khaslana
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            interactive: music.player?.canSeek ?? false
                            value: music.progress
                            onMoved: to => music.seek(to)
                        }

                        // Reaver: a scorched line with one ember for its head
                        CfScorch {
                            visible: Form.reaver
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            interactive: music.player?.canSeek ?? false
                            value: music.progress
                            onMoved: to => music.seek(to)
                        }
                    }

                    Item {
                        width: parent.width
                        height: 16

                        StyledText {
                            text: Chrono.format(Math.floor(music.player?.position ?? 0))
                            font.family: Form.phainon ? Theme.fontFamily : Theme.monoFontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.withAlpha(Theme.surfaceText, 0.6)
                        }

                        StyledText {
                            anchors.right: parent.right
                            text: Chrono.format(Math.floor(music.length))
                            font.family: Form.phainon ? Theme.fontFamily : Theme.monoFontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.withAlpha(Theme.surfaceText, 0.6)
                        }
                    }
                }
            }
        }
    }
}
