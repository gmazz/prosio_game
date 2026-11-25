package pack_assets

// Trees, and the rocks, grass, ferns, stumps, logs and bushes packed the same
// way (a rock's stone is its "bark", its moss its "leaves"; grass and ferns
// are all leaves). From assets/trees/<name>.glb it writes
//
//   <name>.bin   every triangle's three corners, 9 floats each: position,
//                flat normal, smooth normal (for the outline); the bark
//                first, then the leaves
//   <name>.json  how many corners are bark and leaves, how tall it is, where
//                its crown starts and ends and how wide it is, how far it
//                reaches, its colours, and spots on the crown for apples
//
// in the game's frame (+Y up, metres as modelled: the game scales each tree
// to its kind's height), the foot of the trunk at the origin (a rock, or a
// plant with no trunk, with the middle of its bottom there); and the tables
// of all of them, src/game/tree_assets.odin.

import "core:encoding/json"
import "core:fmt"
import "core:image"
import _ "core:image/jpeg"
import _ "core:image/png"
import "core:math"
import "core:math/linalg"
import "core:slice"
import "core:strings"
import "vendor:cgltf"

TREES := []string {
	"broad1", "broad2", "broad3", "broad4", "common1", "common2", "birch1", "birch2",
	"round1", "round2", "round3", "pine1", "pine2", "pine3", "pine4", "pine5",
	"rock1", "rock2", "rock3", "rock4", "rock5", "rockmoss1", "rockmoss2", "rockmoss3", "rockmoss4",
	"grass1", "grass2", "grass3", "fern1", "fern2", "fern3", "stump1", "stump2", "log1", "bush1", "bush2",
}
// Which materials are bark and which leaves, by name (before any ".001").
// The models of the nature packs share names: the Ultimate Nature Pack's
// ("Wood" or a birch's "White" and "Black" bark, "Green" and "DarkGreen"
// leaves) and the Stylized Tree Pack's ("Bark" or "Birch_Bark", and
// "Tree_Leaves", "Pine_Leaves" or "Birch_Leaves"). Anything else is left
// out: the mushrooms on the fallen logs, for one, which would look like
// food that is not there.
TREE_BARK := []string{"Wood", "LightWood", "White", "Black", "Bark", "Birch_Bark", "Rock"}
TREE_LEAVES := []string{"Green", "DarkGreen", "Tree_Leaves", "Pine_Leaves", "Birch_Leaves", "Leaves"}
// The trunk's foot: the middle of the bark this far above its lowest point.
TREE_FOOT :: 0.3
// Apple spots: on faces turned this far up, this far out from the trunk (a
// share of the crown's reach), this far proud of the leaves (a share of the
// height); at most this many.
TREE_SPOT_UP :: 0.25
TREE_SPOT_OUT :: 0.45
TREE_SPOT_PROUD :: 0.04
TREE_SPOTS :: 8

Tree_Packed :: struct {
	name:                             string,
	rows:                             [dynamic][9]f32,
	bark, leaves:                     int,
	height, crown_low, crown_high:    f32,
	crown_r, radius:                  f32,
	bark_color, leaf_color:           [4]u8, // alpha 0: none
	spots:                            [dynamic]Vec3,
}

Tree_Corner :: struct {
	pos, flat, smooth: Vec3,
}

