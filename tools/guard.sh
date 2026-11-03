#!/bin/sh
# Coreflame fail-safe. Installed to ~/.config/coreflame/guard.sh by `coreflame.sh`.
#
#   guard.sh snapshot   remember the theme settings in use right now (your stock setup)
#   guard.sh preselect  run by systemd just before DMS starts: when forms follow the clock,
#                       write this hour's form into the settings, so the shell starts in it
#   guard.sh check      run by systemd just after DMS starts with the Coreflame interface:
#                       fails unless the shell answers and has drawn its top-of-screen pieces
#   guard.sh fallback   run by systemd when DMS fails while Coreflame is on (or by the shell
#                       itself when it cannot reach the backend): put stock DMS back with the
#                       remembered settings
set -u

home_cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
state="$home_cfg/coreflame"
dropin="$home_cfg/systemd/user/dms.service.d/coreflame.conf"
settings="$home_cfg/dms/settings.json"
session="${XDG_STATE_HOME:-$HOME/.local/state}/dms/session.json"
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

preselect)
    # Run by systemd just before DMS starts. When forms follow the clock, start straight in this
    # hour's form, so the shell draws it first time: no switch at login, one theme build, the right
    # wallpaper from the first frame. Same rule as Form.scheduledForm; the sun mode is left to the shell.
    python3 -I - "$settings" "$session" "$state/schedule.json" "$HOME/Pictures/Phainon" << 'EOF'
import json, os, sys, time
settings, session, schedule, walls = sys.argv[1:5]
try:
    s = json.load(open(schedule))
    cfg = json.load(open(settings))
    ses = json.load(open(session))
except Exception:
    sys.exit(0)
if not s.get("enabled") or s.get("sun") or "coreflame" not in str(cfg.get("customThemeFile", "")):
    sys.exit(0)
defaults = {"phainon": "08:00", "khaslana": "17:00", "reaver": "01:00"}
def minutes(form):
    for value in (s.get(form), defaults[form]):
        try:
            h, m = str(value).split(":")
            return int(h) * 60 + int(m)
        except ValueError:
            pass
now = time.localtime()
at = now.tm_hour * 60 + now.tm_min
starts = sorted(((f, minutes(f)) for f in ("phainon", "khaslana", "reaver")), key=lambda x: x[1])
# Before the first start of the day, the last one of yesterday still holds.
pick = starts[-1][0]
for form, start in starts:
    if start <= at:
        pick = form
variants = cfg.get("registryThemeVariants") or {}
wall = os.path.join(walls, {"phainon": "phianon.png", "khaslana": "khaslana.png", "reaver": "flame reaver.jpeg"}[pick])
def save(path, data):
    tmp = path + ".coreflame-tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    os.replace(tmp, path)
if variants.get("coreflame") != pick:
    variants["coreflame"] = pick
    cfg["registryThemeVariants"] = variants
    save(settings, cfg)
light = pick == "phainon"
if ses.get("isLightMode") != light or (os.path.exists(wall) and ses.get("wallpaperPath") != wall):
    ses["isLightMode"] = light
    if os.path.exists(wall):
        ses["wallpaperPath"] = wall
    save(session, ses)
print(pick)
EOF
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
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
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
    echo "usage: $0 snapshot | preselect | check | fallback [reason] | gtk-on | gtk-off" >&2
    exit 2
    ;;
esac
