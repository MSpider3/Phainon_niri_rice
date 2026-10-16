pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

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
    }

    function unregisterChrome(item) {
        chromes = chromes.filter(c => c !== item);
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

    readonly property string epithet: phainon ? "The Deliverer" : (khaslana ? "Worldbearer" : (reaver ? "of the Deepest Dark" : ""))
    readonly property string quote: phainon ? "Amphoreus will welcome a true dawn." : (khaslana ? "And now, I am the fire at the end of the long night." : (reaver ? "Here we go... again." : ""))
    // What each form says as a new cycle begins
    // A line in Cyrene's voice for each start, chosen by the boot count. Written for this
    // rice in her spirit; they are not quotes from the game.
    readonly property var cyreneLines: ["Even if the world forgets, I'll remember you.", "Every flower that falls blooms again somewhere.", "Go on. I'll be waiting at the end of the road.", "Hold the light a little longer, hero.", "One more dawn. Let's see it together.", "You've carried it all this way. Rest a moment.", "The path loops, but your steps are never the same.", "When you're lost, follow the scent of the wheat fields."]
    readonly property string cyreneLine: cyreneLines[boots % cyreneLines.length]
    readonly property string greeting: phainon ? "Remember the past, and become the hero of tomorrow." : (khaslana ? "As long as I burn, they'll never truly leave me." : (reaver ? "Climb, fall, climb, fall, climb again." : ""))

    Process {
        running: root.active
        command: ["sh", "-c", "journalctl --list-boots -q 2>/dev/null | wc -l"]
        stdout: StdioCollector {
            onStreamFinished: root.boots = parseInt(text.trim()) || 0
        }
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
        }
    }

    function minutesOf(text) {
        const m = /^(\d{1,2}):(\d{2})$/.exec(text ?? "");
        return m ? (parseInt(m[1]) % 24) * 60 + parseInt(m[2]) % 60 : 0;
    }

    function scheduledForm(now) {
        const at = now.getHours() * 60 + now.getMinutes();
        const starts = [["phainon", minutesOf(schedule.phainon)], ["khaslana", minutesOf(schedule.khaslana)], ["reaver", minutesOf(schedule.reaver)]];
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
        if (!active || !schedule.enabled) {
            lastScheduled = "";
            return;
        }
        const wanted = scheduledForm(new Date());
        if (wanted === lastScheduled && !force)
            return;
        if (wanted === form || scheduleTries >= 5) {
            lastScheduled = wanted;
            scheduleTries = 0;
            return;
        }
        scheduleTries++;
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
            "reaver": schedule.reaver
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
        schedule.enabled = on;
        // Turning it on applies the current slot straight away.
        lastScheduled = "";
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
