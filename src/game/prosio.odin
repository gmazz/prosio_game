package game

import "core:math"

// Prosio's fat, in kilograms. (His weight is this and the rest of him, added
// up in diet.odin.) Running out of it and of his carbs as well, or carrying
// too much fat, is a fail.
FAT_MAX :: f32(100) // heart gives up
FAT_START :: f32(45)
FAT_LEAN :: f32(30) // below this he is lean
FAT_HUGE :: f32(70) // above this he is huge
FAT_DANGER :: f32(7) // warning zone width at each end
KG_START :: f32(80) // what he weighs at the start; walking and running burn in proportion to this
KG_SLIM :: f32(35) // the weight at which he is at his narrowest

STAMINA_MAX :: f32(100)
DASH_TIME :: f32(0.28)
PICK_TIME :: f32(0.5) // stooping to pick something up and putting it in the sack

// Everything he does burns some of his weight, a little for everyday things
// and more for fighting. Walking and running burn in proportion to his
// weight: these are for an 80 kg Prosio.
WALK_BURN :: f32(0.02) // kg per second of walking
SPRINT_BURN :: f32(0.06) // kg per second of sprinting
GATHER_BURN :: f32(0.08) // kg per thing picked up
JUMP_BURN :: f32(0.06) // kg per jump
FIGHT_BURN :: f32(0.2) // kg per bump, grab, bash or throw
HURT_BURN :: f32(0.35) // kg per shove or peck taken

// Ordinary legs put the same energy into every jump, so height = energy /
// weight: a 40 kg Prosio jumps 0.9 high, a 120 kg Prosio only 0.3. Strong
// legs put in more (see LEG_SPRING in body.odin).
JUMP_ENERGY :: f32(36)

Fail :: enum {
	None,
	Fainted,
	Heart_Attack,
	Diet, // a nutrient, or water, stayed at an extreme too long (see diet.odin)
}

Prosio :: struct {
	pos, vel:     Vec2,
	height:       f32, // how far his feet are above the meadow
	vy:           f32, // vertical speed while in the air
	airborne:     bool,
	peak:         f32, // the highest his feet have been since he left the ground
	facing:       f32,
	kg:           f32, // what he weighs: the sum of his parts (see body_kg in diet.odin)
	fat:          f32, // kg of fat on him
	trait:        [Trait]f32, // his muscles and skills (see body.odin)
	trait_was:    [Trait]f32, // what they were a few seconds ago,
	trend:        [Trait]f32, // and how much each has changed since
	fat_was:      f32,
	fat_trend:    f32,
	trend_t:      f32,
	pick_total:   f32, // how long this stoop takes in all
	stamina:      f32,
	regen_delay:  f32,
	sprinting:    bool,
	winded:       bool, // ran out of stamina; no sprinting until some is back
	dust_t:       f32,
	dash_t:       f32, // time left in the current bump charge
	dazed_t:      f32, // time left seeing stars
	safe_t:       f32, // time left during which enemies cannot shove him again
	eat_t:        f32, // time left in the munching animation
	pick_t:       f32, // time left picking something up
	pick_item:    Item, // what he is picking up
	walk_phase:   f32,
	wobble:       f32, // belly jiggle, a small spring
	wobble_vel:   f32,
	stretch:      f32, // squash and stretch on jumps and landings, another spring
	stretch_vel:  f32,
	carry:        Carry, // what he is holding, if anything
	carry_index:  int, // which enemy or rock
	carry_kg:     f32, // its weight; 0 when his hands are empty
	carry_r:      f32, // a carried rock's size
	lift_t:       f32, // time left until it is up over his head
	lift_total:   f32,
	held_t:       f32, // how long he has held it
	swinging:     bool, // swinging a held animal round, to bash with it or throw it
	swing_throw:  bool, // the swing ends in a throw
	swing_t:      f32, // how long the swing has lasted
	swing_total:  f32, // how long it takes
	swing_from:   Vec3, // where his hand points from his shoulder (in his own frame) at the start,
	swing_via:    Vec3, // the way it sweeps round,
	swing_to:     Vec3, // and where it ends
	bash_queued:  bool, // SPACE was pressed again during a swing
	strain:       f32, // 0 to 1: how hard he strains against a heavy animal
	heave_t:      f32, // time left in a heave at an animal too heavy to swing
	lunge_t:      f32, // a held animal is lunging while this is positive
	throw_queued: bool, // F was pressed while still lifting a rock
	hand:         Vec3, // where the hand that holds an animal by the leg is
	fail:         Fail,
	fail_t:       f32,
	fail_need:    Need, // which level ended the game,
	hiccup_t:     f32, // time until his next hiccup, with too much sugar in him
	need:         [Need]f32, // his levels of each nutrient and of water, 0 to 100
	need_was:     [Need]Need_State, // how each was a moment ago, to notice changes
	extreme_t:    [Need]f32, // how long each has been at a dangerous extreme
	rush:         bool, // on a sugar rush
	crash_t:      f32, // time left in the sugar crash after one
	gas_t:        f32, // time until his next wind
	ache_cd:      f32, // time until the next tummy ache
	ache_t:       f32, // time left doubled up with an ache or a cramp
	cramp_t:      f32, // how long he has sprinted towards a cramp
	drinking:     bool, // the thing he is stooping for is a drink
	sack:         [Item]int, // what he has gathered or baked
	sack_kcal:    [Item]f32, // and the calories in all of each kind
	sack_sel:     Item, // what he would eat next
	bubble:       cstring, // speech bubble text
	bubble_t:     f32,
	hint_cd:      f32,
}

