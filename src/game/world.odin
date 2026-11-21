package game

import "core:math"

GRAVITY :: f32(25)

// The meadow reaches this far from the centre, inside a fence. Prosio's home
// with its oven is in the middle; each kind of food grows in its own part of
// the meadow (see REGIONS), so he has to go out and fetch it.
WORLD_HALF :: Vec2{100, 70}
HOME :: Vec2{0, 0}
BERRY_REGROW :: f32(9) // seconds for a bush to grow another bunch
MAX_BERRIES :: 3
MAX_APPLES :: 4 // apples hanging on one tree
APPLE_LIFE :: f32(45) // seconds a fallen apple lies there before it rots away
EGG_LIFE :: f32(90) // seconds a laid egg lies there before it is gone
MAX_EGGS :: 10 // eggs lying about at once, all over the meadow

MAX_ROUNDS :: 640
MAX_FOODS :: 360
MAX_PARTICLES :: 256
MAX_DECOR :: 2400
MAX_FIELDS :: 8

Round_Kind :: enum {
	Tree,
	Rock,
	Bush,
	Oven,
}

Tree_Species :: enum {
	Broadleaf,
	Apple,
	Blossom,
	Pine,
}

// A round obstacle.
Round :: struct {
	pos:     Vec2,
	r:       f32,
	kind:    Round_Kind,
	species: Tree_Species, // trees only
	fruit:   int, // apples on an apple tree, bunches of berries on a bush
	fruit_t: f32, // until the next apple or bunch grows (or falls)
	shake_t: f32, // just shaken: the leaves are still trembling
}

// The parts of the meadow, each with its own food. They are ellipses.
Region_Kind :: enum {
	Home,
	Forest,
	Fields,
	Garden,
	Turkeys,
	Hills,
}

Region :: struct {
	name:   cstring,
	about:  cstring, // what is found there
	centre: Vec2,
	radius: Vec2,
	sign:   cstring, // what its signpost by the house says
}

REGIONS := [Region_Kind]Region {
	.Home    = {"HOME", "the oven", HOME, {13, 11}, ""},
	.Forest  = {"THE FOREST", "berries, wild apples, mushrooms", {-62, -10}, {33, 50}, "FOREST"},
	.Fields  = {"THE WHEAT FIELDS", "wheat", {58, 26}, {27, 20}, "WHEAT"},
	.Garden  = {"THE PUMPKIN PATCH", "pumpkins", {-14, 48}, {17, 15}, "PUMPKINS"},
	.Turkeys = {"TURKEY MEADOW", "eggs... and angry turkeys", {14, -46}, {25, 18}, "TURKEYS"},
	.Hills   = {"GOAT HILLS", "rocks... and goats", {70, -42}, {26, 22}, "GOATS"},
}

// The region a place is in, if any.
region_at :: proc(pos: Vec2) -> (kind: Region_Kind, ok: bool) {
	for r, k in REGIONS {
		d := (pos - r.centre) / r.radius
		if d.x * d.x + d.y * d.y < 1 {
			return k, true
		}
	}
	return {}, false
}

// How deep inside a region a place is: 0 at its edge or outside, 1 at its centre.
inside_region :: proc(pos: Vec2, kind: Region_Kind) -> f32 {
	r := REGIONS[kind]
	d := (pos - r.centre) / r.radius
	return max(1 - math.sqrt(d.x * d.x + d.y * d.y), 0)
}

// A random place in a region, no further out than edge (1 is its edge).
spot_in :: proc(kind: Region_Kind, edge: f32 = 0.92) -> Vec2 {
	r := REGIONS[kind]
	a := random_range(0, math.TAU)
	k := math.sqrt(random()) * edge
	return r.centre + Vec2{math.cos(a), math.sin(a)} * r.radius * k
}

// Paths from home out to each region, as straight segments; they wander a
// little when drawn.
PATH_ENDS := [Region_Kind]Vec2 {
	.Home    = HOME,
	.Forest  = {-30, -8},
	.Fields  = {36, 18},
	.Garden  = {-10, 34},
	.Turkeys = {10, -29},
	.Hills   = {50, -30},
}

