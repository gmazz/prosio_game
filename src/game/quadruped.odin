package game

import "core:math"
import "core:math/linalg"

// Four-legged animals made from the animated animal pack (see
// tools/pack_quadruped.py): a mesh that bends on a skeleton, and the pack's
// animations, reshaped and recoloured for the game. The goat and the billy
// goat are drawn this way, and the fox (unless PACK_FOX is off, when the fox
// of the asset pilot is drawn instead).
//
// The game decides the pose, as it does for the drawn animals: it picks an
// animation by what the animal is doing (standing, walking, running, licking,
// lying dead, flying, swimming) and runs it at the animal's own pace; the
// front and rear halves of the body follow the frames the game gives them
// (so a held goat bends at the middle); and held by its hind legs, both legs
// are turned and stretched to reach his hooves. The mesh is bent on the CPU
// each time it is drawn, into fixed buffers: nothing is allocated.
//
// The pack's own eyes are hidden: the game's big cartoon eyes are drawn in
// their place, so a goat still shuts them when dizzy and shows crosses when
// dead. A nanny goat's udder still shows whether she has milk.
QUAD_ANIMALS :: #config(QUAD_ANIMALS, true) // false draws the goats as before, from shapes
PACK_FOX :: #config(PACK_FOX, true) // the fox from the pack; false draws the asset pilot's fox instead (-define:PACK_FOX=false)
QUAD_EYE_SIZE :: f32(0.11) // the cartoon eyes, in the animal's own units (it is scaled by its radius)
QUAD_RUN :: f32(0.7) // above this share of its top speed it gallops rather than walks

Quad_Vertex :: [17]f32 // position, flat normal, smooth normal, four bones, four weights
Quad_Group :: struct {
	name:        string,
	first, count: int,
}
Quad_Clip :: struct {
	name:         string,
	first, count: int,
	fps:          f32,
	loop:         bool,
	stride:       f32, // how far the animal goes over the ground in one cycle, in the model's units (0 if it stays put)
}
Quad_Socket :: struct {
	name:        string,
	pos, normal: Vec3,
	bone:        int,
}
Quad_Model :: struct {
	name:    string,
	bones:   []string,
	parents: []int,
	front:   []bool, // moves with the front half of the body
	groups:  []Quad_Group,
	clips:   []Quad_Clip,
	sockets: []Quad_Socket,
	mesh:    []Quad_Vertex,
	rest:    [][16]f32, // each bone's rest frame, inverted
	frames:  [][12]f32, // each sampled frame, each bone: a 3 by 4 frame, column by column
}

// The bent mesh, in the world, for the platform to draw: positions, flat
// normals (for the light) and smooth normals (for the outline).
quad_pos: [QUAD_MAX_VERTS][3]f32
quad_flat: [QUAD_MAX_VERTS][3]f32
quad_smooth: [QUAD_MAX_VERTS][3]f32

// Which model draws an animal of this kind, if any.
quad_model_for :: proc(kind: Enemy_Kind) -> (Quad_Kind, bool) {
	when QUAD_ANIMALS {
		#partial switch kind {
		case .Goat:
			return .Goat, true
		case .Billy:
			return .Billy, true
		case .Fox:
			if PACK_FOX {
				return .Packfox, true
			}
		}
	}
	return {}, false
}

quad_bone :: proc(m: ^Quad_Model, name: string) -> int {
	for b, i in m.bones {
		if b == name {
			return i
		}
	}
	return -1
}

quad_socket :: proc(m: ^Quad_Model, name: string) -> (Quad_Socket, bool) {
	for s in m.sockets {
		if s.name == name {
			return s, true
		}
	}
	return {}, false
}

quad_clip :: proc(m: ^Quad_Model, name: string) -> (Quad_Clip, bool) {
	for c in m.clips {
		if c.name == name {
			return c, true
		}
	}
	return {}, false
}

quad_frame :: proc(f: [12]f32) -> Mat4 {
	return Mat4{f[0], f[3], f[6], f[9], f[1], f[4], f[7], f[10], f[2], f[5], f[8], f[11], 0, 0, 0, 1}
}

