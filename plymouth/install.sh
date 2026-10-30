#!/bin/sh
# Boot splash for the Coreflame rice. Needs root, and rebuilds the initramfs (about a minute).
#
#   sudo sh plymouth/install.sh phainon | khaslana | reaver
#   sudo sh plymouth/install.sh recurrence [video]
#                                             the Eternal Recurrence cinematic with this boot's
#                                             cycle number (default video: cinematics/boot.mp4)
#   sudo sh plymouth/install.sh revert        put back the splash you had before
#
# The splash is fixed at boot, so pick one; it does not switch with the desktop.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
themes=/usr/share/plymouth/themes
saved=/var/lib/coreflame-plymouth-before
unit=/etc/systemd/system/coreflame-recurrence.service
counter=/usr/local/libexec/coreflame-recurrence-count

if [ "$(id -u)" -ne 0 ]; then
    echo "Run with sudo." >&2
    exit 1
fi

# The service that sends the cycle number to the splash; only the recurrence splash uses it.
drop_counter() {
    if [ -f "$unit" ]; then
        systemctl disable coreflame-recurrence.service 2> /dev/null || true
        rm -f "$unit" "$counter"
        systemctl daemon-reload
    fi
}

case "${1:-}" in
phainon | khaslana | reaver | recurrence)
    # The themes are Plymouth "script" themes; Fedora ships that plugin separately.
    if [ ! -e /usr/lib64/plymouth/script.so ] && [ ! -e /usr/lib/plymouth/script.so ]; then
        dnf install -y plymouth-plugin-script
    fi
    if [ "$1" = recurrence ]; then
        video="${2:-$here/../cinematics/boot.mp4}"
        user_home=$(getent passwd "${SUDO_USER:-}" | cut -d: -f6)
        [ -f "$video" ] || { echo "No video at $video" >&2; exit 1; }
        [ -n "${SUDO_USER:-}" ] && [ -d "$user_home" ] || { echo "Run it with sudo from your own account, so the splash can find your cycle count." >&2; exit 1; }
        command -v ffmpeg > /dev/null 2>&1 || { echo "Missing: ffmpeg. Install it first." >&2; exit 1; }
    fi
    [ -f "$saved" ] || plymouth-set-default-theme > "$saved"
    rm -rf "$themes/coreflame-$1"
    cp -r "$here/coreflame-$1" "$themes/"
    if [ "$1" = recurrence ]; then
        # 15 frames a second at 960x540 in 256 colours (about 30 MB in the initramfs), with the
        # same 2^0.2 zoom the shell gives the clip, so its black side bars fall off screen.
        echo "Turning the video into splash frames..."
        ffmpeg -v error -i "$video" -vf "crop=trunc(iw/pow(2\,0.2)/2)*2:trunc(ih/pow(2\,0.2)/2)*2,fps=15,scale=960:540:flags=lanczos,split[a][b];[a]palettegen=max_colors=256:stats_mode=full[p];[b][p]paletteuse=dither=sierra2_4a" \
            -start_number 1 "$themes/coreflame-recurrence/f%d.png" ||
            { echo "ffmpeg could not read $video. Fedora's ffmpeg-free has no H.264; install ffmpeg from RPM Fusion." >&2; exit 1; }
        install -m 755 "$here/coreflame-recurrence-count" "$counter"
        sed "s|@HOME@|$user_home|g" "$here/coreflame-recurrence.service" > "$unit"
        systemctl daemon-reload
        systemctl enable coreflame-recurrence.service
    else
        drop_counter
    fi
    plymouth-set-default-theme -R "coreflame-$1"
    echo "Boot splash: coreflame-$1. It shows from the next boot."
    ;;
revert)
    previous=$(cat "$saved" 2> /dev/null || echo bgrt)
    drop_counter
    plymouth-set-default-theme -R "$previous"
    rm -rf "$themes"/coreflame-* "$saved"
    echo "Boot splash back to $previous."
    ;;
*)
    echo "usage: sudo sh $0 phainon | khaslana | reaver | recurrence [video] | revert" >&2
    exit 2
    ;;
esac
