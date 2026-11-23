package game

import "core:math"
import "core:math/linalg"

Quad_Drag_Grip :: struct {
	first, second: []int,
	root, hinge, tip, hand: Vec3,
	upper, lower: f32,
}

quad_drag_grounded :: proc(e: Enemy) -> bool {
	p := &g.prosio
	return e.state == .Held && e.ko && !p.swinging && p.height <= QUAD_FLOOR_EPSILON && !in_pond(e.pos)
}

// Use the fallen pose for the head, shoulders and forelegs. Turn the
// pelvis around a spine joint, so the rear can follow the grip without
// pulling the torso apart. Work with rigid rotations throughout.
quad_drag_skin :: proc(k: Quad_Kind, pose: Animal_Pose, e: Enemy, skin: ^[QUAD_MAX_BONES]Mat4) {
	m := &QUAD_MODELS[k]
	bones: [QUAD_MAX_BONES]Mat4
	quad_sample(m, "Death", 99, &bones)
	mid := quad_origin(bones[quad_bone(m, "Torso2")])
	r := ENEMY_RADIUS[e.kind]
	settle := QUAD_DRAG_SETTLE[k]
	body := translate({e.chain[1].x, 0, e.chain[1].z}) * rot_y(e.facing) *
	        scale({r, r, r}) * rot_x(settle.x) * rot_z(settle.y) * translate(-mid)
	across := facing_dir(e.facing + math.PI / 2)
	pull := clamp(dot2(pose.hand.xz - e.chain[1].xz, across) / r, -1, 1)
	pitch := QUAD_DRAG_HIP_PITCH
	if e.kind == .Fox {
		pitch += clamp(pose.hand.y / r - QUAD_DRAG_HIGH_TAIL, 0, QUAD_DRAG_TAIL_LIFT)
	}
	hips := translate(mid) * rot_x(pitch) * rot_z(QUAD_DRAG_HIP_ROLL + QUAD_DRAG_HIP_PULL * pull) * translate(-mid)
	for b in 0 ..< len(m.bones) {
		bones[b] = (m.front[b] ? body : body * hips) * bones[b]
	}
	quad_build_skin(m, &bones, skin)
	floor := translate({0, -quad_mesh_low(m, skin), 0})
	for b in 0 ..< len(m.bones) {
		bones[b] = floor * bones[b]
	}

	groups: [2][8]int
	grips: [2]Quad_Drag_Grip
	count := 2
	if e.kind == .Fox {
		count = 1
		root, _ := quad_socket(m, "tail_root")
		tip, _ := quad_socket(m, "tail_tip")
		tail := [8]string{"Tail1", "Tail2", "Tail3", "Tail4", "Tail5", "Tail6", "Tail7", "Tail8"}
		for name, i in tail {
			groups[0][i] = quad_bone(m, name)
		}
		grips[0] = {
			first = groups[0][:4], second = groups[0][4:],
			root = quad_carry(m, &bones, root.bone, root.pos),
			hinge = quad_origin(bones[groups[0][4]]),
			tip = quad_carry(m, &bones, tip.bone, tip.pos),
			hand = pose.hand,
		}
	} else {
		for i in 0 ..< count {
			left := i == 0
			hip, _ := quad_socket(m, left ? "hip_L" : "hip_R")
			hoof, _ := quad_socket(m, left ? "hoof_L" : "hoof_R")
			leg := left ? [5]string{"BackLeg.L", "BackUpperLeg.L", "BackLowerLeg.L", "IKBackLeg.L", "FFB.L"} :
			              [5]string{"BackLeg.R", "BackUpperLeg.R", "BackLowerLeg.R", "IKBackLeg.R", "FFB.R"}
			for name, j in leg {
				groups[i][j] = quad_bone(m, name)
			}
			grips[i] = {
				first = groups[i][:2], second = groups[i][2:5],
				root = quad_carry(m, &bones, hip.bone, hip.pos),
				hinge = quad_origin(bones[groups[i][2]]),
				tip = quad_carry(m, &bones, hoof.bone, hoof.pos),
				hand = quad_grip(pose, left ? 1 : -1),
			}
		}
	}

	// Pull the whole fallen pose towards the hand just enough for the
	// limbs to reach. Solve in the ground plane to keep chest contact.
	offset: Vec2
	for &grip in grips[:count] {
		grip.upper = linalg.length(grip.hinge - grip.root)
		grip.lower = linalg.length(grip.tip - grip.hinge)
	}
	for _ in 0 ..< 4 {
		for grip in grips[:count] {
			reach := (grip.upper + grip.lower) * QUAD_DRAG_REACH_MARGIN
			d := grip.hand - grip.root
			room := math.sqrt(max(reach * reach - d.y * d.y, 0))
			pull := d.xz - offset
			distance := length2(pull)
			if distance > room && distance > 0 {
				offset += pull * (1 - room / distance)
			}
		}
	}
	move := Vec3{offset.x, 0, offset.y}
	shift := translate(move)
	for b in 0 ..< len(m.bones) {
		bones[b] = shift * bones[b]
	}
	for &grip in grips[:count] {
		grip.root += move
		grip.hinge += move
		grip.tip += move
		quad_drag_reach(&bones, grip)
	}
	quad_build_skin(m, &bones, skin)
}

quad_drag_reach :: proc(bones: ^[QUAD_MAX_BONES]Mat4, grip: Quad_Drag_Grip) {
	d := grip.hand - grip.root
	axis := linalg.normalize0(d)
	if axis == {} {
		return
	}
	reach := clamp(linalg.length(d), abs(grip.upper - grip.lower) + 0.0001, grip.upper + grip.lower)
	target := grip.root + axis * reach
	along := (grip.upper * grip.upper - grip.lower * grip.lower + reach * reach) / (2 * reach)
	// Keep slack above the ground as the leg folds back towards its grip.
	up := Vec3{0, 1, 0}
	bend := up - axis * linalg.dot(up, axis)
	if linalg.length(bend) < 0.05 {
		side := grip.hinge - grip.root
		bend = side - axis * linalg.dot(side, axis)
	}
	joint := grip.root + axis * along + linalg.normalize0(bend) * math.sqrt(max(0, grip.upper * grip.upper - along * along))
	first := translate(grip.root) * quad_rotate_from_to(grip.hinge - grip.root, joint - grip.root) * translate(-grip.root)
	second := translate(joint) * quad_rotate_from_to(grip.tip - grip.hinge, target - joint) * translate(-grip.hinge)
	for b in grip.first {
		bones[b] = first * bones[b]
	}
	for b in grip.second {
		bones[b] = second * bones[b]
	}
}
