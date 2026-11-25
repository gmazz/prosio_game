package game

import "core:math"
import "core:math/linalg"

// Prosio's pose: where each part of him is this frame, worked out from his
// state, with nothing drawn. Two bodies are drawn from it: the body of shapes
// he has always had (and his clothes on it), and the skin made in Blender
// (see prosio_base.odin), which bends on the same 36 parts. The parts are the
// contract with Blender: the skin's bones are named after them, and the skin
// was made at their bind pose (assets/prosio_base/bind.json, which this
// procedure writes: see the check program's export-prosio-base).

// Each name is a deformation region in the workshop's Blender armature.
Prosio_Part :: enum {
	Pelvis, Haunch_L, Haunch_R, Belly, Chest, Head, Snout, Ear_L, Ear_R,
	Thigh_L, Thigh_R, Knee_L, Knee_R, Shin_L, Shin_R, Toe_Inner_L, Toe_Inner_R,
	Toe_Outer_L, Toe_Outer_R, Shoulder_L, Shoulder_R, Upper_Arm_L, Upper_Arm_R,
	Biceps_L, Biceps_R, Elbow_L, Elbow_R, Forearm_L, Forearm_R, Hand_L, Hand_R,
	Neck, Pec_L, Pec_R, Brow_L, Brow_R,
}

// A part: the shape it is drawn as in the body of shapes, where, and its colour.
Prosio_Piece :: struct {
	shape: Shape,
	frame: linalg.Matrix4f32,
	color: Color,
}

// The skin's face is drawn on it as small shapes: the eyes and their
// catchlights, closed lids, the mouth. (By name, for the bind export.)
Prosio_Detail :: struct {
	name:  string,
	piece: Prosio_Piece,
}
PROSIO_DETAILS_MAX :: 32

Prosio_Leg :: struct {
	hip:                 Mat4, // the thigh's frame
	start, knee, ankle: Vec3, // in it
}

Prosio_Arm :: struct {
	shoulder, elbow, hand: Vec3, // in the body's frame (root)
}

Prosio_Pose :: struct {
	pieces:       [Prosio_Part]Prosio_Piece,
	face_fat:     f32, // how much of the skin's "Facial Fat" shape
	details:      [PROSIO_DETAILS_MAX]Prosio_Detail,
	detail_count: int,

	// What the body of shapes and its clothes are drawn from.
	skin, skin_dark:      Color,
	t, swing:             f32, // his fatness, and how his arms and legs swing as he walks
	root:                 Mat4, // his body's frame, unsquashed: the arms and the head hang from it
	torso:                Mat4, // above the hips, squashed and compacted
	hips, chest:          f32,
	belly_w, belly_h:     f32, // the belly's radius and half-height, as it wobbles
	belly_r:              f32, // its radius before it wobbles (his pack sits behind it)
	belly_mid, belly_out: f32,
	jacket:               Mat4, // the top of his chest, where a shirt sits
	jacket_w, jacket_h:   f32,
	leg_r, arm_r:         f32,
	legs:                 [2]Prosio_Leg, // left, right
	arms:                 [2]Prosio_Arm,
	item_shown:           bool, // what he picked up, in his hoof
	item_side:            int,
	item_color:           Color,
	head:                 Mat4, // the head of shapes' frame
	cheeks, head_r:       f32,
	ear_droop:            [2]f32,
	eyes_closed:          bool,
	brow_tilt:            f32, // positive is worried, negative is fierce
	mouth_open, teeth:    bool,
	quiet:                bool, // no smile
}

prosio_side_part :: proc(left: Prosio_Part, side: f32) -> Prosio_Part {
	return side < 0 ? left : Prosio_Part(int(left) + 1)
}

@(private = "file")
put :: proc(pose: ^Prosio_Pose, part: Prosio_Part, shape: Shape, frame: Mat4, color: Color) {
	pose.pieces[part] = {shape, frame, color}
}

@(private = "file")
put_ball :: proc(pose: ^Prosio_Pose, part: Prosio_Part, frame: Mat4, pos, size: Vec3, color: Color) {
	put(pose, part, .Sphere, frame * translate(pos) * scale(size), color)
}

