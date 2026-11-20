package game

import "core:math"
import "core:math/linalg"

// Everything is drawn from a handful of simple shapes placed with matrices.

COLOR_SKY :: Color{159, 181, 157, 255}
COLOR_OUTSIDE :: Color{93, 130, 105, 255}
COLOR_TUFT :: Color{94, 132, 85, 255}
COLOR_FENCE :: Color{174, 145, 99, 255}
COLOR_SHACK :: Color{172, 97, 71, 255}
COLOR_VAULT :: Color{124, 147, 141, 255}
COLOR_GATE :: Color{75, 98, 100, 255}
COLOR_SKIN :: Color{249, 181, 160, 255}
COLOR_SKIN_DARK :: Color{222, 136, 127, 255}
COLOR_BLUSH :: Color{230, 136, 125, 255}
COLOR_NOSTRIL :: Color{116, 67, 71, 255}
COLOR_SHIRT :: Color{222, 163, 64, 255}
COLOR_SHORTS :: Color{60, 106, 111, 255}
COLOR_HEADBAND :: Color{178, 65, 52, 255}
COLOR_HOOF :: Color{96, 62, 57, 255}
COLOR_WHITE :: Color{255, 248, 226, 255}
COLOR_BLACK :: Color{49, 43, 46, 255}
COLOR_STAR :: Color{255, 226, 80, 255}
COLOR_GOLD :: Color{255, 196, 40, 255}
COLOR_DUST :: Color{232, 220, 188, 255}
COLOR_SWEAT :: Color{130, 200, 255, 255}
COLOR_CRUMB :: Color{240, 190, 120, 255}
COLOR_HEART :: Color{235, 50, 70, 255}
COLOR_LEAF :: Color{96, 164, 80, 255}
COLOR_LEAF_DARK :: Color{66, 134, 76, 255}
COLOR_LEAF_LIGHT :: Color{146, 190, 90, 255}
COLOR_TRUNK :: Color{120, 99, 77, 255}
COLOR_ROCK :: Color{137, 150, 143, 255}
COLOR_ROCK_LIGHT :: Color{157, 166, 146, 255}
COLOR_PLANK :: Color{214, 168, 110, 255}
COLOR_CRATE :: Color{196, 142, 84, 255}
COLOR_IRON :: Color{74, 78, 96, 255}

FLOWER_COLORS := [?]Color{{255, 120, 150, 255}, {255, 236, 120, 255}, {250, 250, 255, 255}, {190, 150, 255, 255}}

// A darker or lighter version of a colour.
shade :: proc(c: Color, f: f32) -> Color {
	return {u8(min(f32(c.r) * f, 255)), u8(min(f32(c.g) * f, 255)), u8(min(f32(c.b) * f, 255)), c.a}
}

ball :: proc(m: Mat4, pos, size: Vec3, color: Color) {
	draw_shape(.Sphere, m * translate(pos) * scale(size), color)
}

box :: proc(m: Mat4, pos, size: Vec3, color: Color) {
	draw_shape(.Cube, m * translate(pos) * scale(size), color)
}

// An upright cylinder standing on pos.
tube :: proc(m: Mat4, pos: Vec3, radius, height: f32, color: Color) {
	draw_shape(.Cylinder, m * translate(pos) * scale({radius, height, radius}), color)
}

// An upright cone standing on pos.
cone :: proc(m: Mat4, pos: Vec3, radius, height: f32, color: Color) {
	draw_shape(.Cone, m * translate(pos) * scale({radius, height, radius}), color)
}

// The world is much bigger than the screen, so things far from the camera
// are not drawn at all.
on_screen :: proc(pos: Vec2, margin: f32 = 0) -> bool {
	z := g.camera_zoom
	dx := abs(pos.x - g.camera.x)
	dz := pos.y - g.camera.y
	return dx < 21 * z + margin && dz > -19 * z - margin && dz < 10 * z + margin
}

// Rounded joints for arms, legs and tails. The long axis joins
// the two endpoints in model space, including when the parent is tilted.
limb :: proc(m: Mat4, a, b: Vec3, radius: f32, color: Color) {
	d := b - a
	span := math.sqrt(d.x * d.x + d.z * d.z)
	length := math.sqrt(span * span + d.y * d.y)
	joint := m * translate((a + b) * 0.5) * rot_y(math.atan2(d.x, d.z)) * rot_x(math.atan2(span, d.y))
	ball(joint, {}, {radius, length * 0.5 + radius * 0.38, radius}, color)
}

// A tapered limb from a to b: radius ra at a, narrowing towards b, like a
// thigh or a forearm.
taper :: proc(m: Mat4, a, b: Vec3, ra: f32, color: Color) {
	d := b - a
	span := math.sqrt(d.x * d.x + d.z * d.z)
	length := math.sqrt(span * span + d.y * d.y)
	frame := m * translate(a) * rot_y(math.atan2(d.x, d.z)) * rot_x(math.atan2(span, d.y))
	draw_shape(.Frustum, frame * scale({ra, length, ra}), color)
}

// The sun is high on the left. The projected shadow moves away from the
// feet and softens when its caster rises. The quad fades to transparent.
shadow :: proc(pos: Vec2, radius: f32, ground: f32 = 0, rise: f32 = 0) {
	offset := max(rise, 0) * 0.65 + radius * 0.37
	extent := radius * (1.0 + min(max(rise, 0) * 0.07, 0.25))
	set_surface(.Shadow)
	centre := Vec3{pos.x + offset, ground + 0.057, pos.y - offset * 0.65}
	draw_shape(.Plane, translate(centre) * rot_y(-0.55) * scale({extent * 1.28, 1, extent * 0.92}),
		{48, 65, 65, u8(124 / (1 + max(rise, 0) * 0.18))})
	set_surface(.Solid)
}

// The cast footprint of walls and raised decks, offset along the sun direction.
structure_shadow :: proc(lo, hi: Vec2, height: f32) {
	if height < 0.05 {
		return
	}
	size := hi - lo
	offset := Vec2{0.69, -0.48} * height
	centre := (lo + hi + offset) * 0.5
	if !on_screen(centre, max(size.x, size.y) * 0.5 + height) {
		return
	}
	set_surface(.Rect_Shadow)
	draw_shape(.Plane, translate({centre.x, 0.047, centre.y}) *
		scale({(size.x + abs(offset.x)) * 0.52, 1, (size.y + abs(offset.y)) * 0.52}), {46, 63, 68, 104})
	set_surface(.Solid)
}

