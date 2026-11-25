#!/bin/sh
# Builds the browser game into build/web. Open it through a local web server,
# for example: python3 -m http.server --directory build/web
#
# Needs raylib compiled for the web. Homebrew's Odin does not include it, so
# put the file at lib/libraylib.web.a (or point RAYLIB_WEB_LIB at it).
set -e
cd "$(dirname "$0")"
LIB="${RAYLIB_WEB_LIB:-lib/libraylib.web.a}"
if [ ! -f "$LIB" ]; then
	echo "Missing $LIB: raylib compiled for the web is needed." >&2
	exit 1
fi
sh tools/gen_data.sh # data/*.json into src/game/gen_*.odin
sh tools/pack_assets.sh # assets/<name>/<name>.glb into what the game loads
OUT=build/web
if [ "${1:-}" = "--lab" ]; then
	OUT=build/web-lab
	set -- -define:PROSIO_LAB=true
else
	set --
fi
mkdir -p "$OUT"
odin build src/main_web -target:js_wasm32 -build-mode:obj -o:size -vet \
	-define:RAYLIB_WASM_LIB=env.o -out:"$OUT/game.wasm.o" "$@"
cp "$(odin root)/core/sys/wasm/js/odin.js" "$OUT/odin.js"
emcc -o "$OUT/index.html" "$OUT/game.wasm.o" "$LIB" -Os \
	-sUSE_GLFW=3 -sWARN_ON_UNDEFINED_SYMBOLS=0 -sDECLARE_ASM_MODULE_EXPORTS=0 \
	--shell-file src/main_web/index_template.html
rm "$OUT/game.wasm.o"
echo "Built $OUT/index.html"
