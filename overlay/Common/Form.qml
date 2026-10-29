pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

// Which of the three Coreflame forms is showing, and the shape rules that follow from it.
// Inactive (form === "") whenever another theme is selected, so the shell then looks like stock DMS.
Singleton {
    id: root

    readonly property string themeId: "coreflame"
    readonly property bool active: typeof SettingsData !== "undefined" && SettingsData.currentThemeName === "custom" && (SettingsData.customThemeFile || "").endsWith("/themes/" + themeId + "/theme.json")
    readonly property string form: active ? SettingsData.getRegistryThemeVariant(themeId, "phainon") : ""

    readonly property bool phainon: form === "phainon"
    readonly property bool khaslana: form === "khaslana"
    readonly property bool reaver: form === "reaver"

    // "round": paper pill, "cut": plate with two chamfered corners, "slab": flat, square, no edge
    readonly property string shape: khaslana ? "cut" : (reaver ? "slab" : "round")
    readonly property real cut: khaslana ? 8 : 0
    readonly property bool pillRound: phainon
    readonly property real edgeWidth: (phainon || khaslana) ? 1 : 0
    readonly property real edgeOpacity: khaslana ? 1.0 : 0.6
    readonly property bool mono: reaver

    // Typefaces. Display is for titles, numerals and small caps labels; body replaces the UI font.
    // Phainon: Marcellus, a Roman inscription face. Khaslana: Cinzel over Chakra Petch, whose
    // chamfered letters echo his cut plates. The Flame Reaver stays in monospace.
    readonly property string displayFont: phainon ? "Marcellus" : (khaslana ? "Cinzel" : "")
    readonly property string bodyFont: khaslana ? "Chakra Petch" : ""
    readonly property string quoteFont: (phainon || khaslana) ? "Cormorant Garamond" : ""

    function display(fallback) {
        return displayFont !== "" ? displayFont : fallback;
    }

    function quoteFace(fallback) {
        return quoteFont !== "" ? quoteFont : fallback;
    }

    // While a form is showing, the island and corner tabs replace the stock bar.
    readonly property bool chrome: active
    property var chromes: []

    function registerChrome(item) {
        chromes = chromes.concat([item]);
        Coreflames.earn("worldbearing");
        playOpening();
    }

    function unregisterChrome(item) {
        chromes = chromes.filter(c => c !== item);
    }

    // Clicking a notification opens what it is about: its default action (as stock DMS popups do),
    // else the app's open window, else the app itself. Then it is dismissed.
    function openNotification(n) {
        if (!n)
            return;
        const actions = n.actions ?? [];
        const action = actions.find(a => a.identifier === "default") || actions[0];
        if (action?.invoke) {
            action.invoke();
        } else {
            const names = [n.desktopEntry, n.appName].filter(Boolean).map(s => s.toLowerCase());
            const win = NiriService.windows.find(w => {
                const id = (w.app_id ?? "").toLowerCase();
                return id !== "" && names.some(name => id === name || id.endsWith("." + name) || name.endsWith("." + id));
            });
            if (win)
                NiriService.focusWindow(win.id);
            else
                (DesktopEntries.byId(n.desktopEntry) ?? DesktopEntries.heuristicLookup(n.appName))?.execute();
        }
        NotificationService.dismissNotification(n);
    }

    // App windows: round for Phainon, barely eased for Khaslana, square for the Flame Reaver.
    function windowRadius(base) {
        if (!active)
            return base;
        return phainon ? Math.max(base, 18) : (khaslana ? 3 : 0);
    }

    function radius(base) {
        if (!active || phainon)
            return base;
        return khaslana ? 2 : 0;
    }

    // Eternal Recurrence: he lived 33,550,336 cycles before this one. Every boot of this machine
    // counts as one more.
    property int boots: 0
    readonly property int cycle: 33550336 + boots
    readonly property string cycleText: cycle.toLocaleString(Qt.locale("en_US"), "f", 0)

    readonly property string epithet: phainon ? "The Deliverer" : (khaslana ? "Bearer of Chaos" : (reaver ? "of the Deepest Dark" : ""))
    // Lock-screen quotes: game lines, one per boot from each form's pool.
    readonly property var lockQuotes: ({
            "phainon": ["Amphoreus will welcome a true dawn.", "They say, if suffering has an end, then I will be the Deliverer.", "May this world never again need a Deliverer.", "My wish? My wish is to fulfill everyone else's wishes. If I can't fulfill them... then send them on to tomorrow."],
            "khaslana": ["And now, I am the fire at the end of the long night.", "Are you ready? Nanook, I brought you destruction!", "If this is not the end, then I will keep walking, until I witness the end of this journey. But I will never submit to this idea of fate. Never!", "If what lies ahead is a mass of chaos, I will tear it apart... then usher in the first ray of blazing sunlight.", "Climb, fall, climb, fall, climb again, and fall..."],
            "reaver": ["Why not... let wrath... incinerate fate...?"]
        })
    readonly property string quote: {
        const pool = lockQuotes[form] ?? [];
        return pool.length ? pool[boots % pool.length] : "";
    }
    // A line in Cyrene's voice for each start, chosen by the boot count. The first eight are
    // original fan-written lines in her spirit, not her dialogue; the last is hers, from the game.
    readonly property var cyreneLines: ["Even if the world forgets, I'll remember you.", "Every flower that falls blooms again somewhere.", "Go on. I'll be waiting at the end of the road.", "Hold the light a little longer, hero.", "One more dawn. Let's see it together.", "You've carried it all this way. Rest a moment.", "The path loops, but your steps are never the same.", "When you're lost, follow the scent of the wheat fields.", "Of course, this will be a romantic story like none that has come before. You think so too, right?"]
    readonly property string cyreneLine: cyreneLines[boots % cyreneLines.length]
    // What each form says as a new cycle begins (island, first start after boot)
    readonly property string greeting: phainon ? "Remember the past, and become the hero of tomorrow." : (khaslana ? "I'll remember this world through anger. As long as I burn, they'll never truly leave me." : (reaver ? "The Flame-Chase will not end..." : ""))
    // The island notice when the user switches to this form
    readonly property string formLine: phainon ? "Light up the dawn!" : (khaslana ? "I will never yield to such a fate." : (reaver ? "The Flame-Chase will not end..." : ""))
    // Said to him; the lock screen asks it inside the password box.
    readonly property string passwordHint: phainon ? "Phainon of Aedes Elysiae, what is your dream?" : ""
    // His breaking point, shown while he becomes Khaslana.
    readonly property string transformCaption: khaslana ? "Why... did you... take them all away... from me!?" : ""

    // Kept in stateDir/boots as "<count> <boot id>": one more each time the kernel's boot id is new.
    // Seeded once from the journal; after that, journal rotation or vacuuming can't lower it.
    Process {
        running: root.active
        command: ["sh", "-c", "f=\"$1/boots\"; id=$(cat /proc/sys/kernel/random/boot_id); n=; last=; [ -f \"$f\" ] && read -r n last < \"$f\"; case \"$n\" in '' | *[!0-9]*) n=$(journalctl --list-boots -q 2>/dev/null | wc -l); last=$id ;; esac; new=0; [ \"$id\" != \"$last\" ] && n=$((n + 1)) && new=1; mkdir -p \"$1\" && printf '%s %s\\n' \"$n\" \"$id\" > \"$f\"; echo \"$n $new\"", "sh", root.stateDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const [count, isNew] = text.trim().split(" ");
                root.boots = parseInt(count) || 0;
                root.newBoot = isNew === "1";
                root.playOpening();
            }
        }
    }

    // True when this is the shell's first start since the machine booted (the opening cinematic plays).
    property bool newBoot: false
    property bool openingPlayed: false
    // Bumped by any lock surface on key or pointer input, so the lock video stops on every screen.
    property int lockInput: 0

    // The boot check and the first chrome can finish in either order; whichever is last starts it.
    // Waits until the screens have stopped changing: at a real boot the outputs are still being set
    // up and the chrome holding the video could be rebuilt mid-play, which hid the opening.
    function playOpening() {
        if (!newBoot || openingPlayed || chromes.length === 0 || !active || !live)
            return;
        openingSettle.restart();
    }

    Timer {
        id: openingSettle
        interval: 2000
        onTriggered: {
            if (!root.newBoot || root.openingPlayed || root.chromes.length === 0 || !root.active || !root.live)
                return;
            root.openingPlayed = true;
            console.info("Coreflame opening: playing");
            root.cinematic("opening", cut => {
                console.info("Coreflame opening:", cut ? "cut short by a rebuild, playing again" : "done");
                if (cut) {
                    root.openingPlayed = false;
                    root.playOpening();
                }
            });
        }
    }

    // Plays ~/.config/coreflame/cinematics/<name>.mkv full screen, then runs `then`. Without a live
    // Coreflame chrome (stock DMS, the sandbox) it runs `then` straight away.
    function cinematic(name, then) {
        const lead = active && live ? chromes[0] : null;
        if (!lead) {
            if (then)
                then();
            return;
        }
        lead.playCinematic(stateDir + "/cinematics/" + name + ".mkv", then);
    }

    // The terminal prompt and cycle file are written at start; rewrite them if the count lands late.
    onCycleChanged: {
        if (settled)
            applyDesktop();
    }

    // Each form has its wallpaper. Changing form changes it; random wallpaper cycling is switched
    // off while a form is showing, or it would replace the form's wallpaper within the hour.
    readonly property string wallpaperFolder: Quickshell.env("HOME") + "/Pictures/Phainon/"
    readonly property var wallpapers: ({
            "phainon": wallpaperFolder + "phianon.png",
            "khaslana": wallpaperFolder + "khaslana.png",
            "reaver": wallpaperFolder + "flame reaver.jpeg"
        })

    // Plugins that would take the wallpaper away from the form (the shuffler picks a new one
    // every time its widget loads). They are left unloaded while a form is active.
    readonly property var heldPlugins: active ? ["wallpaperShufflerPlugin"] : []

    function applyWallpaper() {
        if (!active || typeof SessionData === "undefined")
            return;
        const wanted = wallpapers[form];
        if (!wanted)
            return;
        if (SessionData.wallpaperCyclingEnabled)
            SessionData.setWallpaperCyclingEnabled(false);
        if (SessionData.wallpaperPath !== wanted)
            SessionData.setWallpaper(wanted);
    }

    // Icon and folder packs: Gruvbox Plus as the base (muted paper-and-charcoal app icons), with
    // the folder set tinted in each form's own primary colour. Made by tools/icons.sh.
    readonly property var iconThemes: ({
            "phainon": "Coreflame-Phainon",
            "khaslana": "Coreflame-Khaslana",
            "reaver": "Coreflame-Reaver"
        })
    // Only the real session touches system-wide settings; the test sandbox leaves them alone.
    readonly property var cursors: ({
            "phainon": "Bibata-Modern-Ice",
            "khaslana": "Bibata-Modern-Amber",
            "reaver": "Bibata-Modern-Classic"
        })
    readonly property bool live: (Quickshell.env("DMS_SHELL_DIR") ?? "") !== ""

    // GTK apps need three things to follow a form: the system light/dark preference, a GTK 3
    // theme of the same lightness, and a gtk.css that does not hard-code another theme's colours.
    function applyDesktop() {
        if (!active || !live || typeof SettingsData === "undefined")
            return;
        // Read the form itself: inside onFormChanged the `phainon` shorthand may still hold the
        // previous form's answer.
        const light = form === "phainon";
        const guard = Quickshell.env("HOME") + "/.config/coreflame/guard.sh";
        Quickshell.execDetached(["sh", guard, "gtk-on"]);
        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", light ? "prefer-light" : "prefer-dark"]);
        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", light ? "adw-gtk3" : "adw-gtk3-dark"]);
        // DMS reads the light slot only when "icon theme per mode" is on; otherwise the dark slot
        // is the one in use, whatever the form.
        const slotLight = light && SettingsData.iconThemePerMode;
        const icons = iconThemes[form];
        if (icons && (slotLight ? SettingsData.iconThemeLight : SettingsData.iconThemeDark) !== icons)
            SettingsData.setIconThemeForMode(icons, slotLight);
        // Terminal: Fastfetch shows this form's portrait, Starship prints the cycle in its colour.
        const portrait = String(Qt.resolvedUrl("../assets/coreflame/fastfetch/" + form + ".png")).replace("file://", "");
        Quickshell.execDetached(["ln", "-sfn", portrait, stateDir + "/fastfetch-logo.png"]);
        // Each form has its own Fastfetch layout; your original is kept in fastfetch-config.jsonc.before.
        const fetchConfig = String(Qt.resolvedUrl("../assets/coreflame/fastfetch/" + form + ".jsonc")).replace("file://", "");
        Quickshell.execDetached(["ln", "-sfn", fetchConfig, Quickshell.env("HOME") + "/.config/fastfetch/config.jsonc"]);
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" > \"$2\"", "sh", cycleText, stateDir + "/cycle"]);
        // btop reads themes/coreflame.theme, which points at this form's colours.
        const btopTheme = String(Qt.resolvedUrl("../assets/coreflame/btop/" + form + ".theme")).replace("file://", "");
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$2\" && ln -sfn \"$1\" \"$2/coreflame.theme\"", "sh", btopTheme, Quickshell.env("HOME") + "/.config/btop/themes"]);
        // Cursor: Bibata Ice, Amber or Classic, if installed (tools/icons.sh installs them).
        const cursor = cursors[form];
        if (cursor && SettingsData.cursorSettings?.theme !== cursor)
            SettingsData.setCursorTheme(cursor);
        if (cursor)
            Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "cursor-theme", cursor]);
        const rgb = ({
                "phainon": "51;71;134",
                "khaslana": "212;177;74",
                "reaver": "122;106;168"
            })[form] ?? "200;200;200";
        Quickshell.execDetached(["sh", "-c", "printf '\\033[38;2;%sm✦ [Cycle %s]\\033[0m' \"$1\" \"$2\" > \"$3\"", "sh", rgb, cycleText, stateDir + "/prompt"]);
    }

    // Sounds (CC0, see assets/coreflame/sounds/CREDITS): one when the form changes, glass when the
    // battery runs low. Follows DMS's "sounds" switch; silent during the first seconds after start.
    property bool settled: false

    function playSound(name) {
        if (!active || !settled || (typeof SettingsData !== "undefined" && !SettingsData.soundsEnabled))
            return;
        Quickshell.execDetached(["pw-play", String(Qt.resolvedUrl("../assets/coreflame/sounds/" + name + ".ogg")).replace("file://", "")]);
    }

    onFormChanged: {
        applyWallpaper();
        applyDesktop();
        playSound(form);
        if (active)
            Coreflames.sawForm(form);
    }

    Timer {
        interval: 4000
        running: true
        onTriggered: {
            root.applyWallpaper();
            root.applyDesktop();
            root.settled = true;
        }
    }

    // Forms by the hour: each form has a start time and holds until the next one starts.
    // Kept in ~/.config/coreflame/schedule.json; a form picked by hand stays until the next start.
    readonly property string stateDir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/coreflame"
    readonly property alias schedule: schedule
    property string lastScheduled: ""
    property int scheduleTries: 0
    // Set once the first screen has checked the backend after start-up (see Chrome.qml).
    property bool startupChecked: false

    FileView {
        id: scheduleFile
        path: root.stateDir + "/schedule.json"
        blockLoading: true
        printErrors: false
        // Read once at start. The values in memory are the truth after that; watching the file
        // made a save race with its own reload and flip the switch back off.

        JsonAdapter {
            id: schedule
            property bool enabled: false
            property string phainon: "08:00"
            property string khaslana: "17:00"
            property string reaver: "01:00"
            // Follow the sun: Phainon starts at sunrise, Khaslana at sunset, the Reaver keeps its time.
            property bool sun: false
        }
    }

    // Today's sunrise and sunset ("HH:MM") at the weather location, or null when none is known.
    // sunDay is moved on by checkSunDay (schedule timer, panel, status), so this is worked out once a day.
    property string sunDay: new Date().toDateString()
    function checkSunDay() {
        const day = new Date().toDateString();
        if (day !== sunDay)
            sunDay = day;
    }
    readonly property var sunRaw: {
        if (!active || sunDay === "")
            return null;
        const now = new Date();
        return WeatherService.getSunTimes(new Date(now.getFullYear(), now.getMonth(), now.getDate(), 12));
    }
    // Polar day or night: the location is known, but there is no sunrise or sunset today.
    readonly property bool sunPolar: !!sunRaw && sunTimes === null
    readonly property var sunTimes: {
        const t = sunRaw;
        if (!t || isNaN(t.sunrise) || isNaN(t.sunset))
            return null;
        const hm = d => String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0");
        return {
            "sunrise": hm(t.sunrise),
            "sunset": hm(t.sunset)
        };
    }

    // The time a form really starts: by the sun when that is on and known, else its set time.
    function startOf(name) {
        if (schedule.sun && sunTimes && name !== "reaver")
            return name === "phainon" ? sunTimes.sunrise : sunTimes.sunset;
        return schedule[name];
    }

    function minutesOf(text) {
        const m = /^(\d{1,2}):(\d{2})$/.exec(text ?? "");
        return m ? (parseInt(m[1]) % 24) * 60 + parseInt(m[2]) % 60 : 0;
    }

    function scheduledForm(now) {
        const at = now.getHours() * 60 + now.getMinutes();
        const starts = [["phainon", minutesOf(startOf("phainon"))], ["khaslana", minutesOf(startOf("khaslana"))], ["reaver", minutesOf(startOf("reaver"))]];
        starts.sort((a, b) => a[1] - b[1]);
        // Before the first start of the day, the last one of yesterday still holds.
        let pick = starts[starts.length - 1][0];
        for (const start of starts) {
            if (start[1] <= at)
                pick = start[0];
        }
        return pick;
    }

    function followSchedule(force) {
        checkSunDay();
        if (!active || !schedule.enabled) {
            lastScheduled = "";
            return;
        }
        // By the sun, but the weather location is still on its way (start-up, location change):
        // wait for it instead of switching by the set times and back. A failed fetch ends the wait;
        // the island chrome always holds a weather ref while a form is active, so a fetch does run.
        if (schedule.sun && !sunTimes && SettingsData.weatherEnabled && WeatherService.weather.loading)
            return;
        const wanted = scheduledForm(new Date());
        if (wanted === lastScheduled && !force)
            return;
        if (wanted === form || scheduleTries >= 5) {
            lastScheduled = wanted;
            scheduleTries = 0;
            return;
        }
        scheduleTries++;
        console.info("Coreflame schedule: switching to", wanted, "(try " + scheduleTries + ")");
        // Not marked as done until the form has really changed: just after start-up the
        // form-switch plugin may not be listening yet, and the retry timer asks again.
        Quickshell.execDetached(["dms", "ipc", "call", "form", "set", wanted]);
        scheduleRetry.restart();
    }

    Timer {
        id: scheduleRetry
        interval: 5000
        onTriggered: root.followSchedule(false)
    }

    function saveSchedule() {
        scheduleFile.setText(JSON.stringify({
            "enabled": schedule.enabled,
            "phainon": schedule.phainon,
            "khaslana": schedule.khaslana,
            "reaver": schedule.reaver,
            "sun": schedule.sun
        }, null, 2) + "\n");
        // Not forced: a form picked by hand stays unless the edit moved the current slot.
        followSchedule(false);
    }

    function setStart(name, time) {
        const m = /^(\d{1,2}):(\d{2})$/.exec(time ?? "");
        if (["phainon", "khaslana", "reaver"].indexOf(name) < 0 || !m || parseInt(m[1]) > 23 || parseInt(m[2]) > 59)
            return false;
        schedule[name] = String(Math.floor(minutesOf(time) / 60)).padStart(2, "0") + ":" + String(minutesOf(time) % 60).padStart(2, "0");
        saveSchedule();
        return true;
    }

    function setScheduleEnabled(on) {
        console.info("Coreflame schedule: turned", on ? "on" : "off");
        schedule.enabled = on;
        // Turning it on applies the current slot straight away.
        lastScheduled = "";
        saveSchedule();
    }

    function setSunEnabled(on) {
        console.info("Coreflame schedule: follow the sun", on ? "on" : "off");
        schedule.sun = on;
        saveSchedule();
    }

    // Moves one form's start time by a number of minutes, wrapping round midnight.
    function shiftStart(name, minutes) {
        const at = (minutesOf(schedule[name]) + minutes + 1440) % 1440;
        schedule[name] = String(Math.floor(at / 60)).padStart(2, "0") + ":" + String(at % 60).padStart(2, "0");
        saveSchedule();
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", stateDir])

    Timer {
        interval: 30000
        repeat: true
        running: root.active && schedule.enabled
        triggeredOnStart: true
        onTriggered: root.followSchedule(false)
    }

    // The Dawn Device's five light periods, mapped onto the day.
    function dawnPeriod(hour) {
        if (hour < 5 || hour >= 21)
            return "Curtain-Fall Hour";
        if (hour < 9)
            return "Entry Hour";
        if (hour < 13)
            return "Lucid Hour";
        if (hour < 17)
            return "Action Hour";
        return "Parting Hour";
    }
}
