package game

import "core:math"
import "core:math/linalg"

PROSIO_BASE :: #config(PROSIO_BASE, true)
PROSIO_BASE_EXPORT :: #config(PROSIO_BASE_EXPORT, false)

// Each name is a deformation region in the workshop's Blender armature.
// The original animator supplies the exact transform of its primitive.
Prosio_Base_Part :: enum {
	Pelvis, Haunch_L, Haunch_R, Belly, Chest, Head, Snout, Ear_L, Ear_R,
	Thigh_L, Thigh_R, Knee_L, Knee_R, Shin_L, Shin_R, Toe_Inner_L, Toe_Inner_R,
	Toe_Outer_L, Toe_Outer_R, Shoulder_L, Shoulder_R, Upper_Arm_L, Upper_Arm_R,
	Biceps_L, Biceps_R, Elbow_L, Elbow_R, Forearm_L, Forearm_R, Hand_L, Hand_R,
	Neck, Pec_L, Pec_R, Brow_L, Brow_R,
}

Prosio_Base_Piece :: struct {
	shape: Shape,
	frame: linalg.Matrix4f32,
	color: Color,
}

Prosio_Base_Pose :: struct {
	pieces: [Prosio_Base_Part]Prosio_Base_Piece,
	face_fat: f32,
	collect: bool,
}

when PROSIO_BASE_EXPORT {
	Prosio_Base_Detail :: struct {
		name: string,
		piece: Prosio_Base_Piece,
	}
	prosio_base_exporting: bool
	prosio_base_details: [32]Prosio_Base_Detail
	prosio_base_detail_count: int
}

prosio_side_part :: proc(left: Prosio_Base_Part, side: f32) -> Prosio_Base_Part {
	return side < 0 ? left : Prosio_Base_Part(int(left) + 1)
}

prosio_base_visible :: proc() -> bool {
	return PROSIO_BASE && !prosio_character_visible() && outfit == PRESETS[.Bare]
}

prosio_base_head_lift :: proc() -> f32 {
	return prosio_base_visible() ? PROSIO_BASE_HEAD_LIFT : 0
}

// A palm target outside the arm's reach is capped before the elbow is solved.
// The hint picks the bend plane while both segment lengths stay fixed.
prosio_base_arm :: proc(shoulder, hint, target: Vec3, side: f32) -> (elbow, palm: Vec3) {
	sizes := PROSIO_BASE_ARM_LENGTHS
	delta := target - shoulder
	distance := linalg.length(delta)
	axis := distance > 0.0001 ? delta / distance : Vec3{0, -1, 0}
	reach := clamp(distance, abs(sizes.x - sizes.y) + 0.0001, sizes.x + sizes.y - 0.0001)
	along := (sizes.x * sizes.x - sizes.y * sizes.y + reach * reach) / (2 * reach)
	bend := hint - shoulder + {side * PROSIO_BASE_ARM_BIAS, 0, 0}
	pole := bend - axis * linalg.dot(bend, axis)
	if linalg.dot(pole, pole) < 0.000001 {
		guide := abs(axis.x) < 0.9 ? Vec3{side, 0, 0} : Vec3{0, 0, 1}
		pole = guide - axis * linalg.dot(guide, axis)
	}
	pole = linalg.normalize0(pole)
	elbow = shoulder + axis * along + pole * math.sqrt(max(0, sizes.x * sizes.x - along * along))
	palm = shoulder + axis * reach
	return
}

prosio_base_face_fat :: proc(fat: f32) -> f32 {
	tune := PROSIO_BASE_FACE_FAT
	return smooth(clamp((fat - tune.x) / tune.y, 0, 1)) -
		tune.z * smooth(clamp((tune.x - fat) / tune.x, 0, 1))
}

prosio_base_piece :: proc(pose: ^Prosio_Base_Pose, part: Prosio_Base_Part, shape: Shape, frame: Mat4, color: Color) {
	if pose.collect {
		pose.pieces[part] = {shape, frame, color}
	} else {
		draw_shape(shape, frame, color)
	}
}

prosio_base_ball :: proc(pose: ^Prosio_Base_Pose, part: Prosio_Base_Part, frame: Mat4, pos, size: Vec3, color: Color) {
	prosio_base_piece(pose, part, .Sphere, frame * translate(pos) * scale(size), color)
}

