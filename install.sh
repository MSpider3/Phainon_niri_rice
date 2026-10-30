#!/bin/sh
# Installs the Phainon rice on top of DankMaterialShell 2.0 and switches to it.
# Your DMS settings, plugins and niri keybinds stay as they are; `sh coreflame.sh off`
# takes you back to stock DMS with the theme you had before.
#
#   sh install.sh                 install everything and switch on
#   sh install.sh --icons         also the icon, folder, cursor and GTK theme packs (about 185 MB download)
#   sh install.sh --system-font   also make Coreflame Display your system font (undo: see SETUP.md)
#   sh install.sh update          after "git pull": refresh fonts, theme and shell, restart DMS
#   sh install.sh build [dir]     only assemble the shell (default ~/.config/quickshell/coreflame)
set -eu

here=$(cd "$(dirname "$0")" && pwd)
cfg="${XDG_CONFIG_HOME:-$HOME/.config}/dms"
state="${XDG_STATE_HOME:-$HOME/.local/state}/dms"
fonts="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/coreflame"
walls="$HOME/Pictures/Phainon"

# The shell: the untouched DMS 2.0.0 interface from vendor/ with overlay/ laid on top. Only
# files whose content changed are touched, so a running shell reloads once.
build() {
    dest="${1:-${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/coreflame}"
    stage="${XDG_CACHE_HOME:-$HOME/.cache}/coreflame-build"
    mkdir -p "$stage" "$dest"
    rsync -a --delete --chmod=Du=rwx,Dgo=rx,Fu=rwx,Fgo=rx "$here/vendor/dms-2.0.0/" "$stage/"
    rsync -a --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r "$here/overlay/" "$stage/"
    rsync -a --delete --checksum "$stage/" "$dest/"
    echo "Coreflame shell built at $dest"
}

# Files the repo owns outright, so they are refreshed on every install and update.
fonts_and_theme() {
    echo "Fonts -> $fonts"
    mkdir -p "$fonts"
    cp "$here"/fonts/*.ttf "$fonts/"
    fc-cache -f "$fonts" 2> /dev/null || true
    echo "Theme and form-switch plugin -> $cfg"
    mkdir -p "$cfg/themes/coreflame" "$cfg/plugins/coreflameForms"
    cp "$here"/dms-config/theme/coreflame/* "$cfg/themes/coreflame/"
    cp "$here"/dms-config/plugin/coreflameForms/* "$cfg/plugins/coreflameForms/"
}

icons=0
system_font=0
case "${1:-}" in
build)
    shift
    build "$@"
    exit 0
    ;;
update)
    fonts_and_theme
    build
    systemctl --user restart dms.service
    echo "Updated and restarted DMS."
    exit 0
    ;;
esac
for arg in "$@"; do
    case "$arg" in
    --icons) icons=1 ;;
    --system-font) system_font=1 ;;
    -h | --help)
        sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    *)
        echo "Unknown option: $arg (try: sh install.sh --help)" >&2
        exit 1
        ;;
    esac
done

for tool in dms rsync python3 systemctl; do
    command -v "$tool" > /dev/null 2>&1 || { echo "Missing: $tool. Install it first." >&2; exit 1; }
done
if [ ! -f "$cfg/settings.json" ]; then
    echo "No DMS settings found in $cfg. Start DankMaterialShell once, then run this again." >&2
    exit 1
fi
case "$(dms version 2> /dev/null || dms --version 2> /dev/null)" in
*2.*) ;;
*) echo "Note: this rice is built on the DMS 2.0 interface. Another DMS version may not work with it." >&2 ;;
esac

fonts_and_theme

echo "Wallpapers -> $walls"
mkdir -p "$walls"
cp -n "$here"/wallpapers/* "$walls/"

# Opening (first shell start after a boot) and closing (restart / shut down) cinematics, the
# lock-screen video, and the art the power menu (Phainon) and lock screen (Khaslana) show.
# A file already there is kept, so your own clips and pictures survive a reinstall.
cine="${XDG_CONFIG_HOME:-$HOME/.config}/coreflame/cinematics"
echo "Cinematics -> $cine"
mkdir -p "$cine"
cp -n "$here"/cinematics/*.mkv "$here"/cinematics/lock.mp4 "$here"/cinematics/*.png "$cine/"

if [ "$icons" = 1 ]; then
    sh "$here/tools/icons.sh"
fi

# Optional: Coreflame Display as the default sans/serif/UI font for every app. It covers basic
# Latin only; accents, symbols and other scripts still come from your current font.
if [ "$system_font" = 1 ]; then
    fc_dir="${XDG_CONFIG_HOME:-$HOME/.config}/fontconfig/conf.d"
    echo "System font -> $fc_dir"
    mkdir -p "$fc_dir"
    cp "$here/fonts/60-coreflame-display.conf" "$fc_dir/"
    fc-cache -f 2> /dev/null || true
    if command -v gsettings > /dev/null 2>&1; then
        gsettings set org.gnome.desktop.interface font-name 'Coreflame Display 11' || true
        gsettings set org.gnome.desktop.interface document-font-name 'Coreflame Display 11' || true
    fi
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
