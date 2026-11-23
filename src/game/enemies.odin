package game

import "core:math"

MAX_ENEMIES :: 40
EGG_EVERY :: Vec2{600, 1200} // a turkey lays an egg every so many seconds, at random in this range: only now and then
SHAKE_EGG :: f32(0.01) // chance that shaking a held turkey shakes an egg out of it: hardly ever
PEN_EGG_EVERY :: Vec2{60, 120} // a penned turkey, settled and fed, lays far more often
AWAKE :: f32(42) // animals further than this from Prosio rest

// A bump hits with Prosio's momentum: his weight times his speed. An enemy
// digs in and soaks up the first part of that (its grip); only what is left
// over throws it:
//
//   launch speed = BUMP_GAIN * (weight * speed - grip) / enemy's weight
//
// So a lean Prosio just bounces off, and the throw grows quickly with weight.
BUMP_GAIN :: f32(0.479)
// How hard an enemy shoves Prosio: speed = BONK * enemy's weight / Prosio's weight
BONK :: f32(31)

// Bad-tempered turkeys live in Turkey Meadow and roam the open meadow, laying
// eggs as they go; goats keep to the goat hills, led by a big billy goat;
// and foxes lurk in the forest, after what is in his sack.
Enemy_Kind :: enum {
	Turkey,
	Goat,
	Billy,
	Fox,
}

// How a turkey hunts. Like wolves round their prey, the turkeys near Prosio
// spread out round him at a distance, drifting towards his back, and take it
// in turns to dart in, preferably from where he is not looking. After a
// strike they fall back and circle again.
//
// Goats square up instead: they keep a few steps off, facing him, then
// lower their heads and charge in a straight line, and back off again.
Hunt :: enum {
	Stalk, // circling at a distance
	Charge, // darting in
	Retreat, // falling back after a strike or a miss
}

Enemy_State :: enum {
	Chase,
	Flying,
	Dizzy,
	Held, // in Prosio's hands
	Dead, // knocked out for good: its body lies there, to be dragged to the fire
	Swimming, // in the pond, thrown there: making for the nearest bank, or (drowned) floating to it
	Gone,
}

Enemy :: struct {
	kind:   Enemy_Kind,
	state:  Enemy_State,
	pos:    Vec2,
	vel:    Vec2,
	home:   Vec2,
	y, vy:  f32, // height above the ground and vertical speed
	facing: f32,
	impact: Enemy_Impact,
	hop:    f32,
	gait:   f32, // how many strides it has walked, run or swum: the legs of a packed animal keep step with it (see quadruped.odin)
	pace:   f32, // measured ground step speed (m/s, negative when backing up)
	motion: Quad_Motion,
	yield_t: f32,
	yield_dir: Vec2,
	look:   f32, // how far its head is turned to watch him (radians)
	squaring: bool, // a goat, squaring up to him: it faces him, and steps forwards and back
	detour:   f32, // which way a goat on four legs turns to get round something in its way,
	detour_t: f32, // and for how much longer
	timer:  f32, // attack pause, dizzy time or time until it comes back
	ko:     bool, // no health left: once it has landed and lain dizzy a moment, that is the end of it
	skip:   bool, // slammed down spinning: it skips along the ground
	hit_t:  f32, // just hit by a swung animal: not hit again until this runs out
	hunt:   Hunt,
	hunt_t: f32, // time left in this part of the hunt
	orbit:  f32, // the direction from Prosio it is circling towards
	turn:   f32, // +1 or -1: which way round it likes to go
	stuck_t:    f32, // how long it has been pressing against things
	stuck_from: Vec2, // where it was when it started
	turn_lock:  f32, // having turned back from a dead end, it keeps going this way for a while
	// While held its body is a floppy chain (see grab.odin):
	chain:     [3]Vec3, // the feet (or hoof) in Prosio's hand, the middle of its body, its shoulders
	chain_old: [3]Vec3, // where they were a step ago
	side:      Vec3, // which way its side points
	dangle:    [2]Vec3, // which way the hind and the front legs hang
	limp:      f32, // bashed about: limp for this long
	health:    f32, // what it has left, out of ENEMY_HEALTH: every blow takes from it
	hurt_t:    f32, // seconds since the last blow: it mends only when left alone a while
	home_t:    f32, // it has chased him too far from home, and gives up for this long
	egg_t:     f32, // a turkey lays an egg when this runs out
	scared_t:  f32, // running from Prosio's wind for this long
	licking:   bool, // a goat, licking the salt off him
	sour:      bool, // a goat he has hit: it will not lick him, however salty, until it forgets
	forget_t:  f32, // and it forgets once he has been out of its sight this much longer
	drowned_t: f32, // how long it has lain drowned in the pond: it floats a moment, then sinks
	body_t:    f32, // how much longer its body lies there
	milk_t:    f32, // a goat has milk again when this runs out
	penned:    bool, // with fences all round it: settled, and at home there (see look_for_pen)
	wild:      Vec2, // a penned animal's home before it was penned
	pen_t:     f32, // until it next looks whether it is penned
	has_loot:  bool, // a fox, with something out of his sack in its mouth
	loot_t:    f32, // for how long it has been carrying it
	loot:      Item,
	loot_kcal: f32,
}

// A big farm turkey, a goat, and the billy goat, who weighs more than an
// ordinary Prosio.
ENEMY_KG := [Enemy_Kind]f32 {
	.Turkey = 16,
	.Goat   = 55,
	.Billy  = 95,
	.Fox    = 20,
}
ENEMY_RADIUS := [Enemy_Kind]f32 {
	.Turkey = 0.42,
	.Goat   = 0.62,
	.Billy  = 0.78,
	.Fox    = 0.45,
}
ENEMY_SPEED := [Enemy_Kind]f32 {
	.Turkey = 2.8,
	.Goat   = 3.2, // (faster than a turkey: a goat is a runner)
	.Billy  = 2.9,
	.Fox    = 3.4,
}
GOAT_CHARGE :: f32(1.8) // how many times its own speed a goat charges at
ENEMY_GRIP := [Enemy_Kind]f32 {
	.Turkey = 560,
	.Goat   = 450,
	.Billy  = 500,
	.Fox    = 600,
}
// Knocked out, a turkey or a goat is dead: its body lies where it fell for
// BODY_LIFE, and chopped up at the fire it gives this many pieces of meat. A
// fox only slinks off for a while. Another animal takes a dead one's place,
// but not for a good while (seconds, somewhere in this range): so hunting
// thins the flock, and with it the eggs.
MEAT_FROM := [Enemy_Kind]int {
	.Turkey = 2,
	.Goat   = 5,
	.Billy  = 8,
	.Fox    = 0,
}
RESPAWN := [Enemy_Kind]Vec2 {
	.Turkey = {300, 480},
	.Goat   = {480, 720},
	.Billy  = {600, 900},
	.Fox    = {60, 120},
}
BODY_LIFE :: f32(240)
// Thrown into the pond, an animal swims for the nearest bank, this fast (m/s)
// and losing this much health a second while it does: a fox swims well, a
// goat tires, and a turkey is no swimmer at all, so one that lands far out
// goes bottoms up (comically: feet in the air, cross eyes, bubbles), then
// sinks out of sight: nothing of it comes ashore.
SWIM_SPEED := [Enemy_Kind]f32{.Turkey = 0.7, .Goat = 1.1, .Billy = 0.9, .Fox = 1.6}
DROWN_RATE := [Enemy_Kind]f32{.Turkey = 16, .Goat = 3, .Billy = 5, .Fox = 0}
SWIM_SINK := [Enemy_Kind]f32{.Turkey = 0.16, .Goat = 0.62, .Billy = 0.75, .Fox = 0.3} // how far down it sits in the water
SINK_WAIT :: f32(1.5) // seconds a drowned one floats bottoms up,
SINK_SPEED :: f32(0.5) // then sinks this fast (m/s)
SINK_DEPTH :: f32(1.4) // until it is this deep, and gone
// How far down a drowned animal has sunk.
sunk :: proc(e: Enemy) -> f32 {
	return max(e.drowned_t - SINK_WAIT, 0) * SINK_SPEED
}

