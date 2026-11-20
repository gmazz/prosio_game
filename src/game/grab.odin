package game

import "core:math"

// Grabbing, dragging, slamming and throwing. Everything happens while the
// grab button is held, and the throw comes when it is let go.
//
//   Animals are grabbed by the tail and dragged, rear end up, front paws
//   scraping. The tail is a rope: while it is taut, Prosio and the animal are
//   pulled together and each moves by a share set by the other's weight (a
//   digging animal counts DIG times its weight). So a heavy Prosio tows a fox
//   along, while a fleeing boar hauls a lean Prosio backwards. Letting go of
//   the button spins it round him like a hammer throw and lets it fly, at a
//   slightly different direction and angle every time. When it hits the
//   ground it is spinning, so it skips along, turning part of each fall into
//   forward speed, and bowls over whatever it meets.
//
//   Rocks are lifted overhead and held there. Letting go hurls them down in
//   front of him, and they skim across the ground.
//
// Nothing here is a yes-or-no rule; it all depends on how heavy the thing is
// compared with Prosio:
//
//   lifting    takes longer and costs more stamina the heavier it is;
//   holding    keeps draining stamina, and an animal wriggles free sooner
//              the heavier it is;
//   throwing   the push is proportional to Prosio's own weight, so the
//              speed of what he throws or slams is
//
//                  speed = THROW_GAIN * Prosio's weight / its weight
//
// A carried rock's weight counts as his: on the pressure plate, on the
// seesaws and when he lands. A dragged animal stands on its own feet, so it
// does not.

THROW_GAIN :: f32(2.6)
MAX_THROW :: f32(22)
MAX_THROWN :: 4
GRAB_REACH :: f32(0.85) // how far beyond touching he can reach: about an arm
LIFT_TIME :: f32(0.35) // seconds to lift something of his own weight
HOLD_TIME :: f32(3.0) // seconds he can hold an enemy of his own weight
CARRY_DRAIN :: f32(5) // stamina per second for carrying his own weight
// A rock of radius 0.3 weighs about 10 kg, 0.6 about 82 kg, and the big
// boulders (0.9) about 280 kg: liftable only by a heavy, rested Prosio.
ROCK_DENSITY :: f32(380)
DIG :: f32(1.5) // a dragged animal digs in: it resists like this many times its weight
LUNGE_SPEED :: f32(3) // how much faster a dragged animal pulls when it lunges
SKIP_KEEP :: f32(0.82) // share of forward speed kept at each skip
SKIP_BOUNCE :: f32(0.55) // share of falling speed that bounces back up
SKIP_SPIN :: f32(0.18) // share of falling speed the spin turns into forward speed

Carry :: enum {
	Nothing,
	Enemy,
	Rock,
}

// A rock in flight.
Thrown_Rock :: struct {
	active: bool,
	round:  int, // which rock of the world this is
	r, kg:  f32,
	pos:    Vec2,
	vel:    Vec2,
	y, vy:  f32,
	spin:   f32,
}

// A thrown enemy that leaves his hands at least this fast is knocked out.
ENEMY_THROW_KO := [Enemy_Kind]f32 {
	.Fox  = 12,
	.Boar = 1.5,
}

rock_kg :: proc(r: f32) -> f32 {
	return ROCK_DENSITY * r * r * r
}

// Prosio's weight together with a rock he is carrying. A dragged animal
// stands on its own feet, so it does not count.
total_kg :: proc() -> f32 {
	p := &g.prosio
	return p.kg + (p.carry == .Rock ? p.carry_kg : 0)
}



// An enemy with its feet on the ground, free to be bumped, grabbed or shoved.
on_ground :: proc(e: ^Enemy) -> bool {
	return e.state == .Chase || e.state == .Dizzy
}

Grab_Target :: struct {
	kind:  Carry,
	index: int,
	kg:    f32,
}