draw_world :: proc() {
	w := WORLD_HALF
	outlines_enabled = false
	box(IDENTITY, {0, -0.56, 0}, {w.x * 2 + 40, 1, w.y * 2 + 40}, COLOR_OUTSIDE)
	set_surface(.Meadow)
	draw_shape(.Terrain, translate({0, 0.01, 0}) * scale({w.x, 1, w.y}), COLOR_WHITE)
	set_surface(.Solid)
	for d in g.decor[:g.decor_count] {
		if !on_screen(d.pos) {
			continue
		}
		m := translate({d.pos.x, 0, d.pos.y}) * rot_y(f32(d.variant) * 1.7)
		switch d.kind {
		case .Tuft:
			for i in 0 ..< 3 {
				blade := m * rot_y(f32(i) * 2.1) * translate({0.06, 0, 0}) * rot_z(-0.3)
				cone(blade, {0, 0, 0}, 0.05, 0.2 + 0.05 * f32((d.variant + i) % 3), COLOR_TUFT)
			}
		case .Flower:
			tube(m, {0, 0, 0}, 0.02, 0.26, COLOR_TUFT)
			ball(m, {0, 0.28, 0}, {0.1, 0.06, 0.1}, FLOWER_COLORS[d.variant % len(FLOWER_COLORS)])
			ball(m, {0, 0.31, 0}, {0.04, 0.04, 0.04}, COLOR_STAR)
		}
	}

	// Shadows go down before anything stands on them.
	p := &g.prosio
	floor := ground_height(p.pos)
	shadow(p.pos, prosio_radius(p.kg) * 1.23, floor, p.height - floor)
	for e in g.enemies[:g.enemy_count] {
		if e.state != .Gone && on_screen(e.pos, 1) {
			shadow(e.pos, ENEMY_RADIUS[e.kind] * 1.2, 0, e.y)
		}
	}
	for &f in g.foods[:g.food_count] {
		if !f.gone && f.respawn <= 0 && on_screen(f.pos, 1) {
			shadow(f.pos, FOOD_SIZE[f.kind] * 1.3, 0, f.y)
		}
	}
	for r, i in g.rounds[:g.round_count] {
		if r.kind == .Tree && on_screen(r.pos, 5) {
			// The crown's shadow falls well away from the trunk, as the sun is high.
			t := tree_shape(i)
			shadow(r.pos, t.canopy * 1.05, 0, t.canopy_y * 0.75)
			shadow(r.pos, 0.4)
		} else if r.r > 0 && r.kind != .Tree && on_screen(r.pos, 2) {
			shadow(r.pos, r.r * 1.1)
		}
	}
	for wall in g.walls[:g.wall_count] {
		h := wall.height
		if wall.gate >= 0 {
			h -= g.gates[wall.gate].anim * (h + 0.2)
		}
		structure_shadow(wall.lo, wall.hi, h)
	}
	for deck in g.platforms[:g.platform_count] {
		structure_shadow(deck.lo, deck.hi, deck.ramp ? deck.height * 0.5 : deck.height)
	}
	if g.boulder.state == .Flying {
		shadow(g.boulder.pos, BOULDER_RADIUS, 0, g.boulder.y)
	}
	outlines_enabled = true

	// Pressure plate.
	open := g.gates[0].open
	tube(IDENTITY, {g.plate_pos.x, 0, g.plate_pos.y}, 1.05, 0.08, COLOR_IRON)
	tube(IDENTITY, {g.plate_pos.x, 0, g.plate_pos.y}, 0.88, open ? 0.1 : 0.2, open ? Color{96, 206, 96, 255} : Color{226, 84, 74, 255})

	// Fence: posts and two rails all the way round.
	for x := -w.x; x <= w.x; x += 2 {
		if abs(x - g.camera.x) > 21 * g.camera_zoom {
			continue
		}
		box(IDENTITY, {x, 0.45, -w.y - 0.2}, {0.24, 0.9, 0.24}, COLOR_FENCE)
		box(IDENTITY, {x, 0.45, w.y + 0.2}, {0.24, 0.9, 0.24}, COLOR_FENCE)
	}
	for z := -w.y + 2; z <= w.y - 2; z += 2 {
		if !on_screen({g.camera.x, z}, 1) {
			continue
		}
		box(IDENTITY, {-w.x - 0.2, 0.45, z}, {0.24, 0.9, 0.24}, COLOR_FENCE)
		box(IDENTITY, {w.x + 0.2, 0.45, z}, {0.24, 0.9, 0.24}, COLOR_FENCE)
	}
	rail := shade(COLOR_FENCE, 0.9)
	for y in ([2]f32{0.32, 0.68}) {
		box(IDENTITY, {0, y, -w.y - 0.2}, {w.x * 2 + 0.4, 0.1, 0.1}, rail)
		box(IDENTITY, {0, y, w.y + 0.2}, {w.x * 2 + 0.4, 0.1, 0.1}, rail)
		box(IDENTITY, {-w.x - 0.2, y, 0}, {0.1, 0.1, w.y * 2 + 0.4}, rail)
		box(IDENTITY, {w.x + 0.2, y, 0}, {0.1, 0.1, w.y * 2 + 0.4}, rail)
	}

	// Walls and gates.
	for wall in g.walls[:g.wall_count] {
		if wall.style == .Fence {
			continue
		}
		centre := (wall.lo + wall.hi) / 2
		size := wall.hi - wall.lo
		sink: f32 = 0
		if wall.gate >= 0 {
			sink = g.gates[wall.gate].anim * (wall.height + 0.2)
		}
		box(IDENTITY, {centre.x, wall.height / 2 - sink, centre.y}, {size.x, wall.height, size.y}, wall.color)
		if wall.gate >= 0 {
			// Gate bars.
			for i in 0 ..< 3 {
				x := wall.lo.x + size.x * (f32(i) + 0.5) / 3
				box(IDENTITY, {x, wall.height / 2 - sink, centre.y}, {0.14, wall.height + 0.1, size.y + 0.08}, shade(wall.color, 0.7))
			}
		} else {
			// A coping stone along the top.
			box(IDENTITY, {centre.x, wall.height + 0.05, centre.y}, {size.x + 0.14, 0.14, size.y + 0.14}, shade(wall.color, 0.78))
		}
	}
	// Posts either side of the skinny door.
	for side in ([2]f32{-1, 1}) {
		x := g.door_pos.x + side * (DOOR_GAP / 2 + 0.14)
		box(IDENTITY, {x, 0.85, g.door_pos.y}, {0.26, 1.7, 0.62}, COLOR_TRUNK)
		ball(IDENTITY, {x, 1.78, g.door_pos.y}, {0.17, 0.17, 0.17}, COLOR_STAR)
	}

	// Trees, rocks.
	for r, i in g.rounds[:g.round_count] {
		if r.r <= 0 || !on_screen(r.pos, r.kind == .Tree ? 5 : 2) {
			continue // carried, in flight, smashed or far away
		}
		switch r.kind {
		case .Tree:
			draw_tree(r.pos, i)
		case .Bush:
			draw_bush(r, i)
		case .Rock:
			m := translate({r.pos.x, 0, r.pos.y}) * rot_y(f32(i) * 2.3)
			draw_rock(m * translate({0, r.r * 0.34, 0}), r.r)
		case .Crate:
		// Drawn with the seesaws.
		}
	}

	// The tower and its ramp.
	for &pl, i in g.platforms[:g.platform_count] {
		centre := (pl.lo + pl.hi) / 2
		size := pl.hi - pl.lo
		if pl.ramp {
			slope := math.atan2(pl.height, size.y)
			length := math.sqrt(size.y * size.y + pl.height * pl.height)
			slab := translate({centre.x, pl.height / 2 - 0.07, centre.y}) * rot_x(slope)
			box(slab, {0, 0, 0}, {size.x, 0.14, length}, COLOR_PLANK)
			// Cleats to climb on, and trestles underneath.
			for k in 1 ..< 6 {
				box(slab, {0, 0.09, length * (f32(k) / 6 - 0.5)}, {size.x, 0.06, 0.12}, shade(COLOR_PLANK, 0.8))
			}
			for k in 1 ..< 3 {
				t := f32(k) / 3
				h := pl.height * t - 0.1
				box(IDENTITY, {centre.x, h / 2, pl.hi.y - size.y * t}, {size.x - 0.3, h, 0.2}, COLOR_TRUNK)
			}
		} else {
			box(IDENTITY, {centre.x, pl.height / 2 - 0.06, centre.y}, {size.x - 0.2, pl.height - 0.12, size.y - 0.2}, COLOR_CRATE)
			box(IDENTITY, {centre.x, pl.height - 0.06, centre.y}, {size.x, 0.12, size.y}, COLOR_PLANK)
			box(IDENTITY, {centre.x, pl.height * 0.45, centre.y}, {size.x - 0.12, 0.14, size.y - 0.12}, COLOR_TRUNK)
			if i == g.tower {
				// A painted spot: jump from here.
				tube(IDENTITY, {centre.x, pl.height + 0.005, centre.y}, 0.7, 0.01, COLOR_STAR)
				tube(IDENTITY, {centre.x, pl.height + 0.01, centre.y}, 0.45, 0.01, COLOR_HEADBAND)
			}
		}
	}
}

// The size of one tree, worked out from its number so it never changes.
Tree_Shape :: struct {
	species:  Tree_Species,
	size:     f32,
	canopy:   f32, // radius of the crown
	canopy_y: f32, // height of the crown's centre
}

// Trees are tall and slim, so that standing close together they make a
// little wood rather than a row of lollipops.
tree_shape :: proc(index: int) -> Tree_Shape {
	species := g.rounds[index].species
	size := 0.85 + 0.4 * math.mod(f32(index) * 0.37, 1)
	switch species {
	case .Pine:
		return {species, size, 1.25 * size, 3.2 * size}
	case .Apple:
		size *= 0.85 // apple trees are smaller, with a low, round crown
		return {species, size, 1.55 * size, 3.7 * size}
	case .Broadleaf, .Blossom:
	}
	return {species, size, 1.4 * size, 4.7 * size}
}

