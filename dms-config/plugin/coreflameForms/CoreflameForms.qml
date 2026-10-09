import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins

PluginComponent {
    id: root

    readonly property string themeId: "coreflame"
    readonly property string themeFile: Quickshell.env("HOME") + "/.config/DankMaterialShell/themes/" + themeId + "/theme.json"
    readonly property var forms: ["phainon", "khaslana", "reaver"]
    readonly property bool active: Theme.currentTheme === "custom" && SettingsData.customThemeFile === themeFile
    readonly property string form: SettingsData.getRegistryThemeVariant(themeId, forms[0])

    // Saved once, when Coreflame takes over from another theme, so `off` can go back.
    function rememberPrevious() {
        if (active || !pluginService)
            return;
        pluginService.savePluginData(pluginId, "previous", {
            "theme": Theme.currentTheme,
            "category": Theme.currentThemeCategory,
            "file": SettingsData.customThemeFile,
            "light": SessionData.isLightMode
        });
    }

    function apply(name) {
        if (forms.indexOf(name) < 0)
            return "ERROR: unknown form '" + name + "' (phainon, khaslana, reaver)";

        // Phainon is the light form; the other two are dark.
        const light = name === "phainon";
        const wasActive = active;
        const sameFile = SettingsData.customThemeFile === themeFile;
        rememberPrevious();
        Theme.screenTransition();

        // Store the variant without reloading yet, so the theme changes once, in its final mode.
        var variants = JSON.parse(JSON.stringify(SettingsData.registryThemeVariants));
        variants[themeId] = name;
        SettingsData.registryThemeVariants = variants;
        SettingsData.saveSettings();

        const modeChanges = SessionData.isLightMode !== light;
        if (modeChanges)
            Theme.setLightMode(light, true, false);

        if (!wasActive) {
            if (!sameFile)
                SettingsData.set("customThemeFile", themeFile);
            Theme.currentThemeCategory = "registry";
            Theme.switchTheme("custom", true, false);
            if (sameFile)
                Theme.reloadCustomThemeVariant();
        } else if (!modeChanges) {
            Theme.reloadCustomThemeVariant();
        }
        return name;
    }

    function restore() {
        if (!active)
            return "off";
        const prev = pluginService ? pluginService.loadPluginData(pluginId, "previous", null) : null;
        if (!prev || !prev.theme)
            return "ERROR: no saved theme to return to, pick one in Settings";

        Theme.screenTransition();
        if (SessionData.isLightMode !== prev.light)
            Theme.setLightMode(prev.light, true, false);
        if (prev.file)
            SettingsData.set("customThemeFile", prev.file);
        Theme.currentThemeCategory = prev.category;
        Theme.switchTheme(prev.theme, true, false);
        return "off";
    }

    IpcHandler {
        target: "form"

        function set(name: string): string {
            return root.apply(name);
        }

        function next(): string {
            if (!root.active)
                return root.apply(root.form);
            return root.apply(root.forms[(root.forms.indexOf(root.form) + 1) % root.forms.length]);
        }

        function get(): string {
            return root.active ? root.form : "off";
        }

        function off(): string {
            return root.restore();
        }
    }
}
