#!/bin/sh
# Builds the native game into build/desktop/prosio.
set -e
cd "$(dirname "$0")"
mkdir -p build/desktop
sh tools/gen_data.sh # data/*.json into src/game/gen_*.odin
odin build src/main_desktop -out:build/desktop/prosio -o:speed -vet
echo "Built build/desktop/prosio"
