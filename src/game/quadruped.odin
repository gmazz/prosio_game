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
// The eyes come from the mesh, with separate marks for dizzy and dead poses.
QUAD_ANIMALS :: #config(QUAD_ANIMALS, true) // false draws the goats as before, from shapes
PACK_FOX :: #config(PACK_FOX, true) // the fox from the pack; false draws the asset pilot's fox instead (-define:PACK_FOX=false)
QUAD_FLOOR_EPSILON :: f32(0.0001)

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

// What the animal is doing, as an animation and how far into it (seconds),
// for everything but going about on its feet (see quad_moving).
quad_action :: proc(m: ^Quad_Model, e: Enemy) -> (clip: string, t: f32, moving: bool) {
	offset := e.home.x * 0.37 + e.home.y * 0.53 // so that a herd does not move as one
	if e.impact.kind != .None {
		return "Idle", g.time + offset, e.impact.phase == .Brace
	}
	switch e.state {
	case .Dead:
		return "Death", 99, false
	case .Swimming:
		if e.ko {
			return "Death", 99, false
		}
		c, _ := quad_clip(m, "Gallop")
		return "Gallop", e.gait * f32(c.count) / c.fps, false
	case .Flying:
		return "Gallop_Jump", 0.4, false
	case .Held:
		return "Idle", 0, false // a separate template braces or kicks
	case .Dizzy:
		return "Idle_HitReact_Left", 0.25, false
	case .Chase, .Gone:
	}
	return "Idle", g.time + offset, true
}

// How much of a walk (against standing), and of a gallop (against a walk),
// there is at this speed.
quad_mix :: proc(speed: f32) -> (walk, gallop: f32) {
	walk = smooth(clamp((speed - QUAD_WALK_FROM) / (QUAD_WALK_FULL - QUAD_WALK_FROM), 0, 1))
	gallop = smooth(clamp((speed - QUAD_GALLOP_FROM) / (QUAD_GALLOP_FULL - QUAD_GALLOP_FROM), 0, 1))
	return
}

// Strides a second at this speed: as many as carry it over the ground at
// that speed (each stride measured from the animation when it was packed),
// so its planted feet stay put; but a gallop no slower than looks right.
quad_stride_rate :: proc(kind: Enemy_Kind, speed: f32) -> f32 {
	qk, ok := quad_model_for(kind)
	if !ok {
		return 0
	}
	m := &QUAD_MODELS[qk]
	r := ENEMY_RADIUS[kind]
	walk, has_walk := quad_clip(m, "Walk")
	run, has_run := quad_clip(m, "Gallop")
	if !has_walk || !has_run || walk.stride <= 0 || run.stride <= 0 {
		return speed
	}
	pace := abs(speed) // (going backwards, the same strides, the other way)
	_, gallop := quad_mix(pace)
	walking := pace / (walk.stride * r * quad_step(pace))
	running := max(pace / (run.stride * r), QUAD_GALLOP_SLOWEST * run.fps / f32(run.count))
	return math.sign(speed) * lerp(walking, running, gallop)
}

// How long a walking step is at this speed, as a share of the walk's own.
quad_step :: proc(pace: f32) -> f32 {
	return lerp(QUAD_SHORT_STEP, 1, clamp(pace / QUAD_LONG_STEP_AT, 0, 1))
}

// Whether this kind uses the packed quadruped motion templates.
quad_legged :: proc(kind: Enemy_Kind) -> bool {
	_, packed := quad_model_for(kind)
	return packed
}

