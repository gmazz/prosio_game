#!/bin/sh
# Turns the game's data files (data/tuning/*.json, data/text/*.json) into
# the Odin code the game is built from (src/game/gen_*.odin). The build
# scripts and tools/check.sh run it first; run it by hand after editing a
# data file only if you build some other way. See tools/gen_data/main.odin.
set -e
cd "$(dirname "$0")/.."
mkdir -p build/tools
odin build tools/gen_data -out:build/tools/gen_data -vet
build/tools/gen_data .
