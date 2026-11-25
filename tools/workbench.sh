#!/bin/sh
# The workbench: the game in a window that rebuilds and swaps in new code
# whenever a file in src/game, src/workbench or data is saved, with Prosio
# where he was. Desktop only. See src/workbench/host/main.odin.
#
#   tools/workbench.sh
set -e
cd "$(dirname "$0")/.."
mkdir -p build/workbench
odin build src/workbench/host -out:build/workbench/workbench -vet
exec build/workbench/workbench "$@"
