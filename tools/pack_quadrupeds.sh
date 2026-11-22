#!/bin/sh
# Packs the four-legged animals the game draws from the animated animal pack
# (Blender files sharing one skeleton): the goat and the billy goat from the
# deer, and the pack's fox (as packfox, beside the fox of the asset pilot in
# assets/fox, which this leaves alone), into assets/<name>/, and writes their
# tables to src/game/quadruped_assets.odin. See tools/pack_quadruped.py.
#
#   tools/pack_quadrupeds.sh [folder with the pack's .blend files]
#
# Blender is looked for at $BLENDER, then on the path, then where macOS
# keeps it.
set -e
cd "$(dirname "$0")/.."
PACK="${1:-$HOME/Desktop/3D_assets/animated_animals_blender}"
BLENDER="${BLENDER:-$(command -v blender || echo /Applications/Blender.app/Contents/MacOS/Blender)}"
for spec in goat:Deer billy:Deer packfox:Fox; do
	name=${spec%%:*}
	source=${spec#*:}
	"$BLENDER" -b "$PACK/$source.blend" --python tools/pack_quadruped.py -- "$name" "assets/$name" 2>&1 | grep -E "PACKED|Error|Traceback" || true
done
python3 tools/quadruped_odin.py goat billy packfox:PACK_FOX > src/game/quadruped_assets.odin
echo "Wrote src/game/quadruped_assets.odin"