// Moves a quadruped towards the way the game wants it to go
// (target, m/s), as an animal on legs can: it goes the way it faces, turns
// to change its way, and never slides sideways. Squaring up to him it keeps
// facing him and steps forwards or slowly backwards (whatever pushes it
// sideways, another goat crowding it, is no use to it then); otherwise it
// turns towards where it is going and walks there. It stands, or walks at a
// walking pace, and never creeps. Turning on the spot, its hooves step round. Its head turns to
// watch him, smoothly, and looks ahead again when he is behind it.
quad_steer :: proc(e: ^Enemy, target: Vec2, dt: f32) {
	target := target
	to := g.prosio.pos - e.pos
	heading := e.facing
	backs := e.squaring
	if e.yield_t > 0 {
		target = e.yield_dir * QUAD_YIELD_SPEED
		if e.kind == .Fox && e.has_loot {
			target += normalize2(e.home - e.pos) * QUAD_YIELD_SPEED
		}
		backs = false
		e.squaring = false
	}
	e.detour_t -= dt
	if e.detour_t > 0 {
		heading = e.detour // going round something in its way
		target = facing_dir(heading) * length2(target)
		backs = false
	} else if e.squaring && length2(to) > 0.01 {
		heading = math.atan2(to.x, to.y)
	} else if length2(target) > QUAD_WALK_FROM {
		heading = math.atan2(target.x, target.y)
	}
	e.facing = approach_angle(e.facing, heading, QUAD_TURN * dt)

	// Only what lies ahead (or behind) of the target is any use to it.
	ahead := facing_dir(e.facing)
	want := dot2(target, ahead)
	want = backs ? max(want, -QUAD_BACKWARDS) : max(want, 0)
	forward := dot2(e.vel, ahead)
	// It stands, or it walks at a walking pace: it does not creep.
	if abs(want) < (abs(forward) > 0.05 ? QUAD_STOP : QUAD_SET_OFF) {
		want = 0
	} else if abs(want) < QUAD_SLOWEST {
		want = math.sign(want) * QUAD_SLOWEST
	}
	step := QUAD_GOAT_ACCEL * dt
	forward += clamp(want - forward, -step, step)
	e.vel = ahead * forward

	// Its head watches him when he is near and in front of it.
	look: f32 = 0
	if length2(to) < 9 && length2(to) > 0.01 {
		off := angle_diff(math.atan2(to.x, to.y), e.facing)
		if abs(off) < QUAD_HEAD_TURN + 0.6 {
			look = clamp(off, -QUAD_HEAD_TURN, QUAD_HEAD_TURN)
		}
	}
	e.look += clamp(look - e.look, -QUAD_HEAD_SPEED * dt, QUAD_HEAD_SPEED * dt)
}

