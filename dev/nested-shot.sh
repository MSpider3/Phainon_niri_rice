#!/bin/sh
# Saves a screenshot of the sandboxed (nested) niri screen.
# usage: dev/nested-shot.sh [sandbox-dir] out.png
set -eu
NEST="${TMPDIR:-/tmp}/coreflame-nest"
if [ -d "${1:-}" ]; then NEST="$1"; shift; fi
out="$1"
# Prefer this sandbox's own niri (its session writes NIRI_SOCKET to env.txt), so several
# sandboxes can run at once; otherwise take the newest nested niri.
socket=$(sed -n 's/^NIRI_SOCKET=//p' "$NEST/env.txt" 2> /dev/null)
[ -S "${socket:-}" ] || socket=$(ls -t "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/niri.wayland-*.sock | while read -r s; do
    # The nested niri is the one whose screenshots land in the sandbox.
    NIRI_SOCKET="$s" niri msg outputs 2> /dev/null | grep -q winit && { echo "$s"; break; }
done)
[ -n "$socket" ] || { echo "No sandbox niri running." >&2; exit 1; }
rm -f "$NEST"/shots/*.png
NIRI_SOCKET="$socket" niri msg action screenshot-screen > /dev/null
for _ in 1 2 3 4 5 6 7 8 9 10; do
    shot=$(ls -t "$NEST"/shots/*.png 2> /dev/null | head -1)
    [ -n "$shot" ] && break
    sleep 0.2
done
cp "$shot" "$out"