// The nearest thing within reach that can be picked up.
grab_target :: proc() -> (target: Grab_Target, found: bool) {
	p := &g.prosio
	pr := prosio_radius(p.kg)
	best := f32(1e9)
	for &e, i in g.enemies[:g.enemy_count] {
		if !on_ground(&e) {
			continue
		}
		gap := length2(e.pos - p.pos) - pr - ENEMY_RADIUS[e.kind]
		if gap < GRAB_REACH && gap < best {
			best = gap
			target = {.Enemy, i, ENEMY_KG[e.kind]}
			found = true
		}
	}
	for rd, i in g.rounds[:g.round_count] {
		if rd.kind != .Rock || rd.r <= 0 {
			continue
		}
		gap := length2(rd.pos - p.pos) - pr - rd.r
		if gap < GRAB_REACH && gap < best {
			best = gap
			target = {.Rock, i, rock_kg(rd.r)}
			found = true
		}
	}
	return
}

// How big the thing he carries is.
carry_radius :: proc() -> f32 {
	p := &g.prosio
	switch p.carry {
	case .Enemy:
		return ENEMY_RADIUS[g.enemies[p.carry_index].kind]
	case .Rock:
		return p.carry_r
	case .Nothing:
	}
	return 0
}

// Where the carried thing is: it starts in front of him and ends overhead.
carry_place :: proc() -> (pos: Vec2, height: f32) {
	p := &g.prosio
	lifted := smooth(1 - p.lift_t / max(p.lift_total, 0.001))
	reach := (prosio_radius(p.kg) + carry_radius()) * (1 - lifted)
	pos = p.pos + facing_dir(p.facing) * reach
	height = p.height + lerp(0.05, 1.95, lifted)
	return
}

update_grab :: proc(dt: f32, can_act: bool) {
	p := &g.prosio

	if p.carry == .Nothing {
		if p.airborne || !can_act || p.pushups || !pressed(.Grab) {
			return
		}
		target, found := grab_target()
		if !found {
			hint("Nothing to grab here.")
			return
		}
		ratio := target.kg / p.kg
		cost := 6 + 25 * ratio
		if p.stamina < cost {
			hint("Too tired to grab that!")
			return
		}
		p.stamina -= cost
		p.regen_delay = 0.5
		p.carry = target.kind
		p.carry_index = target.index
		p.carry_kg = target.kg
		p.held_t = 0
		p.snatching = false
		p.lunge_t = 0
		p.throw_queued = false

		towards: Vec2
		switch target.kind {
		case .Enemy:
			// Catching the tail is quick; it is the dragging that is hard.
			p.lift_total = clamp(0.12 * ratio, 0.06, 0.3)
			e := &g.enemies[target.index]
			towards = e.pos - p.pos
			e.state = .Held
			e.vel = {}
			e.y = 0
			say(ratio > 0.9 ? "Got your tail! Oof, heavy!" : "Got your tail!", 1)
		case .Rock:
			p.lift_total = clamp(LIFT_TIME * ratio, 0.08, 1.2)
			p.vel = {}
			rd := &g.rounds[target.index]
			towards = rd.pos - p.pos
			p.carry_r = rd.r
			rd.r = 0 // it is in his hands now, not on the ground
			say(ratio > 0.9 ? "Hnnngh... so heavy!" : "Up it goes!", 1)
		case .Nothing:
		}
		p.lift_t = p.lift_total
		if towards != {} {
			p.facing = math.atan2(towards.x, towards.y)
		}
		return
	}

	// Holding.
	ratio := p.carry_kg / p.kg
	p.lift_t -= dt
	p.held_t += dt
	if p.snatching {
		update_snatch(dt)
		return
	}
	// Space while dragging: snatch it.
	if p.carry == .Enemy && p.lift_t <= 0 && pressed(.Bump) {
		begin_snatch()
		return
	}
	p.stamina -= CARRY_DRAIN * ratio * dt
	p.regen_delay = 0.5

	if p.stamina <= 0 {
		p.stamina = 0
		drop_carry()
		say("Too heavy! I can't hold on!", 1.4)
		return
	}
	if p.carry == .Enemy && p.held_t > HOLD_TIME / ratio {
		drop_carry()
		p.safe_t = max(p.safe_t, 0.8)
		say("It wriggled free!", 1.2)
		return
	}
	if !button_down(.Grab) {
		p.throw_queued = true
	}
	if p.throw_queued && p.lift_t <= 0 {
		switch p.carry {
		case .Enemy:
			drop_carry() // letting go of a tail just lets it go
			say("Off you go!", 0.8)
		case .Rock:
			throw_rock()
		case .Nothing:
		}
	}
}