pack_tree :: proc(name, glb: string) -> (t: Tree_Packed) {
	t.name = name
	data := load_glb(name, glb)
	colours := material_colours(name, data)
	parts := [2][dynamic]Tree_Corner{}
	rgb: [2][3]f64
	weight: [2]f64
	for &node in data.nodes {
		if node.mesh == nil {
			continue
		}
		world := world_matrix(data, rest_pose(data), &node)
		w3 := world
		w3[0, 3], w3[1, 3], w3[2, 3] = 0, 0, 0
		// The mesh as one: its points (welded where they meet), triangles,
		// and which part each triangle is of.
		points: [dynamic]Vec3
		tris: [dynamic]u32
		tri_part: [dynamic]int
		tri_colour: [dynamic]Maybe([3]f32)
		for &prim in node.mesh.primitives {
			mat := prim.material != nil ? string(prim.material.name) : ""
			short := strings.split_n(mat, ".", 2)[0]
			part := slice.contains(TREE_BARK, short) ? 0 : (slice.contains(TREE_LEAVES, short) ? 1 : -1)
			pos := find_attribute(&prim, .position)
			base := u32(len(points))
			for k in 0 ..< pos.count {
				append(&points, read_vec3(pos, k))
			}
			tt := triangles(name, &prim)
			for i := 0; i + 2 < len(tt); i += 3 {
				append(&tris, base + tt[i], base + tt[i + 1], base + tt[i + 2])
				append(&tri_part, part)
				c: Maybe([3]f32)
				if prim.material != nil {
					c = colours[cgltf.material_index(data, prim.material)]
				}
				append(&tri_colour, c)
			}
		}
		face_outwards(points[:], tris[:])
		smooth := smooth_normals(points[:], tris[:])
		for i in 0 ..< len(tri_part) {
			part := tri_part[i]
			if part < 0 {
				continue
			}
			c := [3]Vec3{points[tris[3 * i]], points[tris[3 * i + 1]], points[tris[3 * i + 2]]}
			n := linalg.cross(c[1] - c[0], c[2] - c[0])
			if col, ok := tri_colour[i].?; ok {
				a := f64(linalg.length(n)) / 2
				for k in 0 ..< 3 {
					rgb[part][k] += f64(col[k]) * a
				}
				weight[part] += a
			}
			flat := linalg.normalize0(transform_dir(w3, linalg.normalize0(n)))
			for k in 0 ..< 3 {
				v := tris[3 * i + k]
				append(&parts[part], Tree_Corner{transform_point(world, points[v]), flat, linalg.normalize0(transform_dir(w3, smooth[v]))})
			}
		}
	}
	for part in 0 ..< 2 {
		if weight[part] > 0 {
			col: [4]u8
			for k in 0 ..< 3 {
				col[k] = u8(math.round(clamp(rgb[part][k] / weight[part], 0, 1) * 255))
			}
			col[3] = 255
			if part == 0 {t.bark_color = col} else {t.leaf_color = col}
		}
	}
	t.bark, t.leaves = len(parts[0]), len(parts[1])
	if t.bark + t.leaves == 0 {
		fail(name, "%s has neither bark nor leaves (materials named as in TREE_BARK, TREE_LEAVES)", glb)
	}

	// The foot of the trunk at the origin.
	every: [dynamic]Vec3
	for part in parts {
		for c in part {append(&every, c.pos)}
	}
	base := f32(math.F32_MAX)
	for p in every {base = min(base, p.y)}
	axis: Vec3
	if t.bark > 0 && !strings.has_prefix(name, "rock") {
		base = f32(math.F32_MAX)
		for c in parts[0] {base = min(base, c.pos.y)}
		sum: Vec3
		n := 0
		for c in parts[0] {
			if c.pos.y < base + TREE_FOOT {
				sum += c.pos
				n += 1
			}
		}
		axis = {sum.x / f32(n), base, sum.z / f32(n)}
	} else {
		lo, hi := Vec3(math.F32_MAX), Vec3(-math.F32_MAX)
		for p in every {lo, hi = linalg.min(lo, p), linalg.max(hi, p)}
		axis = {(lo.x + hi.x) / 2, base, (lo.z + hi.z) / 2}
	}
	for part in parts {
		for c in part {
			q := c.pos - axis
			append(&t.rows, [9]f32{q.x, q.y, q.z, c.flat.x, c.flat.y, c.flat.z, c.smooth.x, c.smooth.y, c.smooth.z})
		}
	}

	t.height = -math.F32_MAX
	for p in every {t.height = max(t.height, p.y - axis.y)}
	t.crown_low, t.crown_high = 0, t.height
	if t.leaves > 0 {
		t.crown_low, t.crown_high = math.F32_MAX, -math.F32_MAX
		for c in parts[1] {
			y := c.pos.y - axis.y
			t.crown_low, t.crown_high = min(t.crown_low, y), max(t.crown_high, y)
			t.crown_r = max(t.crown_r, math.hypot(c.pos.x - axis.x, c.pos.z - axis.z))
		}
	}
	for p in every {t.radius = max(t.radius, math.hypot(p.x - axis.x, p.z - axis.z))}

	// Spots on the upper slope of the crown for apples: spread out, a little
	// proud of the leaves.
	candidates: [dynamic]Vec3
	for i := 0; i + 2 < len(parts[1]); i += 3 {
		c := (parts[1][i].pos + parts[1][i + 1].pos + parts[1][i + 2].pos) / 3 - axis
		n := parts[1][i].flat
		if n.y > TREE_SPOT_UP && math.hypot(c.x, c.z) > TREE_SPOT_OUT * t.crown_r {
			append(&candidates, c + n * TREE_SPOT_PROUD * t.height)
		}
	}
	if len(candidates) > 0 {
		first := candidates[0]
		for c in candidates {
			if math.hypot(c.x, c.z) > math.hypot(first.x, first.z) {first = c}
		}
		append(&t.spots, first)
		for len(t.spots) < min(TREE_SPOTS, len(candidates)) {
			best, best_d := candidates[0], f32(-1)
			for c in candidates {
				d := f32(math.F32_MAX)
				for s in t.spots {d = min(d, linalg.length(c - s))}
				if d > best_d {best, best_d = c, d}
			}
			append(&t.spots, best)
		}
	}
	return
}