// Where the signpost for a region stands, beside its path a little way from home.
signpost_pos :: proc(kind: Region_Kind) -> Vec2 {
	dir := normalize2(PATH_ENDS[kind] - HOME)
	side := Vec2{-dir.y, dir.x}
	return HOME + dir * 8.5 + side * 1.6
}

// A ploughed field of wheat or a pumpkin bed: bare soil in rows.
Field :: struct {
	lo, hi: Vec2,
	crop:   Food_Kind,
}

// Food is found, not served: wheat in the fields, pumpkins in the pumpkin
// patch, apples, berries and mushrooms in the forest, and eggs wherever the
// turkeys lay them. All of it goes into Prosio's sack (see kitchen.odin).
Food_Kind :: enum {
	Apple,
	Mushroom,
	Pumpkin,
	Wheat,
	Egg,
}

Food :: struct {
	kind:    Food_Kind,
	pos:     Vec2,
	y, vy:   f32, // a falling apple's or egg's height and speed
	respawn: f32, // seconds until it grows back; 0 means it is there
	fallen:  bool, // an apple off a tree or a laid egg: once taken (or gone off) it is gone for good
	gone:    bool, // this slot is free
	life:    f32, // a fallen apple rots away, and an egg goes, when this runs out
	tree:    int, // the tree a fallen apple came from
}

// What each becomes in the sack.
FOOD_ITEM := [Food_Kind]Item {
	.Apple    = .Apple,
	.Mushroom = .Mushroom,
	.Pumpkin  = .Pumpkin,
	.Wheat    = .Wheat,
	.Egg      = .Egg,
}
FOOD_RESPAWN := [Food_Kind]f32 {
	.Apple    = 0, // apples are not replanted: new ones fall from the trees
	.Mushroom = 25,
	.Pumpkin  = 40,
	.Wheat    = 30,
	.Egg      = 0, // the turkeys lay new ones
}
// How big each is on the ground. Only a pumpkin is big enough to bump into.
FOOD_SIZE := [Food_Kind]f32 {
	.Apple    = 0.12,
	.Mushroom = 0.14,
	.Pumpkin  = 0.34,
	.Wheat    = 0.22,
	.Egg      = 0.1,
}

// Food lying on the ground, ready to pick up.
food_ready :: proc(f: ^Food) -> bool {
	return !f.gone && f.respawn <= 0 && f.y <= 0.01
}

Decor_Kind :: enum {
	Tuft,
	Flower,
}

// Grass tufts and flowers. Purely for looks.
Decor :: struct {
	pos:     Vec2,
	kind:    Decor_Kind,
	variant: int,
}

Particle :: struct {
	pos, vel: Vec3,
	life:     f32,
	max_life: f32,
	size:     f32,
	gravity:  f32,
	color:    Color,
}

add_round :: proc(pos: Vec2, r: f32, kind: Round_Kind) -> int {
	if g.round_count >= MAX_ROUNDS {
		return -1
	}
	g.rounds[g.round_count] = Round{pos = pos, r = r, kind = kind}
	g.round_count += 1
	return g.round_count - 1
}

add_tree :: proc(pos: Vec2, species: Tree_Species) {
	i := add_round(pos, 0.32, .Tree)
	if i < 0 {
		return
	}
	t := &g.rounds[i]
	t.species = species
	if species == .Apple {
		t.fruit = 2 + int(random() * 3)
		t.fruit_t = random_range(2, 8)
	}
}

// A forest tree: mostly broadleaves and pines, with wild apple trees.
forest_species :: proc() -> Tree_Species {
	roll := random()
	switch {
	case roll < 0.2:
		return .Apple
	case roll < 0.55:
		return .Pine
	}
	return .Broadleaf
}

// A lone tree out in the meadow: no fruit out here.
meadow_species :: proc() -> Tree_Species {
	roll := random()
	switch {
	case roll < 0.25:
		return .Blossom
	case roll < 0.5:
		return .Pine
	}
	return .Broadleaf
}