prosio_base_taper :: proc(pose: ^Prosio_Base_Pose, part: Prosio_Base_Part, frame: Mat4, a, b: Vec3, radius: f32, color: Color) {
	prosio_base_piece(pose, part, .Frustum, taper_frame(frame, a, b, radius), color)
}

prosio_base_face_detail :: proc(name: string, frame: Mat4, at, radii: Vec3, color: Color) {
	m := frame * translate(at) * scale(radii)
	when PROSIO_BASE_EXPORT {
		if prosio_base_exporting {
			prosio_base_details[prosio_base_detail_count] = {name, {.Sphere, m, color}}
			prosio_base_detail_count += 1
			return
		}
	}
	draw_shape(.Sphere, m, color)
}

prosio_base_face :: proc(pose: ^Prosio_Base_Pose, root: Mat4, munch, stoop, brow_tilt: f32,
                         walking, eyes_closed: bool, reaction: Prosio_Reaction, skin, snout: Color) {
	p := &g.prosio
	face_y := HEAD_HEIGHT + PROSIO_BASE_HEAD_LIFT
	h := root * translate({0, face_y + munch, 0.04}) * rot_x(-0.16 + 0.30 * stoop) * scale(Vec3{PROSIO_BASE_HEAD_SCALE, PROSIO_BASE_HEAD_SCALE, PROSIO_BASE_HEAD_SCALE})
	neck := PROSIO_BASE_NECK_ANCHOR
	prosio_base_ball(pose, .Neck, root, {0, face_y - neck.x + munch * neck.y, neck.z}, PROSIO_BASE_NECK_RADII, skin)
	radii := PROSIO_BASE_HEAD_RADII
	prosio_base_ball(pose, .Head, h, {}, radii, skin)
	pose.face_fat = prosio_base_face_fat(p.fat)
	prosio_base_ball(pose, .Snout, h, PROSIO_BASE_SNOUT_CENTER, PROSIO_BASE_SNOUT_RADII, snout)
	expressions := prosio_shape_weights(p, fatness(), g.time, reaction)
	brow_turn := PROSIO_BASE_BROW_TURN
	brow_lift := clamp(expressions[.Brow_Lift] + brow_tilt * brow_turn.z, -1, 1)
	for side in ([2]f32{-1, 1}) {
		wag := walking ? 0.14 * math.sin(p.walk_phase * 2 + side) : 0.03 * math.sin(g.time * 2 + side)
		fold := PROSIO_BASE_EAR_FOLD
		droop := fold.x + wag
		if p.airborne {
			air := PROSIO_BASE_EAR_AIR
			lift := smooth(clamp(p.height / fold.z, 0, 1))
			droop = lerp(droop, clamp(air.x + p.vy * air.y, air.z, fold.x), lift)
		}
		hinge := PROSIO_BASE_EAR_ANCHOR
		ear := h * translate({side * radii.x * hinge.x, hinge.y, hinge.z}) * rot_x(fold.y) * rot_z(-side * droop)
		prosio_base_ball(pose, prosio_side_part(.Ear_L, side), ear, {0, PROSIO_BASE_EAR_CENTER, 0}, PROSIO_BASE_EAR_RADII, skin)

		brow := PROSIO_BASE_BROW_ANCHOR
		tune := PROSIO_BASE_BROW_MOTION
		brow_frame := h * translate({side * brow.x, brow.y + tune.x * brow_lift, brow.z - tune.y * brow_lift}) *
			rot_y(side * brow_turn.x) * rot_z(side * (brow_turn.y + brow_tilt * tune.z))
		prosio_base_ball(pose, prosio_side_part(.Brow_L, side), brow_frame, {}, PROSIO_BASE_BROW_RADII, skin)

		eye_at := PROSIO_BASE_EYE_ANCHOR
		eye := h * translate({side * eye_at.x, eye_at.y, eye_at.z}) * rot_y(side * PROSIO_BASE_EYE_TURN)
		if eyes_closed {
			prosio_base_face_detail("ClosedLid", eye, PROSIO_BASE_LID_AT, PROSIO_BASE_LID_RADII, COLOR_NOSTRIL)
		} else {
			prosio_base_face_detail(side < 0 ? "Eye.L" : "Eye.R", eye, {}, PROSIO_BASE_EYE_RADII, COLOR_BLACK)
			prosio_base_face_detail("Catchlight", eye, PROSIO_BASE_GLINT_AT, PROSIO_BASE_GLINT_RADII, COLOR_WHITE)
			prosio_base_face_detail("SmallCatchlight", eye, PROSIO_BASE_SMALL_GLINT_AT, PROSIO_BASE_SMALL_GLINT_RADII, COLOR_WHITE)
		}
	}

	mouth := PROSIO_BASE_MOUTH
	switch {
	case p.eat_t > 0 || p.airborne:
		prosio_base_face_detail("OpenMouth", h, {0, mouth.y, mouth.z}, PROSIO_BASE_OPEN_MOUTH, COLOR_NOSTRIL)
	case p.strain > 0.5 || p.heave_t > 0:
		prosio_base_face_detail("Teeth", h, {0, mouth.y, mouth.z}, PROSIO_BASE_TEETH, COLOR_WHITE)
	case !eyes_closed || p.fail == .None:
		smile := expressions[.Smile]
		arc := PROSIO_BASE_SMILE_ARC
		tilt := PROSIO_BASE_SMILE_TILT
		for i in 0..<7 {
			u := f32(i) / 3 - 1
			curve := u * u
			at := Vec3{mouth.x * u, mouth.y + curve * (arc.x + smile * arc.y), mouth.z - arc.z * curve}
			angle := u * (tilt.x + smile * tilt.y)
			prosio_base_face_detail("Smile", h * translate(at) * rot_z(angle), {}, PROSIO_BASE_SMILE_RADII, COLOR_NOSTRIL)
		}
	}
}