// A tree standing between the camera and Prosio fades to a see-through
// pattern where it covers him, so he never disappears behind it.
tree_fade :: proc(pos: Vec2, t: Tree_Shape) -> f32 {
	p := &g.prosio
	if pos.y < p.pos.y - 0.5 {
		return 0 // behind him
	}
	centre := Vec3{pos.x, t.canopy_y, pos.y}
	crown := world_to_screen(centre)
	reach := abs(world_to_screen(centre + {t.canopy, 0, 0}).x - crown.x)
	him := world_to_screen({p.pos.x, p.height + 1, p.pos.y})
	apart := length2(crown - him)
	cover := 1 - smooth((apart - reach * 0.75) / (reach * 0.5 + 1))
	// The leftover leaves show as single pixels, so it fades a long way.
	strength: f32 = 0.86
	return strength * cover * smooth((pos.y - p.pos.y + 0.5) / 1.0)
}

BERRY_COLOR :: Color{196, 40, 76, 255}

// Trees are built from a trunk and clusters of round leafy lumps, so they
// match everything else and sit correctly however the camera looks at them.
draw_tree :: proc(pos: Vec2, index: int) {
	t := tree_shape(index)
	s := t.size
	fade := tree_fade(pos, t)
	if fade > 0 {
		set_fade(fade)
	}
	defer if fade > 0 {
		set_fade(0)
	}
	m := translate({pos.x, 0, pos.y}) * rot_y(f32(index) * 2.39)
	// A shaken tree trembles for a moment.
	shake := g.rounds[index].shake_t
	crown := m * translate({math.sin(g.time * 47) * shake * 0.25, 0, math.cos(g.time * 39) * shake * 0.2})

	bark := t.species == .Blossom ? Color{104, 78, 72, 255} : COLOR_TRUNK
	set_surface(.Bark)
	switch t.species {
	case .Pine:
		cone(m, {}, 0.3 * s, 0.5 * s, bark)
		tube(m, {}, 0.17 * s, 2.4 * s, bark)
	case .Apple:
		cone(m, {}, 0.38 * s, 0.5 * s, bark)
		tube(m, {}, 0.2 * s, 3.0 * s, bark)
		for side in ([2]f32{-1, 1}) {
			limb(m, {0, 2.2 * s, 0}, {side * 0.75 * s, 3.1 * s, 0.2 * side * s}, 0.1 * s, bark)
		}
	case .Broadleaf, .Blossom:
		cone(m, {}, 0.36 * s, 0.6 * s, bark) // flared roots
		tube(m, {}, 0.19 * s, 4.0 * s, bark)
		for side in ([2]f32{-1, 1}) {
			limb(m, {0, 3.0 * s, 0}, {side * 0.6 * s, 3.9 * s, 0.2 * side * s}, 0.09 * s, bark)
		}
	}

	set_surface(.Leaf)
	set_sway(0.07 * s)
	defer set_sway(0)
	switch t.species {
	case .Pine:
		dark := Color{58, 112, 80, 255}
		tiers := [?][3]f32{{1.25, 1.2, 1.9}, {1.02, 2.3, 1.8}, {0.8, 3.35, 1.7}, {0.57, 4.35, 1.5}, {0.34, 5.25, 1.2}}
		for tier, k in tiers {
			cone(crown, {0, tier.y * s, 0}, tier.x * s, tier.z * s, k % 2 == 0 ? dark : shade(dark, 1.12))
		}
	case .Broadleaf, .Blossom, .Apple:
		colors := [3]Color{COLOR_LEAF, COLOR_LEAF_DARK, COLOR_LEAF_LIGHT}
		if t.species == .Blossom {
			colors = {{236, 158, 178, 255}, {222, 132, 158, 255}, {250, 192, 206, 255}}
		} else if t.species == .Apple {
			colors = {{104, 160, 74, 255}, {78, 136, 70, 255}, {140, 182, 86, 255}}
		}
		c := t.canopy
		y := t.canopy_y
		tall: f32 = t.species == .Apple ? 0.85 : 1.15 // a tall, oval crown
		ball(crown, {0, y, 0}, {c, c * tall, c}, colors[0])
		for k in 0 ..< 5 {
			a := f32(k) * math.TAU / 5 + f32(index)
			lobe := c * (0.5 + 0.08 * f32((index + k) % 3))
			ball(crown, {math.cos(a) * c * 0.6, y - c * 0.25 + c * 0.3 * f32(k % 2), math.sin(a) * c * 0.6}, {lobe, lobe * tall, lobe}, colors[1 + k % 2])
		}
		ball(crown, {c * 0.1, y + c * 0.75 * tall, -c * 0.1}, {c * 0.55, c * 0.5 * tall, c * 0.55}, colors[2])
		if t.species == .Apple {
			// Its apples, hanging round the lower half of the crown.
			set_surface(.Solid)
			set_sway(0)
			// They sit on the upper slope of the crown, where the camera sees them.
			for k in 0 ..< g.rounds[index].fruit {
				a := f32(k) * 2.4 + f32(index) + 0.5
				up := 0.45 + 0.15 * f32(k % 2)
				out := math.sqrt(1 - up * up) * c * 1.02
				ball(crown, {math.cos(a) * out, y + up * c * tall * 1.02, math.sin(a) * out}, {0.17, 0.16, 0.17}, {222, 44, 48, 255})
			}
		}
	}
	set_surface(.Solid)
}

// A berry bush: a low clump of leaves, with a few bunches of berries.
draw_bush :: proc(b: Round, index: int) {
	m := translate({b.pos.x, 0, b.pos.y}) * rot_y(f32(index) * 1.3)
	m = m * translate({math.sin(g.time * 41) * b.shake_t * 0.12, 0, 0})
	r := b.r
	set_surface(.Leaf)
	ball(m, {0, r * 0.75, 0}, {r, r * 0.8, r}, {74, 124, 66, 255})
	ball(m, {r * 0.45, r * 0.6, r * 0.2}, {r * 0.7, r * 0.6, r * 0.7}, {92, 146, 74, 255})
	ball(m, {-r * 0.4, r * 0.65, -r * 0.25}, {r * 0.72, r * 0.62, r * 0.72}, {62, 112, 64, 255})
	set_surface(.Solid)
	for k in 0 ..< b.fruit {
		a := f32(k) * 2.1 + 0.4
		bunch := m * translate({math.cos(a) * r * 0.62, r * 1.45, math.sin(a) * r * 0.62})
		for j in 0 ..< 3 {
			ball(bunch, {f32(j % 2) * 0.11 - 0.055, -f32(j / 2) * 0.09, 0}, {0.09, 0.09, 0.09}, BERRY_COLOR)
		}
	}
}

// Height of the ground alone, for placing shadows.
ground_height :: proc(pos: Vec2) -> f32 {
	h, _ := ground_at(pos)
	return h
}