// Each material's colour in sRGB, or none: its base colour if it has one,
// or the mean of the picture painted on it; none if it has neither (a
// picture the exporter could not find leaves none: the game then uses its
// own colour).
material_colours :: proc(name: string, data: ^cgltf.data) -> []Maybe([3]f32) {
	Raw :: struct {
		materials: []struct {
			pbrMetallicRoughness: struct {
				baseColorFactor: []f32,
			},
		},
	}
	raw: Raw
	if e := json.unmarshal(transmute([]byte)data.json, &raw); e != nil {
		fail(name, "cannot read the GLB's materials (%v)", e)
	}
	out := make([]Maybe([3]f32), len(data.materials))
	for &m, i in data.materials {
		if !m.has_pbr_metallic_roughness {
			continue
		}
		pbr := &m.pbr_metallic_roughness
		if pbr.base_color_texture.texture != nil && pbr.base_color_texture.texture.image_ != nil {
			if mean, ok := image_mean(pbr.base_color_texture.texture.image_); ok {
				out[i] = mean
				continue
			}
		}
		if i < len(raw.materials) && len(raw.materials[i].pbrMetallicRoughness.baseColorFactor) >= 3 {
			f := pbr.base_color_factor
			out[i] = [3]f32{srgb(f[0]), srgb(f[1]), srgb(f[2])}
		}
	}
	return out
}

srgb :: proc(linear: f32) -> f32 {
	c := max(linear, 0)
	return c <= 0.0031308 ? c * 12.92 : 1.055 * math.pow(c, 1 / 2.4) - 0.055
}

// The mean colour of a picture held in the GLB (sRGB, 0 to 1).
image_mean :: proc(img: ^cgltf.image) -> (mean: [3]f32, ok: bool) {
	if img.buffer_view == nil {
		return
	}
	data := cgltf.buffer_view_data(img.buffer_view)[:img.buffer_view.size]
	pic, err := image.load_from_bytes(data, {.alpha_add_if_missing})
	if err != nil || pic.depth != 8 || pic.channels != 4 {
		return
	}
	px := pic.pixels[:]
	sum: [3]f64
	n := len(px) / 4
	for i in 0 ..< n {
		for k in 0 ..< 3 {sum[k] += f64(px[4 * i + k])}
	}
	for k in 0 ..< 3 {mean[k] = f32(sum[k] / f64(max(n, 1)) / 255)}
	return mean, true
}

tree_info :: proc(t: Tree_Packed) -> string {
	b := strings.builder_make()
	spots: [dynamic]string
	for s in t.spots {append(&spots, fmt.tprintf("[%v, %v, %v]", s.x, s.y, s.z))}
	fmt.sbprintf(&b, "{{\n \"name\": %q,\n \"source\": \"%s.glb\",\n \"bark\": %d,\n \"leaves\": %d,\n \"height\": %v,\n \"crown_low\": %v,\n \"crown_high\": %v,\n \"crown_r\": %v,\n \"radius\": %v,\n", t.name, t.name, t.bark, t.leaves, t.height, t.crown_low, t.crown_high, t.crown_r, t.radius)
	fmt.sbprintf(&b, " \"bark_color\": [%d, %d, %d, %d],\n \"leaf_color\": [%d, %d, %d, %d],\n", t.bark_color[0], t.bark_color[1], t.bark_color[2], t.bark_color[3], t.leaf_color[0], t.leaf_color[1], t.leaf_color[2], t.leaf_color[3])
	fmt.sbprintf(&b, " \"spots\": [%s]\n}}\n", strings.join(spots[:], ", "))
	return strings.to_string(b)
}

