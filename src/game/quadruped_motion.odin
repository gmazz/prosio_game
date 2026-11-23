package game

import "core:math"
import "core:math/linalg"

Quad_Motion :: struct {
	active: bool,
	last_pos: Vec2,
	last_yaw: f32,
	rear_twist, lean, gait_speed, graze: f32,
	struggle_phase, limp_blend: f32,
}
Quad_Leg :: struct {
	upper, knee, ankle, sole: int,
	contact_y: f32,
	knee_sign: f32,
}

quad_origin :: proc(m: Mat4) -> Vec3 {
	return {m[0, 3], m[1, 3], m[2, 3]}
}

@(private)
quad_legs: [Quad_Kind][4]Quad_Leg
@(private)
quad_legs_ready: [Quad_Kind]bool

quad_leg_rig :: proc(k: Quad_Kind) -> ^[4]Quad_Leg {
	if quad_legs_ready[k] {
		return &quad_legs[k]
	}
	m := &QUAD_MODELS[k]
	names := [4][4]string {
		{"FrontUpperLeg.L", "FrontLowerLeg.L", "IKFrontLeg.L", "FF.L"},
		{"BackUpperLeg.R", "BackLowerLeg.R", "IKBackLeg.R", "FFB.R"},
		{"FrontUpperLeg.R", "FrontLowerLeg.R", "IKFrontLeg.R", "FF.R"},
		{"BackUpperLeg.L", "BackLowerLeg.L", "IKBackLeg.L", "FFB.L"},
	}
	for n, i in names {
		foot := quad_bone(m, n[3])
		quad_legs[k][i] = {
			upper = quad_bone(m, n[0]),
			knee = quad_bone(m, n[1]),
			ankle = quad_bone(m, n[2]),
			sole = foot,
			knee_sign = i % 2 == 0 ? 1 : -1,
		}
	}
	// Find each sole's lowest rest vertex relative to its sole joint.
	for &leg in quad_legs[k] {
		lowest: f32 = 1e9
		for v in m.mesh {
			if int(v[9]) == leg.sole || int(v[9]) == leg.ankle {
				lowest = min(lowest, v[1])
			}
		}
		rest := linalg.inverse(transmute(Mat4)m.rest[leg.sole])
		leg.contact_y = max(0, quad_origin(rest).y - lowest)
	}

	quad_legs_ready[k] = true
	return &quad_legs[k]
}

quad_update_motion :: proc(e: ^Enemy, dt: f32) {
	_, ok := quad_model_for(e.kind)
	if !ok {
		return
	}
	m := &e.motion
	filter := 1 - math.exp(-QUAD_BODY_FOLLOW * dt)
	if e.state == .Held {
		if m.active {
			m.struggle_phase, m.limp_blend = 0, 0
		}
		m.active = false
		m.struggle_phase += dt * QUAD_STRUGGLE_RATE
		m.limp_blend = e.ko ? 1 : lerp(m.limp_blend, e.limp > 0 ? 1 : 0, filter)
		return
	}
	if e.state != .Chase && (e.state != .Dizzy || e.ko) {
		m.active = false
		return
	}
	r := ENEMY_RADIUS[e.kind]
	delta := e.pos - m.last_pos
	if !m.active || length2(delta) > 2 * r {
		m^ = {active = true, last_pos = e.pos, last_yaw = e.facing}
		return
	}
	yaw := angle_diff(e.facing, m.last_yaw)
	m.last_pos, m.last_yaw = e.pos, e.facing
	turn_rate := yaw / dt
	side := facing_dir(e.facing + math.PI / 2)
	pull := dot2(delta, side) / dt
	twist := clamp(-turn_rate * 0.11 + pull * 0.09, -QUAD_REAR_TWIST_MAX, QUAD_REAR_TWIST_MAX)
	lean := clamp(-turn_rate * 0.04 - pull * 0.09, -QUAD_BODY_LEAN_MAX, QUAD_BODY_LEAN_MAX)
	m.rear_twist = lerp(m.rear_twist, twist, filter)
	m.lean = lerp(m.lean, lean, filter)
	forward := dot2(delta, facing_dir(e.facing)) / dt
	step_speed := max(abs(forward), abs(turn_rate) * QUAD_TURN_STEP, abs(pull))
	e.pace = (forward < -QUAD_WALK_FROM ? -1 : 1) * step_speed
	m.gait_speed = lerp(m.gait_speed, clamp(e.pace, -QUAD_BACKWARDS, ENEMY_SPEED[e.kind] * 2), filter)
	m.graze = lerp(m.graze, e.licking ? 1 : 0, filter)
	e.gait = math.mod(e.gait + quad_stride_rate(e.kind, m.gait_speed) * dt, 1)
}

quad_rotate_from_to :: proc(from, to: Vec3) -> Mat4 {
	a, b := linalg.normalize0(from), linalg.normalize0(to)
	if a == {} || b == {} {
		return IDENTITY
	}
	return linalg.matrix4_from_quaternion(linalg.quaternion_between_two_vector3(a, b))
}

// Solve the visible leg through its knee. Use a consistent bend pole so an
// almost straight leg cannot flip during a turn or a change of clip.
// Used only for a held animal's free kicks. A target beyond reach
// stops at full extension; every bone keeps its length.
quad_reach_foot :: proc(bones: ^[QUAD_MAX_BONES]Mat4, leg: Quad_Leg, foot: Mat4, forward: Vec2) {
	hip := quad_origin(bones[leg.upper])
	knee := quad_origin(bones[leg.knee])
	ankle := quad_origin(bones[leg.ankle])
	foot_move := foot * linalg.inverse(bones[leg.sole])
	wanted := (foot_move * [4]f32{ankle.x, ankle.y, ankle.z, 1}).xyz
	upper, lower := linalg.length(knee - hip), linalg.length(ankle - knee)
	axis := linalg.normalize0(wanted - hip)
	if min(upper, lower) < 1e-4 || axis == {} {
		return
	}
	reach := clamp(linalg.length(wanted - hip), abs(upper - lower) + 0.0001, (upper + lower) * 0.999)
	target := hip + axis * reach
	along := (upper * upper - lower * lower + reach * reach) / (2 * reach)
	pole := Vec3{forward.x, 0, forward.y} * leg.knee_sign
	side := linalg.normalize0(pole - axis * linalg.dot(pole, axis))
	bend := hip + axis * along + side * math.sqrt(max(0, upper * upper - along * along))
	bones[leg.upper] = translate(hip) * quad_rotate_from_to(knee - hip, bend - hip) * translate(-hip) * bones[leg.upper]
	bones[leg.knee] = translate(bend) * quad_rotate_from_to(ankle - knee, target - bend) * translate(-knee) * bones[leg.knee]
	adjust := translate(target - wanted)
	bones[leg.ankle] = adjust * foot_move * bones[leg.ankle]
	bones[leg.sole] = adjust * foot
}