// Every bone's frame in the model, part way (seconds) into an animation;
// a looping one goes round, one that does not stops at its end.
quad_sample :: proc(m: ^Quad_Model, name: string, t: f32, out: ^[QUAD_MAX_BONES]Mat4) {
	nb := len(m.bones)
	c, ok := quad_clip(m, name)
	if !ok {
		c, _ = quad_clip(m, "Idle")
	}
	x := t * c.fps
	if c.loop {
		x = math.mod(x, f32(c.count))
		if x < 0 {
			x += f32(c.count)
		}
	} else {
		x = clamp(x, 0, f32(c.count - 1))
	}
	k0 := int(x)
	k1 := c.loop ? (k0 + 1) % c.count : min(k0 + 1, c.count - 1)
	k := x - f32(k0)
	for b in 0 ..< nb {
		a := m.frames[(c.first + k0) * nb + b]
		z := m.frames[(c.first + k1) * nb + b]
		mix: [12]f32
		for i in 0 ..< 12 {
			mix[i] = a[i] + (z[i] - a[i]) * k
		}
		out[b] = quad_frame(mix)
	}
}

// Where a point fixed to a bone at rest is, with the bones as they are.
quad_carry :: proc(m: ^Quad_Model, pose: ^[QUAD_MAX_BONES]Mat4, bone: int, p: Vec3) -> Vec3 {
	return (pose[bone] * transmute(Mat4)m.rest[bone] * [4]f32{p.x, p.y, p.z, 1}).xyz
}

// Turns and stretches a run of bones about root, so that tip comes to target.
quad_reach :: proc(pose: ^[QUAD_MAX_BONES]Mat4, bones: []int, root, tip, target: Vec3) {
	from := tip - root
	to := target - root
	if linalg.length(from) < 1e-4 || linalg.length(to) < 1e-4 {
		return
	}
	turn := linalg.matrix4_from_quaternion(linalg.quaternion_between_two_vector3(linalg.normalize(from), linalg.normalize(to)))
	d := linalg.normalize(to)
	k := linalg.length(to) / linalg.length(from)
	stretch := Mat4(1)
	for i in 0 ..< 3 {
		for j in 0 ..< 3 {
			stretch[i, j] += (k - 1) * d[i] * d[j]
		}
	}
	move := translate(root) * stretch * turn * translate(-root)
	for b in bones {
		if b >= 0 {
			pose[b] = move * pose[b]
		}
	}
}

// What the animal is doing, as an animation and how far into it (seconds).
quad_action :: proc(m: ^Quad_Model, e: Enemy) -> (clip: string, t: f32) {
	offset := e.home.x * 0.37 + e.home.y * 0.53 // so that a herd does not move as one
	speed := linalg.length(e.vel)
	switch e.state {
	case .Dead:
		return "Death", 99
	case .Swimming:
		if e.ko {
			return "Death", 99
		}
		return "Gallop", quad_stepped(m, "Gallop", e)
	case .Flying:
		return "Gallop_Jump", 0.4
	case .Held:
		if e.ko {
			return "Death", 99 // (lying no more: see quad_skin)
		}
		return "Gallop", e.hop / math.TAU // kicking
	case .Dizzy:
		return "Idle_HitReact_Left", 0.25
	case .Chase, .Gone:
	}
	switch {
	case e.licking:
		return "Eating", g.time + offset
	case speed < 0.3:
		return "Idle", g.time + offset
	case speed > ENEMY_SPEED[e.kind] * QUAD_RUN || e.hunt == .Charge:
		return "Gallop", quad_stepped(m, "Gallop", e)
	}
	return "Walk", quad_stepped(m, "Walk", e)
}

// How far into a walking or running animation an animal is, by how far it
// has gone: one cycle for each stride (measured from the animation when it
// was packed), so its legs keep step with the ground and do not slide.
quad_stepped :: proc(m: ^Quad_Model, name: string, e: Enemy) -> f32 {
	c, ok := quad_clip(m, name)
	if !ok || c.stride <= 0 {
		return e.hop / math.TAU
	}
	stride := c.stride * ENEMY_RADIUS[e.kind] // metres a cycle
	return e.gait / stride * f32(c.count) / c.fps
}

