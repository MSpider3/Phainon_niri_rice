#!/bin/sh
# Boot splash for one Coreflame form. Needs root, and rebuilds the initramfs (about a minute).
#
#   sudo sh plymouth/install.sh phainon | khaslana | reaver
#   sudo sh plymouth/install.sh revert        put back the splash you had before
#
# The splash is fixed at boot, so pick one form; it does not switch with the desktop.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
themes=/usr/share/plymouth/themes
saved=/var/lib/coreflame-plymouth-before

if [ "$(id -u)" -ne 0 ]; then
    echo "Run with sudo." >&2
    exit 1
fi

case "${1:-}" in
phainon | khaslana | reaver)
    # The themes are Plymouth "script" themes; Fedora ships that plugin separately.
    if [ ! -e /usr/lib64/plymouth/script.so ] && [ ! -e /usr/lib/plymouth/script.so ]; then
        dnf install -y plymouth-plugin-script
    fi
    [ -f "$saved" ] || plymouth-set-default-theme > "$saved"
    rm -rf "$themes/coreflame-$1"
    cp -r "$here/coreflame-$1" "$themes/"
    plymouth-set-default-theme -R "coreflame-$1"
    echo "Boot splash: coreflame-$1. It shows from the next boot."
    ;;
revert)
    previous=$(cat "$saved" 2> /dev/null || echo bgrt)
    plymouth-set-default-theme -R "$previous"
    rm -rf "$themes"/coreflame-* "$saved"
    echo "Boot splash back to $previous."
    ;;
*)
    echo "usage: sudo sh $0 phainon | khaslana | reaver | revert" >&2
    exit 2
    ;;
esac
