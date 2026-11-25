#!/bin/sh
# Builds the native game into build/desktop/prosio.
set -e
cd "$(dirname "$0")"
mkdir -p build/desktop
sh tools/gen_data.sh # data/*.json into src/game/gen_*.odin
sh tools/pack_assets.sh # assets/<name>/<name>.glb into what the game loads
OUT=build/desktop/prosio
if [ "${1:-}" = "--lab" ]; then
	OUT=build/desktop/prosio-lab
	set -- -define:PROSIO_LAB=true
else
	set --
fi
odin build src/main_desktop -out:"$OUT" -o:speed -vet "$@"
echo "Built $OUT"
