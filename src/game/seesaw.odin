package game

import "core:math"

// Seesaws are real levers: a plank that turns on a pivot.
//
// Each one keeps an angle and a turning speed. Three things turn it:
//
//   weight   everything on the plank pulls its side down with
//            weight x distance from the pivot;
//   landing  when Prosio lands on it, his momentum (weight x falling speed
//            x distance from the pivot) is shared with the plank and what
//            is on it. Falling from higher means more speed, so both his
//            weight and the height of the jump count;
//   stops    a plank end that reaches the ground stops dead.
//
// How easily the plank turns depends on how much mass sits how far out
// (weight x distance squared), which is why a heavy load is hard to shift.
//
//   Catapult: Prosio's arm is short and the boulder's is long, so the boulder
//             end moves much faster than he does. When his end hits the
//             ground the boulder flies off at the speed its end was moving.
//   Lever:    a big iron weight sits close to the pivot. Standing on the far
//             end is not enough; a jump there adds the kick that tips it.

PLANK_HALF_WIDTH :: f32(0.9)
PLANK_KG :: f32(12)
BOULDER_KG :: f32(15)
BOULDER_RADIUS :: f32(0.42)
IRON_KG :: f32(520)
THROW_ANGLE :: f32(0.87) // the cup tilts the boulder's flight about 50 degrees up
MIN_THROW :: f32(1.5) // slower than this and the boulder stays in its cup
CRATE_HIT_RADIUS :: f32(1.15)
PAD_DISTANCE :: f32(0.85) // the catapult's landing pad, measured from the pivot
AIM_KG :: f32(88) // the crate stands where a jump at this weight throws the boulder

Seesaw_Kind :: enum {
	Catapult,
	Lever,
}

Seesaw :: struct {
	kind:      Seesaw_Kind,
	pivot:     Vec2,
	dir:       f32, // +1 if Prosio's end points east, -1 if west
	arm_a:     f32, // plank length on Prosio's side
	arm_b:     f32, // plank length on the load's side
	load_kg:   f32,
	load_arm:  f32, // how far from the pivot the load sits
	pivot_h:   f32, // height of the pivot above the ground
	angle:     f32, // tilt; positive means Prosio's end is down
	spin:      f32, // turning speed
	min_angle: f32,
	max_angle: f32,
	gate:      int, // lever: the gate it opens
}

Boulder_State :: enum {
	On_Seesaw,
	Flying,
	Landed,
}

Boulder :: struct {
	state: Boulder_State,
	pos:   Vec2,
	vel:   Vec2,
	y, vy: f32,
	spin:  f32,
	timer: f32,
}

CATAPULT :: 0
LEVER :: 1

build_seesaws :: proc() {
	c := &g.seesaws[CATAPULT]
	c^ = Seesaw {
		kind     = .Catapult,
		pivot    = {-30, 12},
		dir      = -1,
		arm_a    = 1.2,
		arm_b    = 3.0,
		load_kg  = BOULDER_KG,
		load_arm = 2.5,
		pivot_h  = 0.5,
	}
	c.max_angle = math.asin(c.pivot_h / c.arm_a)
	c.min_angle = -math.asin(c.pivot_h / c.arm_b)
	c.angle = c.min_angle

	l := &g.seesaws[LEVER]
	l^ = Seesaw {
		kind     = .Lever,
		pivot    = {33.5, 13.5},
		dir      = 1,
		arm_a    = 3.2,
		arm_b    = 1.3,
		load_kg  = IRON_KG,
		load_arm = 0.8,
		pivot_h  = 0.22,
		gate     = 1,
	}
	l.max_angle = math.asin(l.pivot_h / l.arm_a)
	l.min_angle = -0.04 // the iron weight rests on a block
	l.angle = l.min_angle

	// The jumping tower stands at the catapult's short end, with a ramp up
	// its south side.
	end := c.pivot.x + c.dir * c.arm_a
	// It stands far enough back that even the biggest Prosio fits on the pad.
	tower_lo := Vec2{end - 2.7, c.pivot.y - 1}
	tower_hi := Vec2{end - 0.7, c.pivot.y + 1}
	g.tower = add_platform(tower_lo, tower_hi, TOWER_HEIGHT)
	add_platform({tower_lo.x, tower_hi.y}, {tower_hi.x, tower_hi.y + 4}, TOWER_HEIGHT, true)

	// The crate stands where a well-fed Prosio's jump throws the boulder.
	g.boulder.pos = boulder_rest_pos()
	g.crate_pos = boulder_release_pos() + {-c.dir * predict_throw(AIM_KG), 0}
	g.crate_round = add_round(g.crate_pos, 0.8, .Crate)
}

// Distance along the plank from the pivot; positive is Prosio's side.
seesaw_along :: proc(s: ^Seesaw, pos: Vec2) -> f32 {
	return (pos.x - s.pivot.x) * s.dir
}

