package game

import "core:math"

GRAVITY :: f32(25)
STEP_UP :: f32(0.36) // the highest ledge Prosio can simply walk onto
DROP :: f32(0.4) // walking off anything taller than this is a fall

WORLD_HALF :: Vec2{44, 30} // the meadow reaches this far from the centre
WALL_HEIGHT :: f32(1.3) // taller than Prosio's highest jump
DOOR_GAP :: f32(1.2) // width of the skinny door
PLATE_KG :: f32(105) // weight needed on the pressure plate
FOOD_RESPAWN :: f32(7)
FOOD_RADIUS :: f32(0.16)
TOWER_HEIGHT :: f32(2.0) // the jumping tower next to the catapult

MAX_WALLS :: 32
MAX_ROUNDS :: 96
MAX_FOODS :: 24
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
}

// A round obstacle.
Round :: struct {
	pos:  Vec2,
	r:    f32,
	kind: Round_Kind,
}

// Something to stand on: a flat block, or a ramp that rises from its south
// edge (hi.y) to its north edge (lo.y).
Platform :: struct {
	lo, hi: Vec2,
	height: f32,
	ramp:   bool,
}

Food_Kind :: enum {
	Apple,
	Donut,
	Cake,
}

Food :: struct {
	kind:    Food_Kind,
	pos:     Vec2,
	respawn: f32, // seconds until it is back; 0 means it is there
}

FOOD_KG := [Food_Kind]f32 {
	.Apple = 3,
	.Donut = 8,
	.Cake  = 15,
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

add_round :: proc(pos: Vec2, r: f32, kind: Round_Kind) {
	g.rounds[g.round_count] = Round{pos, r, kind}
	g.round_count += 1
}

add_food :: proc(kind: Food_Kind, pos: Vec2) {
	g.foods[g.food_count] = Food{kind, pos, 0}
	g.food_count += 1
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

	// Picnic by the start, plus snacks near each building.
	add_food(.Donut, {-1.6, 10.2})
	add_food(.Apple, {0, 9.4})
	add_food(.Cake, {1.6, 10.2})
	add_food(.Apple, {-25, 4})
	add_food(.Donut, {17, -7})
	add_food(.Apple, {0, -4})

	trees := [?]Vec2{{-18, -12}, {-6, -12.5}, {5, -12}, {18, -12}, {-22.5, 2}, {13, 13.6}, {-8, 3}, {7.5, 5.5}, {-13, 12.5}, {12, 11.5}, {-3, -1}}
	for t in trees {
		add_round(t, 0.4, .Tree)
	}
	rocks := [?]Vec3{{-5, 3.5, 0.7}, {5.5, 0.5, 0.9}, {-15, -11.5, 0.8}, {15.5, 4.5, 0.6}, {2.5, -7.5, 0.7}, {-10.5, 13.5, 0.55}}
	for r in rocks {
		add_round({r.x, r.y}, r.z, .Rock)
	}

	build_seesaws()
	spawn_enemies()

	// The rest of the meadow is filled at random, leaving the puzzles, the
	// start and the catapult's firing line clear.
	for placed := 0; placed < 40; {
		pos := random_spot()
		if clear_spot(pos, 2.2) {
			add_round(pos, 0.4, .Tree)
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
			add_food(Food_Kind(placed % 3), pos)
			placed += 1
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
// so those only block him where they are too high to step onto. Enemies
// (enemy = true) cannot climb, so platforms and planks block them like walls.
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
			}
			if feet >= top || rd.r <= 0 {
				continue
			}
			if h, n := push_out_circle(pos, r, rd.pos, rd.r); h {
				hit, normal = true, n
			}
		}
		for &f in g.foods[:g.food_count] {
			if f.respawn > 0 || feet >= 0.8 {
				continue
			}
			if h, n := push_out_circle(pos, r, f.pos, FOOD_RADIUS); h {
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
			blocked := enemy ? (top > 0.25 && feet < top) : top > feet + STEP_UP
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
		if f.respawn > 0 {
			continue
		}
		d := length2(f.pos - pos)
		if d < best_dist {
			best, best_dist = &f, d
		}
	}
	return best
}

update_world :: proc(dt: f32) {
	for &f in g.foods[:g.food_count] {
		if f.respawn > 0 {
			f.respawn -= dt
			// Food does not pop back on top of someone standing there.
			if f.respawn <= 0 {
				crowded := length2(g.prosio.pos - f.pos) < prosio_radius(g.prosio.kg) + FOOD_RADIUS + 0.1
				for &e in g.enemies[:g.enemy_count] {
					if e.state != .Gone && length2(e.pos - f.pos) < ENEMY_RADIUS[e.kind] + FOOD_RADIUS + 0.1 {
						crowded = true
					}
				}
				if crowded {
					f.respawn = 0.3
				} else {
					f.respawn = 0
					burst({f.pos.x, 0.6, f.pos.y}, 8, 2.5, COLOR_STAR, 0.1)
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
