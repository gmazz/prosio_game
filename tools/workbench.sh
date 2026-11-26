#!/bin/sh
# The workbench: the game in a window that rebuilds and swaps in new code
# whenever a file in src/game, src/workbench or data is saved, with Prosio
# where he was. Desktop only. See src/workbench/host/main.odin. Started by
# a program, WORKBENCH_UNFOCUSED=1 opens it without taking the keyboard. One runs to a
# folder (build/workbench); WORKBENCH_OUT=build/workbench_2 starts another
# beside it, with its own command and answer files there.
#
#   tools/workbench.sh
set -e
cd "$(dirname "$0")/.."
OUT=${WORKBENCH_OUT:-build/workbench}
mkdir -p "$OUT"
odin build src/workbench/host -out:"$OUT/workbench" -vet
exec "$OUT/workbench" "$@"
