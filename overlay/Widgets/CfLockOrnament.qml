import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Common
import qs.Services
import "../Common/WidgetPlacement.js" as Placement

// The Coreflame lock screen: one composition per form, laid around DMS's own password box
// (centre of the screen) and notifications (just below it), which stay untouched.
//   Phainon      dawn. A paper-light sky, the time high up in serif, the sun rising on the
//                horizon inside the Oronyx dial, and Aedes Elysiae wheat along the foot.
//   Khaslana     Bearer of Chaos. A dark wash from the left, a huge time down the left side cut
//                by the three gold slashes of his wound, and the blocks of a breaking simulation.
//   Flame Reaver almost nothing. A near-black screen, a quiet lowercase ledger in the corner,
//                one violet mark, and a tally of every cycle this machine has lived.
// Nothing here animates; the clock updates once a minute.
Item {
    id: root

    property string screenName: ""
    property string backgroundKey: ""

    // "h" without an am/pm marker in the format prints 24-hour time, so format with it and drop it.
    readonly property string time: (clock.date?.toLocaleTimeString(Qt.locale(), SettingsData.use24HourClock ? "HH:mm" : "h:mm ap") ?? "").replace(/\s*[ap]\.?m\.?$/i, "")
    readonly property string ampm: SettingsData.use24HourClock ? "" : (clock.date?.toLocaleTimeString(Qt.locale(), "ap") ?? "")
    readonly property string day: clock.date?.toLocaleDateString(Qt.locale(), "dddd, d MMMM") ?? ""
    readonly property string period: Form.dawnPeriod(clock.date?.getHours() ?? 0)

    visible: Form.active

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // ── Phainon: dawn ──
    Item {
        id: dawn
        anchors.fill: parent
        visible: Form.phainon

        readonly property color gold: Theme.secondary
        readonly property color lapis: Theme.primary
        readonly property color ink: Theme.surfaceText
        readonly property real horizon: Math.round(height * 0.9)
        readonly property real sunSize: Math.round(Math.min(width, height) * 0.62)
        readonly property real inset: Math.round(width * 0.06)

        // Where the time goes: 0 top-centre (the default, kept on a tie or without a sample),
        // 1 top-left, 2 top-right, 3 centre-left. Picked from DMS's cached wallpaper sample.
        readonly property int spot: {
            const sample = Form.phainon ? LockPlacementService.sampleFor(root.screenName, root.backgroundKey) : null;
            const w = width, h = height;
            if (!sample || w <= 0 || h <= 0)
                return 0;
            // About the size of the block (the time and date scale with the height); centre-left only
            // when that clears DMS's password box in the middle of the screen.
            const bw = Math.round(Math.max(w * 0.3, h * 0.48)), bh = Math.round(h * 0.34), top = Math.round(h * 0.07);
            const spots = [[(w - bw) / 2, top], [inset, top], [w - inset - bw, top]];
            if (inset + bw < w / 2 - 210)
                spots.push([inset, (h - bh) / 2]);
            const rects = spots.map(p => ({
                        x: p[0],
                        y: p[1],
                        width: bw,
                        height: bh
                    }));
            const ink = [Placement.luminance(lapis.r, lapis.g, lapis.b)];
            // Own cache slot, so the stock clock placement for this screen is not overwritten.
            return LockPlacementService.layoutFor(root.screenName + "/coreflame", sample, JSON.stringify([w, h, ink]), (luma, sw, sh) => ({
                        spot: Math.max(0, rects.indexOf(Placement.choose(luma, sw, sh, w, h, rects, ink)))
                    })).spot ?? 0;
        }
        readonly property int align: spot === 0 ? 0 : (spot === 2 ? 1 : -1)

        function along(itemWidth, columnWidth) {
            return align < 0 ? 0 : (align > 0 ? columnWidth - itemWidth : Math.round((columnWidth - itemWidth) / 2));
        }

        // Paper sky: light at the top where the time sits, clear in the middle, warm at the horizon.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Theme.withAlpha(Theme.surface, 0.82)
                }
                GradientStop {
                    position: 0.36
                    color: Theme.withAlpha(Theme.surface, 0.18)
                }
                GradientStop {
                    position: 0.72
                    color: Theme.withAlpha(Theme.surface, 0.1)
                }
                GradientStop {
                    position: 1
                    color: Theme.withAlpha(dawn.gold, 0.5)
                }
            }
        }

        // The rising sun, mostly below the horizon, with the emblem's eight rays and the dial around it.
        Item {
            id: sun
            x: Math.round((parent.width - dawn.sunSize) / 2)
            y: Math.round(dawn.horizon - dawn.sunSize * 0.32)
            width: dawn.sunSize
            height: dawn.sunSize

            Repeater {
                model: 8

                Rectangle {
                    required property int index
                    anchors.centerIn: parent
                    width: index % 2 === 0 ? 3 : 2
                    height: dawn.sunSize * (index % 2 === 0 ? 2.1 : 1.6)
                    rotation: index * 22.5 - 90 + 11.25
                    radius: 2
                    color: Theme.withAlpha(dawn.gold, index % 2 === 0 ? 0.3 : 0.18)
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Theme.withAlpha("#FFF4D0", 0.95)
                    }
                    GradientStop {
                        position: 0.4
                        color: Theme.withAlpha(dawn.gold, 0.75)
                    }
                }
            }

            // The Oronyx dial: twelve marks, turned one step (30°) each hour.
            Item {
                anchors.centerIn: parent
                width: parent.width + 70
                height: width
                rotation: (clock.date?.getHours() ?? 0) % 12 * 30

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.withAlpha(dawn.lapis, 0.45)
                }

                Repeater {
                    model: 12

                    Item {
                        required property int index
                        anchors.fill: parent
                        rotation: index * 30

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: index === 0 ? 4 : 2
                            height: index === 0 ? 16 : 9
                            color: Theme.withAlpha(dawn.lapis, index === 0 ? 0.9 : 0.55)
                        }
                    }
                }
            }
        }

        // The field, misting up into the sky with no hard horizon line
        Rectangle {
            readonly property real rise: Math.round(dawn.height * 0.08)
            y: dawn.horizon - rise
            width: parent.width
            height: parent.height - y
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Theme.withAlpha(Theme.surface, 0)
                }
                GradientStop {
                    position: 0.55
                    color: Theme.withAlpha(Theme.surface, 0.4)
                }
                GradientStop {
                    position: 1
                    color: Theme.withAlpha(Theme.surface, 0.6)
                }
            }
        }

        // Aedes Elysiae
        CfWheat {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            width: parent.width
            height: Math.round(parent.height - dawn.horizon - 6)
            spacing: 14
            color: Theme.withAlpha(dawn.gold, 0.7)
        }

        Column {
            x: dawn.align < 0 ? dawn.inset : (dawn.align > 0 ? parent.width - dawn.inset - width : Math.round((parent.width - width) / 2))
            y: Math.round(dawn.spot === 3 ? (parent.height - height) / 2 : parent.height * 0.07)
            spacing: 6

            Row {
                x: dawn.along(width, parent.width)
                spacing: 12

                Text {
                    text: root.time
                    font.family: Form.numerals
                    font.pixelSize: Math.round(dawn.height * 0.15)
                    font.weight: Font.DemiBold
                    color: dawn.lapis
                }

                Text {
                    anchors.baseline: parent.children[0].baseline
                    text: root.ampm.toUpperCase()
                    font.family: Form.display(Theme.fontFamily)
                    font.pixelSize: Math.round(dawn.height * 0.035)
                    color: dawn.gold
                }
            }

            Text {
                x: dawn.along(width, parent.width)
                text: root.day
                font.family: Form.display(Theme.fontFamily)
                font.pixelSize: Math.round(dawn.height * 0.03)
                color: dawn.ink
            }

            Text {
                x: dawn.along(width, parent.width)
                text: "·  " + root.period.toUpperCase() + "  ·"
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(dawn.height * 0.016)
                font.letterSpacing: 4
                color: Theme.withAlpha(dawn.lapis, 0.85)
            }

            Item {
                width: 1
                height: 10
            }

            // The long lines in the pool wrap, kept clear of the password box (centre) and below.
            // On short screens, lines that would come within 7 px of the password box (top at
            // height/2 - 27) are cut. Not in the centre-left spot, which sits beside the box.
            Text {
                id: quote
                x: dawn.along(width, parent.width)
                // Natural width from the metrics: with elide on, implicitWidth follows width (a loop).
                width: Math.min(Math.ceil(quoteMetrics.advanceWidth(text)) + 1, Math.round(dawn.width * (dawn.align === 0 ? 0.5 : 0.3)))
                wrapMode: Text.WordWrap
                maximumLineCount: dawn.spot === 3 ? 99 : Math.max(1, Math.floor((dawn.height / 2 - 34 - parent.y - y) / quoteMetrics.height))
                elide: Text.ElideRight
                horizontalAlignment: dawn.align < 0 ? Text.AlignLeft : (dawn.align > 0 ? Text.AlignRight : Text.AlignHCenter)
                text: "“" + Form.quote + "”"
                font.family: Form.quoteFace(Theme.fontFamily)
                font.pixelSize: Form.quoteFont !== "" ? 22 : 18
                font.italic: true
                color: Theme.withAlpha(dawn.ink, 0.8)

                FontMetrics {
                    id: quoteMetrics
                    font: quote.font
                }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: dawn.horizon - height - 10

            Text {
                id: recurrenceLabel
                text: "ETERNAL RECURRENCE  "
                font.family: Theme.monoFontFamily
                font.pixelSize: 12
                font.letterSpacing: 3
                color: Theme.withAlpha(dawn.lapis, 0.75)
            }

            Text {
                anchors.baseline: recurrenceLabel.baseline
                text: Form.cycle
                font.family: Form.numerals
                font.pixelSize: 15
                font.letterSpacing: 1
                color: Theme.withAlpha(dawn.lapis, 0.75)
            }
        }
    }

    // ── Khaslana: Bearer of Chaos ──
    Item {
        id: bearer
        anchors.fill: parent
        visible: Form.khaslana

        readonly property color gold: Theme.primary
        readonly property color wound: Theme.error
        readonly property color ink: "#F5F6E6"
        readonly property real inset: Math.round(width * 0.065)

        // The "Ignite That Primal Sun" mural behind everything, softened (it is only 1000 px wide).
        // Game art, so it lives outside the repo; without the file the wallpaper shows as before.
        Image {
            anchors.fill: parent
            visible: status === Image.Ready
            source: Form.khaslana ? "file://" + Form.stateDir + "/cinematics/khaslana-mural.png" : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            layer.enabled: visible
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 0.35
                blurMax: 32
            }
        }

        // Dark from the left, where the words stand; the wallpaper shows through on the right.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: Qt.rgba(0.02, 0.03, 0.08, 0.92)
                }
                GradientStop {
                    position: 0.38
                    color: Qt.rgba(0.02, 0.03, 0.08, 0.62)
                }
                GradientStop {
                    position: 1
                    color: Qt.rgba(0.02, 0.03, 0.08, 0.2)
                }
            }
        }

        // The gold rule the column hangs from
        Rectangle {
            x: bearer.inset - 26
            y: column.y - 18
            width: 4
            height: column.height + 36
            color: bearer.gold
        }

        Column {
            id: column
            x: bearer.inset
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Text {
                text: "KHASLANA  //  " + Form.epithet.toUpperCase()
                font.family: Theme.monoFontFamily
                font.pixelSize: 14
                font.letterSpacing: 5
                color: bearer.gold
            }

            Item {
                width: timeText.contentWidth
                height: timeText.contentHeight

                // As large as the left third allows, so it never reaches the password box at the centre.
                Text {
                    id: timeText
                    width: Math.round(bearer.width * 0.34) - bearer.inset
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: 40
                    text: root.time
                    font.family: Form.numerals
                    font.pixelSize: Math.round(bearer.height * 0.24)
                    font.weight: Font.Bold
                    color: bearer.ink
                }

                // The wound: three gold slashes through the hour
                Repeater {
                    model: 3

                    Item {
                        required property int index
                        x: timeText.contentWidth * 0.2 + index * 26
                        y: timeText.contentHeight * 0.42 + index * 14
                        width: timeText.contentWidth * 0.75
                        height: 9
                        rotation: -24

                        Rectangle {
                            x: 3
                            y: 3
                            width: parent.width
                            height: 4
                            color: Theme.withAlpha(bearer.wound, 0.75)
                        }

                        Rectangle {
                            width: parent.width
                            height: 4
                            color: "#FBD865"
                        }
                    }
                }
            }

            Text {
                text: (root.ampm !== "" ? root.ampm.toUpperCase() + "  //  " : "") + root.day.toUpperCase() + "  //  " + root.period.toUpperCase()
                font.family: Theme.monoFontFamily
                font.pixelSize: 15
                font.letterSpacing: 2
                color: Theme.withAlpha(bearer.ink, 0.85)
            }

            Item {
                width: 1
                height: 18
            }

            Text {
                width: Math.round(bearer.width * 0.3)
                wrapMode: Text.WordWrap
                text: Form.quote
                font.family: Form.quoteFace(Theme.fontFamily)
                font.pixelSize: Form.quoteFont !== "" ? 24 : 20
                font.italic: true
                color: bearer.ink
            }

            Row {
                Text {
                    id: cycleLabel
                    text: "CYCLE "
                    font.family: Theme.monoFontFamily
                    font.pixelSize: 12
                    font.letterSpacing: 3
                    color: Theme.withAlpha(bearer.gold, 0.85)
                }

                Text {
                    anchors.baseline: cycleLabel.baseline
                    text: Form.cycle
                    font.family: Form.numerals
                    font.pixelSize: 15
                    font.letterSpacing: 1
                    color: Theme.withAlpha(bearer.gold, 0.85)
                }

                Text {
                    text: "  //  THE EMBERS REFUSE TO SLEEP"
                    font: cycleLabel.font
                    color: cycleLabel.color
                }
            }
        }

        // The simulation breaking: displaced blocks around the column and at the far edge
        Repeater {
            // Kept to the screen edges, clear of the words and of DMS's widgets.
            model: [[0.012, 0.16, 30, 8, 1], [0.02, 0.2, 10, 10, 0], [0.015, 0.8, 52, 5, 0], [0.03, 0.84, 12, 12, 2], [0.955, 0.08, 40, 7, 0], [0.97, 0.12, 12, 12, 1], [0.94, 0.9, 64, 5, 2], [0.965, 0.86, 18, 9, 0]]

            Rectangle {
                required property var modelData
                x: Math.round(modelData[0] * bearer.width)
                y: Math.round(modelData[1] * bearer.height)
                width: modelData[2]
                height: modelData[3]
                color: modelData[4] === 0 ? bearer.gold : (modelData[4] === 1 ? Theme.withAlpha(bearer.wound, 0.85) : Qt.rgba(1, 1, 1, 0.45))
            }
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: Math.round(bearer.width * 0.03)
            y: Math.round(bearer.height * 0.04)
            text: "[ SIMULATION  ·  DESTABILISED ]"
            font.family: Theme.monoFontFamily
            font.pixelSize: 12
            font.letterSpacing: 3
            color: Theme.withAlpha(bearer.wound, 0.9)
        }
    }

    // ── Flame Reaver: the ledger ──
    Item {
        id: ledger
        anchors.fill: parent
        visible: Form.reaver

        readonly property color dim: Qt.rgba(0.78, 0.79, 0.86, 0.45)
        readonly property color ink: Qt.rgba(0.86, 0.86, 0.84, 0.9)
        readonly property var lines: [["time", (root.time + " " + root.ampm).trim()], ["date", root.day], ["hour", root.period], ["cycle", Form.cycleText], ["state", "locked."]]

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.05, 0.05, 0.06, 0.86)
        }

        // The one violet mark
        Rectangle {
            x: 52
            y: entries.y + 4
            width: 2
            height: entries.height - 8
            color: Theme.live
        }

        Column {
            id: entries
            x: 72
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 72
            spacing: 6

            Repeater {
                model: ledger.lines

                Row {
                    required property var modelData

                    Text {
                        width: 120
                        text: "// " + modelData[0]
                        font.family: Theme.monoFontFamily
                        font.pixelSize: 16
                        color: ledger.dim
                    }

                    Text {
                        text: String(modelData[1]).toLowerCase()
                        font.family: Theme.monoFontFamily
                        font.pixelSize: 16
                        color: ledger.ink
                    }
                }
            }

            Item {
                width: 1
                height: 10
            }

            Text {
                text: "> " + Form.quote.toLowerCase()
                font.family: Theme.monoFontFamily
                font.pixelSize: 16
                color: Theme.live
            }
        }

        // One stroke for every cycle this machine has lived, struck through in fives
        Grid {
            anchors.right: parent.right
            anchors.rightMargin: 72
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 78
            columns: 8
            spacing: 12

            Repeater {
                model: Math.min(40, Math.ceil(Form.boots / 5))

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
                            color: ledger.dim
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
}