// A berry bush, picked from where it stands.
add_bush :: proc(pos: Vec2) {
	i := add_round(pos, random_range(0.45, 0.6), .Bush)
	if i >= 0 {
		g.rounds[i].fruit = MAX_BERRIES
		g.rounds[i].fruit_t = BERRY_REGROW
	}
}

add_food :: proc(kind: Food_Kind, pos: Vec2) -> ^Food {
	slot := -1
	for &f, i in g.foods[:g.food_count] {
		if f.gone {
			slot = i
			break
		}
	}
	if slot < 0 {
		if g.food_count >= MAX_FOODS {
			return nil
		}
		slot = g.food_count
		g.food_count += 1
	}
	g.foods[slot] = Food{kind = kind, pos = pos, tree = -1}
	return &g.foods[slot]
}

// A field, sown in rows step apart.
add_field :: proc(lo, hi: Vec2, crop: Food_Kind, step: Vec2) {
	g.fields[g.field_count] = Field{lo, hi, crop}
	g.field_count += 1
	for y := lo.y + step.y * 0.6; y < hi.y - step.y * 0.4; y += step.y {
		for x := lo.x + step.x * 0.6; x < hi.x - step.x * 0.4; x += step.x {
			add_food(crop, {x + random_range(-0.1, 0.1), y + random_range(-0.08, 0.08)})
		}
	}
}

in_field :: proc(pos: Vec2, margin: f32) -> bool {
	for f in g.fields[:g.field_count] {
		if pos.x > f.lo.x - margin && pos.x < f.hi.x + margin && pos.y > f.lo.y - margin && pos.y < f.hi.y + margin {
			return true
		}
	}
	return false
}