// How fat he is: 0 with none at all, 1 with all he can carry.
fatness :: proc() -> f32 {
	return clamp(g.prosio.fat / FAT_MAX, 0, 1)
}

// Prosio's size on the ground. The hands swing beyond this torso radius.
prosio_radius :: proc(kg: f32) -> f32 {
	return 0.42 + (kg - KG_SLIM) * 0.0055
}

// How wide his chest is: wider with fat, and with good lungs. His arms hang
// from its sides.
prosio_chest :: proc(kg: f32) -> f32 {
	return min(prosio_radius(kg) - 0.12, 0.33 + 0.16 * fatness()) * lerp(1, 1.1, g.prosio.trait[.Lungs])
}

// Everything below gets worse with fat, and the gap is deliberately wide.
// Strong legs make up for some of it, and good lungs for some more.
walk_speed :: proc() -> f32 {
	return lerp(7.2, 2.6, math.pow(fatness(), 0.8)) * tone(.Legs, WEAK_LEGS, LEG_SPEED)
}

sprint_boost :: proc() -> f32 {
	return lerp(1.7, 1.25, fatness())
}

sprint_drain :: proc() -> f32 {
	return lerp(9, 42, fatness()) * lerp(1, LUNG_DRAIN, g.prosio.trait[.Lungs]) // stamina per second
}

dash_speed :: proc() -> f32 {
	return lerp(15, 10.5, fatness())
}

dash_cost :: proc() -> f32 {
	return lerp(9, 42, fatness())
}

jump_cost :: proc() -> f32 {
	return lerp(4, 22, fatness())
}

stamina_regen :: proc() -> f32 {
	return lerp(50, 8, math.pow(fatness(), 0.8)) * lerp(1, LUNG_REGEN, g.prosio.trait[.Lungs]) // stamina per second
}

// How high he jumps weighing this much (with what he carries).
jump_height :: proc(kg: f32) -> f32 {
	return JUMP_ENERGY * tone(.Legs, WEAK_LEGS, LEG_SPRING) / kg
}