draw_seesaws :: proc() {
	for &s in g.seesaws {
		base := translate({s.pivot.x, 0, s.pivot.y}) * rot_y(s.dir > 0 ? 0 : math.PI)
		width := PLANK_HALF_WIDTH * 2

		// Pivot: a wedge-shaped stand with an axle through it.
		box(base, {0, s.pivot_h / 2 - 0.04, 0}, {0.5, s.pivot_h - 0.08, width + 0.3}, COLOR_IRON)
		draw_shape(.Cylinder, base * translate({0, s.pivot_h - 0.06, -width / 2 - 0.15}) * rot_x(math.PI / 2) * scale({0.14, width + 0.3, 0.14}), COLOR_BLACK)

		// Plank, in its own tilted frame: +x runs towards Prosio's end.
		plank := base * translate({0, s.pivot_h, 0}) * rot_z(-s.angle)
		length := s.arm_a + s.arm_b
		box(plank, {(s.arm_a - s.arm_b) / 2, 0, 0}, {length, 0.14, width}, COLOR_PLANK)

		switch s.kind {
		case .Catapult:
			// Landing pad on the short end, cup on the long one.
			box(plank, {PAD_DISTANCE, 0.08, 0}, {0.6, 0.02, width - 0.3}, COLOR_STAR)
			box(plank, {-s.load_arm - 0.5, 0.22, 0}, {0.1, 0.32, width * 0.7}, COLOR_TRUNK)
			box(plank, {-s.load_arm + 0.5, 0.16, 0}, {0.1, 0.2, width * 0.7}, COLOR_TRUNK)
		case .Lever:
			// Jump mark on the far end; iron weight near the pivot.
			box(plank, {s.arm_a - 0.5, 0.08, 0}, {0.8, 0.02, width - 0.3}, COLOR_STAR)
			box(plank, {-s.load_arm, 0.62, 0}, {1.0, 1.1, 1.4}, COLOR_IRON)
			box(plank, {-s.load_arm, 1.22, 0}, {0.5, 0.14, 0.5}, shade(COLOR_IRON, 0.75))
			tube(plank, {-s.load_arm, 1.26, 0}, 0.12, 0.16, shade(COLOR_IRON, 0.75))
		}
	}

	// The boulder.
	b := g.boulder
	m := translate({b.pos.x, b.y + BOULDER_RADIUS * 0.85, b.pos.y}) * rot_z(-b.spin)
	ball(m, {0, 0, 0}, {BOULDER_RADIUS, BOULDER_RADIUS * 0.9, BOULDER_RADIUS}, COLOR_ROCK)
	ball(m, {0.15, 0.18, 0.15}, {0.2, 0.18, 0.2}, COLOR_ROCK_LIGHT)

	// The crate, or its splinters.
	c := translate({g.crate_pos.x, 0, g.crate_pos.y})
	if !g.crate_broken {
		box(c, {0, 0.6, 0}, {1.2, 1.2, 1.2}, COLOR_CRATE)
		box(c, {0, 0.6, 0}, {1.28, 0.16, 1.28}, COLOR_TRUNK)
		box(c, {0, 1.14, 0}, {1.28, 0.14, 1.28}, COLOR_TRUNK)
		box(c, {0, 0.07, 0}, {1.28, 0.14, 1.28}, COLOR_TRUNK)
	} else {
		box(c * rot_y(0.5), {0.5, 0.04, 0.2}, {0.9, 0.06, 0.25}, COLOR_CRATE)
		box(c * rot_y(-0.9), {-0.4, 0.04, 0.5}, {0.8, 0.06, 0.25}, COLOR_TRUNK)
		box(c * rot_y(2.0), {0.3, 0.04, -0.6}, {0.7, 0.06, 0.25}, COLOR_CRATE)
	}
}

// A marker on the ground showing where the boulder would land if Prosio
// jumped off the tower right now.
draw_throw_marker :: proc() {
	s := &g.seesaws[CATAPULT]
	p := &g.prosio
	if g.crate_broken || g.boulder.state != .On_Seesaw || length2(p.pos - s.pivot) > 9 {
		return
	}
	distance := predict_throw(total_kg())
	if distance <= 0 {
		return
	}
	spot := boulder_release_pos() + {-s.dir * distance, 0}
	on_target := length2(spot - g.crate_pos) < CRATE_HIT_RADIUS
	color := on_target ? Color{90, 230, 90, 210} : Color{255, 230, 80, 210}
	pulse := 0.6 + 0.08 * math.sin(g.time * 6)
	y: f32 = on_target ? 1.3 : 0.07
	tube(IDENTITY, {spot.x, y, spot.y}, pulse, 0.01, color)
	tube(IDENTITY, {spot.x, y + 0.01, spot.y}, pulse * 0.45, 0.01, {255, 255, 255, 220})
}

draw_food :: proc(f: Food, index: int) {
	if f.gone || f.respawn > 0 || !on_screen(f.pos, 1) {
		return
	}
	m := translate({f.pos.x, f.y, f.pos.y}) * rot_y(f32(index) * 2.1)
	switch f.kind {
	case .Apple:
		// Fallen apples brown a little as they start to rot.
		ripe := Color{222, 44, 48, 255}
		if f.fallen && f.life < 12 {
			ripe = {170, 88, 50, 255}
		}
		ball(m, {0, 0.12, 0}, {0.13, 0.12, 0.13}, ripe)
		tube(m, {0, 0.22, 0}, 0.012, 0.07, COLOR_TRUNK)
	case .Mushroom:
		tube(m, {}, 0.05, 0.16, {240, 228, 206, 255})
		draw_shape(.Hemisphere, m * translate({0, 0.14, 0}) * scale({0.15, 0.1, 0.15}), {196, 64, 46, 255})
		for k in 0 ..< 3 {
			a := f32(k) * 2.1
			ball(m, {math.cos(a) * 0.08, 0.21, math.sin(a) * 0.08}, {0.025, 0.012, 0.025}, COLOR_WHITE)
		}
	case .Pumpkin:
		orange := Color{232, 128, 40, 255}
		for k in 0 ..< 5 {
			a := f32(k) * math.TAU / 5
			ball(m, {math.cos(a) * 0.12, 0.22, math.sin(a) * 0.12}, {0.2, 0.2, 0.2}, k % 2 == 0 ? orange : shade(orange, 0.9))
		}
		ball(m, {0, 0.23, 0}, {0.26, 0.21, 0.26}, orange)
		tube(m, {0, 0.4, 0}, 0.035, 0.1, {96, 110, 56, 255})
		ball(m, {0.1, 0.42, 0.04}, {0.1, 0.02, 0.07}, COLOR_LEAF)
	}
}

draw_truffle :: proc(t: Truffle) {
	if !t.visible || t.taken {
		return
	}
	glow := 0.8 + math.sin(g.time * 4) * 0.15
	tube(IDENTITY, {t.pos.x, 0.06, t.pos.y}, glow, 0.01, {255, 240, 120, 90})
	m := translate({t.pos.x, 0.7 + math.sin(g.time * 2.5) * 0.12, t.pos.y}) * rot_y(g.time * 2)
	ball(m, {0, 0, 0}, {0.3, 0.27, 0.3}, COLOR_GOLD)
	ball(m, {0.2, 0.08, 0.05}, {0.17, 0.16, 0.17}, COLOR_GOLD)
	ball(m, {-0.14, 0.14, -0.1}, {0.16, 0.15, 0.16}, {255, 214, 90, 255})
	ball(m, {-0.05, -0.12, 0.17}, {0.14, 0.13, 0.14}, {240, 176, 30, 255})
	// Sparkles circling it.
	for i in 0 ..< 2 {
		a := g.time * 3 + f32(i) * math.PI
		ball(m, {math.cos(a) * 0.55, math.sin(g.time * 5 + f32(i)) * 0.2, math.sin(a) * 0.55}, {0.05, 0.05, 0.05}, COLOR_WHITE)
	}
}

// A few little stars circling a dizzy head, each its own size, height and
// pace. seed keeps them the same from frame to frame.
draw_stars :: proc(centre: Vec3, radius: f32, seed: f32) {
	count := 2 + int(hash01(seed) * 3)
	for i in 0 ..< count {
		k := seed * 7.31 + f32(i) * 3.17
		pace := lerp(3, 6, hash01(k)) * (hash01(k + 1) < 0.3 ? -1 : 1)
		a := g.time * pace + hash01(k + 2) * math.TAU
		orbit := radius * lerp(0.55, 1.1, hash01(k + 3))
		rise := (hash01(k + 4) - 0.5) * 0.18 + math.sin(g.time * lerp(4, 8, hash01(k + 5)) + k) * 0.04
		size := lerp(0.035, 0.065, hash01(k + 6))
		ball(IDENTITY, centre + {math.cos(a) * orbit, rise, math.sin(a) * orbit}, {size, size, size}, hash01(k + 7) < 0.2 ? COLOR_WHITE : COLOR_STAR)
	}
}

// A steady random number from 0 to 1 for any seed.
hash01 :: proc(n: f32) -> f32 {
	x := math.sin(n * 12.9898 + 78.233) * 43758.5453
	return x - math.floor(x)
}

// How an animal's body is placed. Standing, both halves of its body share
// one frame; held by the tail, the back and the front halves hang between
// the points of its floppy chain, and its legs dangle.
Animal_Pose :: struct {
	rear, front: Mat4,
	legs:        [2][2]Vec2, // [side][hind, front]: how far each leg turns forward (x) and outward (y)
	held:        bool, // its tail runs to Prosio's hand
	hand:        Vec3,
	dizzy:       bool,
}

