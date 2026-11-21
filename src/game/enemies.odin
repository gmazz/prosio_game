package game

import "core:math"

MAX_ENEMIES :: 40
EGG_EVERY :: Vec2{100, 220} // a turkey lays an egg every so many seconds, at random in this range
SHAKE_EGG :: f32(0.2) // chance that shaking a held turkey shakes an egg out of it
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
// Throws slower than this do not get an enemy off its feet.
WEAK_HIT :: f32(3)

// Bad-tempered turkeys live in Turkey Meadow and roam the open meadow, laying
// eggs as they go; goats keep to the goat hills, led by a big billy goat.
Enemy_Kind :: enum {
	Turkey,
	Goat,
	Billy,
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
	spin:   f32,
	hop:    f32,
	timer:  f32, // attack pause, dizzy time or time until it comes back
	ko:     bool, // knocked out: it disappears after landing
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
	egg_t:     f32, // a turkey lays an egg when this runs out
}

// A big farm turkey, a goat, and the billy goat, who weighs more than an
// ordinary Prosio.
ENEMY_KG := [Enemy_Kind]f32 {
	.Turkey = 16,
	.Goat   = 55,
	.Billy  = 95,
}
ENEMY_RADIUS := [Enemy_Kind]f32 {
	.Turkey = 0.42,
	.Goat   = 0.62,
	.Billy  = 0.78,
}
ENEMY_SPEED := [Enemy_Kind]f32 {
	.Turkey = 2.8,
	.Goat   = 2.3,
	.Billy  = 2.0,
}
ENEMY_GRIP := [Enemy_Kind]f32 {
	.Turkey = 560,
	.Goat   = 450,
	.Billy  = 500,
}
// An enemy bumped at least this fast is knocked out. A heavy animal needs
// less speed: it hits the ground that much harder. A turkey is knocked out
// by a bump from a Prosio of about 90 kg, a goat about 95 kg, and the billy
// goat only by a huge one, about 115 kg.
ENEMY_KO_SPEED := [Enemy_Kind]f32 {
	.Turkey = 15,
	.Goat   = 6,
	.Billy  = 4,
}

