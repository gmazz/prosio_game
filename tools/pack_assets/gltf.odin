package pack_assets

// Reading a GLB: its nodes posed at rest or part way into an animation, and
// the vertices of its meshes.

import "core:math"
import "core:math/linalg"
import "core:strings"
import "vendor:cgltf"

Mat4 :: matrix[4, 4]f32
Vec3 :: [3]f32
Quat :: [4]f32 // x, y, z, w, as glTF keeps them

load_glb :: proc(asset, path: string) -> ^cgltf.data {
	opts: cgltf.options
	cpath := strings.clone_to_cstring(path)
	data, res := cgltf.parse_file(opts, cpath)
	if res != .success {
		fail(asset, "cannot read %s (%v)", path, res)
	}
	if r := cgltf.load_buffers(opts, data, cpath); r != .success {
		fail(asset, "cannot read the buffers of %s (%v)", path, r)
	}
	if r := cgltf.validate(data); r != .success {
		fail(asset, "%s is not a valid glTF file (%v)", path, r)
	}
	for &n in data.nodes {
		if n.has_matrix {
			fail(asset, "node %s is given as a matrix; export translation, rotation and scale", n.name)
		}
	}
	return data
}

// Every node's own translation, rotation and scale, by node number.
Pose :: struct {
	t, s: []Vec3,
	r:    []Quat,
}

rest_pose :: proc(data: ^cgltf.data) -> Pose {
	n := len(data.nodes)
	p := Pose{make([]Vec3, n), make([]Vec3, n), make([]Quat, n)}
	for &node, i in data.nodes {
		p.t[i] = node.has_translation ? node.translation : {}
		p.s[i] = node.has_scale ? node.scale : {1, 1, 1}
		p.r[i] = node.has_rotation ? node.rotation : {0, 0, 0, 1}
	}
	return p
}

copy_pose :: proc(dst, src: Pose) {
	copy(dst.t, src.t)
	copy(dst.s, src.s)
	copy(dst.r, src.r)
}

quat_matrix :: proc(q: Quat) -> Mat4 {
	x, y, z, w := q.x, q.y, q.z, q.w
	return Mat4 {
		1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w), 0,
		2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w), 0,
		2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y), 0,
		0, 0, 0, 1,
	}
}

local_matrix :: proc(data: ^cgltf.data, p: Pose, node: ^cgltf.node) -> Mat4 {
	i := cgltf.node_index(data, node)
	t, s := p.t[i], p.s[i]
	m := quat_matrix(p.r[i])
	for c in 0 ..< 3 {
		for r in 0 ..< 3 {
			m[r, c] *= s[c]
		}
		m[c, 3] = t[c]
	}
	return m
}

world_matrix :: proc(data: ^cgltf.data, p: Pose, node: ^cgltf.node) -> Mat4 {
	m := local_matrix(data, p, node)
	for n := node.parent; n != nil; n = n.parent {
		m = local_matrix(data, p, n) * m
	}
	return m
}

find_animation :: proc(data: ^cgltf.data, name: string) -> ^cgltf.animation {
	for &a in data.animations {
		if string(a.name) == name {
			return &a
		}
	}
	return nil
}

// When an animation starts and ends, in seconds.
animation_span :: proc(a: ^cgltf.animation) -> (t0, t1: f32) {
	t0, t1 = math.F32_MAX, -math.F32_MAX
	for &s in a.samplers {
		lo, hi: f32
		_ = cgltf.accessor_read_float(s.input, 0, &lo, 1)
		_ = cgltf.accessor_read_float(s.input, s.input.count - 1, &hi, 1)
		t0, t1 = min(t0, lo), max(t1, hi)
	}
	return
}

// Poses the nodes an animation moves as they are t seconds into it; the
// rest stay as they were.
apply_animation :: proc(data: ^cgltf.data, a: ^cgltf.animation, t: f32, p: Pose) {
	for &ch in a.channels {
		if ch.target_node == nil {
			continue
		}
		i := cgltf.node_index(data, ch.target_node)
		#partial switch ch.target_path {
		case .translation:
			v := sample(ch.sampler, t, 3, false)
			p.t[i] = {v[0], v[1], v[2]}
		case .scale:
			v := sample(ch.sampler, t, 3, false)
			p.s[i] = {v[0], v[1], v[2]}
		case .rotation:
			v := sample(ch.sampler, t, 4, true)
			p.r[i] = linalg.normalize(Quat{v[0], v[1], v[2], v[3]})
		}
	}
}

