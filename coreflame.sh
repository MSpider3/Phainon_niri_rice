#!/bin/sh
# Switches the real session between the Coreflame shell and stock DMS.
# The DMS backend, your settings, plugins and keybinds are the same either way;
# only the interface files that `dms` loads change.
#
#   coreflame.sh on        build, then run DMS with the Coreflame interface
#   coreflame.sh off       go back to the stock DMS interface
#   coreflame.sh status    show which one is configured
#   coreflame.sh selftest  prove the fail-safe works: load a deliberately broken interface
#                          and confirm stock DMS comes back by itself (takes about a minute)
#
# Fail-safe: while Coreflame is on, any failure of DMS (it will not start, it crashes, it starts
# but never draws the island, or it cannot reach its backend) puts stock DMS back with the
# theme settings you had before, and leaves a note in ~/.config/coreflame/fallback.log.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
home_cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
state="$home_cfg/coreflame"
units="$home_cfg/systemd/user"
dropin_dir="$units/dms.service.d"
dropin="$dropin_dir/coreflame.conf"
shell_dir="$home_cfg/quickshell/coreflame"
runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

# Installs the guard and tells systemd to load the given interface folder, guarded.
arm() {
    target="$1"
    mkdir -p "$state" "$dropin_dir"
    cp "$here/tools/guard.sh" "$state/guard.sh"
    chmod +x "$state/guard.sh"
    # Remember the stock setup only when coming from stock, never while already armed.
    if [ ! -f "$dropin" ]; then
        sh "$state/guard.sh" snapshot
    fi
    cat > "$units/coreflame-fallback.service" << EOF
[Unit]
Description=Return to stock DMS after the Coreflame shell failed

[Service]
Type=oneshot
ExecStart=/bin/sh $state/guard.sh fallback
EOF
    cat > "$units/coreflame-leave.service" << EOF
[Unit]
Description=Leave the Coreflame shell and return to stock DMS

[Service]
Type=oneshot
ExecStart=/bin/sh $state/guard.sh fallback requested
EOF
    cat > "$dropin" << EOF
# Written by coreflame.sh. Remove this file (or run "coreflame.sh off") for stock DMS.
[Unit]
OnFailure=coreflame-fallback.service

[Service]
Environment=DMS_SHELL_DIR=$target
TimeoutStartSec=60
# One failure is enough to go back to stock; no retry loop.
Restart=no
ExecStartPost=/bin/sh $state/guard.sh check
EOF
    systemctl --user daemon-reload
}

disarm() {
    rm -f "$dropin"
    systemctl --user daemon-reload
}

stock_running() {
    systemctl --user is-active --quiet dms.service || return 1
    case "$(cat "$runtime/danklinux.path" 2>/dev/null)" in
    *danklinux-shell*) return 0 ;;
    esac
    return 1
}

case "${1:-status}" in
arm)
    arm "$shell_dir"
    ;;
disarm)
    disarm
    ;;
on)
    sh "$here/build.sh"
    arm "$shell_dir"
    if systemctl --user restart dms.service; then
        echo "Coreflame shell is running. Pick a form: dms ipc call form set phainon | khaslana | reaver"
    else
        echo "Coreflame failed to start. Waiting for the fail-safe to put stock DMS back..." >&2
        tries=0
        while [ -f "$dropin" ] && [ "$tries" -lt 90 ]; do
            tries=$((tries + 1))
            sleep 1
        done
        echo "See $state/fallback.log" >&2
        exit 1
    fi
    ;;
off)
    # Same route as the button in the control panel: stock DMS, with the theme settings you had
    # before Coreflame.
    if [ -f "$dropin" ] && [ -x "$state/guard.sh" ]; then
        sh "$state/guard.sh" fallback requested
    else
        disarm
        systemctl --user restart dms.service
    fi
    echo "Back on the stock DMS interface."
    ;;
status)
    if [ -f "$dropin" ]; then echo "configured: Coreflame shell (fail-safe armed)"; else echo "configured: stock DMS"; fi
    if [ -f "$state/fallback.log" ]; then echo "last fail-safe note: $(tail -n 1 "$state/fallback.log")"; fi
    ;;
selftest)
    if [ -f "$dropin" ]; then
        echo "Turn Coreflame off first (coreflame.sh off), then run the self-test." >&2
        exit 1
    fi
    broken="${XDG_CACHE_HOME:-$HOME/.cache}/coreflame-selftest"
    mkdir -p "$broken"
    printf 'import QtQuick\nThisIsDeliberatelyBroken {\n' > "$broken/shell.qml"
    echo "Loading a deliberately broken interface. Your bar will vanish for up to a minute..."
    arm "$broken"
    systemctl --user restart dms.service 2> /dev/null || true
    tries=0
    while [ "$tries" -lt 120 ]; do
        if [ ! -f "$dropin" ] && stock_running; then
            echo "PASS: the fail-safe put stock DMS back after $tries s."
            tail -n 3 "$state/fallback.log"
            exit 0
        fi
        tries=$((tries + 1))
        sleep 1
    done
    echo "FAIL: stock DMS did not come back by itself. Restoring it now." >&2
    disarm
    systemctl --user reset-failed dms.service 2> /dev/null || true
    systemctl --user restart dms.service
    exit 1
    ;;
*)
    echo "usage: $0 on | off | status | selftest" >&2
    exit 2
    ;;
esac
