#!/bin/sh
# Packs the trees the game draws from the low-poly nature packs in the
# asset folder (several broadleaves, birches, round trees and pines), and
# the rocks, grass and ferns, which are packed the same way (a rock's stone
# is its "bark", its moss its "leaves"; grass and ferns are all leaves), into
# assets/trees/, and writes their tables to src/game/tree_assets.odin. See
# tools/pack_trees.py.
#
#   tools/pack_trees.sh [the asset folder, with nature_1 and nature_2 in it]
#
# Blender is looked for at $BLENDER, then on the path, then where macOS
# keeps it.
set -e
cd "$(dirname "$0")/.."
ASSETS="${1:-$HOME/Desktop/3D_assets}"
BLENDER="${BLENDER:-$(command -v blender || echo /Applications/Blender.app/Contents/MacOS/Blender)}"
# name:file, the file in the asset folder. nature_1 is Quaternius' Ultimate
# Nature Pack, nature_2 his Stylized Tree Pack.
MODELS="
broad1:nature_2/Tree_2.blend
broad2:nature_2/Tree_3.blend
broad3:nature_2/Tree_5.blend
broad4:nature_2/Tree_9.blend
common1:nature_1/CommonTree_1.blend
common2:nature_1/CommonTree_2.blend
birch1:nature_1/BirchTree_3.blend
birch2:nature_1/BirchTree_5.blend
round1:nature_2/Tree_4.blend
round2:nature_2/Tree_10.blend
round3:nature_2/Tree_7.blend
pine1:nature_1/PineTree_2.blend
pine2:nature_1/PineTree_3.blend
pine3:nature_1/PineTree_4.blend
pine4:nature_2/Pine_2.blend
pine5:nature_2/Pine_5.blend
rock1:nature_1/Rock_1.blend
rock2:nature_1/Rock_3.blend
rock3:nature_1/Rock_5.blend
rock4:nature_1/Rock_6.blend
rock5:nature_1/Rock_7.blend
rockmoss1:nature_1/Rock_Moss_2.blend
rockmoss2:nature_1/Rock_Moss_3.blend
rockmoss3:nature_1/Rock_Moss_5.blend
rockmoss4:nature_1/Rock_Moss_6.blend
grass1:nature_1/Grass_Short.blend
grass2:nature_1/Grass.blend
grass3:nature_1/Grass_2.blend
fern1:nature_1/Plant_1.blend
fern2:nature_1/Plant_3.blend
fern3:nature_1/Plant_4.blend
stump1:nature_1/TreeStump_Moss.blend
stump2:nature_1/TreeStump.blend
log1:nature_1/WoodLog_Moss.blend
bush1:nature_1/Bush_1.blend
bush2:nature_1/Bush_2.blend
"
names=""
for spec in $MODELS; do
	name=${spec%%:*}
	"$BLENDER" -b "$ASSETS/${spec#*:}" --python tools/pack_trees.py -- "$name" assets/trees 2>&1 | grep -E "PACKED|Error|Traceback" || true
	names="$names $name"
done
python3 - $names > src/game/tree_assets.odin <<'EOF2'
import json, sys
names = sys.argv[1:]
infos = [json.load(open("assets/trees/%s.json" % n)) for n in names]
print("package game\n")
print("// Made by tools/pack_trees.sh from the tree models: do not edit.\n")
print("Tree_Model_Kind :: enum {%s}" % ", ".join(n.capitalize() for n in names))
print("TREE_MAX_VERTS :: %d\n" % max(i["bark"] + i["leaves"] for i in infos))
print("TREE_MODELS := [Tree_Model_Kind]Tree_Model {")
for n, i in zip(names, infos):
    print("\t.%s = {" % n.capitalize())
    print('\t\tname = "%s", // from %s' % (n, i["source"]))
    print("\t\tbark = %d," % i["bark"])
    print("\t\tleaves = %d," % i["leaves"])
    print("\t\theight = %g," % round(i["height"], 4))
    print("\t\tcrown_low = %g," % round(i["crown_low"], 4))
    print("\t\tcrown_high = %g," % round(i["crown_high"], 4))
    print("\t\tcrown_r = %g," % round(i["crown_r"], 4))
    print("\t\tbark_color = {%d, %d, %d, %d}, // (none: the game's own)" % (tuple(i["bark_color"]) + (255 if any(i["bark_color"]) else 0,)))
    print("\t\tleaf_color = {%d, %d, %d, %d}," % (tuple(i["leaf_color"]) + (255 if any(i["leaf_color"]) else 0,)))
    print("\t\tradius = %g," % round(i["radius"], 4))
    print("\t\tspots = []Vec3{%s}," % ", ".join("{%g, %g, %g}" % tuple(round(x, 4) for x in s) for s in i["spots"]))
    print('\t\tmesh = #load("../../assets/trees/%s.bin", [][9]f32),' % n)
    print("\t},")
print("}")
EOF2
echo "Wrote src/game/tree_assets.odin"
