package game

import "core:math"
import "core:math/linalg"

// The Blender rig is opt-in while the procedural wardrobe is being fitted.
PROSIO_CHARACTER :: #config(PROSIO_CHARACTER, false)

Prosio_Joint :: enum {
	Pelvis, Spine, Chest, Head, Eye_R, Eye_L,
	Upper_Arm_R, Forearm_R, Hand_R, Upper_Arm_L, Forearm_L, Hand_L,
	Thigh_R, Shin_R, Hoof_R, Thigh_L, Shin_L, Hoof_L,
}

Prosio_Reach :: struct {
	active: bool,
	elbow, grip: Vec3, // in the unsquashed body frame
}

// Keep this order in sync with tools/pack_prosio.py.
Prosio_Shape :: enum { Fat, Arm_Muscle, Leg_Muscle, Chest_Muscle, Belly_Full, Jaw_Open, Cheek_Puff, Smile, Brow_Lift }

Prosio_Reaction :: struct {
	gas, hiccup, tipsy, sway: f32,
}

update_prosio_reactions :: proc(p: ^Prosio, dt: f32) {
	p.gas_pose_t = max(p.gas_pose_t - dt, 0)
	p.hiccup_pose_t = max(p.hiccup_pose_t - dt, 0)
	p.tipsy_pose_t = max(p.tipsy_pose_t - dt, 0)
	p.meal_hold_t = max(0, p.meal_hold_t - dt)
	if p.meal_hold_t == 0 {
		p.meal_target *= math.exp(-dt * PROSIO_MEAL_VISUAL.z)
	}
	if p.eat_t <= PROSIO_MEAL_EAT_TIME * PROSIO_MEAL_CHEW.x {
		p.meal_fill = lerp(p.meal_fill, p.meal_target, 1 - math.exp(-dt * PROSIO_MEAL_EASE))
	}
}

prosio_reaction :: proc(p: ^Prosio, time: f32) -> Prosio_Reaction {
	if p.fail != .None {
		return {}
	}
	gas := clamp(p.gas_pose_t / PROSIO_REACTION_TIME.x, 0, 1)
	hiccup := clamp(p.hiccup_pose_t / PROSIO_REACTION_TIME.y, 0, 1)
	tipsy := clamp(p.tipsy_pose_t / PROSIO_REACTION_TIME.z, 0, 1)
	strength := smooth(min(tipsy * PROSIO_TIPSY_FADE.y, (1 - tipsy) * PROSIO_TIPSY_FADE.x, 1))
	return {gas = math.sin(math.PI * gas) * math.sqrt(gas), hiccup = smooth(hiccup),
		tipsy = strength, sway = strength * math.sin(time * PROSIO_REACTION_SWAY.x)}
}

prosio_shape_weights :: proc(p: ^Prosio, fatness, time: f32, reaction: Prosio_Reaction) -> (w: [Prosio_Shape]f32) {
	neutral := PROSIO_MESH_BELLY.x
	w[.Fat] = clamp((fatness - neutral) / (1 - neutral), -1, 1)
	w[.Arm_Muscle] = clamp(p.trait[.Arms], -1, 1)
	w[.Leg_Muscle] = clamp(p.trait[.Legs], -1, 1)
	w[.Chest_Muscle] = clamp((p.trait[.Arms] + p.trait[.Lungs]) * 0.5, -1, 1)
	w[.Belly_Full] = clamp(p.meal_fill + reaction.gas * PROSIO_FACE_WIND.x, 0, 1)
	if p.fail != .None {
		return
	}
	if p.eat_t > 0 {
		chew := clamp(p.eat_t / PROSIO_MEAL_EAT_TIME, 0, 1)
		envelope := math.sin(math.PI * chew)
		w[.Jaw_Open] = envelope * (0.5 + 0.5 * math.cos(chew * math.TAU * PROSIO_MEAL_CHEW.y))
		w[.Cheek_Puff] = envelope * (1 - w[.Jaw_Open])
	} else if p.meal_hold_t > 0 {
		w[.Smile] = smooth(min(p.meal_hold_t * PROSIO_FACE_SMILE_FADE, p.meal_fill, 1))
	}
	if p.winded || p.crash_t > 0 {
		w[.Jaw_Open] = max(w[.Jaw_Open], PROSIO_FACE_PANT.y + math.sin(time * PROSIO_FACE_PANT.x) * PROSIO_FACE_PANT.z)
	}
	w[.Jaw_Open] = max(w[.Jaw_Open], reaction.hiccup, reaction.tipsy * PROSIO_FACE_TIPSY.x)
	w[.Cheek_Puff] = max(w[.Cheek_Puff], reaction.gas * PROSIO_FACE_WIND.y)
	w[.Smile] = max(w[.Smile], reaction.tipsy * PROSIO_FACE_TIPSY.y)
	w[.Brow_Lift] = max(w[.Smile] * PROSIO_FACE_BROWS.x, reaction.hiccup * PROSIO_FACE_BROWS.y, reaction.gas * PROSIO_FACE_BROWS.z)
	return
}