// Where each animal's tail tip is, in its own model (units of its radius).
TAIL_TIP := [Enemy_Kind]Vec3 {
	.Fox  = {0, 1.57, -2.18},
	.Boar = {0.05, 0.78, -1.32},
}
FRONT_PAW_Z :: f32(0.63) // how far forward its front paws are, in the same units
HOLD_HEIGHT :: f32(1.15) // how high Prosio holds a tail
SNATCH_HEIGHT :: f32(0.95) // the height a snatched animal sweeps round at
AIM_SPREAD :: f32(0.6) // a throw goes up to this far (radians) either side of the aim

// How far in front of his middle Prosio's hands are when he holds a tail.
hold_reach :: proc() -> f32 {
	return prosio_radius(g.prosio.kg) + 0.25
}

// How an animal hangs from its tail: the model is placed so that its tail
// tip is exactly in Prosio's hands, then tipped nose-down by its tilt.
held_matrix :: proc(e: ^Enemy) -> Mat4 {
	r := ENEMY_RADIUS[e.kind]
	return translate(e.tip) * rot_y(e.facing) * rot_x(e.tilt) * scale({r, r, r}) * translate(-TAIL_TIP[e.kind])
}

// Hangs an animal from a tail held at tip, and updates where its body is.
hang :: proc(e: ^Enemy, tip: Vec3, facing, tilt: f32) {
	e.tip, e.facing, e.tilt = tip, facing, tilt
	origin := held_matrix(e) * [4]f32{0, 0, 0, 1}
	e.pos = origin.xz
	e.y = origin.y
}

// How far its rear is lifted when its tail is held at this height and its
// front paws stay on the ground. A small animal hangs almost nose-down; a
// big one barely tips.
drag_tilt :: proc(kind: Enemy_Kind, height: f32) -> f32 {
	r := ENEMY_RADIUS[kind]
	tip := TAIL_TIP[kind]
	up := tip.y
	along := FRONT_PAW_Z - tip.z
	reach := math.sqrt(up * up + along * along)
	need := height / r
	if need >= reach {
		return math.atan2(along, up) // even fully tipped, its paws are off the ground
	}
	return math.atan2(along, up) - math.acos(need / reach)
}

// Keeps a dragged animal hanging from his hands. Called after Prosio has
// moved this step.
update_drag :: proc(dt: f32) {
	p := &g.prosio
	if p.carry != .Enemy || p.snatching {
		return
	}
	e := &g.enemies[p.carry_index]
	d := e.pos - p.pos
	dist := length2(d)
	u := dist > 1e-4 ? d / dist : facing_dir(p.facing)

	// It keeps trying to run away, now and then with a sudden lunge.
	p.lunge_t -= dt
	if p.lunge_t < -random_range(0.5, 1.1) {
		p.lunge_t = 0.25
	}
	pull := ENEMY_SPEED[e.kind] * (p.lunge_t > 0 ? LUNGE_SPEED : 1)
	e.pos += u * pull * dt
	e.hop += dt * 14

	// The held tail is a rope: when it is taut they are pulled together, and
	// each moves by the other's share of their weight.
	height := HOLD_HEIGHT
	tilt := drag_tilt(e.kind, height)
	probe := e^
	hang(&probe, {0, height, 0}, 0, tilt)
	length := hold_reach() + probe.pos.y // facing 0 is +z, so .y here is its distance beyond his hands
	d = e.pos - p.pos
	dist = length2(d)
	if dist > length {
		excess := dist - length
		animal := ENEMY_KG[e.kind] * DIG
		his_share := animal / (p.kg + animal)
		u = d / dist
		p.pos += u * excess * his_share
		collide_static(&p.pos, prosio_radius(p.kg), p.height)
	}
	d = e.pos - p.pos
	if length2(d) > 1e-4 {
		u = normalize2(d)
	}

	// He faces it, leaning back, with its tail in both hands.
	reach := hold_reach()
	tip := Vec3{p.pos.x + u.x * reach, p.height + height, p.pos.y + u.y * reach}
	p.facing = math.atan2(u.x, u.y)
	hang(e, tip, p.facing, tilt)
	p.hand = tip

	// Its front paws scrape along the ground.
	e.timer -= dt
	if e.timer <= 0 && (length2(p.vel) > 0.5 || p.lunge_t > 0) {
		e.timer = 0.09
		for side in ([2]f32{-1, 1}) {
			paw := held_matrix(e) * [4]f32{side * 0.34, 0, FRONT_PAW_Z, 1}
			burst({paw.x, 0.08, paw.z}, 1, 1.4, COLOR_DUST, 0.08)
		}
	}
}

