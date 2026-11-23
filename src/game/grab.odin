package game

import "core:math"
import "core:math/linalg"

// Grabbing, dragging, bashing and throwing. F grabs, and F again throws:
// nothing has to be held down.
//
//   Animals are caught by the legs with one hand: a turkey by both feet,
//   held up so that it dangles head down, flapping; a goat by a hind leg,
//   dragged along behind him as he walks. The animal is not stiff: its body
//   is a short chain of points (the feet in his hand, the middle of its body,
//   its shoulders) that swing, fall and drag on the ground under their own
//   weight, and its other legs dangle. So when he whacks it about it flops
//   like a sack.
//
//   The held leg is a rope. While it is taut, Prosio and the animal are
//   pulled together and each gives way by the other's share of their weight
//   (an animal standing on its feet digs in, and counts DIG times its
//   weight). A turkey hardly slows him down. The billy goat weighs more than
//   he does: it drags him about on his heels while he leans back and strains.
//
//   SPACE swings the animal like a club, roughly the way he is walking: over
//   his head or round his side, slamming it into the ground in front of him
//   and into anything standing there. Each swing goes a little differently.
//   F hurls it away the way he is walking. Only something lighter than
//   LIFT_LIMIT times his own weight can be swung or thrown; the billy goat
//   can only be hung on to, until it pulls free or he lets go.
//
//   Rocks are lifted overhead and held there. F again hurls them down in
//   front of him, and they skim across the ground.
//
// Nothing here is a yes-or-no rule; it all depends on how heavy the thing is
// compared with Prosio:
//
//   lifting    takes longer and costs more stamina the heavier it is;
//   holding    keeps draining stamina, and a struggling animal pulls free
//              sooner the heavier it is;
//   swinging   takes longer the heavier it is, so it hits less hard;
//   throwing   the push is proportional to Prosio's own weight, so the
//              speed of what he throws is
//
//                  speed = gain * Prosio's weight / its weight
//
// A carried rock's weight counts as his: on the pressure plate, on the
// seesaws and when he lands. A dragged animal stands on its own feet, so it
// does not.

// Rocks and stones: his arms put the same energy into every throw,
// THROW_ENERGY joules for each kilogram of him (times the strength of his
// arms), so the speed is the square root of twice that over the stone's
// weight. A heavy rock is a short, slow lob; a light stone would fly faster
// than an arm can move, and leaves at ARM_SPEED (times the root of his
// strength) at the most.
THROW_ENERGY :: f32(8)
ARM_SPEED :: f32(22)
PEBBLE_KG :: f32(0.3)
PEBBLE_RADIUS :: f32(0.07)
PEBBLE_COST :: f32(3) // stamina to throw one
// What a thrown stone does to an animal it hits is the blow of an animal of
// that kind landing with the stone's energy, counted STONE_HARD times over
// (a stone does not give). A stone under LIGHT_STONE kg knocks nothing over:
// it stings, startles (the animal runs for PEBBLE_FRIGHT seconds) and makes
// a fox drop what it stole.
STONE_HARD :: f32(2)
LIGHT_STONE :: f32(2)
PEBBLE_FRIGHT :: Vec2{3, 6}
AIM_RANGE :: f32(16) // how far off he can pick something out to throw at

stone_speed :: proc(kg: f32) -> f32 {
	return min(math.sqrt(2 * THROW_ENERGY * strength() * g.prosio.kg / kg), ARM_SPEED * math.sqrt(strength()))
}

stone_damage :: proc(kg, speed: f32, kind: Enemy_Kind) -> f32 {
	return STONE_HARD * blow_damage(kind, speed * math.sqrt(kg / ENEMY_KG[kind]))
}

// What he is aiming a throw at, chosen while he winds up.
Aim_Kind :: enum {
	None,
	Enemy,
	Pest,
}
Aim :: struct {
	kind:  Aim_Kind,
	index: int,
}

// Where the thing he aims at is, how high its middle is and how it is
// moving; ok is false if it can no longer be aimed at.
aim_at :: proc(a: Aim) -> (pos: Vec2, height: f32, vel: Vec2, ok: bool) {
	p := &g.prosio
	switch a.kind {
	case .Enemy:
		e := &g.enemies[a.index]
		if (e.state != .Chase && e.state != .Dizzy) || (p.carry == .Enemy && p.carry_index == a.index) {
			return
		}
		pos, height, vel, ok = e.pos, ENEMY_RADIUS[e.kind], e.state == .Chase ? e.vel : Vec2{}, true
	case .Pest:
		c := &g.pests[a.index]
		if c.state == .Away {
			return
		}
		pos, height, ok = c.pos, c.y + 0.2, true
	case .None:
	}
	if ok && length2(pos - p.pos) > AIM_RANGE {
		ok = false
	}
	return
}

// The best thing to aim at in this direction from him: as nearly that way
// as possible (at least `least`, as a cosine), and nearer rather than
// further. Not `skip`.
aim_towards :: proc(dir: Vec2, least: f32, skip: Aim) -> (best: Aim) {
	try :: proc(a: Aim, dir: Vec2, least: f32, skip: Aim, best: ^Aim, best_score: ^f32) {
		if a == skip {
			return
		}
		pos, _, _, ok := aim_at(a)
		to := pos - g.prosio.pos
		dist := length2(to)
		if !ok || dist < 0.01 {
			return
		}
		along := dot2(to / dist, dir)
		if along < least {
			return
		}
		if score := along - 0.6 * dist / AIM_RANGE; score > best_score^ {
			best^, best_score^ = a, score
		}
	}
	best_score := f32(-1e9)
	for i in 0 ..< g.enemy_count {
		try({.Enemy, i}, dir, least, skip, &best, &best_score)
	}
	for i in 0 ..< len(g.pests) {
		try({.Pest, i}, dir, least, skip, &best, &best_score)
	}
	return
}

// While he winds up he stands and aims. At first it is the nearest thing in
// front of him; a direction button moves the aim to the next thing that way,
// or, with nothing there, just turns him that way to throw at nothing.
update_aim :: proc() {
	p := &g.prosio
	if _, _, _, ok := aim_at(p.aim); !ok {
		p.aim = {}
	}
	key: Vec2
	if pressed(.Left) {key.x -= 1}
	if pressed(.Right) {key.x += 1}
	if pressed(.Up) {key.y -= 1}
	if pressed(.Down) {key.y += 1}
	if key != {} {
		key = normalize2(key)
		if next := aim_towards(key, 0.4, p.aim); next.kind != .None {
			p.aim = next
		} else {
			p.aim = {}
			p.facing = math.atan2(key.x, key.y)
		}
	}
	if pos, _, _, ok := aim_at(p.aim); ok {
		to := pos - p.pos
		p.facing = math.atan2(to.x, to.y)
	}
}