@(private)
read_key :: proc(acc: ^cgltf.accessor, k: uint, n: int) -> (v: [4]f32) {
	f := floats_of(acc)
	for i in 0 ..< n {
		v[i] = f[int(k) * n + i]
	}
	return
}

// An accessor's numbers, sparse ones applied (as the Blender exporter writes
// shape keys), normalised ones as fractions; read once and kept.
unpacked: map[^cgltf.accessor][]f32

floats_of :: proc(acc: ^cgltf.accessor) -> []f32 {
	if f, ok := unpacked[acc]; ok {
		return f
	}
	n := cgltf.accessor_unpack_floats(acc, nil, 0)
	f := make([]f32, n)
	_ = cgltf.accessor_unpack_floats(acc, raw_data(f), n)
	unpacked[acc] = f
	return f
}

// A sampler's value at t: held before its first key and after its last.
sample :: proc(s: ^cgltf.animation_sampler, t: f32, n: int, rotation: bool) -> [4]f32 {
	keys := s.input.count
	time :: proc(acc: ^cgltf.accessor, k: uint) -> f32 {
		return floats_of(acc)[k]
	}
	cubic := s.interpolation == .cubic_spline
	value :: proc(s: ^cgltf.animation_sampler, k: uint, n: int, cubic: bool) -> [4]f32 {
		return read_key(s.output, cubic ? 3 * k + 1 : k, n)
	}
	if keys == 1 || t <= time(s.input, 0) {
		return value(s, 0, n, cubic)
	}
	if t >= time(s.input, keys - 1) {
		return value(s, keys - 1, n, cubic)
	}
	lo, hi := uint(0), keys - 1 // time(lo) <= t < time(hi)
	for hi - lo > 1 {
		mid := (lo + hi) / 2
		if time(s.input, mid) <= t {
			lo = mid
		} else {
			hi = mid
		}
	}
	t0, t1 := time(s.input, lo), time(s.input, hi)
	u := (t - t0) / (t1 - t0)
	a, b := value(s, lo, n, cubic), value(s, hi, n, cubic)
	switch s.interpolation {
	case .step:
		return a
	case .cubic_spline:
		d := t1 - t0
		out_a := read_key(s.output, 3 * lo + 2, n)
		in_b := read_key(s.output, 3 * hi, n)
		u2, u3 := u * u, u * u * u
		r: [4]f32
		for i in 0 ..< n {
			r[i] = (2 * u3 - 3 * u2 + 1) * a[i] + (u3 - 2 * u2 + u) * d * out_a[i] + (-2 * u3 + 3 * u2) * b[i] + (u3 - u2) * d * in_b[i]
		}
		return r
	case .linear:
		if rotation {
			return slerp(a, b, u)
		}
	}
	return a + (b - a) * u
}

slerp :: proc(a, b: [4]f32, u: f32) -> [4]f32 {
	b := b
	d := linalg.dot(a, b)
	if d < 0 {
		b, d = -b, -d
	}
	if d > 0.9995 {
		return linalg.normalize(a + (b - a) * u)
	}
	th := math.acos(d)
	return (a * math.sin((1 - u) * th) + b * math.sin(u * th)) / math.sin(th)
}

find_attribute :: proc(prim: ^cgltf.primitive, type: cgltf.attribute_type, index: i32 = 0) -> ^cgltf.accessor {
	for &at in prim.attributes {
		if at.type == type && at.index == index {
			return at.data
		}
	}
	return nil
}

read_vec3 :: proc(acc: ^cgltf.accessor, k: uint) -> Vec3 {
	f := floats_of(acc)
	c := int(cgltf.num_components(acc.type))
	return {f[int(k) * c], f[int(k) * c + 1], f[int(k) * c + 2]}
}

read_vec4 :: proc(acc: ^cgltf.accessor, k: uint) -> (v: [4]f32) {
	f := floats_of(acc)
	c := int(cgltf.num_components(acc.type))
	for i in 0 ..< min(c, 4) {
		v[i] = f[int(k) * c + i]
	}
	return
}

read_uvec4 :: proc(acc: ^cgltf.accessor, k: uint) -> (v: [4]u32) {
	_ = cgltf.accessor_read_uint(acc, k, &v[0], 4)
	return
}

