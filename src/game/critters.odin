package game

import "core:math"

// Small creatures that are not fought: the fish in the pond, the rabbits
// and crows that eat the crops, and the bees that guard their honey.

// Fish swim about the pond. They are shy of a pig on the move, but one that
// stands still on the bank makes them curious, and they drift over: then F
// grabs the nearest, if it is within reach.
MAX_FISH :: 6
FISH_BACK :: Vec2{240, 480} // seconds until another fish takes a caught one's place
FISH_REACH :: f32(1.25) // how far beyond himself he can grab one
FISH_FRIGHT :: Vec2{12, 22} // seconds a grab into the water keeps the fish away
FISH_SHY :: f32(4.5) // fish this near a moving Prosio dart away
FISH_CURIOUS :: f32(7) // fish this near a still one drift towards him

Fish :: struct {
	pos:    Vec2,
	facing: f32,
	turn:   f32, // which way it is curving
	turn_t: f32,
	dart_t: f32, // darting away for this long
	shy_t:  f32, // keeping its distance for this long, after a fright
	away_t: f32, // caught: time until another comes
	size:   f32,
}

spawn_fish :: proc() {
	for &f, i in g.fish {
		f = Fish {
			pos    = POND + facing_dir(f32(i) * 1.1) * random_range(1, POND_RADIUS - 2.5),
			facing = random_range(0, math.TAU),
			size   = random_size(),
		}
	}
}

update_fish :: proc(dt: f32) {
	p := &g.prosio
	waiting := pond_in_reach(p.pos, prosio_radius(p.kg)) && length2(p.vel) < 0.5
	for &f in g.fish {
		if f.away_t > 0 {
			f.away_t -= dt
			if f.away_t <= 0 {
				f.pos = POND + facing_dir(random_range(0, math.TAU)) * random_range(0, 2)
				f.size = random_size()
			}
			continue
		}
		f.turn_t -= dt
		f.dart_t -= dt
		f.shy_t -= dt
		if f.turn_t <= 0 {
			f.turn_t = random_range(1, 3)
			f.turn = random_range(-0.9, 0.9)
		}
		to_him := p.pos - f.pos
		if length2(to_him) < FISH_SHY && length2(p.vel) > 1.5 {
			f.dart_t = 0.8
		}
		speed: f32 = 0.9
		switch {
		case f.dart_t > 0:
			speed = 3.2
			f.facing = approach_angle(f.facing, math.atan2(-to_him.x, -to_him.y), 8 * dt)
		case f.shy_t > 0 && length2(to_him) < FISH_SHY:
			f.facing = approach_angle(f.facing, math.atan2(-to_him.x, -to_him.y), 2 * dt)
		case waiting && f.shy_t <= 0 && length2(to_him) < FISH_CURIOUS:
			speed = 0.6
			f.facing = approach_angle(f.facing, math.atan2(to_him.x, to_him.y), 1.2 * dt)
		case:
			f.facing += f.turn * dt
		}
		// Keep to the water: near the bank, turn back towards the middle.
		out := f.pos - POND
		if length2(out) > POND_RADIUS - 1.2 {
			f.facing = approach_angle(f.facing, math.atan2(-out.x, -out.y), 4 * dt)
			speed = min(speed, 0.5)
		}
		f.pos += facing_dir(f.facing) * speed * dt
	}
}

// The nearest fish, and how far it is from him.
nearest_fish :: proc() -> (best: ^Fish, dist: f32) {
	dist = 1e9
	for &f in g.fish {
		if d := length2(f.pos - g.prosio.pos); f.away_t <= 0 && d < dist {
			best, dist = &f, d
		}
	}
	return
}

// With his rod chosen in the sack, F at the pond casts it.
rod_chosen :: proc() -> bool {
	return g.prosio.sack_sel == .Rod && g.prosio.sack[.Rod] > 0
}