// A goat he has hit will not lick him, however salty he is, until it has
// not seen him (he is further off than SOUR_SIGHT) for SOUR_FORGET seconds.
SOUR_SIGHT :: f32(22)
SOUR_FORGET :: f32(90)
MILK_EVERY :: f32(180) // seconds until a milked goat has milk again
FOX_NOTICE :: f32(13) // how far off a fox scents his sack
FOX_REST :: f32(25) // seconds a fox keeps away after a theft or a fright
FOX_PATIENCE :: f32(30) // seconds it carries what it took before eating it wherever it is
// Every animal has the same measure of health, ENEMY_HEALTH, and every kind
// of blow takes from it: being thrown, bumped, bashed on the ground, hit by
// a rock or by another animal, stomped on. What a blow takes goes with the
// square of its speed, measured against how sturdy that kind is: a blow at
// its sturdy speed takes HARD_BLOW. A heavy animal is the less sturdy, since
// it comes down that much harder: a toss a turkey shrugs off would break a
// billy goat. With no health left it is knocked out for good. Left alone
// for HEAL_AFTER seconds it starts to mend, HEAL_RATE a second.
ENEMY_HEALTH :: f32(100)
HARD_BLOW :: f32(28)
ENEMY_STURDY := [Enemy_Kind]f32 {
	.Turkey = 14,
	.Goat   = 5.5,
	.Billy  = 3.5,
	.Fox    = 12,
}
HEAL_RATE :: f32(1.2)
HEAL_AFTER :: f32(8)
HURT_SLOW :: f32(0.6) // how fast it still goes with almost no health left, as a share

blow_damage :: proc(kind: Enemy_Kind, speed: f32) -> f32 {
	share := speed / ENEMY_STURDY[kind]
	return HARD_BLOW * share * share
}

// Prosio has hit it, thrown it, or knocked it about, hurt or not: a goat
// will not come licking him again for a long while (see SOUR_FORGET).
offend :: proc(e: ^Enemy) {
	if e.kind == .Goat || e.kind == .Billy {
		e.sour = true
		e.forget_t = SOUR_FORGET
		e.licking = false
	}
}

// The animal takes a blow. True if it has no health left.
hurt_enemy :: proc(e: ^Enemy, damage: f32) -> bool {
	if e.ko || damage <= 0 {
		return e.ko
	}
	e.health = max(e.health - damage, 0)
	e.hurt_t = 0
	offend(e)
	if e.kind == .Turkey && damage > 4 {
		// Feathers fly.
		burst({e.pos.x, e.y + 0.6, e.pos.y}, 3 + int(min(damage, 60) / 8), 2.5, TURKEY_TIP, 0.07)
	}
	if e.health <= 0 {
		e.ko = true
	}
	if damage >= ALARM_BLOW {
		alarm_flock(e)
	}
	return e.ko
}

// How dangerous Prosio is to an animal of this kind: the share of its health
// that one good throw of his would take. It goes with his weight and with
// the strength of his arms, and the animals can tell.
threat :: proc(kind: Enemy_Kind) -> f32 {
	p := &g.prosio
	speed := min(ANIMAL_THROW_GAIN * strength() * p.kg / ENEMY_KG[kind], MAX_THROW)
	return clamp(blow_damage(kind, speed) / ENEMY_HEALTH, 0, 1)
}

// A small, weak Prosio they know they can beat, and they press him harder:
// faster, from further off, more of them at once. This is 1 when he is no
// danger to them at all (threat under FEARLESS_BELOW) and 0 once he is
// (RESPECT_ABOVE and over), which the pig he starts as already is.
FEARLESS_BELOW :: f32(0.04)
RESPECT_ABOVE :: f32(0.16)
BOLD_SPEED :: f32(0.3) // how much faster the boldest are
BOLD_NOTICE :: f32(0.4) // and from how much further off they come for him
boldness :: proc(kind: Enemy_Kind) -> f32 {
	return 1 - smooth(clamp((threat(kind) - FEARLESS_BELOW) / (RESPECT_ABOVE - FEARLESS_BELOW), 0, 1))
}

// A big, strong Prosio they fear: from threat WARY_FROM they dart in less,
// and hardly at all from WARY_FULL.
WARY_FROM :: f32(0.45)
WARY_FULL :: f32(0.75)
wariness :: proc(kind: Enemy_Kind) -> f32 {
	return smooth(clamp((threat(kind) - WARY_FROM) / (WARY_FULL - WARY_FROM), 0, 1))
}

// When one of a flock takes a real blow, the others nearby may run for it:
// each with a chance that goes with how dangerous he is (threat times
// SCATTER), so from a strong Prosio nearly all of them scatter and from a
// weak one hardly any. The one that was hit may run too, once it is up.
ALARM_BLOW :: f32(8) // a blow at least this hard is noticed
ALARM_RANGE :: f32(11)
SCATTER :: f32(1.6)
FRIGHT :: Vec2{6, 12} // seconds they keep away

same_flock :: proc(a, b: Enemy_Kind) -> bool {
	goat :: proc(k: Enemy_Kind) -> bool {return k == .Goat || k == .Billy}
	return a == b || (goat(a) && goat(b))
}

alarm_flock :: proc(hurt: ^Enemy) {
	chance := min(threat(hurt.kind) * SCATTER, 0.95)
	for &o in g.enemies[:g.enemy_count] {
		if &o == hurt || o.state != .Chase || !same_flock(o.kind, hurt.kind) || length2(o.pos - hurt.pos) > ALARM_RANGE {
			continue
		}
		if random() < chance {
			o.scared_t = max(o.scared_t, random_range(FRIGHT.x, FRIGHT.y))
		}
	}
	if random() < chance {
		hurt.scared_t = max(hurt.scared_t, random_range(FRIGHT.x, FRIGHT.y) + 3)
	}
}

