package pack_assets

// The four-legged animals: a mesh bent on a skeleton, and the animations
// that move it. From assets/<name>/<name>.glb it writes, in the game's
// model frame (+Y up, +Z towards the muzzle, the feet on y = 0, the animal
// `length` long from tail to muzzle, the middle of that length 0.2 behind
// the origin):
//
//   points.bin  each distinct point of the mesh at rest (Quad_Point): its
//               place, its smooth normal (for the outline), four bone
//               numbers and their four weights
//   corners.bin every triangle as three points (u16 each), grouped by
//               material, the groups in order of their names
//   flats.bin   every triangle's flat normal at rest (3 floats), in the
//               same order
//   rest.bin    each bone's rest frame, inverted (16 floats, column by column)
//   frames.bin  each animation sampled QUAD_FPS times a second: each bone's
//               frame (12 floats, column by column)
//   info.json   bones, material groups, animations and sockets
//
// and the tables of all of them, src/game/quadruped_assets.odin.
//
// What the GLB must hold: one skin, every point weighted to it; the
// animations named in the asset's clips; and each socket as a node named
// "socket_<name>" whose parent is a bone, placed where the socket is at rest,
// its +Z along the socket's normal (eyes) or the GLB's own +Z.

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:slice"
import "core:strings"
import "vendor:cgltf"

Quad_Spec :: struct {
	name:    string,
	length:  f32, // from tail to muzzle, in the model's units
	flag:    string, // the build switch it is compiled in under ("" always)
	clips:   []string, // the animations the game uses, in this order
	sockets: []string, // the sockets it must have
}

QUAD_FPS :: 20
// The bones the game looks up by name (quadruped.odin, quadruped_motion.odin,
// quadruped_drag.odin): every animal must have them.
QUAD_BONES := []string {
	"Body", "Torso2", "Neck1", "Head",
	"FrontShoulder.L", "FrontUpperLeg.L", "FrontLowerLeg.L", "IKFrontLeg.L", "FF.L",
	"FrontShoulder.R", "FrontUpperLeg.R", "FrontLowerLeg.R", "IKFrontLeg.R", "FF.R",
	"BackShoulder.L", "BackLeg.L", "BackUpperLeg.L", "BackLowerLeg.L", "IKBackLeg.L", "FFB.L",
	"BackShoulder.R", "BackLeg.R", "BackUpperLeg.R", "BackLowerLeg.R", "IKBackLeg.R", "FFB.R",
}
// Animations that play once and stop, rather than go round.
QUAD_ONE_SHOT := []string{"Idle_HitReact_Left", "Death", "Attack_Headbutt", "Attack", "Gallop_Jump"}
// Bones that move with the front half of the body (the rest with the rear):
// when he holds an animal, each half follows its own frame (see draw.odin).
QUAD_FRONT := []string{"Torso2", "Torso3", "Neck", "Head", "Ear", "Front", "IKFront", "FF.", "PoleTarget."}
// The socket that follows the hind hoof: how far an animal goes in one cycle
// is measured from it.
QUAD_STRIDE_FOOT :: "hoof_L"
// How many points of a cycle the stride is measured on, and how far above
// its lowest the hoof still counts as down.
QUAD_STRIDE_SAMPLES :: 240
QUAD_STRIDE_DOWN :: 0.03

Quad_Group :: struct {
	name:         string,
	first, count: int,
}
Quad_Clip :: struct {
	name:         string,
	first, count: int,
	loop:         bool,
	stride:       f32,
}
Quad_Socket :: struct {
	name:        string,
	pos, normal: Vec3,
	bone:        int,
}
// A point of the mesh at rest, as the game reads it (quadruped.odin).
Quad_Point :: struct {
	pos, smooth: Vec3,
	bones:       [4]u8,
	weights:     [4]f32,
}
Quad_Packed :: struct {
	spec:    Quad_Spec,
	source:  string,
	bones:   []string,
	parents: []int,
	groups:  [dynamic]Quad_Group,
	clips:   [dynamic]Quad_Clip,
	sockets: [dynamic]Quad_Socket,
	points:  [dynamic]Quad_Point,
	corners: [dynamic]u16,
	flats:   [dynamic]Vec3,
	rest:    [][16]f32,
	frames:  [dynamic][12]f32,
	scale:   f32,
}

