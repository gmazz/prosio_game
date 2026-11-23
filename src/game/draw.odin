package game

import "core:math"
import "core:math/linalg"

// Everything is drawn from a handful of simple shapes placed with matrices.

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

// The ground: grass, forest floor, paths and fields (all painted by the
// shader), with tufts and flowers. Shadows are laid over it next.
draw_ground :: proc() {
	w := WORLD_HALF
	outlines_enabled = false
	box(IDENTITY, {0, -0.56, 0}, {w.x * 2 + 40, 1, w.y * 2 + 40}, COLOR_OUTSIDE)
	set_surface(.Meadow)
	draw_shape(.Terrain, translate({0, 0.01, 0}) * scale({w.x, 1, w.y}), COLOR_WHITE)
	set_surface(.Solid)
	// (Grass, ferns and bushes are drawn with the leaf surface, swaying, set
	// once for them all; flowers are drawn after.)
	set_surface(.Leaf)
	set_sway(0.05)
	for d in g.decor[:g.decor_count] {
		if d.kind == .Flower || !on_screen(d.pos) {
			continue
		}
		m := translate({d.pos.x, 0, d.pos.y}) * rot_y(f32(d.variant) * 1.7)
		draw_plant(d, m)
	}
	set_sway(0)
	set_surface(.Solid)
	for d in g.decor[:g.decor_count] {
		if d.kind != .Flower || !on_screen(d.pos) {
			continue
		}
		m := translate({d.pos.x, 0, d.pos.y}) * rot_y(f32(d.variant) * 1.7)
		#partial switch d.kind {
		case .Flower:
			tube(m, {0, 0, 0}, 0.02, 0.26, COLOR_TUFT)
			ball(m, {0, 0.28, 0}, {0.1, 0.06, 0.1}, FLOWER_COLORS[d.variant % len(FLOWER_COLORS)])
			ball(m, {0, 0.31, 0}, {0.04, 0.04, 0.04}, COLOR_STAR)
		}
	}
	draw_fish()
	// Lily pads float on the pond, bobbing a little.
	if on_screen(POND, POND_RADIUS) {
		for k in 0 ..< 7 {
			a := f32(k) * 2.4 + 0.5
			d := POND_RADIUS * (0.25 + 0.09 * f32(k % 5))
			bob := 0.012 * math.sin(g.time * 1.4 + f32(k))
			pad := translate({POND.x + math.cos(a) * d, 0.03 + bob, POND.y + math.sin(a) * d}) * rot_y(f32(k) * 1.3)
			tube(pad, {}, 0.3 + 0.06 * f32(k % 3), 0.02, {84, 150, 84, 255})
			if k % 3 == 0 {
				ball(pad, {0.05, 0.07, 0}, {0.1, 0.07, 0.1}, {250, 214, 226, 255})
				ball(pad, {0.05, 0.11, 0}, {0.04, 0.04, 0.04}, COLOR_STAR)
			}
		}
	}
	outlines_enabled = true
}

// The trees, rocks and bushes. (Round the meadow there is no fence: it
// fades into fog, see scene.frag.)
draw_world :: proc() {
	// Trees, rocks, bushes. Trees further off still cast shadows into view.
	for r, i in g.rounds[:g.round_count] {
		if r.r <= 0 || !on_screen(r.pos, r.kind == .Tree ? 6 : 2) {
			continue // carried, in flight or far away
		}
		switch r.kind {
		case .Tree:
			draw_tree(r.pos, i)
		case .Bush:
			draw_bush(r, i)
		case .Rock:
			draw_rock(translate({r.pos.x, r.r * 0.5, r.pos.y}), r.r, i)
		case .Hive:
			draw_hive(r, i)
		case .Salt_Rock:
			draw_salt_rock(r, i)
		case .Pebbles:
			// As many little stones as there are to take, on a bare patch.
			set_surface(.Stone)
			for k in 0 ..< r.fruit {
				a := f32(k) * 2.4 + f32(i)
				d := r.r * (0.25 + 0.6 * f32(k % 3) / 2)
				size := 0.07 + 0.02 * f32((k + i) % 3)
				ball(translate({r.pos.x + math.cos(a) * d, size * 0.6, r.pos.y + math.sin(a) * d}), {}, {size * 1.2, size * 0.8, size}, k % 2 == 0 ? COLOR_ROCK : COLOR_ROCK_LIGHT)
			}
			set_surface(.Solid)
		case .Scarecrow:
			draw_scarecrow(translate({r.pos.x, 0, r.pos.y}) * rot_y(0.3 * math.sin(f32(i) * 1.7)))
		case .Larder:
			if r.r > 0 {
				draw_larder(translate({r.pos.x, 0, r.pos.y}))
			}
		case .Stump:
			draw_stump(r, i)
		case .Oven, .Mill, .Fire, .Churn, .Block, .Bench:
		// Drawn by draw_oven, draw_mill, draw_fire, draw_churn and draw_bench.
		}
	}

	// Bulrushes in clumps round the pond's edge, leaving the side towards
	// home open.
	if on_screen(POND, POND_RADIUS + 3) {
		for k in 0 ..< 9 {
			a := 2.2 + f32(k) * 0.52
			at := POND + Vec2{math.cos(a), math.sin(a)} * (POND_RADIUS - 0.15 + 0.2 * f32(k % 2))
			m := translate({at.x, 0, at.y}) * rot_y(f32(k) * 1.9)
			set_sway(0.06)
			for j in 0 ..< 4 {
				lean := Vec3{0.1 * f32(j) - 0.15, 0, 0.07 * f32(j % 2)}
				tall := 0.75 + 0.18 * f32((k + j) % 3)
				limb(m, lean, lean * 1.5 + {0, tall, 0}, 0.02, {104, 150, 72, 255})
				if j % 2 == 0 {
					ball(m, lean * 1.5 + {0, tall, 0}, {0.045, 0.13, 0.045}, {110, 72, 48, 255})
				}
			}
			set_sway(0)
		}
	}

}

// The size of one tree, worked out from its number so it never changes.
Tree_Shape :: struct {
	species:  Tree_Species,
	size:     f32,
	canopy:   f32, // radius of the crown
	canopy_y: f32, // height of the crown's centre
	// Drawn from a model (see trees.odin): which, where its leaves start and
	// end, and how it is scaled.
	model:    Tree_Model_Kind,
	low, high: f32,
	scale:    Vec3,
}

// Trees are tall and slim, so that standing close together they make a
// little wood rather than a row of lollipops.
tree_shape :: proc(index: int) -> Tree_Shape {
	return tree_shape_of(g.rounds[index].species, index)
}