when PROSIO_BASE_EXPORT {
	// Run the in-game pose calculation without a rendering context. The wider
	// arm stance gives the retopology clear separation at the armpits.
	prosio_base_snapshot :: proc(bind: bool, pose: ^Prosio_Base_Pose) {
		saved := outfit
		outfit = PRESETS[.Bare]
		prosio_base_exporting = true
		prosio_base_detail_count = 0
		defer {
			prosio_base_exporting = false
			outfit = saved
		}
		draw_prosio(pose, bind)
	}
}

when PROSIO_BASE {
	Prosio_Base_Vertex :: struct {
		pos, normal: Vec3,
		joints: [4]u8,
		weights: [4]f32,
	}
	PROSIO_BASE_VERTICES := #load("../../assets/prosio_base/vertices.bin", []Prosio_Base_Vertex)
	PROSIO_BASE_INDICES := #load("../../assets/prosio_base/indices.bin", []u16)
	PROSIO_BASE_REST := #load("../../assets/prosio_base/rest.bin", []Mat4)
	PROSIO_BASE_PAINT := #load("../../assets/prosio_base/paint.bin", []Color)
	PROSIO_BASE_FACE_DELTA := #load("../../assets/prosio_base/face_fat.bin", [][6]f32)
	PROSIO_BASE_VERTEX_CAPACITY :: 1 << (size_of(u16) * 8)
	prosio_base_positions: [PROSIO_BASE_VERTEX_CAPACITY]Vec3
	prosio_base_normals: [PROSIO_BASE_VERTEX_CAPACITY]Vec3

	prosio_base_skin :: proc(pose: ^Prosio_Base_Pose) {
		frames, normals: [Prosio_Base_Part]Mat4
		for part in Prosio_Base_Part {
			frame := pose.pieces[part].frame * PROSIO_BASE_REST[int(part)]
			frames[part] = frame
			normals[part] = linalg.transpose(linalg.inverse(frame))
		}
		for v, i in PROSIO_BASE_VERTICES {
			face := PROSIO_BASE_FACE_DELTA[i]
			pos := v.pos + face.xyz * pose.face_fat
			normal := v.normal + Vec3{face[3], face[4], face[5]} * pose.face_fat
			p, n: Vec3
			for weight, k in v.weights {
				if weight <= 0 { break }
				j := Prosio_Base_Part(v.joints[k])
				p += weight * (frames[j] * [4]f32{pos.x, pos.y, pos.z, 1}).xyz
				n += weight * (normals[j] * [4]f32{normal.x, normal.y, normal.z, 0}).xyz
			}
			prosio_base_positions[i] = p
			prosio_base_normals[i] = linalg.normalize0(n)
		}
	}
}
