#!/bin/sh
# Installs the Phainon rice on top of DankMaterialShell 1.6.2 and switches to it.
# Your DMS settings, plugins and niri keybinds stay as they are; `sh coreflame.sh off`
# takes you back to stock DMS with the theme you had before.
#
#   sh install.sh           install and switch on
#   sh install.sh --icons   also install the matching icon and folder packs (about 185 MB download)
set -eu

here=$(cd "$(dirname "$0")" && pwd)
cfg="${XDG_CONFIG_HOME:-$HOME/.config}/DankMaterialShell"
state="${XDG_STATE_HOME:-$HOME/.local/state}/DankMaterialShell"
fonts="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/coreflame"
walls="$HOME/Pictures/Phainon"

for tool in dms rsync python3 systemctl; do
    command -v "$tool" > /dev/null 2>&1 || { echo "Missing: $tool. Install it first." >&2; exit 1; }
done
if [ ! -f "$cfg/settings.json" ]; then
    echo "No DMS settings found in $cfg. Start DankMaterialShell once, then run this again." >&2
    exit 1
fi
case "$(dms version 2> /dev/null || dms --version 2> /dev/null)" in
*1.6.*) ;;
*) echo "Note: this rice is built on the DMS 1.6.2 interface. Another DMS version may not work with it." >&2 ;;
esac

echo "Fonts -> $fonts"
mkdir -p "$fonts"
cp "$here"/fonts/*.ttf "$fonts/"
fc-cache -f "$fonts" 2> /dev/null || true

echo "Wallpapers -> $walls"
mkdir -p "$walls"
cp -n "$here"/wallpapers/* "$walls/"

echo "Theme and form-switch plugin -> $cfg"
mkdir -p "$cfg/themes/coreflame" "$cfg/plugins/coreflameForms"
cp "$here"/dms-config/theme/coreflame/* "$cfg/themes/coreflame/"
cp "$here"/dms-config/plugin/coreflameForms/* "$cfg/plugins/coreflameForms/"

if [ "${1:-}" = "--icons" ]; then
    sh "$here/tools/icons.sh"
fi

# Remember the stock setup first, then point DMS at the Coreflame theme (Phainon form).
sh "$here/coreflame.sh" arm

# Terminal pieces that follow the form. The shell links Fastfetch's config to the form's own
# layout, so keep yours (put back by "coreflame.sh off"); btop gets a config only if it has none.
state_dir="${XDG_CONFIG_HOME:-$HOME/.config}/coreflame"
fetch="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch/config.jsonc"
if [ -f "$fetch" ] && [ ! -L "$fetch" ] && [ ! -f "$state_dir/fastfetch-config.jsonc.before" ]; then
    cp "$fetch" "$state_dir/fastfetch-config.jsonc.before"
fi
btop_conf="${XDG_CONFIG_HOME:-$HOME/.config}/btop/btop.conf"
if [ ! -f "$btop_conf" ]; then
    mkdir -p "$(dirname "$btop_conf")"
    printf 'color_theme = "coreflame"\ntheme_background = False\ntruecolor = True\n' > "$btop_conf"
fi
python3 -I - "$cfg" "$state" << 'PY'
import json, os, sys
cfg, state = sys.argv[1:3]
p = cfg + "/settings.json"
s = json.load(open(p))
s["currentThemeName"] = "custom"
s["currentThemeCategory"] = "registry"
s["customThemeFile"] = cfg + "/themes/coreflame/theme.json"
variants = s.get("registryThemeVariants") or {}
variants["coreflame"] = "phainon"
s["registryThemeVariants"] = variants
json.dump(s, open(p, "w"), indent=2)
p = cfg + "/plugin_settings.json"
plugins = json.load(open(p)) if os.path.exists(p) else {}
plugins.setdefault("coreflameForms", {})["enabled"] = True
json.dump(plugins, open(p, "w"), indent=2)
p = state + "/session.json"
if os.path.exists(p):
    s = json.load(open(p))
    s["isLightMode"] = True
    json.dump(s, open(p, "w"), indent=2)
PY

sh "$here/coreflame.sh" on
echo
echo "Done. Switch forms with:  dms ipc call form set phainon | khaslana | reaver"
echo "Back to stock DMS:        sh coreflame.sh off"
