"""Pack the authored Blender character into the game coordinate frame.

Blender -b --python tools/pack_prosio.py -- prosio-anderson.blend assets/prosio
"""
from pathlib import Path
import json
import struct
import sys
import bpy
import numpy as np

filename, dest = map(Path,sys.argv[sys.argv.index("--")+1:])
dest.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(filename),load_ui=False)
rig = next(o for o in bpy.context.scene.objects if o.type=="ARMATURE")
parts = [o for o in bpy.context.scene.objects if o.type=="MESH" and o.get("Export")]
bones = list(rig.data.bones)
joint_id = {b.name:i for i,b in enumerate(bones)}
VERTEX_SCALE_X = 1.91
VERTEX_SCALE_Y = 1.95
VERTEX_SCALE_Z = 1.91
floor = min(v.co.z for o in parts for v in o.data.vertices)
def point(v):
    return (v.x*VERTEX_SCALE_X,(v.z-floor)*VERTEX_SCALE_Y,(-v.y-.127)*VERTEX_SCALE_Z)
def vector(v):
    x, y, z = v
    return x*VERTEX_SCALE_X, z*VERTEX_SCALE_Y, -y*VERTEX_SCALE_Z
def inverse_n(v):
    x, y, z = v
    return x/VERTEX_SCALE_X, z/VERTEX_SCALE_Y, -y/VERTEX_SCALE_Z
def srgb(x):
    return x*12.92 if x<=.0031308 else 1.055*x**(1/2.4)-.055
def rgba(color):
    rgb=[int(round(min(1.,max(0.,srgb(x)))*255)) for x in color[:3]]
    return bytes((*rgb,255))

verts=bytearray()
colors=bytearray()
body_indices=[]
detail_indices=[]
part_stats={}
shape_names = ("Fat", "ArmMuscle", "LegMuscle", "ChestMuscle", "BellyFull", "JawOpen", "CheekPuff", "Smile", "BrowLift")
shape_entries = {name: [] for name in shape_names}

def smooth_normals(points, triangles):
    a, b, c = points[triangles].transpose(1, 0, 2)
    area_normals = np.cross(b - a, c - a)
    normals = np.zeros_like(points)
    for corners in triangles.T:
        np.add.at(normals, corners, area_normals)
    lengths = np.linalg.norm(normals, axis=1)
    return normals / np.maximum(lengths[:, None], 1e-12)

for obj in parts:
    mesh=obj.data
    mesh.calc_loop_triangles()
    cache={}
    shapes = {}
    part_indices = body_indices if obj.get("Region") == "body" or obj.name.startswith("Prosio • quad body") else detail_indices
    if mesh.shape_keys:
        points = np.array([v.co[:] for v in mesh.vertices])
        triangles = np.array([t.vertices[:] for t in mesh.loop_triangles])
        neutral_normals = smooth_normals(points, triangles)
        for name in shape_names:
            key = mesh.shape_keys.key_blocks.get(name)
            if key is not None:
                target = np.array([p.co[:] for p in key.data])
                shapes[name] = target - points, smooth_normals(target, triangles) - neutral_normals
    for tri in mesh.loop_triangles:
        mi=mesh.polygons[tri.polygon_index].material_index
        for vi in tri.vertices:
            key=(vi,mi)
            if key not in cache:
                v=mesh.vertices[vi]
                co=obj.matrix_world @ v.co
                n=mesh.vertex_normals[vi].vector
                morph=mesh.shape_keys.key_blocks.get("Blink") if mesh.shape_keys else None
                delta=vector(morph.data[vi].co-v.co) if morph else (0.,0.,0.)
                weights=sorted(((joint_id[obj.vertex_groups[g.group].name],g.weight) for g in v.groups),key=lambda t:-t[1])[:4]
                assert sum(w for _,w in weights)>.999
                weights.extend([(0,0.)]*(4-len(weights)))
                cache[key]=len(verts)//68
                for name, (positions, normals) in shapes.items():
                    if max(np.linalg.norm(positions[vi]), np.linalg.norm(normals[vi])) > 1e-5:
                        d, dn = positions[vi], normals[vi]
                        shape_entries[name].append((cache[key], *vector(d), *inverse_n(dn)))
                verts.extend(struct.pack("<17f",*point(co),*inverse_n(n),*delta,*(b for b,_ in weights),*(w for _,w in weights)))
                attr=mesh.color_attributes.get("Prosio paint")
                color=attr.data[vi].color if attr else mesh.materials[mi].diffuse_color
                colors.extend(rgba(color))
            part_indices.append(cache[key])
    part_stats[obj.name]={"vertices":len(cache),"triangles":len(mesh.loop_triangles)}
assert len(verts)//68<65536
(dest/"vertices.bin").write_bytes(verts)
(dest/"paint.bin").write_bytes(colors)
indices=body_indices+detail_indices
(dest/"layout.bin").write_bytes(struct.pack("<I",len(body_indices)))
(dest/"indices.bin").write_bytes(struct.pack(f"<{len(indices)}H",*indices))
(dest/"joints.bin").write_bytes(b"".join(struct.pack("<6f",*point(b.head_local),*point(b.tail_local)) for b in bones))
offset = 0
ranges = bytearray()
with (dest / "shapes.bin").open("wb") as blob:
    for name, entries in shape_entries.items():
        ranges += struct.pack("<2I", offset, len(entries))
        for entry in entries:
            blob.write(struct.pack("<7f", *entry))
        offset += len(entries)
(dest / "shape_ranges.bin").write_bytes(ranges)
stats={"joint_names":list(joint_id),"parts":part_stats,"vertices":len(verts)//68,"outline_indices":len(body_indices),"indices":len(indices)}
stats["shape_vertices"] = {name: len(entries) for name, entries in shape_entries.items()}
(dest/"info.json").write_text(json.dumps(stats,indent=2)+"\n")
print("PACKED",stats)