// The way to throw, and how fast upwards, for a stone leaving `from` at
// this height and speed to come down on what he aims at (leading it if it
// moves). ok is false with nothing aimed at.
aimed_throw :: proc(from: Vec2, height, speed: f32) -> (dir: Vec2, rise: f32, ok: bool) {
	pos, h, vel, has := aim_at(g.prosio.aim)
	if !has || speed < 0.5 {
		return
	}
	t := length2(pos - from) / speed
	to := pos + vel * t - from
	dist := length2(to)
	if dist < 0.3 {
		return
	}
	t = dist / speed
	return to / dist, clamp((h - height) / t + GRAVITY * t / 2, -speed, speed * 0.9), true
}

// A pebble or a spear out of the sack, thrown.
throw_stone :: proc() {
	p := &g.prosio
	item := p.wind_item
	spear := item == .Spear
	cost := spear ? SPEAR_COST : PEBBLE_COST
	kg := spear ? SPEAR_KG : PEBBLE_KG
	if p.sack[item] <= 0 {
		return
	}
	if p.stamina < cost {
		answer("Too tired to throw!")
		return
	}
	for &t in g.thrown {
		if t.active {
			continue
		}
		sack_take(item, 1)
		sack_step(0)
		p.stamina -= cost
		p.regen_delay = 0.3
		speed := stone_speed(kg) * p.throw_power
		dir := facing_dir(p.facing)
		height := p.height + 1.1 * PROSIO_SIZE
		rise := speed * 0.08
		if d, r, ok := aimed_throw(p.pos, height, speed); ok {
			dir, rise = d, r
		}
		t = Thrown_Rock{active = true, round = -1, spear = spear, r = spear ? SPEAR_RADIUS : PEBBLE_RADIUS, kg = kg, pos = p.pos + dir * 0.45, vel = dir * speed, y = height, vy = rise}
		train(.Arms, SWING_WORK * (spear ? 0.3 : 0.1))
		p.stretch_vel -= 2
		say(spear ? "Hyah!" : "Fwip!", 0.4)
		return
	}
	answer("Wait... too many in the air!")
}
ANIMAL_THROW_GAIN :: f32(3.2) // for animals, which he can wind up
MAX_THROW :: f32(22)
MAX_THROWN :: 4
GRAB_REACH :: f32(0.85) // how far beyond touching he can reach: about an arm
LIFT_TIME :: f32(0.35) // seconds to lift something of his own weight
CARRY_DRAIN :: f32(5) // stamina per second for holding his own weight
LIFT_LIMIT :: f32(0.9) // he can swing or throw up to this share of his own weight
ROCK_LIMIT :: f32(2) // he can lift a rock of up to twice his own weight
// A rock of radius 0.3 weighs about 10 kg, 0.6 about 82 kg, and the big
// boulders (0.9) about 280 kg: liftable only by a heavy, rested Prosio.
ROCK_DENSITY :: f32(380)
DIG :: f32(1.5) // an animal on its feet digs in: it resists like this many times its weight
DRAG_SLIDE :: f32(0.6) // a limp animal slides along the grass: it resists like this share of its weight
PROSIO_GRIP :: f32(1.5) // and Prosio digs his heels in too
LUNGE_SPEED :: f32(3) // how much faster a dragged animal pulls when it lunges
SKIP_KEEP :: f32(0.82) // share of forward speed kept at each skip
SKIP_BOUNCE :: f32(0.55) // share of falling speed that bounces back up
SKIP_SPIN :: f32(0.18) // share of falling speed the spin turns into forward speed
ARM_LEN :: f32(0.55) * PROSIO_SIZE // from his shoulder to his hoof, arm outstretched
HOLD_SIDE :: f32(1) // which hand holds an animal by the leg: +1 is the side his model's +x points to
FOLLOW_THROUGH :: f32(0.12) // seconds his arm stays down after a swing lands
// What a slam takes from a held animal's health: so much, plus so much for
// each m/s it hit at, and never more than SLAM_MOST. (His arm sets the speed,
// whatever he holds, so this does not go by how sturdy the animal is.)
SLAM_BLOW :: Vec2{4, 1.2}
SLAM_MOST :: f32(30)
LIMP_MOST :: f32(8) // seconds an animal bashed about hangs limp, at most

Carry :: enum {
	Nothing,
	Enemy,
	Rock,
}

// A rock in flight.
Thrown_Rock :: struct {
	active: bool,
	round:  int, // which rock of the world this is (-1: a pebble or a spear out of the sack)
	spear:  bool, // a spear: it goes in where a stone would bounce off, and lies where it lands
	r, kg:  f32,
	pos:    Vec2,
	vel:    Vec2,
	y, vy:  f32,
	spin:   f32,
}

// The points of a held animal's body, in its own model (units of its
// radius): the feet or hoof in his hand, the middle of its body and its
// shoulders. The back half of the model hangs between the first two, the
// front half between the last two.
CHAIN_MODEL := [Enemy_Kind][3]Vec3 {
	.Turkey = {{0, 0.02, -0.08}, {0, 1.2, -0.08}, {0, 1.6, 0.5}},
	.Goat   = {{0, 0.05, -0.78}, {0, 1.05, -0.12}, {0, 1.2, 0.58}},
	.Billy  = {{0, 0.05, -0.78}, {0, 1.05, -0.12}, {0, 1.2, 0.58}},
	.Fox    = {{0, 1.3, -1.7}, {0, 0.97, -0.1}, {0, 1.1, 0.5}}, // a fox is held by the tip of its tail
}
// Where the held leg (or the fox's tail) leaves the body, in the same units.
GRIP_ROOT := [Enemy_Kind]Vec3 {
	.Turkey = {0, 0.85, -0.08},
	.Goat   = {0.3, 0.88, -0.55},
	.Billy  = {0.3, 0.88, -0.55},
	.Fox    = {0, 1.04, -0.75},
}

// A turkey is lifted off its feet by them and dangles head down; anything
// bigger is dragged by a hind leg and can still stand on the other three.
held_up :: proc(kind: Enemy_Kind) -> bool {
	return kind == .Turkey
}

// Goats he holds by both hind legs, a hoof on each.
two_handed :: proc(kind: Enemy_Kind) -> bool {
	return kind == .Goat || kind == .Billy
}

rock_kg :: proc(r: f32) -> f32 {
	return ROCK_DENSITY * r * r * r
}