// The patch of ground the plank covers.
seesaw_rect :: proc(s: ^Seesaw) -> (lo, hi: Vec2) {
	x0 := s.pivot.x + s.dir * s.arm_a
	x1 := s.pivot.x - s.dir * s.arm_b
	lo = {min(x0, x1), s.pivot.y - PLANK_HALF_WIDTH}
	hi = {max(x0, x1), s.pivot.y + PLANK_HALF_WIDTH}
	return
}

// The patch of ground the lever's iron weight covers.
iron_rect :: proc(s: ^Seesaw) -> (lo, hi: Vec2) {
	x0 := s.pivot.x - s.dir * (s.load_arm - 0.5)
	x1 := s.pivot.x - s.dir * (s.load_arm + 0.5)
	lo = {min(x0, x1), s.pivot.y - 0.7}
	hi = {max(x0, x1), s.pivot.y + 0.7}
	return
}

// Height of the top of the plank at a distance along it.
plank_height :: proc(s: ^Seesaw, along: f32) -> f32 {
	return max(s.pivot_h - along * math.sin(s.angle), 0) + 0.07
}

// How hard the bare plank is to turn, and which way its own weight pulls.
plank_inertia :: proc(s: ^Seesaw) -> f32 {
	a, b := s.arm_a, s.arm_b
	return PLANK_KG * (a * a * a + b * b * b) / (3 * (a + b))
}

plank_pull :: proc(s: ^Seesaw) -> f32 {
	return PLANK_KG * (s.arm_a - s.arm_b) / 2
}

has_load :: proc(s: ^Seesaw) -> bool {
	return s.kind == .Lever || g.boulder.state == .On_Seesaw
}

// Where the boulder sits on the catapult, and where it leaves from.
boulder_rest_pos :: proc() -> Vec2 {
	s := &g.seesaws[CATAPULT]
	return s.pivot - {s.dir * s.load_arm, 0}
}

boulder_release_pos :: proc() -> Vec2 {
	s := &g.seesaws[CATAPULT]
	return s.pivot - {s.dir * s.load_arm * math.cos(s.max_angle), 0}
}

// The middle of the catapult's landing pad.
catapult_pad :: proc() -> Vec2 {
	s := &g.seesaws[CATAPULT]
	return s.pivot + {s.dir * PAD_DISTANCE, 0}
}

// Height of the pad while the catapult is loaded and waiting.
pad_rest_height :: proc() -> f32 {
	s := &g.seesaws[CATAPULT]
	return s.pivot_h - PAD_DISTANCE * math.sin(s.min_angle) + 0.07
}

on_tower :: proc(pos: Vec2, height: f32) -> bool {
	pl := &g.platforms[g.tower]
	return inside(pos, pl.lo, pl.hi) && height > TOWER_HEIGHT - 0.1
}

// How far a boulder leaving the cup at this speed travels.
throw_range :: proc(speed: f32) -> f32 {
	s := &g.seesaws[CATAPULT]
	start_height := s.pivot_h + s.load_arm * math.sin(s.max_angle)
	vx := speed * math.cos(THROW_ANGLE)
	vy := speed * math.sin(THROW_ANGLE)
	air_time := (vy + math.sqrt(vy * vy + 2 * GRAVITY * start_height)) / GRAVITY
	return vx * air_time
}

// How far the catapult would throw if Prosio jumped off the tower at this
// weight. It follows the same steps as the real thing: fall, landing kick,
// swing, release. Zero means the boulder would stay in its cup.
predict_throw :: proc(kg: f32) -> f32 {
	s := &g.seesaws[CATAPULT]
	fall := TOWER_HEIGHT + jump_height(kg) - pad_rest_height()
	landing_speed := math.sqrt(2 * GRAVITY * fall)

	loaded := plank_inertia(s) + s.load_kg * s.load_arm * s.load_arm
	with_prosio := loaded + kg * PAD_DISTANCE * PAD_DISTANCE
	spin := kg * landing_speed * PAD_DISTANCE / with_prosio

	// His weight keeps pushing (or the boulder keeps resisting) through the swing.
	pull := plank_pull(s) + kg * PAD_DISTANCE - s.load_kg * s.load_arm
	spin_squared := spin * spin + 2 * GRAVITY * pull * (s.max_angle - s.min_angle) / with_prosio
	if spin_squared <= 0 {
		return 0
	}
	speed := s.load_arm * math.sqrt(spin_squared)
	if speed < MIN_THROW {
		return 0
	}
	return throw_range(speed)
}

// Prosio lands on a plank: his momentum is shared with it.
seesaw_impact :: proc(index: int, landing_speed: f32) {
	s := &g.seesaws[index]
	p := &g.prosio
	along := seesaw_along(s, p.pos)
	if s.kind == .Catapult && along > 0 {
		// Anywhere on the short end counts as the pad, and he ends up on it.
		along = PAD_DISTANCE
		p.pos = catapult_pad()
		p.vel = {}
	}
	before := plank_inertia(s)
	if has_load(s) {
		before += s.load_kg * s.load_arm * s.load_arm
	}
	after := before + total_kg() * along * along
	s.spin = (before * s.spin + total_kg() * landing_speed * along) / after
}