build_world :: proc() {
	// Home: the oven, by the start.
	g.oven.pos = HOME + {-4, -2.5}
	add_round(g.oven.pos, OVEN_RADIUS, .Oven)

	// The forest: trees close together, with berry bushes in the gaps and
	// round its edge, wild apple trees among them, and mushrooms in the shade.
	for placed, tries := 0, 0; placed < 230 && tries < 4000; tries += 1 {
		pos := spot_in(.Forest, 0.97)
		if clear_spot(pos, 1.0) {
			add_tree(pos, forest_species())
			placed += 1
		}
	}
	for placed, tries := 0, 0; placed < 46 && tries < 3000; tries += 1 {
		pos := spot_in(.Forest, 1.02)
		if clear_spot(pos, 1.1) {
			add_bush(pos)
			placed += 1
		}
	}
	for placed, tries := 0, 0; placed < 45 && tries < 2000; tries += 1 {
		t := g.rounds[int(random() * f32(g.round_count)) % g.round_count]
		if t.kind != .Tree || inside_region(t.pos, .Forest) <= 0 {
			continue
		}
		a := random_range(0, math.TAU)
		pos := t.pos + Vec2{math.cos(a), math.sin(a)} * random_range(0.75, 1.5)
		if clear_spot(pos, 0.3) {
			add_food(.Mushroom, pos)
			placed += 1
		}
	}

	// The wheat fields, and the pumpkin patch.
	add_field({40, 13}, {50, 21}, .Wheat, {1.3, 1.15})
	add_field({56, 9}, {68, 16}, .Wheat, {1.3, 1.15})
	add_field({48, 28}, {60, 37}, .Wheat, {1.3, 1.15})
	add_field({66, 24}, {75, 32}, .Wheat, {1.3, 1.15})
	add_field({-24, 40}, {-15, 46}, .Pumpkin, {1.5, 1.6})
	add_field({-9, 42}, {-1, 48}, .Pumpkin, {1.5, 1.6})
	add_field({-20, 51}, {-10, 57}, .Pumpkin, {1.5, 1.6})
	// A few shady trees round the fields.
	for placed, tries := 0, 0; placed < 8 && tries < 400; tries += 1 {
		pos := spot_in(.Fields, 1.05)
		if clear_spot(pos, 2) {
			add_tree(pos, .Broadleaf)
			placed += 1
		}
	}

	// The goat hills: rocks large and small, and a few pines.
	for placed, tries := 0, 0; placed < 34 && tries < 2000; tries += 1 {
		pos := spot_in(.Hills, 0.98)
		size := random() < 0.3 ? random_range(0.9, 1.5) : random_range(0.35, 0.8)
		if clear_spot(pos, size + 1.2) {
			add_round(pos, size, .Rock)
			placed += 1
		}
	}
	for placed, tries := 0, 0; placed < 10 && tries < 400; tries += 1 {
		pos := spot_in(.Hills, 0.95)
		if clear_spot(pos, 2) {
			add_tree(pos, .Pine)
			placed += 1
		}
	}

	// Turkey meadow: open grass with a few shady trees.
	for placed, tries := 0, 0; placed < 9 && tries < 400; tries += 1 {
		pos := spot_in(.Turkeys, 0.95)
		if clear_spot(pos, 3) {
			add_tree(pos, meadow_species())
			placed += 1
		}
	}

	// The open meadow in between: lone trees and rocks, but no food.
	for placed, tries := 0, 0; placed < 70 && tries < 3000; tries += 1 {
		pos := random_spot()
		if _, in_region := region_at(pos); !in_region && clear_spot(pos, 2.5) {
			add_tree(pos, meadow_species())
			placed += 1
		}
	}
	for placed, tries := 0, 0; placed < 40 && tries < 3000; tries += 1 {
		pos := random_spot()
		if region, in_region := region_at(pos); (!in_region || region == .Turkeys) && clear_spot(pos, 2) {
			add_round(pos, random_range(0.3, 0.7), .Rock)
			placed += 1
		}
	}

	spawn_enemies()

	// Scatter tufts and flowers where nothing else stands.
	w := WORLD_HALF
	for tries := 0; g.decor_count < MAX_DECOR && tries < MAX_DECOR * 3; tries += 1 {
		pos := Vec2{random_range(-w.x + 0.5, w.x - 0.5), random_range(-w.y + 0.5, w.y - 0.5)}
		probe := pos
		if hit, _ := collide_static(&probe, 0.5, 0, true); hit || in_field(pos, 0.3) {
			continue
		}
		g.decor[g.decor_count] = Decor {
			pos     = pos,
			kind    = g.decor_count % 3 == 0 ? .Flower : .Tuft,
			variant = g.decor_count,
		}
		g.decor_count += 1
	}
}

random_spot :: proc() -> Vec2 {
	w := WORLD_HALF
	return {random_range(-w.x + 2, w.x - 2), random_range(-w.y + 2, w.y - 2)}
}

// True if a spot is free: nothing solid within r, not on a field, and not
// where home or the paths need to stay open.
clear_spot :: proc(pos: Vec2, r: f32) -> bool {
	if length2(pos - HOME) < 12 + r || in_field(pos, r + 0.5) {
		return false
	}
	for kind in Region_Kind {
		if kind != .Home && near_segment(pos, HOME, PATH_ENDS[kind], 2.2 + r) {
			return false
		}
	}
	for e in g.enemies[:g.enemy_count] {
		if length2(pos - e.home) < r + 1.5 {
			return false
		}
	}
	probe := pos
	hit, _ := collide_static(&probe, r, 0, true)
	return !hit
}

near_segment :: proc(p, a, b: Vec2, reach: f32) -> bool {
	ab := b - a
	t := clamp(dot2(p - a, ab) / max(dot2(ab, ab), 1e-6), 0, 1)
	return length2(p - (a + ab * t)) < reach
}

