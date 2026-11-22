# Turns a tree from the asset folder into what the game draws. Run inside
# Blender (see tools/pack_trees.sh); it writes
#
#   assets/trees/<name>.bin    every triangle's three corners, 9 floats each:
#                              position, flat normal, smooth normal (for the
#                              outline); the bark first, then the leaves
#   assets/trees/<name>.json   how many corners are bark and leaves, how tall
#                              the tree is, where its crown starts and ends
#                              and how wide it is, and spots on the crown
#                              where apples can hang
#
# in the game's frame (+Y up, metres as modelled: the game scales each tree
# to its kind's height), the foot of the trunk at the origin. Nothing is
# saved back into the .blend file.
#
#   Blender -b tree.blend --python tools/pack_trees.py -- round assets/trees
import bpy, sys, os, math, json, struct
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
NAME, OUT = argv[0], argv[1]
os.makedirs(OUT, exist_ok=True)

# Which materials are bark and which leaves, and anything to do first.
RECIPES = {
    "round": dict(bark=["tronco normal"], leaves=["folhas"]),
    "lumpy": dict(bark=["Material"], leaves=["Material.001"], remesh=("Leaves", 0.5, 0.15)),
    "pine": dict(bark=["Material.001"], leaves=["Material"]),
    "fir": dict(bark=["Material.001"], leaves=["Material.002"]),
}
R = RECIPES[NAME]

if "remesh" in R:
    # A crown made of thousands of loose leaves becomes one lumpy whole:
    # melted together, then simplified.
    obj, voxel, ratio = R["remesh"]
    o = bpy.data.objects[obj]
    m = o.modifiers.new("remesh", 'REMESH')
    m.mode, m.voxel_size = 'VOXEL', voxel
    d = o.modifiers.new("simplify", 'DECIMATE')
    d.ratio = ratio

TO_GAME = Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, -1, 0, 0), (0, 0, 0, 1)))
deps = bpy.context.evaluated_depsgraph_get()
parts = {"bark": [], "leaves": []}
for o in bpy.data.objects:
    if o.type not in ('MESH', 'CURVE'):
        continue
    e = o.evaluated_get(deps)
    me = e.to_mesh()
    me.calc_loop_triangles()
    W = TO_GAME @ o.matrix_world
    W3 = W.to_3x3()
    for tri in me.loop_triangles:
        mat = me.materials[tri.material_index].name if len(me.materials) else ""
        part = "bark" if mat in R["bark"] else ("leaves" if mat in R["leaves"] else None)
        if part is None:
            continue
        fn = (W3 @ tri.normal).normalized()
        for vi in tri.vertices:
            v = me.vertices[vi]
            parts[part].append((W @ v.co, fn, (W3 @ v.normal).normalized()))
    e.to_mesh_clear()

# The foot of the trunk at the origin.
bark = [c[0] for c in parts["bark"]]
base = min(p.y for p in bark)
low = [p for p in bark if p.y < base + 0.3]
axis = Vector((sum(p.x for p in low) / len(low), base, sum(p.z for p in low) / len(low)))
rows = []
for part in ("bark", "leaves"):
    for p, fn, sn in parts[part]:
        q = p - axis
        rows.append(list(q) + list(fn) + list(sn))
with open(os.path.join(OUT, NAME + ".bin"), "wb") as f:
    for r in rows:
        f.write(struct.pack("<9f", *r))

leaves = [(p - axis, fn) for p, fn, _ in parts["leaves"]]
crown_low = min(p.y for p, _ in leaves)
crown_high = max(p.y for p, _ in leaves)
height = max(crown_high, max(p.y - axis.y for p in bark))
crown_r = max(math.hypot(p.x, p.z) for p, _ in leaves)

# Spots on the upper slope of the crown for apples: spread out, a little
# proud of the leaves.
candidates = []
for i in range(0, len(leaves), 3):
    tri = leaves[i:i + 3]
    c = (tri[0][0] + tri[1][0] + tri[2][0]) / 3
    n = tri[0][1]
    if n.y > 0.25 and math.hypot(c.x, c.z) > 0.45 * crown_r:
        candidates.append(c + n * 0.04 * height)
spots = []
if candidates:
    spots.append(max(candidates, key=lambda c: math.hypot(c.x, c.z)))
    while len(spots) < min(8, len(candidates)):
        spots.append(max(candidates, key=lambda c: min((c - s).length for s in spots)))

info = dict(
    name=NAME,
    source=os.path.basename(bpy.data.filepath),
    bark=len(parts["bark"]),
    leaves=len(parts["leaves"]),
    height=height,
    crown_low=crown_low,
    crown_high=crown_high,
    crown_r=crown_r,
    spots=[list(s) for s in spots],
)
with open(os.path.join(OUT, NAME + ".json"), "w") as f:
    json.dump(info, f, indent=1)
print("PACKED", NAME, (len(parts["bark"]) + len(parts["leaves"])) // 3, "triangles, height %.2f, crown %.2f to %.2f, radius %.2f" % (height, crown_low, crown_high, crown_r))