// Prosio's weight together with his sack and a rock he is carrying. A
// dragged animal stands on its own feet, so it does not count.
total_kg :: proc() -> f32 {
	p := &g.prosio
	return p.kg + sack_kg() + (p.carry == .Rock ? p.carry_kg : 0)
}

// How much what he carries weighs on him, against what he weighs: a rock in
// his arms all of its weight, the sack on his back, well packed, only
// LOAD_EASE of it; so 0.12 for a 16 kg sack on an 80 kg pig. It makes
// walking and sprinting cost that much more and slows him as much, and
// trains his legs (and, sprinting, his lungs) LOAD_TRAIN times that much
// faster.
load_share :: proc() -> f32 {
	p := &g.prosio
	return (total_kg() - p.kg - sack_kg() * (1 - LOAD_EASE)) / p.kg
}

// What he and his load come to, as his legs feel it.
felt_kg :: proc() -> f32 {
	return g.prosio.kg * (1 + load_share())
}

load_training :: proc() -> f32 {
	return 1 + LOAD_TRAIN * load_share()
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
		if !on_ground(&e) && e.state != .Dead {
			continue
		}
		gap := length2(e.pos - p.pos) - pr - ENEMY_RADIUS[e.kind]
		if gap < GRAB_REACH * deft_reach() && gap < best {
			best = gap
			target = {.Enemy, i, ENEMY_KG[e.kind]}
			found = true
		}
	}
	if found {
		return // an animal within reach comes before any rock
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

// Where the carried rock is: it starts in front of him and ends overhead.
carry_place :: proc() -> (pos: Vec2, height: f32) {
	p := &g.prosio
	lifted := smooth(1 - p.lift_t / max(p.lift_total, 0.001))
	reach := (prosio_radius(p.kg) + carry_radius()) * (1 - lifted)
	pos = p.pos + facing_dir(p.facing) * reach
	height = p.height + lerp(0.05, 1.95 * PROSIO_SIZE, lifted)
	return
}

update_grab :: proc(dt: f32, can_act: bool) {
	p := &g.prosio

	if p.carry == .Nothing {
		if p.wind_stone {
			// Winding up a pebble or a spear out of the sack. A tap is a
			// quick flick.
			switch wind_up(dt) {
			case .Put_Down:
				p.throw_power = WIND_LEAST
				throw_stone()
			case .Throw:
				throw_stone()
			case .Nothing:
			}
			p.wind_stone = p.winding
			return
		}
		if p.airborne || !can_act || !pressed(.Grab) {
			return
		}
		target, found := grab_target()
		if !found {
			// At the pond there may be a fish; with a pebble or a spear
			// chosen in the sack, he winds up to throw it; and failing all
			// that, he takes down what he has built, if he is standing at it.
			if pond_in_reach(p.pos, prosio_radius(p.kg)) {
				grab_fish()
			} else if throwable_chosen() {
				p.wind_stone = true
				p.wind_item = p.sack_sel
				p.winding = true
				p.wind_t = 0
				p.aim = aim_towards(facing_dir(p.facing), 0.3, {})
			} else if !take_down() {
				answer("Nothing to grab here.")
			}
			return
		}
		ratio := target.kg / p.kg
		if target.kind == .Rock && ratio > ROCK_LIMIT * strength() {
			answer("Way too heavy to lift!")
			return
		}
		cost := 6 + 25 * min(ratio, 1)
		if p.stamina < cost {
			answer("Too tired to grab that!")
			return
		}
		p.stamina -= cost
		p.regen_delay = 0.5
		burn(FIGHT_BURN, .Fighting, true)
		p.carry = target.kind
		p.carry_index = target.index
		g.grabs += 1
		p.carry_kg = target.kg
		p.held_t = 0
		p.swinging = false
		p.bash_queued = false
		p.winding = false
		p.grab_spent = true
		p.lunge_t = 0

		towards: Vec2
		switch target.kind {
		case .Enemy:
			p.lift_total = 0.12 // catching a leg is quick; it is the dragging that is hard
			e := &g.enemies[target.index]
			towards = e.pos - p.pos
			start_hold(e)
			switch {
			case held_up(e.kind):
				say("Got you by the legs!", 1)
			case e.kind == .Fox:
				say("Got you by the tail!", 1)
			case ratio > LIFT_LIMIT * strength():
				say("Got your hind legs! Uh-oh...", 1)
			case:
				say("Got your hind legs!", 1)
			}
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
	p.regen_delay = 0.5
	if !button_down(.Grab) {
		p.grab_spent = false // the press that took hold is over: the next one lets go
	}

	switch p.carry {
	case .Enemy:
		e := &g.enemies[p.carry_index]
		struggling := e.limp <= 0 && !e.ko
		p.stamina -= CARRY_DRAIN * ratio * (struggling ? 1 : 0.25) * dt
		train(.Arms, CARRY_WORK * min(ratio, 1.5) * dt)
		if p.stamina <= 0 {
			p.stamina = 0
			drop_carry()
			say("Too heavy! I can't hold on!", 1.4)
			return
		}
		// A struggling animal pulls free in the end: a heavy one sooner.
		if struggling {
			p.held_t += dt
			if p.held_t > 9 / (ratio + 0.4) {
				heavy := ratio > 1
				drop_carry()
				p.safe_t = max(p.safe_t, 0.8)
				if heavy {
					p.dazed_t = 0.5 // it yanks him off his feet
					say("Whoa! It got away!", 1.2)
				} else {
					say("It wriggled free!", 1.2)
				}
				return
			}
		}
		if p.lift_t > 0 {
			return
		}
		too_heavy := ratio > LIFT_LIMIT * strength()
		// F always lets go: tapped, he puts it down; held, he winds up and
		// throws it when the button is let go (if he can: otherwise down it
		// goes all the same). While a throw is under way F changes nothing.
		let_go := Let_Go.Nothing
		if !(p.swinging && p.swing_throw) {
			let_go = wind_up(dt)
		}
		switch let_go {
		case .Put_Down:
			if hoist_over() {
				return
			}
			drop_carry()
			say("Down you go.", 0.9)
			return
		case .Throw:
			switch {
			case too_heavy:
				drop_carry()
				say("Way too heavy to throw!", 1.2)
				return
			case p.stamina < throw_cost():
				drop_carry()
				say("Too tired to throw it... down it goes.", 1.4)
				return
			case:
				begin_swing(true)
			}
		case .Nothing:
		}
		if let_go == .Nothing && !p.winding && pressed(.Bump) {
			switch {
			case too_heavy:
				heave(dt)
			case !p.swinging:
				begin_swing(false)
			case !p.swing_throw:
				p.bash_queued = true
			}
		}

	case .Rock:
		p.stamina -= CARRY_DRAIN * ratio * dt
		train(.Arms, CARRY_WORK * min(ratio, 1.5) * dt)
		if p.stamina <= 0 {
			p.stamina = 0
			drop_carry()
			say("Too heavy! I can't hold on!", 1.4)
			return
		}
		if p.lift_t > 0 {
			return
		}
		switch wind_up(dt) {
		case .Put_Down:
			drop_carry()
		case .Throw:
			throw_rock()
		case .Nothing:
		}

	case .Nothing:
	}
}

// What F does with something in his hands. A tap (let go within WIND_TAP
// seconds) puts it down. Held longer, he winds up: the throw has WIND_LEAST
// of its full speed at first and all of it after WIND_FULL seconds.
WIND_TAP :: f32(0.2)
WIND_FULL :: f32(1.0)
WIND_LEAST :: f32(0.35)

Let_Go :: enum {
	Nothing,
	Put_Down,
	Throw,
}

// Something to throw is chosen in the sack: a pebble or a spear.
throwable_chosen :: proc() -> bool {
	p := &g.prosio
	return (p.sack_sel == .Pebble || p.sack_sel == .Spear) && p.sack[p.sack_sel] > 0
}

// Follows the F button while he holds something, and says what he does
// with it when the button comes up. A throw's strength is left in
// p.throw_power.
wind_up :: proc(dt: f32) -> Let_Go {
	p := &g.prosio
	if !p.winding {
		// F down again after the press that took hold (even if it went down
		// while he was still lifting): the wind-up starts.
		if button_down(.Grab) && !p.grab_spent {
			p.winding = true
			p.wind_t = 0
			p.aim = aim_towards(facing_dir(p.facing), 0.3, {})
		}
		return .Nothing
	}
	update_aim()
	if button_down(.Grab) {
		p.wind_t += dt
		return .Nothing
	}
	p.winding = false
	if p.wind_t < WIND_TAP {
		return .Put_Down
	}
	p.throw_power = wind_power()
	return .Throw
}

// How much of a full throw he has wound up so far.
wind_power :: proc() -> f32 {
	return clamp(g.prosio.wind_t / WIND_FULL, WIND_LEAST, 1)
}

// The chain of a freshly grabbed animal: its points as it stands now.
start_hold :: proc(e: ^Enemy) {
	drop_loot(e)
	r := ENEMY_RADIUS[e.kind]
	m := translate({e.pos.x, e.y, e.pos.y}) * rot_y(e.facing) * scale({r, r, r})
	for k in 0 ..< 3 {
		point := m * [4]f32{CHAIN_MODEL[e.kind][k].x, CHAIN_MODEL[e.kind][k].y, CHAIN_MODEL[e.kind][k].z, 1}
		e.chain[k] = point.xyz
		e.chain_old[k] = point.xyz
	}
	e.side = {math.cos(e.facing), 0, -math.sin(e.facing)}
	e.state = .Held
	e.impact = {}
	e.vel = {}
	e.vy = 0
	e.limp = 0
	e.skip = false
}

// From his own frame (x to his side, y up from his feet, z ahead) to the world.
prosio_to_world :: proc(local: Vec3) -> Vec3 {
	p := &g.prosio
	right := Vec2{math.cos(p.facing), -math.sin(p.facing)}
	xz := p.pos + (right * local.x + facing_dir(p.facing) * local.z) * PROSIO_SIZE
	return {xz.x, p.height + local.y * PROSIO_SIZE, xz.y}
}

// A direction in the world, turned into his own frame.
direction_to_prosio :: proc(v: Vec3) -> Vec3 {
	p := &g.prosio
	right := Vec2{math.cos(p.facing), -math.sin(p.facing)}
	return {dot2(v.xz, right), v.y, dot2(v.xz, facing_dir(p.facing))}
}

// The shoulder of the arm that holds an animal by the leg, in his own frame.
holding_shoulder :: proc() -> Vec3 {
	p := &g.prosio
	return {HOLD_SIDE * prosio_chest(p.kg) * 0.86, SHOULDER_HEIGHT, 0.035}
}

// SPACE (bash = false) or F (bash = true... a throw): a swing of the held
// animal. His hand sweeps from where it is, round through a waypoint, to
// where the swing ends; the animal follows on the end of its leg.
// The stamina a throw, or a bash, of what he holds would cost.
throw_cost :: proc() -> f32 {
	return 4 + 12 * g.prosio.carry_kg / g.prosio.kg
}

bash_cost :: proc() -> f32 {
	return 3 + 10 * g.prosio.carry_kg / g.prosio.kg
}

begin_swing :: proc(throw: bool) {
	p := &g.prosio
	e := &g.enemies[p.carry_index]
	ratio := p.carry_kg / p.kg
	cost := throw ? throw_cost() : bash_cost()
	if p.stamina < cost {
		answer("Too tired to swing it!")
		return
	}
	p.stamina -= cost
	burn(FIGHT_BURN, .Fighting, true)
	train(.Arms, SWING_WORK * min(ratio, 1.5))

	from := direction_to_prosio(p.hand - prosio_to_world(holding_shoulder()))
	p.swing_from = linalg.normalize0(from)
	if p.swing_from == {} {
		p.swing_from = {0, -1, 0}
	}
	p.swinging = true
	p.swing_throw = throw
	p.swing_t = 0
	p.bash_queued = false
	// A heavier animal is slower to get round, so it hits less hard; a
	// heavier Prosio is quicker with it.
	p.swing_total = clamp(0.3 + 0.45 * ratio, 0.3, 0.75) * stiffness()
	if throw {
		// Back, over his head, and up and away in front.
		p.swing_total *= 0.8
		p.swing_via = {0, 1, -0.3}
		p.swing_to = linalg.normalize(Vec3{0, 0.35, 1})
		say("Aaand...", 0.5)
		return
	}
	// A bash is one swing of a pendulum across his front: from the side his
	// hoof is on now, round past his front, out to the other side, so
	// pressing again swings it back. Each swing is a little different: how
	// far out it goes, how high, and how deep it dips in the middle (a deep
	// dip slams it into the ground in front of him).
	to_side: f32 = p.swing_from.x > 0.1 ? -1 : (p.swing_from.x < -0.1 ? 1 : (random() < 0.5 ? -1 : 1))
	yaw := to_side * random_range(1.0, 1.75)
	pitch := random_range(-0.45, 0.05)
	p.swing_to = {math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch)}
	p.swing_via = {random_range(-0.25, 0.25), -random_range(0, 0.9), 1}
	e.limp = max(e.limp, 0.3) // swung off its feet
	// Shaken about, a turkey sometimes lets go of an egg.
	if e.kind == .Turkey && random() < SHAKE_EGG && drop_egg(e.chain[1].xz, e.chain[1].y) {
		burst(e.chain[1], 4, 2, TURKEY_TIP, 0.07)
		say("An egg fell out!", 1.2)
	}
}

// Where his hand points during a swing (k from 0 to 1), in his own frame.
swing_direction :: proc(k: f32) -> Vec3 {
	p := &g.prosio
	a, b := (1 - k) * (1 - k), 2 * k * (1 - k)
	d := p.swing_from * a + p.swing_via * 1.6 * b + p.swing_to * k * k
	return linalg.normalize0(d)
}

// SPACE with an animal too heavy to swing: he heaves with all he has, lifts
// it a little, and it answers with a lunge.
heave :: proc(dt: f32) {
	p := &g.prosio
	e := &g.enemies[p.carry_index]
	if p.stamina < 10 {
		answer("Too tired!")
		return
	}
	p.stamina -= 10
	train(.Arms, SWING_WORK * 1.5)
	p.heave_t = 0.6
	lift := 6 * min(p.kg / p.carry_kg, 1)
	e.chain_old[1].y -= lift * dt
	p.lunge_t = 0.35
	burst({p.pos.x, p.height + 1.6 * PROSIO_SIZE, p.pos.y}, 4, 2.5, COLOR_SWEAT, 0.06)
	say("Hnnnngh! Way too heavy!", 1)
}

// Keeps a held animal moving: its body swings, falls and drags on its own,
// hanging from his hand by a leg. Called after Prosio has moved this step.
update_drag :: proc(dt: f32) {
	p := &g.prosio
	p.heave_t -= dt
	if p.carry != .Enemy {
		p.strain = max(p.strain - dt * 3, 0)
		return
	}
	e := &g.enemies[p.carry_index]
	r := ENEMY_RADIUS[e.kind]
	kg := ENEMY_KG[e.kind]
	ratio := kg / p.kg
	leg_len, body_len := chain_lengths(e.kind)
	e.limp -= dt
	alive := e.limp <= 0 && !e.ko

	// The swing runs its course.
	if p.swinging {
		p.swing_t += dt
		if p.swing_t >= p.swing_total {
			if p.swing_throw {
				throw_animal()
				return
			}
			if p.swing_t >= p.swing_total + FOLLOW_THROUGH {
				p.swinging = false
				if p.bash_queued {
					begin_swing(false)
				}
			}
		}
	}

	// Where his hand is: sweeping round in a swing, otherwise held out
	// towards the animal at the end of his arm.
	shoulder := prosio_to_world(holding_shoulder())
	hand: Vec3
	swing_aim: Vec3 // during a swing: where his arm and the held leg point, in the world
	if p.swinging {
		k := min(p.swing_t / p.swing_total, 1)
		if p.swing_throw {
			k = math.pow(k, 1.6) // it speeds up all the way, like the crack of a whip
		} else {
			k = 0.5 - 0.5 * math.cos(k * math.PI) // a pendulum: fastest across his front
		}
		dir := swing_direction(k)
		right := Vec2{math.cos(p.facing), -math.sin(p.facing)}
		world := right * dir.x + facing_dir(p.facing) * dir.z
		swing_aim = Vec3{world.x, dir.y, world.y}
		hand = shoulder + swing_aim * ARM_LEN
	} else if held_up(e.kind) {
		// A turkey he holds up and out to his side, at arm's length.
		right := Vec2{math.cos(p.facing), -math.sin(p.facing)}
		out := right * HOLD_SIDE * 0.75 + facing_dir(p.facing) * 0.45
		hand = shoulder + linalg.normalize(Vec3{out.x, 0.15, out.y}) * ARM_LEN
	} else {
		to := e.chain[1] - shoulder
		hand = shoulder + linalg.normalize0(to) * ARM_LEN
	}
	hand.y = max(hand.y, p.height + 0.2 * PROSIO_SIZE)

	// Its body falls and flies freely between steps. Held up by the feet, a
	// turkey cannot stand: it flaps, and every beat of its wings jerks it
	// about.
	standing := alive && !p.swinging && !held_up(e.kind)
	for k in 1 ..= 2 {
		step := (e.chain[k] - e.chain_old[k]) * 0.995
		e.chain_old[k] = e.chain[k]
		e.chain[k] += step + Vec3{0, -GRAVITY * dt * dt, 0}
	}
	// In a swing he whips its back end round on the end of his arm, as if
	// the leg were a handle; it lags behind his hand a little, and the front
	// half just flops along after it.
	if p.swinging {
		ideal := hand + swing_aim * leg_len
		e.chain[1] += (ideal - e.chain[1]) * 0.3
	}

	// It keeps trying to run away, now and then with a sudden lunge.
	p.lunge_t -= dt
	if alive && p.lunge_t < -random_range(0.5, 1.1) {
		p.lunge_t = 0.25
		if held_up(e.kind) && !p.swinging {
			flap := Vec3{random_range(-1, 1), random_range(0.5, 1.5), random_range(-1, 1)} * 2.2
			e.chain_old[1] -= flap * dt
			e.chain_old[2] -= flap * dt * 1.4
			burst({e.chain[1].x, e.chain[1].y, e.chain[1].z}, 2, 1.5, TURKEY_TIP, 0.07)
		}
	}
	away := normalize2(e.chain[2].xz - p.pos)
	wander := 0.6 * math.sin(g.time * 1.3 + f32(p.carry_index))
	run := Vec2{away.x * math.cos(wander) - away.y * math.sin(wander), away.x * math.sin(wander) + away.y * math.cos(wander)}
	run *= ENEMY_SPEED[e.kind] * (p.lunge_t > 0 ? LUNGE_SPEED : 1)

	floors: [3]f32
	for k in 1 ..= 2 {
		floors[k] = r * (standing ? CHAIN_MODEL[e.kind][k].y : (k == 1 ? 0.5 : 0.45))
	}
	on_floor := e.chain[1].y <= floors[1] + 0.03 || e.chain[2].y <= floors[2] + 0.03

	moved_him: f32
	for _ in 0 ..< 4 {
		// The held leg is a rope from his hand to its middle. When it is taut
		// they pull against each other, each giving way by the other's share.
		d := e.chain[1] - hand
		dist := linalg.length(d)
		if dist > leg_len {
			if !p.swinging {
				his_weight := 1 / (p.kg * PROSIO_GRIP)
				its_weight := 1 / (kg * (!on_floor ? 1 : (standing ? DIG : DRAG_SLIDE)))
				share := his_weight / (his_weight + its_weight)
				shift := d.xz / dist * (dist - leg_len) * share
				p.pos += shift
				hand += {shift.x, 0, shift.y}
				shoulder += {shift.x, 0, shift.y}
				moved_him += length2(shift)
				d = e.chain[1] - hand
				dist = linalg.length(d)
			}
			e.chain[1] = hand + d / dist * leg_len
		} else if dist < leg_len * 0.5 && !p.swinging {
			// Too close: it is pushed out sideways, never lifted.
			flat := normalize2(d.xz)
			if flat == {} {
				flat = normalize2(e.chain[1].xz - p.pos)
			}
			need := math.sqrt(max(leg_len * leg_len * 0.25 - d.y * d.y, 0))
			if length2(d.xz) < need {
				e.chain[1].x = hand.x + flat.x * need
				e.chain[1].z = hand.z + flat.y * need
			}
		}
		// Its body keeps its length; the middle is heavier than the front.
		d = e.chain[2] - e.chain[1]
		dist = linalg.length(d)
		if dist > 1e-4 {
			fix := d * (dist - body_len) / dist
			e.chain[1] += fix * 0.4
			e.chain[2] -= fix * 0.6
		}
		for k in 1 ..= 2 {
			e.chain[k].y = max(e.chain[k].y, floors[k])
		}
	}
	if moved_him > 0 {
		collide_static(&p.pos, prosio_radius(p.kg), p.height, false, clears_fences())
	}

	// On the ground: it scrabbles along on its feet, or slides limply. A fast
	// fall onto the ground is a slam.
	hit_something := false
	for k in 1 ..= 2 {
		point := &e.chain[k]
		old := &e.chain_old[k]
		vel := (point^ - old^) / dt
		if point.y <= floors[k] + 0.02 {
			bounce: f32 = 0
			if vel.y < -5 && p.swinging {
				slam(e, point^ + {0, -r * 0.4, 0}, -vel.y)
				hit_something = true
				bounce = -vel.y * 0.25
			}
			flat := approach2(vel.xz, standing ? run : {}, (standing ? 40 : 14) * dt)
			old^ = point^ - Vec3{flat.x, bounce, flat.y} * dt
		}
		// It cannot go through trees and walls, through Prosio, or through a
		// fence: over one he lifts it, with F (see hoist_over).
		xz := point.xz
		if hit, _ := collide_static(&xz, r * 0.55, point.y - r * 0.5, true); hit {
			speed := linalg.length(vel)
			if p.swinging && speed > 5 && !hit_something {
				shake_trees_near(xz, r * 0.55 + 0.4, speed)
				slam(e, point^, speed)
				hit_something = true
				g.shake = max(g.shake, 0.3)
				say("BONK!", 0.6)
			}
		}
		if point.y < p.height + 1.6 * PROSIO_SIZE {
			push_out_circle(&xz, r * 0.45, p.pos, prosio_radius(p.kg))
		}
		// Being pushed out moves it, but must not fling it: the push is not
		// speed. Nor can anything else make it faster than a thrown animal.
		push := xz - point.xz
		point.x, point.z = xz.x, xz.y
		old.x += push.x
		old.z += push.y
		step := point^ - old^
		if fast := linalg.length(step); fast > MAX_THROW * dt {
			old^ = point^ - step * (MAX_THROW * dt / fast)
		}
	}
	e.chain[0] = hand
	p.hand = hand

	// Swung, it hits like a club.
	if p.swinging {
		bash_hits(e, dt)
	}

	// Its pose: where it is, which way it points, which way is up for it, and
	// how its legs dangle. (A turkey hanging by its feet keeps its legs
	// together in his hand.)
	e.pos = e.chain[1].xz
	e.y = max(e.chain[1].y - r * CHAIN_MODEL[e.kind][1].y, 0)
	along := e.chain[2] - e.chain[1]
	e.facing = math.atan2(along.x, along.z)
	axis := linalg.normalize0(along)
	carried := e.side - axis * linalg.dot(e.side, axis)
	upright := linalg.cross(Vec3{0, 1, 0}, axis)
	side := linalg.normalize0(carried)
	if linalg.length(upright) > 0.2 {
		// On its feet it stays upright; limp, it rolls only slowly back.
		side = linalg.normalize0(side + (linalg.normalize(upright) - side) * (standing ? 0.3 : 0.03))
	}
	if side != {} {
		e.side = side
	}
	for half in 0 ..< 2 {
		vel := (e.chain[half + 1] - e.chain_old[half + 1]) / dt
		e.dangle[half] = linalg.normalize0(Vec3{0, -1, 0} - vel * 0.09)
	}
	e.hop += dt * (alive ? (on_floor ? 16 : 30) : 0)

	// How hard he strains: he leans back and digs in against a heavy animal.
	want: f32 = alive ? clamp((ratio - 0.4) * 0.9, 0, 1) : 0
	if p.heave_t > 0 {
		want = 1
	}
	p.strain += (want - p.strain) * (1 - math.exp(-6 * dt))
	if p.strain > 0.4 && !p.swinging {
		to := e.pos - p.pos
		p.facing = approach_angle(p.facing, math.atan2(to.x, to.y), 6 * dt)
	}

	// Paws scrape and his heels plough the grass.
	e.timer -= dt
	if e.timer <= 0 && (moved_him > 0.01 * dt || (standing && p.lunge_t > 0)) {
		e.timer = 0.09
		for k in 1 ..= 2 {
			burst({e.chain[k].x, 0.08, e.chain[k].z}, 1, 1.4, COLOR_DUST, 0.07)
		}
		if p.strain > 0.4 {
			burst({p.pos.x, p.height + 0.08, p.pos.y}, 2, 1.6, COLOR_DUST, 0.09)
		}
	}
}

// How long its held leg is (from his hand to its middle) and its body.
chain_lengths :: proc(kind: Enemy_Kind) -> (leg, body: f32) {
	r := ENEMY_RADIUS[kind]
	c := CHAIN_MODEL[kind]
	return r * linalg.length(c[1] - c[0]), r * linalg.length(c[2] - c[1])
}

// The held animal is slammed into the ground or into something solid at
// this speed: a blow like any other (see ENEMY_HEALTH in enemies.odin).
slam :: proc(e: ^Enemy, at: Vec3, speed: f32) {
	if e.hit_t > 0 {
		return // one bounce of the same whack does not count again
	}
	e.hit_t = 0.2
	kg := ENEMY_KG[e.kind]
	g.shake = max(g.shake, min(speed * kg / 1200, 0.4))
	burst({at.x, at.y + 0.1, at.z}, 3 + int(speed * 0.4), 1.5 + speed * 0.15, COLOR_DUST, 0.11)
	pain_stars({at.x, at.y + ENEMY_RADIUS[e.kind], at.z}, speed)
	e.limp = min(max(e.limp, 0) + 0.8 + speed * 0.12, LIMP_MOST)
	hurt_enemy(e, min(SLAM_BLOW.x + SLAM_BLOW.y * speed, SLAM_MOST))
	if speed > 6 {
		WORDS := [?]cstring{"WHACK!", "THUD!", "SPLAT!", "BONK!", "WHUMP!"}
		say(WORDS[int(random() * len(WORDS)) % len(WORDS)], 0.5)
	}
}

// Whatever the swung animal hits takes a share of its speed set by their
// weights, as when two balls collide. But the club is floppy: only part of
// its body (CLUB_SHARE of its weight) is behind the blow, and it squashes
// rather than bounces (restitution BASH_BOUNCE). For a club of weight m
// moving at v, striking something of weight M:
//
//     it flies off at   (1 + e) * m' / (m' + M) * v,   with m' = CLUB_SHARE * m
//     the club goes on  (m' - e * M) / (m' + M) * v
//
// So a turkey swung into a turkey knocks it about half as fast as it was
// swung, and swung into the billy goat it barely rocks it and bounces back.
CLUB_SHARE :: f32(0.6)
BASH_BOUNCE :: f32(0.35)
bash_hits :: proc(e: ^Enemy, dt: f32) {
	p := &g.prosio
	r := ENEMY_RADIUS[e.kind]
	club := ENEMY_KG[e.kind]
	for k in 1 ..= 2 {
		point := e.chain[k]
		vel := (point - e.chain_old[k]) / dt
		speed := linalg.length(vel)
		if speed < 3 {
			continue
		}
		for &o, i in g.enemies[:g.enemy_count] {
			if i == p.carry_index || o.hit_t > 0 || !on_ground(&o) {
				continue
			}
			ro := ENEMY_RADIUS[o.kind]
			if length2(o.pos - point.xz) >= r * 0.6 + ro || point.y > ro * 2.2 {
				continue
			}
			other := ENEMY_KG[o.kind]
			blow := club * CLUB_SHARE
			passed := (1 + BASH_BOUNCE) * blow / (blow + other) * speed
			dir := normalize2(normalize2(vel.xz) * 0.7 + normalize2(o.pos - point.xz) * 0.5)
			if dir == {} {
				dir = facing_dir(p.facing)
			}
			o.hit_t = 0.4
			offend(&o)
			if enemy_impact(&o, dir, passed) == .Launch {
				o.vy = min(passed * 0.3, IMPACT_MAX_RISE) // sideways more than up
				o.skip = true
			}
			// The club goes on with what it kept (or bounces back), and gets
			// hurt too.
			e.chain_old[k] = point - vel * dt * (blow - BASH_BOUNCE * other) / (blow + other)
			slam(e, point, speed * 0.6)
			pain_stars({o.pos.x, ro * 1.8, o.pos.y}, passed)
			g.shake = max(g.shake, min(passed * other / 500, 0.6))
			say(passed > 8 ? "BASH!" : "Bonk!", 0.6)
		}
		for &rd, i in g.rounds[:g.round_count] {
			if rd.kind != .Rock || rd.r <= 0 || length2(rd.pos - point.xz) >= r * 0.6 + rd.r || point.y > rd.r * 2 {
				continue
			}
			rock := rock_kg(rd.r)
			if rock > club * 2.5 {
				continue // a boulder: the club just bonks off it (collide_static)
			}
			blow := club * CLUB_SHARE
			passed := (1 + BASH_BOUNCE) * blow / (blow + rock) * speed
			for &t in g.thrown {
				if !t.active {
					t = Thrown_Rock{active = true, round = i, r = rd.r, kg = rock, pos = rd.pos, vel = normalize2(vel.xz) * passed, y = 0.05, vy = passed * 0.3}
					rd.r = 0
					break
				}
			}
			burst({rd.pos.x, 0.5, rd.pos.y}, 8, 3, COLOR_DUST, 0.12)
		}
	}
}

// The end of a throw: the animal flies off the way he is walking, and he
// recoils with the same push (divided by his weight).
throw_animal :: proc() {
	p := &g.prosio
	e := &g.enemies[p.carry_index]
	r := ENEMY_RADIUS[e.kind]
	kg := ENEMY_KG[e.kind]
	dir := facing_dir(p.facing)
	speed := min(ANIMAL_THROW_GAIN * strength() * p.kg / kg, MAX_THROW) * p.throw_power
	rise := random_range(0.15, 0.4)
	e.pos = p.pos + dir * (prosio_radius(p.kg) + r * 0.9)
	collide_static(&e.pos, r, 0.5, true)
	e.facing = math.atan2(dir.x, dir.y)
	launch_enemy(e, dir, speed)
	e.vel = dir * speed * math.cos(rise)
	e.vy = speed * math.sin(rise)
	e.y = 0.6
	e.skip = true
	e.limp = 0

	p.vel -= dir * min(speed * kg / p.kg, 6)
	p.carry = .Nothing
	p.winding = false
	p.lift_t = 0 // whatever happens, he is not lifting any more
	p.carry_kg = 0
	p.swinging = false
	p.stretch_vel -= 3
	burn(FIGHT_BURN, .Fighting, true)
	g.shake = max(g.shake, min(speed * kg / 600, 0.6))
	say(speed > 11 ? "HAI-YA!" : "Hup!", 0.9)
	burst({p.pos.x, p.height + 0.1, p.pos.y}, 5, 2, COLOR_DUST, 0.1)
}

// A little spray of pain stars: a few, small, each its own size and way.
pain_stars :: proc(pos: Vec3, strength: f32) {
	count := 2 + int(random() * 3) + int(min(strength, 12) / 5)
	for _ in 0 ..< count {
		a := random_range(0, math.TAU)
		s := random_range(0.8, 2.6)
		vel := Vec3{math.cos(a) * s, random_range(1.5, 4), math.sin(a) * s}
		spawn_particle(pos + {random_range(-0.15, 0.15), random_range(0, 0.2), random_range(-0.15, 0.15)}, vel, random_range(0.3, 0.7), random_range(0.035, 0.07), random() < 0.25 ? COLOR_WHITE : COLOR_STAR)
	}
}

// Letting go of a rock overhead: it is hurled down in front of him.
throw_rock :: proc() {
	p := &g.prosio
	dir := facing_dir(p.facing)
	speed := stone_speed(p.carry_kg) * p.throw_power
	train(.Arms, SWING_WORK * min(p.carry_kg / p.kg, 1.5))
	_, height := carry_place()
	rise := -speed * 0.3 // thrown down, not up
	if d, r, ok := aimed_throw(p.pos, height, speed); ok {
		dir, rise = d, r
	}
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
			vy     = rise,
		}
		break
	}
	// Every push pushes back.
	p.vel -= dir * min(speed * p.carry_kg / p.kg, 4)
	p.carry = .Nothing
	p.winding = false
	p.lift_t = 0 // whatever happens, he is not lifting any more
	p.carry_kg = 0
	p.stretch_vel -= 3
	burn(FIGHT_BURN, .Fighting, true)
	say(speed > 9 ? "HAI-YA!" : "Oof!", 0.9)
	burst({p.pos.x, p.height + 0.1, p.pos.y}, 6, 2.5, COLOR_DUST, 0.12)
}

