#!/bin/sh
# After a form change: quit GTK apps that are running only in the background, so the next time
# they open they start fresh and read the new form's colours and stylesheet (GTK reads them at
# start only).
#
# A process is quit only when all of these hold:
#   - it is yours and was started in GTK's background-service mode (--gapplication-service),
#     so D-Bus starts it again on demand;
#   - it uses GTK 3 or 4;
#   - it has no window open (the pids of processes with windows are given as arguments).
# The file picker apps open through the desktop portal (xdg-desktop-portal-gtk) is restarted the
# same way, unless a picker is open.
# Exits 1 when a candidate was skipped because a window is open, so the shell can try again
# once windows close; 0 otherwise.
#
# usage: gtk-refresh.sh [pid-with-a-window ...]
skipped=0
has_window() {
    case " $* " in *" $pid "*) return 0 ;; esac
    return 1
}
for pid in $(pgrep -u "$(id -u)" -f -- "--gapplication-service"); do
    [ "$pid" = "$$" ] && continue
    grep -qE "libgtk-(3|4)" "/proc/$pid/maps" 2> /dev/null || continue
    if has_window "$@"; then
        skipped=1
        continue
    fi
    kill -TERM "$pid" 2> /dev/null
done
pid=$(pgrep -u "$(id -u)" -f -- "/xdg-desktop-portal-gtk$" | head -n 1)
if [ -n "$pid" ]; then
    if has_window "$@"; then
        skipped=1
    else
        systemctl --user try-restart xdg-desktop-portal-gtk.service 2> /dev/null
    fi
fi
exit "$skipped"
