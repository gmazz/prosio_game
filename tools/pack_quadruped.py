# Turns an animal from the animated animal pack (Blender files sharing one
# four-legged skeleton) into what the game draws: run inside Blender, it
# reshapes the animal into the game's rounder, cuter build, adds what the
# game's kind needs (a goat's horns and beard), and writes
#
#   mesh.bin      every triangle's three corners, 17 floats each: position,
#                 flat normal, smooth normal (for the outline), four bone
#                 numbers and their four weights; grouped by material
#   rest.bin      each bone's rest frame, inverted (16 floats)
#   frames.bin    each animation, sampled: each bone's frame (12 floats)
#   info.json     bones, material groups, animations and sockets
#
# in the game's model frame: metres of the animal's own size (the game
# scales it by its radius), +Y up, +Z towards the muzzle, feet on y = 0.
# tools/pack_quadrupeds.sh runs it for each animal and makes the Odin tables.
#
#   Blender -b Deer.blend --python tools/pack_quadruped.py -- goat assets/goat
#
# Nothing is saved back into the .blend file.
import bpy, bmesh, sys, os, math, json, struct
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
NAME, OUT = argv[0], argv[1]
os.makedirs(OUT, exist_ok=True)

# How each kind is reshaped (bone scales, as x, length, z), what it gets,
# and how long it is from tail to muzzle in the game's model units.
RECIPES = {
    "goat": dict(head=1.6, neck=(1.15, 0.7, 1.15), torso=(1.3, 1.0, 1.3), legs=0.62, horns="short", beard=0.3, length=2.6),
    "billy": dict(head=1.5, neck=(1.3, 0.7, 1.3), torso=(1.45, 1.0, 1.45), legs=0.66, horns="curled", beard=0.5, length=2.6),
    "packfox": dict(head=1.55, neck=(1.15, 0.8, 1.15), torso=(1.3, 1.0, 1.3), legs=0.7, horns=None, beard=0, length=3.2, tail=1.3),
}
R = RECIPES[NAME]
CLIPS = ["Idle", "Walk", "Gallop", "Eating", "Idle_HitReact_Left", "Death", "Attack_Headbutt", "Attack", "Gallop_Jump"]
SAMPLE_FPS = 20

scene = bpy.context.scene
arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
meshes = [o for o in bpy.data.objects if o.type == 'MESH']
bpy.context.view_layer.objects.active = arm
if arm.animation_data:
    arm.animation_data.action = None

# 1. The rounder build: scale bones each by itself (nothing compounds down a
# chain), with the leg IK off; carry each foot's IK target up with the
# shortened leg, so the hooves stay on the legs; bake that into the mesh and
# make it the new rest pose.
LEGS = {"L": [], "R": []}
for b in arm.data.bones:
    b.inherit_scale = 'NONE'
for pb in arm.pose.bones:
    for c in pb.constraints:
        c.mute = True
    pb.location = (0, 0, 0)
    pb.rotation_quaternion = (1, 0, 0, 0)
    pb.rotation_euler = (0, 0, 0)
    pb.scale = (1, 1, 1)

def scale(name, s):
    if name in arm.pose.bones:
        arm.pose.bones[name].scale = s

h = R["head"]
scale("Head", (h, h, h))
for n in ("Neck1", "Neck2", "Neck3"):
    scale(n, R["neck"])
for n in ("Back", "Torso", "Torso2", "Torso3"):
    scale(n, R["torso"])
for side in ("L", "R"):
    for n in ("FrontUpperLeg", "FrontLowerLeg", "BackLeg", "BackUpperLeg", "BackLowerLeg"):
        scale(n + "." + side, (1.25, R["legs"], 1.25))
if R.get("tail"):
    for i in range(1, 10):
        scale("Tail%d" % i, (R["tail"], 1, R["tail"]))
bpy.context.view_layer.update()
for side in ("L", "R"):
    for lower, ik in (("FrontLowerLeg", "IKFrontLeg"), ("BackLowerLeg", "IKBackLeg")):
        pb, ikb = arm.pose.bones[lower + "." + side], arm.pose.bones[ik + "." + side]
        delta = pb.tail - ikb.head  # armature space
        ikb.location = ikb.bone.matrix_local.to_3x3().inverted() @ delta
