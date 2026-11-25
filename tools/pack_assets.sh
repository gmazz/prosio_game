#!/bin/sh
# Packs the models in assets/<name>/<name>.glb into the files the game loads
# (assets/<name>/*.bin, info.json) and the tables that name them
# (src/game/*_assets.odin). The build scripts and tools/check.sh run it; it
# writes a file only when what it holds changes. See tools/pack_assets/main.odin.
set -e
cd "$(dirname "$0")/.."
mkdir -p build/tools
odin build tools/pack_assets -out:build/tools/pack_assets -vet
build/tools/pack_assets .
