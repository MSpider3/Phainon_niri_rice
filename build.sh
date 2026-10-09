#!/bin/sh
# Assembles the Coreflame shell: the untouched DMS 1.6.2 interface from vendor/,
# with the files in overlay/ laid on top. Safe to re-run after every edit;
# only files whose content changed are touched, so a running shell reloads once.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
dest="${1:-${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/coreflame}"
stage="${XDG_CACHE_HOME:-$HOME/.cache}/coreflame-build"

mkdir -p "$stage" "$dest"
rsync -a --delete --chmod=Du=rwx,Dgo=rx,Fu=rwx,Fgo=rx "$here/vendor/dms-1.6.2/" "$stage/"
rsync -a --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r "$here/overlay/" "$stage/"
rsync -a --delete --checksum "$stage/" "$dest/"
echo "Coreflame shell built at $dest"
