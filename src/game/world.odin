package game

import "core:math"

GRAVITY :: f32(25)
STEP_UP :: f32(0.36) // the highest ledge Prosio can simply walk onto
DROP :: f32(0.4) // walking off anything taller than this is a fall

WORLD_HALF :: Vec2{44, 30} // the meadow reaches this far from the centre
WALL_HEIGHT :: f32(1.3) // taller than Prosio's highest jump
DOOR_GAP :: f32(1.2) // width of the skinny door
PLATE_KG :: f32(105) // weight needed on the pressure plate
BERRY_KG :: f32(2) // one bunch of berries off a bush
BERRY_REGROW :: f32(9) // seconds for a bush to grow another bunch
MAX_BERRIES :: 3
MAX_APPLES :: 4 // apples hanging on one tree
APPLE_LIFE :: f32(45) // seconds a fallen apple lies there before it rots away
TOWER_HEIGHT :: f32(2.0) // the jumping tower next to the catapult

MAX_WALLS :: 32
MAX_ROUNDS :: 230
MAX_FOODS :: 80
MAX_PARTICLES :: 256
MAX_PLATFORMS :: 4
MAX_DECOR :: 420

Wall_Style :: enum {
	Brick,
	Fence,
}

Wall :: struct {
	lo, hi: Vec2,
	height: f32,
	color:  Color,
	gate:   int, // index of the gate this wall is, or -1 for a plain wall
	style:  Wall_Style,
}

Gate :: struct {
	open: bool,
	anim: f32, // 0 closed, 1 fully sunk into the ground
}

