package check

import game "../game"
import "core:fmt"
import "core:math"
import "core:math/linalg"

rules_prosio_character :: proc() {
	section("imported Prosio")
	vertices := game.PROSIO_VERTICES
	indices := game.PROSIO_INDICES
	body_indices := game.prosio_body_indices()
	valid := len(vertices) > 0 && len(vertices) <= game.PROSIO_VERTEX_CAPACITY &&
		len(game.PROSIO_PAINT) == len(vertices) && len(indices) % 3 == 0 &&
		body_indices > 0 && body_indices <= len(indices) &&
		body_indices % 3 == 0 && len(game.prosio_joints) == len(game.Prosio_Joint)
	for index in indices {
		valid = valid && int(index) < len(vertices)
	}
	morphs := 0
	bad_weights := 0
	bad_joints := 0
	for vertex in vertices {
		total: f32
		for k in 0 ..< 4 {
			joint, weight := int(vertex[9+k]), vertex[13+k]
			if joint < 0 || joint >= len(game.Prosio_Joint) || weight < 0 { bad_joints += 1 }
			total += weight
		}
		if math.abs(total - 1) >= 0.0002 { bad_weights += 1 }
		if vertex[6] != 0 || vertex[7] != 0 || vertex[8] != 0 {
			morphs += 1
		}
	}
	check("Prosio's painted animation mesh has valid triangles and skin weights", valid && bad_weights == 0 && bad_joints == 0,
		fmt.tprintf("%d vertices, %d colors, %d indices, %d body indices, %d joints, %d bad weights, %d bad joints",
			len(vertices), len(game.PROSIO_PAINT), len(indices), body_indices, len(game.prosio_joints), bad_weights, bad_joints))
	check("Both pairs of modeled eyelids have a geometric blink", morphs > 100)

	// Reach within the fixed segment lengths then verify the hand's world
	// contact and the continuity of the elbow and wrist along the chain.
	grip_error, elbow_error, wrist_error: f32
	for side in ([2]f32{-1,1}) {
		arm := side < 0 ? [3]game.Prosio_Joint{.Upper_Arm_R,.Forearm_R,.Hand_R} :
			[3]game.Prosio_Joint{.Upper_Arm_L,.Forearm_L,.Hand_L}
		upper, forearm, hand := arm[0], arm[1], arm[2]
		shoulder := game.prosio_rest_start(upper)
		target := shoulder + {side * 0.08, -0.32, 0.27}
		pose: [game.Prosio_Joint]game.Mat4
		game.prosio_reach_arm(&pose,upper,forearm,hand,{true,shoulder+{side*.36,-.11,.05},target},side)
		tip := game.prosio_point_in(pose[hand],game.prosio_rest_end(hand))
		elbow := game.prosio_point_in(pose[upper],game.prosio_rest_end(upper))
		wrist := game.prosio_point_in(pose[forearm],game.prosio_rest_end(forearm))
		grip_error = max(grip_error,linalg.length(tip-target))
		elbow_error = max(elbow_error,linalg.length(elbow-game.prosio_point_in(pose[forearm],game.prosio_rest_start(forearm))))
		wrist_error = max(wrist_error,linalg.length(wrist-game.prosio_point_in(pose[hand],game.prosio_rest_start(hand))))
	}
	check("Prosio's modeled hands reach an in-range contact without joint gaps", max(grip_error,elbow_error,wrist_error) < 0.0002,
		fmt.tprintf("grip %.6f, elbow %.6f, wrist %.6f",grip_error,elbow_error,wrist_error))
	rules_prosio_shapes()
	rules_prosio_reactions()
}

