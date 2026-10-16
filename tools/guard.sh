#!/bin/sh
# Coreflame fail-safe. Installed to ~/.config/coreflame/guard.sh by `coreflame.sh`.
#
#   guard.sh snapshot   remember the theme settings in use right now (your stock setup)
#   guard.sh check      run by systemd just after DMS starts with the Coreflame interface:
#                       fails unless the shell answers and has drawn its top-of-screen pieces
#   guard.sh fallback   run by systemd when DMS fails while Coreflame is on (or by the shell
#                       itself when it cannot reach the backend): put stock DMS back with the
#                       remembered settings
set -u

home_cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
state="$home_cfg/coreflame"
dropin="$home_cfg/systemd/user/dms.service.d/coreflame.conf"
settings="$home_cfg/DankMaterialShell/settings.json"
session="${XDG_STATE_HOME:-$HOME/.local/state}/DankMaterialShell/session.json"
log="$state/fallback.log"

mkdir -p "$state"

say() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$log"
}

ipc() {
    dms ipc call "$@" 2>/dev/null | tail -n 1
}

case "${1:-}" in
snapshot)
    python3 -I - "$settings" "$session" "$state/before.json" << 'EOF'
import json, subprocess, sys
settings, session, out = sys.argv[1:4]
s = json.load(open(settings))
keep = {"settings": {k: s.get(k) for k in ("currentThemeName", "currentThemeCategory", "customThemeFile", "registryThemeVariants", "iconThemeDark", "iconThemeLight", "cursorSettings")}}
try:
    st = json.load(open(session))
except Exception:
    st = {}
keep["session"] = {k: st.get(k) for k in ("isLightMode", "wallpaperCyclingEnabled", "wallpaperPath")}
keep["gsettings"] = {}
for key in ("color-scheme", "gtk-theme", "icon-theme", "cursor-theme"):
    try:
        keep["gsettings"][key] = subprocess.run(["gsettings", "get", "org.gnome.desktop.interface", key], capture_output=True, text=True).stdout.strip().strip("'")
    except Exception:
        pass
json.dump(keep, open(out, "w"), indent=2)
EOF
    ;;

# While a form is showing, GTK 4 apps use plain libadwaita recoloured by DMS, so they can follow
# light and dark. Your own gtk.css (a full theme) is kept aside and put back on the way out.
gtk-on)
    css="$home_cfg/gtk-4.0/gtk.css"
    if [ -f "$css" ] && ! grep -q "coreflame" "$css"; then
        [ -f "$state/gtk4-gtk.css.before" ] || cp "$css" "$state/gtk4-gtk.css.before"
        printf '/* coreflame: plain libadwaita with the form colours; your own file is in %s */\n@import url("dank-colors.css");\n' "$state/gtk4-gtk.css.before" > "$css"
    fi
    ;;

gtk-off)
    # The Starship cycle tag belongs to the forms; without the file it simply stops showing.
    rm -f "$state/prompt"
    # Fastfetch: put your own config back in place of the form's.
    if [ -L "$home_cfg/fastfetch/config.jsonc" ] && [ -f "$state/fastfetch-config.jsonc.before" ]; then
        rm -f "$home_cfg/fastfetch/config.jsonc" && cp "$state/fastfetch-config.jsonc.before" "$home_cfg/fastfetch/config.jsonc"
    fi
    if [ -f "$state/gtk4-gtk.css.before" ]; then
        cp "$state/gtk4-gtk.css.before" "$home_cfg/gtk-4.0/gtk.css" && rm -f "$state/gtk4-gtk.css.before"
    fi
    ;;

check)
    # Only meaningful while the Coreflame interface is the one being loaded.
    [ -n "${DMS_SHELL_DIR:-}" ] || exit 0
    tries=0
    answer=""
    while [ "$tries" -lt 30 ]; do
        answer=$(ipc form get)
        case "$answer" in
        off | phainon | khaslana | reaver) break ;;
        esac
        answer=""
        tries=$((tries + 1))
        sleep 1
    done
    if [ -z "$answer" ]; then
        say "check failed: the shell did not answer within 30 s"
        exit 1
    fi
    # With a form active, the island and corner tabs must exist. niri lists them as a layer.
    if [ "$answer" != off ] && [ -n "${NIRI_SOCKET:-}" ]; then
        tries=0
        while [ "$tries" -lt 15 ]; do
            if niri msg -j layers 2>/dev/null | grep -q '"coreflame:chrome"'; then
                exit 0
            fi
            tries=$((tries + 1))
            sleep 1
        done
        say "check failed: the shell answered but never drew the island and corners"
        exit 1
    fi
    exit 0
    ;;

fallback)
    say "falling back to stock DMS (${2:-DMS failed while the Coreflame interface was on})"
    systemctl --user stop dms.service 2>/dev/null
    rm -f "$dropin"
    systemctl --user daemon-reload
    # Put the remembered theme settings back while nothing is running.
    if [ -f "$state/before.json" ]; then
        python3 -I - "$settings" "$session" "$state/before.json" << 'EOF' && say "theme, wallpaper, icon and colour-scheme settings restored"
import json, os, subprocess, sys
settings, session, before = sys.argv[1:4]
b = json.load(open(before))

def patch(path, values):
    try:
        data = json.load(open(path))
    except Exception:
        return
    for k, v in (values or {}).items():
        if v is None:
            data.pop(k, None)
        else:
            data[k] = v
    tmp = path + ".coreflame-tmp"
    json.dump(data, open(tmp, "w"), indent=2)
    os.replace(tmp, path)

patch(settings, b.get("settings"))
patch(session, b.get("session"))
for key, value in (b.get("gsettings") or {}).items():
    if value:
        subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", key, value])
EOF
    fi
    sh "$0" gtk-off
    systemctl --user reset-failed dms.service 2>/dev/null
    systemctl --user start dms.service
    tries=0
    while [ "$tries" -lt 40 ]; do
        if systemctl --user is-active --quiet dms.service; then
            say "stock DMS is running again"
            case "${2:-}" in
            requested*) notify-send -a Coreflame "Back on stock DMS" "As you asked. Your earlier theme settings are restored." 2>/dev/null ;;
            *) notify-send -a Coreflame "Coreflame stopped" "Something failed, so your usual DMS is back. Details: $log" 2>/dev/null ;;
            esac
            exit 0
        fi
        tries=$((tries + 1))
        sleep 1
    done
    say "stock DMS did not come back within 40 s"
    exit 1
    ;;

*)
    echo "usage: $0 snapshot | check | fallback [reason] | gtk-on | gtk-off" >&2
    exit 2
    ;;
esac