// Animal models share the same metre-independent frame (+Z is the muzzle).
// A diagonal pair of feet advances together in the trot.
draw_enemy :: proc(e: Enemy) {
	if e.state == .Gone || !on_screen(e.pos, 2) {
		return
	}
	r := ENEMY_RADIUS[e.kind]
	pose := Animal_Pose{dizzy = e.state == .Dizzy || e.limp > 0 || e.ko}
	if e.state == .Held {
		pose = held_pose(e)
	} else {
		pace := e.state == .Chase ? min(length2(e.vel) / ENEMY_SPEED[e.kind], 1) : f32(0)
		stride := math.sin(e.hop) * pace
		bob := abs(stride) * 0.07
		m := translate({e.pos.x, e.y, e.pos.y}) * rot_y(e.facing) * scale({r, r, r})
		#partial switch e.state {
		case .Flying:
			m = m * translate({0, 0.9, 0}) * rot_x(e.spin) * translate({0, -0.9, 0})
		case .Dizzy:
			m = m * rot_z(0.10 * math.sin(g.time * 6))
		}
		body := m * translate({0, bob, 0})
		pose.rear, pose.front = body, body
		for si in 0 ..< 2 {
			side := f32(si * 2 - 1)
			for ei in 0 ..< 2 {
				end := f32(ei * 2 - 1)
				pose.legs[si][ei] = {side * end * stride * 0.52, 0}
			}
		}
	}
	if e.kind == .Boar {
		draw_boar(pose, e)
	} else {
		draw_fox(pose, e)
	}
	if e.state == .Dizzy || (e.state == .Held && (e.limp > 0 || e.ko)) {
		head := pose.front * [4]f32{0, 2.3, 0.6, 1}
		draw_stars(head.xyz, r * 0.75, e.home.x * 1.7 + e.home.y)
	}
}

// The frame that carries one half of a held animal's body: the model point a
// goes to the world point wa, the model direction from a to b points from wa
// to wb, and the model's side (x) lies as close to side as it can.
frame_between :: proc(a, b, wa, wb, side: Vec3, r: f32) -> Mat4 {
	mz := linalg.normalize(b - a)
	mx := Vec3{1, 0, 0} // the chain lies in the model's middle plane, so x is square to it
	my := linalg.cross(mz, mx)
	wz := linalg.normalize0(wb - wa)
	if wz == {} {
		wz = mz
	}
	wx := side - wz * linalg.dot(side, wz)
	if linalg.length(wx) < 1e-3 {
		wx = linalg.cross(Vec3{0, 1, 0}, wz)
		if linalg.length(wx) < 1e-3 {
			wx = {1, 0, 0}
		}
	}
	wx = linalg.normalize(wx)
	wy := linalg.cross(wz, wx)
	turn := IDENTITY
	for i in 0 ..< 3 {
		for j in 0 ..< 3 {
			turn[i, j] = wx[i] * mx[j] + wy[i] * my[j] + wz[i] * mz[j]
		}
	}
	return translate(wa) * turn * scale({r, r, r}) * translate(-a)
}

// The turns that point a leg, which hangs down its frame's -y at rest, along
// the world direction d.
leg_towards :: proc(frame: Mat4, d: Vec3) -> Vec2 {
	ex := linalg.normalize(Vec3{frame[0, 0], frame[1, 0], frame[2, 0]})
	ey := linalg.normalize(Vec3{frame[0, 1], frame[1, 1], frame[2, 1]})
	ez := linalg.normalize(Vec3{frame[0, 2], frame[1, 2], frame[2, 2]})
	local := Vec3{linalg.dot(d, ex), linalg.dot(d, ey), linalg.dot(d, ez)}
	forward := math.asin(clamp(-local.z, -1, 1))
	outward := math.atan2(local.x, -local.y)
	return {clamp(forward, -1.4, 1.4), clamp(outward, -0.9, 0.9)}
}

held_pose :: proc(e: Enemy) -> (pose: Animal_Pose) {
	r := ENEMY_RADIUS[e.kind]
	c := CHAIN_MODEL[e.kind]
	pose.rear = frame_between(c[1], c[0], e.chain[1], e.chain[0], e.side, r)
	pose.front = frame_between(c[1], c[2], e.chain[1], e.chain[2], e.side, r)
	pose.held = true
	pose.hand = e.chain[0]
	pose.dizzy = e.limp > 0 || e.ko
	alive := !pose.dizzy
	ground, _ := ground_at(e.chain[1].xz)
	on_feet := alive && e.chain[1].y < ground + r * c[1].y + 0.05
	for si in 0 ..< 2 {
		side := f32(si * 2 - 1)
		for ei in 0 ..< 2 {
			end := f32(ei * 2 - 1)
			if on_feet {
				// Scrabbling to get away.
				pose.legs[si][ei] = {side * end * math.sin(e.hop) * 0.6, 0}
				continue
			}
			frame := ei == 0 ? pose.rear : pose.front
			hang := leg_towards(frame, e.dangle[ei])
			// Alive, it kicks wildly in the air; limp, only a twitch.
			kick: f32 = alive ? 0.5 : 0.06
			hang.x += kick * math.sin(e.hop * 1.3 + side * 1.7 + end)
			hang.y += side * (alive ? f32(0.25) : 0.1)
			pose.legs[si][ei] = hang
		}
	}
	return
}

FOX_COAT :: Color{212, 116, 55, 255}
FOX_FEET :: Color{84, 60, 52, 255}
ANIMAL_CREAM :: Color{248, 222, 178, 255}
ANIMAL_INK :: Color{58, 47, 48, 255}

draw_fox :: proc(pose: Animal_Pose, e: Enemy) {
	coat, feet, cream, ink := FOX_COAT, FOX_FEET, ANIMAL_CREAM, ANIMAL_INK
	r := ENEMY_RADIUS[e.kind]
	for si in 0 ..< 2 {
		side := f32(si * 2 - 1)
		for ei in 0 ..< 2 {
			end := f32(ei * 2 - 1)
			turn := pose.legs[si][ei]
			frame := end < 0 ? pose.rear : pose.front
			leg := frame * translate({side * 0.34, 0.77, end * 0.59}) * rot_z(turn.y) * rot_x(turn.x)
			knee := Vec3{0, -0.35, end < 0 ? -0.10 : 0.05}
			paw := Vec3{0, -0.69, 0.04}
			taper(leg, {0, 0.05, 0}, knee, 0.2, coat)
			taper(leg, knee, paw, 0.12, feet)
			ball(leg, paw + {0, 0, 0.035}, {0.12, 0.105, 0.16}, feet)
		}
	}
	// The body in three overlapping parts, so it can bend in the middle.
	ball(pose.rear, {0, 0.97, -0.45}, {0.51, 0.53, 0.6}, coat)
	ball(pose.rear, {0, 0.98, -0.07}, {0.5, 0.52, 0.45}, coat)
	ball(pose.front, {0, 0.99, 0.27}, {0.5, 0.52, 0.56}, coat)
	limb(pose.front, {0, 1.07, 0.36}, {0, 1.47, 0.64}, 0.40, cream)
	if pose.held {
		// The bushy tail runs straight to Prosio's hoof.
		root := pose.rear * [4]f32{TAIL_ROOT[.Fox].x, TAIL_ROOT[.Fox].y, TAIL_ROOT[.Fox].z, 1}
		mid := root.xyz + (pose.hand - root.xyz) * 0.6
		limb(IDENTITY, root.xyz, pose.hand + (root.xyz - pose.hand) * 0.25, 0.305 * r, coat)
		limb(IDENTITY, mid, pose.hand, 0.2 * r, cream)
	} else {
		wag: f32 = 0.39 + 0.20 * math.sin(e.hop * 0.52)
		tail := pose.rear * translate({0, 1.04, -0.75}) * rot_y(wag)
		limb(tail, {0, 0, 0.07}, {0, 0.30, -1.12}, 0.305, coat)
		limb(tail, {0, 0.26, -0.87}, {0, 0.53, -1.43}, 0.20, cream)
	}

	h := pose.front * translate({0, 1.51, 0.65}) * scale({1.12, 1.12, 1.12}) // a big head is a cute head
	if pose.held && !pose.dizzy {
		h = h * rot_y(0.3 * math.sin(e.hop * 0.7)) // looking wildly about
	}
	ball(h, {0, 0, 0}, {0.51, 0.44, 0.47}, coat)
	ball(h, {0, -0.15, 0.31}, {0.36, 0.21, 0.35}, cream)
	ball(h, {0, -0.10, 0.58}, {0.19, 0.15, 0.22}, coat)
	ball(h, {0, -0.095, 0.76}, {0.12, 0.083, 0.078}, ink)
	for side in ([2]f32{-1, 1}) {
		ear := h * translate({side * 0.31, 0.28, -0.14}) * rot_z(-side * 0.24)
		draw_shape(.Cone, ear * scale({0.215, 0.63, 0.185}), coat)
		draw_shape(.Cone, ear * translate({0, 0.059, 0.106}) * scale({0.139, 0.44, 0.077}), ink)
		patch := h * translate({side * 0.32, -0.085, 0.265}) * rot_z(side * 0.32)
		ball(patch, {}, {0.23, 0.16, 0.18}, cream)
		draw_cute_eye(h * translate({side * 0.24, 0.07, 0.36}) * rot_y(side * 0.45), 0.13, pose.dizzy)
		ball(h, {side * 0.3, -0.12, 0.31}, {0.085, 0.045, 0.035}, ANIMAL_BLUSH)
	}
	draw_smile(h * translate({0, -0.2, 0.62}), 0.06)
}