// An animal that has chased him this far from its home gives up, and
// ambles back for GIVE_UP seconds whatever he does.
LEASH := [Enemy_Kind]f32 {
	.Turkey = 30,
	.Goat   = 26,
	.Billy  = 26,
	.Fox    = 1000,
}
GIVE_UP :: f32(8)

add_enemy :: proc(kind: Enemy_Kind, home: Vec2) {
	g.enemies[g.enemy_count] = Enemy {
		kind = kind,
		pos  = home,
		home = home,
		turn = g.enemy_count % 2 == 0 ? 1 : -1,
		hunt_t = random_range(1.5, 3),
		egg_t = random_range(30, EGG_EVERY.y),
		health = ENEMY_HEALTH,
	}
	g.enemy_count += 1
}

spawn_enemies :: proc() {
	// Most turkeys in their meadow, some wandering the open meadow.
	for placed, tries := 0, 0; placed < 22 && tries < 3000; tries += 1 {
		pos := placed < 14 ? spot_in(.Turkeys, 0.9) : random_spot()
		if region, in_region := region_at(pos); placed >= 14 && in_region && region != .Turkeys {
			continue
		}
		if clear_spot(pos, 1) {
			add_enemy(.Turkey, pos)
			placed += 1
		}
	}
	// The goats, round their billy goat.
	// (The billy goat as near the middle of the hills as there is room.)
	hills := REGIONS[.Hills].centre
	for k in 0 ..< 60 {
		spot := hills + facing_dir(f32(k) * 2.4) * f32(k) * 0.25
		if clear_spot(spot, 1.2) {
			hills = spot
			break
		}
	}
	add_enemy(.Billy, hills)
	for placed, tries := 0, 0; placed < 5 && tries < 500; tries += 1 {
		pos := spot_in(.Hills, 0.6)
		if clear_spot(pos, 1) {
			add_enemy(.Goat, pos)
			placed += 1
		}
	}
	// Foxes, each with its den somewhere in the forest.
	for placed, tries := 0, 0; placed < 5 && tries < 500; tries += 1 {
		pos := spot_in(.Forest, 0.85)
		if clear_spot(pos, 1) {
			add_enemy(.Fox, pos)
			placed += 1
		}
	}
}

// How fast a hit with this much momentum throws an enemy.
bump_speed :: proc(momentum: f32, kind: Enemy_Kind) -> f32 {
	return BUMP_GAIN * max(momentum - ENEMY_GRIP[kind], 0) / ENEMY_KG[kind]
}

// Sends an enemy flying. Leaving at this speed is a blow of that speed
// (unless the blow has been counted already).
launch_enemy :: proc(e: ^Enemy, dir: Vec2, speed: f32, hurts := true) {
	offend(e)
	begin_enemy_impact(e, dir, speed, .Launch)
	if hurts {
		hurt_enemy(e, blow_damage(e.kind, speed))
	}
}