pack_quadruped :: proc(spec: Quad_Spec, glb: string) -> (q: Quad_Packed) {
	a := spec.name
	data := load_glb(a, glb)
	q.spec = spec
	q.source = glb
	if len(data.skins) != 1 {
		fail(a, "%s has %d skins; an animal has one", glb, len(data.skins))
	}
	skin := &data.skins[0]
	nb := len(skin.joints)
	bone_of := make(map[^cgltf.node]int)
	q.bones = make([]string, nb)
	q.parents = make([]int, nb)
	for j, i in skin.joints {
		bone_of[j] = i
		q.bones[i] = strings.clone_from_cstring(j.name)
	}
	for want in QUAD_BONES {
		if !slice.contains(q.bones, want) {
			fail(a, "%s has no bone %s", glb, want)
		}
	}
	for j, i in skin.joints {
		q.parents[i] = j.parent in bone_of ? bone_of[j.parent] : -1
	}
	rest := rest_pose(data)
	bind := make([]Mat4, nb) // each bone's frame at rest, times its inverse bind matrix
	for j, i in skin.joints {
		inv: Mat4
		_ = cgltf.accessor_read_float(skin.inverse_bind_matrices, uint(i), raw_data(&inv), 16)
		bind[i] = world_matrix(data, rest, j) * inv
	}

	// The mesh at rest, in the GLB's frame, mesh by mesh.
	Corner :: struct {
		point:   int,
		group:   string,
	}
	points: [dynamic]Vec3
	smooth: [dynamic]Vec3
	weights: [dynamic][8]f32 // four bones, four weights
	corners: [dynamic]Corner
	for &node in data.nodes {
		if node.mesh == nil {
			continue
		}
		if node.skin != skin {
			fail(a, "mesh %s is not on the animal's skin", node.name)
		}
		first := len(points)
		tris: [dynamic]u32
		for &prim in node.mesh.primitives {
			group := prim.material != nil ? strings.clone_from_cstring(prim.material.name) : "Main"
			pos := find_attribute(&prim, .position)
			jnt := find_attribute(&prim, .joints)
			wgt := find_attribute(&prim, .weights)
			if jnt == nil || wgt == nil {
				fail(a, "mesh %s (%s) has no weights", node.name, group)
			}
			base := len(points)
			for k in 0 ..< pos.count {
				v := read_vec3(pos, k)
				bj := read_uvec4(jnt, k)
				bw := read_vec4(wgt, k)
				p: Vec3
				for c in 0 ..< 4 {
					if bw[c] > 0 {
						p += transform_point(bind[bj[c]], v) * bw[c]
					}
				}
				append(&points, p)
				append(&weights, strongest_four(a, node.name, int(k), bj[:], bw[:]))
			}
			for t in triangles(a, &prim) {
				append(&tris, u32(base) + t)
				append(&corners, Corner{base + int(t), group})
			}
		}
		local_tris := make([]u32, len(tris))
		for t, i in tris {
			local_tris[i] = t - u32(first)
		}
		append(&smooth, ..smooth_normals(points[first:], local_tris))
	}
	if len(corners) == 0 {
		fail(a, "%s has no mesh", glb)
	}

	// Into the game's model frame.
	lo, hi := Vec3(math.F32_MAX), Vec3(-math.F32_MAX)
	for p in points {
		lo, hi = linalg.min(lo, p), linalg.max(hi, p)
	}
	s := spec.length / (hi.z - lo.z)
	to_game := linalg.matrix4_translate(Vec3{0, -lo.y * s, -(lo.z + hi.z) / 2 * s + 0.2}) * linalg.matrix4_scale(Vec3(s))
	q.scale = s

	names: [dynamic]string
	for c in corners {
		if !slice.contains(names[:], c.group) {
			append(&names, c.group)
		}
	}
	slice.sort(names[:])
	// Each distinct point once (the same place, outline normal, bones and
	// weights: points the GLB splits for its own reasons are one here), and
	// each triangle as three of them, with its flat normal at rest. The game
	// bends each point once, and each corner's flat normal with that
	// corner's bones (as when every corner was stored on its own).
	point_of := make(map[[14]u32]u16)
	for name in names {
		g := Quad_Group{name, len(q.corners), 0}
		for t := 0; t + 2 < len(corners); t += 3 {
			if corners[t].group != name {
				continue
			}
			// The triangle's flat normal at rest, for the light: the game
			// bends it with each corner's own bones.
			c: [3]Vec3
			for k in 0 ..< 3 {
				c[k] = transform_point(to_game, points[corners[t + k].point])
			}
			append(&q.flats, linalg.normalize0(linalg.cross(c[1] - c[0], c[2] - c[0])))
			for k in 0 ..< 3 {
				i := corners[t + k].point
				p := Quad_Point{pos = transform_point(to_game, points[i]), smooth = smooth[i]}
				for b in 0 ..< 4 {
					p.bones[b] = u8(weights[i][b])
					p.weights[b] = weights[i][4 + b]
				}
				key := transmute([14]u32)[14]f32 {
					p.pos.x, p.pos.y, p.pos.z, p.smooth.x, p.smooth.y, p.smooth.z,
					weights[i][0], weights[i][1], weights[i][2], weights[i][3],
					p.weights[0], p.weights[1], p.weights[2], p.weights[3],
				}
				n, seen := point_of[key]
				if !seen {
					if len(q.points) > int(max(u16)) {
						fail(a, "%s has more than %d points", glb, int(max(u16)) + 1)
					}
					n = u16(len(q.points))
					point_of[key] = n
					append(&q.points, p)
				}
				append(&q.corners, n)
			}
			g.count += 3
		}
		append(&q.groups, g)
	}
	if nb > 256 {
		fail(a, "%s has %d bones; a point names its bones in a byte", glb, nb)
	}

	q.rest = make([][16]f32, nb)
	for j, i in skin.joints {
		q.rest[i] = transmute([16]f32)linalg.inverse(to_game * world_matrix(data, rest, j))
	}

	// Sockets, at rest.
	for &node in data.nodes {
		name := string(node.name)
		if !strings.has_prefix(name, "socket_") {
			continue
		}
		if node.parent == nil || !(node.parent in bone_of) {
			fail(a, "socket %s is not on a bone", name)
		}
		m := to_game * world_matrix(data, rest, &node)
		append(&q.sockets, Quad_Socket {
			name = strings.trim_prefix(name, "socket_"),
			pos = m[3].xyz,
			normal = linalg.normalize(m[2].xyz),
			bone = bone_of[node.parent],
		})
	}
	slice.sort_by(q.sockets[:], proc(x, y: Quad_Socket) -> bool {return x.name < y.name})
	foot: ^cgltf.node
	for want in spec.sockets {
		found := false
		for s in q.sockets {
			found ||= s.name == want
		}
		if !found {
			fail(a, "%s has no socket_%s", glb, want)
		}
	}
	for &node in data.nodes {
		if string(node.name) == "socket_" + QUAD_STRIDE_FOOT {
			foot = &node
		}
	}

	// The animations.
	pose := rest_pose(data)
	for name in spec.clips {
		anim := find_animation(data, name)
		if anim == nil {
			fail(a, "%s has no animation %s", glb, name)
		}
		t0, t1 := animation_span(anim)
		loop := !slice.contains(QUAD_ONE_SHOT, name)
		n := max(1, int(math.round((t1 - t0) * QUAD_FPS)))
		count := loop ? n : n + 1
		c := Quad_Clip{name, len(q.frames) / nb, count, loop, 0}
		for k in 0 ..< count {
			copy_pose(pose, rest)
			apply_animation(data, anim, t0 + (t1 - t0) * f32(k) / f32(n), pose)
			for j in skin.joints {
				m := to_game * world_matrix(data, pose, j)
				f: [12]f32
				for col in 0 ..< 4 {
					for row in 0 ..< 3 {
						f[col * 3 + row] = m[row, col]
					}
				}
				append(&q.frames, f)
			}
		}
		// How far the animal goes over the ground in one cycle, if its feet
		// are not to slide: a hind foot, while it is down, goes back under the
		// body as far as the body goes forward; so the cycle covers that
		// distance over the share of the cycle the foot is down. (Measured on
		// a much finer pass than the frames kept: a gallop's foot is down for
		// only a moment.)
		if loop && foot != nil {
			reach := make([]Vec3, QUAD_STRIDE_SAMPLES)
			low := f32(math.F32_MAX)
			for k in 0 ..< QUAD_STRIDE_SAMPLES {
				copy_pose(pose, rest)
				apply_animation(data, anim, t0 + (t1 - t0) * f32(k) / QUAD_STRIDE_SAMPLES, pose)
				reach[k] = transform_point(to_game * world_matrix(data, pose, foot), {})
				low = min(low, reach[k].y)
			}
			down := 0
			zlo, zhi := f32(math.F32_MAX), -f32(math.F32_MAX)
			for p in reach {
				if p.y < low + QUAD_STRIDE_DOWN {
					down += 1
					zlo, zhi = min(zlo, p.z), max(zhi, p.z)
				}
			}
			if down > 1 {
				c.stride = (zhi - zlo) / (f32(down) / QUAD_STRIDE_SAMPLES)
			}
		}
		append(&q.clips, c)
	}
	return
}