// The snatch. While dragging, Space yanks the animal round and flings it the
// way he is heading. It is a real two-body spin: Prosio and the animal turn
// together about their shared centre of weight, and at the end his legs give
// them equal and opposite pushes. So:
//
//   - a heavy Prosio barely moves and whips a fox round himself;
//   - a boar weighs more than he does, so the pivot is near the boar: Prosio
//     swings round it while it hardly budges, and he is the one sent reeling.
//
// The animal leaves at  SNATCH_GAIN * his weight / its weight, more the
// further the snatch twists (up to half a turn); he recoils at the matching
// speed the other way. Whatever the animal sweeps into on the way is hit, as
// by a club.

SNATCH_GAIN :: f32(2.6)
BASH_GAIN :: f32(1.6) // how much of the club's speed a struck animal or rock takes

// The arrows: where he is heading, and so where a snatch will fling it.
arrow_aim :: proc() -> (aim: Vec2) {
	if button_down(.Left) {aim.x -= 1}
	if button_down(.Right) {aim.x += 1}
	if button_down(.Up) {aim.y -= 1}
	if button_down(.Down) {aim.y += 1}
	return normalize2(aim)
}

// Where a snatch would fling the animal right now: the way he is heading,
// or, standing still, straight past him to the far side.
snatch_heading :: proc() -> f32 {
	p := &g.prosio
	if aim := arrow_aim(); aim != {} {
		return math.atan2(aim.x, aim.y)
	}
	e := &g.enemies[p.carry_index]
	d := p.pos - e.pos
	return math.atan2(d.x, d.y)
}

angle_gap :: proc(a, b: f32) -> f32 {
	d := math.mod(a - b + math.PI, math.TAU)
	if d < 0 {
		d += math.TAU
	}
	return abs(d - math.PI)
}

begin_snatch :: proc() {
	p := &g.prosio
	e := &g.enemies[p.carry_index]
	heading := snatch_heading()
	d := e.pos - p.pos
	start := math.atan2(d.x, d.y)

	// It flies off along its arc, so it must be let go a quarter turn before
	// the heading: twist whichever way gets there sooner.
	best_sweep := f32(1e9)
	for sign in ([2]f32{-1, 1}) {
		release := heading - sign * math.PI / 2
		sweep := math.mod(sign * (release - start), math.TAU)
		if sweep < 0 {
			sweep += math.TAU
		}
		if sweep < best_sweep {
			best_sweep = sweep
			p.snatch_sign = sign
		}
	}
	sweep := max(best_sweep, 0.35)

	// Both turn about their shared centre of weight.
	mp, ma := p.kg, ENEMY_KG[e.kind]
	centre := (p.pos * mp + e.pos * ma) / (mp + ma)
	apart := max(length2(d), 0.5)
	p.snatch_centre = centre
	p.snatch_start = start
	p.snatch_sweep = sweep
	p.snatch_reach_p = apart * ma / (mp + ma) // his distance from the centre
	p.snatch_reach_a = apart * mp / (mp + ma) // the animal's
	twist := 0.5 + 0.5 * min(sweep / math.PI, 1)
	p.snatch_speed = min(SNATCH_GAIN * mp / ma * twist, MAX_THROW)
	p.snatch_heading = heading
	p.snatch_rise = random_range(-0.4, 0.15)
	p.snatch_tilt = e.tilt
	ratio := ma / mp
	p.snatch_total = 0.12 + 0.1 * min(ratio, 3) + 0.03 * sweep // violent and quick; a heavy one takes longer
	p.snatch_t = 0
	p.snatching = true
	p.vel = {}
	say(ratio > 1 ? "Hnnnngh!" : "HUP!", 0.6)
}