// How far beyond himself he can get a fish: by hoof, or with the rod.
fish_reach :: proc() -> f32 {
	return rod_chosen() ? ROD_REACH : FISH_REACH * deft_reach()
}

fish_in_reach :: proc() -> bool {
	_, dist := nearest_fish()
	return dist < prosio_radius(g.prosio.kg) + fish_reach()
}

// F at the pond: a grab into the water, or a cast of the rod. The rod
// reaches much further, and the other fish take no fright at it.
grab_fish :: proc() {
	p := &g.prosio
	rod := rod_chosen()
	to := POND - p.pos
	p.facing = math.atan2(to.x, to.y)
	p.pick_t = pick_time()
	p.pick_total = p.pick_t
	train(.Hooves, FISH_WORK)
	p.drinking = true // his hoof comes up empty, unless he gets one
	p.vel = {}
	burn(GATHER_BURN, .Gathering)
	fish, dist := nearest_fish()
	at := p.pos + normalize2(to) * (prosio_radius(p.kg) + 0.6)
	if rod {
		at = p.pos + normalize2(to) * (prosio_radius(p.kg) + ROD_REACH * 0.7)
	}
	if fish != nil && dist < prosio_radius(p.kg) + fish_reach() {
		at = fish.pos
		if sack_room(.Fish) < 1 {
			answer("No room in my sack for more fish!")
		} else {
			sack_add(.Fish, math.round(RAW_KCAL[.Fish] * fish.size))
			fish.away_t = random_range(FISH_BACK.x, FISH_BACK.y)
			p.pick_item = .Fish
			p.drinking = false
			say(rod ? "A bite! Got one on the line!" : "Got one! A slippery fish!", 1.4)
		}
	} else {
		say(rod ? "No bite... they are too far out. I'll wait." : "Splash! Missed... they come close if I stand still.", 2)
	}
	p.casting = rod
	p.cast_at = at
	burst({at.x, 0.2, at.y}, rod ? 4 : 12, rod ? 1.5 : 2.5, POND_SPLASH, 0.08)
	// The others have had a fright (a float on a line frightens nobody).
	for &f in g.fish {
		if !rod && length2(f.pos - p.pos) < 8 {
			f.dart_t = 1.5
			f.shy_t = random_range(FISH_FRIGHT.x, FISH_FRIGHT.y)
		}
	}
}

FISH_ORANGE :: Color{240, 136, 64, 255}

// Seen through the water: flat, with a tail that beats as it swims.
draw_fish :: proc() {
	if !on_screen(POND, POND_RADIUS) {
		return
	}
	for f, i in g.fish {
		if f.away_t > 0 {
			continue
		}
		m := translate({f.pos.x, 0.03, f.pos.y}) * rot_y(f.facing) * scale({f.size, 1, f.size})
		beat := math.sin(g.time * (f.dart_t > 0 ? 22 : 7) + f32(i)) * 0.5
		ball(m, {}, {0.11, 0.02, 0.27}, FISH_ORANGE)
		ball(m, {0, 0.012, 0.06}, {0.07, 0.012, 0.1}, COLOR_WHITE)
		tail := m * translate({0, 0, -0.24}) * rot_y(beat)
		ball(tail, {0, 0, -0.1}, {0.09, 0.015, 0.12}, shade(FISH_ORANGE, 0.85))
	}
}

// Rabbits (in the garden) and crows (over the wheat) eat what is left
// standing. Now and then one comes out for a crop that is nearly ripe and
// eats it down: not away altogether, but back to a smaller size. They run
// from Prosio, from his wind and from a stone. A crow will not come to wheat
// with a scarecrow near it, nor a rabbit to anything fenced in (see
// crop_guarded in workshop.odin).
Pest_Kind :: enum {
	Rabbit,
	Crow,
}

Pest_State :: enum {
	Away, // a rabbit down its burrow, a crow circling high up
	Coming,
	Eating,
	Fleeing,
}

