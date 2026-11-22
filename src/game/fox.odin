package game

import "core:math"
import "core:math/linalg"

// Rest-space vertices are grouped by rigid joint and material at build time.
Fox_Group :: struct {
	joint: Fox_Joint,
	first_vertex, vertex_count, first_index, index_count: int,
	color: Color,
}

FOX_MODEL_SCALE :: f32(1.25) // fit the workshop fox to the game's radius-relative animal frames
FOX_PROCEDURAL :: #config(FOX_PROCEDURAL, false)

fox_turn :: proc(pivot: Vec3, rotation: Mat4) -> Mat4 {
	return translate(pivot) * rotation * translate(-pivot)
}

fox_point :: proc(frame: Mat4, pos: Vec3) -> Vec3 {
	return (frame * [4]f32{pos.x, pos.y, pos.z, 1}).xyz
}

fox_tail_sweep :: proc(seconds: f32) -> f32 {
	t := math.mod(seconds, FOX_SWEEP[len(FOX_SWEEP)-1].x)
	for key, i in FOX_SWEEP[1:] {
		if t <= key.x {
			prev := FOX_SWEEP[i]
			return lerp(prev.y, key.y, (t-prev.x)/(key.x-prev.x))
		}
	}
	return 0
}

fox_joint_frames :: proc(pose: Animal_Pose, phase: f32) -> (frames: [Fox_Joint]Mat4) {
	fit := scale({FOX_MODEL_SCALE, FOX_MODEL_SCALE, FOX_MODEL_SCALE})
	rear, front := pose.rear * fit, pose.front * fit
	for joint in Fox_Joint {frames[joint] = front}
	frames[.hips] = rear
	legs := [2][2][3]Fox_Joint{
		{{.hind_R, .shin_hind_R, .socket_paw_hind_R}, {.fore_R, .shin_fore_R, .socket_paw_fore_R}},
		{{.hind_L, .shin_hind_L, .socket_paw_hind_L}, {.fore_L, .shin_fore_L, .socket_paw_fore_L}},
	}
	for pair, side in legs {
		for chain, end in pair {
			turn := pose.legs[side][end]
			frame := end == 0 ? rear : front
			frame *= fox_turn(FOX_PIVOT[chain[0]], rot_z(turn.y) * rot_x(turn.x))
			for joint in chain {frames[joint] = frame}
		}
	}
	root, tip := FOX_PIVOT[.tail], FOX_PIVOT[FOX_GRIP]
	tail := rear
	if pose.held {
		anchor := fox_point(rear, root)
		axis := linalg.normalize(tip-root)
		r := linalg.length(Vec3{rear[0,0], rear[1,0], rear[2,0]})
		side := Vec3{rear[0,0], rear[1,0], rear[2,0]} / r
		// Stretch only along the tail so the tip meets the simulated hand.
		stretch := IDENTITY
		factor := linalg.length(pose.hand-anchor) / (r*linalg.length(tip-root))
		for i in 0..<3 {
			for j in 0..<3 {stretch[i,j] += (factor-1)*axis[i]*axis[j]}
		}
		tail = frame_between(root, tip, anchor, pose.hand, side, r) * fox_turn(root, stretch)
	} else if !pose.dead {
		tail *= fox_turn(root, rot_y(fox_tail_sweep(phase)))
	}
	frames[.tail], frames[.tail_tip], frames[FOX_GRIP] = tail, tail, tail
	return
}

draw_workshop_fox :: proc(pose: Animal_Pose, e: Enemy) {
	frames := fox_joint_frames(pose, g.time + abs(e.home.x))
	draw_fox_meshes(&frames, pose.dead || pose.dizzy)
	if pose.dead || pose.dizzy {
		for eye in ([2]Fox_Joint{.eye_L, .eye_R}) {
			frame := frames[eye] * translate(FOX_PIVOT[eye]) * rot_y(eye == .eye_L ? 0.55 : -0.55)
			draw_cute_eye(frame, 0.086, true, pose.dead)
		}
	}
	if e.has_loot {
		color := ITEM_COLOR[e.loot]
		ball(frames[FOX_MOUTH], FOX_PIVOT[FOX_MOUTH], {0.24, 0.18, 0.18}, color.a > 0 ? color : CRUST)
	}
}