update_enemies :: proc(dt: f32) {
	p := &g.prosio
	licked := false

	for &e, index in g.enemies[:g.enemy_count] {
		r := ENEMY_RADIUS[e.kind]
		e.yield_t = max(0, e.yield_t - dt)
		if e.sour {
			// A goat he hit forgets it only once he has been well out of
			// its sight for a long while; seen again, it starts over.
			if length2(p.pos - e.pos) > SOUR_SIGHT {
				e.forget_t -= dt
				e.sour = e.forget_t > 0
			} else {
				e.forget_t = SOUR_FORGET
			}
		}
		e.hit_t -= dt
		e.scared_t -= dt
		e.milk_t -= dt
		e.hurt_t += dt
		if e.state == .Chase && e.hurt_t > HEAL_AFTER && !e.ko {
			e.health = min(e.health + HEAL_RATE * dt, ENEMY_HEALTH)
		}
		switch e.state {
		case .Gone:
			e.timer -= dt
			if e.timer <= 0 && length2(p.pos - e.home) > 3 {
				e.state = .Chase
				e.pos = e.home
				e.vel = {}
				e.y = 0
				e.ko = false
				e.health = ENEMY_HEALTH
				e.scared_t = 0
				e.limp = 0
				e.body_t = 0
				e.sour = false // a new one: it never met him
				e.drowned_t = 0
				burst({e.pos.x, 0.5, e.pos.y}, 10, 3, COLOR_DUST, 0.14)
			}

		case .Held:
		// Carried: update_grab moves it.

		case .Dead:
			// Its body lies there until it is carried off, or is gone.
			e.vel = {}
			e.y = 0
			e.body_t -= dt
			if e.body_t < BODY_LIFE * BODY_FLIES && math.mod(g.time + f32(index) * 0.41, 0.5) < dt {
				// It is going off: the flies come.
				a := g.time * 7 + f32(index)
				spawn_particle({e.pos.x + math.cos(a) * 0.3, 0.5 + 0.15 * math.sin(a * 1.3), e.pos.y + math.sin(a) * 0.3}, {math.cos(a * 3) * 1.2, 0.4, math.sin(a * 2) * 1.2}, 0.9, 0.035, {30, 30, 34, 255}, 0)
			}
			if e.body_t <= 0 {
				burst({e.pos.x, 0.3, e.pos.y}, 8, 2, COLOR_DUST, 0.12)
				leave(&e)
			}

		case .Chase:
			e.timer -= dt
			e.turn_lock -= dt
			// Now and then a turkey lays an egg where it stands.
			if e.kind == .Turkey {
				e.egg_t -= dt
				if e.egg_t <= 0 {
					every := e.penned ? PEN_EGG_EVERY : EGG_EVERY
					e.egg_t = random_range(every.x, every.y)
					behind := e.pos - facing_dir(e.facing) * ENEMY_RADIUS[e.kind] * 0.8
					if drop_egg(behind, 0.3) {
						burst({behind.x, 0.4, behind.y}, 3, 1.5, TURKEY_TIP, 0.06)
					}
				}
			}
			// Now and then it looks about it: fenced in, or not?
			e.pen_t -= dt
			if e.pen_t <= 0 {
				e.pen_t = PEN_CHECK
				look_for_pen(&e)
			}
			// Far from Prosio, it rests (but a fox with something of his
			// goes on to its den).
			if length2(p.pos - e.pos) > AWAKE && !e.has_loot {
				e.vel = {}
				continue
			}
			target := chase_velocity(&e, index, dt)
			speed: f32
			if quad_legged(e.kind) {
				// Four legs that step: it goes the way it faces, forwards or
				// slowly backwards, and turns to change its way (see quad_steer).
				quad_steer(&e, target, dt)
				e.pos += e.vel * dt
				speed = length2(e.vel)
			} else {
				accel: f32 = e.kind == .Goat || e.kind == .Billy ? 10 : 14
				e.vel = approach2(e.vel, target, accel * dt)
				e.pos += e.vel * dt
				speed = length2(e.vel)
				look := e.vel
				near := e.hunt == .Stalk && length2(p.pos - e.pos) < 9
				if near {
					look = normalize2(e.vel) * 0.6 + normalize2(p.pos - e.pos)
				}
				if speed > 0.3 && look != {} {
					e.facing = approach_angle(e.facing, math.atan2(look.x, look.y), 8 * dt)
				}
			}
			e.hop += dt * (speed > 0.3 ? 9 : 3)
			if hit, n := collide_static(&e.pos, r, e.y, true); hit && dot2(target, n) < -0.2 * length2(target) {
				// Something is in the way: go round it, the side nearer its goal.
				along := Vec2{-n.y, n.x}
				side := dot2(along, target)
				if abs(side) > 0.2 * length2(target) && e.turn_lock <= 0 {
					e.turn = side > 0 ? 1 : -1
				}
				if quad_legged(e.kind) {
					// (On four legs it turns to walk along it.)
					aim := along * e.turn
					e.detour = math.atan2(aim.x, aim.y)
					e.detour_t = 0.4
				} else {
					e.vel = along * e.turn * max(length2(target), speed)
				}
				// Wedged in a corner, getting nowhere: try the other way round.
				e.stuck_t += dt
				if e.stuck_t > 0.8 {
					if length2(e.pos - e.stuck_from) < 0.6 {
						e.turn = -e.turn
						e.turn_lock = 2
					}
					e.stuck_t = 0
					e.stuck_from = e.pos
				}
			} else {
				e.stuck_t = 0
				e.stuck_from = e.pos
			}
			e.y = 0
			if e.licking {
				// A rough tongue takes the salt off him, bit by bit (however
				// many goats there are, there is only so much to lick).
				if !licked {
					p.need[.Electrolytes] = max(p.need[.Electrolytes] - LICK * dt, 0)
					licked = true
				}
				hint("Hee hee! That tickles!")
				if math.mod(g.time + f32(index) * 0.37, 0.7) < dt {
					spawn_particle({e.pos.x, 1.3, e.pos.y}, {0, 1, 0}, 0.8, 0.09, COLOR_HEART, 0)
				}
			}
			touch_prosio(&e, e.scared_t <= 0 && !e.licking && e.kind != .Fox && !e.penned)

		case .Flying:
			e.vy -= GRAVITY * dt
			e.y += e.vy * dt
			e.pos += e.vel * dt
			if e.impact.kind != .None {
				spin_enemy_impact(&e.impact, dt)
			}
			hit, n := collide_static(&e.pos, r, e.y, true, false, true, false)
			if out := beyond_edge(e.pos); out > FOG_LOST || (out > 0 && e.y <= 0 && e.vy < 0) {
				// Into the fog beyond the meadow: lost.
				if length2(e.pos - p.pos) < 25 {
					say("Bye bye! Into the fog...", 1.4)
				}
				leave(&e)
				continue
			}
			if ENEMY_KG[e.kind] > FENCE_HEAVY && e.y < FENCE_TOP + 0.6 {
				// Too big to sail over a fence: it bangs into it.
				if h, fn := push_out_fences(&e.pos, r); h {
					hit, n = true, fn
				}
			}
			if hit {
				into := dot2(e.vel, n)
				if into < 0 {
					e.vel -= n * into * 1.6 // bounce off
					if into < -4 {
						shake_trees_near(e.pos, r + 0.6, -into) // apples come down
					}
					burst({e.pos.x, e.y + r, e.pos.y}, 5, 2, COLOR_DUST, 0.1)
				}
			}
			// A flying enemy bowls over the ones it hits.
			speed := length2(e.vel)
			if e.y < 1.2 && speed > 4 {
				for &other, other_index in g.enemies[:g.enemy_count] {
					if other_index == index || !on_ground(&other) {
						continue
					}
					d := other.pos - e.pos
					if length2(d) < r + ENEMY_RADIUS[other.kind] {
						passed := speed * 0.7 * ENEMY_KG[e.kind] / ENEMY_KG[other.kind]
						enemy_impact(&other, normalize2(d), min(passed, speed))
						e.vel *= 0.5
						burst({other.pos.x, 0.6, other.pos.y}, 8, 4, COLOR_STAR, 0.12)
						break
					}
				}
			}
			if e.y <= 0 && e.vy < 0 && in_pond(e.pos) {
				// SPLASH: into the water.
				e.y = 0
				e.vy = 0
				e.vel *= 0.2
				e.state = .Swimming
				e.impact = {}
				e.skip = false
				e.limp = 0
				burst({e.pos.x, 0.2, e.pos.y}, 22, 5, POND_SPLASH, 0.13)
				if length2(e.pos - p.pos) < 25 {
					say(e.ko ? "Sploosh!" : (DROWN_RATE[e.kind] > 10 ? "SPLASH! Can turkeys swim?" : "SPLASH! Swim for it!"), 1.2)
				}
				continue
			}
			if e.y <= 0 && e.vy < 0 {
				e.y = 0
				burst({e.pos.x, 0.1, e.pos.y}, 6, 2.5, COLOR_DUST, 0.12)
				if e.skip && e.vy < -4 {
					// Slammed down spinning: the spin turns part of the fall into
					// forward speed, so it skips on along the ground.
					fall := -e.vy
					forward := length2(e.vel)
					dir := forward > 0.1 ? e.vel / forward : facing_dir(e.facing)
					e.vy = fall * SKIP_BOUNCE
					e.vel = dir * (forward * SKIP_KEEP + fall * SKIP_SPIN)
					g.shake = max(g.shake, min(fall * ENEMY_KG[e.kind] / 900, 0.6))
					burst({e.pos.x, 0.1, e.pos.y}, 4 + int(fall), 2 + fall * 0.2, COLOR_DUST, 0.13)
				} else {
					e.vel *= IMPACT_LANDING_KEEP
					if e.vy < -IMPACT_REBOUND_SPEED {
						e.vy *= -IMPACT_RESTITUTION
					} else {
						land_enemy_impact(&e)
					}
				}
			}

		case .Swimming:
			// Paddling for the nearest bank; or, drowned, bottoms up a moment
			// and then down it goes, and is gone.
			out := e.pos - POND
			bank := POND + normalize2(out) * (POND_RADIUS - 0.3)
			to := bank - e.pos
			if e.ko {
				e.vel = approach2(e.vel, {}, 2 * dt)
				e.pos += e.vel * dt
				e.y = 0
				e.drowned_t += dt
				if math.mod(g.time + f32(index) * 0.29, e.drowned_t > SINK_WAIT ? 0.2 : 0.9) < dt {
					spawn_particle({e.pos.x, 0.1, e.pos.y}, {0, 0.8, 0}, 1.2, 0.07, {220, 240, 250, 255}, 0) // a bubble
				}
				if sunk(e) >= SINK_DEPTH {
					burst({e.pos.x, 0.1, e.pos.y}, 6, 1, POND_SPLASH, 0.06)
					leave(&e)
				}
				break
			}
			e.vel = approach2(e.vel, normalize2(to) * SWIM_SPEED[e.kind] * lerp(HURT_SLOW, 1, e.health / ENEMY_HEALTH), 3 * dt)
			e.pos += e.vel * dt
			e.y = 0
			e.facing = math.atan2(to.x, to.y)
			e.hop += dt * 9
			e.gait += quad_stride_rate(e.kind, length2(e.vel)) * dt
			if DROWN_RATE[e.kind] > 0 && hurt_enemy(&e, DROWN_RATE[e.kind] * dt) {
				// Glub glub... bottoms up.
				burst({e.pos.x, 0.3, e.pos.y}, 12, 2, POND_SPLASH, 0.1)
				e.drowned_t = 0
				if length2(e.pos - p.pos) < 25 {
					say("Glub glub... oops! Bottoms up!", 1.6)
				}
			}
			if math.mod(g.time + f32(index) * 0.29, 0.35) < dt {
				spawn_particle({e.pos.x - math.sin(e.facing) * r, 0.05, e.pos.y - math.cos(e.facing) * r}, {0, 1.4, 0}, 0.5, 0.06, POND_SPLASH, 0)
			}
			if !in_pond(e.pos) || length2(out) > POND_RADIUS - 0.35 {
				// Ashore: out it climbs and shakes itself, and keeps well away
				// for a while.
				e.pos = POND + normalize2(out) * (POND_RADIUS - 0.5 + r + 0.15)
				e.vel = {}
				burst({e.pos.x, 0.5, e.pos.y}, 14, 3, POND_SPLASH, 0.08)
				e.state = .Dizzy
				e.timer = 1.2
				e.scared_t = max(e.scared_t, 6)
			}

		case .Dizzy:
			e.timer -= dt
			ready := e.timer <= 0
			if e.impact.kind == .None {
				e.vel = approach2(e.vel, {}, 14 * dt)
			} else {
				ready = step_enemy_impact(&e, dt) && ready
			}
			e.pos += e.vel * dt
			hit, normal := collide_static(&e.pos, r, 0, true)
			if hit && e.impact.kind != .None {
				e.vel -= normal * min(dot2(e.vel, normal), 0)
			}
			e.y = 0
			touch_prosio(&e, false)
			if e.state == .Dizzy && ready && (e.impact.kind == .None || e.impact.age > 0) {
				if e.ko && MEAT_FROM[e.kind] > 0 {
					// That was the end of it: its body stays.
					e.state = .Dead
					if e.body_t <= 0 {
						e.body_t = BODY_LIFE
						burst({e.pos.x, 0.6, e.pos.y}, 18, 5, COLOR_STAR, 0.15)
					}
				} else if e.ko {
					burst({e.pos.x, 0.6, e.pos.y}, 18, 5, COLOR_STAR, 0.15)
					leave(&e)
				} else {
					e.state = .Chase
					e.impact = {}
					e.timer = 0.5
					e.hunt = .Retreat
					e.hunt_t = 0.8
				}
			}
		}
	}

	// Enemies on the ground never overlap each other: each moves half way out.
	for i in 0 ..< g.enemy_count {
		a := &g.enemies[i]
		if !on_ground(a) {
			continue
		}
		for j in i + 1 ..< g.enemy_count {
			b := &g.enemies[j]
			if !on_ground(b) {
				continue
			}
			d := b.pos - a.pos
			dist := length2(d)
			overlap := ENEMY_RADIUS[a.kind] + ENEMY_RADIUS[b.kind] - dist
			if overlap <= 0 {
				continue
			}
			away := dist > 1e-4 ? d / dist : Vec2{1, 0}
			a.pos -= away * overlap / 2
			b.pos += away * overlap / 2
			collide_static(&a.pos, ENEMY_RADIUS[a.kind], 0, true)
			collide_static(&b.pos, ENEMY_RADIUS[b.kind], 0, true)
		}
	}
	for &e in g.enemies[:g.enemy_count] {
		quad_update_motion(&e, dt)
	}
}

