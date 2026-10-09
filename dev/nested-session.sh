#!/bin/sh
# Runs inside the nested test niri. Starts a second, fully separate DMS (backend + Coreflame UI)
# with its own config, state, cache and runtime dirs, so the real session is never touched.
set -eu
: "${NEST:?NEST must point at the sandbox directory}"
: "${COREFLAME_DIR:?COREFLAME_DIR must point at the built shell}"

real_runtime="$XDG_RUNTIME_DIR"
export XDG_RUNTIME_DIR="$NEST/run"
export XDG_CONFIG_HOME="$NEST/config"
export XDG_STATE_HOME="$NEST/state"
export XDG_CACHE_HOME="$NEST/cache"
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"
ln -sf "$real_runtime/pipewire-0" "$XDG_RUNTIME_DIR/pipewire-0"
# The Wayland socket is linked in under its own name, since the backend only accepts a socket name.
ln -sf "$real_runtime/$WAYLAND_DISPLAY" "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"

# One ordinary window, so window corners and the focused-app icon have something to show.
# COREFLAME_DEMO=1 gives it a neutral prompt instead of your own shell, for screenshots.
for term in foot kitty ghostty alacritty ptyxis; do
    if command -v "$term" > /dev/null 2>&1; then
        if [ "${COREFLAME_DEMO:-0}" = 1 ] && [ "$term" = kitty ]; then
            (sleep 4; cd /; PS1='okhema > ' exec kitty sh -c 'printf "\n  33,550,336 cycles, and one more.\n\n"; exec sh') > /dev/null 2>&1 &
        else
            (sleep 4; exec "$term") > /dev/null 2>&1 &
        fi
        break
    fi
done

env | grep -E '^(WAYLAND_DISPLAY|NIRI_SOCKET|XDG_)' > "$NEST/env.txt"
# With COREFLAME_PRIVATE_BUS=1 the sandbox gets its own session bus, so its shell owns the
# notification service there and `notify-send` can reach it (address saved in $NEST/bus).
# Media players and tray icons from the real session are not visible in that mode.
if [ "${COREFLAME_PRIVATE_BUS:-0}" = 1 ]; then
    exec dbus-run-session -- sh -c 'echo "$DBUS_SESSION_BUS_ADDRESS" > "$NEST/bus"; exec dms run -c "$COREFLAME_DIR"' > "$NEST/dms.log" 2>&1
fi
exec dms run -c "$COREFLAME_DIR" > "$NEST/dms.log" 2>&1