@(private = "file")
put_taper :: proc(pose: ^Prosio_Pose, part: Prosio_Part, frame: Mat4, a, b: Vec3, radius: f32, color: Color) {
	put(pose, part, .Frustum, taper_frame(frame, a, b, radius), color)
}

@(private = "file")
put_detail :: proc(pose: ^Prosio_Pose, name: string, frame: Mat4, at, radii: Vec3, color: Color) {
	pose.details[pose.detail_count] = {name, {.Sphere, frame * translate(at) * scale(radii), color}}
	pose.detail_count += 1
}

// His pose now. With bind, his arms are held out from his sides, as the skin
// was made (the wider stance shows the armpits).
prosio_pose :: proc(bind := false) -> (pose: Prosio_Pose) {
	p := &g.prosio
	t := fatness()
	reaction := prosio_reaction(p, g.time)
	// A tough hide is a darker, rougher one.
	skin := blend(COLOR_SKIN, HIDE_TAN, p.trait[.Hide] * 0.7)
	skin_dark := blend(COLOR_SKIN_DARK, shade(HIDE_TAN, 0.85), p.trait[.Hide] * 0.7)
	if too_much(.Vitamins) && p.fail == .None {
		// Too many vitamins: he glows orange.
		glow := 0.6 + 0.15 * math.sin(g.time * 5)
		skin = blend(skin, {255, 150, 40, 255}, glow)
		skin_dark = blend(skin_dark, {230, 110, 30, 255}, glow)
	}
	pose.skin, pose.skin_dark, pose.t = skin, skin_dark, t
	r := prosio_radius(p.kg) / PROSIO_SIZE // (drawn in his own measurements, then scaled)
	wob := p.wobble

	speed := length2(p.vel)
	walking := speed > 0.5 && p.fail == .None && !p.airborne
	// Picking something up: he stoops and reaches down for it (reach_down
	// goes 0 to 1), then brings it up over his shoulder into the sack on his
	// back (stow goes 0 to 1).
	picking := p.pick_t > 0 && p.fail == .None
	u := picking ? 1 - p.pick_t / max(p.pick_total, 0.01) : 0
	reach_down := smooth(min(u * 2.2, 1))
	stow := smooth(clamp(u * 2.2 - 1.2, 0, 1))
	stoop := reach_down * (1 - stow)
	bob: f32 = walking ? abs(math.sin(p.walk_phase)) * 0.07 : 0
	swing: f32 = walking ? math.sin(p.walk_phase) * (p.sprinting ? 1.0 : 0.7) : 0
	pose.swing = swing

	// The collision radius follows the belly. The jacket stays snug as he grows.
	// Eating goes to the belly: it swells forwards and sideways, while his
	// bottom stays about the same size.
	belly_out := 0.03 + 0.17 * t // how far the belly sticks out in front
	belly := (r - belly_out * 0.6) * lerp(0.8, 0.93, t)
	belly_out += p.meal_fill * PROSIO_MEAL_DRAW.x
	belly += p.meal_fill * PROSIO_MEAL_DRAW.y
	chest := prosio_chest(p.kg)
	hips := 0.3 + 0.1 * t
	head := f32(0.46) // a big round head: he is drawn cute, kawaii style
	pose.chest, pose.hips = chest, hips
	pose.belly_r = belly

	base := translate({p.pos.x, p.height, p.pos.y}) * rot_y(p.facing) * scale({PROSIO_SIZE, PROSIO_SIZE, PROSIO_SIZE})
	m := base * translate({0, bob, 0})
	eyes_closed := math.mod(g.time, PROSIO_BLINK.x) < PROSIO_BLINK.y
	brow_tilt: f32 = 0 // positive is worried, negative is fierce
	if starving() || p.fat > FAT_MAX - FAT_DANGER || p.winded {
		brow_tilt = 0.4
	}
	switch {
	case p.fail == .Fainted || p.fail == .Diet || p.fail == .Beaten:
		// Topples over onto his side.
		a := smooth(p.fail_t / 0.5)
		m = base * translate({a * 1.0, a * chest, 0}) * rot_z(a * 1.5)
		eyes_closed = true
	case p.fail == .Heart_Attack:
		// Flops onto his back, belly up.
		a := smooth(p.fail_t / 0.5)
		m = base * translate({0, a * belly * 0.8, a * 1.0}) * rot_x(-a * 1.5)
		eyes_closed = true
	case picking:
		m = m * translate({0, -0.1 * stoop, 0}) * rot_x(0.55 * stoop)
	case p.ache_t > 0:
		// Doubled up with a tummy ache or a cramp.
		m = m * rot_x(0.45) * rot_z(math.sin(g.time * 22) * 0.05)
		eyes_closed = true
		brow_tilt = 0.5
	case p.dash_t > 0:
		m = m * rot_x(0.2)
		brow_tilt = -0.5
	case p.carry == .Enemy:
		// Leaning back against a heavy animal, or into a swing.
		lean := -0.45 * p.strain
		if p.swinging {
			k := min(p.swing_t / p.swing_total, 1)
			lean = p.swing_throw ? -0.25 + 0.5 * k : 0.35 * math.sin(k * math.PI * 0.9)
		}
		m = m * rot_x(lean)
		brow_tilt = p.strain > 0.5 ? 0.35 : -0.4
	case p.dazed_t > 0:
		m = m * rot_z(math.sin(g.time * 9) * 0.2)
		eyes_closed = true
	}
	if p.carry == .Nothing && p.fail == .None {
		pitch := reaction.gas * PROSIO_REACTION_WIND.x - reaction.hiccup * PROSIO_REACTION_SWAY.z
		roll := reaction.sway * PROSIO_REACTION_SWAY.y + reaction.gas * PROSIO_REACTION_WIND.y
		m = m * rot_x(pitch) * rot_z(roll)
	}
	pose.eyes_closed, pose.brow_tilt = eyes_closed, brow_tilt
	// Squash the torso. The limbs use the same body orientation and an
	// unscaled rig, with the shoulders attached to the squashing chest.
	root := m
	pose.root = root
	st := clamp(p.stretch, -0.3, 0.3)
	squash := Vec3{1 - st * 0.5, 1 + st, 1 - st * 0.5}
	m = root * scale(squash)

	// Legs: a thick thigh tapering to a round knee, then a slimmer shin
	// tapering to a cloven hoof. The knee bends a little as he walks, and in
	// the air he tucks his legs up.
	leg_x := 0.13 + 0.13 * t
	leg_r := (0.1 + 0.06 * t) * tone(.Legs, 0.85, 1.45) // thin when wasted, sturdy when built
	pose.leg_r = leg_r
	for side, si in ([2]f32{-1, 1}) {
		leg_swing := p.airborne ? -0.5 + side * 0.3 : side * swing
		hip := root * translate({side * leg_x, HIP * LEG_SCALE, 0}) * rot_x(leg_swing)
		bend := 0.03 + (p.airborne ? 0.12 : 0.07 * max(-side * swing, 0))
		start := Vec3{0, 0.06, 0}
		upper := Vec3{0, -0.23 * LEG_SCALE - start.y, 0.03}
		lower := Vec3{0, -0.18 * LEG_SCALE, -0.03}
		knee := start + linalg.normalize0(Vec3{0, upper.y, bend}) * linalg.length(upper)
		ankle := knee + linalg.normalize0(Vec3{0, lower.y, -bend}) * linalg.length(lower)
		put_taper(&pose, prosio_side_part(.Thigh_L, side), hip, start, knee, leg_r * 1.5, skin)
		put_ball(&pose, prosio_side_part(.Knee_L, side), hip, knee, {leg_r * 0.95, PROSIO_BASE_KNEE_AXIAL, leg_r * 0.95}, skin)
		put_taper(&pose, prosio_side_part(.Shin_L, side), hip, knee, ankle, leg_r * 0.98, skin)
		sole := ankle + Vec3{0, -0.01 * LEG_SCALE, 0.05}
		for toe in ([2]f32{-1, 1}) {
			part: Prosio_Part = toe * side > 0 ? .Toe_Outer_L : .Toe_Inner_L
			put_ball(&pose, prosio_side_part(part, side), hip, sole + {toe * leg_r * 0.42, 0, 0},
				{leg_r * 0.64, 0.075, leg_r * 1.2}, COLOR_HOOF)
		}
		pose.legs[si] = {hip, start, knee, ankle}
	}
	// Everything above the hips: sat on the shorter legs, a little compacted.
	m = m * translate({0, HIP * LEG_SCALE, 0}) * scale({1, TORSO_SCALE, 1}) * translate({0, -HIP, 0})
	pose.torso = m

	// His own body, whole, with nothing on: two round buttocks, the belly, and
	// a chest that rises from the top of the belly to his shoulders.
	put_ball(&pose, .Pelvis, m, {0, 0.6, 0.05}, {hips * 0.95 - LAYER, 0.2 - LAYER, hips * 0.8 - LAYER}, skin)
	for side in ([2]f32{-1, 1}) {
		put_ball(&pose, prosio_side_part(.Haunch_L, side), m, {side * hips * 0.42, 0.57, -hips * 0.25},
			{hips * 0.58 - LAYER, 0.21 - LAYER, hips * 0.62 - LAYER}, skin)
	}
	belly_y := 0.26 + 0.2 * t + p.meal_fill * PROSIO_MEAL_DRAW.z
	belly_mid := 0.86 + 0.04 * t // the belly hangs over the shorts, but not down to the knees
	put_ball(&pose, .Belly, m, {0, belly_mid, belly_out},
		{belly * (1 + wob), belly_y * (1 - wob), belly * (1 + wob)}, skin)
	pose.belly_w, pose.belly_h, pose.belly_mid, pose.belly_out = belly * (1 + wob), belly_y * (1 - wob), belly_mid, belly_out
	// His chest follows the upper arc of his belly, and so does a shirt.
	jacket := m * translate({0, belly_mid + belly_y * (1 - wob) * 0.51, belly_out})
	jacket_w := max(chest, belly * (1 + wob) * 0.86 + 0.014)
	jacket_h := max(0.33, 1.46 - (belly_mid + belly_y * (1 - wob) * 0.51))
	put(&pose, .Chest, .Hemisphere, jacket * scale({jacket_w - LAYER, jacket_h - LAYER * 0.5, jacket_w - LAYER}), skin)
	pose.jacket, pose.jacket_w, pose.jacket_h = jacket, jacket_w, jacket_h
	{
		pec := PROSIO_BASE_PEC_ANCHOR
		radii := PROSIO_BASE_PEC_RADII
		motion := PROSIO_BASE_PEC_MOTION
		soften := smooth(clamp((p.kg - PROSIO_BASE_PEC_MASS.x) / PROSIO_BASE_PEC_MASS.y, 0, 1))
		trained := max(0, p.trait[.Arms])
		for side in ([2]f32{-1, 1}) {
			put_ball(&pose, prosio_side_part(.Pec_L, side), jacket,
				{side * jacket_w * pec.x, jacket_h * pec.y, jacket_w * pec.z},
				{jacket_w * radii.x, radii.y * (1 - motion.x * soften),
					radii.z * (1 - motion.y * soften + motion.z * trained)}, skin)
		}
	}

	// Aim outside the current belly cross-section in torso space, then solve
	// the arm using fixed segment lengths in the rigid body frame.
	arm_r := lerp(0.1, 0.135, t) * tone(.Arms, 0.78, 1.5) // noodles when wasted, bulging when built
	pose.arm_r = arm_r
	belly_width := belly * (1 + wob)
	belly_height := belly_y * (1 - wob)
	for side, si in ([2]f32{-1, 1}) {
		shoulder := Vec3{side * (chest * 0.86), 1.30, 0.035}
		rest_x := side * (chest + arm_r * 0.85)
		elbow := Vec3{rest_x, 1.09, 0.04 - side * swing * 0.18}
		hand := Vec3{rest_x, 0.86 + 0.075 * abs(swing), 0.16 - side * swing * 0.35}
		holds := p.carry == .Enemy && (side == HOLD_SIDE || two_handed(g.enemies[p.carry_index].kind))
		switch {
		case holds:
			// A hoof on the leg or the tail, wherever it is (or both hooves,
			// one on each hind leg of a goat): the hold point is turned into
			// his own frame and kept within arm's reach.
			local := direction_to_prosio(p.hand - {p.pos.x, p.height, p.pos.y}) / PROSIO_SIZE
			if two_handed(g.enemies[p.carry_index].kind) {
				local.x += side * 0.09
			}
			local.y = (local.y - HIP * LEG_SCALE) / TORSO_SCALE + HIP // into the compacted body's measurements
			from_shoulder := local - shoulder
			reach := linalg.length(from_shoulder)
			if reach > 0.75 {
				local = shoulder + from_shoulder * (0.75 / reach)
			}
			hand = local
			elbow = (shoulder + hand) * 0.5 + {side * 0.1, -0.04, 0}
		case p.carry == .Enemy && (p.swinging || p.strain > 0.4):
			// The free arm flung out for balance.
			elbow = {side * (chest + 0.22), 1.25, 0.05}
			hand = {side * (chest + 0.36), 1.45, 0.12}
		case p.carry == .Rock:
			lift := smooth(1 - p.lift_t / max(p.lift_total, 0.001))
			reach := (r + carry_radius()) * (1 - lift)
			hand = {side * lerp(carry_radius() * 0.66, 0.37, lift), lerp(0.54, 2.29, lift), lerp(reach, 0.10, lift)}
			elbow = {side * max(chest + 0.21, 0.53), lerp(0.99, 1.78, lift), 0.19 + 0.25 * (1 - lift)}
		case picking && side == HOLD_SIDE:
			// Down to the ground in front of him, then up and back over his
			// shoulder.
			ground := Vec3{side * (chest * 0.7), 0.2, belly_out + belly + 0.25}
			sack := Vec3{side * (chest * 0.6), 1.62, -0.12}
			low := hand + (ground - hand) * reach_down
			hand = low + (sack - low) * stow
			elbow = shoulder + (hand - shoulder) * 0.5 + {side * 0.16, 0.06, 0}
		case reaction.hiccup > 0:
			// A startle on the first beat and loose elbows as the hop settles.
			elbow.z += reaction.hiccup * PROSIO_REACTION_ARMS.y
			hand.y += reaction.hiccup * PROSIO_REACTION_ARMS.z
		case p.airborne:
			elbow = {side * (chest + 0.23), 1.36, 0.07}
			hand = {side * (chest + 0.32), 1.62, 0.18}
		case p.eat_t > 0:
			hand = {side * 0.24, 1.55, 0.48}
			elbow.z = 0.32
		case p.shake_t > 0 && p.fail == .None:
			// Both hooves on the trunk in front of him, shaking it to and fro.
			jiggle := math.sin(g.time * 38) * 0.06 * p.shake_power
			hand = {side * 0.22, 1.2, belly_out + belly + 0.3 + jiggle}
			elbow = {side * (chest + 0.12), 1.2, (belly_out + belly) * 0.5 + jiggle * 0.5}
		case p.dash_t > 0:
			hand.y, hand.z = 1.02, -0.31
			elbow.z = -0.23
		case reaction.gas > 0 || reaction.tipsy > 0:
			// Loose, asymmetric counterbalance during the stagger.
			brace := reaction.gas * PROSIO_REACTION_WIND.z
			spread := max(0, reaction.tipsy + side * reaction.sway) * PROSIO_REACTION_ARMS.x
			elbow.x += side * (spread + brace)
			hand.x += side * spread
			hand.y += spread
			hand.z -= brace
		}
		for point in ([2]^Vec3{&elbow, &hand}) {
			dy := (point.y - belly_mid) / belly_height
			dz := (point.z - belly_out) / belly_width
			section := 1 - dy * dy - dz * dz
			if section > 0 {
				clearance := belly_width * math.sqrt(section) + arm_r * 1.17
				point.x = side * max(abs(point.x), clearance)
			}
		}
		// Chubby arms: a plump upper arm with a round biceps, narrowing to the
		// elbow, then a forearm narrowing to the hoof; a round shoulder joins it
		// to his chest.
		if bind {
			elbow.x += side * arm_r * 1.45
			hand.x += side * arm_r * 2.25
		}
		for point in ([3]^Vec3{&shoulder, &elbow, &hand}) {
			point.y = (point.y - HIP) * TORSO_SCALE + HIP * LEG_SCALE
			point^ *= squash
		}
		if holds {
			contact := p.hand
			if two_handed(g.enemies[p.carry_index].kind) {
				contact += hold_apart(side)
			}
			hand = (linalg.inverse(root) * [4]f32{contact.x, contact.y, contact.z, 1}).xyz
		}
		elbow, hand = prosio_arm(shoulder, elbow, hand, side)
		axial := PROSIO_BASE_ARM_AXIAL
		put_taper(&pose, prosio_side_part(.Upper_Arm_L, side), root, shoulder, elbow, arm_r * 1.75, skin)
		put_ball(&pose, prosio_side_part(.Biceps_L, side), root, shoulder + (elbow - shoulder) * 0.45,
			{arm_r * 1.45, axial.y, arm_r * 1.45}, skin)
		put_ball(&pose, prosio_side_part(.Elbow_L, side), root, elbow, {arm_r * 1.05, axial.z, arm_r * 1.05}, skin)
		put_taper(&pose, prosio_side_part(.Forearm_L, side), root, elbow, hand, arm_r * 1.12, skin)
		put_ball(&pose, prosio_side_part(.Shoulder_L, side), root, shoulder, {arm_r * 1.7, axial.x, arm_r * 1.7}, skin)
		dim := PROSIO_BASE_HAND_RADII
		put_ball(&pose, prosio_side_part(.Hand_L, side), root, hand, {arm_r * dim.x, dim.y * TORSO_SCALE, arm_r * dim.z}, skin)
		pose.arms[si] = {shoulder, elbow, hand}
		if picking && !p.drinking && side == HOLD_SIDE && u > 0.45 {
			pose.item_shown, pose.item_side, pose.item_color = true, si, ITEM_COLOR[p.pick_item]
		}
	}

	// The head: cheeks get rounder too.
	munch: f32 = p.eat_t > 0 ? math.sin(p.eat_t * 40) * 0.05 : 0
	prosio_face(&pose, root, munch, stoop, brow_tilt, walking, eyes_closed, reaction, skin, skin_dark)
	h := root * translate({0, HEAD_HEIGHT + munch, 0.04}) * rot_x(-0.16)
	if picking {
		h = h * rot_x(0.3 * stoop) // looking at what he picks up
	}
	pose.head, pose.cheeks, pose.head_r = h, head * (1 + 0.2 * t), head
	for side, si in ([2]f32{-1, 1}) {
		// Floppy ears: they hang down beside his cheeks, flap a little as he
		// walks, and fly up when he falls.
		droop := EAR_DROOP + (walking ? 0.14 * math.sin(p.walk_phase * 2 + side) : 0.03 * math.sin(g.time * 2 + side))
		if p.airborne {
			droop = clamp(1.5 + p.vy * 0.09, 0.6, EAR_DROOP)
		}
		pose.ear_droop[si] = droop
	}
	pose.mouth_open = p.eat_t > 0 || p.airborne
	pose.teeth = p.strain > 0.5 || p.heave_t > 0
	pose.quiet = pose.teeth || eyes_closed && p.fail != .None
	return
}