// A point's four strongest bones, their weights made to add up to one;
// weights under `least` (a thousandth) are dropped.
strongest_four :: proc(asset: string, mesh: cstring, k: int, bones: []u32, weights: []f32, least: f32 = 0.001) -> (out: [8]f32) {
	order := [4]int{0, 1, 2, 3}
	for i in 0 ..< 4 {
		for j in i + 1 ..< 4 {
			if weights[order[j]] > weights[order[i]] {
				order[i], order[j] = order[j], order[i]
			}
		}
	}
	total: f32
	for i in order {
		if weights[i] > least {
			total += weights[i]
		}
	}
	if total <= 0 {
		fail(asset, "point %d of mesh %s is weighted to no bone", k, mesh)
	}
	for i, n in order {
		if weights[i] > least {
			out[n] = f32(bones[i])
			out[4 + n] = weights[i] / total
		}
	}
	return
}

quad_front :: proc(bone: string) -> bool {
	for p in QUAD_FRONT {
		if strings.has_prefix(bone, p) {
			return true
		}
	}
	return false
}

// The tables of the packed animals: src/game/quadruped_assets.odin.
quad_tables :: proc(quads: []Quad_Packed) -> string {
	b := strings.builder_make()
	w :: proc(b: ^strings.Builder, format: string, args: ..any) {
		if len(args) == 0 {
			strings.write_string(b, format)
		} else {
			fmt.sbprintf(b, format, ..args)
		}
		strings.write_byte(b, '\n')
	}
	w(&b, "package game")
	w(&b, "")
	w(&b, "// Made by tools/pack_assets from assets/<name>/<name>.glb: do not edit.")
	w(&b, "")
	kinds: [dynamic]string
	most_bones, most_verts, most_points, most_groups := 0, 0, 0, 0
	for q in quads {
		append(&kinds, title(q.spec.name))
		most_bones = max(most_bones, len(q.bones))
		most_verts = max(most_verts, len(q.corners))
		most_points = max(most_points, len(q.points))
		most_groups = max(most_groups, len(q.groups))
	}
	w(&b, "Quad_Kind :: enum {{%s}}", strings.join(kinds[:], ", "))
	w(&b, "QUAD_MAX_BONES :: %d", most_bones)
	w(&b, "QUAD_MAX_VERTS :: %d", most_verts)
	w(&b, "QUAD_MAX_POINTS :: %d", most_points)
	w(&b, "QUAD_MAX_GROUPS :: %d", most_groups)
	w(&b, "")
	for q in quads {
		if q.spec.flag == "" {
			continue
		}
		u, n := strings.to_upper(q.spec.name), q.spec.name
		w(&b, "when %s {{", q.spec.flag)
		w(&b, "\tQUAD_%s_POINTS := #load(\"../../assets/%s/points.bin\", []Quad_Point)", u, n)
		w(&b, "\tQUAD_%s_CORNERS := #load(\"../../assets/%s/corners.bin\", []u16)", u, n)
		w(&b, "\tQUAD_%s_FLATS := #load(\"../../assets/%s/flats.bin\", [][3]f32)", u, n)
		w(&b, "\tQUAD_%s_REST := #load(\"../../assets/%s/rest.bin\", [][16]f32)", u, n)
		w(&b, "\tQUAD_%s_FRAMES := #load(\"../../assets/%s/frames.bin\", [][12]f32)", u, n)
		w(&b, "} else {")
		w(&b, "\tQUAD_%s_POINTS: []Quad_Point", u)
		w(&b, "\tQUAD_%s_CORNERS: []u16", u)
		w(&b, "\tQUAD_%s_FLATS: [][3]f32", u)
		w(&b, "\tQUAD_%s_REST: [][16]f32", u)
		w(&b, "\tQUAD_%s_FRAMES: [][12]f32", u)
		w(&b, "}")
		w(&b, "")
	}
	w(&b, "QUAD_MODELS := [Quad_Kind]Quad_Model {")
	for q in quads {
		n := q.spec.name
		w(&b, "\t.%s = {{", title(n))
		w(&b, "\t\tname = \"%s\", // from %s.glb", n, n)
		list: [dynamic]string
		for bone in q.bones {append(&list, fmt.tprintf("%q", bone))}
		w(&b, "\t\tbones = []string{{%s}},", strings.join(list[:], ", "))
		clear(&list)
		for p in q.parents {append(&list, fmt.tprint(p))}
		w(&b, "\t\tparents = []int{{%s}},", strings.join(list[:], ", "))
		clear(&list)
		for bone in q.bones {append(&list, quad_front(bone) ? "true" : "false")}
		w(&b, "\t\tfront = []bool{{%s}},", strings.join(list[:], ", "))
		clear(&list)
		for g in q.groups {append(&list, fmt.tprintf("{{%q, %d, %d}}", g.name, g.first, g.count))}
		w(&b, "\t\tgroups = []Quad_Group{{%s}},", strings.join(list[:], ", "))
		clear(&list)
		for c in q.clips {
			append(&list, fmt.tprintf("{{%q, %d, %d, %d, %v, %s}}", c.name, c.first, c.count, QUAD_FPS, c.loop, num(c.stride)))
		}
		w(&b, "\t\tclips = []Quad_Clip{{%s}},", strings.join(list[:], ", "))
		clear(&list)
		for s in q.sockets {
			append(&list, fmt.tprintf("{{%q, %s, %s, %d}}", s.name, vec(s.pos), vec(s.normal), s.bone))
		}
		w(&b, "\t\tsockets = []Quad_Socket{{%s}},", strings.join(list[:], ", "))
		if q.spec.flag != "" {
			u := strings.to_upper(n)
			w(&b, "\t\tpoints = QUAD_%s_POINTS,", u)
			w(&b, "\t\tcorners = QUAD_%s_CORNERS,", u)
			w(&b, "\t\tflats = QUAD_%s_FLATS,", u)
			w(&b, "\t\trest = QUAD_%s_REST,", u)
			w(&b, "\t\tframes = QUAD_%s_FRAMES,", u)
		} else {
			w(&b, "\t\tpoints = #load(\"../../assets/%s/points.bin\", []Quad_Point),", n)
			w(&b, "\t\tcorners = #load(\"../../assets/%s/corners.bin\", []u16),", n)
			w(&b, "\t\tflats = #load(\"../../assets/%s/flats.bin\", [][3]f32),", n)
			w(&b, "\t\trest = #load(\"../../assets/%s/rest.bin\", [][16]f32),", n)
			w(&b, "\t\tframes = #load(\"../../assets/%s/frames.bin\", [][12]f32),", n)
		}
		w(&b, "\t},")
	}
	w(&b, "}")
	return strings.to_string(b)
}