bpy.context.view_layer.update()
for m in meshes:
    for mod in list(m.modifiers):
        if mod.type == 'ARMATURE':
            with bpy.context.temp_override(object=m, active_object=m):
                bpy.ops.object.modifier_apply(modifier=mod.name)
bpy.ops.object.mode_set(mode='POSE')
bpy.ops.pose.armature_apply(selected=False)
bpy.ops.object.mode_set(mode='OBJECT')
for b in arm.data.bones:
    b.inherit_scale = 'FULL'
for pb in arm.pose.bones:
    for c in pb.constraints:
        c.mute = False
for m in meshes:
    mod = m.modifiers.new("Armature", 'ARMATURE')
    mod.object = arm

# 2. What this kind wears on its head, weighted wholly to the head bone.
def head_points():
    main = max(meshes, key=lambda o: len(o.data.vertices))
    g = main.vertex_groups.get("Head")
    pts = []
    for v in main.data.vertices:
        for ge in v.groups:
            if ge.group == g.index and ge.weight > 0.5:
                pts.append(main.matrix_world @ v.co)
    return pts

def add_part(name, material, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    mat = bpy.data.materials.get(material) or bpy.data.materials.new(material)
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    vg = ob.vertex_groups.new(name="Head")
    vg.add(list(range(len(me.vertices))), 1.0, 'REPLACE')
    mod = ob.modifiers.new("Armature", 'ARMATURE')
    mod.object = arm
    meshes.append(ob)

def tube(bm, points, radii, sides=6):
    # A tapering tube along points: a ring at each, joined to the next.
    rings = []
    for i, p in enumerate(points):
        d = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
        a = d.orthogonal().normalized()
        b = d.cross(a).normalized()
        rings.append([bm.verts.new(p + (a * math.cos(t * 2 * math.pi / sides) + b * math.sin(t * 2 * math.pi / sides)) * radii[i]) for t in range(sides)])
    for r0, r1 in zip(rings, rings[1:]):
        for t in range(sides):
            bm.faces.new((r0[t], r0[(t + 1) % sides], r1[(t + 1) % sides], r1[t]))
    tip = bm.verts.new(points[-1] + (points[-1] - points[-2]).normalized() * radii[-1] * 1.5)
    for t in range(sides):
        bm.faces.new((rings[-1][t], rings[-1][(t + 1) % sides], tip))
    bm.faces.new(list(reversed(rings[0])))

if R["horns"] or R["beard"]:
    pts = head_points()
    xs = [p.x for p in pts]; ys = [p.y for p in pts]; zs = [p.z for p in pts]
    size = max(max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs))
    top = max(pts, key=lambda p: p.z)
    nose_y = min(ys)  # the muzzle points along -Y here
    up, back = Vector((0, 0, 1)), Vector((0, 1, 0))
    if R["horns"]:
        bm = bmesh.new()
        for side in (-1, 1):
            across = Vector((side, 0, 0))
            base = Vector((side * 0.13 * size, top.y + 0.05 * size, top.z - 0.06 * size))
            if R["horns"] == "short":
                pts_h = [base + (up * 0.85 + back * 0.5 + across * 0.15).normalized() * (k / 4) * 0.42 * size for k in range(5)]
                tube(bm, pts_h, [0.075 * size * (1 - 0.18 * k) for k in range(5)])
            else:
                # Great horns curling back and round, as on the drawn billy goat.
                pts_h = []
                for k in range(10):
                    a = k / 9 * 3.6
                    pts_h.append(base + across * (0.03 * a * size) + up * (0.32 * math.sin(a) * size) + back * (0.3 * (1 - math.cos(a)) * size))
                tube(bm, pts_h, [0.1 * size * (1 - 0.07 * k) for k in range(10)])
        add_part("Horns", "Horn", bm)
    if R["beard"]:
        chin = min((p for p in pts if p.y < nose_y + 0.45 * size), key=lambda p: p.z)
        bm = bmesh.new()
        base = Vector((0, chin.y + 0.05 * size, chin.z + 0.04 * size))
        pts_b = [base + Vector((0, 0.15 * k / 3, -1)).normalized() * (k / 3) * R["beard"] * size for k in range(4)]
        tube(bm, pts_b, [0.07 * size * (1 - 0.25 * k) for k in range(4)])
        add_part("Beard", "Beard", bm)