// How fast, and which way, a chasing enemy wants to go.
chase_velocity :: proc(e: ^Enemy, index: int, dt: f32) -> Vec2 {
	p := &g.prosio
	// Hurt, it is slower; sure of beating him, it is faster.
	bold := boldness(e.kind)
	speed := ENEMY_SPEED[e.kind] * lerp(HURT_SLOW, 1, e.health / ENEMY_HEALTH) * (1 + BOLD_SPEED * bold)
	to := p.pos - e.pos
	dist := length2(to)
	goat := e.kind == .Goat || e.kind == .Billy
	e.licking = false
	e.squaring = false
	e.home_t -= dt
	if length2(e.pos - e.home) > LEASH[e.kind] {
		e.home_t = GIVE_UP
	}
	toward := to / max(dist, 0.001)
	if e.scared_t > 0 && p.fail == .None {
		// His wind has reached it: away, as fast as its legs will go.
		e.hunt = .Retreat
		e.hunt_t = 0.5
		return dist < 16 ? -toward * speed * 1.7 : Vec2{}
	}
	if e.penned {
		// In a pen it has settled down: it potters about, and bothers nobody.
		e.hunt = .Stalk
		e.hunt_t = 1
		k := f32(index)
		if math.sin(g.time * 0.5 + k * 2.1) < 0.3 {
			return {} // standing about, mostly
		}
		return facing_dir(g.time * 0.17 + k * 1.9 + math.sin(g.time * 0.31 + k)) * speed * 0.3
	}
	if e.kind == .Fox {
		return fox_velocity(e, dist, toward, dt)
	}
	if goat && salty() && !e.sour && dist < 16 {
		// A salty pig! It trots up and licks him, and has no mind to butt.
		e.hunt = .Stalk
		e.hunt_t = 1
		reach := prosio_radius(p.kg) + ENEMY_RADIUS[e.kind] + 0.15
		e.licking = dist < reach + 0.3
		return dist > reach ? toward * speed * 1.2 + keep_apart(e, index) * speed * 0.5 : Vec2{}
	}
	// Glowing orange with vitamins, he is spotted from further off.
	notice: f32 = (too_much(.Vitamins) ? GLOW_NOTICE : 1) * (1 + BOLD_NOTICE * bold)
	if p.fail != .None || e.home_t > 0 || dist > 11 * notice || (goat && dist > 8 * notice) {
		// Nothing to hunt: amble home. When it spots him again it first
		// takes its time to fan out round him.
		e.hunt = .Stalk
		e.hunt_t = random_range(1.5, 3)
		e.orbit = math.atan2(-to.x, -to.y)
		home := e.home
		if goat {
			// Goats wander about their patch, grazing.
			k := f32(index)
			home += Vec2{math.sin(g.time * 0.13 + k * 1.7), math.cos(g.time * 0.11 + k * 2.3)} * 2.2
		}
		if e.timer <= 0 && length2(home - e.pos) > 1 {
			return normalize2(home - e.pos) * speed * (goat ? 0.35 : 0.6)
		}
		return {}
	}
	e.hunt_t -= dt
	if goat {
		return goat_velocity(e, index, dist, toward)
	}
	switch e.hunt {
	case .Stalk:
		// Circle at a distance, each turkey heading for its own place round him,
		// the places spread round his back.
		slot, count := hunt_slot(index)
		spread := min(f32(1.1), math.TAU / f32(max(count, 1)))
		back := math.atan2(-math.sin(p.facing), -math.cos(p.facing))
		want := back + (f32(slot) - f32(count - 1) / 2) * spread
		e.orbit = approach_angle(e.orbit, want, 1.5 * dt)
		radius := 3.3 + 0.5 * math.sin(g.time * 0.7 + f32(index) * 1.9)
		here := math.atan2(-to.x, -to.y) // its direction from him
		gap := angle_diff(e.orbit, here)
		around := Vec2{-toward.y, toward.x} * (gap > 0 ? 1 : -1) // along the circle, the short way
		pace := clamp(abs(gap) * 1.5, 0.3, 1)
		closing := clamp((dist - radius) * 1.6, -0.7 * speed, 0.7 * speed)
		want_vel := around * speed * 0.9 * pace + toward * closing
		want_vel += keep_apart(e, index) * speed
		if length2(want_vel) > speed {
			want_vel = normalize2(want_vel) * speed
		}
		// Now and then one darts in: much more likely from where he is not
		// looking, and never more than two at once.
		if e.hunt_t <= 0 {
			e.hunt_t = random_range(0.5, 1.3)
			seen := dot2(facing_dir(p.facing), -toward) // 1 when he looks straight at it
			chance: f32 = seen < -0.2 ? 0.55 : (seen < 0.4 ? 0.25 : 0.06)
			// Bold, more of them dare at once, and more often; wary, they hang back.
			chance *= (1 + bold) * (1 - 0.8 * wariness(e.kind))
			if dist < 6 && e.timer <= 0 && chargers() < 2 + int(bold * 2.5) && random() < chance {
				e.hunt = .Charge
				e.hunt_t = 1.6
				e.turn = random() < 0.5 ? -1 : 1
			}
		}
		return want_vel
	case .Charge:
		// Lead him a little and come in on a curve, not in a straight line.
		lead := p.pos + p.vel * min(dist / (speed * 1.4), 0.5)
		aim := lead - e.pos
		curve := Vec2{-aim.y, aim.x} * e.turn * min(dist * 0.08, 0.35)
		if e.hunt_t <= 0 {
			e.hunt = .Retreat
			e.hunt_t = random_range(0.6, 1.0)
		}
		return normalize2(aim + curve) * speed * 1.45
	case .Retreat:
		if e.hunt_t <= 0 || dist > 5.5 {
			e.hunt = .Stalk
			e.hunt_t = random_range(0.8, 2.5)
			e.turn = random() < 0.5 ? -1 : 1
		}
		side := Vec2{-toward.y, toward.x} * e.turn
		return normalize2(-toward + side * 0.6 + keep_apart(e, index)) * speed * 1.15
	}
	return {}
}