prosio_character_visible :: proc() -> bool {
	return PROSIO_CHARACTER && outfit == PRESETS[.Bare]
}

PROSIO_VERTICES :: #load("../../assets/prosio/vertices.bin", [][17]f32)
PROSIO_PAINT :: #load("../../assets/prosio/paint.bin", []Color)
PROSIO_INDICES :: #load("../../assets/prosio/indices.bin", []u16)
prosio_shapes := #load("../../assets/prosio/shapes.bin", [][7]f32) // vertex index, position delta, normal delta
prosio_shape_ranges := #load("../../assets/prosio/shape_ranges.bin", [][2]u32)
prosio_joints := #load("../../assets/prosio/joints.bin", [][6]f32)
// The packed body is first in the index array. Only its silhouette is inked.
prosio_layout := #load("../../assets/prosio/layout.bin", []u32)
PROSIO_VERTEX_CAPACITY :: 12000
prosio_skin_positions: [PROSIO_VERTEX_CAPACITY]Vec3
prosio_skin_normals: [PROSIO_VERTEX_CAPACITY]Vec3
prosio_shape_positions: [PROSIO_VERTEX_CAPACITY]Vec3
prosio_shape_normals: [PROSIO_VERTEX_CAPACITY]Vec3

prosio_body_indices :: proc() -> int { return int(prosio_layout[0]) }

prosio_rest_start :: proc(joint: Prosio_Joint) -> Vec3 {
	j := prosio_joints[int(joint)]
	return {j[0], j[1], j[2]}
}

prosio_rest_end :: proc(joint: Prosio_Joint) -> Vec3 {
	j := prosio_joints[int(joint)]
	return {j[3], j[4], j[5]}
}

prosio_joint_turn :: proc(joint: Prosio_Joint, turn: Mat4) -> Mat4 {
	origin := prosio_rest_start(joint)
	return translate(origin) * turn * translate(-origin)
}

prosio_point_in :: proc(frame: Mat4, p: Vec3) -> Vec3 {
	return (frame * [4]f32{p.x, p.y, p.z, 1}).xyz
}

// Two fixed-length segments bend towards the elbow target. The last
// joint puts the palm on the game's existing hold point where it can reach.
prosio_reach_arm :: proc(frames: ^[Prosio_Joint]Mat4, upper, forearm, hand: Prosio_Joint, reach: Prosio_Reach, side: f32) {
	shoulder, elbow, wrist := prosio_rest_start(upper), prosio_rest_start(forearm), prosio_rest_start(hand)
	hand_tip := prosio_rest_end(hand)
	u, v := linalg.length(elbow - shoulder), linalg.length(wrist - elbow)
	axis := linalg.normalize0(reach.grip - shoulder)
	if axis == {} {
		return
	}
	// The hand's tip is the contact. Leave a palm-length space for it.
	target := reach.grip - axis * linalg.length(hand_tip - wrist)
	d := clamp(linalg.length(target - shoulder), abs(u - v) + 0.002, u + v - 0.002)
	along := (u * u - v * v + d * d) / (2 * d)
	elbow_dir := reach.elbow - shoulder + Vec3{side * PROSIO_MESH_ELBOW_POLE.x, 0, PROSIO_MESH_ELBOW_POLE.y}
	pole := linalg.normalize0(elbow_dir - axis * linalg.dot(elbow_dir, axis))
	if pole == {} {
		fallback := Vec3{side, 0, 0}
		pole = linalg.normalize0(fallback - axis * linalg.dot(fallback, axis))
	}
	knee := shoulder + axis * along + pole * math.sqrt(max(0, u*u - along*along))
	end := shoulder + axis * d
	frames[upper] = translate(shoulder) * quad_rotate_from_to(elbow-shoulder,knee-shoulder) * translate(-shoulder)
	frames[forearm] = translate(knee) * quad_rotate_from_to(wrist-elbow,end-knee) * translate(-elbow)
	frames[hand] = translate(end) * quad_rotate_from_to(hand_tip-wrist,reach.grip-end) * translate(-wrist)
}