ANIMAL_BLUSH :: Color{255, 150, 165, 255}

// A big glossy cartoon eye: a dark oval with a large and a small highlight.
// Shut tight when dizzy.
draw_cute_eye :: proc(m: Mat4, size: f32, shut: bool) {
	if shut {
		box(m, {0, 0, 0.02}, {size * 1.1, size * 0.18, size * 0.3}, ANIMAL_INK)
		return
	}
	ball(m, {}, {size * 0.85, size, size * 0.55}, ANIMAL_INK)
	ball(m, {-size * 0.28, size * 0.33, size * 0.42}, {size * 0.32, size * 0.32, size * 0.15}, COLOR_WHITE)
	ball(m, {size * 0.3, -size * 0.35, size * 0.45}, {size * 0.14, size * 0.14, size * 0.08}, COLOR_WHITE)
}

// A tiny cat-like smile: two little arcs side by side.
draw_smile :: proc(m: Mat4, size: f32) {
	for side in ([2]f32{-1, 1}) {
		arc := m * translate({side * size * 0.55, 0, 0}) * rot_z(side * 0.5)
		box(arc, {}, {size * 1.1, size * 0.3, size * 0.3}, ANIMAL_INK)
	}
}

BOAR_COAT :: Color{116, 90, 76, 255}
BOAR_DARK :: Color{70, 55, 51, 255}
BOAR_BELLY :: Color{152, 124, 102, 255}
BOAR_SNOUT :: Color{204, 152, 140, 255}
BOAR_HOOF :: Color{48, 40, 40, 255}

// The height of the boar's back along its length, for placing its bristles:
// a high hump over the shoulders, sloping down to the rump and to the neck.
boar_back :: proc(z: f32) -> f32 {
	switch {
	case z > 0.42:
		return 2.0 - (z - 0.42) * 0.9
	case z > 0:
		return lerp(1.74, 2.0, z / 0.42)
	}
	return 1.74 + z * 0.3
}

// A wild boar: a heavy front with a hump of shoulders over thin legs, small
// hindquarters, a crest of bristles, and a long snout with tusks.
draw_boar :: proc(pose: Animal_Pose, e: Enemy) {
	coat, dark, ink := BOAR_COAT, BOAR_DARK, ANIMAL_INK
	r := ENEMY_RADIUS[e.kind]
	for si in 0 ..< 2 {
		side := f32(si * 2 - 1)
		for ei in 0 ..< 2 {
			end := f32(ei * 2 - 1)
			turn := pose.legs[si][ei]
			// Thick at the body, slim down to a small cloven hoof.
			leg := (end < 0 ? pose.rear : pose.front) * translate({side * 0.4, 0.8, end * 0.6}) * rot_z(turn.y) * rot_x(turn.x)
			knee := Vec3{0, -0.36, end < 0 ? -0.09 : 0.06}
			ankle := Vec3{0, -0.67, 0.02}
			taper(leg, {0, 0.14, 0}, knee, 0.27, coat)
			ball(leg, knee, {0.165, 0.165, 0.165}, coat)
			taper(leg, knee, ankle, 0.16, dark)
			for toe in ([2]f32{-1, 1}) {
				ball(leg, ankle + {toe * 0.055, -0.045, 0.05}, {0.065, 0.07, 0.1}, BOAR_HOOF)
			}
		}
	}

	// Torso: haunches, barrel and a hump of shoulders, with a paler belly.
	ball(pose.rear, {0, 1.02, -0.55}, {0.52, 0.55, 0.62}, coat)
	ball(pose.rear, {0, 1.08, -0.15}, {0.62, 0.66, 0.6}, coat)
	ball(pose.front, {0, 1.1, 0.1}, {0.62, 0.66, 0.5}, coat)
	ball(pose.front, {0, 1.28, 0.42}, {0.64, 0.72, 0.6}, coat)
	ball(pose.rear, {0, 0.86, -0.15}, {0.46, 0.3, 0.55}, BOAR_BELLY)
	ball(pose.front, {0, 0.88, 0.2}, {0.44, 0.3, 0.45}, BOAR_BELLY)
	// A crest of stiff bristles along the spine, tallest over the shoulders.
	for i in 0 ..< 9 {
		z := 0.85 - f32(i) * 0.2
		tall := 0.34 - abs(z - 0.35) * 0.18
		tuft := (z < -0.1 ? pose.rear : pose.front) * translate({0, boar_back(z) - 0.08, z}) * rot_x(-0.55)
		cone(tuft, {}, 0.1, tall, dark)
	}
	// A thin tail ending in a tuft.
	if pose.held {
		root := pose.rear * [4]f32{TAIL_ROOT[.Boar].x, TAIL_ROOT[.Boar].y, TAIL_ROOT[.Boar].z, 1}
		limb(IDENTITY, root.xyz, pose.hand, 0.05 * r, coat)
	} else {
		limb(pose.rear, {0, 1.4, -1.07}, {0.04, 0.95, -1.3}, 0.05, coat)
		ball(pose.rear, {0.05, 0.8, -1.32}, {0.08, 0.15, 0.075}, dark)
	}

	// Head held low, with a long snout ending in a flat disc of a nose.
	h := pose.front * translate({0, 1.22, 0.98}) * rot_x(0.22) * scale({1.15, 1.15, 1.15}) // a big head is a cute head
	ball(h, {0, 0, 0}, {0.44, 0.48, 0.5}, coat)
	taper(h, {0, -0.06, 0.2}, {0, -0.18, 0.86}, 0.34, coat)
	nose := h * translate({0, -0.19, 0.84}) * rot_x(math.PI / 2)
	draw_shape(.Cylinder, nose * scale({0.2, 0.07, 0.17}), BOAR_SNOUT)
	for side in ([2]f32{-1, 1}) {
		ball(h, {side * 0.07, -0.19, 0.915}, {0.04, 0.05, 0.02}, ink)
		// Tusks curving up from the corners of the mouth.
		tusk := h * translate({side * 0.17, -0.3, 0.6}) * rot_x(-0.45) * rot_z(-side * 0.4)
		cone(tusk, {}, 0.06, 0.26, ANIMAL_CREAM)
		// Upright pointed ears, dark outside and pink inside.
		ear := h * translate({side * 0.27, 0.36, -0.12}) * rot_z(-side * 0.45) * rot_x(-0.25)
		draw_shape(.Cone, ear * scale({0.15, 0.36, 0.11}), dark)
		draw_shape(.Cone, ear * translate({0, 0.04, 0.06}) * scale({0.09, 0.24, 0.05}), BOAR_SNOUT)
		// Shaggy cheeks with a blush, big glossy eyes under a grumpy little brow.
		ball(h, {side * 0.36, -0.14, 0.12}, {0.15, 0.2, 0.16}, dark)
		ball(h, {side * 0.32, -0.1, 0.34}, {0.1, 0.055, 0.045}, ANIMAL_BLUSH)
		// A pale rim round each eye makes them stand out on the dark face.
		eye := h * translate({side * 0.21, 0.1, 0.42}) * rot_y(side * 0.45)
		if !pose.dizzy {
			ball(eye, {0, 0, -0.02}, {0.15, 0.17, 0.08}, BOAR_SNOUT)
		}
		draw_cute_eye(eye, 0.15, pose.dizzy)
		brow := h * translate({side * 0.21, 0.3, 0.43}) * rot_z(side * 0.3)
		box(brow, {}, {0.14, 0.035, 0.05}, dark)
	}
	draw_smile(h * translate({0, -0.32, 0.72}), 0.05)
}