add_enemy :: proc(kind: Enemy_Kind, home: Vec2) {
	g.enemies[g.enemy_count] = Enemy {
		kind = kind,
		pos  = home,
		home = home,
		turn = g.enemy_count % 2 == 0 ? 1 : -1,
		hunt_t = random_range(1.5, 3),
		egg_t = random_range(EGG_EVERY.x * 0.3, EGG_EVERY.y),
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
	hills := REGIONS[.Hills].centre
	add_enemy(.Billy, hills)
	for placed, tries := 0, 0; placed < 5 && tries < 500; tries += 1 {
		pos := spot_in(.Hills, 0.6)
		if clear_spot(pos, 1) {
			add_enemy(.Goat, pos)
			placed += 1
		}
	}
}

// How fast a hit with this much momentum throws an enemy.
bump_speed :: proc(momentum: f32, kind: Enemy_Kind) -> f32 {
	return BUMP_GAIN * max(momentum - ENEMY_GRIP[kind], 0) / ENEMY_KG[kind]
}

// Sends an enemy flying. It is knocked out if it leaves at ko_speed or more
// (by default, the speed that knocks it out when bumped).
launch_enemy :: proc(e: ^Enemy, dir: Vec2, speed: f32, ko_speed: f32 = -1) {
	e.state = .Flying
	e.skip = false
	e.vel = dir * speed
	e.vy = speed * 0.55
	e.ko = speed >= (ko_speed >= 0 ? ko_speed : ENEMY_KO_SPEED[e.kind])
}

update_enemies :: proc(dt: f32) {
	p := &g.prosio

	for &e, index in g.enemies[:g.enemy_count] {
		r := ENEMY_RADIUS[e.kind]
		e.hit_t -= dt
		switch e.state {
		case .Gone:
			e.timer -= dt
			if e.timer <= 0 && length2(p.pos - e.home) > 3 {
				e.state = .Chase
				e.pos = e.home
				e.vel = {}
				e.y = 0
				burst({e.pos.x, 0.5, e.pos.y}, 10, 3, COLOR_DUST, 0.14)
			}

		case .Held:
		// Carried: update_grab moves it.

		case .Chase:
			e.timer -= dt
			e.turn_lock -= dt
			// Now and then a turkey lays an egg where it stands.
			if e.kind == .Turkey {
				e.egg_t -= dt
				if e.egg_t <= 0 {
					e.egg_t = random_range(EGG_EVERY.x, EGG_EVERY.y)
					behind := e.pos - facing_dir(e.facing) * ENEMY_RADIUS[e.kind] * 0.8
					if drop_egg(behind, 0.3) {
						burst({behind.x, 0.4, behind.y}, 3, 1.5, TURKEY_TIP, 0.06)
					}
				}
			}
			// Far from Prosio, it rests.
			if length2(p.pos - e.pos) > AWAKE {
				e.vel = {}
				continue
			}
			target := chase_velocity(&e, index, dt)
			accel: f32 = e.kind == .Turkey ? 14 : 10
			e.vel = approach2(e.vel, target, accel * dt)
			e.pos += e.vel * dt
			speed := length2(e.vel)
			look := e.vel
			if e.hunt == .Stalk && length2(p.pos - e.pos) < 9 {
				// Circling or squaring up, it keeps its eyes on him.
				look = normalize2(e.vel) * 0.6 + normalize2(p.pos - e.pos)
			}
			if speed > 0.3 && look != {} {
				e.facing = approach_angle(e.facing, math.atan2(look.x, look.y), 8 * dt)
			}
			e.hop += dt * (speed > 0.3 ? 9 : 3)
			if hit, n := collide_static(&e.pos, r, e.y, true); hit && dot2(target, n) < -0.2 * length2(target) {
				// Something is in the way: go round it, the side nearer its goal.
				along := Vec2{-n.y, n.x}
				side := dot2(along, target)
				if abs(side) > 0.2 * length2(target) && e.turn_lock <= 0 {
					e.turn = side > 0 ? 1 : -1
				}
				e.vel = along * e.turn * max(length2(target), speed)
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
			touch_prosio(&e, true)

		case .Flying:
			e.vy -= GRAVITY * dt
			e.y += e.vy * dt
			e.pos += e.vel * dt
			e.spin += length2(e.vel) * dt * 1.2
			if hit, n := collide_static(&e.pos, r, e.y, true); hit {
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
						launch_enemy(&other, normalize2(d), min(passed, speed))
						e.vel *= 0.5
						burst({other.pos.x, 0.6, other.pos.y}, 8, 4, COLOR_STAR, 0.12)
						break
					}
				}
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
				} else if e.vy < -4 {
					e.vy = -e.vy * 0.4
					e.vel *= 0.7
				} else {
					e.vy = 0
					e.skip = false
					e.state = .Dizzy
					e.timer = e.ko ? 0.7 : 2.5
				}
			}

		case .Dizzy:
			e.vel = approach2(e.vel, {}, 14 * dt)
			e.pos += e.vel * dt
			collide_static(&e.pos, r, e.y, true)
			e.y = 0
			e.timer -= dt
			touch_prosio(&e, false)
			if e.state == .Dizzy && e.timer <= 0 {
				if e.ko {
					e.state = .Gone
					e.timer = 12
					burst({e.pos.x, 0.6, e.pos.y}, 18, 5, COLOR_STAR, 0.15)
				} else {
					e.state = .Chase
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
}

// How fast, and which way, a chasing enemy wants to go.
chase_velocity :: proc(e: ^Enemy, index: int, dt: f32) -> Vec2 {
	p := &g.prosio
	speed := ENEMY_SPEED[e.kind]
	to := p.pos - e.pos
	dist := length2(to)
	goat := e.kind != .Turkey
	if p.fail != .None || dist > 11 || (goat && dist > 8) {
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
	toward := to / max(dist, 0.001)
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
			if dist < 6 && e.timer <= 0 && chargers() < 2 && random() < chance {
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

// A goat squares up to him, charges head down, and backs off again.
goat_velocity :: proc(e: ^Enemy, index: int, dist: f32, toward: Vec2) -> Vec2 {
	speed := ENEMY_SPEED[e.kind]
	switch e.hunt {
	case .Stalk:
		// A few steps off, facing him, pawing the ground.
		closing := clamp((dist - 4) * 1.2, -0.8 * speed, 0.8 * speed)
		v := toward * closing + keep_apart(e, index) * speed
		if e.hunt_t <= 0 {
			e.hunt_t = random_range(0.3, 0.8)
			if e.timer <= 0 && dist < 6.5 && random() < 0.6 {
				e.hunt = .Charge
				e.hunt_t = clamp(dist / (speed * 2.2) + 0.5, 0.8, 1.8)
				e.orbit = math.atan2(toward.x, toward.y) // straight at where he is now
				e.facing = e.orbit
			}
		}
		return v
	case .Charge:
		if e.hunt_t <= 0 {
			e.hunt = .Retreat
			e.hunt_t = random_range(0.7, 1.2)
		}
		return facing_dir(e.orbit) * speed * 2.2
	case .Retreat:
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
			if !p.swinging {
				p.vel = -away * min(BONK * ENEMY_KG[e.kind] / p.kg, 12)
			}
			p.stamina -= 12
			p.regen_delay = 0.4
			burn(HURT_BURN)
			p.wobble_vel += 3
			// After a shove he cannot be shoved again for a moment, so a
			// crowd of enemies cannot keep him pinned down.
			p.safe_t = 1.2
			if p.stamina <= 0 {
				// Knocked dizzy: a short rest, then he gets up with some
				// breath back and time to get away.
				p.stamina = 30
				p.dazed_t = 0.9
				p.safe_t = 3
				p.winded = false
				say("Wooo... dizzy...", 1.2)
			} else {
				say(e.kind == .Turkey ? "Ouch! It pecked me!" : "Oof! Headbutt!", 0.9)
			}
			e.vel = away * 4
			e.timer = 1.2
			e.hunt = .Retreat // strike and fall back, like a wolf
			e.hunt_t = random_range(0.8, 1.4)
			g.shake = max(g.shake, 0.25)
		}
	}

	// Push them apart, the lighter one moving more. If the enemy is pinned
	// against something, Prosio takes up the rest.
	overlap := pr + r - dist
	share := p.kg / (p.kg + ENEMY_KG[e.kind])
	e.pos += away * overlap * share
	p.pos -= away * overlap * (1 - share)
	collide_static(&e.pos, r, 0, true)
	collide_static(&p.pos, pr, p.height)
	left := pr + r - length2(e.pos - p.pos)
	if left > 0 {
		p.pos -= away * left
		collide_static(&p.pos, pr, p.height)
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

	if speed < min(WEAK_HIT, ENEMY_KO_SPEED[e.kind]) {
		// Too light: the enemy holds its ground and Prosio bounces back.
		e.vel = dir * speed
		e.timer = 0.6
		p.vel = -away * hit_speed * 0.45
		burst({e.pos.x, 0.7, e.pos.y}, 4, 2, COLOR_DUST, 0.1)
		say("Boing! I'm too light!", 1.2)
		return
	}

	launch_enemy(e, dir, speed)
	// A heavy Prosio ploughs on; a lighter one is slowed more.
	p.vel *= lerp(0.2, 0.75, fatness(p.kg))
	g.shake = max(g.shake, min(speed * 0.04, 0.8))
	burst({e.pos.x, 0.7, e.pos.y}, 6 + int(speed), 3 + speed * 0.2, COLOR_STAR, 0.12)
	if e.ko {
		say("BOOM!", 0.9)
	} else {
		hint("Not hard enough... I need more weight!")
	}
}

// Prosio lands on top of enemies. A hard landing throws them; a soft one
// leaves them dizzy, and he hops off either way.
stomp_enemies :: proc(landing_speed: f32) {
	p := &g.prosio
	if landing_speed < 3 || p.fail != .None {
		return
	}
	pr := prosio_radius(p.kg)
	stomped := false
	for &e in g.enemies[:g.enemy_count] {
		if e.state != .Chase && e.state != .Dizzy {
			continue
		}
		d := e.pos - p.pos
		dist := length2(d)
		if dist >= pr + ENEMY_RADIUS[e.kind] * 0.9 {
			continue
		}
		away := dist > 1e-4 ? d / dist : facing_dir(p.facing)
		speed := bump_speed(p.kg * landing_speed, e.kind)
		if speed >= min(WEAK_HIT, ENEMY_KO_SPEED[e.kind]) {
			launch_enemy(&e, away, speed)
		} else {
			e.state = .Dizzy
			e.ko = false
			e.timer = 1.8
			e.vel = away * 2
		}
		burst({e.pos.x, 0.7, e.pos.y}, 8, 4, COLOR_STAR, 0.12)
		stomped = true
	}
	if stomped {
		p.vy = 5
		p.airborne = true
		say("STOMP!", 0.8)
	}
}