bpy.context.view_layer.update()

# 3. From Blender's frame to the game's: (x, z, -y), scaled to the kind's
# length, feet on the ground, the middle of its length near the origin.
TO_GAME = Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, -1, 0, 0), (0, 0, 0, 1)))
deps = bpy.context.evaluated_depsgraph_get()
corners = []
for m in meshes:
    e = m.evaluated_get(deps)
    me = e.to_mesh()
    corners += [TO_GAME @ m.matrix_world @ v.co for v in me.vertices]
    e.to_mesh_clear()
lo = Vector([min(c[i] for c in corners) for i in range(3)])
hi = Vector([max(c[i] for c in corners) for i in range(3)])
s = R["length"] / (hi.z - lo.z)
C = Matrix.Translation((0, -lo.y * s, -(lo.z + hi.z) / 2 * s + 0.2)) @ Matrix.Scale(s, 4) @ TO_GAME
C3 = TO_GAME.to_3x3()

bones = list(arm.data.bones)
index = {b.name: i for i, b in enumerate(bones)}

def flat(m4):
    # Column by column, as Odin keeps a matrix.
    return [m4[r][c] for c in range(4) for r in range(4)]

# 4. The mesh: every triangle's corners, by material.
groups = {}
for m in meshes:
    me = m.data
    me.calc_loop_triangles()
    names = {g.index: g.name for g in m.vertex_groups}
    W = C @ m.matrix_world
    for tri in me.loop_triangles:
        mat = m.material_slots[tri.material_index].material.name if m.material_slots else "Main"
        fn = (C3 @ (m.matrix_world.to_3x3() @ tri.normal)).normalized()
        for vi in tri.vertices:
            v = me.vertices[vi]
            sn = (C3 @ (m.matrix_world.to_3x3() @ v.normal)).normalized()
            ws = sorted(((ge.weight, index[names[ge.group]]) for ge in v.groups if names.get(ge.group) in index and ge.weight > 0.001), reverse=True)[:4]
            total = sum(w for w, _ in ws) or 1
            ws = [(w / total, b) for w, b in ws] + [(0.0, 0)] * (4 - len(ws))
            p = W @ v.co
            groups.setdefault(mat, []).append(list(p) + list(fn) + list(sn) + [float(b) for _, b in ws] + [w for w, _ in ws])
group_info = []
with open(os.path.join(OUT, "mesh.bin"), "wb") as f:
    first = 0
    for name in sorted(groups):
        rows = groups[name]
        for r in rows:
            f.write(struct.pack("<17f", *r))
        group_info.append(dict(name=name, first=first, count=len(rows)))
        first += len(rows)

# 5. Bones at rest, and every sampled frame of each animation.
with open(os.path.join(OUT, "rest.bin"), "wb") as f:
    for b in bones:
        f.write(struct.pack("<16f", *flat((C @ arm.matrix_world @ b.matrix_local).inverted())))