// Prosio is short and stocky: short legs, a compact body and a big head.
LEG_SCALE :: f32(0.86) // leg length, as a share of the old, longer legs
TORSO_SCALE :: f32(0.84) // the body from hips to neck, likewise
HIP :: f32(0.47) // hip height in the body's own measurements
SHOULDER_HEIGHT :: HIP * LEG_SCALE + (1.30 - HIP) * TORSO_SCALE // above his feet

draw_prosio :: proc() {
	p := &g.prosio
	// A warm pulse marks shove immunity while keeping his pose readable.
	flashing := p.safe_t > 0 && p.fail == .None
	if flashing {
		set_hit_flash(0.10 + 0.14 * (1 + math.cos(g.time * 38)))
	}
	defer if flashing {
		set_hit_flash(0)
	}
	t := fatness(p.kg)
	r := prosio_radius(p.kg)
	wob := p.wobble

	speed := length2(p.vel)
	walking := speed > 0.5 && p.fail == .None && !p.pushups && !p.airborne
	bob: f32 = walking ? abs(math.sin(p.walk_phase)) * 0.07 : 0
	swing: f32 = walking ? math.sin(p.walk_phase) * (p.sprinting ? 1.0 : 0.7) : 0

	// The collision radius follows the belly. The jacket stays snug as he grows.
	// Eating goes to the belly: it swells forwards and sideways, while his
	// bottom stays about the same size.
	belly_out := 0.03 + 0.17 * t // how far the belly sticks out in front
	belly := (r - belly_out * 0.6) * lerp(0.8, 0.93, t)
	chest := prosio_chest(p.kg)
	hips := 0.3 + 0.1 * t
	head := f32(0.43)

	base := translate({p.pos.x, p.height, p.pos.y}) * rot_y(p.facing)
	m := base * translate({0, bob, 0})
	eyes_closed := math.mod(g.time, 3.2) < 0.12
	brow_tilt: f32 = 0 // positive is worried, negative is fierce
	if p.kg < KG_MIN + KG_DANGER || p.kg > KG_MAX - KG_DANGER || p.winded {
		brow_tilt = 0.4
	}
	switch {
	case p.fail == .Fainted:
		// Topples over onto his side.
		a := smooth(p.fail_t / 0.5)
		m = base * translate({a * 1.0, a * chest, 0}) * rot_z(a * 1.5)
		eyes_closed = true
	case p.fail == .Heart_Attack:
		// Flops onto his back, belly up.
		a := smooth(p.fail_t / 0.5)
		m = base * translate({0, a * belly * 0.8, a * 1.0}) * rot_x(-a * 1.5)
		eyes_closed = true
	case p.pushups:
		down := 0.5 - 0.5 * math.cos(p.pushup_phase * math.TAU)
		m = base * translate({0, belly + 0.28 - down * 0.25, 0}) * rot_x(1.3) * translate({0, -1.0, 0})
		brow_tilt = -0.3
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
	// Squash and stretch: taller and thinner on take-off, flatter on landing.
	st := clamp(p.stretch, -0.3, 0.3)
	m = m * scale({1 - st * 0.5, 1 + st, 1 - st * 0.5})
	root := m // the head is placed from here, so the body's squash does not reach it

	// Legs: a thick thigh tapering to a round knee, then a slimmer shin
	// tapering to a cloven hoof. The knee bends a little as he walks, and in
	// the air he tucks his legs up.
	leg_x := 0.13 + 0.13 * t
	leg_r := 0.1 + 0.06 * t
	for side in ([2]f32{-1, 1}) {
		leg_swing := p.airborne ? -0.5 + side * 0.3 : side * swing
		hip := m * translate({side * leg_x, HIP * LEG_SCALE, 0}) * rot_x(leg_swing)
		bend := 0.03 + (p.airborne ? 0.12 : 0.07 * max(-side * swing, 0))
		knee := Vec3{0, -0.23 * LEG_SCALE, bend}
		ankle := Vec3{0, -0.41 * LEG_SCALE, 0}
		taper(hip, {0, 0.06, 0}, knee, leg_r * 1.5, COLOR_SKIN)
		ball(hip, knee, {leg_r * 0.95, leg_r * 0.95, leg_r * 0.95}, COLOR_SKIN)
		taper(hip, knee, ankle, leg_r * 0.98, COLOR_SKIN)
		for toe in ([2]f32{-1, 1}) {
			ball(hip, {toe * leg_r * 0.42, -0.42 * LEG_SCALE, 0.05}, {leg_r * 0.64, 0.075, leg_r * 1.2}, COLOR_HOOF)
		}
		// The short leg of his shorts round the top of the thigh.
		taper(hip, {0, 0.1, 0}, {0, -0.08, 0.02}, leg_r * 1.8, COLOR_SHORTS)
	}
	// Everything above the hips: sat on the shorter legs, a little compacted.
	m = m * translate({0, HIP * LEG_SCALE, 0}) * scale({1, TORSO_SCALE, 1}) * translate({0, -HIP, 0})

	// Shorts over two round buttocks, with a crease between them at the back.
	// They sit high, so his legs show below them.
	ball(m, {0, 0.6, 0.05}, {hips * 0.95, 0.2, hips * 0.8}, COLOR_SHORTS)
	for side in ([2]f32{-1, 1}) {
		ball(m, {side * hips * 0.42, 0.57, -hips * 0.25}, {hips * 0.58, 0.21, hips * 0.62}, COLOR_SHORTS)
	}
	belly_y := 0.26 + 0.2 * t
	belly_mid := 0.86 + 0.04 * t // the belly hangs over the shorts, but not down to the knees
	ball(m, {0, belly_mid, belly_out}, {belly * (1 + wob), belly_y * (1 - wob), belly * (1 + wob)}, COLOR_SKIN)
	if t > 0.25 {
		ball(m, {0, belly_mid - 0.08, belly_out + belly * (1 + wob)}, {0.045, 0.045, 0.03}, COLOR_SKIN_DARK)
	}
	// Cropped jacket follows the upper arc of his belly, with a narrow sewn hem.
	jacket := m * translate({0, belly_mid + belly_y * (1 - wob) * 0.51, belly_out})
	jacket_w := max(chest, belly * (1 + wob) * 0.86 + 0.014)
	jacket_h := max(0.33, 1.46 - (belly_mid + belly_y * (1 - wob) * 0.51))
	set_surface(.Jacket)
	draw_shape(.Hemisphere, jacket * scale({jacket_w, jacket_h, jacket_w}), COLOR_SHIRT)
	set_surface(.Solid)
	draw_shape(.Cylinder, jacket * scale({jacket_w, 0.044, jacket_w}), {175, 115, 60, 255})
	// The kerchief sits just below his chin.
	ball(m, {0, 1.40, 0.03}, {chest * 0.74, 0.095, chest * 0.72}, COLOR_HEADBAND)
	knot := m * translate({chest * 0.56, 1.39, 0.11}) * rot_z(0.44)
	ball(knot, {0, -0.06, 0.035}, {0.07, 0.14, 0.055}, COLOR_HEADBAND)
	// Small canvas pack with a flap and brass clasp, visible from behind.
	pack := m * translate({0, 1.15, -max(chest * 0.78, belly * 0.64)})
	ball(pack, {}, {0.235, 0.255, 0.135}, COLOR_SHORTS)
	ball(pack, {0, 0.077, -0.069}, {0.232, 0.123, 0.093}, {89, 133, 126, 255})
	box(pack, {0, 0.031, -0.165}, {0.047, 0.065, 0.016}, COLOR_SHIRT)
	ball(m, {0, 0.72, -hips * 0.86}, {0.08, 0.08, 0.08}, COLOR_SKIN_DARK) // curly tail, above the crease
	ball(m, {0.06, 0.8, -hips * 0.9 - 0.04}, {0.05, 0.05, 0.05}, COLOR_SKIN_DARK)

	// Set the wrist and elbow outside the current belly cross section. All
	// points are in the same local frame as the wobbling torso, so squash,
	// spin, facing and the push-up tilt are applied to the whole rig together.
	arm_r := lerp(0.1, 0.135, t)
	belly_width := belly * (1 + wob)
	belly_height := belly_y * (1 - wob)
	for side in ([2]f32{-1, 1}) {
		shoulder := Vec3{side * (chest * 0.86), 1.30, 0.035}
		rest_x := side * (chest + arm_r * 0.85)
		elbow := Vec3{rest_x, 1.09, 0.04 - side * swing * 0.18}
		hand := Vec3{rest_x, 0.86 + 0.075 * abs(swing), 0.16 - side * swing * 0.35}
		switch {
		case p.carry == .Enemy && side == HOLD_SIDE:
			// One hoof on the tail, wherever it is: the hold point is turned
			// into his own frame and kept within arm's reach.
			local := direction_to_prosio(p.hand - {p.pos.x, p.height, p.pos.y})
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
		case p.pushups:
			// Place the palm on the ground under the forward-tilted shoulder.
			down := 0.5 - 0.5 * math.cos(p.pushup_phase * math.TAU)
			hand.z = (belly + 0.28 - down * 0.25 + math.cos(f32(1.3)) * (hand.y - 1) - 0.08) / math.sin(f32(1.3))
			elbow.z = hand.z * 0.48
			elbow.x = side * (chest + 0.13 + 0.1 * down)
		case p.airborne:
			elbow = {side * (chest + 0.23), 1.36, 0.07}
			hand = {side * (chest + 0.32), 1.62, 0.18}
		case p.eat_t > 0:
			hand = {side * 0.24, 1.55, 0.48}
			elbow.z = 0.32
		case p.dash_t > 0:
			hand.y, hand.z = 1.02, -0.31
			elbow.z = -0.23
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
		// Chubby arms: a plump upper arm with a round biceps, narrowing to
		// the elbow, then a forearm narrowing to the hoof. A short sleeve
		// covers the top of the arm.
		taper(m, shoulder, elbow, arm_r * 1.75, COLOR_SKIN)
		ball(m, shoulder + (elbow - shoulder) * 0.45, {arm_r * 1.45, arm_r * 1.45, arm_r * 1.45}, COLOR_SKIN)
		ball(m, elbow, {arm_r * 1.05, arm_r * 1.05, arm_r * 1.05}, COLOR_SKIN)
		taper(m, elbow, hand, arm_r * 1.12, COLOR_SKIN)
		sleeve_end := shoulder + (elbow - shoulder) * 0.4
		ball(m, shoulder, {arm_r * 1.8, arm_r * 1.8, arm_r * 1.8}, COLOR_SHIRT)
		taper(m, shoulder, sleeve_end, arm_r * 1.95, COLOR_SHIRT)
		ball(m, hand, {arm_r * 1.1, 0.1, arm_r * 1.15}, COLOR_HOOF)
	}

	// Head: cheeks get rounder too.
	munch: f32 = p.eat_t > 0 ? math.sin(p.eat_t * 40) * 0.05 : 0
	cheeks := head * (1 + 0.2 * t)
	h := root * translate({0, HIP * LEG_SCALE + (1.72 - HIP) * TORSO_SCALE + munch, 0.04}) * rot_x(-0.16)
	if p.pushups {
		h = h * rot_x(-0.9) // look ahead, not at the grass
	}
	ball(h, {0, 0, 0}, {cheeks, head * 0.95, head}, COLOR_SKIN)
	// A vermilion head cloth, with a knot and two loose ends behind one ear.
	// A swept forelock gives his head an asymmetric outline in profile.
	lock := h * translate({-0.075, 0.34, -0.028}) * rot_z(0.64)
	ball(lock, {}, {0.098, 0.143, 0.12}, {165, 104, 82, 255})
	limb(lock, {0, 0.006, 0}, {-0.065, 0.152, -0.039}, 0.047, {165, 104, 82, 255})
	band := h * rot_z(-0.075)
	ball(band, {0, 0.195, -0.01}, {cheeks * 0.94, 0.145, head * 0.97}, COLOR_HEADBAND)
	ball(band, {0.34, 0.19, -0.23}, {0.087, 0.069, 0.083}, COLOR_HEADBAND)
	flutter := 0.036 * math.sin(g.time * 4.0) + 0.035 * swing
	limb(band, {0.35, 0.18, -0.24}, {0.48, 0.06 + flutter, -0.4}, 0.055, COLOR_HEADBAND)
	limb(band, {0.35, 0.18, -0.24}, {0.32, -0.04 - flutter, -0.43}, 0.049, COLOR_HEADBAND)
	for side in ([2]f32{-1, 1}) {
		ear := h * translate({side * cheeks * 0.66, 0.27, -0.02}) * rot_z(-side * 0.6)
		draw_shape(.Cone, ear * scale({0.157, 0.28, 0.109}), COLOR_SKIN)
		draw_shape(.Cone, ear * translate({0, 0.025, 0.068}) * scale({0.104, 0.18, 0.054}), COLOR_SKIN_DARK)
		if eyes_closed {
			box(h, {side * 0.16, 0.06, 0.37}, {0.14, 0.03, 0.03}, COLOR_BLACK)
		} else {
			ball(h, {side * 0.17, 0.074, 0.365}, {0.09, 0.103, 0.069}, COLOR_WHITE)
			ball(h, {side * 0.17, 0.076, 0.413}, {0.055, 0.080, 0.040}, COLOR_BLACK)
			ball(h, {side * 0.17 - 0.014, 0.107, 0.448}, {0.02, 0.02, 0.012}, COLOR_WHITE)
		}
		// Eyebrows show how he feels.
		brow := h * translate({side * 0.16, 0.2, 0.35}) * rot_z(side * brow_tilt)
		box(brow, {0, 0, 0}, {0.12, 0.025, 0.03}, COLOR_HOOF)
		cheek := h * translate({side * cheeks * 0.67, -0.077, 0.293}) * rot_y(side * 0.68)
		ball(cheek, {}, {0.088, 0.047, 0.034}, COLOR_BLUSH)
		ball(h, {side * 0.067, -0.077, 0.532}, {0.027, 0.037, 0.018}, COLOR_NOSTRIL)
	}
	ball(h, {0, -0.09, 0.404}, {0.182, 0.122, 0.141}, COLOR_SKIN_DARK)
	if p.eat_t > 0 || p.airborne {
		ball(h, {0, -0.23, 0.33}, {0.06, 0.05, 0.03}, COLOR_NOSTRIL) // open mouth
	}
	if p.strain > 0.5 || p.heave_t > 0 {
		ball(h, {0, -0.22, 0.34}, {0.09, 0.025, 0.03}, COLOR_WHITE) // gritted teeth
	}

	head_top := Vec3{p.pos.x, p.height + 2.2, p.pos.y}
	if p.dazed_t > 0 {
		draw_stars(head_top, 0.45, 3.3)
	}
	if p.fail == .Fainted && p.fail_t > 0.4 {
		draw_stars({p.pos.x, p.height + 1.3, p.pos.y}, 0.6, 5.1)
	}
	if p.fail == .Heart_Attack && p.fail_t > 0.4 {
		// A thumping cartoon heart above him.
		beat := 1 + 0.25 * abs(math.sin(g.time * 7))
		hm := translate({p.pos.x, p.height + 2.3, p.pos.y}) * scale({beat, beat, beat})
		ball(hm, {-0.13, 0.08, 0}, {0.17, 0.17, 0.12}, COLOR_HEART)
		ball(hm, {0.13, 0.08, 0}, {0.17, 0.17, 0.12}, COLOR_HEART)
		draw_shape(.Cone, hm * translate({0, 0.08, 0}) * rot_z(math.PI) * scale({0.29, 0.36, 0.12}), COLOR_HEART)
	}
}

draw_particles :: proc() {
	outlines_enabled = false
	for p in g.particles {
		if p.life <= 0 {
			continue
		}
		s := p.size * (0.3 + 0.7 * p.life / p.max_life)
		ball(IDENTITY, p.pos, {s, s, s}, p.color)
	}
	outlines_enabled = true
}
