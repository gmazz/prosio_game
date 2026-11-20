package game

import "core:math"

MAX_ENEMIES :: 24

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

Enemy_Kind :: enum {
	Fox,
	Boar,
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
	tip:    Vec3, // while held: the point where Prosio holds its tail
	tilt:   f32, // while held: how far its rear is lifted (radians)
	hit_t:  f32, // just hit by a swung animal: not hit again until this runs out
}

// Weight goes with volume: the boar is about 2.1 times the fox's size, so it
// is about 9.4 times as heavy (weight grows with size cubed).
ENEMY_KG := [Enemy_Kind]f32 {
	.Fox  = 20,
	.Boar = 190,
}
ENEMY_RADIUS := [Enemy_Kind]f32 {
	.Fox  = 0.45,
	.Boar = 0.95,
}
ENEMY_SPEED := [Enemy_Kind]f32 {
	.Fox  = 2.6,
	.Boar = 1.7,
}
ENEMY_GRIP := [Enemy_Kind]f32 {
	.Fox  = 600,
	.Boar = 700,
}
// An enemy bumped at least this fast is knocked out. A heavy animal needs
// less speed: it hits the ground that much harder.
ENEMY_KO_SPEED := [Enemy_Kind]f32 {
	.Fox  = 12,
	.Boar = 1.6,
}

add_enemy :: proc(kind: Enemy_Kind, home: Vec2) {
	g.enemies[g.enemy_count] = Enemy {
		kind = kind,
		pos  = home,
		home = home,
	}
	g.enemy_count += 1
}

spawn_enemies :: proc() {
	add_enemy(.Fox, {-5, -2})
	add_enemy(.Fox, {5, -3})
	add_enemy(.Fox, {-12, -0.5})
	add_enemy(.Fox, {10, 8})
	add_enemy(.Boar, {0, -22})
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
			if e.kind == .Fox {
				e.timer -= dt
				if e.timer <= 0 && length2(p.pos - e.home) > 3 {
					e.state = .Chase
					e.pos = e.home
					e.vel = {}
					e.y = 0
					burst({e.pos.x, 0.5, e.pos.y}, 10, 3, COLOR_DUST, 0.14)
				}
			}

		case .Held:
		// Carried: update_grab moves it.

		case .Chase:
			e.timer -= dt
			to_prosio := p.pos - e.pos
			dist := length2(to_prosio)
			target: Vec2
			if p.fail == .None && dist < 9 && e.timer <= 0 {
				target = to_prosio / max(dist, 0.001) * ENEMY_SPEED[e.kind]
			} else if e.timer <= 0 && length2(e.home - e.pos) > 1 {
				target = normalize2(e.home - e.pos) * ENEMY_SPEED[e.kind] * 0.6
			}
			e.vel = approach2(e.vel, target, 10 * dt)
			e.pos += e.vel * dt
			speed := length2(e.vel)
			if speed > 0.3 {
				e.facing = approach_angle(e.facing, math.atan2(e.vel.x, e.vel.y), 8 * dt)
			}
			e.hop += dt * (speed > 0.3 ? 9 : 3)
			collide_static(&e.pos, r, 0, true)
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
			collide_static(&e.pos, r, 0, true)
			e.timer -= dt
			touch_prosio(&e, false)
			if e.state == .Dizzy && e.timer <= 0 {
				if e.ko {
					e.state = .Gone
					e.timer = 12
					burst({e.pos.x, 0.6, e.pos.y}, 18, 5, COLOR_STAR, 0.15)
					if e.kind == .Boar && !g.truffles[2].visible {
						g.truffles[2] = {pos = e.pos, visible = true}
					}
				} else {
					e.state = .Chase
					e.timer = 0.5
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

// Everything that happens when an enemy on the ground and Prosio touch:
// his bump lands, or it shoves him, and either way they end up side by side.
touch_prosio :: proc(e: ^Enemy, can_shove: bool) {
	p := &g.prosio
	r := ENEMY_RADIUS[e.kind]
	pr := prosio_radius(p.kg)
	d := e.pos - p.pos
	dist := length2(d)
	if dist >= pr + r || p.height > r * 1.8 {
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
			// middle of a snatch he cannot be pushed off course.
			if p.carry == .Rock {
				drop_carry()
			}
			if !p.snatching {
				p.vel = -away * min(BONK * ENEMY_KG[e.kind] / p.kg, 12)
			}
			p.stamina -= 12
			p.regen_delay = 0.4
			p.wobble_vel += 3
			p.pushups_on = false
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
				say("Ouch!", 0.8)
			}
			e.vel = away * 4
			e.timer = 1.2
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
