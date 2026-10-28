import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets as DW

// The month, with the days that hold events marked. Picking a day lists its events (view only).
// Events come from Evolution Data Server (GNOME Calendar's store) through calendar-events.py,
// read only while the dashboard is open: on open, on a month change, then every ten minutes.
DashCard {
    id: cal

    // The dashboard is open; nothing is read while it is closed.
    property bool live: false
    property date now: new Date()
    property date month: new Date(now.getFullYear(), now.getMonth(), 1)
    property date selected: now
    property var events: []
    readonly property date first: new Date(month.getFullYear(), month.getMonth(), 1 - month.getDay())
    // "y-m-d" of every day in the grid that holds at least one event
    readonly property var marks: {
        const out = {};
        for (const ev of events) {
            const s = parse(ev.start);
            const e = parse(ev.end);
            for (let d = new Date(s.getFullYear(), s.getMonth(), s.getDate()), n = 0; n < 42 && (d < e || n === 0); d.setDate(d.getDate() + 1), n++)
                out[key(d)] = true;
        }
        return out;
    }
    readonly property var dayEvents: {
        const from = new Date(selected.getFullYear(), selected.getMonth(), selected.getDate());
        const to = new Date(from.getFullYear(), from.getMonth(), from.getDate() + 1);
        return events.filter(ev => {
            const s = parse(ev.start);
            const e = parse(ev.end);
            return s < to && (e > from || s >= from);
        });
    }

    numeral: "III"
    glyph: "time"
    label: "Time · Calendar"

    function tx(text) {
        return Form.reaver ? String(text).toLowerCase() : text;
    }

    function key(d) {
        return d.getFullYear() + "-" + d.getMonth() + "-" + d.getDate();
    }

    // All-day events come as plain dates, which must be read as local days, not UTC midnight.
    function parse(s) {
        const m = String(s).match(/^(\d{4})-(\d{2})-(\d{2})$/);
        return m ? new Date(parseInt(m[1]), parseInt(m[2]) - 1, parseInt(m[3])) : new Date(s);
    }

    function iso(d) {
        return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
    }

    function fetch() {
        if (!live)
            return;
        // A month turned while a read is still running: read again once it ends.
        if (reader.running) {
            reader.again = true;
            return;
        }
        reader.command = ["python3", "-I", decodeURIComponent(String(Qt.resolvedUrl("../../assets/coreflame/calendar-events.py")).replace("file://", "")), iso(first), iso(new Date(first.getFullYear(), first.getMonth(), first.getDate() + 42))];
        reader.running = true;
    }

    function shift(by) {
        month = new Date(month.getFullYear(), month.getMonth() + by, 1);
    }

    onLiveChanged: fetch()
    onMonthChanged: fetch()
    Component.onCompleted: fetch()

    Process {
        id: reader
        property bool again: false
        onExited: {
            if (again) {
                again = false;
                cal.fetch();
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const list = JSON.parse(text);
                    cal.events = Array.isArray(list) ? list : [];
                } catch (e) {
                    cal.events = [];
                }
            }
        }
    }

    Timer {
        interval: 600000
        repeat: true
        running: cal.live
        onTriggered: cal.fetch()
    }

    Column {
        anchors.fill: parent
        spacing: 4

        Item {
            width: parent.width
            height: 22

            StyledText {
                anchors.centerIn: parent
                text: cal.tx(cal.month.toLocaleDateString(I18n.locale(), "MMMM yyyy"))
                font.family: Form.reaver ? Theme.monoFontFamily : Theme.fontFamily
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.DemiBold
                color: Theme.surfaceText
            }

            Repeater {
                model: [-1, 1]

                DW.DIcon {
                    required property int modelData
                    anchors.left: modelData < 0 ? parent.left : undefined
                    anchors.right: modelData > 0 ? parent.right : undefined
                    anchors.verticalCenter: parent.verticalCenter
                    name: modelData < 0 ? "chevron_left" : "chevron_right"
                    size: 22
                    color: Form.reaver ? Theme.live : Theme.primary

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cal.shift(parent.modelData)
                    }
                }
            }
        }

        Grid {
            id: days
            readonly property real cell: Math.floor(parent.width / 7)
            anchors.horizontalCenter: parent.horizontalCenter
            columns: 7

            Repeater {
                model: 7

                StyledText {
                    required property int index
                    width: days.cell
                    height: 18
                    horizontalAlignment: Text.AlignHCenter
                    text: cal.tx(new Date(2023, 0, 1 + index).toLocaleDateString(I18n.locale(), "ddd"))
                    font.family: Form.reaver ? Theme.monoFontFamily : Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.withAlpha(Theme.surfaceText, 0.55)
                }
            }

            Repeater {
                model: 42

                Item {
                    id: day
                    required property int index
                    readonly property date when: new Date(cal.first.getFullYear(), cal.first.getMonth(), cal.first.getDate() + index)
                    readonly property bool inMonth: when.getMonth() === cal.month.getMonth()
                    readonly property bool today: when.toDateString() === cal.now.toDateString()
                    readonly property bool picked: when.toDateString() === cal.selected.toDateString()
                    readonly property bool marked: !!cal.marks[cal.key(when)]
                    width: days.cell
                    height: 28

                    // Today: Phainon's sun, Khaslana's diamond. The Flame Reaver underlines it instead.
                    Rectangle {
                        visible: (day.today && !Form.reaver) || (day.picked && !day.today)
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        radius: Form.phainon || !Form.active ? 12 : 0
                        rotation: Form.khaslana ? 45 : 0
                        color: day.today ? (Form.phainon ? "#E9B92E" : Theme.primary) : "transparent"
                        border.width: day.today ? 0 : 1.5
                        border.color: Form.reaver ? Theme.live : Theme.primary
                    }

                    StyledText {
                        id: num
                        anchors.centerIn: parent
                        text: day.when.getDate()
                        font.family: Form.reaver ? Theme.monoFontFamily : Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: day.today ? Font.DemiBold : Font.Normal
                        font.underline: Form.reaver && day.today
                        // The Flame Reaver strikes out the days already spent.
                        font.strikeout: Form.reaver && day.inMonth && !day.today && day.when < cal.now
                        color: day.today ? (Form.reaver ? Theme.live : Theme.primaryText) : Theme.withAlpha(Theme.surfaceText, day.inMonth ? 0.95 : 0.3)
                    }

                    // A day that holds events: a dot, a small diamond, or an ember.
                    Rectangle {
                        visible: day.marked
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Form.khaslana ? 0 : 1
                        width: 4
                        height: 4
                        radius: Form.phainon || !Form.active ? 2 : 0
                        rotation: Form.khaslana ? 45 : 0
                        color: Form.reaver ? Theme.live : (day.today && !Form.phainon ? Theme.primaryText : Theme.primary)
                        opacity: day.inMonth ? 1 : 0.4
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cal.selected = day.when
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Form.reaver ? Theme.withAlpha(Theme.live, 0.35) : Theme.withAlpha(Theme.outline, 0.35)
        }

        StyledText {
            width: parent.width
            text: cal.tx(cal.selected.toLocaleDateString(I18n.locale(), "dddd d MMMM"))
            font.family: Form.reaver ? Theme.monoFontFamily : Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.DemiBold
            color: Theme.withAlpha(Theme.surfaceText, 0.65)
        }

        ListView {
            width: parent.width
            height: parent.height - y
            clip: true
            spacing: 2
            model: cal.dayEvents
            boundsBehavior: Flickable.StopAtBounds

            delegate: Row {
                required property var modelData
                width: ListView.view.width
                spacing: 8

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: 12
                    radius: Form.phainon ? 1.5 : 0
                    color: Form.reaver ? Theme.live : (modelData.color || Theme.primary)
                }

                StyledText {
                    width: 62
                    text: modelData.allDay ? cal.tx("All day") : cal.parse(modelData.start).toLocaleTimeString(I18n.locale(), SettingsData.use24HourClock ? "HH:mm" : "h:mm ap")
                    font.family: Theme.monoFontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.withAlpha(Theme.surfaceText, 0.6)
                }

                StyledText {
                    width: parent.width - 62 - 3 - 16
                    elide: Text.ElideRight
                    text: cal.tx(modelData.summary)
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                }
            }

            StyledText {
                visible: cal.dayEvents.length === 0
                text: Form.reaver ? "nothing." : "No events"
                font.family: Form.reaver ? Theme.monoFontFamily : Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.withAlpha(Theme.surfaceText, 0.45)
            }
        }
    }
}