// Each bone's whole journey for an animal as it is now: from rest, through
// its pose, to where its half of the body is in the world. False if its
// kind has no packed model.
quad_skin :: proc(pose: Animal_Pose, e: Enemy, skin: ^[QUAD_MAX_BONES]Mat4) -> (Quad_Kind, bool) {
	qk, ok := quad_model_for(e.kind)
	if !ok {
		return {}, false
	}
	m := &QUAD_MODELS[qk]
	r := ENEMY_RADIUS[e.kind]
	bones: [QUAD_MAX_BONES]Mat4
	clip, t := quad_action(m, e)
	quad_sample(m, clip, t, &bones)

	if e.state == .Held && e.ko {
		// Limp, as the death animation leaves it, but held: the body is not
		// laid down on the ground (it hangs where his hand puts it), so the
		// animation's own fall is taken out again.
		body := quad_bone(m, "Body")
		if body >= 0 {
			undo := linalg.inverse(transmute(Mat4)m.rest[body]) * linalg.inverse(bones[body])
			for b in 0 ..< len(m.bones) {
				bones[b] = undo * bones[b]
			}
		}
	}
	rear, front := pose.rear, pose.front
	lying := e.state == .Dead || (e.state == .Swimming && e.ko)
	if lying {
		// The death animation lays it down on its side: the body frame stays
		// upright. Drowned, it floats feet up.
		lift: f32 = 0
		turn := Mat4(1)
		if e.state == .Swimming {
			lift = 0.05 + 0.03 * math.sin(g.time * 2.5 + e.pos.x)
			turn = translate({0, 0.55, 0}) * rot_z(-math.PI / 2) * translate({0, -0.55, 0})
		}
		rear = translate({e.pos.x, lift, e.pos.y}) * rot_y(e.facing) * scale({r, r, r}) * turn
		front = rear
	}
	if pose.held && e.kind == .Fox {
		// Held by the tip of its tail: the tail runs to his hoof.
		root, has_root := quad_socket(m, "tail_root")
		tip, has_tip := quad_socket(m, "tail_tip")
		if has_root && has_tip {
			tail: [QUAD_MAX_BONES]int
			n := 0
			for name, b in m.bones {
				if len(name) >= 4 && name[:4] == "Tail" {
					tail[n] = b
					n += 1
				}
			}
			hand := linalg.inverse(rear) * [4]f32{pose.hand.x, pose.hand.y, pose.hand.z, 1}
			quad_reach(&bones, tail[:n], quad_carry(m, &bones, root.bone, root.pos), quad_carry(m, &bones, tip.bone, tip.pos), hand.xyz)
		}
	} else if pose.held && !held_up(e.kind) {
		// Both hind legs run to his hooves, one in each.
		inv := linalg.inverse(rear)
		for side in ([2]string{"L", "R"}) {
			s: f32 = side == "L" ? 1 : -1
			hip, ok_hip := quad_socket(m, side == "L" ? "hip_L" : "hip_R")
			hoof, ok_hoof := quad_socket(m, side == "L" ? "hoof_L" : "hoof_R")
			if !ok_hip || !ok_hoof {
				continue
			}
			leg := [5]int {
				quad_bone(m, side == "L" ? "BackLeg.L" : "BackLeg.R"),
				quad_bone(m, side == "L" ? "BackUpperLeg.L" : "BackUpperLeg.R"),
				quad_bone(m, side == "L" ? "BackLowerLeg.L" : "BackLowerLeg.R"),
				quad_bone(m, side == "L" ? "IKBackLeg.L" : "IKBackLeg.R"),
				quad_bone(m, side == "L" ? "FFB.L" : "FFB.R"),
			}
			grip := quad_grip(pose, s)
			grip = (inv * [4]f32{grip.x, grip.y, grip.z, 1}).xyz
			quad_reach(&bones, leg[:], quad_carry(m, &bones, hip.bone, hip.pos), quad_carry(m, &bones, hoof.bone, hoof.pos), grip)
		}
	}
	for b in 0 ..< len(m.bones) {
		skin[b] = (m.front[b] ? front : rear) * bones[b] * transmute(Mat4)m.rest[b]
	}
	return qk, true
}

// Where one of a held goat's hind hooves is gripped: his hand, a little to
// one side.
quad_grip :: proc(pose: Animal_Pose, side: f32) -> Vec3 {
	return pose.hand + hold_apart(side)
}

// Where a socket of the model is in the world, for these bones.
quad_socket_at :: proc(qk: Quad_Kind, skin: ^[QUAD_MAX_BONES]Mat4, name: string) -> Vec3 {
	sock, _ := quad_socket(&QUAD_MODELS[qk], name)
	return (skin[sock.bone] * [4]f32{sock.pos.x, sock.pos.y, sock.pos.z, 1}).xyz
}