update_snatch :: proc(dt: f32) {
	p := &g.prosio
	e := &g.enemies[p.carry_index]
	p.snatch_t += dt
	k := min(p.snatch_t / p.snatch_total, 1)
	// It speeds up all the way, like the crack of a whip.
	angle := p.snatch_start + p.snatch_sign * p.snatch_sweep * k * k
	out := facing_dir(angle)
	p.pos = p.snatch_centre - out * p.snatch_reach_p
	collide_static(&p.pos, prosio_radius(p.kg), p.height)
	p.facing = angle
	reach := hold_reach()
	height := p.height + lerp(HOLD_HEIGHT, SNATCH_HEIGHT, smooth(k * 2))
	tip := Vec3{p.pos.x + out.x * reach, height, p.pos.y + out.y * reach}
	hang(e, tip, angle, lerp(p.snatch_tilt, -0.15, smooth(k * 2)))
	p.hand = tip

	// What it sweeps into is hit, at the speed it is moving now.
	if snatch_hits(p.snatch_speed * k) {
		return // it bonked into something solid
	}
	if k >= 1 {
		fling(p.snatch_speed, p.snatch_heading, true)
	}
}

// The snatched animal hits like a club: whatever it strikes takes a share of
// its speed set by their weights, as when two balls collide. Anything too
// big to knock away stops it dead. Returns true if it did.
snatch_hits :: proc(speed: f32) -> bool {
	p := &g.prosio
	e := &g.enemies[p.carry_index]
	if speed < 1 {
		return false
	}
	r := ENEMY_RADIUS[e.kind]
	club := ENEMY_KG[e.kind]
	angle := p.snatch_start + p.snatch_sign * p.snatch_sweep * min(p.snatch_t / p.snatch_total, 1)
	along := facing_dir(angle + p.snatch_sign * math.PI / 2)
	hit_dir := normalize2(along * 0.75 + facing_dir(angle) * 0.45)

	for &o, i in g.enemies[:g.enemy_count] {
		if i == p.carry_index || o.hit_t > 0 {
			continue
		}
		if !on_ground(&o) && !(o.state == .Flying && o.y < 1.6) {
			continue
		}
		if length2(o.pos - e.pos) >= r + ENEMY_RADIUS[o.kind] {
			continue
		}
		other := ENEMY_KG[o.kind]
		passed := BASH_GAIN * club / (club + other) * speed
		launch_enemy(&o, hit_dir, passed, ENEMY_THROW_KO[o.kind])
		o.skip = true
		o.hit_t = 0.4
		if speed >= ENEMY_THROW_KO[e.kind] {
			e.ko = true // the club gets knocked out too
		}
		g.shake = max(g.shake, min(passed * other / 500, 0.7))
		burst({o.pos.x, 0.8, o.pos.y}, 10, 4, COLOR_STAR, 0.13)
		say(passed > 8 ? "BASH!" : "Bonk!", 0.7)
	}

	for &rd, i in g.rounds[:g.round_count] {
		if rd.kind != .Rock || rd.r <= 0 || length2(rd.pos - e.pos) >= r + rd.r {
			continue
		}
		rock := rock_kg(rd.r)
		if rock > club * 2.5 {
			continue // a boulder: it stops the snatch, below
		}
		passed := BASH_GAIN * club / (club + rock) * speed
		for &t in g.thrown {
			if !t.active {
				t = Thrown_Rock{active = true, round = i, r = rd.r, kg = rock, pos = rd.pos, vel = hit_dir * passed, y = 0.05, vy = passed * 0.3}
				rd.r = 0
				break
			}
		}
		burst({rd.pos.x, 0.5, rd.pos.y}, 8, 3, COLOR_DUST, 0.12)
	}

	// Walls, trees, boulders: BONK. It drops off, dazed, bouncing back.
	probe := e.pos
	if hit, n := collide_static(&probe, r * 0.85, e.y, true); hit {
		if speed >= ENEMY_THROW_KO[e.kind] {
			e.ko = true
		}
		g.shake = max(g.shake, min(speed * club / 600, 0.6))
		burst({e.pos.x, e.y + r, e.pos.y}, 10, 3.5, COLOR_STAR, 0.13)
		say("BONK!", 0.7)
		fling(speed * 0.3, math.atan2(n.x, n.y), false)
		return true
	}
	return false
}

