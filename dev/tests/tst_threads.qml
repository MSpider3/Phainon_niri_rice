import QtQuick
import QtTest
import "../../overlay/Modules/Coreflame/Threads.js" as Threads

// The messages list: live notifications first, then the saved history that is not live, by app.
TestCase {
    name: "Threads"

    function wrapper(id, ms, app, summary) {
        return {
            notification: {
                id: id
            },
            time: new Date(ms),
            appName: app,
            desktopEntry: "",
            summary: summary,
            body: "",
            actions: [
                {
                    text: "Open"
                }
            ]
        };
    }

    function entry(id, sourceId, ms, app, summary) {
        return {
            id: id,
            sourceNotificationId: sourceId,
            timestamp: ms,
            appName: app,
            desktopEntry: "",
            summary: summary,
            body: "b"
        };
    }

    function test_age_reads_short() {
        const now = 10 * 86400000;
        compare(Threads.age(now - 20000, now), "now");
        compare(Threads.age(now - 2 * 60000, now), "2m");
        compare(Threads.age(now - 3 * 3600000, now), "3h");
        compare(Threads.age(now - 3 * 86400000, now), "3d");
        compare(Threads.age(now + 5000, now), "now");
    }

    function test_history_only_shows_when_nothing_is_live() {
        const t = Threads.merge([], [entry("a", "1", 100, "Firefox", "Old"), entry("b", "2", 300, "Mail", "New")]);
        compare(t.length, 2);
        compare(t[0].appName, "Mail");
        compare(t[0].notes[0].id, "b");
        compare(t[0].notes[0].wrapper, null);
        compare(t[1].notes[0].summary, "Old");
    }

    function test_live_first_and_its_history_twin_skipped() {
        const w = wrapper(7, 500, "Firefox", "Live");
        const live = [
            {
                key: "firefox",
                appName: "Firefox",
                notifications: [w]
            }
        ];
        const history = [entry("x", "7", 500, "Firefox", "Live"), entry("y", "3", 200, "Firefox", "Older"), entry("z", "4", 900, "Mail", "Newer")];
        const t = Threads.merge(live, history);
        compare(t.length, 2);
        compare(t[0].key, "firefox");
        compare(t[0].notes.length, 2);
        compare(t[0].notes[0].wrapper, w);
        compare(t[0].notes[0].actions.length, 1);
        compare(t[0].notes[1].id, "y");
        // clearing the app removes its saved twin too
        compare(t[0].historyIds, ["x", "y"]);
        compare(t[1].key, "mail");
    }

    function test_desktop_entry_groups_before_name() {
        const e = entry("a", "1", 100, "Some Name", "s");
        e.desktopEntry = "org.App";
        compare(Threads.merge([], [e])[0].key, "org.app");
    }

    function test_empty_inputs() {
        compare(Threads.merge(null, undefined).length, 0);
    }
}