// A fox does not fight: it steals. It comes up on him from wherever he is
// not looking, and stands stock still whenever he turns to look at it. If it
// reaches him it has the best thing out of his sack and is off to its den
// with it, where it eats it. A bump, a grab, a stomp, anything thrown at it,
// or his wind, and it lets go.
fox_velocity :: proc(e: ^Enemy, dist: f32, toward: Vec2, dt: f32) -> Vec2 {
	p := &g.prosio
	speed := ENEMY_SPEED[.Fox]
	home := e.home - e.pos
	if e.has_loot {
		// At its den it eats what it took; and if it cannot get there (a den
		// in a thicket can be hard to get back into), it eats it on the way.
		e.loot_t += dt
		if length2(home) < 1.2 || e.loot_t > FOX_PATIENCE {
			e.loot_t = 0
			e.has_loot = false
			e.timer = FOX_REST
			e.yield_dir = normalize2(-toward)
			e.yield_t = QUAD_YIELD_TIME
			if dist < 40 {
				say_named("Oh no! The fox ate my %s!", ITEM_NAME[e.loot])
			}
			return e.yield_dir * QUAD_YIELD_SPEED
		}
		return normalize2(home) * speed * 1.5
	}
	if p.fail != .None || dist > FOX_NOTICE || e.timer > 0 || !sack_has_loot() {
		return length2(home) > 1 ? normalize2(home) * speed * 0.5 : Vec2{}
	}
	if dist < prosio_radius(p.kg) + ENEMY_RADIUS[.Fox] + 0.2 {
		steal(e)
		return -toward * speed * 1.5
	}
	seen := dot2(facing_dir(p.facing), -toward) // 1 when he looks straight at it
	if seen > 0.5 && dist < 8 {
		return {} // caught in the open: it freezes, all innocence
	}
	return toward * speed * (dist < 5 ? 1.3 : 0.8)
}

// The fox has the richest thing in his sack.
steal :: proc(e: ^Enemy) {
	p := &g.prosio
	best: Item
	best_kcal := f32(-1)
	for count, item in p.sack {
		if kcal := sack_piece_kcal(item); count > 0 && is_food(item) && kcal > best_kcal {
			best, best_kcal = item, kcal
		}
	}
	if best_kcal < 0 {
		return
	}
	e.loot = best
	e.loot_kcal = sack_take(best, 1)
	e.has_loot = true
	e.loot_t = 0
	sack_step(0)
	say_named("Hey! The fox took my %s!", ITEM_NAME[best])
	burst({p.pos.x, p.height + 1.2 * PROSIO_SIZE, p.pos.y}, 6, 2.5, COLOR_STAR, 0.08)
}

// A fox that is hit or frightened lets go of what it stole, and Prosio has
// it back.
drop_loot :: proc(e: ^Enemy) {
	if !e.has_loot {
		return
	}
	e.has_loot = false
	e.loot_t = 0
	e.timer = FOX_REST
	if sack_room(e.loot) > 0 {
		sack_add(e.loot, e.loot_kcal)
		sack_step(0)
		say_named("Got my %s back!", ITEM_NAME[e.loot])
	}
}

// It is gone, and another will not take its place for a good while.
leave :: proc(e: ^Enemy) {
	unpen(e) // the next one comes back where its kind lives, not in the pen
	e.state = .Gone
	e.impact = {}
	e.timer = random_range(RESPAWN[e.kind].x, RESPAWN[e.kind].y)
	e.has_loot = false
}