clips = []
frame_count = 0
with open(os.path.join(OUT, "frames.bin"), "wb") as f:
    for clip in CLIPS:
        action = bpy.data.actions.get(clip)
        if action is None:
            continue
        if arm.animation_data is None:
            arm.animation_data_create()
        arm.animation_data.action = action
        try:
            if action.slots:
                arm.animation_data.action_slot = action.slots[0]
        except AttributeError:
            pass
        f0, f1 = action.frame_range
        loop = clip not in ("Death", "Idle_HitReact_Left", "Attack_Headbutt", "Attack", "Gallop_Jump")
        n = max(1, round((f1 - f0) / scene.render.fps * SAMPLE_FPS))
        samples = [f0 + (f1 - f0) * k / n for k in range(n if loop else n + 1)]
        # How far the animal goes over the ground in one cycle, if its feet
        # are not to slide: a hind foot, while it is down, goes back under
        # the body as far as the body goes forward; so the cycle covers that
        # distance over the share of the cycle the foot is down.
        foot = "FFB.L" if "FFB.L" in index else "BackLowerLeg.L"
        reach = []
        for t in samples:
            scene.frame_set(int(t), subframe=t - int(t))
            for b in bones:
                m4 = C @ arm.matrix_world @ arm.pose.bones[b.name].matrix
                f.write(struct.pack("<12f", *[m4[r][c] for c in range(4) for r in range(3)]))
            reach.append(C @ arm.matrix_world @ arm.pose.bones[foot].tail)
        # (Measured on a much finer pass than the frames kept: a gallop's
        # foot is down for only a moment.)
        stride = 0.0
        if loop:
            fine = [f0 + (f1 - f0) * k / 240 for k in range(240)]
            reach = []
            for t in fine:
                scene.frame_set(int(t), subframe=t - int(t))
                reach.append(C @ arm.matrix_world @ arm.pose.bones[foot].tail)
            low = min(p.y for p in reach)
            down = [k for k, p in enumerate(reach) if p.y < low + 0.03]
            if len(down) > 1:
                travel = max(reach[k].z for k in down) - min(reach[k].z for k in down)
                stride = travel / (len(down) / len(fine))
        clips.append(dict(name=clip, first=frame_count, count=len(samples), fps=SAMPLE_FPS, loop=loop, stride=stride))
        frame_count += len(samples)
arm.animation_data.action = None
bpy.context.view_layer.update()

# 6. Sockets: where the eyes are (the game draws its own, big and cartoon),
# where an udder hangs, and the end of each hind leg (held there).
def centre(rows):
    n = len(rows)
    return [sum(r[i] for r in rows) / n for i in range(6)]
sockets = {}
eyes = [r for name, rows in groups.items() if name.lower().startswith("eye") for r in rows]
for side, sign in (("L", 1), ("R", -1)):
    rows = [r for r in eyes if r[0] * sign > 0]
    if rows:
        c = centre(rows)
        sockets["eye_" + side] = dict(pos=c[:3], normal=c[3:6], bone="Head")
def rest(name, end="head"):
    b = arm.data.bones[name]
    return list(C @ arm.matrix_world @ (b.head_local if end == "head" else b.tail_local))
if "BackLeg.L" in index:
    hip = rest("BackLeg.L")
    main = [r for name, rows in groups.items() if name.startswith("Main") for r in rows]
    under = [r for r in main if abs(r[0]) < 0.12 and abs(r[2] - hip[2] - 0.15) < 0.2]
    if under:
        sockets["udder"] = dict(pos=[0, min(r[1] for r in under), hip[2] + 0.15], bone="Torso")
for side in ("L", "R"):
    if "FFB." + side in index:
        sockets["hoof_" + side] = dict(pos=rest("FFB." + side, "tail"), bone="FFB." + side)
        sockets["hip_" + side] = dict(pos=rest("BackLeg." + side), bone="BackLeg." + side)
# The mouth: the front of the muzzle, a little below its tip (where a fox
# carries what it stole).
heads = [r for rows in groups.values() for r in rows if r[13] > 0.5 and int(r[9]) == index.get("Head", -1)]
if heads:
    tip = max(heads, key=lambda r: r[2])
    size = max(r[1] for r in heads) - min(r[1] for r in heads)
    sockets["mouth"] = dict(pos=[0, tip[1] - 0.15 * size, tip[2] - 0.05 * size], bone="Head")
if "Tail1" in index:
    tail_bones = [b.name for b in bones if b.name.startswith("Tail")]
    sockets["tail_tip"] = dict(pos=rest(tail_bones[-1], "tail"), bone=tail_bones[-1])
    sockets["tail_root"] = dict(pos=rest(tail_bones[0]), bone=tail_bones[0])

info = dict(
    name=NAME,
    source=os.path.basename(bpy.data.filepath),
    bones=[b.name for b in bones],
    parents=[index[b.parent.name] if b.parent else -1 for b in bones],
    groups=group_info,
    clips=clips,
    sockets=sockets,
    scale=s,
)
with open(os.path.join(OUT, "info.json"), "w") as f:
    json.dump(info, f, indent=1)
print("PACKED", NAME, sum(g["count"] for g in group_info) // 3, "triangles,", len(bones), "bones,", frame_count, "frames")
