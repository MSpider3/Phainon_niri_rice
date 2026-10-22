#!/bin/sh
# After a form change: quit GTK4 apps that are running only in the background, so the next time
# they open they start fresh and read the new form's colours (GTK4 reads them at start only).
#
# A process is quit only when all of these hold:
#   - it is yours and was started in GTK's background-service mode (--gapplication-service),
#     so D-Bus starts it again on demand;
#   - it uses GTK4;
#   - it has no window open (the pids of processes with windows are given as arguments).
# Exits 1 when a candidate was skipped because a window is open, so the shell can try again
# once windows close; 0 otherwise.
#
# usage: gtk-refresh.sh [pid-with-a-window ...]
skipped=0
for pid in $(pgrep -u "$(id -u)" -f -- "--gapplication-service"); do
    [ "$pid" = "$$" ] && continue
    grep -q "libgtk-4" "/proc/$pid/maps" 2> /dev/null || continue
    case " $* " in
    *" $pid "*)
        skipped=1
        continue
        ;;
    esac
    kill -TERM "$pid" 2> /dev/null
done
exit "$skipped"