// Keeps a circle out of everything solid: trees, rocks, bushes, the oven,
// pumpkins and the fence round the meadow.
//
// feet is how high off the ground the circle is: things fly or jump over
// obstacles lower than that.
collide_static :: proc(pos: ^Vec2, r: f32, feet: f32, enemy := false) -> (hit: bool, normal: Vec2) {
	// Two passes, so a push out of one thing cannot leave the circle inside another.
	for _ in 0 ..< 2 {
		for i in 0 ..< g.round_count {
			rd := &g.rounds[i]
			if rd.r <= 0 || abs(rd.pos.x - pos.x) > rd.r + r || abs(rd.pos.y - pos.y) > rd.r + r {
				continue
			}
			top: f32
			switch rd.kind {
			case .Tree:
				top = 3
			case .Rock:
				top = rd.r * 1.05
			case .Bush:
				top = 0.8
			case .Oven:
				top = 2.2
			}
			if feet >= top {
				continue
			}
			if h, n := push_out_circle(pos, r, rd.pos, rd.r); h {
				hit, normal = true, n
			}
		}
		for &f in g.foods[:g.food_count] {
			if f.kind != .Pumpkin || !food_ready(&f) || feet >= 0.6 {
				continue
			}
			if h, n := push_out_circle(pos, r, f.pos, FOOD_SIZE[f.kind]); h {
				hit, normal = true, n
			}
		}
		lim := WORLD_HALF - {r, r}
		if pos.x < -lim.x {
			pos.x = -lim.x
			hit, normal = true, {1, 0}
		}
		if pos.x > lim.x {
			pos.x = lim.x
			hit, normal = true, {-1, 0}
		}
		if pos.y < -lim.y {
			pos.y = -lim.y
			hit, normal = true, {0, 1}
		}
		if pos.y > lim.y {
			pos.y = lim.y
			hit, normal = true, {0, -1}
		}
	}
	return
}

// The nearest food Prosio can reach, if any.
food_in_reach :: proc(pos: Vec2, reach: f32) -> ^Food {
	best: ^Food
	best_dist := reach
	for &f in g.foods[:g.food_count] {
		if !food_ready(&f) {
			continue
		}
		d := length2(f.pos - pos) - FOOD_SIZE[f.kind]
		if d < best_dist {
			best, best_dist = &f, d
		}
	}
	return best
}

// The nearest bush with berries on it that Prosio can reach, if any.
bush_in_reach :: proc(pos: Vec2, reach: f32) -> ^Round {
	best: ^Round
	best_dist := reach
	for &b in g.rounds[:g.round_count] {
		if b.kind != .Bush || b.fruit <= 0 {
			continue
		}
		d := length2(b.pos - pos) - b.r
		if d < best_dist {
			best, best_dist = &b, d
		}
	}
	return best
}

// An apple comes loose from tree t and falls from somewhere in its crown.
drop_apple :: proc(t: int) {
	tree := &g.rounds[t]
	if tree.fruit <= 0 {
		return
	}
	shape := tree_shape(t)
	for tries in 0 ..< 6 {
		a := random_range(0, math.TAU)
		pos := tree.pos + Vec2{math.cos(a), math.sin(a)} * random_range(0.5, shape.canopy * 0.85)
		probe := pos
		if hit, _ := collide_static(&probe, 0.15, 0, true); hit && tries < 5 {
			continue
		}
		f := add_food(.Apple, probe)
		if f == nil {
			return
		}
		f.fallen = true
		f.life = APPLE_LIFE
		f.tree = t
		f.y = shape.canopy_y - shape.canopy * 0.5
		tree.fruit -= 1
		return
	}
}

eggs_lying :: proc() -> (n: int) {
	for &f in g.foods[:g.food_count] {
		if !f.gone && f.kind == .Egg {
			n += 1
		}
	}
	return
}

// An egg drops from a turkey at this place and height.
drop_egg :: proc(pos: Vec2, height: f32) -> bool {
	if eggs_lying() >= MAX_EGGS {
		return false
	}
	probe := pos
	collide_static(&probe, 0.12, 0, true)
	f := add_food(.Egg, probe)
	if f == nil {
		return false
	}
	f.fallen = true
	f.life = EGG_LIFE
	f.y = max(height, 0.05)
	return true
}