// Blends two sets of bone frames: k of the way from a to b, into a.
quad_blend :: proc(a, b: ^[QUAD_MAX_BONES]Mat4, k: f32, count: int) {
	if k <= 0 {
		return
	}
	for i in 0 ..< count {
		for c in 0 ..< 4 {
			for r in 0 ..< 3 {
				a[i][r, c] += (b[i][r, c] - a[i][r, c]) * k
			}
		}
	}
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
	if quad_drag_grounded(e) {
		quad_drag_skin(qk, pose, e, skin)
		return qk, true
	}
	r := ENEMY_RADIUS[e.kind]
	bones: [QUAD_MAX_BONES]Mat4
	clip, t, moving := quad_action(m, e)
	quad_sample(m, clip, t, &bones)
	if moving {
		// On its feet: standing, walking and galloping, blended by its speed
		// on one stride cycle (e.gait).
		pace := abs(e.motion.active ? e.motion.gait_speed : e.pace)
		if e.impact.kind != .None {
			pace = length2(e.vel)
		}
		walk, gallop := quad_mix(pace)
		if walk > 0 {
			strides: [2][QUAD_MAX_BONES]Mat4
			for name, i in ([2]string{"Walk", "Gallop"}) {
				c, _ := quad_clip(m, name)
				quad_sample(m, name, e.gait * f32(c.count) / c.fps, &strides[i])
			}
			// A shorter step is the walk drawn part of the way back towards
			// standing (its stride shortened to match: see quad_stride_rate).
			quad_blend(&strides[0], &bones, 1 - quad_step(pace), len(m.bones))
			quad_blend(&strides[0], &strides[1], gallop, len(m.bones))
			quad_blend(&bones, &strides[0], walk, len(m.bones))
		}
		if e.motion.graze > 0.001 {
			graze: [QUAD_MAX_BONES]Mat4
			quad_sample(m,"Eating",t,&graze)
			quad_blend(&bones,&graze,e.motion.graze,len(m.bones))
		}
		// Near him, it turns its head to watch him (see quad_steer).
		turn := e.look
		if turn != 0 {
			neck := quad_bone(m, "Neck1")
			if neck >= 0 {
				pivot := Vec3{bones[neck][0, 3], bones[neck][1, 3], bones[neck][2, 3]}
				look := translate(pivot) * rot_y(turn) * translate(-pivot)
				for name, b in m.bones {
					if len(name) >= 4 && (name[:4] == "Neck" || name[:4] == "Head" || name[:3] == "Ear") {
						bones[b] = look * bones[b]
					}
				}
			}
		}
	}

	limp := e.ko ? 1 : e.motion.limp_blend
	bend := pose.held ? limp : e.impact.bend
	if bend > 0.001 {
		// Reuse the slack limbs with the rotation of the fall removed.
		// The impact or carry pose controls the body's position.
		death: [QUAD_MAX_BONES]Mat4
		quad_sample(m, "Death", 99, &death)
		body := quad_bone(m, "Body")
		undo := linalg.inverse(transmute(Mat4)m.rest[body]) * linalg.inverse(death[body])
		for b in 0 ..< len(m.bones) {
			death[b] = undo * death[b]
		}
		quad_blend(&bones, &death, bend, len(m.bones))
	}
	rear, front := pose.rear, pose.front
	lying := e.impact.kind == .None && (e.state == .Dead || (e.state == .Swimming && e.ko))
	if lying {
		// The death animation lays it down on its side: the body frame stays
		// upright. Drowned, it floats feet up.
		lift: f32 = 0
		turn := Mat4(1)
		if e.state == .Swimming {
			lift = 0.05 + 0.03 * math.sin(g.time * 2.5 + e.pos.x) - sunk(e)
			turn = translate({0, 0.55, 0}) * rot_z(-math.PI / 2) * translate({0, -0.55, 0})
		}
		rear = translate({e.pos.x, lift, e.pos.y}) * rot_y(e.facing) * scale({r, r, r}) * turn
		front = rear
	}
	if e.impact.kind == .None && e.motion.active && (e.state == .Chase || e.state == .Dizzy) {
		// Counter-rotate the chest and let the hips follow behind the turn.
		rear = rear * rot_y(e.motion.rear_twist) * rot_z(e.motion.lean)
		front = front * rot_y(-e.motion.rear_twist * 0.30) * rot_z(e.motion.lean * 0.65)
	}
	phase := e.motion.struggle_phase
	struggle: f32
	if pose.held && !e.ko {
		burst := 0.45 + 0.55 * math.pow((1 + math.sin(phase * 0.26)) * 0.5, 2)
		struggle = burst * (1 - limp)
		front *= rot_y(QUAD_GRAB_TWIST * struggle * math.sin(phase * 0.63)) *
		         rot_z(QUAD_GRAB_TWIST * struggle * math.sin(phase * 0.53))
	}
	for b in 0..<len(m.bones) {
		bones[b] = (m.front[b] ? front : rear) * bones[b]
	}
	if struggle > 0.001 {
		// Free limbs recoil independently. Keep the hooves in Prosio's
		// hands out of this pass; those use the grip solver below.
		legs := quad_leg_rig(qk)
		frontward := facing_dir(e.facing)
		for leg, i in legs^ {
			if e.kind != .Fox && i % 2 == 1 {
				continue
			}
			sole := quad_origin(bones[leg.sole])
			pulse := math.sin(phase * (0.67 + f32(i) * 0.11) + f32(i) * 1.9) * 0.5 + 0.5
			kick := pulse * pulse * QUAD_GRAB_KICK * r * struggle
			airborne := smooth(clamp(sole.y / (r * 0.55), 0, 1))
			target := sole + Vec3{-frontward.x * kick, kick * (0.65 + airborne), -frontward.y * kick}
			target.y = max(target.y, leg.contact_y * r)
			foot := translate(target - sole) * bones[leg.sole]
			quad_reach_foot(&bones, leg, foot, frontward)
		}
	}
	quad_held_grips(m, &bones, pose, e.kind)
	quad_build_skin(m, &bones, skin)
	if e.impact.kind != .None {
		lift := impact_ground_lift(e, quad_mesh_low(m, skin))
		for b in 0..<len(m.bones) {
			skin[b][1, 3] += lift
		}
	} else if e.state == .Dead || e.state == .Dizzy || (pose.held && !in_pond(e.pos)) {
		// The authored death pose uses a different floor from the standing
		// mesh. Find support after deforming, with the final silhouette.
		for _ in 0..<(pose.held ? 2 : 1) {
			low := quad_mesh_low(m, skin)
			lift := e.state == .Dead ? -low : max(-low,0)
			if abs(lift) <= QUAD_FLOOR_EPSILON {break}
			for b in 0..<len(m.bones) {bones[b][1,3] += lift}
			quad_held_grips(m, &bones, pose, e.kind)
			quad_build_skin(m, &bones, skin)
		}
	}
	return qk, true
}

