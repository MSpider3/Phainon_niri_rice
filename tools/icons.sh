#!/bin/sh
# Installs the icon, folder and cursor packs the three forms use.
#
# Base pack: Gruvbox Plus (github.com/SylEleuth/gruvbox-plus-icon-pack, GPL-3.0), whose app icons
# sit on muted paper-and-charcoal plates. On top of it this makes three small icon themes that
# only replace the folder set, tinted with each form's own primary colour from the theme file:
#
#   Coreflame-Phainon   lapis folders, light variant of the pack
#   Coreflame-Khaslana  gold folders
#   Coreflame-Reaver    bronze folders
#
# usage: tools/icons.sh [path to a copy of the gruvbox-plus-icon-pack repository]
# Without a path, the pack is downloaded once into ~/.cache/coreflame-icons.
# Everything goes into ~/.local/share/icons; delete the folders there to remove it.
set -eu

here=$(cd "$(dirname "$0")/.." && pwd)
icons="${XDG_DATA_HOME:-$HOME/.local/share}/icons"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/coreflame-icons"
source_dir="${1:-$cache/SylEleuth_gruvbox-plus-icon-pack}"
mkdir -p "$icons"

if [ ! -d "$icons/Gruvbox-Plus-Dark" ] || [ ! -d "$icons/Gruvbox-Plus-Light" ]; then
    if [ ! -d "$source_dir/Gruvbox-Plus-Dark" ]; then
        mkdir -p "$cache"
        git clone --depth 1 https://github.com/SylEleuth/gruvbox-plus-icon-pack "$source_dir"
    fi
    for variant in Gruvbox-Plus-Dark Gruvbox-Plus-Light; do
        rm -rf "$icons/$variant.new"
        cp -a "$source_dir/$variant" "$icons/$variant.new"
        # The shipped cache describes the author's copy; a stale one makes GTK miss icons.
        rm -f "$icons/$variant.new/icon-theme.cache"
        rm -rf "$icons/$variant"
        mv "$icons/$variant.new" "$icons/$variant"
    done
    echo "Gruvbox Plus installed in $icons"
fi

python3 -I - "$here" "$icons" << 'EOF'
import json, os, re, shutil, sys

here, icons = sys.argv[1:3]
base = here + "/icons/gruvbox-plus-folders"
theme = json.load(open(here + "/dms-config/theme/coreflame/theme.json"))
forms = {option["id"]: option for option in theme["variants"]["options"]}

# form id -> (theme folder, display name, palette mode, parent themes)
targets = {
    "phainon": ("Coreflame-Phainon", "Coreflame Phainon", "light", "Gruvbox-Plus-Light,Gruvbox-Plus-Dark"),
    "khaslana": ("Coreflame-Khaslana", "Coreflame Khaslana", "dark", "Gruvbox-Plus-Dark"),
    "reaver": ("Coreflame-Reaver", "Coreflame Flame Reaver", "dark", "Gruvbox-Plus-Dark"),
}

def shade(colour, factor):
    return "#%02x%02x%02x" % tuple(int(int(colour[i:i + 2], 16) * factor) for i in (1, 3, 5))

links = [line.split() for line in open(base + "/links.txt") if line.strip()]
for form, (folder, name, mode, parents) in targets.items():
    primary = forms[form][mode]["primary"]
    out = os.path.join(icons, folder)
    places = out + "/places/scalable"
    shutil.rmtree(out, ignore_errors=True)
    os.makedirs(places)
    for file in sorted(os.listdir(base)):
        if not file.endswith(".svg"):
            continue
        art = open(os.path.join(base, file)).read()
        # The base set is the pack's gold one: #d79921 is the folder face, #b57614 its back and marks.
        art = re.sub("#d79921", primary, art, flags=re.I)
        art = re.sub("#b57614", shade(primary, 0.74), art, flags=re.I)
        open(os.path.join(places, file), "w").write(art)
    for link, to in links:
        os.symlink(to, os.path.join(places, link))
    open(out + "/index.theme", "w").write(
        "[Icon Theme]\nName=%s\nComment=Gruvbox Plus with %s folders in the form's own colour (%s)\n"
        "Inherits=%s,hicolor\nDirectories=places/scalable\n\n"
        "[places/scalable]\nContext=Places\nSize=256\nMinSize=16\nMaxSize=512\nType=Scalable\n" % (name, form, primary, parents))
    print("%s: folders tinted %s" % (folder, primary))
EOF

for theme in Coreflame-Phainon Coreflame-Khaslana Coreflame-Reaver Gruvbox-Plus-Dark Gruvbox-Plus-Light; do
    gtk-update-icon-cache -q -f "$icons/$theme" 2> /dev/null || true
done
# Cursors, one per form: Bibata Modern Ice, Amber and Classic (github.com/ful1e5/Bibata_Cursor, GPL-3.0).
for variant in Bibata-Modern-Ice Bibata-Modern-Amber Bibata-Modern-Classic; do
    if [ ! -d "$icons/$variant" ]; then
        curl -sL "https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/$variant.tar.xz" | tar -xJ -C "$icons"
    fi
done

# GTK theme the forms set (adw-gtk3 / adw-gtk3-dark, github.com/lassekongo83/adw-gtk3, LGPL-2.1).
# Without it GTK3 apps fall back to plain light Adwaita and DMS skips its live GTK refresh.
themes="${XDG_DATA_HOME:-$HOME/.local/share}/themes"
if [ ! -d "$themes/adw-gtk3" ] && [ ! -d /usr/share/themes/adw-gtk3 ]; then
    mkdir -p "$themes"
    curl -sL "https://github.com/lassekongo83/adw-gtk3/releases/download/v6.5/adw-gtk3v6.5.tar.xz" | tar -xJ -C "$themes"
fi

echo "Icon and cursor themes ready. The forms pick them up on the next form change or shell start."
