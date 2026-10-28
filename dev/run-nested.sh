#!/bin/sh
# Opens a nested niri window running the Coreflame shell in a sandbox.
# The real session's DMS, settings and keybinds are not involved. Close the window to stop.
# usage: dev/run-nested.sh [sandbox-dir] [phainon|khaslana|reaver]
# Switch form while it runs with: dev/nested-ipc.sh [sandbox-dir] form set <name>
set -eu

here=$(cd "$(dirname "$0")" && pwd)
NEST="${1:-${TMPDIR:-/tmp}/coreflame-nest}"
COREFLAME_DIR="${COREFLAME_DIR:-$HOME/.config/quickshell/coreflame}"
real_cfg="${XDG_CONFIG_HOME:-$HOME/.config}/dms"
real_state="${XDG_STATE_HOME:-$HOME/.local/state}/dms"

rm -rf "$NEST/run"
mkdir -p "$NEST/config/dms/themes" "$NEST/config/dms/plugins" "$NEST/state/dms" "$NEST/cache" "$NEST/shots"

# Seed the sandbox once from the real settings, with only the form-switch plugin enabled.
if [ ! -f "$NEST/config/dms/settings.json" ]; then
    cp "$real_cfg/settings.json" "$NEST/config/dms/"
    cp "$real_state/session.json" "$NEST/state/dms/"
    printf '{"coreflameForms":{"enabled":true}}\n' > "$NEST/config/dms/plugin_settings.json"
fi
# The sandbox always starts on the Coreflame theme, whatever the real session is using,
# otherwise the shell would look like stock DMS.
FORM="${2:-khaslana}"
python3 -I - "$NEST" "$HOME" "$FORM" <<'PY'
import json, sys
nest, home, form = sys.argv[1:4]
p = nest + "/config/dms/settings.json"
s = json.load(open(p))
s["currentThemeName"] = "custom"
s["currentThemeCategory"] = "registry"
s["customThemeFile"] = home + "/.config/dms/themes/coreflame/theme.json"
v = s.get("registryThemeVariants") or {}
v["coreflame"] = form
s["registryThemeVariants"] = v
json.dump(s, open(p, "w"), indent=2)
p = nest + "/state/dms/session.json"
s = json.load(open(p))
s["isLightMode"] = form == "phainon"
json.dump(s, open(p, "w"), indent=2)
PY
rsync -a --delete "$real_cfg/themes/coreflame" "$NEST/config/dms/themes/"
rsync -a --delete "$real_cfg/plugins/coreflameForms" "$NEST/config/dms/plugins/"

sed -e "s|@SHOTS@|$NEST/shots|" -e "s|@NEST@|$NEST|g" "$here/niri-test.kdl" > "$NEST/niri.kdl"
# The sandbox must never count as the live shell (that is what binds wallpaper, GTK colours and
# icon packs to the form), even when it is started from an app the live shell launched.
unset DMS_SHELL_DIR
export NEST COREFLAME_DIR COREFLAME_DEV="$here"
exec niri -c "$NEST/niri.kdl"
