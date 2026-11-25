package pack_assets

// The fox of the asset pilot: rigid parts, each on one joint (see
// src/game/fox.odin; drawn with -define:PACK_FOX=false). From
// assets/fox/fox.glb and its manifest fox.asset.json it writes
//
//   vertices.bin  each point: position and normal (6 floats)
//   indices.bin   triangles, 16-bit numbers within their group
//
// and src/game/fox_asset.odin: the joints, each one's pivot, the mouth and
// tail-grip sockets, the tail's sweep, and the groups (one joint and one
// colour each).

import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:os"
import "core:slice"
import "core:strings"
import "vendor:cgltf"

FOX_SWEEP_ANIMATION :: "tail_sweep"
FOX_SWEEP_JOINT :: "tail"
// Faces meeting at more than this (degrees) meet at a sharp edge.
FOX_HARD_ANGLE :: 45

Fox_Packed :: struct {
	vertices: [dynamic][6]f32,
	indices:  [dynamic]u16,
	table:    string,
}

pack_fox :: proc(a, dir: string) -> (f: Fox_Packed) {
	Manifest :: struct {
		version:                  int,
		model, units, up, forward: string,
		sockets:                  map[string]string,
	}
	text, err := os.read_entire_file(join(dir, "fox.asset.json"), context.allocator)
	if err != nil {
		fail(a, "cannot read fox.asset.json (%v)", err)
	}
	man: Manifest
	if e := json.unmarshal(text, &man); e != nil {
		fail(a, "cannot read fox.asset.json (%v)", e)
	}
	if man.version != 1 || man.units != "metres" || man.up != "+Y" || man.forward != "+Z" {
		fail(a, "fox.asset.json is not version 1 in metres, +Y up, +Z forward")
	}
	glb := join(dir, man.model)
	data := load_glb(a, glb)
	if len(data.skins) != 1 || len(data.meshes) != 1 {
		fail(a, "%s must have one skin and one mesh", glb)
	}
	skin := &data.skins[0]
	names := make([]string, len(skin.joints))
	joint :: proc(name: string) -> string {
		s, _ := strings.replace_all(name, ".", "_")
		return s
	}
	for j, i in skin.joints {
		names[i] = string(j.name)
	}
	for want in ([]string{"mouth", "tail_grip"}) {
		if !(want in man.sockets) || !slice.contains(names, man.sockets[want]) {
			fail(a, "%s has no joint for the socket %s", glb, want)
		}
	}
	pivots := make([]Vec3, len(names))
	for i in 0 ..< len(names) {
		inv: Mat4
		_ = cgltf.accessor_read_float(skin.inverse_bind_matrices, uint(i), raw_data(&inv), 16)
		pivots[i] = linalg.inverse(inv)[3].xyz
	}

	groups := strings.builder_make()
	for &prim in data.meshes[0].primitives {
		pos := find_attribute(&prim, .position)
		jnt := find_attribute(&prim, .joints)
		wgt := find_attribute(&prim, .weights)
		if jnt == nil || wgt == nil {
			fail(a, "the fox's mesh has no weights")
		}
		tris := triangles(a, &prim)
		points := make([]Vec3, pos.count)
		for k in 0 ..< int(pos.count) {
			points[k] = read_vec3(pos, uint(k))
		}
		// Each triangle to the one joint all its points are wholly on, in the
		// order the joints first come.
		order: [dynamic]int
		batches := make(map[int][dynamic]u32)
		for t := 0; t + 2 < len(tris); t += 3 {
			bone := -1
			for c in 0 ..< 3 {
				v := uint(tris[t + c])
				bj := read_uvec4(jnt, v)
				bw := read_vec4(wgt, v)
				slot := 0
				for s in 1 ..< 4 {
					if bw[s] > bw[slot] {slot = s}
				}
				if bw[slot] < 0.99999 {
					fail(a, "point %d is not wholly on one joint (the fox is drawn as rigid parts)", v)
				}
				if bone >= 0 && bone != int(bj[slot]) {
					fail(a, "a triangle spans two joints (%s and %s)", names[bone], names[bj[slot]])
				}
				bone = int(bj[slot])
			}
			if !(bone in batches) {
				append(&order, bone)
				batches[bone] = {}
			}
			b := &batches[bone]
			append(b, tris[t], tris[t + 1], tris[t + 2])
		}
		if prim.material == nil || !prim.material.has_pbr_metallic_roughness {
			fail(a, "a part of the fox has no colour")
		}
		rgb := prim.material.pbr_metallic_roughness.base_color_factor
		color := [4]u8{srgb_byte(rgb[0]), srgb_byte(rgb[1]), srgb_byte(rgb[2]), 255}
		part: [dynamic]Vec3
		for bone in order {
			batch := batches[bone]
			remap := make(map[u32]int)
			first, offset := len(f.vertices), len(f.indices)
			for v in batch {
				if v in remap {
					continue
				}
				remap[v] = len(remap)
				append(&part, points[v])
			}
			local := make([]u32, len(batch))
			for v, i in batch {
				local[i] = u32(remap[v])
				append(&f.indices, u16(remap[v]))
			}
			// Smooth within the part, keeping its sharp edges; never across two
			// parts that touch.
			normals := smooth_normals_hard(part[:], local, FOX_HARD_ANGLE)
			for p, i in part {
				n := normals[i]
				append(&f.vertices, [6]f32{p.x, p.y, p.z, n.x, n.y, n.z})
			}
			clear(&part)
			fmt.sbprintf(&groups, "    {{.%s, %d, %d, %d, %d, {{%d, %d, %d, %d}}}},\n", joint(names[bone]), first, len(remap), offset, len(batch), color[0], color[1], color[2], color[3])
		}
	}
	if len(f.vertices) > 1 << 16 {
		fail(a, "the fox has %d points; it is numbered in 16 bits", len(f.vertices))
	}

	// The tail's sweep: its turn about the GLB's Y (Blender's Z), as it goes.
	anim := find_animation(data, FOX_SWEEP_ANIMATION)
	if anim == nil {
		fail(a, "%s has no animation %s", glb, FOX_SWEEP_ANIMATION)
	}
	sampler: ^cgltf.animation_sampler
	for &ch in anim.channels {
		if ch.target_node != nil && string(ch.target_node.name) == FOX_SWEEP_JOINT && ch.target_path == .rotation {
			sampler = ch.sampler
		}
	}
	if sampler == nil || sampler.interpolation != .linear || sampler.input.count < 2 {
		fail(a, "%s has no sampled sweep of the %s joint", glb, FOX_SWEEP_JOINT)
	}
	b := strings.builder_make()
	fmt.sbprintln(&b, "// Generated by tools/pack_assets from assets/fox: do not edit.")
	fmt.sbprintln(&b, "package game")
	fmt.sbprintln(&b, "")
	joints: [dynamic]string
	for n in names {append(&joints, joint(n))}
	fmt.sbprintf(&b, "Fox_Joint :: enum {{%s}}\n", strings.join(joints[:], ", "))
	fmt.sbprintln(&b, "FOX_PIVOT := [Fox_Joint]Vec3{")
	for n, i in names {
		fmt.sbprintf(&b, "    .%s = %s,\n", joint(n), vec8(pivots[i].x, pivots[i].y, pivots[i].z))
	}
	fmt.sbprintln(&b, "}")
	fmt.sbprintf(&b, "FOX_MOUTH :: Fox_Joint.%s\n", joint(man.sockets["mouth"]))
	fmt.sbprintf(&b, "FOX_GRIP :: Fox_Joint.%s\n", joint(man.sockets["tail_grip"]))
	fmt.sbprintln(&b, "FOX_SWEEP := [?][2]f32{")
	t0 := floats_of(sampler.input)[0]
	for k in 0 ..< int(sampler.input.count) {
		q := read_vec4(sampler.output, uint(k))
		if abs(q.x) + abs(q.y) > 1e-5 {
			fail(a, "the tail must sweep about one axis only")
		}
		fmt.sbprintf(&b, "    %s,\n", vec8(floats_of(sampler.input)[k] - t0, 2 * math.atan2(q.z, q.w)))
	}
	fmt.sbprintln(&b, "}")
	fmt.sbprintln(&b, "FOX_GROUPS := [?]Fox_Group{")
	strings.write_string(&b, strings.to_string(groups))
	fmt.sbprintln(&b, "}")
	f.table = strings.to_string(b)
	return
}

vec8 :: proc(v: ..f32) -> string {
	parts := make([]string, len(v))
	for x, i in v {
		parts[i] = fmt.tprintf("%.8f", x)
	}
	return fmt.tprintf("{{%s}}", strings.join(parts, ", "))
}