update_seesaws :: proc(dt: f32) {
	p := &g.prosio

	for &s, index in g.seesaws {
		riding := !p.airborne && p.on_seesaw == index
		along := seesaw_along(&s, p.pos)

		// Weights pull each side down; mass far from the pivot makes it sluggish.
		inertia := plank_inertia(&s)
		pull := plank_pull(&s)
		if has_load(&s) {
			inertia += s.load_kg * s.load_arm * s.load_arm
			pull -= s.load_kg * s.load_arm
		}
		if riding {
			inertia += total_kg() * along * along
			pull += total_kg() * along
		}
		s.spin += GRAVITY * pull / inertia * dt
		s.angle += s.spin * dt

		if s.angle >= s.max_angle {
			// Prosio's end hits the ground.
			hit := s.spin
			s.angle = s.max_angle
			s.spin = 0
			if hit > 0.05 {
				g.shake = max(g.shake, min(hit * 0.12, 0.6))
				end := s.pivot + {s.dir * s.arm_a, 0}
				burst({end.x, 0.1, end.y}, 8, 2.5, COLOR_DUST, 0.12)
				switch s.kind {
				case .Catapult:
					speed := s.load_arm * hit
					if g.boulder.state == .On_Seesaw && speed >= MIN_THROW {
						throw_boulder(speed)
					}
				case .Lever:
					if !g.gates[s.gate].open {
						g.gates[s.gate].open = true
						say("CLUNK! It tipped!", 2)
					}
				}
			}
		}
		if s.angle <= s.min_angle {
			s.angle = s.min_angle
			s.spin = 0
		}

		if riding && s.kind == .Lever && along > 0 && !g.gates[s.gate].open && s.angle <= s.min_angle {
			if along < s.arm_a * 0.75 {
				hint("Further from the middle pushes harder!")
			} else {
				hint("Standing is not enough. Jump!")
			}
		}
	}

	update_boulder(dt)
}

throw_boulder :: proc(speed: f32) {
	s := &g.seesaws[CATAPULT]
	b := &g.boulder
	b.state = .Flying
	b.pos = boulder_release_pos()
	b.y = s.pivot_h + s.load_arm * math.sin(s.max_angle)
	b.vel = {-s.dir * speed * math.cos(THROW_ANGLE), 0}
	b.vy = speed * math.sin(THROW_ANGLE)
	say("WHEEE!", 1)
}

update_boulder :: proc(dt: f32) {
	s := &g.seesaws[CATAPULT]
	b := &g.boulder
	switch b.state {
	case .On_Seesaw:
		b.pos = s.pivot - {s.dir * s.load_arm * math.cos(s.angle), 0}
		b.y = plank_height(s, -s.load_arm)
		b.vel = {}

	case .Flying:
		b.vy -= GRAVITY * dt
		b.y += b.vy * dt
		b.pos += b.vel * dt
		b.spin += length2(b.vel) * dt
		if b.y <= 0 {
			b.y = 0
			// It must not come to rest inside anything; the crate is judged on
			// where it actually came down.
			landed_at := b.pos
			collide_static(&b.pos, BOULDER_RADIUS, 0, true)
			b.state = .Landed
			b.timer = 1.6
			g.shake = max(g.shake, 0.5)
			burst({b.pos.x, 0.2, b.pos.y}, 14, 4, COLOR_DUST, 0.16)

			if !g.crate_broken && length2(landed_at - g.crate_pos) < CRATE_HIT_RADIUS {
				smash_crate()
			} else if !g.crate_broken {
				start := boulder_release_pos()
				short := length2(landed_at - start) < length2(g.crate_pos - start)
				say(short ? "Too short! I need more weight." : "Too far! I need less weight.", 2.4)
			}

			// A landing boulder sends nearby enemies flying.
			for &e in g.enemies[:g.enemy_count] {
				if on_ground(&e) && length2(e.pos - landed_at) < 1.6 {
					launch_enemy(&e, normalize2(e.pos - landed_at + {0.01, 0}), 14)
				}
			}
		}

	case .Landed:
		b.timer -= dt
		if b.timer <= 0 {
			burst({b.pos.x, 0.4, b.pos.y}, 10, 3, COLOR_DUST, 0.14)
			b.state = .On_Seesaw
			rest := boulder_rest_pos()
			burst({rest.x, 1, rest.y}, 10, 3, COLOR_DUST, 0.14)
		}
	}
}

// The crate breaks open and its truffle appears.
smash_crate :: proc() {
	g.crate_broken = true
	g.rounds[g.crate_round].r = 0
	g.truffles[3] = {pos = g.crate_pos, visible = true}
	burst({g.crate_pos.x, 0.6, g.crate_pos.y}, 26, 6, COLOR_CRATE, 0.18)
	say("SMASH! Bullseye!", 2)
}