// info.json: what was packed, for people and other tools to read.
quad_info :: proc(q: Quad_Packed) -> string {
	b := strings.builder_make()
	fmt.sbprintf(&b, "{{\n \"name\": %q,\n \"source\": \"%s.glb\",\n \"scale\": %v,\n", q.spec.name, q.spec.name, q.scale)
	list: [dynamic]string
	for bone in q.bones {append(&list, fmt.tprintf("%q", bone))}
	fmt.sbprintf(&b, " \"bones\": [%s],\n", strings.join(list[:], ", "))
	clear(&list)
	for p in q.parents {append(&list, fmt.tprint(p))}
	fmt.sbprintf(&b, " \"parents\": [%s],\n", strings.join(list[:], ", "))
	uses: [4]int
	for p in q.points {
		n := 0
		for w in p.weights {
			if w > 0 {n += 1}
		}
		uses[n - 1] += 1
	}
	fmt.sbprintf(&b, " \"points\": %d,\n \"corners\": %d,\n \"points_by_bones\": [%d, %d, %d, %d],\n", len(q.points), len(q.corners), uses[0], uses[1], uses[2], uses[3])
	clear(&list)
	for g in q.groups {append(&list, fmt.tprintf("  {{\"name\": %q, \"first\": %d, \"count\": %d}}", g.name, g.first, g.count))}
	fmt.sbprintf(&b, " \"groups\": [\n%s\n ],\n", strings.join(list[:], ",\n"))
	clear(&list)
	for c in q.clips {
		append(&list, fmt.tprintf("  {{\"name\": %q, \"first\": %d, \"count\": %d, \"fps\": %d, \"loop\": %v, \"stride\": %v}}", c.name, c.first, c.count, QUAD_FPS, c.loop, c.stride))
	}
	fmt.sbprintf(&b, " \"clips\": [\n%s\n ],\n", strings.join(list[:], ",\n"))
	clear(&list)
	for s in q.sockets {
		append(&list, fmt.tprintf("  %q: {{\"pos\": [%v, %v, %v], \"normal\": [%v, %v, %v], \"bone\": %q}}", s.name, s.pos.x, s.pos.y, s.pos.z, s.normal.x, s.normal.y, s.normal.z, q.bones[s.bone]))
	}
	fmt.sbprintf(&b, " \"sockets\": {{\n%s\n }}\n}}\n", strings.join(list[:], ",\n"))
	return strings.to_string(b)
}

title :: proc(s: string) -> string {
	return strings.concatenate({strings.to_upper(s[:1]), s[1:]})
}

// A number for the tables: four decimals, no trailing zeros.
num :: proc(x: f32) -> string {
	r := math.round(f64(x) * 10000) / 10000
	if r == 0 {
		return "0"
	}
	return fmt.tprintf("%v", r)
}

vec :: proc(v: Vec3) -> string {
	return fmt.tprintf("{{%s, %s, %s}}", num(v.x), num(v.y), num(v.z))
}
