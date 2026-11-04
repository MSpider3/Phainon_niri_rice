.pragma library

// The messages list. DMS drops a notification from `groupedNotifications` once its app closes it
// (and on every shell restart), but keeps it in `historyList`; show both, grouped by app:
// the live threads first (they still have their buttons), then the saved ones, newest first.
// A thread: {key, appName, notes: [{summary, body, time, actions, wrapper, entry, id}], historyIds}.

// The app a notification belongs to, as NotificationService.getGroupKey has it
function key(n) {
    return String(n.desktopEntry || n.appName || "").toLowerCase();
}

function merge(groups, history) {
    const threads = [], byKey = {}, live = {};
    for (const g of groups ?? []) {
        const t = {
            key: g.key,
            appName: g.appName,
            notes: [],
            historyIds: []
        };
        for (const w of g.notifications) {
            const time = w.time.getTime();
            live[(w.notification?.id ?? "").toString() + "@" + time] = true;
            t.notes.push({
                summary: w.summary,
                body: w.body,
                time: time,
                actions: w.actions ?? [],
                wrapper: w,
                entry: null,
                id: ""
            });
        }
        byKey[t.key] = t;
        threads.push(t);
    }
    const saved = (history ?? []).slice().sort((a, b) => b.timestamp - a.timestamp);
    for (const h of saved) {
        const k = key(h);
        let t = byKey[k];
        if (!t) {
            t = {
                key: k,
                appName: h.appName,
                notes: [],
                historyIds: []
            };
            byKey[k] = t;
            threads.push(t);
        }
        t.historyIds.push(h.id);
        if (live[h.sourceNotificationId + "@" + h.timestamp])
            continue;
        t.notes.push({
            summary: h.summary,
            body: h.body,
            time: h.timestamp,
            actions: [],
            wrapper: null,
            entry: h,
            id: h.id
        });
    }
    return threads.filter(t => t.notes.length > 0);
}

// How long ago, short: "now", "2m", "1h", "3d"
function age(ms, now) {
    const m = Math.floor((now - ms) / 60000);
    if (m < 1)
        return "now";
    if (m < 60)
        return m + "m";
    if (m < 1440)
        return Math.floor(m / 60) + "h";
    return Math.floor(m / 1440) + "d";
}