// Draws an animal from its packed model. False if its kind has none.
draw_quad_enemy :: proc(pose: Animal_Pose, e: Enemy) -> bool {
	skin: [QUAD_MAX_BONES]Mat4
	qk, ok := quad_skin(pose, e, &skin)
	if !ok {
		return false
	}
	m := &QUAD_MODELS[qk]
	for v, i in m.mesh {
		p, n, sn: Vec3
		for k in 0 ..< 4 {
			w := v[13 + k]
			if w <= 0 {
				continue
			}
			s := &skin[int(v[9 + k])]
			p += w * (s^ * [4]f32{v[0], v[1], v[2], 1}).xyz
			n += w * (s^ * [4]f32{v[3], v[4], v[5], 0}).xyz
			sn += w * (s^ * [4]f32{v[6], v[7], v[8], 0}).xyz
		}
		quad_pos[i] = p
		quad_flat[i] = linalg.normalize0(n)
		quad_smooth[i] = linalg.normalize0(sn)
	}
	colors: [QUAD_MAX_GROUPS]Color
	shown: [QUAD_MAX_GROUPS]bool
	for grp, i in m.groups {
		colors[i], shown[i] = quad_color(e.kind, grp.name)
	}
	draw_quad_mesh(qk, len(m.mesh), colors[:len(m.groups)], shown[:len(m.groups)])

	// The game's own cartoon eyes, and a nanny goat's udder.
	head := quad_bone(m, "Head")
	for name in ([2]string{"eye_L", "eye_R"}) {
		eye, has := quad_socket(m, name)
		if !has || head < 0 {
			continue
		}
		z := linalg.normalize0(eye.normal)
		x := linalg.normalize0(linalg.cross(Vec3{0, 1, 0}, z))
		y := linalg.cross(z, x)
		at := Mat4{x.x, y.x, z.x, eye.pos.x, x.y, y.y, z.y, eye.pos.y, x.z, y.z, z.z, eye.pos.z, 0, 0, 0, 1}
		draw_cute_eye(skin[head] * at, QUAD_EYE_SIZE, pose.dizzy, pose.dead)
	}
	if e.has_loot {
		// What it stole, in its mouth.
		if mouth, has := quad_socket(m, "mouth"); has {
			color := ITEM_COLOR[e.loot] // (things that are made have no colour of their own here)
			ball(skin[mouth.bone] * translate(mouth.pos), {}, {0.26, 0.2, 0.2}, color.a > 0 ? color : CRUST)
		}
	}
	if e.kind == .Goat && !pose.dead {
		if udder, has := quad_socket(m, "udder"); has {
			full: f32 = e.milk_t <= 0 ? 1 : 0.45
			at := skin[udder.bone] * translate(udder.pos)
			ball(at, {0, 0.05, 0}, Vec3{0.3, 0.26, 0.3} * full, UDDER_PINK)
			for side in ([2]f32{-1, 1}) {
				ball(at, {side * 0.1 * full, 0.05 - 0.2 * full, 0.02}, Vec3{0.06, 0.09, 0.06} * full, UDDER_PINK)
			}
		}
	}
	return true
}

// The top of a packed animal's head, as it is now: where stars go round
// when it is dizzy.
quad_head_top :: proc(pose: Animal_Pose, e: Enemy) -> Vec3 {
	skin: [QUAD_MAX_BONES]Mat4
	qk, ok := quad_skin(pose, e, &skin)
	if !ok {
		return (pose.front * [4]f32{0, 2.3, 0.6, 1}).xyz
	}
	eye := quad_socket_at(qk, &skin, "eye_L")
	return eye + {0, ENEMY_RADIUS[e.kind] * 0.5, 0}
}

// The colour of each part of a packed animal, by the material it came with
// (and whether to draw it: the pack's eyes are not).
quad_color :: proc(kind: Enemy_Kind, group: string) -> (Color, bool) {
	if len(group) >= 3 && group[:3] == "Eye" {
		return {}, false
	}
	if kind == .Fox {
		switch group {
		case "Main":
			return FOX_COAT, true
		case "Main_Light":
			return ANIMAL_CREAM, true
		case "Black":
			return FOX_FEET, true
		case "Grey":
			return {200, 196, 190, 255}, true
		}
		return FOX_COAT, true
	}
	billy := kind == .Billy
	switch group {
	case "Main":
		return billy ? BILLY_COAT : GOAT_WHITE, true
	case "Main_Light":
		return billy ? BILLY_COAT : GOAT_WHITE, true
	case "Main_Dark":
		return billy ? BILLY_DARK : GOAT_PATCH, true
	case "Muzzle":
		return GOAT_PINK, true
	case "Hooves":
		return GOAT_HOOF, true
	case "Horn":
		return GOAT_HORN, true
	case "Beard":
		return billy ? BILLY_DARK : GOAT_PATCH, true
	}
	return billy ? BILLY_COAT : GOAT_WHITE, true
}