// The shape a tree of this species would have as tree number index.
tree_shape_of :: proc(species: Tree_Species, index: int) -> Tree_Shape {
	size := 0.85 + 0.4 * math.mod(f32(index) * 0.37, 1)
	when PACKED_TREES {
		return packed_tree_shape(species, index, size)
	}
	switch species {
	case .Pine:
		return {species = species, size = size, canopy = 1.25 * size, canopy_y = 3.2 * size}
	case .Apple:
		size *= 0.85 // apple trees are smaller, with a low, round crown
		return {species = species, size = size, canopy = 1.55 * size, canopy_y = 3.7 * size}
	case .Broadleaf, .Blossom:
	}
	return {species = species, size = size, canopy = 1.4 * size, canopy_y = 4.7 * size}
}

// How high a tree's leaves start and how high they reach.
foliage :: proc(t: Tree_Shape) -> (low, high: f32) {
	when PACKED_TREES {
		return t.low, t.high
	}
	switch t.species {
	case .Pine:
		return 1.2 * t.size, 6.45 * t.size
	case .Apple:
		return t.canopy_y - t.canopy * 0.85, t.canopy_y + t.canopy * 1.2
	case .Broadleaf, .Blossom:
	}
	return t.canopy_y - t.canopy * 1.15, t.canopy_y + t.canopy * 1.45
}

// A tree standing between the camera and Prosio fades to a see-through
// pattern where it covers him, so he never disappears behind it.
tree_fade :: proc(pos: Vec2, t: Tree_Shape) -> f32 {
	p := &g.prosio
	if pos.y < p.pos.y - 0.5 {
		return 0 // behind him
	}
	// How far he is, on the screen, from the middle of its leaves: 1 at
	// their edge.
	low, high := foliage(t)
	middle := Vec3{pos.x, (low + high) / 2, pos.y}
	crown := world_to_screen(middle)
	wide := abs(world_to_screen(middle + {t.canopy, 0, 0}).x - crown.x)
	tall := abs(world_to_screen({pos.x, high, pos.y}).y - crown.y)
	him := world_to_screen({p.pos.x, p.height + PROSIO_SIZE, p.pos.y})
	apart := length2((crown - him) / Vec2{max(wide, 1), max(tall, 1)})
	// In the forest it clears a wider space round him, so that he sees the
	// ground he is walking on, and what lies there, through the trees.
	reveal: f32 = inside_region(p.pos, .Forest) > 0 ? FOREST_REVEAL : 0
	cover := 1 - smooth((apart - 0.8 - reveal) / 0.5)
	// The leftover leaves show as single pixels, so it fades a long way.
	strength: f32 = 0.86
	return strength * cover * smooth((pos.y - p.pos.y + 0.5) / 1.0)
}

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
	when PACKED_TREES {
		draw_packed_tree(pos, index, t)
		return
	}
	m := translate({pos.x, 0, pos.y}) * rot_y(f32(index) * 2.39)
	// A shaken tree trembles for a moment.
	shake := g.rounds[index].shake_t * g.rounds[index].shake_power
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
				ripe := g.rounds[index].ripe
				big := lerp(0.09, 0.17, ripe)
				ball(crown, {math.cos(a) * out, y + up * c * tall * 1.02, math.sin(a) * out}, {big, big * 0.95, big}, blend(UNRIPE_GREEN, APPLE_RED, ripe * 1.2 - 0.2))
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
		big := lerp(0.05, 0.09, b.ripe)
		for j in 0 ..< 3 {
			ball(bunch, {f32(j % 2) * 0.11 - 0.055, -f32(j / 2) * 0.09, 0}, {big, big, big}, blend({170, 196, 120, 255}, BERRY_COLOR, b.ripe * 1.2 - 0.2))
		}
	}
}

// A colour part of the way from one to another.
blend :: proc(a, b: Color, t: f32) -> Color {
	k := clamp(t, 0, 1)
	return {u8(lerp(f32(a.r), f32(b.r), k)), u8(lerp(f32(a.g), f32(b.g), k)), u8(lerp(f32(a.b), f32(b.b), k)), 255}
}