// Lets go: the animal flies off, and Prosio recoils with equal and opposite
// momentum (the same push, divided by his weight).
fling :: proc(speed, heading: f32, recoil: bool) {
	p := &g.prosio
	e := &g.enemies[p.carry_index]
	out := facing_dir(heading)
	knocked := e.ko
	launch_enemy(e, out, speed, ENEMY_THROW_KO[e.kind])
	e.ko = e.ko || knocked
	e.vel = out * speed * math.cos(p.snatch_rise)
	e.vy = speed * math.sin(p.snatch_rise)
	e.skip = true
	e.tilt = 0
	e.spin = random_range(0, math.TAU)
	e.y = max(e.y, 0.1)
	collide_static(&e.pos, ENEMY_RADIUS[e.kind], e.y, true)

	if recoil {
		p.vel = -out * min(speed * ENEMY_KG[e.kind] / p.kg, 12)
	}
	p.carry = .Nothing
	p.carry_kg = 0
	p.snatching = false
	p.stretch_vel -= 3
	p.kg -= DASH_BURN
	g.shake = max(g.shake, min(speed * ENEMY_KG[e.kind] / 600, 0.7))
	if recoil {
		say(speed > 9 ? "HAI-YA!" : (ENEMY_KG[e.kind] > p.kg ? "Whoa-oa-oa!" : "Hup!"), 0.9)
	}
}

// While he drags an animal: an arrow on the ground showing where a snatch
// would fling it.
draw_snatch_aim :: proc() {
	p := &g.prosio
	if p.carry != .Enemy || p.snatching || p.lift_t > 0 {
		return
	}
	heading := snatch_heading()
	dir := facing_dir(heading)
	aimed := arrow_aim() != {}
	color := aimed ? Color{255, 220, 70, 230} : Color{255, 255, 255, 150}
	ground := p.height + 0.06
	outlines_enabled = false
	for k in 0 ..< 4 {
		at := p.pos + dir * (1.2 + f32(k) * 0.42)
		tube(IDENTITY, {at.x, ground, at.y}, 0.1, 0.01, color)
	}
	head := p.pos + dir * 3.0
	draw_shape(.Cone, translate({head.x, ground, head.y}) * rot_y(heading) * rot_x(math.PI / 2) * scale({0.3, 0.42, 0.02}), color)
	outlines_enabled = true
}

// Letting go of a rock overhead: it is hurled down in front of him.
throw_rock :: proc() {
	p := &g.prosio
	dir := facing_dir(p.facing)
	speed := min(THROW_GAIN * p.kg / p.carry_kg, MAX_THROW)
	_, height := carry_place()
	for &t in g.thrown {
		if t.active {
			continue
		}
		t = Thrown_Rock {
			active = true,
			round  = p.carry_index,
			r      = p.carry_r,
			kg     = p.carry_kg,
			pos    = p.pos + dir * 0.3,
			vel    = dir * speed,
			y      = height,
			vy     = -speed * 0.3, // thrown down, not up
		}
		break
	}
	// Every push pushes back.
	p.vel -= dir * min(speed * p.carry_kg / p.kg, 4)
	p.carry = .Nothing
	p.carry_kg = 0
	p.stretch_vel -= 3
	p.kg -= DASH_BURN
	say(speed > 9 ? "HAI-YA!" : "Oof!", 0.9)
	burst({p.pos.x, p.height + 0.1, p.pos.y}, 6, 2.5, COLOR_DUST, 0.12)
}