quad_build_skin :: proc(m: ^Quad_Model, bones: ^[QUAD_MAX_BONES]Mat4, skin: ^[QUAD_MAX_BONES]Mat4) {
	for b in 0..<len(m.bones) {
		skin[b] = bones[b]*transmute(Mat4)m.rest[b]
	}
}

quad_mesh_low :: proc(m: ^Quad_Model, skin: ^[QUAD_MAX_BONES]Mat4) -> f32 {
	low: f32 = 1e9
	for v in m.mesh {
		y: f32
		for k in 0..<4 {
			w := v[13+k]
			if w <= 0 {continue}
			s := &skin[int(v[9+k])]
			y += w*(s[1,0]*v[0] + s[1,1]*v[1] + s[1,2]*v[2] + s[1,3])
		}
		low = min(low,y)
	}
	return low
}

quad_held_grips :: proc(m: ^Quad_Model, bones: ^[QUAD_MAX_BONES]Mat4, pose: Animal_Pose, kind: Enemy_Kind) {
	if !pose.held {return}
	if kind == .Fox {
		root, _ := quad_socket(m,"tail_root")
		tip, _ := quad_socket(m,"tail_tip")
		tail: [QUAD_MAX_BONES]int
		n := 0
		for name, b in m.bones {
			if len(name) >= 4 && name[:4] == "Tail" {
				tail[n] = b
				n += 1
			}
		}
		quad_reach(bones, tail[:n], quad_carry(m,bones,root.bone,root.pos),quad_carry(m,bones,tip.bone,tip.pos),pose.hand)
		return
	}
	for side in ([2]f32{1,-1}) {
		left := side > 0
		hip, _ := quad_socket(m,left ? "hip_L" : "hip_R")
		hoof, _ := quad_socket(m,left ? "hoof_L" : "hoof_R")
		names := left ? [5]string{"BackLeg.L","BackUpperLeg.L","BackLowerLeg.L","IKBackLeg.L","FFB.L"} :
		                [5]string{"BackLeg.R","BackUpperLeg.R","BackLowerLeg.R","IKBackLeg.R","FFB.R"}
		leg: [5]int
		for name,i in names {leg[i]=quad_bone(m,name)}
		quad_reach(bones,leg[:],quad_carry(m,bones,hip.bone,hip.pos),quad_carry(m,bones,hoof.bone,hoof.pos),quad_grip(pose,side))
	}
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
draw_quad_enemy :: proc(pose: Animal_Pose, e: Enemy) -> (head_top: Vec3, ok: bool) {
	skin: [QUAD_MAX_BONES]Mat4
	qk, found := quad_skin(pose, e, &skin)
	if !found {
		return {}, false
	}
	m := &QUAD_MODELS[qk]
	grounded := e.state != .Swimming && !in_pond(e.pos)
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
		if grounded {p.y = max(0,p.y)}
		quad_pos[i] = p
		quad_flat[i] = linalg.normalize0(n)
		quad_smooth[i] = linalg.normalize0(sn)
	}
	colors: [QUAD_MAX_GROUPS]Color
	shown: [QUAD_MAX_GROUPS]bool
	for grp, i in m.groups {
		colors[i], shown[i] = quad_color(e.kind, grp.name)
		if (pose.dizzy || pose.dead) && quad_eye_material(grp.name) {shown[i] = false}
	}
	draw_quad_mesh(qk, len(m.mesh), colors[:len(m.groups)], shown[:len(m.groups)])

	// The sculpted eyes follow the head; only the closed-eye marks are drawn separately.
	head := quad_bone(m, "Head")
	for name in ([2]string{"eye_L", "eye_R"}) {
		eye, has := quad_socket(m, name)
		if !has || head < 0 || (!pose.dizzy && !pose.dead) {
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
	head_top = quad_socket_at(qk, &skin, "eye_L") + {0, ENEMY_RADIUS[e.kind] * 0.5, 0}
	return head_top, true
}

quad_eye_material :: proc(name: string) -> bool {
	return len(name) >= 3 && name[:3] == "Eye"
}

// The colour of each part of a packed animal.
quad_color :: proc(kind: Enemy_Kind, group: string) -> (Color, bool) {
	if quad_eye_material(group) {
		switch group {
		case "Eye_Lighter": return {112,77,40,255}, true
		case "Eye_White": return {226,211,177,255}, true
		case: return ANIMAL_INK, true
		}
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
