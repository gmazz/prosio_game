#!/bin/sh
# Builds the test program and runs it. With no arguments it runs the check
# suite; "autoplay" lets a bot play (see src/check/autoplay.odin); "mix"
# says what bowls of things mix into (see src/check/mix.odin):
#
#   tools/check.sh
#   tools/check.sh autoplay --minutes 30 --seed 3
#   tools/check.sh mix "500g flour, 300ml water" --mix 8 --bake 200 40
set -e
cd "$(dirname "$0")/.."
mkdir -p build/check
sh tools/gen_data.sh # data/*.json into src/game/gen_*.odin
sh tools/pack_assets.sh # assets/<name>/<name>.glb into what the game loads
odin build src/check -out:build/check/prosio-check -vet -define:PROSIO_BASE_DATA=true # the skin's data, for its rules (the game itself leaves it out)
exec build/check/prosio-check "$@"
