import QtQuick
import QtQuick.Shapes
import QtQuick.Window
import qs.Common
import qs.Services
import qs.Widgets
import "Threads.js" as Threads

// "Romance · Messages": every notification, live or saved, grouped by app with the app's own
// buttons; dismiss one, a whole app, or all of them; do not disturb at the foot.
//   Phainon: a paper card per app, round chips, a soft pill switch.
//   Khaslana: heralds on obsidian blocks two to a row, flame marks, cut plates, a red foot block.
//   Flame Reaver: a shard per app in two columns, lower case, the two swords for do not disturb.
DashSheet {
    id: view

    readonly property var threads: Threads.merge(NotificationService.groupedNotifications, NotificationService.historyList)
    // The ages ("2m") move with the service's own minute tick
    readonly property real now: {
        NotificationService.timeUpdateTick;
        return Date.now();
    }
    readonly property int gap: kh ? 5 : (ph ? 12 : 14)
    readonly property int footH: ph ? 34 : (kh ? 46 : 64)
    // DashCard's caption above the notes and margin below them, per form
    readonly property int pad: ph ? 40 : (kh ? 37 : 52)
    readonly property var cards: layout(threads)
    readonly property real contentH: cards.length > 0 ? Math.max(...cards.map(c => c.y + c.h)) : 150
    readonly property real listH: Math.min(contentH, 520 - gap - footH)
    readonly property color rule: ph ? "#ECE3CC" : (kh ? "#3A1A1E" : "#2C2840")
    // the mockup's .dv-p1 .dv-p2 .dv-p4 .dv-p3 shards, in turn
    readonly property var shards: [[[0, 0], [1, 0.03], [0.97, 1], [0.02, 0.94]], [[0.04, 0], [1, 0], [0.96, 1], [0, 0.88]], [[0, 0.06], [1, 0], [0.98, 1], [0.03, 0.95]], [[0.03, 0], [1, 0], [1, 0.92], [0, 1]]]

    // Fixed heights (one line of body) so Khaslana's blocks can be laid out from the data
    function noteH(n) {
        return 34 + (n.body ? 20 : 0) + (n.actions.length > 0 ? 30 : 0);
    }

    function cardH(t) {
        return pad + t.notes.reduce((s, n) => s + noteH(n), 0);
    }

    // [{x, y, w, h, t, poly}] in list coordinates
    function layout(list) {
        const out = [];
        if (ph) {
            let y = 0;
            for (const t of list) {
                out.push({
                    x: 0,
                    y: y,
                    w: bodyWidth,
                    h: cardH(t),
                    t: t
                });
                y += cardH(t) + gap;
            }
        } else if (kh) {
            // two heralds to a row, the last alone across the whole row
            let y = 0;
            for (let i = 0; i < list.length; i += 2) {
                const pair = list.slice(i, i + 2);
                const h = Math.max(...pair.map(cardH));
                pair.forEach((t, j) => out.push({
                        x: colX(2 * j),
                        y: y,
                        w: spanW(pair.length > 1 ? 2 : 4),
                        h: h,
                        t: t
                    }));
                y += h + gap;
            }
        } else {
            // each shard under the shorter column
            const col = [0, 0];
            for (const t of list) {
                const c = col[1] < col[0] ? 1 : 0;
                out.push({
                    x: c ? 394 : 0,
                    y: col[c],
                    w: c ? 386 : 380,
                    h: cardH(t),
                    t: t,
                    poly: shards[out.length % 4]
                });
                col[c] += cardH(t) + gap;
            }
        }
        return out;
    }

    // Khaslana's blocks under the cards in sight, then the red foot block
    function khBlocks() {
        const out = [];
        for (const c of cards) {
            const y0 = Math.max(0, c.y - list.contentY), y1 = Math.min(listH, c.y + c.h - list.contentY);
            if (y1 > y0)
                out.push([c.x, y0, c.w, y1 - y0, false]);
        }
        if (cards.length === 0)
            out.push([0, 0, bodyWidth, listH, false]);
        out.push([0, listH + gap, bodyWidth, footH, true]);
        return out;
    }

    // A live one is also in the saved history: drop both so it does not come back as saved
    function dismiss(n) {
        if (n.wrapper)
            NotificationService.permanentlyDismissNotification(n.wrapper);
        else
            NotificationService.removeFromHistory(n.id);
    }

    function clearApp(t) {
        t.historyIds.forEach(id => NotificationService.removeFromHistory(id));
        NotificationService.dismissGroup(t.key);
    }

    function clearAll() {
        NotificationService.clearAllNotifications();
        NotificationService.clearHistory();
    }

    function open(n) {
        Form.openNotification(n.wrapper ?? n.entry);
        view.Window.window?.close?.();
    }

    title: "Romance · Messages"
    glyph: "romance"
    bodyHeight: listH + gap + footH
    blocks: kh ? khBlocks() : []
    Component.onCompleted: NotificationService.markNotificationsSeen()

    CfInk {
        id: ink
    }

    // An action pill (Phainon), cut plate (Khaslana) or bracket (Flame Reaver); `strong` is
    // Khaslana's red plate for Clear all
    component Chip: Item {
        id: chip

        property string label: ""
        property bool strong: false
        readonly property bool plate: view.kh && strong
        signal clicked

        implicitWidth: chipText.implicitWidth + (plate ? 32 : 28)
        implicitHeight: plate ? 34 : 26
        opacity: enabled ? 1 : 0.4

        Rectangle {
            visible: view.ph || chip.plate
            anchors.fill: parent
            radius: view.ph ? height / 2 : 0
            color: chip.plate ? "#8E1424" : (chipMouse.containsMouse ? "#F1EAD6" : "#FBF9F3")
            border.width: 1
            border.color: chip.plate ? "#F2C75C" : "#C8B27E"
        }

        Shape {
            visible: view.kh && !chip.plate
            anchors.fill: parent

            ShapePath {
                strokeColor: "#E0B04A"
                strokeWidth: 1
                fillColor: chipMouse.containsMouse ? "#2A1015" : "transparent"
                PathPolyline {
                    path: [Qt.point(0.5, 0.5), Qt.point(chip.width - 0.5, 0.5), Qt.point(chip.width - 0.5, chip.height * 0.68), Qt.point(chip.width - 8, chip.height - 0.5), Qt.point(0.5, chip.height - 0.5), Qt.point(0.5, 0.5)]
                }
            }
        }

        Rectangle {
            visible: view.rv
            anchors.fill: parent
            color: "transparent"
            border.width: 1
            border.color: chipMouse.containsMouse ? "#8F7BE0" : "#5C5478"

            Rectangle {
                width: 3
                height: parent.height
                color: parent.border.color
            }
        }

        Text {
            id: chipText
            anchors.centerIn: parent
            text: view.kh ? chip.label.toUpperCase() : ink.tx(chip.label)
            font.family: view.kh ? "Cinzel" : ink.font
            font.pixelSize: view.kh ? (chip.plate ? 13 : 12) : 13
            font.weight: view.kh ? Font.DemiBold : Font.Normal
            font.letterSpacing: view.kh ? 1.8 : 0
            color: view.ph ? "#334786" : (view.kh ? "#F5D27A" : (chipMouse.containsMouse ? "#E9E7F2" : "#A8A4BC"))
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    // One message: summary, age and ×, one line of body, the app's buttons
    component Note: Item {
        id: note

        required property var modelData

        height: view.noteH(modelData)

        // Click anywhere on the message to open it (the buttons and × keep their own clicks)
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: view.open(note.modelData)
        }

        Rectangle {
            width: parent.width
            height: 1
            color: view.rule
        }

        Row {
            y: 8
            width: parent.width - stamp.width - 10
            spacing: 6

            // Khaslana: a flame mark before each message (the mockup's #flame)
            Shape {
                visible: view.kh
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: "#E2434E"
                    strokeWidth: 1.2
                    fillColor: "transparent"
                    joinStyle: ShapePath.RoundJoin
                    scale: Qt.size(16 / 24, 16 / 24)
                    PathSvg {
                        path: "M12 3c1 4 6 6 6 11a6 6 0 0 1-12 0c0-3 2-4 2-7 2 1 3 3 3 5 1-2 1-6 1-9z"
                    }
                }
            }

            Text {
                width: parent.width - (view.kh ? 22 : 0)
                elide: Text.ElideRight
                text: ink.tx(note.modelData.summary || "")
                font.family: ink.font
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: ink.text
            }
        }

        Row {
            id: stamp
            anchors.right: parent.right
            y: 10
            spacing: 6

            Text {
                text: Threads.age(note.modelData.time, view.now)
                font.family: ink.font
                font.pixelSize: 12
                color: ink.muted
            }

            Text {
                text: "×"
                font.pixelSize: 14
                color: ink.muted

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -5
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.dismiss(note.modelData)
                }
            }
        }

        Text {
            visible: !!note.modelData.body
            y: 30
            width: parent.width
            elide: Text.ElideRight
            maximumLineCount: 1
            textFormat: Text.PlainText
            text: ink.tx(String(note.modelData.body || "").replace(/\s+/g, " "))
            font.family: ink.font
            font.pixelSize: 13
            color: ink.muted
        }

        Row {
            y: note.modelData.body ? 52 : 32
            spacing: 8

            Repeater {
                model: note.modelData.actions

                Chip {
                    required property var modelData
                    label: modelData.text
                    onClicked: modelData.invoke()
                }
            }
        }
    }

    // Nothing waiting
    Column {
        visible: view.threads.length === 0
        anchors.horizontalCenter: list.horizontalCenter
        y: Math.round((view.listH - height) / 2)
        spacing: 12

        CfSigil {
            visible: !view.rv
            anchors.horizontalCenter: parent.horizontalCenter
            size: 54
            lit: 0
            litColor: ink.icon
            dimColor: ink.icon
        }

        CfGlyph {
            visible: view.rv
            anchors.horizontalCenter: parent.horizontalCenter
            name: "mask"
            size: 44
            strokeWidth: 1.4
            color: "#8F7BE0"
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: view.ph ? "All quiet in Okhema." : (view.kh ? "No threads pull at you." : "nothing.")
            font.family: view.ph ? "Marcellus" : (view.kh ? "Cinzel" : "Chakra Petch")
            font.pixelSize: 16
            color: ink.muted
        }
    }

    Flickable {
        id: list
        width: view.bodyWidth
        height: view.listH
        contentWidth: width
        contentHeight: view.contentH
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Repeater {
            model: view.cards

            DashCard {
                id: card

                required property var modelData
                readonly property var thread: modelData.t

                x: modelData.x
                y: modelData.y
                width: modelData.w
                height: modelData.h
                bare: view.kh
                flute: false
                poly: modelData.poly ?? null
                glyph: "romance"
                label: (thread.appName || "Unknown") + " · " + thread.notes.length

                Text {
                    anchors.right: parent.right
                    y: -16
                    text: view.rv ? "CLEAR" : (view.kh ? "clear app" : "Clear app")
                    font.family: view.rv ? "Chakra Petch" : ink.font
                    font.pixelSize: view.ph ? 13 : 12
                    font.weight: view.rv ? Font.DemiBold : Font.Normal
                    font.letterSpacing: view.rv ? 1.7 : 0
                    color: ink.muted

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.clearApp(card.thread)
                    }
                }

                Column {
                    width: parent.width

                    Repeater {
                        model: card.thread.notes

                        Note {
                            width: card.width - 2 * (view.rv ? 26 : 15)
                        }
                    }
                }
            }
        }
    }

    // ── the foot: do not disturb, clear all ──
    Item {
        y: view.listH + view.gap
        width: view.bodyWidth
        height: view.footH

        DashCard {
            visible: view.rv
            anchors.fill: parent
            poly: [[0.02, 0.04], [1, 0], [0.97, 0.96], [0, 1]]
        }

        Row {
            x: view.rv ? 30 : (view.kh ? 15 : 4)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            // Phainon: a soft pill switch
            Rectangle {
                visible: view.ph
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                height: 22
                radius: 11
                color: SessionData.doNotDisturb ? "#334786" : "#E4DAC0"

                Rectangle {
                    x: SessionData.doNotDisturb ? parent.width - width - 3 : 3
                    y: 3
                    width: 16
                    height: 16
                    radius: 8
                    color: "#FBF9F3"
                    border.width: 1
                    border.color: "#C8B27E"
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SessionData.setDoNotDisturb(!SessionData.doNotDisturb)
                }
            }

            // Khaslana: an Off/On plate pair, the chosen plate red
            Row {
                visible: view.kh
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: [false, true]

                    Rectangle {
                        required property bool modelData
                        readonly property bool picked: SessionData.doNotDisturb === modelData
                        width: plateText.implicitWidth + 24
                        height: 24
                        color: picked ? "#8E1424" : "transparent"
                        border.width: 1
                        border.color: "#E0B04A"

                        Text {
                            id: plateText
                            anchors.centerIn: parent
                            text: parent.modelData ? "ON" : "OFF"
                            font.family: "Cinzel"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1.5
                            color: parent.picked ? "#F5D27A" : "#C9B89E"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: SessionData.setDoNotDisturb(parent.modelData)
                        }
                    }
                }
            }

            // The Flame Reaver's swords cross when the world is shut out
            CfCrossToggle {
                visible: view.rv
                anchors.verticalCenter: parent.verticalCenter
                checked: SessionData.doNotDisturb
                color: "#B9A8FF"
                offColor: "#5C5478"
                onToggled: on => SessionData.setDoNotDisturb(on)
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: view.rv ? "do not disturb · " + (SessionData.doNotDisturb ? "on" : "off") : (view.kh ? "DO NOT DISTURB" : "Do not disturb")
                font.family: view.kh ? "Cinzel" : ink.font
                font.pixelSize: view.ph ? 14 : (view.kh ? 12 : 13)
                font.weight: view.kh ? Font.DemiBold : Font.Normal
                font.letterSpacing: view.kh ? 2.6 : 0
                color: view.kh ? "#E0B04A" : (view.rv ? ink.muted : ink.text)
                style: view.kh ? Text.Outline : Text.Normal
                styleColor: "#0B080B"
            }
        }

        Chip {
            anchors.right: parent.right
            anchors.rightMargin: view.rv ? 30 : (view.kh ? 15 : 4)
            anchors.verticalCenter: parent.verticalCenter
            label: "Clear all"
            strong: true
            enabled: view.threads.length > 0
            onClicked: view.clearAll()
        }
    }
}
