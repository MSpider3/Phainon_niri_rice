#!/bin/sh
# Copies the Coreflame trial theme and form-switch plugin into the DMS config
# and asks the running shell to pick the plugin up. Safe to re-run after edits.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
cfg="${XDG_CONFIG_HOME:-$HOME/.config}/dms"

mkdir -p "$cfg/themes/coreflame" "$cfg/plugins/coreflameForms"
cp "$here"/theme/coreflame/* "$cfg/themes/coreflame/"
cp "$here"/plugin/coreflameForms/* "$cfg/plugins/coreflameForms/"

dms ipc call plugin-scan scan
echo "Installed. Enable once with: dms ipc call plugins enable coreflameForms"
echo "Then: dms ipc call form set phainon | khaslana | reaver   (form off to go back)"