// Food shows how far along it is: it sprouts small and green, and grows and
// colours as it ripens. Each piece is also a little bigger or smaller than
// the next.
draw_food :: proc(f: Food, index: int) {
	if f.gone || !on_screen(f.pos, 1) {
		return
	}
	if f.respawn > 0 {
		return
	}
	grown := lerp(0.4, 1, f.grow) * math.pow(f.size, 0.4)
	m := translate({f.pos.x, f.y, f.pos.y}) * rot_y(f32(index) * 2.1) * scale({grown, grown, grown})
	switch f.kind {
	case .Apple:
		// Fallen apples brown a little as they start to rot.
		ripe := blend(UNRIPE_GREEN, APPLE_RED, f.grow * 1.2 - 0.2)
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
		orange := blend({118, 150, 70, 255}, {232, 128, 40, 255}, f.grow * 1.3 - 0.3)
		for k in 0 ..< 5 {
			a := f32(k) * math.TAU / 5
			ball(m, {math.cos(a) * 0.12, 0.22, math.sin(a) * 0.12}, {0.2, 0.2, 0.2}, k % 2 == 0 ? orange : shade(orange, 0.9))
		}
		ball(m, {0, 0.23, 0}, {0.26, 0.21, 0.26}, orange)
		tube(m, {0, 0.4, 0}, 0.035, 0.1, {96, 110, 56, 255})
		ball(m, {0.1, 0.42, 0.04}, {0.1, 0.02, 0.07}, COLOR_LEAF)
	case .Wheat:
		// A little sheaf: stalks bound at the middle, heavy ears on top.
		set_sway(0.05)
		for k in 0 ..< 7 {
			a := f32(k) * 0.9
			spread := 0.08 + 0.03 * f32(k % 3)
			base := Vec3{math.cos(a) * spread, 0, math.sin(a) * spread}
			top := Vec3{math.cos(a) * spread * 1.9, 0.6 + 0.07 * f32(k % 2), math.sin(a) * spread * 1.9}
			gold := blend({124, 170, 78, 255}, WHEAT, f.grow * 1.3 - 0.3)
			limb(m, base, top, 0.018, shade(gold, 0.85))
			ball(m, top + {0, 0.07, 0}, {0.04, 0.1, 0.04}, k % 2 == 0 ? gold : shade(gold, 0.9))
		}
		set_sway(0)
		tube(m, {0, 0.24, 0}, 0.1, 0.06, COLOR_TRUNK)
	case .Egg:
		ball(m, {0, 0.13, 0}, {0.085, 0.11, 0.085}, {246, 236, 214, 255})
		ball(m, {0.03, 0.17, 0.05}, {0.015, 0.015, 0.015}, {176, 136, 104, 255})
	case .Cabbage:
		// A pale heart wrapped in darker outer leaves.
		heart := blend({96, 150, 70, 255}, {176, 216, 124, 255}, f.grow)
		for k in 0 ..< 5 {
			a := f32(k) * math.TAU / 5
			leaf := m * translate({math.cos(a) * 0.17, 0.1, math.sin(a) * 0.17}) * rot_y(-a) * rot_z(0.5)
			ball(leaf, {}, {0.09, 0.17, 0.15}, k % 2 == 0 ? COLOR_LEAF : COLOR_LEAF_DARK)
		}
		ball(m, {0, 0.17, 0}, {0.2, 0.17, 0.2}, heart)
		ball(m, {0.03, 0.27, 0.02}, {0.11, 0.07, 0.11}, shade(heart, 1.08))
	case .Nuts:
		// A little heap: more nuts lie on it as time goes by.
		m = translate({f.pos.x, f.y, f.pos.y}) * rot_y(f32(index) * 2.1)
		for k in 0 ..< 1 + int(f.grow * 4.99) {
			a := f32(k) * 2.4
			d: f32 = k == 0 ? 0 : 0.1
			nut := m * translate({math.cos(a) * d, 0.055, math.sin(a) * d}) * rot_y(a)
			ball(nut, {}, {0.055, 0.05, 0.065}, k % 2 == 0 ? Color{168, 118, 74, 255} : Color{142, 98, 62, 255})
			box(nut, {0, 0.045, 0}, {0.012, 0.012, 0.09}, {112, 76, 50, 255})
		}
	case .Wood:
		// A fallen branch, broken in three: pale where it snapped, so that
		// it shows on the dark forest floor, with a sprig of leaves still on.
		for k in 0 ..< 3 {
			a := f32(k) * 1.1 - 0.5
			from := Vec3{math.cos(a) * -0.42, 0.07 + 0.05 * f32(k % 2), math.sin(a) * -0.42 + 0.1 * f32(k - 1)}
			to := Vec3{math.cos(a) * 0.42, 0.08 + 0.05 * f32(k % 2), math.sin(a) * 0.42 + 0.1 * f32(k - 1)}
			limb(m, from, to, 0.065, k == 1 ? PLANK_DARK : shade(PLANK_DARK, 0.88))
			ball(m, from, {0.06, 0.06, 0.06}, COLOR_PLANK)
			ball(m, to, {0.06, 0.06, 0.06}, COLOR_PLANK)
		}
		limb(m, {0.1, 0.12, 0.05}, {0.3, 0.34, 0.24}, 0.02, PLANK_DARK)
		ball(m, {0.32, 0.36, 0.26}, {0.09, 0.04, 0.07}, COLOR_LEAF_LIGHT)
		ball(m, {0.22, 0.3, 0.3}, {0.07, 0.03, 0.06}, COLOR_LEAF)
	case .Spear:
		// Stuck in the ground where it came down, leaning.
		lean := Vec3{0.3, 0.95, 0.1} * SPEAR_LEN
		at := Vec3{f.pos.x, 0, f.pos.y}
		draw_spear(at + lean, at - lean * 0.05)
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
// one frame; held by a leg, the back and the front halves hang between
// the points of its floppy chain, and its legs dangle.
Animal_Pose :: struct {
	rear, front: Mat4,
	legs:        [2][2]Vec2, // [side][hind, front]: how far each leg turns forward (x) and outward (y)
	held:        bool, // a leg runs to Prosio's hand
	hand:        Vec3,
	dizzy:       bool,
	dead:        bool, // crosses for eyes
}

// Carry the same body frame across flight, floor contact and standing up.
impact_pose :: proc(e: Enemy) -> Animal_Pose {
	r := ENEMY_RADIUS[e.kind]
	i := e.impact
	pivot := Vec3{0, e.kind == .Turkey ? IMPACT_TURKEY_PIVOT : IMPACT_QUAD_PIVOT, 0}
	m := translate({e.pos.x, e.y, e.pos.y}) * rot_y(e.facing) * scale({r, r, r}) *
	     translate(pivot) * linalg.matrix4_from_quaternion(i.rotation) * translate(-pivot)
	pose := Animal_Pose{rear = m, front = m, dizzy = i.kind >= .Fall, dead = e.state == .Dead}
	for si in 0..<2 {
		side := f32(si * 2 - 1)
		stride := side * math.sin(e.hop) * min(length2(e.vel) / IMPACT_FALL_SPEED, 1) * (1 - smooth(clamp(i.age / i.duration, 0, 1)))
		if i.phase != .Brace {
			stride = 0
		}
		pose.legs[si] = {
			{stride * IMPACT_STEP_ANGLE + i.bend * IMPACT_HIND_TUCK, -side * i.bend * IMPACT_LEG_SPLAY},
			{-stride * IMPACT_STEP_ANGLE + i.bend * IMPACT_FRONT_TUCK, -side * i.bend * IMPACT_LEG_SPLAY},
		}
	}
	if _, packed := quad_model_for(e.kind); !packed {
		// Procedural models have no mesh skin to query. Use body and limb bounds.
		low := impact_shape_low(pose, e.kind)
		lift := impact_ground_lift(e, low)
		pose.rear[1, 3] += lift
		pose.front[1, 3] += lift
	}
	return pose
}

impact_shape_low :: proc(pose: Animal_Pose, kind: Enemy_Kind) -> f32 {
	m := pose.rear
	if kind != .Turkey {
		return min(impact_part_low(m, {0, 1, 0}, {0.51, 1, 1.32}),
		           impact_part_low(m, {0, 1.55, 1}, {0.45, 0.47, 0.48}))
	}
	low := min(impact_part_low(m, {0, 1.22, -0.25}, {0.7, 0.6, 0.72}),
	           impact_part_low(m, {0, 1.2, 0.18}, {0.62, 0.64, 0.6}),
	           impact_part_low(m, {0, 1.92, 0.83}, {0.29, 0.31, 0.54}))
	fan := m * translate({0, 1.3, -0.62}) * rot_x(-1)
	for side, si in ([2]f32{-1, 1}) {
		turn := pose.legs[si][0]
		leg := m * translate({side * 0.22, 0.86, -0.06}) * rot_z(turn.y) * rot_x(turn.x)
		low = min(low, impact_part_low(leg, {0, -0.84, 0.075}, {0.165, 0.04, 0.22}),
		          impact_part_low(fan * rot_z(side * 0.55), {0, 0.5, 0}, {0.14, 0.5, 0.05}))
	}
	return min(low, impact_part_low(fan, {0, 0.5, 0}, {0.14, 0.5, 0.05}))
}

impact_part_low :: proc(m: Mat4, center, radii: Vec3) -> f32 {
	up := Vec3{m[1, 0], m[1, 1], m[1, 2]}
	return m[1, 3] + linalg.dot(up, center) - linalg.length(up * radii)
}

// Animal models share the same metre-independent frame (+Z is the muzzle).
// A diagonal pair of feet advances together in the trot.
draw_enemy :: proc(e: Enemy) {
	if e.state == .Gone || !on_screen(e.pos, 2) {
		return
	}
	r := ENEMY_RADIUS[e.kind]
	pose := Animal_Pose{dizzy = e.state == .Dizzy || e.limp > 0 || e.ko}
	if e.impact.kind != .None {
		pose = impact_pose(e)
	} else if e.state == .Held {
		pose = held_pose(e)
	} else if e.state == .Dead {
		pose.dead = true
		// Flat out on its side, legs anyhow.
		m := translate({e.pos.x, 0, e.pos.y}) * rot_y(e.facing) * scale({r, r, r})
		body := m * translate({0.75, 0.5, 0}) * rot_z(-1.42)
		pose.rear, pose.front = body, body * rot_y(0.25)
		pose.legs = {{{0.5, 0.1}, {-0.4, 0.15}}, {{0.15, 0.5}, {-0.1, 0.6}}}
	} else if e.state == .Swimming && e.ko {
		// Bottoms up: on its back in the water, feet in the air.
		pose.dead = true
		bob := 0.03 * math.sin(g.time * 2.5 + e.pos.x)
		m := translate({e.pos.x, 0.12 + bob - sunk(e), e.pos.y}) * rot_y(e.facing + g.time * 0.3) * scale({r, r, r}) * rot_z(math.PI) * translate({0, -0.55, 0})
		pose.rear, pose.front = m, m
	} else {
		pace := e.state == .Chase ? min(length2(e.vel) / ENEMY_SPEED[e.kind], 1) : f32(0)
		if e.state == .Swimming {
			pace = 1 // paddling for all it is worth
		}
		stride := math.sin(e.hop) * pace
		bob: f32
		if !quad_legged(e.kind) {
			bob = abs(stride) * 0.07 // packed clips already move the body
		}
		lift := e.y
		if e.state == .Swimming {
			lift = -SWIM_SINK[e.kind] + 0.04 * math.sin(g.time * 5 + e.pos.y) // low in the water, bobbing
		}
		m := translate({e.pos.x, lift, e.pos.y}) * rot_y(e.facing) * scale({r, r, r})
		#partial switch e.state {
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
	if head, drawn := draw_quad_enemy(pose, e); drawn {
		draw_enemy_marks(e, head)
		return
	}
	switch e.kind {
	case .Turkey:
		draw_turkey(pose, e)
	case .Goat, .Billy:
		draw_goat(pose, e)
	case .Fox:
		when FOX_PROCEDURAL {
			draw_fox(pose, e)
		} else {
			draw_workshop_fox(pose, e)
		}
	}
	draw_enemy_marks(e, (pose.front * [4]f32{0, 2.3, 0.6, 1}).xyz)
}

// Stars over a dizzy animal's head, and a bar of its health when it is hurt.
draw_enemy_marks :: proc(e: Enemy, head: Vec3) {
	r := ENEMY_RADIUS[e.kind]
	if !e.ko && (e.state == .Dizzy || (e.state == .Held && e.limp > 0)) {
		draw_stars(head, r * 0.75, e.home.x * 1.7 + e.home.y)
	}
	// A hurt animal shows how much health it has left, in a little bar over it.
	if !e.ko && e.health < ENEMY_HEALTH - 0.5 && !drawing_shadows() {
		at := e.state == .Held ? e.chain[1] : Vec3{e.pos.x, e.y, e.pos.y}
		m := translate(at + {0, r * 2.2 + 0.75, 0})
		share := e.health / ENEMY_HEALTH
		box(m, {}, {HEALTH_BAR + 0.06, 0.14, 0.03}, UI_DARK)
		box(m, {-HEALTH_BAR * (1 - share) / 2, 0, 0.02}, {HEALTH_BAR * share, 0.08, 0.03}, share > 0.5 ? HEALTH_GOOD : (share > 0.25 ? UI_ORANGE : UI_RED))
	}
}

HEALTH_BAR :: f32(0.9) // metres wide

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
	pose.dead = e.ko
	alive := !pose.dizzy
	on_feet := alive && !held_up(e.kind) && e.chain[1].y < r * c[1].y + 0.05
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

// A big, cross farm turkey: a round bronze body on two pink legs, a fan of
// barred tail feathers it spreads when it means trouble, and a bare blue head
// with a red wattle. Held, it hangs from Prosio's hand by its feet.
draw_turkey :: proc(pose: Animal_Pose, e: Enemy) {
	r := ENEMY_RADIUS[e.kind]
	cross := e.state == .Chase
	charging := cross && e.hunt == .Charge
	// Its wings beat madly when it is held up or charges, and droop when it
	// is limp.
	wing: f32 = 0.12
	switch {
	case pose.dizzy:
		wing = pose.held ? 0.9 : 0.35
	case pose.held:
		wing = 0.9 + 0.8 * math.sin(e.hop * 2.4)
	case charging:
		wing = 0.6 + 0.4 * math.sin(e.hop * 2)
	}

	// Legs: feathered thighs, then thin pink shanks and toes.
	if pose.held {
		for side in ([2]f32{-1, 1}) {
			ball(pose.rear, {side * 0.22, 0.86, -0.08}, {0.2, 0.26, 0.22}, TURKEY_DARK)
			hip := pose.rear * [4]f32{side * 0.18, 0.72, -0.08, 1}
			limb(IDENTITY, hip.xyz, pose.hand, 0.065 * r, TURKEY_LEG)
		}
	} else {
		for si in 0 ..< 2 {
			side := f32(si * 2 - 1)
			turn := pose.legs[si][0]
			leg := pose.rear * translate({side * 0.22, 0.86, -0.06}) * rot_z(turn.y) * rot_x(turn.x)
			ball(leg, {}, {0.2, 0.26, 0.22}, TURKEY_DARK)
			foot := Vec3{0, -0.83, 0.04}
			limb(leg, {0, -0.12, 0}, foot, 0.06, TURKEY_LEG)
			for toe in ([3]f32{-1, 0, 1}) {
				limb(leg, foot, foot + {toe * 0.13, -0.02, 0.22}, 0.035, TURKEY_LEG)
			}
			limb(leg, foot, foot + {0, -0.02, -0.15}, 0.035, TURKEY_LEG)
		}
	}

	// The tail fan: barred feathers with pale tips, spread wide when cross,
	// folded when held or knocked about.
	spread: f32 = cross ? 1.25 : 0.55
	if pose.held || pose.dizzy {
		spread = 0.3
	}
	fan := pose.rear * translate({0, 1.3, -0.62}) * rot_x(cross ? -0.25 : -1.0)
	for k in 0 ..< 9 {
		a := (f32(k) / 8 - 0.5) * 2 * spread
		feather := fan * rot_z(a)
		ball(feather, {0, 0.5, 0}, {0.14, 0.5, 0.05}, k % 2 == 0 ? TURKEY_BRONZE : TURKEY_RUST)
		ball(feather, {0, 0.72, 0.01}, {0.12, 0.08, 0.05}, TURKEY_DARK)
		ball(feather, {0, 0.88, 0.01}, {0.12, 0.1, 0.05}, TURKEY_TIP)
	}

	// The body: a plump back and a puffed-out breast.
	ball(pose.rear, {0, 1.22, -0.25}, {0.7, 0.6, 0.72}, TURKEY_BRONZE)
	ball(pose.front, {0, 1.2, 0.18}, {0.62, 0.64, 0.6}, TURKEY_BRONZE)
	ball(pose.front, {0, 1.08, 0.4}, {0.42, 0.42, 0.34}, TURKEY_DARK)
	// A tuft of a beard on the breast.
	limb(pose.front, {0, 1.32, 0.68}, {0, 0.98, 0.74}, 0.05, ANIMAL_INK)
	// Wings, hinged at the shoulder.
	for side in ([2]f32{-1, 1}) {
		w := pose.rear * translate({side * 0.52, 1.5, -0.08}) * rot_z(side * wing)
		ball(w, {side * 0.08, -0.3, -0.06}, {0.15, 0.42, 0.6}, TURKEY_DARK)
		ball(w, {side * 0.1, -0.5, -0.24}, {0.11, 0.18, 0.42}, TURKEY_TIP)
	}

	// The bare neck and head.
	limb(pose.front, {0, 1.35, 0.42}, {0, 1.86, 0.62}, 0.14, TURKEY_SKIN)
	h := pose.front * translate({0, 1.92, 0.66}) * scale({1.15, 1.15, 1.15})
	if pose.held && !pose.dizzy {
		h = h * rot_y(0.4 * math.sin(e.hop * 0.9)) // looking wildly about
	} else if charging {
		h = h * rot_x(0.35) // head down
	}
	ball(h, {}, {0.24, 0.26, 0.27}, TURKEY_SKIN)
	draw_shape(.Cone, h * translate({0, -0.03, 0.2}) * rot_x(math.PI / 2) * scale({0.07, 0.17, 0.06}), BEAK)
	// The snood over the beak, and the wattle under the chin.
	limb(h, {0.02, 0.08, 0.2}, {0.05, -0.2, 0.33}, 0.045, TURKEY_RED)
	ball(h, {0, -0.25, 0.08}, {0.1, 0.15, 0.1}, TURKEY_RED)
	ball(pose.front, {0, 1.55, 0.66}, {0.1, 0.14, 0.08}, TURKEY_RED)
	for side in ([2]f32{-1, 1}) {
		draw_cute_eye(h * translate({side * 0.15, 0.06, 0.18}) * rot_y(side * 0.5), 0.085, pose.dizzy, pose.dead)
		if cross && !pose.dizzy {
			// A cross little brow.
			brow := h * translate({side * 0.14, 0.17, 0.2}) * rot_z(-side * 0.45)
			box(brow, {}, {0.12, 0.03, 0.04}, ANIMAL_INK)
		}
	}
}

// How far to his own side each of his two hooves is from the middle of his
// hold, when he holds something with both: a little apart.
hold_apart :: proc(side: f32) -> Vec3 {
	f := g.prosio.facing
	return Vec3{math.cos(f), 0, -math.sin(f)} * side * 0.09
}

draw_goat :: proc(pose: Animal_Pose, e: Enemy) {
	billy := e.kind == .Billy
	r := ENEMY_RADIUS[e.kind]
	coat := billy ? BILLY_COAT : GOAT_WHITE
	dark := billy ? BILLY_DARK : GOAT_PATCH
	charging := e.state == .Chase && e.hunt == .Charge
	for si in 0 ..< 2 {
		side := f32(si * 2 - 1)
		for ei in 0 ..< 2 {
			end := f32(ei * 2 - 1)
			if pose.held && ei == 0 {
				// Both hind legs run to Prosio's hooves, one in each.
				hip := pose.rear * [4]f32{side * GRIP_ROOT[e.kind].x, GRIP_ROOT[e.kind].y, GRIP_ROOT[e.kind].z, 1}
				grip := pose.hand + hold_apart(side)
				limb(IDENTITY, hip.xyz, grip, 0.1 * r, coat)
				ball(IDENTITY, grip, {0.08, 0.08, 0.08} * r, GOAT_HOOF)
				continue
			}
			turn := pose.legs[si][ei]
			leg := (end < 0 ? pose.rear : pose.front) * translate({side * 0.3, 0.84, end * 0.55}) * rot_z(turn.y) * rot_x(turn.x)
			knee := Vec3{0, -0.4, end < 0 ? -0.08 : 0.04}
			ankle := Vec3{0, -0.74, 0.02}
			taper(leg, {0, 0.12, 0}, knee, 0.17, coat)
			ball(leg, knee, {0.1, 0.1, 0.1}, coat)
			taper(leg, knee, ankle, 0.09, billy ? dark : coat)
			ball(leg, ankle + {0, -0.03, 0.03}, {0.09, 0.07, 0.11}, GOAT_HOOF)
		}
	}

	// The body, with a patch or two.
	ball(pose.rear, {0, 1.06, -0.42}, {0.5, 0.5, 0.55}, coat)
	ball(pose.rear, {0, 1.1, -0.06}, {0.55, 0.55, 0.5}, coat)
	ball(pose.front, {0, 1.14, 0.3}, {0.5, 0.56, 0.5}, coat)
	if !billy {
		ball(pose.rear, {0.3, 1.28, -0.22}, {0.3, 0.28, 0.32}, dark)
		ball(pose.front, {-0.26, 1.2, 0.32}, {0.28, 0.3, 0.26}, dark)
	} else {
		ball(pose.front, {0, 1.32, 0.38}, {0.5, 0.42, 0.42}, dark) // a shaggy mane
	}
	cone(pose.rear * translate({0, 1.38, -0.86}) * rot_x(-0.7), {}, 0.08, 0.26, coat)
	if !billy && !pose.dead {
		// The udder: full and round when she has milk, small when she has not.
		full: f32 = e.milk_t <= 0 ? 1 : 0.45
		ball(pose.rear, {0, 0.7, -0.4}, Vec3{0.3, 0.26, 0.3} * full, UDDER_PINK)
		for side in ([2]f32{-1, 1}) {
			ball(pose.rear, {side * 0.1 * full, 0.7 - 0.2 * full, -0.38}, Vec3{0.06, 0.09, 0.06} * full, UDDER_PINK)
		}
	}

	// The neck and head. Charging, the head goes down, horns first.
	limb(pose.front, {0, 1.3, 0.5}, {0, 1.72, 0.84}, 0.22, coat)
	tilt: f32 = charging ? 0.85 : 0.15
	if pose.held && !pose.dizzy {
		tilt = 0.3 * math.sin(e.hop * 0.7)
	}
	h := pose.front * translate({0, 1.78, 0.9}) * rot_x(tilt) * scale({1.12, 1.12, 1.12})
	ball(h, {}, {0.3, 0.32, 0.34}, coat)
	taper(h, {0, -0.05, 0.12}, {0, -0.2, 0.55}, 0.21, coat)
	ball(h, {0, -0.21, 0.56}, {0.13, 0.1, 0.08}, GOAT_PINK)
	for side in ([2]f32{-1, 1}) {
		ball(h, {side * 0.05, -0.2, 0.63}, {0.025, 0.03, 0.015}, ANIMAL_INK)
		ear := h * translate({side * 0.27, 0.06, -0.04}) * rot_z(side * 1.2)
		ball(ear, {0, 0.16, 0}, {0.07, 0.18, 0.1}, coat)
		ball(ear, {0, 0.17, 0.04}, {0.04, 0.12, 0.05}, GOAT_PINK)
		draw_cute_eye(h * translate({side * 0.19, 0.08, 0.22}) * rot_y(side * 0.55), 0.09, pose.dizzy, pose.dead)
		if billy {
			// Great horns curling back and round.
			prev := Vec3{side * 0.12, 0.24, 0.02}
			for k in 1 ..= 8 {
				a := f32(k) / 8 * 3.6
				at := Vec3{side * (0.12 + 0.03 * a), 0.24 + 0.32 * math.sin(a), 0.02 - 0.3 * (1 - math.cos(a))}
				limb(h, prev, at, 0.09 - 0.006 * f32(k), GOAT_HORN)
				prev = at
			}
		} else {
			horn := h * translate({side * 0.11, 0.24, -0.02}) * rot_x(-0.7) * rot_z(-side * 0.25)
			cone(horn, {}, 0.06, 0.3, GOAT_HORN)
		}
	}
	// A beard under the chin.
	beard := h * translate({0, -0.3, 0.38}) * rot_x(math.PI - 0.25)
	cone(beard, {}, billy ? 0.1 : 0.06, billy ? 0.38 : 0.2, billy ? dark : GOAT_PATCH)
	draw_smile(h * translate({0, -0.3, 0.55}), 0.045)
}

// A big glossy cartoon eye: a dark oval with a large and a small highlight.
// Shut tight when dizzy.
draw_cute_eye :: proc(m: Mat4, size: f32, shut: bool, dead := false) {
	if dead {
		// Two little crosses: it will not be getting up again.
		for turn in ([2]f32{-0.8, 0.8}) {
			box(m * rot_z(turn), {0, 0, 0.02}, {size * 1.5, size * 0.3, size * 0.3}, ANIMAL_INK)
		}
		return
	}
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

// Prosio is short and stocky: short legs, a compact body and a big head.
EAR_DROOP :: f32(2.9) // how far his ears hang over, in radians from straight up: almost straight down
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
	t := fatness()
	// A tough hide is a darker, rougher one.
	skin := blend(COLOR_SKIN, HIDE_TAN, p.trait[.Hide] * 0.7)
	skin_dark := blend(COLOR_SKIN_DARK, shade(HIDE_TAN, 0.85), p.trait[.Hide] * 0.7)
	if too_much(.Vitamins) && p.fail == .None {
		// Too many vitamins: he glows orange.
		glow := 0.6 + 0.15 * math.sin(g.time * 5)
		skin = blend(skin, {255, 150, 40, 255}, glow)
		skin_dark = blend(skin_dark, {230, 110, 30, 255}, glow)
	}
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

	// The collision radius follows the belly. The jacket stays snug as he grows.
	// Eating goes to the belly: it swells forwards and sideways, while his
	// bottom stays about the same size.
	belly_out := 0.03 + 0.17 * t // how far the belly sticks out in front
	belly := (r - belly_out * 0.6) * lerp(0.8, 0.93, t)
	chest := prosio_chest(p.kg)
	hips := 0.3 + 0.1 * t
	head := f32(0.46) // a big round head: he is drawn cute, kawaii style

	base := translate({p.pos.x, p.height, p.pos.y}) * rot_y(p.facing) * scale({PROSIO_SIZE, PROSIO_SIZE, PROSIO_SIZE})
	m := base * translate({0, bob, 0})
	eyes_closed := math.mod(g.time, 3.2) < 0.12
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
	// Squash and stretch: taller and thinner on take-off, flatter on landing.
	st := clamp(p.stretch, -0.3, 0.3)
	m = m * scale({1 - st * 0.5, 1 + st, 1 - st * 0.5})
	root := m // the head is placed from here, so the body's squash does not reach it

	// Legs: a thick thigh tapering to a round knee, then a slimmer shin
	// tapering to a cloven hoof. The knee bends a little as he walks, and in
	// the air he tucks his legs up.
	leg_x := 0.13 + 0.13 * t
	leg_r := (0.1 + 0.06 * t) * tone(.Legs, 0.85, 1.45) // thin when wasted, sturdy when built
	for side in ([2]f32{-1, 1}) {
		leg_swing := p.airborne ? -0.5 + side * 0.3 : side * swing
		hip := m * translate({side * leg_x, HIP * LEG_SCALE, 0}) * rot_x(leg_swing)
		bend := 0.03 + (p.airborne ? 0.12 : 0.07 * max(-side * swing, 0))
		knee := Vec3{0, -0.23 * LEG_SCALE, bend}
		ankle := Vec3{0, -0.41 * LEG_SCALE, 0}
		taper(hip, {0, 0.06, 0}, knee, leg_r * 1.5, skin)
		ball(hip, knee, {leg_r * 0.95, leg_r * 0.95, leg_r * 0.95}, skin)
		taper(hip, knee, ankle, leg_r * 0.98, skin)
		draw_leg_outfit(hip, leg_r, knee, ankle)
	}
	// Everything above the hips: sat on the shorter legs, a little compacted.
	m = m * translate({0, HIP * LEG_SCALE, 0}) * scale({1, TORSO_SCALE, 1}) * translate({0, -HIP, 0})

	// His own body first, whole, with nothing on: two round buttocks, the
	// belly, and a chest that rises from the top of the belly to his
	// shoulders. Clothes then go on over it in layers (see outfit.odin), each
	// a little bigger than what it covers.
	ball(m, {0, 0.6, 0.05}, {hips * 0.95 - LAYER, 0.2 - LAYER, hips * 0.8 - LAYER}, skin)
	for side in ([2]f32{-1, 1}) {
		ball(m, {side * hips * 0.42, 0.57, -hips * 0.25}, {hips * 0.58 - LAYER, 0.21 - LAYER, hips * 0.62 - LAYER}, skin)
	}
	ball(m, {0, 0.72, -hips * 0.86}, {0.08, 0.08, 0.08}, skin_dark) // curly tail, above the crease
	ball(m, {0.06, 0.8, -hips * 0.9 - 0.04}, {0.05, 0.05, 0.05}, skin_dark)
	draw_hips_outfit(m, hips)
	belly_y := 0.26 + 0.2 * t
	belly_mid := 0.86 + 0.04 * t // the belly hangs over the shorts, but not down to the knees
	ball(m, {0, belly_mid, belly_out}, {belly * (1 + wob), belly_y * (1 - wob), belly * (1 + wob)}, skin)
	covered := SHIRT_LOOK[outfit.shirt].long || closed_coat() || outfit.over == .Apron
	if t > 0.25 && !covered {
		ball(m, {0, belly_mid - 0.08, belly_out + belly * (1 + wob)}, {0.045, 0.045, 0.03}, skin_dark)
	}
	// His chest follows the upper arc of his belly, and so does a shirt.
	jacket := m * translate({0, belly_mid + belly_y * (1 - wob) * 0.51, belly_out})
	jacket_w := max(chest, belly * (1 + wob) * 0.86 + 0.014)
	jacket_h := max(0.33, 1.46 - (belly_mid + belly_y * (1 - wob) * 0.51))
	draw_shape(.Hemisphere, jacket * scale({jacket_w - LAYER, jacket_h - LAYER * 0.5, jacket_w - LAYER}), skin)
	draw_torso_outfit(m, jacket, jacket_w, jacket_h, chest, belly * (1 + wob), belly_y * (1 - wob), belly_mid, belly_out, hips, swing, skin)
	// Small canvas pack with a flap and brass clasp, visible from behind; it
	// sits outside whatever he wears.
	pack := m * translate({0, 1.15, -max(chest * 0.78, belly * 0.64) - clothes_thickness() - (outfit.over == .Cape ? f32(0.1) : 0)})
	ball(pack, {}, {0.235, 0.255, 0.135}, COLOR_SHORTS)
	ball(pack, {0, 0.077, -0.069}, {0.232, 0.123, 0.093}, {89, 133, 126, 255})
	box(pack, {0, 0.031, -0.165}, {0.047, 0.065, 0.016}, COLOR_SHIRT)

	// Set the wrist and elbow outside the current belly cross section. All
	// points are in the same local frame as the wobbling torso, so squash,
	// spin, facing and the push-up tilt are applied to the whole rig together.
	arm_r := lerp(0.1, 0.135, t) * tone(.Arms, 0.78, 1.5) // noodles when wasted, bulging when built
	belly_width := belly * (1 + wob)
	belly_height := belly_y * (1 - wob)
	for side in ([2]f32{-1, 1}) {
		shoulder := Vec3{side * (chest * 0.86), 1.30, 0.035}
		rest_x := side * (chest + arm_r * 0.85)
		elbow := Vec3{rest_x, 1.09, 0.04 - side * swing * 0.18}
		hand := Vec3{rest_x, 0.86 + 0.075 * abs(swing), 0.16 - side * swing * 0.35}
		switch {
		case p.carry == .Enemy && (side == HOLD_SIDE || two_handed(g.enemies[p.carry_index].kind)):
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
		// the elbow, then a forearm narrowing to the hoof; a round shoulder
		// joins it to his chest. Then the sleeve, if what he wears has one.
		taper(m, shoulder, elbow, arm_r * 1.75, skin)
		ball(m, shoulder + (elbow - shoulder) * 0.45, {arm_r * 1.45, arm_r * 1.45, arm_r * 1.45}, skin)
		ball(m, elbow, {arm_r * 1.05, arm_r * 1.05, arm_r * 1.05}, skin)
		taper(m, elbow, hand, arm_r * 1.12, skin)
		ball(m, shoulder, {arm_r * 1.7, arm_r * 1.7, arm_r * 1.7}, skin)
		draw_sleeve(m, shoulder, elbow, hand, arm_r)
		ball(m, hand, {arm_r * 1.1, 0.1, arm_r * 1.15}, COLOR_HOOF)
		if picking && !p.drinking && side == HOLD_SIDE && u > 0.45 {
			// What he picked up, in his hoof.
			ball(m, hand + {0, 0.1, 0.04}, {0.11, 0.11, 0.11}, ITEM_COLOR[p.pick_item])
		}
	}

	// Head: cheeks get rounder too.
	munch: f32 = p.eat_t > 0 ? math.sin(p.eat_t * 40) * 0.05 : 0
	cheeks := head * (1 + 0.2 * t)
	h := root * translate({0, HIP * LEG_SCALE + (1.72 - HIP) * TORSO_SCALE + munch, 0.04}) * rot_x(-0.16)
	if picking {
		h = h * rot_x(0.3 * stoop) // looking at what he picks up
	}
	ball(h, {0, 0, 0}, {cheeks, head * 0.95, head}, skin)
	draw_hair(h, cheeks, head, swing)
	draw_hat(h, h * rot_z(-0.075), cheeks, head, swing)
	for side in ([2]f32{-1, 1}) {
		// Floppy ears: they hang down beside his cheeks, flap a little as he
		// walks, and fly up when he falls.
		droop := EAR_DROOP + (walking ? 0.14 * math.sin(p.walk_phase * 2 + side) : 0.03 * math.sin(g.time * 2 + side))
		if p.airborne {
			droop = clamp(1.5 + p.vy * 0.09, 0.6, EAR_DROOP)
		}
		root := Vec3{side * cheeks * 0.86, 0.24, -0.02}
		ear := h * translate(root) * rot_x(0.15) * rot_z(-side * droop)
		ball(ear, {0, 0.19, 0}, {0.14, 0.22, 0.055}, skin) // a soft rounded flap
		ball(ear, {0, 0.2, 0.03}, {0.09, 0.15, 0.035}, skin_dark)
		// Big glossy eyes, set wide and low.
		if eyes_closed {
			box(h, {side * 0.19, 0.03, 0.42}, {0.13, 0.028, 0.03}, COLOR_BLACK)
		} else {
			eye := h * translate({side * 0.19, 0.035, 0.385}) * rot_y(side * 0.3)
			ball(eye, {}, {0.085, 0.115, 0.06}, COLOR_BLACK)
			ball(eye, {-0.026, 0.045, 0.045}, {0.034, 0.04, 0.02}, COLOR_WHITE)
			ball(eye, {0.028, -0.042, 0.05}, {0.016, 0.016, 0.01}, COLOR_WHITE)
		}
		// Little eyebrows show how he feels.
		brow := h * translate({side * 0.19, 0.21, 0.37}) * rot_z(side * brow_tilt)
		box(brow, {0, 0, 0}, {0.09, 0.022, 0.03}, COLOR_HOOF)
		// Rosy cheeks.
		cheek := h * translate({side * cheeks * 0.62, -0.1, 0.31}) * rot_y(side * 0.6)
		ball(cheek, {}, {0.105, 0.06, 0.034}, ANIMAL_BLUSH)
		ball(h, {side * 0.06, -0.085, 0.53}, {0.024, 0.033, 0.018}, COLOR_NOSTRIL)
	}
	ball(h, {0, -0.1, 0.415}, {0.165, 0.112, 0.13}, skin_dark)
	draw_face_outfit(h, cheeks)
	switch {
	case p.eat_t > 0 || p.airborne:
		ball(h, {0, -0.235, 0.35}, {0.06, 0.05, 0.03}, COLOR_NOSTRIL) // open mouth
	case p.strain > 0.5 || p.heave_t > 0 || eyes_closed && p.fail != .None:
	case outfit.face == .None:
		draw_smile(h * translate({0, -0.235, 0.37}), 0.05) // a small contented smile
	}
	if p.strain > 0.5 || p.heave_t > 0 {
		ball(h, {0, -0.22, 0.34}, {0.09, 0.025, 0.03}, COLOR_WHITE) // gritted teeth
	}

	head_top := Vec3{p.pos.x, p.height + 2.2 * PROSIO_SIZE, p.pos.y}
	if p.dazed_t > 0 {
		draw_stars(head_top, 0.45, 3.3)
	}
	if p.winding && p.wind_t >= WIND_TAP && !drawing_shadows() {
		// Winding up a throw: a bar at his feet fills as it gets stronger.
		bar := translate({p.pos.x, p.height + 0.12, p.pos.y + prosio_radius(p.kg) + 0.55}) // on the ground in front of him, clear of what he says
		power := wind_power()
		box(bar, {}, {1.06, 0.16, 0.03}, UI_DARK)
		box(bar, {-(1 - power) / 2, 0, 0.02}, {power, 0.1, 0.03}, power >= 1 ? UI_RED : UI_YELLOW)
	}
	if (p.fail == .Fainted || p.fail == .Diet || p.fail == .Beaten) && p.fail_t > 0.4 {
		draw_stars({p.pos.x, p.height + 1.3 * PROSIO_SIZE, p.pos.y}, 0.6 * PROSIO_SIZE, 5.1)
	}
	if p.fail == .Heart_Attack && p.fail_t > 0.4 {
		// A thumping cartoon heart above him.
		beat := 1 + 0.25 * abs(math.sin(g.time * 7))
		hm := translate({p.pos.x, p.height + 2.3 * PROSIO_SIZE, p.pos.y}) * scale({beat, beat, beat})
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

// A fox: a slim rust-red body, dark feet, a bushy white-tipped tail and a
// big head with pointed ears. With something stolen, it carries it in its
// mouth. Held, it hangs by its tail from Prosio's hand.
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
		// Held by the tail: it runs taut from its rump to his hoof.
		root := (pose.rear * [4]f32{GRIP_ROOT[e.kind].x, GRIP_ROOT[e.kind].y, GRIP_ROOT[e.kind].z, 1}).xyz
		white := root + (pose.hand - root) * 0.72
		limb(IDENTITY, root, white, 0.26 * r, coat)
		limb(IDENTITY, white, pose.hand, 0.17 * r, cream)
	} else {
		wag: f32 = pose.dead ? 0 : 0.39 + 0.20 * math.sin(e.hop * 0.52)
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
		draw_cute_eye(h * translate({side * 0.24, 0.07, 0.36}) * rot_y(side * 0.45), 0.13, pose.dizzy, pose.dead)
		ball(h, {side * 0.3, -0.12, 0.31}, {0.085, 0.045, 0.035}, ANIMAL_BLUSH)
	}
	if e.has_loot {
		// What it stole, in its mouth.
		color := ITEM_COLOR[e.loot] // (things that are made have no colour of their own here)
		ball(h, {0, -0.24, 0.78}, {0.3, 0.22, 0.22}, color.a > 0 ? color : CRUST)
	} else {
		draw_smile(h * translate({0, -0.2, 0.62}), 0.06)
	}
}

// A big grey rock with rock salt growing on it: a white crust all the time,
// and big pink crystals standing up out of it when there is some to take.
draw_salt_rock :: proc(r: Round, index: int) {
	m := translate({r.pos.x, 0, r.pos.y}) * rot_y(f32(index) * 1.3)
	draw_rock(m * translate({0, r.r * 0.5, 0}), r.r, index)
	set_surface(.Solid)
	// The crust, in patches over the top.
	for k in 0 ..< 5 {
		a := f32(k) * 1.26
		ball(m, {math.cos(a) * r.r * 0.45, r.r * 0.86 - 0.05 * f32(k % 2), math.sin(a) * r.r * 0.4}, {0.22, 0.07, 0.2}, COLOR_WHITE)
	}
	for k in 0 ..< r.fruit {
		// A cluster of crystals for each lump, standing on the rock.
		side := f32(k) * 2 - 1
		c := m * translate({side * r.r * 0.36, r.r * 0.88, 0.1 * side}) * rot_y(side * 0.7)
		draw_shape(.Cube, c * translate({0, 0.34, 0}) * rot_z(0.15 * side) * scale({0.34, 0.74, 0.34}), SALT_PINK)
		draw_shape(.Cube, c * translate({0.26, 0.2, 0.1}) * rot_z(-0.35) * scale({0.22, 0.44, 0.22}), shade(SALT_PINK, 0.92))
		draw_shape(.Cube, c * translate({-0.22, 0.16, 0.13}) * rot_z(0.4) * scale({0.18, 0.34, 0.18}), COLOR_WHITE)
	}
}

// A mossy stump or a fallen log, drawn from its model: a stump as wide as
// it stands in the way, a log LOG_LENGTH long, turned its own way.
draw_stump :: proc(r: Round, index: int) {
	STUMPS := [3]Tree_Model_Kind{.Stump1, .Stump2, .Log1}
	model := STUMPS[r.variant % 3]
	md := &TREE_MODELS[model]
	size := model == .Log1 ? LOG_LENGTH / 2 / md.radius : r.r * 1.25 / md.radius
	m := translate({r.pos.x, 0, r.pos.y}) * rot_y(f32(index) * 2.1) * scale({size, size, size})
	set_surface(.Bark)
	draw_tree_part(model, .Bark, m, md.bark_color)
	set_surface(.Solid)
	if md.leaves > 0 {
		draw_tree_part(model, .Leaves, m, shade(COLOR_FERN, 1.1))
	}
}

// A clump of grass, a fern or a low bush, from its model; the caller has
// set the leaf surface and the sway.
draw_plant :: proc(d: Decor, m: Mat4) {
	#partial switch d.kind {
	case .Tuft:
		// A clump of grass: mostly short, now and then a tall one, a
		// shade lighter or darker, swaying in the wind.
		model, size := Tree_Model_Kind.Grass1, GRASS_SIZE
		if d.variant % 5 == 0 {
			model, size = d.variant % 2 == 0 ? .Grass2 : .Grass3, GRASS_SIZE * 0.55
		}
		size *= 0.8 + 0.4 * tree_random(d.variant, 7)
		draw_tree_part(model, .Leaves, m * scale({size, size, size}), shade(COLOR_TUFT, 0.9 + 0.25 * tree_random(d.variant, 8)))
	case .Shrub:
		size := SHRUB_SIZE * (0.8 + 0.4 * tree_random(d.variant, 7))
		draw_tree_part(d.variant % 2 == 0 ? .Bush1 : .Bush2, .Leaves, m * scale({size, size, size}), shade(COLOR_FERN, 0.95 + 0.25 * tree_random(d.variant, 8)))
	case .Fern:
		FERNS := [3]Tree_Model_Kind{.Fern1, .Fern2, .Fern3}
		size := FERN_SIZE * (0.8 + 0.4 * tree_random(d.variant, 7))
		draw_tree_part(FERNS[d.variant % 3], .Leaves, m * scale({size, size, size}), shade(COLOR_FERN, 0.85 + 0.3 * tree_random(d.variant, 8)))
	}
}