Pest :: struct {
	kind:   Pest_Kind,
	state:  Pest_State,
	pos:    Vec2,
	home:   Vec2,
	y:      f32, // a crow's height
	facing: f32,
	t:      f32, // until it comes out, or done eating
	food:   int, // which crop it is after
	hop:    f32,
	stoned: bool, // driven off with a stone: it stays away longer
}

MAX_PESTS :: 4
PEST_AWAY :: Vec2{50, 150} // seconds between raids
PEST_SPEED := [Pest_Kind]f32{.Rabbit = 3.2, .Crow = 5}
PEST_FLEE := [Pest_Kind]f32{.Rabbit = 7.5, .Crow = 8}
PEST_SCARE := [Pest_Kind]f32{.Rabbit = 4.5, .Crow = 6} // how near Prosio can get
PEST_CROP := [Pest_Kind]Food_Kind{.Rabbit = .Cabbage, .Crow = .Wheat}
RIPE_ENOUGH :: f32(0.6) // they leave anything smaller alone
NIBBLE :: f32(0.7) // how much of a crop's growth one raid eats
NIBBLE_TIME :: f32(14) // and how long that takes
CROW_HEIGHT :: f32(4)

spawn_pests :: proc() {
	homes := [MAX_PESTS]Vec2{{-23, 58.5}, {-8.5, 55.5}, {64, 14}, {43, 30}}
	for &c, i in g.pests {
		c = Pest {
			kind = i < 2 ? .Rabbit : .Crow,
			pos  = homes[i],
			home = homes[i],
			t    = random_range(20, PEST_AWAY.y),
		}
		c.y = c.kind == .Crow ? CROW_HEIGHT : 0
	}
}

// A crop worth a raid: nearly ripe, nobody else's, and Prosio not beside it.
pest_target :: proc(c: ^Pest) -> int {
	best := -1
	best_dist := f32(1e9)
	for &f, i in g.foods[:g.food_count] {
		if f.kind != PEST_CROP[c.kind] || !food_ready(&f) || f.grow < RIPE_ENOUGH || length2(f.pos - g.prosio.pos) < 9 || crop_guarded(c.kind, f.pos) {
			continue
		}
		taken := false
		for &o in g.pests {
			if &o != c && o.state != .Away && o.food == i {
				taken = true
			}
		}
		if d := length2(f.pos - c.pos); !taken && d < best_dist {
			best, best_dist = i, d
		}
	}
	return best
}

// A stone passing or landing this near sends a rabbit or a crow off, and it
// stays away STONED_AWAY times as long as it would have.
STONE_SCARE :: f32(2.5)
STONED_AWAY :: f32(2.5)
PEST_HEARD :: f32(50) // from this far off he hears one start on his crops

scare_pests_near :: proc(pos: Vec2, y: f32) {
	for &c in g.pests {
		if (c.state != .Coming && c.state != .Eating) || length2(c.pos - pos) > STONE_SCARE || abs(c.y - y) > 3 {
			continue
		}
		c.state = .Fleeing
		c.stoned = true
		say(c.kind == .Crow ? "Shoo, crow! And stay away!" : "Shoo, rabbit! And stay away!", 1.4)
	}
}

scare_pest :: proc(c: ^Pest) {
	if c.state == .Coming || c.state == .Eating {
		c.state = .Fleeing
	}
}