// A primitive's triangles, as numbers of its vertices.
triangles :: proc(asset: string, prim: ^cgltf.primitive) -> []u32 {
	if prim.type != .triangles {
		fail(asset, "a mesh is not made of triangles (%v)", prim.type)
	}
	pos := find_attribute(prim, .position)
	if pos == nil {
		fail(asset, "a mesh has no positions")
	}
	n := prim.indices != nil ? prim.indices.count : pos.count
	out := make([]u32, n)
	for k in 0 ..< n {
		out[k] = prim.indices != nil ? u32(cgltf.accessor_read_index(prim.indices, k)) : u32(k)
	}
	return out
}

transform_point :: proc(m: Mat4, p: Vec3) -> Vec3 {
	return (m * [4]f32{p.x, p.y, p.z, 1}).xyz
}

transform_dir :: proc(m: Mat4, d: Vec3) -> Vec3 {
	return (m * [4]f32{d.x, d.y, d.z, 0}).xyz
}

// Each point's smooth normal: the faces round it, each as much as the angle
// it makes there (as Blender does, though Blender takes whole polygons and a
// GLB keeps only triangles). Points at one place are one point (the exporter
// splits a point where materials meet, and along texture seams).
smooth_normals :: proc(points: []Vec3, tris: []u32) -> []Vec3 {
	key := make(map[Vec3]int)
	ids := make([]int, len(points))
	for p, i in points {
		id, found := key[p]
		if !found {
			id = len(key)
			key[p] = id
		}
		ids[i] = id
	}
	sum := make([]Vec3, len(key))
	for t := 0; t + 2 < len(tris); t += 3 {
		c := [3]Vec3{points[tris[t]], points[tris[t + 1]], points[tris[t + 2]]}
		n := linalg.cross(c[1] - c[0], c[2] - c[0])
		if linalg.length(n) == 0 {
			continue
		}
		n = linalg.normalize(n)
		for k in 0 ..< 3 {
			e1 := c[(k + 1) % 3] - c[k]
			e2 := c[(k + 2) % 3] - c[k]
			if linalg.length(e1) == 0 || linalg.length(e2) == 0 {
				continue
			}
			angle := math.acos(clamp(linalg.dot(linalg.normalize(e1), linalg.normalize(e2)), -1, 1))
			sum[ids[tris[t + k]]] += n * angle
		}
	}
	out := make([]Vec3, len(points))
	for i in 0 ..< len(points) {
		out[i] = linalg.normalize0(sum[ids[i]])
	}
	return out
}

// Smooth normals that keep hard edges: points at one place are welded, but
// a point takes in only the faces round that place that lie within
// `hard_angle` (degrees) of its own faces. A GLB splits points both where an
// edge is meant to stay sharp and along its texture seams; this smooths the
// seams and leaves the sharp edges sharp.
smooth_normals_hard :: proc(points: []Vec3, tris: []u32, hard_angle: f32) -> []Vec3 {
	key := make(map[Vec3]int)
	ids := make([]int, len(points))
	for p, i in points {
		id, found := key[p]
		if !found {
			id = len(key)
			key[p] = id
		}
		ids[i] = id
	}
	Corner :: struct {
		normal: Vec3,
		angle:  f32,
		point:  int,
	}
	at := make([][dynamic]Corner, len(key))
	for t := 0; t + 2 < len(tris); t += 3 {
		c := [3]Vec3{points[tris[t]], points[tris[t + 1]], points[tris[t + 2]]}
		n := linalg.cross(c[1] - c[0], c[2] - c[0])
		if linalg.length(n) == 0 {
			continue
		}
		n = linalg.normalize(n)
		for k in 0 ..< 3 {
			e1 := c[(k + 1) % 3] - c[k]
			e2 := c[(k + 2) % 3] - c[k]
			if linalg.length(e1) == 0 || linalg.length(e2) == 0 {
				continue
			}
			angle := math.acos(clamp(linalg.dot(linalg.normalize(e1), linalg.normalize(e2)), -1, 1))
			p := int(tris[t + k])
			append(&at[ids[p]], Corner{n, angle, p})
		}
	}
	least := math.cos(hard_angle * math.RAD_PER_DEG)
	out := make([]Vec3, len(points))
	for i in 0 ..< len(points) {
		own: Vec3
		for c in at[ids[i]] {
			if c.point == i {
				own += c.normal * c.angle
			}
		}
		own = linalg.normalize0(own)
		sum: Vec3
		for c in at[ids[i]] {
			if linalg.dot(c.normal, own) >= least {
				sum += c.normal * c.angle
			}
		}
		out[i] = linalg.normalize0(sum)
	}
	return out
}