// The same, with a name put into the text ("Got my %s back!"). The text is
// kept here, as the formatted one does not last.
named_text: [96]u8
say_named :: proc(format: cstring, name: cstring, seconds: f32 = 2) {
	text := string(ui_format_name(format, name))
	n := min(len(text), len(named_text) - 1)
	copy(named_text[:n], text[:n])
	named_text[n] = 0
	say(cstring(&named_text[0]), seconds)
}

say :: proc(text: cstring, seconds: f32 = 1.6) {
	g.prosio.bubble = text
	g.prosio.bubble_t = seconds
}

// A speech bubble that does not repeat too often.
hint :: proc(text: cstring) {
	if g.prosio.hint_cd <= 0 {
		say(text, 2)
		g.prosio.hint_cd = 3.5
	}
}

reset_prosio :: proc() {
	g.prosio = Prosio {
		pos     = HOME + {0, 4},
		fat     = FAT_START,
		stamina = STAMINA_MAX,
	}
	for n in Need {
		g.prosio.need[n] = n == .Water ? WATER_START : NEED_START
	}
	g.prosio.fat_was = FAT_START
	g.prosio.kg = body_kg()
}

update_prosio :: proc(dt: f32) {
	p := &g.prosio
	r := prosio_radius(p.kg)

	p.bubble_t -= dt
	p.hint_cd -= dt
	p.dazed_t -= dt
	p.safe_t -= dt
	p.eat_t -= dt
	p.pick_t -= dt
	p.wobble_vel += (-180 * p.wobble - 9 * p.wobble_vel) * dt
	p.wobble += p.wobble_vel * dt
	p.stretch_vel += (-260 * p.stretch - 16 * p.stretch_vel) * dt
	p.stretch += p.stretch_vel * dt

	if p.fail != .None {
		// Lying down he takes up more room, so he is kept that much further from walls.
		p.fail_t += dt
		p.vel = approach2(p.vel, {}, 25 * dt)
		p.pos += p.vel * dt
		collide_static(&p.pos, max(r, 1.0), p.height)
		prosio_vertical(dt)
		if p.fail_t > 1 && pressed(.Restart) {
			wake_up()
			save_game()
		}
		return
	}

	move: Vec2
	if button_down(.Left) {move.x -= 1}
	if button_down(.Right) {move.x += 1}
	if button_down(.Up) {move.y -= 1}
	if button_down(.Down) {move.y += 1}
	move = normalize2(move)
	moving := move != {}

	grounded := !p.airborne
	busy := p.eat_t > 0 || p.pick_t > 0 || p.ache_t > 0
	can_act := p.dazed_t <= 0 && p.dash_t <= 0 && !busy
	food := food_in_reach(p.pos, r + 0.75)
	bush := bush_in_reach(p.pos, r + 0.6)
	station, at_station := station_near(p.pos, r)
	mill := mill_in_reach(p.pos, r)
	pond := pond_in_reach(p.pos, r)

	// Grabbing and throwing.
	update_grab(dt, can_act)
	carrying := p.carry != .Nothing

	// With an animal in his hand, the action button milks a goat, or chops
	// a dead one into meat at the fire.
	if grounded && can_act && p.carry == .Enemy && p.lift_t <= 0 && !p.swinging && pressed(.Action) {
		use_held_animal()
		carrying = p.carry != .Nothing
	}
	// The action button next to food puts it in the sack; at the oven, the
	// fire or the churn it makes things, at the mill it grinds, and at the
	// pond he drinks.
	if grounded && can_act && !carrying && pressed(.Action) {
		if food != nil || bush != nil {
			gather(food, bush)
		} else if at_station {
			use_station(station)
		} else if mill {
			use_mill()
		} else if pond {
			drink()
		}
	}
	// The sack: choose with Z and C, eat with Q.
	if pressed(.Sack_Next) {
		sack_step(1)
	}
	if pressed(.Sack_Prev) {
		sack_step(-1)
	}
	if grounded && can_act && !carrying && pressed(.Eat) {
		eat_from_sack()
	}

	// Jump. A lighter Prosio goes higher, and a load weighs him down.
	if grounded && can_act && p.lift_t <= 0 && p.carry != .Enemy && pressed(.Jump) {
		cost := jump_cost()
		if p.stamina >= cost {
			p.stamina -= cost
			p.regen_delay = 0.4
			burn(JUMP_BURN, true)
			train(.Legs, JUMP_WORK)
			height := jump_height(total_kg())
			if lacks(.Electrolytes) {
				height *= CRAMP_JUMP // cramped legs
			}
			p.vy = math.sqrt(2 * GRAVITY * height)
			p.airborne = true
			p.peak = p.height
			p.stretch_vel += 4
			burst({p.pos.x, p.height + 0.1, p.pos.y}, 5, 2, COLOR_DUST, 0.1)
			grounded = false
		} else {
			hint("Too tired to jump!")
		}
	}

	// Bump: a short belly charge. Costs more stamina the heavier he is.
	if grounded && can_act && !carrying && pressed(.Bump) {
		cost := dash_cost()
		if p.stamina >= cost {
			dir := moving ? move : facing_dir(p.facing)
			p.stamina -= cost
			p.regen_delay = 0.6
			p.dash_t = DASH_TIME
			// A bump out of a sprint keeps the extra speed.
			p.vel = dir * max(dash_speed(), length2(p.vel) + 2)
			p.facing = math.atan2(dir.x, dir.y)
			burn(FIGHT_BURN, true)
			p.wobble_vel -= 2
			burst({p.pos.x, p.height + 0.1, p.pos.y}, 6, 2, COLOR_DUST, 0.12)
		} else {
			hint("Too tired!")
		}
	}

	// Sprint: hold the button while moving.
	t := fatness()
	if p.winded && p.stamina > 30 {
		p.winded = false
	}
	p.sprinting = button_down(.Sprint) && moving && grounded && p.dazed_t <= 0 && !busy && !carrying && !p.winded && p.crash_t <= 0
	if p.sprinting {
		p.stamina -= sprint_drain() * (p.rush ? RUSH_DRAIN : 1) * dt
		p.regen_delay = lerp(0.3, 1.0, t)
		burn(SPRINT_BURN * p.kg / KG_START * dt, true)
		train(.Legs, SPRINT_WORK * dt)
		train(.Lungs, SPRINT_WORK * dt)
		p.dust_t -= dt
		if p.dust_t <= 0 {
			p.dust_t = 0.1
			burst({p.pos.x, p.height + 0.1, p.pos.y}, 1, 1.5, COLOR_DUST, 0.1)
		}
		if p.stamina <= 0 {
			p.stamina = 0
			p.winded = true
			p.sprinting = false
			say("Puff... puff...", 1.4)
		}
	}

	// Movement. A heavy Prosio is slower and takes longer to get going.
	if p.dash_t > 0 {
		p.dash_t -= dt
	} else {
		speed := walk_speed() * diet_speed()
		if p.sprinting {
			speed *= sprint_boost()
		}
		// With a load, the same legs have more weight to move.
		speed *= p.kg / total_kg()
		// And a dead weight dragged behind him holds him back.
		if p.carry == .Enemy && g.enemies[p.carry_index].ko {
			speed *= p.kg / (p.kg + ENEMY_KG[g.enemies[p.carry_index].kind] * DRAG_SLIDE / strength())
			if moving {
				train(.Legs, DRAG_WORK * dt)
			}
		}
		target := move * speed
		if p.dazed_t > 0 || busy || p.lift_t > 0 {
			target = {}
		}
		if p.swinging {
			target *= 0.5 // he can bash on the move, slowly
		}
		accel := lerp(55, 10, t)
		if p.airborne {
			accel *= 0.4 // only a little steering in the air
		}
		p.vel = approach2(p.vel, target, accel * dt)
		// Straining against a heavy animal, he keeps facing it and backs away.
		if moving && target != {} && p.strain < 0.4 {
			p.facing = approach_angle(p.facing, math.atan2(move.x, move.y), 12 * dt)
		}
		if moving && target != {} && grounded && !p.sprinting {
			burn(WALK_BURN * p.kg / KG_START * dt)
			train(.Legs, WALK_WORK * dt)
		}
	}
	p.pos += p.vel * dt
	if hit, n := collide_static(&p.pos, r, p.height); hit {
		into := dot2(p.vel, n)
		if p.dash_t > 0 && into < -2 {
			// Bumping a tree shakes it, and down come the apples.
			shake_trees_near(p.pos, r + 0.3, -into * p.kg / 60)
		}
		if into < 0 {
			p.vel -= n * into
		}
	}
	prosio_vertical(dt)

	speed := length2(p.vel)
	if !p.airborne {
		p.walk_phase += speed * dt * 2.2
		if speed > 1 && t > 0.4 {
			// A big belly jiggles with every step.
			p.wobble_vel += math.sin(p.walk_phase * 2) * t * 6 * dt
		}
	}

	// Stamina comes back much faster when he is lean; slowly with no carbs
	// in him, and only part of the way when he is thirsty.
	if p.dash_t <= 0 && !p.sprinting && p.carry == .Nothing {
		p.regen_delay -= dt
		top := lacks(.Water) ? THIRSTY_STAMINA : STAMINA_MAX
		if p.regen_delay <= 0 && p.stamina < top {
			regen := stamina_regen() * (lacks(.Carbs) ? NO_FUEL : 1)
			p.stamina = min(p.stamina + regen * dt, top)
		}
	}

	// What he has eaten and drunk, and what it does to him.
	update_diet(dt)

	// His muscles and skills follow what he has been doing, and his weight
	// follows them and his fat.
	update_body(dt)

	// The limits of his fat.
	if p.fail != .None {
		// His diet has done for him.
	} else if energy_kg() <= 0.001 {
		p.fail = .Fainted // nothing left to burn: no fat, no carbs
	} else if p.fat >= FAT_MAX {
		p.fail = .Heart_Attack
	} else if starving() {
		hint(sack_has_food() ? "So hungry... Q: eat from my sack!" : "So hungry... I must find food!")
	} else if p.fat > FAT_MAX - FAT_DANGER {
		hint("So full... no more food for now!")
	}
	if p.fail != .None {
		if p.carry != .Nothing {
			drop_carry()
		}
		p.fail_t = 0
		p.bubble_t = 0
		p.sprinting = false
		p.dash_t = 0
		g.shake = 0.4
	}
}

// Falling and landing. The meadow is flat.
prosio_vertical :: proc(dt: f32) {
	p := &g.prosio
	if !p.airborne {
		p.height = 0
		return
	}
	p.vy -= GRAVITY * dt
	p.height += p.vy * dt
	p.peak = max(p.peak, p.height)
	if p.vy < -1 && stomp_enemies() {
		return // came down on an animal, and bounced off it
	}
	if p.vy <= 0 && p.height <= 0 {
		speed := -p.vy
		p.height = 0
		p.vy = 0
		p.airborne = false
		prosio_lands(speed)
	}
}

// He hits the ground at this speed. The thump grows with weight times speed.
prosio_lands :: proc(speed: f32) {
	p := &g.prosio
	if speed < 1.5 {
		return
	}
	impact := total_kg() * speed
	g.shake = max(g.shake, min(impact / 2500, 0.6))
	p.stretch_vel -= min(speed * 0.5, 5)
	p.wobble_vel += speed * 0.5 * fatness()
	burst({p.pos.x, p.height + 0.1, p.pos.y}, 4 + int(impact / 150), 2 + impact / 600, COLOR_DUST, 0.12)
}