Round_Kind :: enum {
	Tree,
	Rock,
	Crate,
	Bush,
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

// Something to stand on: a flat block, or a ramp that rises from its south
// edge (hi.y) to its north edge (lo.y).
Platform :: struct {
	lo, hi: Vec2,
	height: f32,
	ramp:   bool,
}

// Food is found, not served: apples fall from apple trees, mushrooms grow
// in the shade under trees, pumpkins in patches out in the open. Berries are
// eaten straight off the bushes (see Round).
Food_Kind :: enum {
	Apple,
	Mushroom,
	Pumpkin,
}

Food :: struct {
	kind:      Food_Kind,
	pos:       Vec2,
	y, vy:     f32, // a falling apple's height and speed
	respawn:   f32, // seconds until it grows back; 0 means it is there
	fallen:    bool, // an apple off a tree: once eaten (or rotten) it is gone for good
	gone:      bool, // this slot is free
	life:      f32, // a fallen apple rots away when this runs out
	tree:      int, // the tree a fallen apple came from
}

FOOD_KG := [Food_Kind]f32 {
	.Apple    = 3,
	.Mushroom = 5,
	.Pumpkin  = 12,
}
FOOD_RESPAWN := [Food_Kind]f32 {
	.Apple    = 0, // apples are not replanted: new ones fall from the trees
	.Mushroom = 25,
	.Pumpkin  = 40,
}
// How big each is on the ground. Only a pumpkin is big enough to bump into.
FOOD_SIZE := [Food_Kind]f32 {
	.Apple    = 0.12,
	.Mushroom = 0.14,
	.Pumpkin  = 0.34,
}

// Food lying on the ground, ready to eat.
food_ready :: proc(f: ^Food) -> bool {
	return !f.gone && f.respawn <= 0 && f.y <= 0.01
}

Truffle :: struct {
	pos:     Vec2,
	visible: bool,
	taken:   bool,
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

add_wall :: proc(lo, hi: Vec2, height: f32, color: Color, gate := -1, style := Wall_Style.Brick) {
	g.walls[g.wall_count] = Wall{lo, hi, height, color, gate, style}
	g.wall_count += 1
}

// A walled room with an opening in the middle of its south side.
// If gate is not -1, that gate closes the opening.
add_room :: proc(centre, half: Vec2, gap: f32, color: Color, gate := -1) {
	T :: f32(0.5)
	H :: WALL_HEIGHT
	lo := centre - half
	hi := centre + half
	add_wall({lo.x, lo.y}, {hi.x, lo.y + T}, H, color)
	add_wall({lo.x, lo.y}, {lo.x + T, hi.y}, H, color)
	add_wall({hi.x - T, lo.y}, {hi.x, hi.y}, H, color)
	add_wall({lo.x, hi.y - T}, {centre.x - gap / 2, hi.y}, H, color)
	add_wall({centre.x + gap / 2, hi.y - T}, {hi.x, hi.y}, H, color)
	if gate >= 0 {
		add_wall({centre.x - gap / 2, hi.y - T + 0.1}, {centre.x + gap / 2, hi.y - 0.1}, H, COLOR_GATE, gate)
	}
}

add_round :: proc(pos: Vec2, r: f32, kind: Round_Kind) -> int {
	if g.round_count >= MAX_ROUNDS {
		return -1
	}
	g.rounds[g.round_count] = Round{pos = pos, r = r, kind = kind}
	g.round_count += 1
	return g.round_count - 1
}

// A tree: mostly broadleaves and pines, with some apple trees and blossoms.
add_tree :: proc(pos: Vec2, species: Maybe(Tree_Species) = nil) {
	i := add_round(pos, 0.32, .Tree)
	if i < 0 {
		return
	}
	t := &g.rounds[i]
	if fixed, ok := species.?; ok {
		t.species = fixed
	} else {
		roll := random()
		switch {
		case roll < 0.18:
			t.species = .Apple
		case roll < 0.3:
			t.species = .Blossom
		case roll < 0.62:
			t.species = .Pine
		case:
			t.species = .Broadleaf
		}
	}
	if t.species == .Apple {
		t.fruit = 2 + int(random() * 3)
		t.fruit_t = random_range(2, 8)
	}
}

// A berry bush, eaten from where it stands.
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

add_platform :: proc(lo, hi: Vec2, height: f32, ramp := false) -> int {
	g.platforms[g.platform_count] = Platform{lo, hi, height, ramp}
	g.platform_count += 1
	return g.platform_count - 1
}

build_world :: proc() {
	// Fence around the meadow.
	w := WORLD_HALF
	F :: f32(0.4)
	add_wall({-w.x - F, -w.y - F}, {w.x + F, -w.y}, 0.8, COLOR_FENCE, -1, .Fence)
	add_wall({-w.x - F, w.y}, {w.x + F, w.y + F}, 0.8, COLOR_FENCE, -1, .Fence)
	add_wall({-w.x - F, -w.y}, {-w.x, w.y}, 0.8, COLOR_FENCE, -1, .Fence)
	add_wall({w.x, -w.y}, {w.x + F, w.y}, 0.8, COLOR_FENCE, -1, .Fence)

	// The skinny shack: only a lean Prosio fits through its door.
	shack := Vec2{-24, -14}
	add_room(shack, {3.5, 3}, DOOR_GAP, COLOR_SHACK)
	g.door_pos = {shack.x, shack.y + 3 - 0.25}
	g.truffles[0] = {pos = shack + {0, -0.6}, visible = true}

	// The heavy vault: its gate opens when enough weight stands on the plate.
	vault := Vec2{22, -16}
	add_room(vault, {3.5, 3}, 2.6, COLOR_VAULT, 0)
	g.plate_pos = {vault.x, vault.y + 6.5}
	g.truffles[1] = {pos = vault + {0, -0.6}, visible = true}

	// The third truffle appears when the big boar is knocked out,
	// the fourth when the catapult's boulder smashes the crate.

	// The cage: its gate opens when the lever tips.
	cage := Vec2{36, 8}
	add_room(cage, {1.7, 1.7}, 1.7, COLOR_VAULT, 1)
	g.truffles[4] = {pos = cage + {0, -0.2}, visible = true}

	// Near the start: an apple tree, a berry bush and a few pumpkins.
	add_tree({3.6, 11.2}, Tree_Species.Apple)
	add_bush({-3.2, 9.6})
	add_food(.Pumpkin, {-1.5, 10.6})
	add_food(.Pumpkin, {1.2, 11.1})
	// And something to eat near each building.
	add_bush({-25, 4})
	add_food(.Pumpkin, {17, -7})
	add_bush({0, -4})

	trees := [?]Vec2{{-18, -12}, {-6, -12.5}, {5, -12}, {18, -12}, {-22.5, 2}, {13, 13.6}, {-8, 3}, {7.5, 5.5}, {-13, 12.5}, {12, 11.5}, {-3, -1}}
	for t in trees {
		add_tree(t)
	}
	rocks := [?]Vec3{{-5, 3.5, 0.7}, {5.5, 0.5, 0.9}, {-15, -11.5, 0.8}, {15.5, 4.5, 0.6}, {2.5, -7.5, 0.7}, {-10.5, 13.5, 0.55}}
	for r in rocks {
		add_round({r.x, r.y}, r.z, .Rock)
	}

	build_seesaws()
	spawn_enemies()

	// The rest of the meadow is filled at random, leaving the puzzles, the
	// start and the catapult's firing line clear.
	// Little woods: groves of trees standing close together, with bushes
	// round their edges and mushrooms in their shade.
	for grove := 0; grove < 9; {
		centre := random_spot()
		if !clear_spot(centre, 3.5) {
			continue
		}
		grove += 1
		count := 6 + int(random() * 5)
		for tries := 0; tries < 60 && count > 0; tries += 1 {
			a := random_range(0, math.TAU)
			pos := centre + Vec2{math.cos(a), math.sin(a)} * random_range(0, 4.8)
			if clear_spot(pos, 1.05) {
				add_tree(pos)
				count -= 1
			}
		}
		for k := 0; k < 2; k += 1 {
			a := random_range(0, math.TAU)
			pos := centre + Vec2{math.cos(a), math.sin(a)} * random_range(4.5, 6)
			if clear_spot(pos, 0.9) {
				add_bush(pos)
			}
		}
	}
	// Single trees all over the meadow.
	for placed := 0; placed < 26; {
		pos := random_spot()
		if clear_spot(pos, 1.8) {
			add_tree(pos)
			placed += 1
		}
	}
	for placed := 0; placed < 18; {
		pos := random_spot()
		if clear_spot(pos, 1.8) {
			add_round(pos, random_range(0.3, 0.6), .Rock)
			placed += 1
		}
	}
	for placed := 0; placed < 14; {
		pos := random_spot()
		if clear_spot(pos, 1.2) {
			add_bush(pos)
			placed += 1
		}
	}
	// Mushrooms in the shade of trees.
	for placed, tries := 0, 0; placed < 18 && tries < 400; tries += 1 {
		t := g.rounds[int(random() * f32(g.round_count)) % g.round_count]
		if t.kind != .Tree {
			continue
		}
		a := random_range(0, math.TAU)
		pos := t.pos + Vec2{math.cos(a), math.sin(a)} * random_range(0.75, 1.5)
		if clear_spot(pos, 0.3) {
			add_food(.Mushroom, pos)
			placed += 1
		}
	}
	// Pumpkin patches out in the open.
	for patch := 0; patch < 4; {
		centre := random_spot()
		if !clear_spot(centre, 2) {
			continue
		}
		patch += 1
		for k in 0 ..< 3 {
			a := f32(k) * 2.1 + random_range(0, 0.8)
			add_food(.Pumpkin, centre + Vec2{math.cos(a), math.sin(a)} * random_range(0.6, 1.1))
		}
	}
	for placed := 0; placed < 10; {
		pos := random_spot()
		if clear_spot(pos, 1.5) && length2(pos - g.prosio.pos) > 14 {
			add_enemy(.Fox, pos)
			placed += 1
		}
	}

	// Scatter tufts and flowers where nothing else stands.
	for g.decor_count < MAX_DECOR {
		pos := Vec2{random_range(-w.x + 0.5, w.x - 0.5), random_range(-w.y + 0.5, w.y - 0.5)}
		probe := pos
		if hit, _ := collide_static(&probe, 0.5, 0, true); hit {
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

// True if a spot is free: nothing solid within r, and not in an area that
// has to stay open.
clear_spot :: proc(pos: Vec2, r: f32) -> bool {
	Keep_Out :: struct {
		centre: Vec2,
		radius: f32,
	}
	catapult := g.seesaws[CATAPULT].pivot
	lever := g.seesaws[LEVER].pivot
	keep_out := [?]Keep_Out {
		{{0, 8}, 7}, // the start and the picnic
		{g.door_pos + {0, 2}, 4}, // in front of the skinny door
		{g.plate_pos, 5}, // the pressure plate and the vault's gate
		{catapult + {2, 1}, 10}, // catapult, tower, ramp and firing line
		{lever + {1, -3}, 7}, // lever and cage
		{{0, -22}, 4}, // the boar's patch
	}
	for k in keep_out {
		if length2(pos - k.centre) < k.radius + r {
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

platform_height :: proc(pl: ^Platform, pos: Vec2) -> f32 {
	if !pl.ramp {
		return pl.height
	}
	t := clamp((pl.hi.y - pos.y) / (pl.hi.y - pl.lo.y), 0, 1)
	return pl.height * t
}

inside :: proc(pos, lo, hi: Vec2) -> bool {
	return pos.x >= lo.x && pos.x <= hi.x && pos.y >= lo.y && pos.y <= hi.y
}

// The height of whatever is underfoot at a place, and which seesaw it is (or -1).
ground_at :: proc(pos: Vec2, platforms := true) -> (height: f32, seesaw: int) {
	seesaw = -1
	for i in 0 ..< (platforms ? g.platform_count : 0) {
		pl := &g.platforms[i]
		if inside(pos, pl.lo, pl.hi) {
			height = max(height, platform_height(pl, pos))
		}
	}
	for &s, i in g.seesaws {
		lo, hi := seesaw_rect(&s)
		if inside(pos, lo, hi) {
			h := plank_height(&s, seesaw_along(&s, pos))
			if h > height {
				height, seesaw = h, i
			}
		}
	}
	return
}

// Keeps a circle out of everything solid: walls, trees, rocks, food, platforms,
// seesaws and the edge of the world.
//
// feet is how high off the ground the circle is: things fly or jump over
// obstacles lower than that. Prosio can also stand on platforms and planks,
// so those only block him where they are too high to step onto, and the same
// goes for animals (enemy = true). Animals cannot climb the seesaw planks.
collide_static :: proc(pos: ^Vec2, r: f32, feet: f32, enemy := false) -> (hit: bool, normal: Vec2) {
	// Two passes, so a push out of one thing cannot leave the circle inside another.
	for _ in 0 ..< 2 {
		for i in 0 ..< g.wall_count {
			w := &g.walls[i]
			if w.gate >= 0 && g.gates[w.gate].open {
				continue
			}
			if feet >= w.height {
				continue
			}
			if h, n := push_out_box(pos, r, w.lo, w.hi); h {
				hit, normal = true, n
			}
		}
		for i in 0 ..< g.round_count {
			rd := &g.rounds[i]
			top: f32
			switch rd.kind {
			case .Tree:
				top = 3
			case .Rock:
				top = rd.r * 1.05
			case .Crate:
				top = 1.2
			case .Bush:
				top = 0.8
			}
			if feet >= top || rd.r <= 0 {
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
		if enemy {
			for &t in g.truffles {
				if t.visible && !t.taken && feet < 1 {
					if h, n := push_out_circle(pos, r, t.pos, 0.3); h {
						hit, normal = true, n
					}
				}
			}
		}
		for i in 0 ..< g.platform_count {
			if !enemy && g.prosio.dive {
				break // mid-dive he sails past the tower's edge
			}
			pl := &g.platforms[i]
			nearest := Vec2{clamp(pos.x, pl.lo.x, pl.hi.x), clamp(pos.y, pl.lo.y, pl.hi.y)}
			if length2(pos^ - nearest) >= r {
				continue
			}
			top := platform_height(pl, nearest)
			blocked := top > feet + STEP_UP // animals climb ramps and steps like Prosio
			if blocked {
				if h, n := push_out_box(pos, r, pl.lo, pl.hi); h {
					hit, normal = true, n
				}
			}
		}
		for &s in g.seesaws {
			lo, hi := seesaw_rect(&s)
			nearest := Vec2{clamp(pos.x, lo.x, hi.x), clamp(pos.y, lo.y, hi.y)}
			if length2(pos^ - nearest) < r {
				top := plank_height(&s, seesaw_along(&s, nearest))
				blocked := enemy ? feet < top + 0.5 : top > feet + STEP_UP
				if blocked {
					if h, n := push_out_box(pos, r, lo, hi); h {
						hit, normal = true, n
					}
				}
			}
			// The lever's iron weight is a solid block.
			if s.kind == .Lever && feet < 1.4 {
				block_lo, block_hi := iron_rect(&s)
				if h, n := push_out_box(pos, r, block_lo, block_hi); h {
					hit, normal = true, n
				}
			}
		}
		if g.boulder.state != .Flying && feet < g.boulder.y + 0.7 {
			if h, n := push_out_circle(pos, r, g.boulder.pos, BOULDER_RADIUS); h {
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
			// Falling, with a little bounce, then lying until it rots.
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
	for &gate in g.gates {
		target: f32 = gate.open ? 1 : 0
		gate.anim += clamp(target - gate.anim, -dt * 1.5, dt * 1.5)
	}
	g.shake = max(g.shake - dt * 2.5, 0)
	if g.truffle_count == len(g.truffles) {
		g.win_t += dt
	}
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
