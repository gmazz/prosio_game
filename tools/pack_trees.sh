#!/bin/sh
# Packs the trees the game draws from the tree models in the asset folder
# (low-poly Blender files): two broadleaves (a round one, and a lumpy one
# whose thousands of leaves are melted into one crown) and two pines, into
# assets/trees/, and writes their tables to src/game/tree_assets.odin. See
# tools/pack_trees.py.
#
#   tools/pack_trees.sh [folder with the tree .blend files]
#
# Blender is looked for at $BLENDER, then on the path, then where macOS
# keeps it.
set -e
cd "$(dirname "$0")/.."
TREES="${1:-$HOME/Desktop/3D_assets/trees}"
BLENDER="${BLENDER:-$(command -v blender || echo /Applications/Blender.app/Contents/MacOS/Blender)}"
pack() {
	"$BLENDER" -b "$TREES/$2" --python tools/pack_trees.py -- "$1" assets/trees 2>&1 | grep -E "PACKED|Error|Traceback" || true
}
pack round "tree-low-poly_1a5a63c3-4ea4-471d-99b8-1cc4321bd9af.blend"
pack lumpy "low-poly-sheesham-tree_2f5ad2ca-4dc1-4863-b37b-a0f09fec1c00.blend"
pack pine "low-poly-pine-tree_cb631e57-dffc-4130-b403-92011cbcd245.blend"
pack fir "tree_3ef9ae8b-ee50-4346-be64-62acae0b221b.blend"
python3 - round lumpy pine fir > src/game/tree_assets.odin <<'EOF'
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
    print("\t\tspots = []Vec3{%s}," % ", ".join("{%g, %g, %g}" % tuple(round(x, 4) for x in s) for s in i["spots"]))
    print('\t\tmesh = #load("../../assets/trees/%s.bin", [][9]f32),' % n)
    print("\t},")
print("}")
EOF
echo "Wrote src/game/tree_assets.odin"
