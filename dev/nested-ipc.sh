#!/bin/sh
# Sends a `dms ipc call ...` to the sandboxed shell instead of the real one.
# usage: dev/nested-ipc.sh [sandbox-dir] <target> <function> [args]
#   dev/nested-ipc.sh /tmp/cfn form set phainon
set -eu
NEST="${TMPDIR:-/tmp}/coreflame-nest"
if [ -d "${1:-}" ]; then NEST="$1"; shift; fi
XDG_RUNTIME_DIR="$NEST/run" XDG_CONFIG_HOME="$NEST/config" XDG_STATE_HOME="$NEST/state" XDG_CACHE_HOME="$NEST/cache" exec dms ipc call "$@"