// E with an animal in his hand: a goat is milked; a dead turkey or goat is
// chopped into meat, but only at the block by the fire.
use_held_animal :: proc() {
	p := &g.prosio
	e := &g.enemies[p.carry_index]
	switch {
	case e.ko && MEAT_FROM[e.kind] == 0:
		answer("Nobody eats fox.")
	case e.ko:
		if !station_in_reach(.Fire, p.pos, prosio_radius(p.kg) + 1.2) {
			answer("The chopping block is by the fire, at the pond.")
			return
		}
		room := sack_room(.Meat)
		if room <= 0 {
			answer("No room in my sack for meat!")
			return
		}
		// A body that has lain a while gives poorer meat, nearer going off.
		fresh: f32 = 1 // (a body never put down has not started to lie: body_t is 0)
		if e.body_t > 0 {
			fresh = lerp(BODY_MEAT_LEAST, 1, clamp(e.body_t / BODY_LIFE, 0, 1))
		}
		for _ in 0 ..< min(MEAT_FROM[e.kind], room) {
			sack_add(.Meat, math.round(RAW_KCAL[.Meat] * fresh), fresh)
		}
		p.sack_sel = .Meat
		block := g.stations[.Fire].pos + FIRE_BLOCK.xz
		burst({block.x, 0.7, block.y}, 12, 3, COLOR_STAR, 0.08)
		leave(e)
		p.carry = .Nothing
		p.lift_t = 0
		p.carry_kg = 0
		p.swinging = false
		say("Chop, chop, chop! Meat for the fire!", 1.8)
	case e.kind == .Goat:
		milk_goat(e, e.chain[1])
	case e.kind == .Billy:
		answer("A billy goat gives no milk!")
	case:
		answer("Nothing to do with this one but bash or throw it.")
	}
}

// Milks a goat, held by its hind legs, standing quietly licking the salt
// off him, or in a pen.
milk_goat :: proc(e: ^Enemy, at: Vec3) {
	if e.milk_t > 0 {
		answer("This goat has no milk just now.")
	} else if sack_room(.Milk) < 1 {
		answer("No room in my sack for more milk!")
	} else {
		sack_add(.Milk, RAW_KCAL[.Milk])
		sack_step(0)
		e.milk_t = MILK_EVERY
		train(.Hooves, MILK_WORK)
		say("Squirt, squirt! A jug of milk!", 1.6)
		burst(at, 6, 1.5, COLOR_WHITE, 0.06)
	}
}

// A goat that stands licking him, or one in a pen that he is standing at,
// can be milked where it stands: the nearest one, one with milk before one
// without.
licking_goat :: proc() -> (best: ^Enemy) {
	p := &g.prosio
	for &e in g.enemies[:g.enemy_count] {
		if e.kind != .Goat || e.state != .Chase || !(e.licking || penned_goat_in_reach(&e)) {
			continue
		}
		if best == nil || (e.milk_t <= 0) != (best.milk_t <= 0) ? e.milk_t <= 0 : length2(e.pos - p.pos) < length2(best.pos - p.pos) {
			best = &e
		}
	}
	return
}

// A goat squares up to him, charges head down, and backs off again.
goat_velocity :: proc(e: ^Enemy, index: int, dist: f32, toward: Vec2) -> Vec2 {
	speed := ENEMY_SPEED[e.kind]
	switch e.hunt {
	case .Stalk:
		// A few steps off, facing him, pawing the ground.
		e.squaring = true
		closing := clamp((dist - 4) * 1.2, -0.8 * speed, 0.8 * speed)
		v := toward * closing + keep_apart(e, index) * speed
		if e.hunt_t <= 0 {
			e.hunt_t = random_range(0.3, 0.8)
			if e.timer <= 0 && dist < 6.5 && random() < 0.6 * (1 - 0.8 * wariness(e.kind)) {
				e.hunt = .Charge
				e.hunt_t = clamp(dist / (speed * GOAT_CHARGE) + 0.5, 0.8, 1.8)
				e.orbit = math.atan2(toward.x, toward.y) // straight at where he is now
				if _, packed := quad_model_for(e.kind); !packed {
					e.facing = e.orbit // (one with legs that step turns into it instead)
				}
			}
		}
		return v
	case .Charge:
		if e.hunt_t <= 0 {
			e.hunt = .Retreat
			e.hunt_t = random_range(0.7, 1.2)
		}
		return facing_dir(e.orbit) * speed * GOAT_CHARGE + keep_apart(e, index) * speed // (swerving round another goat)
	case .Retreat:
		// (On four legs it backs off still facing him.)
		e.squaring = true
		if e.hunt_t <= 0 {
			e.hunt = .Stalk
			e.hunt_t = random_range(1, 2.4)
		}
		return normalize2(-toward + keep_apart(e, index)) * speed * 0.8
	}
	return {}
}

// Which place round Prosio this turkey has, out of how many hunting him. The
// places are handed out in the order the turkeys already stand round him, so
// they fan out without crossing each other's paths.
hunt_slot :: proc(index: int) -> (slot, count: int) {
	p := &g.prosio
	back := math.atan2(-math.sin(p.facing), -math.cos(p.facing))
	mine := g.enemies[index].pos - p.pos
	my_angle := angle_diff(math.atan2(mine.x, mine.y), back)
	for &o, i in g.enemies[:g.enemy_count] {
		if o.kind != .Turkey || o.state != .Chase || length2(o.pos - p.pos) > 11 {
			continue
		}
		count += 1
		d := o.pos - p.pos
		a := angle_diff(math.atan2(d.x, d.y), back)
		if a < my_angle || (a == my_angle && i < index) {
			slot += 1
		}
	}
	return
}

chargers :: proc() -> (n: int) {
	for &o in g.enemies[:g.enemy_count] {
		if o.kind == .Turkey && o.state == .Chase && o.hunt == .Charge {
			n += 1
		}
	}
	return
}

// A push away from packmates that are too close.
keep_apart :: proc(e: ^Enemy, index: int) -> (push: Vec2) {
	for &o, i in g.enemies[:g.enemy_count] {
		if i == index || !on_ground(&o) {
			continue
		}
		d := e.pos - o.pos
		dist := length2(d)
		room := ENEMY_RADIUS[e.kind] + ENEMY_RADIUS[o.kind] + 1.2
		if dist < room && dist > 1e-3 {
			push += d / dist * (1 - dist / room)
		}
	}
	return
}

// The signed angle from b round to a, between -pi and pi.
angle_diff :: proc(a, b: f32) -> f32 {
	d := math.mod(a - b + math.PI, math.TAU)
	if d < 0 {
		d += math.TAU
	}
	return d - math.PI
}