tree_tables :: proc(trees: []Tree_Packed) -> string {
	b := strings.builder_make()
	fmt.sbprintln(&b, "package game\n")
	fmt.sbprintln(&b, "// Made by tools/pack_assets from assets/trees/<name>.glb: do not edit.\n")
	kinds: [dynamic]string
	most := 0
	for t in trees {
		append(&kinds, title(t.name))
		most = max(most, t.bark + t.leaves)
	}
	fmt.sbprintf(&b, "Tree_Model_Kind :: enum {{%s}}\n", strings.join(kinds[:], ", "))
	fmt.sbprintf(&b, "TREE_MAX_VERTS :: %d\n\n", most)
	fmt.sbprintln(&b, "TREE_MODELS := [Tree_Model_Kind]Tree_Model {")
	for t in trees {
		fmt.sbprintf(&b, "\t.%s = {{\n", title(t.name))
		fmt.sbprintf(&b, "\t\tname = %q, // from %s.glb\n", t.name, t.name)
		fmt.sbprintf(&b, "\t\tbark = %d,\n\t\tleaves = %d,\n", t.bark, t.leaves)
		fmt.sbprintf(&b, "\t\theight = %s,\n\t\tcrown_low = %s,\n\t\tcrown_high = %s,\n\t\tcrown_r = %s,\n", num(t.height), num(t.crown_low), num(t.crown_high), num(t.crown_r))
		c := t.bark_color
		fmt.sbprintf(&b, "\t\tbark_color = {{%d, %d, %d, %d}}, // (none: the game's own)\n", c[0], c[1], c[2], c[3])
		c = t.leaf_color
		fmt.sbprintf(&b, "\t\tleaf_color = {{%d, %d, %d, %d}},\n", c[0], c[1], c[2], c[3])
		fmt.sbprintf(&b, "\t\tradius = %s,\n", num(t.radius))
		spots: [dynamic]string
		for s in t.spots {append(&spots, vec(s))}
		fmt.sbprintf(&b, "\t\tspots = []Vec3{{%s}},\n", strings.join(spots[:], ", "))
		fmt.sbprintf(&b, "\t\tmesh = #load(\"../../assets/trees/%s.bin\", [][9]f32),\n", t.name)
		fmt.sbprintln(&b, "\t},")
	}
	fmt.sbprintln(&b, "}")
	return strings.to_string(b)
}
// Turns inside-out pieces outwards. A piece is faces joined by edges that two
// faces share (points at one place being one point). A closed piece, every
// edge of it shared by two faces, has an inside: its faces are wound to agree
// with each other, and if what they enclose comes out negative it is inside
// out and every face of it is turned over. An open piece (a leaf, a blade of
// grass, a patch of moss) has no inside and is left as it was modelled.
face_outwards :: proc(points: []Vec3, tris: []u32) -> (turned: int) {
	key := make(map[Vec3]u32)
	id := make([]u32, len(points))
	for p, i in points {
		k, found := key[p]
		if !found {
			k = u32(len(key))
			key[p] = k
		}
		id[i] = k
	}
	nt := len(tris) / 3
	Edge :: [2]u32
	edge_key :: proc(a, b: u32) -> Edge {return {min(a, b), max(a, b)}}
	edges := make(map[Edge][dynamic]int)
	for t in 0 ..< nt {
		for k in 0 ..< 3 {
			e := edge_key(id[tris[3 * t + k]], id[tris[3 * t + (k + 1) % 3]])
			if !(e in edges) {edges[e] = {}}
			list := &edges[e]
			append(list, t)
		}
	}
	runs :: proc(tris: []u32, id: []u32, t: int, a, b: u32) -> bool {
		for k in 0 ..< 3 {
			if id[tris[3 * t + k]] == a && id[tris[3 * t + (k + 1) % 3]] == b {return true}
		}
		return false
	}
	flip :: proc(tris: []u32, t: int) {
		tris[3 * t + 1], tris[3 * t + 2] = tris[3 * t + 2], tris[3 * t + 1]
	}
	seen := make([]bool, nt)
	for seed in 0 ..< nt {
		if seen[seed] {continue}
		// The piece, its faces wound to agree as it is gathered.
		piece: [dynamic]int
		append(&piece, seed)
		seen[seed] = true
		closed := true
		for i := 0; i < len(piece); i += 1 {
			t := piece[i]
			for k in 0 ..< 3 {
				a, b := id[tris[3 * t + k]], id[tris[3 * t + (k + 1) % 3]]
				list := edges[edge_key(a, b)]
				if len(list) != 2 {
					closed = false
					continue
				}
				for u in list {
					if u == t || seen[u] {continue}
					seen[u] = true
					append(&piece, u)
				}
			}
		}
		if !closed {continue}
		// Wound to agree, from the seed.
		agreed := make(map[int]bool)
		agreed[seed] = true
		queue: [dynamic]int
		append(&queue, seed)
		changed: [dynamic]int
		for i := 0; i < len(queue); i += 1 {
			t := queue[i]
			for k in 0 ..< 3 {
				a, b := id[tris[3 * t + k]], id[tris[3 * t + (k + 1) % 3]]
				for u in edges[edge_key(a, b)] {
					if u == t || agreed[u] {continue}
					if runs(tris, id, u, a, b) {
						flip(tris, u)
						append(&changed, u)
					}
					agreed[u] = true
					append(&queue, u)
				}
			}
		}
		volume: f32
		for t in piece {
			volume += linalg.dot(points[tris[3 * t]], linalg.cross(points[tris[3 * t + 1]], points[tris[3 * t + 2]]))
		}
		if volume < 0 {
			for t in piece {flip(tris, t)}
			turned += len(piece) - len(changed)
		} else {
			turned += len(changed)
		}
	}
	return
}