update_pests :: proc(dt: f32) {
	p := &g.prosio
	for &c, i in g.pests {
		near := length2(p.pos - c.pos) < PEST_SCARE[c.kind] && p.fail == .None
		c.hop += dt * 10
		switch c.state {
		case .Away:
			if c.kind == .Crow {
				// Circling over its corner of the fields.
				a := g.time * 0.5 + f32(i) * 2
				c.pos = c.home + Vec2{math.cos(a), math.sin(a)} * 3
				c.facing = math.atan2(-math.sin(a), math.cos(a))
				c.y = CROW_HEIGHT
			}
			c.t -= dt
			if c.t <= 0 {
				c.food = pest_target(&c)
				if c.food >= 0 {
					c.state = .Coming
				} else {
					c.t = 20
				}
			}
		case .Coming:
			food := &g.foods[c.food]
			if near || !food_ready(food) {
				if near {
					hint(c.kind == .Rabbit ? "Shoo, rabbit! Not my cabbages!" : "Shoo, crow! Not my wheat!")
				}
				c.state = .Fleeing
				continue
			}
			to := food.pos - c.pos
			dist := length2(to)
			c.facing = math.atan2(to.x, to.y)
			c.pos += normalize2(to) * min(PEST_SPEED[c.kind] * dt, dist)
			if c.kind == .Crow {
				c.y = min(CROW_HEIGHT, 0.45 + dist * 0.6)
			}
			if dist < 0.35 {
				c.state = .Eating
				c.t = NIBBLE_TIME
				if length2(p.pos - c.pos) < PEST_HEARD {
					hint(c.kind == .Crow ? "Caw, caw! A crow is at my wheat!" : "Rustle, rustle... a rabbit is at my cabbages!")
				}
			}
		case .Eating:
			food := &g.foods[c.food]
			if near {
				hint(c.kind == .Rabbit ? "Shoo, rabbit! Not my cabbages!" : "Shoo, crow! Not my wheat!")
			}
			c.t -= dt
			if near || c.t <= 0 || !food_ready(food) {
				c.state = .Fleeing
				continue
			}
			food.grow = max(food.grow - NIBBLE / NIBBLE_TIME * dt, 0.1)
			if math.mod(c.hop, 6) < 10 * dt {
				burst({food.pos.x, 0.4, food.pos.y}, 2, 1.2, COLOR_LEAF_LIGHT, 0.05)
			}
		case .Fleeing:
			to := c.home - c.pos
			dist := length2(to)
			c.facing = math.atan2(to.x, to.y)
			c.pos += normalize2(to) * min(PEST_FLEE[c.kind] * dt, dist)
			if c.kind == .Crow {
				c.y = min(c.y + 4 * dt, CROW_HEIGHT)
			}
			if dist < 0.3 {
				c.state = .Away
				c.t = random_range(PEST_AWAY.x, PEST_AWAY.y) * (c.stoned ? STONED_AWAY : 1)
				c.stoned = false
			}
		}
	}
}

RABBIT_COAT :: Color{184, 160, 138, 255}
CROW_BLACK :: Color{52, 50, 62, 255}