rules_prosio_shapes :: proc() {
	vertices := game.PROSIO_VERTICES
	next: u32
	valid := len(game.prosio_shape_ranges) == len(game.Prosio_Shape)
	for range in game.prosio_shape_ranges {
		valid = valid && range[0] == next && range[1] > 0
		next = range[0] + range[1]
	}
	for entry in game.prosio_shapes {
		valid = valid && entry[0] >= 0 && int(entry[0]) < len(vertices)
	}
	check("all nine sculpted shapes have valid packed data", valid && int(next) == len(game.prosio_shapes))
	if !valid { return }

	pose: [game.Prosio_Joint]game.Mat4
	for &joint in pose { joint = game.IDENTITY }
	weights: [game.Prosio_Shape]f32
	weights[.Fat] = 1
	game.prosio_skin(&pose, 0, weights)
	cheek, arm, leg: f32
	for row, i in vertices {
		x, y := abs(row[0]), row[1]
		growth := abs(game.prosio_skin_positions[i].x) - x
		if x > 0.15 && y > 1.35 && y < 1.52 { cheek = max(cheek, growth) }
		if x > 0.40 && y > 0.65 && y < 1.10 { arm = max(arm, growth) }
		if x > 0.12 && y > 0.12 && y < 0.40 { leg = max(leg, growth) }
	}
	check("fat rounds out Prosio's cheeks, arms and legs", min(cheek, arm, leg) > 0.01,
		fmt.tprintf("outward movement: cheek %.3f, arm %.3f, leg %.3f", cheek, arm, leg))

	lean: game.Prosio
	lean.trait[.Arms], lean.trait[.Legs] = 1, 1
	muscle := game.prosio_shape_weights(&lean, game.PROSIO_MESH_BELLY.x, 0, {})
	check("trained limbs can grow independently of cheek fat and meal fullness",
		muscle[.Arm_Muscle] == 1 && muscle[.Leg_Muscle] == 1 && muscle[.Chest_Muscle] > 0 &&
		muscle[.Fat] == 0 && muscle[.Belly_Full] == 0)
}

rules_prosio_reactions :: proc() {
	fresh()
	p := &game.g.prosio
	game.sack_add(.Pumpkin, game.item_kcal(.Pumpkin))
	p.sack_sel = .Pumpkin
	game.eat_from_sack()
	big := p.meal_target
	game.update_prosio_reactions(p, 0.05)
	waited := p.meal_fill == 0
	p.eat_t = 0
	game.update_prosio_reactions(p, 0.5)
	filled := p.meal_fill
	game.update_prosio_reactions(p, 8)
	settled := p.meal_fill
	fresh()
	game.sack_add(.Apple, game.item_kcal(.Apple))
	p.sack_sel = .Apple
	game.eat_from_sack()
	check("swallowing fills the belly for a while, with more room for a large meal",
		waited && filled > p.meal_target && filled > 0.1 && big > p.meal_target && settled < filled * 0.1)

	fresh()
	p.need[.Carbs] = 100
	step(1)
	hiccup := p.airborne && p.hiccup_pose_t > 0 && game.prosio_reaction(p, 0).hiccup > 0.9
	fresh()
	p.need[.Fibre] = 100
	step(1)
	game.update_prosio_reactions(p, game.PROSIO_REACTION_TIME.x * 0.4)
	gas := p.gas_pose_t > 0 && game.prosio_reaction(p, 0).gas > 0.5
	game.update_prosio_reactions(p, 1)
	check("real hiccups launch a startle, and real wind starts a recoil that settles",
		hiccup && gas && game.prosio_reaction(p, 0).gas == 0)

	p.tipsy_pose_t = game.PROSIO_REACTION_TIME.z * 0.5
	a := game.prosio_reaction(p, math.PI / (2 * game.PROSIO_REACTION_SWAY.x))
	b := game.prosio_reaction(p, 3 * math.PI / (2 * game.PROSIO_REACTION_SWAY.x))
	game.update_prosio_reactions(p, game.PROSIO_REACTION_TIME.z)
	check("the tipsy presentation sways both ways and fades back to idle",
		a.sway > 0.9 && b.sway < -0.9 && a.tipsy > 0.9 && game.prosio_reaction(p, 0).tipsy == 0)
}