// Something hit the trees near pos this hard: they shake, and apple trees
// drop some of their apples.
shake_trees_near :: proc(pos: Vec2, reach: f32, strength: f32) {
	for &t, i in g.rounds[:g.round_count] {
		if t.kind != .Tree || length2(t.pos - pos) > reach + t.r {
			continue
		}
		t.shake_t = 0.6
		shape := tree_shape(i)
		burst({t.pos.x, shape.canopy_y, t.pos.y}, 6, 2, COLOR_LEAF, 0.09)
		for _ in 0 ..< min(t.fruit, 1 + int(strength / 4)) {
			drop_apple(i)
		}
	}
}

update_world :: proc(dt: f32) {
	for &f in g.foods[:g.food_count] {
		if f.gone {
			continue
		}
		if f.fallen {
			// Falling, with a little bounce, then lying until it goes.
			if f.y > 0 || f.vy != 0 {
				f.vy -= GRAVITY * dt
				f.y += f.vy * dt
				if f.y <= 0 {
					f.y = 0
					f.vy = f.vy < -3 ? -f.vy * 0.3 : 0
					if f.vy == 0 {
						burst({f.pos.x, 0.1, f.pos.y}, 2, 1, COLOR_DUST, 0.06)
					}
				}
			}
			f.life -= dt
			if f.life <= 0 {
				f.gone = true
			}
			continue
		}
		if f.respawn > 0 {
			f.respawn -= dt
			// Food does not grow back under someone standing there.
			if f.respawn <= 0 {
				crowded := length2(g.prosio.pos - f.pos) < prosio_radius(g.prosio.kg) + FOOD_SIZE[f.kind] + 0.1
				for &e in g.enemies[:g.enemy_count] {
					if e.state != .Gone && length2(e.pos - f.pos) < ENEMY_RADIUS[e.kind] + FOOD_SIZE[f.kind] + 0.1 {
						crowded = true
					}
				}
				if crowded {
					f.respawn = 0.3
				} else {
					f.respawn = 0
					burst({f.pos.x, 0.2, f.pos.y}, 4, 1.2, COLOR_LEAF_LIGHT, 0.06)
				}
			}
		}
	}
	// Apple trees grow apples, and now and then one drops; bushes grow berries.
	for &t, i in g.rounds[:g.round_count] {
		t.shake_t = max(t.shake_t - dt, 0)
		if t.kind == .Bush && t.fruit < MAX_BERRIES {
			t.fruit_t -= dt
			if t.fruit_t <= 0 {
				t.fruit += 1
				t.fruit_t = BERRY_REGROW
			}
		}
		if t.kind == .Tree && t.species == .Apple {
			t.fruit_t -= dt
			if t.fruit_t <= 0 {
				t.fruit_t = random_range(8, 18)
				lying := 0
				for &f in g.foods[:g.food_count] {
					if !f.gone && f.fallen && f.tree == i {
						lying += 1
					}
				}
				if t.fruit > 0 && lying < 2 && random() < 0.45 {
					drop_apple(i)
				} else if t.fruit < MAX_APPLES {
					t.fruit += 1
				}
			}
		}
	}
	update_oven(dt)
	g.shake = max(g.shake - dt * 2.5, 0)
}

spawn_particle :: proc(pos, vel: Vec3, life, size: f32, color: Color, gravity: f32 = 14) {
	g.particles[g.particle_next] = Particle{pos, vel, life, life, size, gravity, color}
	g.particle_next = (g.particle_next + 1) % MAX_PARTICLES
}

// A puff of particles flying outwards from a point.
burst :: proc(pos: Vec3, count: int, speed: f32, color: Color, size: f32) {
	for _ in 0 ..< count {
		a := random_range(0, math.TAU)
		s := random_range(0.4, 1) * speed
		vel := Vec3{math.cos(a) * s, random_range(0.5, 1.2) * speed, math.sin(a) * s}
		spawn_particle(pos, vel, random_range(0.4, 0.9), size * random_range(0.7, 1.3), color)
	}
}

update_particles :: proc(dt: f32) {
	for &p in g.particles {
		if p.life <= 0 {
			continue
		}
		p.life -= dt
		p.vel.y -= p.gravity * dt
		p.pos += p.vel * dt
		if p.pos.y < 0.05 {
			p.pos.y = 0.05
			p.vel = {}
		}
	}
}