// Everything that happens when an enemy on the ground and Prosio touch:
// his bump lands, or it shoves him, and either way they end up side by side.
touch_prosio :: proc(e: ^Enemy, can_shove: bool) {
	p := &g.prosio
	r := ENEMY_RADIUS[e.kind]
	pr := prosio_radius(p.kg)
	d := e.pos - p.pos
	dist := length2(d)
	if dist >= pr + r || abs(p.height - e.y) > r * 1.8 {
		return // apart, or he is jumping over it
	}
	away := dist > 1e-4 ? d / dist : Vec2{1, 0}

	if p.fail == .None {
		if p.dash_t > 0 {
			prosio_hits_enemy(e, away)
			if e.state == .Flying {
				return
			}
		} else if can_shove && e.timer <= 0 && p.safe_t <= 0 {
			// The enemy shoves Prosio. A lean Prosio flies further, and a rock
			// is knocked out of his hands. A tail he keeps hold of, and in the
			// middle of a swing he cannot be pushed off course.
			if p.carry == .Rock {
				drop_carry()
			}
			// Well padded, he hardly feels it; all skin, it hurts the more.
			felt := knock()
			if !p.swinging {
				p.vel = -away * min(BONK * ENEMY_KG[e.kind] / p.kg, 12) * min(felt, 1.3)
			}
			p.stamina -= 12 * felt
			p.regen_delay = 0.4
			bruise(BRUISE[e.kind] * felt)
			train(.Hide, KNOCK_WORK)
			p.wobble_vel += 3
			// After a shove he cannot be shoved again for a moment, so a
			// crowd of enemies cannot keep him pinned down.
			p.safe_t = 1.2 - 0.3 * boldness(e.kind)
			if p.stamina <= 0 {
				// Knocked dizzy: a short rest, then he gets up with some
				// breath back and time to get away.
				p.stamina = min(30, stamina_top())
				p.dazed_t = 0.9
				p.safe_t = 3
				p.winded = false
				say("Wooo... dizzy...", 1.2)
			} else {
				say(felt < 0.7 ? "Boing! It bounced off me!" : (e.kind == .Turkey ? "Ouch! It pecked me!" : "Oof! Headbutt!"), 0.9)
			}
			e.vel = away * (felt < 0.7 ? 7 : 4)
			e.timer = 1.2
			e.hunt = .Retreat // strike and fall back, like a wolf
			e.hunt_t = random_range(0.8, 1.4)
			g.shake = max(g.shake, 0.25)
		}
	}

	// Push them apart, the lighter one moving more. If the enemy is pinned
	// against something, Prosio takes up the rest.
	overlap := pr + r - dist
	if e.state == .Chase && quad_legged(e.kind) && p.fail == .None &&
	   (dot2(p.vel, away) > QUAD_YIELD_MIN_SPEED || overlap > QUAD_YIELD_OVERLAP) {
		e.yield_dir = away
		e.yield_t = QUAD_YIELD_TIME
	}
	share := p.kg / (p.kg + ENEMY_KG[e.kind])
	e.pos += away * overlap * share
	p.pos -= away * overlap * (1 - share)
	collide_static(&e.pos, r, 0, true)
	collide_static(&p.pos, pr, p.height, false, clears_fences())
	left := pr + r - length2(e.pos - p.pos)
	if left > 0 {
		p.pos -= away * left
		collide_static(&p.pos, pr, p.height, false, clears_fences())
	}
}

// Prosio's bump lands.
prosio_hits_enemy :: proc(e: ^Enemy, away: Vec2) {
	p := &g.prosio
	hit_speed := length2(p.vel)
	speed := bump_speed(p.kg * hit_speed, e.kind)
	dir := normalize2(away + normalize2(p.vel))
	if dir == {} {
		dir = away
	}
	p.dash_t = 0
	p.wobble_vel += 4
	offend(e) // even a bump that only pushes it

	before := e.health
	response := enemy_impact(e, dir, speed)
	if response < .Launch {
		// Prosio bounces back when he cannot send it flying.
		p.vel = -away * hit_speed * 0.45
		burst({e.pos.x, 0.7, e.pos.y}, 4, 2, COLOR_DUST, 0.1)
		say("Boing! I'm too light!", 1.2)
		return
	}

	// A heavy Prosio ploughs on; a lighter one is slowed more.
	p.vel *= lerp(0.2, 0.75, fatness())
	g.shake = max(g.shake, min(speed * 0.04, 0.8))
	burst({e.pos.x, 0.7, e.pos.y}, 6 + int(speed), 3 + speed * 0.2, COLOR_STAR, 0.12)
	if e.ko {
		say("BOOM!", 0.9)
	} else if before - e.health < ALARM_BLOW {
		hint("Not hard enough... I need more weight!")
	} else {
		say("Pow!", 0.6)
	}
}

// Prosio comes down on an animal: the blow is his weight times the height
// he came down from (the top of his jump), times STOMP_K. Every Prosio hits
// as hard, since a heavy one cannot jump as high: weight times jump height
// is always 36 (more with a rock in his arms). It takes from the animal's
// health like any blow: all of it at ENEMY_TOUGH, so a turkey is done for
// by two stomps, a goat by four and the billy goat by five.
STOMP_K :: f32(1)
ENEMY_TOUGH := [Enemy_Kind]f32 {
	.Turkey = 50,
	.Goat   = 110,
	.Billy  = 160,
	.Fox    = 60,
}

// Checked as he falls: if he comes down on an animal, it takes the blow and
// he bounces off. True if he did.
stomp_enemies :: proc() -> bool {
	p := &g.prosio
	if p.fail != .None {
		return false
	}
	pr := prosio_radius(p.kg)
	damage: f32
	hit, knocked_out := false, false
	for &e in g.enemies[:g.enemy_count] {
		if (e.state != .Chase && e.state != .Dizzy) || e.hit_t > 0 {
			continue // not on its feet, or just stomped: his bounce off it is not another stomp
		}
		r := ENEMY_RADIUS[e.kind]
		above := p.height - e.y
		d := e.pos - p.pos
		dist := length2(d)
		if above > r * 2.1 || above < r * 0.6 || dist >= pr * 0.8 + r {
			continue
		}
		away := dist > 1e-4 ? d / dist : facing_dir(p.facing)
		damage = STOMP_K * total_kg() * max(p.peak - e.y, 0)
		drop_loot(&e)
		e.hit_t = 0.9
		if hurt_enemy(&e, damage * ENEMY_HEALTH / ENEMY_TOUGH[e.kind]) {
			launch_enemy(&e, away, 5, false) // flattened
			e.vy = 3
			knocked_out = true
		} else {
			enemy_impact(&e, away, IMPACT_FALL_SPEED, false)
			e.timer = 0.8 + 2.5 * (1 - e.health / ENEMY_HEALTH)
		}
		pain_stars({e.pos.x, e.y + r * 1.8, e.pos.y}, damage / 12)
		burst({e.pos.x, e.y + 0.7, e.pos.y}, 4 + int(damage / 25), 3 + damage / 60, COLOR_STAR, 0.12)
		hit = true
	}
	if hit {
		p.vy = 5
		p.peak = p.height
		g.shake = max(g.shake, min(damage / 400, 0.6))
		say(knocked_out ? "MEGA STOMP!" : "STOMP!", 0.8)
	}
	return hit
}