prosio_character_pose :: proc(swing, t, wob, stoop: f32, reach: [2]Prosio_Reach, reaction: Prosio_Reaction) -> (pose: [Prosio_Joint]Mat4) {
	p := &g.prosio
	for &frame in pose {
		frame = IDENTITY
	}
	widen := 1 + (t - PROSIO_MESH_BELLY.x) * PROSIO_MESH_BELLY.y + wob * PROSIO_MESH_BELLY.z
	pose[.Spine] = prosio_joint_turn(.Spine, scale({widen, 1, widen}))
	pose[.Chest] = prosio_joint_turn(.Chest, rot_y(swing * PROSIO_MESH_POSE.x) * rot_x(-reaction.hiccup * PROSIO_FACE_RECOIL.x))
	munch: f32 = p.eat_t > 0 ? math.sin(p.eat_t * PROSIO_MESH_MUNCH.x) * PROSIO_MESH_MUNCH.y : 0
	pose[.Head] = translate({0,munch,0}) * prosio_joint_turn(.Head,
		rot_x(stoop * PROSIO_MESH_POSE.z - reaction.hiccup * PROSIO_FACE_RECOIL.y) *
		rot_y(-swing * PROSIO_MESH_POSE.y - reaction.sway * PROSIO_FACE_RECOIL.z) * rot_z(-reaction.sway * PROSIO_FACE_RECOIL.z))
	pose[.Eye_R], pose[.Eye_L] = pose[.Head], pose[.Head]
	arms := [2][3]Prosio_Joint{{.Upper_Arm_R,.Forearm_R,.Hand_R},{.Upper_Arm_L,.Forearm_L,.Hand_L}}
	legs := [2][3]Prosio_Joint{{.Thigh_R,.Shin_R,.Hoof_R},{.Thigh_L,.Shin_L,.Hoof_L}}
	for i in 0 ..< 2 {
		side := f32(2*i-1)
		upper, forearm, hand := arms[i][0], arms[i][1], arms[i][2]
		pose[upper] = prosio_joint_turn(upper, rot_x(-side*swing*PROSIO_MESH_ARM_SWING.x) * rot_z(side*(widen-1)*PROSIO_MESH_ARM_SWING.y))
		pose[forearm] = pose[upper] * prosio_joint_turn(forearm,rot_x(max(0,side*swing)*PROSIO_MESH_ARM_SWING.z))
		pose[hand] = pose[forearm]
		if reach[i].active {
			prosio_reach_arm(&pose,upper,forearm,hand,reach[i],side)
		}
		thigh, shin, hoof := legs[i][0], legs[i][1], legs[i][2]
		stride := p.airborne ? -PROSIO_MESH_JUMP.x + side*PROSIO_MESH_JUMP.y : side*swing*PROSIO_MESH_STRIDE.x
		bend := p.airborne ? PROSIO_MESH_JUMP.z : max(0,-side*swing)*PROSIO_MESH_STRIDE.y
		pose[thigh] = prosio_joint_turn(thigh,rot_x(stride))
		pose[shin] = pose[thigh] * prosio_joint_turn(shin,rot_x(bend))
		pose[hoof] = pose[shin] * prosio_joint_turn(hoof,rot_x(-PROSIO_MESH_STRIDE.z*(stride+bend)))
	}
	return
}

prosio_skin :: proc(pose: ^[Prosio_Joint]Mat4, blink: f32, shape: [Prosio_Shape]f32 = {}) {
	// Shape keys store only the vertices they move. Apply them in rest space
	// before the fixed-length arms and legs take their current pose.
	for i in 0 ..< len(PROSIO_VERTICES) {
		prosio_shape_positions[i] = {}
		prosio_shape_normals[i] = {}
	}
	for weight, name in shape {
		if weight == 0 {
			continue
		}
		span := prosio_shape_ranges[int(name)]
		for entry in prosio_shapes[span[0]:span[0]+span[1]] {
			index := int(entry[0])
			prosio_shape_positions[index] += Vec3{entry[1], entry[2], entry[3]} * weight
			prosio_shape_normals[index] += Vec3{entry[4], entry[5], entry[6]} * weight
		}
	}
	for row, i in PROSIO_VERTICES {
		position := Vec3{row[0],row[1],row[2]} + Vec3{row[6],row[7],row[8]} * blink + prosio_shape_positions[i]
		normal := Vec3{row[3],row[4],row[5]} + prosio_shape_normals[i]
		pp, nn := Vec3{}, Vec3{}
		for k in 0 ..< 4 {
			w := row[13+k]
			if w > 0 {
				frame := pose[Prosio_Joint(int(row[9+k]))]
				pp += prosio_point_in(frame,position)*w
				nn += (frame * [4]f32{normal.x,normal.y,normal.z,0}).xyz*w
			}
		}
		prosio_skin_positions[i] = pp
		prosio_skin_normals[i] = linalg.normalize0(nn)
	}
}

draw_prosio_character :: proc(root: Mat4, swing, t, wob, stoop: f32, reach: [2]Prosio_Reach, eyes_closed: bool, reaction: Prosio_Reaction) {
	pose := prosio_character_pose(swing,t,wob,stoop,reach,reaction)
	// The normal blink closes and opens continuously. Other states can
	// hold the same authored lid shape shut as long as needed.
	blink := f32(0)
	clock := math.mod(g.time, PROSIO_MESH_BLINK.x)
	if g.prosio.fail != .None || g.prosio.ache_t > 0 || g.prosio.dazed_t > 0 {
		blink = 1
	} else if eyes_closed {
		blink = math.sin(clock * math.PI / PROSIO_MESH_BLINK.y)
	}
	blink = max(blink, reaction.gas * PROSIO_FACE_WIND.z, reaction.tipsy * PROSIO_FACE_TIPSY.z)
	prosio_skin(&pose, blink, prosio_shape_weights(&g.prosio, t, g.time, reaction))
	when PROSIO_CHARACTER { draw_prosio_character_mesh(root) }
}