draw_pests :: proc() {
	for c, i in g.pests {
		if c.kind == .Rabbit {
			// The burrow is always there: a dark hole in a little mound.
			if on_screen(c.home, 1) {
				hole := translate({c.home.x, 0, c.home.y})
				ball(hole, {0, 0.02, 0}, {0.5, 0.12, 0.42}, {150, 116, 84, 255})
				ball(hole, {0, 0.08, 0.1}, {0.24, 0.08, 0.2}, {52, 40, 36, 255})
			}
			if c.state == .Away {
				continue
			}
		}
		if !on_screen(c.pos, 2) {
			continue
		}
		moving := c.state == .Coming || c.state == .Fleeing
		switch c.kind {
		case .Rabbit:
			hop: f32 = moving ? abs(math.sin(c.hop)) * 0.22 : 0
			m := translate({c.pos.x, hop, c.pos.y}) * rot_y(c.facing)
			ball(m, {0, 0.17, -0.04}, {0.15, 0.15, 0.2}, RABBIT_COAT)
			ball(m, {0, 0.17, -0.24}, {0.07, 0.07, 0.07}, COLOR_WHITE)
			nod: f32 = c.state == .Eating ? 0.05 * math.sin(c.hop * 1.5) : 0
			h := m * translate({0, 0.3 + nod, 0.16})
			ball(h, {}, {0.12, 0.11, 0.12}, RABBIT_COAT)
			for side in ([2]f32{-1, 1}) {
				ear := h * translate({side * 0.05, 0.08, -0.03}) * rot_z(-side * 0.2) * rot_x(-0.3)
				ball(ear, {0, 0.13, 0}, {0.035, 0.14, 0.025}, RABBIT_COAT)
				ball(ear, {0, 0.13, 0.015}, {0.018, 0.1, 0.012}, ANIMAL_BLUSH)
				draw_cute_eye(h * translate({side * 0.075, 0.02, 0.08}) * rot_y(side * 0.6), 0.035, false)
			}
			ball(h, {0, -0.02, 0.115}, {0.025, 0.02, 0.02}, ANIMAL_BLUSH)
		case .Crow:
			flying := c.y > 0.5
			m := translate({c.pos.x, c.y, c.pos.y}) * rot_y(c.facing)
			peck: f32 = c.state == .Eating ? 0.5 * max(math.sin(c.hop), 0) : 0
			m = m * rot_x(peck)
			ball(m, {0, 0.2, 0}, {0.14, 0.14, 0.22}, CROW_BLACK)
			ball(m, {0, 0.34, 0.18}, {0.1, 0.1, 0.1}, CROW_BLACK)
			draw_shape(.Cone, m * translate({0, 0.33, 0.26}) * rot_x(math.PI / 2) * scale({0.04, 0.14, 0.04}), BEAK)
			ball(m, {0, 0.2, -0.26}, {0.08, 0.03, 0.14}, CROW_BLACK)
			flap: f32 = flying ? math.sin(g.time * 14 + f32(i)) * 0.7 : -1.1
			for side in ([2]f32{-1, 1}) {
				wing := m * translate({side * 0.1, 0.25, 0}) * rot_z(side * flap)
				ball(wing, {side * 0.2, 0, 0}, {0.22, 0.025, 0.14}, CROW_BLACK)
				ball(m, {side * 0.055, 0.37, 0.25}, {0.02, 0.02, 0.02}, COLOR_WHITE)
			}
		}
	}
}

// Bees. Each hive in the bee meadow has a swarm that minds its own business
// until Prosio comes close: then it is after him, stinging, until he has
// been out of its reach for a while. His wind sends bees back into the hive
// and keeps them quiet for a time, and with enough fat on him the stings
// hardly hurt.
MAX_HIVES :: 3
MAX_HONEY :: 2 // combs in one hive
HONEY_REGROW :: Vec2{240, 480} // seconds until the bees have made another
HIVE_RADIUS :: f32(0.42)
HIVE_GUARD :: f32(3.6) // nearer the hive than this, and they come out
BEE_SPEED :: f32(6.2) // faster than he walks, slower than a lean sprint
BEE_ANGRY :: f32(5) // seconds they stay after him once he is clear
BEE_LEASH :: f32(32) // they give up this far from the hive
STING_EVERY :: f32(0.7)
GAS_CALM :: f32(14) // seconds his wind keeps a hive quiet

Hive :: struct {
	round:   int, // the hive itself, in the world's round things
	swarm:   Vec2,
	angry_t: f32,
	sting_t: f32,
	calm_t:  f32,
}

add_hive :: proc(index: int, pos: Vec2) {
	i := add_round(pos, HIVE_RADIUS, .Hive)
	g.rounds[i].fruit = 1 + index % MAX_HONEY
	g.rounds[i].fruit_t = random_range(HONEY_REGROW.x, HONEY_REGROW.y)
	g.rounds[i].ripe = 1
	g.hives[index] = Hive{round = i, swarm = pos}
}