// Lets go of whatever he holds; it ends up on the ground in front of him.
drop_carry :: proc() {
	p := &g.prosio
	dir := facing_dir(p.facing)
	pr := prosio_radius(p.kg)
	switch p.carry {
	case .Enemy:
		// Let go of the tail: it stays where it is, a little dazed.
		e := &g.enemies[p.carry_index]
		if p.snatching {
			e.pos = p.pos + dir * (pr + ENEMY_RADIUS[e.kind] + 0.05)
		}
		e.y = 0
		e.vy = 0
		e.tilt = 0
		e.state = .Dizzy
		e.ko = false
		e.timer = 0.8
		collide_static(&e.pos, ENEMY_RADIUS[e.kind], 0, true)
	case .Rock:
		rd := &g.rounds[p.carry_index]
		rd.pos = p.pos + dir * (pr + p.carry_r + 0.05)
		collide_static(&rd.pos, p.carry_r, 0, true)
		rd.r = p.carry_r
	case .Nothing:
	}
	p.carry = .Nothing
	p.carry_kg = 0
	p.snatching = false
}

update_thrown :: proc(dt: f32) {
	for &t in g.thrown {
		if !t.active {
			continue
		}
		t.vy -= GRAVITY * dt
		t.y += t.vy * dt
		t.pos += t.vel * dt
		speed := length2(t.vel)
		t.spin += speed * dt

		if hit, n := collide_static(&t.pos, t.r, t.y, true); hit {
			into := dot2(t.vel, n)
			if into < 0 {
				t.vel -= n * into * 1.4 // a dull bounce
				burst({t.pos.x, t.y + t.r, t.pos.y}, 5, 2, COLOR_DUST, 0.1)
			}
		}

		// A flying rock knocks enemies over: a heavier rock passes on more of its speed.
		if speed > 2 {
			for &e in g.enemies[:g.enemy_count] {
				reach := t.r + ENEMY_RADIUS[e.kind]
				if !on_ground(&e) || t.y > ENEMY_RADIUS[e.kind] * 2 || length2(e.pos - t.pos) >= reach {
					continue
				}
				passed := 1.6 * t.kg / (t.kg + ENEMY_KG[e.kind]) * speed
				launch_enemy(&e, normalize2(t.vel), passed, ENEMY_THROW_KO[e.kind])
				t.vel *= 0.5
				g.shake = max(g.shake, 0.3)
				burst({e.pos.x, 0.7, e.pos.y}, 10, 4, COLOR_STAR, 0.12)
			}
		}

		if t.y <= 0 && t.vy < 0 {
			// Down. A heavy enough rock also smashes the crate.
			if !g.crate_broken && length2(t.pos - g.crate_pos) < CRATE_HIT_RADIUS && t.kg * (speed - t.vy) > 250 {
				smash_crate()
			}
			g.shake = max(g.shake, min(t.kg * -t.vy * 0.0015, 0.5))
			burst({t.pos.x, 0.2, t.pos.y}, 10, 3, COLOR_DUST, 0.14)
			// Still fast: it skims on, a little lower and slower each time.
			if speed > 3 && t.vy < -1.5 {
				t.y = 0
				t.vy = -t.vy * 0.45
				t.vel *= 0.8
				continue
			}
			// It becomes an ordinary rock again, clear of everything else.
			collide_static(&t.pos, t.r, 0, true)
			push_out_circle(&t.pos, t.r, g.prosio.pos, prosio_radius(g.prosio.kg))
			rd := &g.rounds[t.round]
			rd.pos = t.pos
			rd.r = t.r
			t.active = false
		}
	}
}

draw_rock :: proc(m: Mat4, r: f32) {
	set_surface(.Stone)
	ball(m, {0, 0, 0}, {r, r * 0.75, r}, COLOR_ROCK)
	ball(m, {r * 0.35, r * 0.3, r * 0.2}, {r * 0.5, r * 0.4, r * 0.5}, COLOR_ROCK_LIGHT)
	set_surface(.Solid)
}

// The rock in his hands, and rocks in the air.
draw_grab :: proc() {
	p := &g.prosio
	if p.carry == .Rock {
		pos, height := carry_place()
		draw_rock(translate({pos.x, height + p.carry_r * 0.75, pos.y}) * rot_y(p.facing), p.carry_r)
	}
	for t in g.thrown {
		if t.active {
			shadow(t.pos, t.r, 0, t.y)
			draw_rock(translate({t.pos.x, t.y + t.r * 0.75, t.pos.y}) * rot_x(t.spin), t.r)
		}
	}
}
