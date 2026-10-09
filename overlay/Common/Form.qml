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
    }

    onFormChanged: {
        applyWallpaper();
        applyDesktop();
    }

    Timer {
        interval: 4000
        running: true
        onTriggered: {
            root.applyWallpaper();
            root.applyDesktop();
        }
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