// Lets go of whatever he holds; it ends up on the ground.
drop_carry :: proc() {
	p := &g.prosio
	dir := facing_dir(p.facing)
	pr := prosio_radius(p.kg)
	switch p.carry {
	case .Enemy:
		// Let go of the leg: it lies where it is, dazed for as long as it
		// was limp. A knocked-out one stays down.
		e := &g.enemies[p.carry_index]
		e.pos = e.chain[1].xz
		e.y = 0
		e.vy = 0
		e.vel = {}
		e.state = .Dizzy
		e.timer = max(0.8, e.limp)
		e.limp = 0
		collide_static(&e.pos, ENEMY_RADIUS[e.kind], 0, true)
		push_out_circle(&e.pos, ENEMY_RADIUS[e.kind], p.pos, pr)
	case .Rock:
		rd := &g.rounds[p.carry_index]
		rd.pos = p.pos + dir * (pr + p.carry_r + 0.05)
		collide_static(&rd.pos, p.carry_r, 0, true)
		rd.r = p.carry_r
	case .Nothing:
	}
	p.carry = .Nothing
	p.winding = false
	p.lift_t = 0 // whatever happens, he is not lifting any more
	p.carry_kg = 0
	p.swinging = false
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

		if hit, n := collide_static(&t.pos, t.r, t.y, true, true); hit { // between the rails of a fence it goes
			into := dot2(t.vel, n)
			if into < 0 {
				t.vel -= n * into * 1.4 // a dull bounce
				if into < -4 {
					shake_trees_near(t.pos, t.r + 0.6, -into) // apples come down
				}
				burst({t.pos.x, t.y + t.r, t.pos.y}, 5, 2, COLOR_DUST, 0.1)
			}
		}
		// Rabbits and crows are off at a stone coming anywhere near.
		scare_pests_near(t.pos, t.y)

		// A flying rock knocks enemies over: a heavier rock passes on more of its speed.
		if speed > 2 {
			for &e in g.enemies[:g.enemy_count] {
				reach := t.r + ENEMY_RADIUS[e.kind]
				if !on_ground(&e) || e.state == .Dead || e.hit_t > 0 || t.y > ENEMY_RADIUS[e.kind] * 2 || length2(e.pos - t.pos) >= reach {
					continue
				}
				e.hit_t = 0.3
				if t.spear {
					spear_hits(&t, &e, speed)
					break
				}
				damage := stone_damage(t.kg, speed, e.kind)
				if t.kg < LIGHT_STONE {
					// A pebble: it stings and startles, and a fox lets go.
					drop_loot(&e)
					if hurt_enemy(&e, damage) {
						enemy_impact(&e, normalize2(t.vel), IMPACT_FALL_SPEED, false)
					} else if e.state == .Chase {
						e.scared_t = max(e.scared_t, random_range(PEBBLE_FRIGHT.x, PEBBLE_FRIGHT.y))
					}
					pain_stars({e.pos.x, ENEMY_RADIUS[e.kind] * 1.6, e.pos.y}, 3)
					t.vel *= 0.15
					continue
				}
				passed := 1.6 * t.kg / (t.kg + ENEMY_KG[e.kind]) * speed
				hurt_enemy(&e, damage)
				enemy_impact(&e, normalize2(t.vel), passed, false)
				t.vel *= 0.5
				g.shake = max(g.shake, 0.3)
				burst({e.pos.x, 0.7, e.pos.y}, 10, 4, COLOR_STAR, 0.12)
			}
		}

		if !t.active {
			continue // a spear that found its mark
		}
		if t.spear && t.y <= 0 && t.vy < 0 {
			spear_lands(&t, t.pos)
			continue
		}
		if t.y <= 0 && t.vy < 0 {
			// Down.
			g.shake = max(g.shake, min(t.kg * -t.vy * 0.0015, 0.5))
			burst({t.pos.x, 0.2, t.pos.y}, 10, 3, COLOR_DUST, 0.14)
			// Still fast: it skims on, a little lower and slower each time.
			if speed > 3 && t.vy < -1.5 {
				t.y = 0
				t.vy = -t.vy * 0.45
				t.vel *= 0.8
				continue
			}
			if t.round < 0 {
				t.active = false // a pebble is lost in the grass
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
		if t.active && t.spear {
			// Point first, along the way it is going.
			at := Vec3{t.pos.x, t.y, t.pos.y}
			along := linalg.normalize0(Vec3{t.vel.x, t.vy, t.vel.y}) * SPEAR_LEN / 2
			draw_spear(at - along, at + along)
		} else if t.active {
			draw_rock(translate({t.pos.x, t.y + t.r * 0.75, t.pos.y}) * rot_x(t.spin), t.r)
		}
	}
	if p.winding && !drawing_shadows() {
		// What he is aiming at: a yellow arrowhead bobbing over it.
		if pos, height, _, ok := aim_at(p.aim); ok {
			top := height * 2 + 0.9 + 0.12 * math.sin(g.time * 9)
			draw_shape(.Cone, translate({pos.x, top, pos.y}) * rot_x(math.PI) * scale({0.22, 0.42, 0.22}), UI_YELLOW)
		}
		if p.wind_stone && p.wind_item == .Spear {
			// The spear, drawn back over his shoulder.
			draw_spear(prosio_to_world({HOLD_SIDE * 0.5, 1.2, -0.95}), prosio_to_world({HOLD_SIDE * 0.5, 1.42, 0.5}))
		} else if p.wind_stone {
			// The pebble, drawn back in his hoof.
			at := prosio_to_world({HOLD_SIDE * 0.5, 1.25, -0.25})
			draw_rock(translate(at), PEBBLE_RADIUS)
		}
	}
}
