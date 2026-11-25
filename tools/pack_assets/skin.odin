package pack_assets

// Prosio's skin: one mesh bent on the parts the game already poses (see
// src/game/prosio_base.odin). From assets/prosio_base/prosio_base.glb and
// the parts' frames at the pose the skin was made in (bind.json, written by
// the game itself: see SKIN_BIND below) it writes
//
//   vertices.bin  each point: position, normal, four part numbers (bytes)
//                 and their weights, strongest first (44 bytes)
//   indices.bin   the triangles, three 16-bit point numbers each
//   paint.bin     each point's colour (sRGB bytes, with alpha)
//   face_fat.bin  each point's change of position and of normal at full
//                 "Facial Fat" (6 floats)
//   rest.bin      each part's frame at that pose, inverted (16 floats)
//
// What the GLB must hold: one mesh with a "Facial Fat" shape key and a
// colour (the skin paint), every point weighted to a skin whose bones are
// named as the parts in bind.json; in the game's frame (+Y up, metres).

import "core:encoding/json"
import "core:math"
import "core:math/linalg"
import "core:os"
import "core:slice"
import "vendor:cgltf"

SKIN_SHAPE :: "Facial Fat"
// The parts' frames when the skin was made, in the order of the game's
// Prosio_Base_Part. Written by the check build with -define:PROSIO_BASE=false
// -define:PROSIO_BASE_EXPORT=true, command export-prosio-base.
SKIN_BIND :: "bind.json"

Skin_Packed :: struct {
	vertices: [dynamic]Skin_Vertex,
	indices:  [dynamic]u16,
	paint:    [dynamic][4]u8,
	face:     [dynamic][6]f32,
	rest:     [dynamic][16]f32,
}
Skin_Vertex :: struct {
	pos, normal: Vec3,
	joints:      [4]u8,
	weights:     [4]f32,
}
#assert(size_of(Skin_Vertex) == 44)

pack_skin :: proc(a, glb, bind_path: string) -> (s: Skin_Packed) {
	data := load_glb(a, glb)

	// The parts, in the game's order, and their frames.
	text, err := os.read_entire_file(bind_path, context.allocator)
	if err != nil {
		fail(a, "cannot read %s (%v)", bind_path, err)
	}
	Bind :: struct {
		pieces: []struct {
			name:  string,
			frame: [16]f32,
		},
	}
	bind: Bind
	if e := json.unmarshal(text, &bind); e != nil {
		fail(a, "cannot read %s (%v)", bind_path, e)
	}
	parts := make([]string, len(bind.pieces))
	for p, i in bind.pieces {
		parts[i] = p.name
		append(&s.rest, transmute([16]f32)linalg.inverse(transmute(Mat4)p.frame))
	}

	// The skin mesh.
	node: ^cgltf.node
	for &n in data.nodes {
		if n.mesh != nil && slice.contains(target_names(n.mesh), SKIN_SHAPE) {
			if node != nil {
				fail(a, "%s has two meshes with a %q shape", glb, SKIN_SHAPE)
			}
			node = &n
		}
	}
	if node == nil {
		fail(a, "%s has no mesh with a %q shape", glb, SKIN_SHAPE)
	}
	if node.skin == nil || len(node.mesh.primitives) != 1 {
		fail(a, "the skin mesh must be one piece on a skin")
	}
	skin := node.skin
	part_of := make([]u8, len(skin.joints))
	for j, i in skin.joints {
		k, found := slice.linear_search(parts, string(j.name))
		if !found {
			fail(a, "bone %s is not a part of the game's (%s)", j.name, bind_path)
		}
		part_of[i] = u8(k)
	}
	for p in parts {
		found := false
		for j in skin.joints {
			found ||= string(j.name) == p
		}
		if !found {
			fail(a, "%s has no bone for the part %s (missing or renamed)", glb, p)
		}
	}
	rest := rest_pose(data)
	bind_m := make([]Mat4, len(skin.joints))
	for j, i in skin.joints {
		inv: Mat4
		_ = cgltf.accessor_read_float(skin.inverse_bind_matrices, uint(i), raw_data(&inv), 16)
		bind_m[i] = world_matrix(data, rest, j) * inv
	}

	prim := &node.mesh.primitives[0]
	pos := find_attribute(prim, .position)
	jnt := find_attribute(prim, .joints)
	wgt := find_attribute(prim, .weights)
	col := find_attribute(prim, .color)
	if jnt == nil || wgt == nil {
		fail(a, "the skin mesh has no weights")
	}
	if col == nil {
		fail(a, "the skin mesh has no colour (its paint)")
	}
	shape_index := -1
	for name, i in target_names(node.mesh) {
		if name == SKIN_SHAPE {
			shape_index = i
		}
	}
	shape: ^cgltf.accessor
	for &at in prim.targets[shape_index].attributes {
		if at.type == .position {
			shape = at.data
		}
	}
	n := int(pos.count)
	if n > 1 << 16 {
		fail(a, "the skin has %d points; the game numbers them in 16 bits (at most 65,536)", n)
	}
	points := make([]Vec3, n)
	shaped := make([]Vec3, n)
	for k in 0 ..< n {
		v := read_vec3(pos, uint(k))
		d := shape != nil ? read_vec3(shape, uint(k)) : {}
		bj := read_uvec4(jnt, uint(k))
		bw := read_vec4(wgt, uint(k))
		m: Mat4
		for c in 0 ..< 4 {
			m += bind_m[bj[c]] * Mat4(bw[c])
		}
		points[k] = transform_point(m, v)
		shaped[k] = transform_point(m, v + d)
		w := strongest_four(a, node.name, k, bj[:], bw[:], 0)
		sv := Skin_Vertex{pos = points[k]}
		for c in 0 ..< 4 {
			if w[4 + c] > 0 {
				sv.joints[c] = part_of[int(w[c])]
				sv.weights[c] = w[4 + c]
			}
		}
		append(&s.vertices, sv)
		rgba := read_vec4(col, uint(k))
		if col.type == .vec3 {
			rgba.a = 1
		}
		append(&s.paint, [4]u8{srgb_byte(rgba.r), srgb_byte(rgba.g), srgb_byte(rgba.b), u8(math.round(clamp(rgba.a, 0, 1) * 255))})
	}
	tris := triangles(a, prim)
	for t in tris {
		append(&s.indices, u16(t))
	}
	normals := smooth_normals(points, tris)
	shaped_normals := smooth_normals(shaped, tris)
	for k in 0 ..< n {
		s.vertices[k].normal = normals[k]
		d := shaped[k] - points[k]
		dn := shaped_normals[k] - normals[k]
		append(&s.face, [6]f32{d.x, d.y, d.z, dn.x, dn.y, dn.z})
	}
	return
}

target_names :: proc(m: ^cgltf.mesh) -> []string {
	out := make([]string, len(m.target_names))
	for t, i in m.target_names {
		out[i] = string(t)
	}
	return out
}

// glTF keeps colours linear; the game's paint is in sRGB bytes.
srgb_byte :: proc(linear: f32) -> u8 {
	c := clamp(linear, 0, 1)
	s := c <= 0.0031308 ? c * 12.92 : 1.055 * math.pow(c, 1 / 2.4) - 0.055
	return u8(math.round(s * 255))
}
