import QtQuick
import Quickshell
import qs.Common

// The Coreflame lock screen layout. The time sits inside an eclipsed sun, taken from his
// technique "Beginning of the End"; DMS's own password handling stays underneath, untouched.
//   Phainon      the eclipse is ending: eight rays show around the disc.
//   Khaslana     three gold slashes cross the ring, for the wound he left on Nanook, with the
//                displaced blocks of a simulation breaking.
//   Flame Reaver thorns grip a dark disc, a violet flame rises from it, and tally marks at the
//                bottom count the cycles this machine has lived.
Item {
    id: root

    readonly property color ink: "#F5F6E6"
    readonly property color accent: Form.reaver ? Theme.live : Theme.secondary
    readonly property real d: Math.round(Math.min(width, height) * 0.5)

    visible: Form.active

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Item {
        id: sun
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.46 - root.d * 0.5)
        width: root.d
        height: root.d

        // Phainon: rays
        // Four bars through the centre give the emblem's eight rays: long on the cardinals, short between.
        Repeater {
            model: Form.phainon ? 4 : 0

            Rectangle {
                required property int index
                anchors.centerIn: parent
                width: 3
                height: root.d * (index % 2 === 0 ? 1.44 : 1.2)
                rotation: index * 45
                radius: 2
                color: Theme.withAlpha(root.accent, index % 2 === 0 ? 0.6 : 0.35)
            }
        }

        // Flame Reaver: thorns and the violet flame
        Repeater {
            model: Form.reaver ? 10 : 0

            Item {
                required property int index
                anchors.centerIn: parent
                width: 4
                height: root.d + 46
                rotation: [200, 222, 240, 258, 280, 300, 60, 84, 108, 130][index]

                Rectangle {
                    width: 4
                    height: 23 + (index % 3) * 9
                    color: Theme.withAlpha("#787870", 0.85)
                }
            }
        }

        Repeater {
            model: Form.reaver ? 3 : 0

            Rectangle {
                required property int index
                x: parent.width / 2 - 6 + index * 9
                y: -34 - index * 16
                width: 12 - index * 3
                height: 56 - index * 10
                radius: 6
                rotation: -14 + index * 16
                color: Theme.withAlpha(Theme.live, 0.5 - index * 0.12)
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 48
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 24
            border.color: Theme.withAlpha(root.accent, 0.09)
        }

        Rectangle {
            id: disc
            anchors.fill: parent
            radius: width / 2
            color: Qt.rgba(0, 0, 0, Form.reaver ? 0.78 : 0.6)
            border.width: Form.reaver ? 1 : 2
            border.color: Form.reaver ? "#787870" : root.accent
        }

        // Khaslana: the wound, and what broke around it
        Repeater {
            model: Form.khaslana ? 3 : 0

            Item {
                required property int index
                x: root.d * 0.52 + index * 17
                y: -22 + index * 30
                width: root.d * 0.6
                height: 8
                rotation: 38

                Rectangle {
                    x: 3
                    y: 3
                    width: parent.width
                    height: 3
                    color: Theme.withAlpha(Theme.error, 0.7)
                }

                Rectangle {
                    width: parent.width
                    height: 3
                    color: "#FBD865"
                }
            }
        }

        Repeater {
            model: Form.khaslana ? [[-0.08, 0.72, 12, 6, 0], [-0.03, 0.8, 6, 6, 1], [-0.1, 0.86, 18, 4, 0], [0.02, 0.9, 5, 5, 2], [0.98, 0.12, 10, 5, 1], [1.04, 0.2, 6, 6, 0], [1.0, 0.27, 14, 3, 0]] : []

            Rectangle {
                required property var modelData
                x: modelData[0] * root.d
                y: modelData[1] * root.d
                width: modelData[2]
                height: modelData[3]
                color: modelData[4] === 0 ? "#D4B14A" : (modelData[4] === 1 ? Theme.withAlpha(Theme.error, 0.85) : Qt.rgba(1, 1, 1, 0.4))
            }
        }

        // The time sits above the password field (which DMS places at the centre of the screen);
        // the date and the Dawn Device's hour sit below it.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(root.d * 0.13)
            text: clock.date?.toLocaleTimeString(Qt.locale(), SettingsData.use24HourClock ? "HH:mm" : "h:mm") ?? ""
            font.family: Form.display(Theme.fontFamily)
            font.pixelSize: Math.round(root.d * 0.24)
            font.weight: Font.DemiBold
            color: root.ink
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(root.d * 0.68)
            spacing: 4

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    const day = clock.date?.toLocaleDateString(Qt.locale(), "dddd, d MMMM") ?? "";
                    return Form.reaver ? day.toLowerCase() : day;
                }
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(root.d * 0.045)
                color: Qt.rgba(0.96, 0.96, 0.9, 0.85)
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    const period = Form.dawnPeriod(clock.date?.getHours() ?? 0);
                    return Form.reaver ? period.toLowerCase() : period.toUpperCase();
                }
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(root.d * 0.032)
                font.letterSpacing: 2.5
                color: root.accent
            }
        }
    }

    // The form's words, and the count
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(sun.y + root.d + 26)
        spacing: 8

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "“" + (Form.reaver ? Form.quote.toLowerCase() : Form.quote) + "”"
            font.family: Form.quoteFace(Theme.fontFamily)
            font.pixelSize: Form.quoteFont !== "" ? 21 : 17
            font.italic: !Form.reaver
            color: Qt.rgba(0.96, 0.96, 0.9, 0.88)
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: (Form.reaver ? "eternal recurrence " : "ETERNAL RECURRENCE ") + Form.cycleText
            font.family: Theme.monoFontFamily
            font.pixelSize: 12
            font.letterSpacing: 2
            color: Qt.rgba(0.96, 0.96, 0.9, 0.55)
        }
    }

    // Flame Reaver: one stroke for every cycle this machine has lived, struck through in fives
    Row {
        visible: Form.reaver
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.9)
        spacing: 12

        Repeater {
            model: Form.reaver ? Math.min(24, Math.ceil(Form.boots / 5)) : 0

            Item {
                required property int index
                readonly property int strokes: Math.min(5, Form.boots - index * 5)
                width: 26
                height: 18

                Repeater {
                    model: Math.min(4, parent.strokes)

                    Rectangle {
                        required property int index
                        x: index * 6 + 2
                        width: 2
                        height: 18
                        color: Qt.rgba(0.78, 0.79, 0.86, 0.5)
                    }
                }

                Rectangle {
                    visible: parent.strokes === 5
                    anchors.centerIn: parent
                    width: 30
                    height: 2
                    rotation: -28
                    color: Theme.withAlpha(Theme.live, 0.8)
                }
            }
        }
    }
}