update_bees :: proc(dt: f32) {
	p := &g.prosio
	for &h in g.hives {
		hive := g.rounds[h.round].pos
		h.calm_t -= dt
		if length2(p.pos - hive) < HIVE_GUARD && h.calm_t <= 0 && p.fail == .None {
			if h.angry_t <= 0 {
				say("Uh oh... BEES!", 1.2)
			}
			h.angry_t = BEE_ANGRY
		}
		if h.angry_t <= 0 || length2(h.swarm - hive) > BEE_LEASH || p.fail != .None {
			// Home again.
			h.angry_t = 0
			h.swarm = approach2(h.swarm, hive, BEE_SPEED * 0.6 * dt)
			continue
		}
		h.angry_t -= dt
		h.swarm = approach2(h.swarm, p.pos, BEE_SPEED * dt)
		if length2(h.swarm - p.pos) < 0.7 {
			h.sting_t -= dt
			if h.sting_t <= 0 {
				h.sting_t = STING_EVERY
				felt := knock()
				bruise(BRUISE_STING * felt)
				train(.Hide, STING_WORK)
				p.stamina = max(p.stamina - 4 * felt, 0)
				p.regen_delay = 0.4
				p.wobble_vel += 2
				g.shake = max(g.shake, 0.1)
				say(felt < 0.7 ? "Ha! I hardly feel them!" : "Ow! Ow! Bees!", 0.7)
				burst({p.pos.x, p.height + 1.4, p.pos.y}, 3, 2, COLOR_STAR, 0.06)
			}
		}
	}
}

// His wind reaches the bees: back into the hive with them.
calm_bees :: proc() {
	p := &g.prosio
	for &h in g.hives {
		if length2(h.swarm - p.pos) < gas_reach() || length2(g.rounds[h.round].pos - p.pos) < gas_reach() {
			h.angry_t = 0
			h.calm_t = GAS_CALM
		}
	}
}

HIVE_STRAW :: Color{226, 182, 96, 255}
HONEY_GOLD :: Color{246, 190, 60, 255}

// A straw hive on a stump, honey running from its door when there is some
// to take.
draw_hive :: proc(r: Round, index: int) {
	m := translate({r.pos.x, 0, r.pos.y})
	set_surface(.Bark)
	tube(m, {}, 0.34, 0.4, COLOR_TRUNK)
	set_surface(.Solid)
	for k in 0 ..< 5 {
		ring := 0.4 - 0.065 * f32(k)
		ball(m, {0, 0.5 + 0.17 * f32(k), 0}, {ring, 0.13, ring}, k % 2 == 0 ? HIVE_STRAW : shade(HIVE_STRAW, 0.88))
	}
	ball(m, {0, 0.52, 0.36}, {0.1, 0.09, 0.05}, {70, 50, 40, 255})
	for k in 0 ..< r.fruit {
		ball(m, {(f32(k) - 0.5) * 0.14, 0.42 - 0.03 * f32(k), 0.4}, {0.05, 0.08, 0.04}, HONEY_GOLD)
	}
}

draw_bees :: proc() {
	outlines_enabled = false
	for h, i in g.hives {
		if !on_screen(h.swarm, 2) {
			continue
		}
		angry := h.angry_t > 0
		at_home := length2(h.swarm - g.rounds[h.round].pos) < 0.3
		if at_home && h.calm_t > 0 {
			continue // smoked into the hive
		}
		for k in 0 ..< 9 {
			a := g.time * (angry ? 11 : 4) + f32(k) * 0.7 + f32(i)
			wide: f32 = (angry ? 0.35 : 0.6) + 0.12 * math.sin(a * 1.7 + f32(k))
			at := Vec3{h.swarm.x + math.cos(a) * wide, 1.1 + 0.35 * math.sin(a * 1.3 + f32(k) * 2), h.swarm.y + math.sin(a) * wide}
			ball(IDENTITY, at, {0.05, 0.045, 0.05}, HONEY_GOLD)
			ball(IDENTITY, at + {0.02, 0, 0.02}, {0.03, 0.03, 0.03}, ANIMAL_INK)
		}
	}
	outlines_enabled = true
}

update_critters :: proc(dt: f32) {
	update_fish(dt)
	update_pests(dt)
	update_bees(dt)
}