// A palm target outside the arm's reach is capped before the elbow is solved.
// The hint picks the bend plane while both segment lengths stay fixed.
prosio_arm :: proc(shoulder, hint, target: Vec3, side: f32) -> (elbow, palm: Vec3) {
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

// How much of the skin's "Facial Fat" shape his fat gives his face (a little
// below nothing when lean).
prosio_face_fat :: proc(fat: f32) -> f32 {
	tune := PROSIO_BASE_FACE_FAT
	return smooth(clamp((fat - tune.x) / tune.y, 0, 1)) -
		tune.z * smooth(clamp((tune.x - fat) / tune.x, 0, 1))
}

// How his face shows what he feels: a smile after a good meal or when
// tipsy, and brows that lift with a smile, a hiccup or wind.
Prosio_Expression :: struct {
	smile, brow_lift: f32,
}

prosio_expression :: proc(p: ^Prosio, reaction: Prosio_Reaction) -> (e: Prosio_Expression) {
	if p.fail != .None {
		return
	}
	if p.eat_t <= 0 && p.meal_hold_t > 0 {
		e.smile = smooth(min(p.meal_hold_t * PROSIO_FACE_SMILE_FADE, p.meal_fill, 1))
	}
	e.smile = max(e.smile, reaction.tipsy * PROSIO_FACE_TIPSY_SMILE)
	e.brow_lift = max(e.smile * PROSIO_FACE_BROWS.x, reaction.hiccup * PROSIO_FACE_BROWS.y, reaction.gas * PROSIO_FACE_BROWS.z)
	return
}

// The skin's head, neck, snout, ears and brows (parts), and the eyes and mouth
// drawn on it (details).
@(private = "file")
prosio_face :: proc(pose: ^Prosio_Pose, root: Mat4, munch, stoop, brow_tilt: f32,
                    walking, eyes_closed: bool, reaction: Prosio_Reaction, skin, snout: Color) {
	p := &g.prosio
	face_y := HEAD_HEIGHT + PROSIO_BASE_HEAD_LIFT
	h := root * translate({0, face_y + munch, 0.04}) * rot_x(-0.16 + 0.30 * stoop) * scale(Vec3{PROSIO_BASE_HEAD_SCALE, PROSIO_BASE_HEAD_SCALE, PROSIO_BASE_HEAD_SCALE})
	neck := PROSIO_BASE_NECK_ANCHOR
	put_ball(pose, .Neck, root, {0, face_y - neck.x + munch * neck.y, neck.z}, PROSIO_BASE_NECK_RADII, skin)
	radii := PROSIO_BASE_HEAD_RADII
	put_ball(pose, .Head, h, {}, radii, skin)
	pose.face_fat = prosio_face_fat(p.fat)
	put_ball(pose, .Snout, h, PROSIO_BASE_SNOUT_CENTER, PROSIO_BASE_SNOUT_RADII, snout)
	expression := prosio_expression(p, reaction)
	brow_turn := PROSIO_BASE_BROW_TURN
	brow_lift := clamp(expression.brow_lift + brow_tilt * brow_turn.z, -1, 1)
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
		put_ball(pose, prosio_side_part(.Ear_L, side), ear, {0, PROSIO_BASE_EAR_CENTER, 0}, PROSIO_BASE_EAR_RADII, skin)

		brow := PROSIO_BASE_BROW_ANCHOR
		tune := PROSIO_BASE_BROW_MOTION
		brow_frame := h * translate({side * brow.x, brow.y + tune.x * brow_lift, brow.z - tune.y * brow_lift}) *
			rot_y(side * brow_turn.x) * rot_z(side * (brow_turn.y + brow_tilt * tune.z))
		put_ball(pose, prosio_side_part(.Brow_L, side), brow_frame, {}, PROSIO_BASE_BROW_RADII, skin)

		eye_at := PROSIO_BASE_EYE_ANCHOR
		eye := h * translate({side * eye_at.x, eye_at.y, eye_at.z}) * rot_y(side * PROSIO_BASE_EYE_TURN)
		if eyes_closed {
			put_detail(pose, "ClosedLid", eye, PROSIO_BASE_LID_AT, PROSIO_BASE_LID_RADII, COLOR_NOSTRIL)
		} else {
			put_detail(pose, side < 0 ? "Eye.L" : "Eye.R", eye, {}, PROSIO_BASE_EYE_RADII, COLOR_BLACK)
			put_detail(pose, "Catchlight", eye, PROSIO_BASE_GLINT_AT, PROSIO_BASE_GLINT_RADII, COLOR_WHITE)
			put_detail(pose, "SmallCatchlight", eye, PROSIO_BASE_SMALL_GLINT_AT, PROSIO_BASE_SMALL_GLINT_RADII, COLOR_WHITE)
		}
	}

	mouth := PROSIO_BASE_MOUTH
	switch {
	case p.eat_t > 0 || p.airborne:
		put_detail(pose, "OpenMouth", h, {0, mouth.y, mouth.z}, PROSIO_BASE_OPEN_MOUTH, COLOR_NOSTRIL)
	case p.strain > 0.5 || p.heave_t > 0:
		put_detail(pose, "Teeth", h, {0, mouth.y, mouth.z}, PROSIO_BASE_TEETH, COLOR_WHITE)
	case !eyes_closed || p.fail == .None:
		arc := PROSIO_BASE_SMILE_ARC
		tilt := PROSIO_BASE_SMILE_TILT
		for i in 0 ..< 7 {
			u := f32(i) / 3 - 1
			curve := u * u
			at := Vec3{mouth.x * u, mouth.y + curve * (arc.x + expression.smile * arc.y), mouth.z - arc.z * curve}
			angle := u * (tilt.x + expression.smile * tilt.y)
			put_detail(pose, "Smile", h * translate(at) * rot_z(angle), {}, PROSIO_BASE_SMILE_RADII, COLOR_NOSTRIL)
		}
	}
}
