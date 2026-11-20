package game

import "core:math"

// Prosio's weight in kilograms. Leaving the range at either end is a fail.
KG_MIN :: f32(35) // faints from hunger
KG_MAX :: f32(135) // heart gives up
KG_START :: f32(80)
KG_LEAN :: f32(65) // below this he is lean
KG_HUGE :: f32(105) // above this he is huge
KG_DANGER :: f32(7) // warning zone width at each end

STAMINA_MAX :: f32(100)
DASH_TIME :: f32(0.28)
PUSHUP_TIME :: f32(0.6) // seconds per push-up
PUSHUP_KG :: f32(2.5) // weight lost per push-up
WALK_BURN :: f32(0.05) // kg lost per second of walking
SPRINT_BURN :: f32(0.2) // kg lost per second of sprinting
DASH_BURN :: f32(0.3) // kg lost per bump
JUMP_BURN :: f32(0.15) // kg lost per jump

// His legs put the same energy into every jump, so height = energy / weight:
// a 40 kg Prosio jumps 0.9 high, a 120 kg Prosio only 0.3.
JUMP_ENERGY :: f32(36)

Fail :: enum {
	None,
	Fainted,
	Heart_Attack,
}

Prosio :: struct {
	pos, vel:     Vec2,
	height:       f32, // how far his feet are above the meadow
	vy:           f32, // vertical speed while in the air
	airborne:     bool,
	on_seesaw:    int, // the seesaw he stands on, or -1
	dive:         bool, // an aimed jump from the tower; no steering until he lands
	facing:       f32,
	kg:           f32,
	stamina:      f32,
	regen_delay:  f32,
	sprinting:    bool,
	winded:       bool, // ran out of stamina; no sprinting until some is back
	dust_t:       f32,
	dash_t:       f32, // time left in the current bump charge
	dazed_t:      f32, // time left seeing stars
	safe_t:       f32, // time left during which enemies cannot shove him again
	eat_t:        f32, // time left in the munching animation
	pushups_on:   bool, // the action button started a push-up session
	pushups:      bool, // doing push-ups right now
	pushup_phase: f32,
	pushup_reps:  int,
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
	hand:         Vec3, // where the hand that holds a tail is
	fail:         Fail,
	fail_t:       f32,
	bubble:       cstring, // speech bubble text
	bubble_t:     f32,
	hint_cd:      f32,
}

// 0 at the thinnest, 1 at the fattest.
fatness :: proc(kg: f32) -> f32 {
	return clamp((kg - KG_MIN) / (KG_MAX - KG_MIN), 0, 1)
}

// Prosio's size on the ground. This is what does or does not fit through a
// door. The hands swing beyond this torso radius.
prosio_radius :: proc(kg: f32) -> f32 {
	return 0.42 + (kg - KG_MIN) * 0.0055
}

// How wide his chest is. His arms hang from its sides.
prosio_chest :: proc(kg: f32) -> f32 {
	return min(prosio_radius(kg) - 0.12, 0.33 + 0.16 * fatness(kg))
}

// Everything below gets worse with weight, and the gap is deliberately wide.
walk_speed :: proc(kg: f32) -> f32 {
	return lerp(7.2, 2.6, math.pow(fatness(kg), 0.8))
}

sprint_boost :: proc(kg: f32) -> f32 {
	return lerp(1.7, 1.25, fatness(kg))
}

sprint_drain :: proc(kg: f32) -> f32 {
	return lerp(9, 42, fatness(kg)) // stamina per second
}

dash_speed :: proc(kg: f32) -> f32 {
	return lerp(15, 10.5, fatness(kg))
}

dash_cost :: proc(kg: f32) -> f32 {
	return lerp(9, 42, fatness(kg))
}

jump_cost :: proc(kg: f32) -> f32 {
	return lerp(4, 22, fatness(kg))
}

pushup_cost :: proc(kg: f32) -> f32 {
	return lerp(5, 11, fatness(kg))
}

stamina_regen :: proc(kg: f32) -> f32 {
	return lerp(50, 8, math.pow(fatness(kg), 0.8)) // stamina per second
}

jump_height :: proc(kg: f32) -> f32 {
	return JUMP_ENERGY / kg
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
		pos       = {0, 6.5},
		kg        = KG_START,
		stamina   = STAMINA_MAX,
		on_seesaw = -1,
	}
}

COUNT_TEXT := [?]cstring{"1!", "2!", "3!", "4!", "5!", "6!", "7!", "8!", "9!", "10!", "So many!"}

update_prosio :: proc(dt: f32) {
	p := &g.prosio
	r := prosio_radius(p.kg)

	p.bubble_t -= dt
	p.hint_cd -= dt
	p.dazed_t -= dt
	p.safe_t -= dt
	p.eat_t -= dt
	p.wobble_vel += (-180 * p.wobble - 9 * p.wobble_vel) * dt
	p.wobble += p.wobble_vel * dt
	p.stretch_vel += (-260 * p.stretch - 16 * p.stretch_vel) * dt
	p.stretch += p.stretch_vel * dt

	// Lying down he takes up more room, so he is kept that much further from walls.
	lying := p.pushups || p.fail != .None
	body_r := lying ? max(r, 1.0) : r

	if p.fail != .None {
		p.fail_t += dt
		p.vel = approach2(p.vel, {}, 25 * dt)
		p.pos += p.vel * dt
		collide_static(&p.pos, body_r, p.height)
		prosio_vertical(dt)
		if p.fail_t > 1 && pressed(.Restart) {
			reset_prosio()
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
	can_act := p.dazed_t <= 0 && p.dash_t <= 0
	food := food_in_reach(p.pos, r + 0.75)
	bush := bush_in_reach(p.pos, r + 0.6)

	// Grabbing and throwing.
	update_grab(dt, can_act)
	carrying := p.carry != .Nothing

	// Eating: tap the action button next to food.
	// Eating: tap the action button next to food, or next to a bush with
	// berries on it.
	if grounded && can_act && !carrying && (food != nil || bush != nil) && pressed(.Action) {
		at: Vec2
		if food != nil {
			p.kg += FOOD_KG[food.kind]
			if food.fallen {
				food.gone = true
			} else {
				food.respawn = FOOD_RESPAWN[food.kind]
			}
			at = food.pos
			EATEN := [Food_Kind]cstring{.Apple = "Crunch! Yum!", .Mushroom = "Mmm, mushroom!", .Pumpkin = "A whole pumpkin! Burp!"}
			say(EATEN[food.kind])
			burst({at.x, 0.5, at.y}, 10, 3, food.kind == .Mushroom ? COLOR_DUST : COLOR_CRUMB, 0.08)
		} else {
			p.kg += BERRY_KG
			bush.fruit -= 1
			bush.fruit_t = BERRY_REGROW
			bush.shake_t = 0.4
			at = bush.pos
			say("Berries! Yum!")
			burst({at.x, 0.7, at.y}, 8, 2.5, BERRY_COLOR, 0.06)
		}
		p.eat_t = 0.5
		p.wobble_vel += 2.5
		to_food := at - p.pos
		p.facing = math.atan2(to_food.x, to_food.y)
	}

	// Push-ups: hold the action button anywhere else.
	if grounded && food == nil && bush == nil && !carrying && pressed(.Action) && can_act && !p.pushups_on {
		p.pushups_on = true
		p.pushup_phase = 0
		p.pushup_reps = 0
	}
	if !button_down(.Action) {
		p.pushups_on = false
	}
	p.pushups = p.pushups_on && grounded && can_act && !carrying && !moving && p.eat_t <= 0
	if p.pushups {
		cost := pushup_cost(p.kg)
		if p.stamina < cost {
			p.pushups_on = false
			p.pushups = false
			say("Phew! I need a rest!")
		} else {
			p.pushup_phase += dt / PUSHUP_TIME
			if p.pushup_phase >= 1 {
				p.pushup_phase -= 1
				p.kg -= PUSHUP_KG
				p.stamina -= cost
				p.regen_delay = 0.5
				say(COUNT_TEXT[min(p.pushup_reps, len(COUNT_TEXT) - 1)], 0.6)
				p.pushup_reps += 1
				burst({p.pos.x, p.height + 1, p.pos.y}, 4, 2.5, COLOR_SWEAT, 0.07)
			}
		}
	}

	// Jump. A lighter Prosio goes higher, and a load weighs him down.
	if grounded && can_act && !p.pushups && p.lift_t <= 0 && p.carry != .Enemy && pressed(.Jump) {
		cost := jump_cost(p.kg)
		if p.stamina >= cost {
			p.stamina -= cost
			p.regen_delay = 0.4
			p.kg -= JUMP_BURN
			p.vy = math.sqrt(2 * GRAVITY * jump_height(total_kg()))
			p.airborne = true
			p.stretch_vel += 4
			burst({p.pos.x, p.height + 0.1, p.pos.y}, 5, 2, COLOR_DUST, 0.1)
			// From the tower, the jump is aimed at the catapult's landing pad.
			if on_tower(p.pos, p.height) {
				pad := catapult_pad()
				fall := max(p.height - pad_rest_height(), 0)
				air_time := (p.vy + math.sqrt(p.vy * p.vy + 2 * GRAVITY * fall)) / GRAVITY
				p.vel = (pad - p.pos) / air_time
				// He must be past the tower's edge before he drops below its top,
				// without flying over the short end of the plank.
				s := &g.seesaws[CATAPULT]
				edge := g.platforms[g.tower].hi.x
				back_at_top := 2 * p.vy / GRAVITY
				needed := (edge + 0.05 - p.pos.x) / back_at_top
				most := (s.pivot.x - 0.2 - p.pos.x) / air_time
				p.vel.x = clamp(max(p.vel.x, needed), 0, most)
				p.dive = true
				p.facing = math.atan2(p.vel.x, p.vel.y)
			}
			p.on_seesaw = -1
			grounded = false
		} else {
			hint("Too tired to jump!")
		}
	}

	// Bump: a short belly charge. Costs more stamina the heavier he is.
	if grounded && can_act && !p.pushups && !carrying && pressed(.Bump) {
		cost := dash_cost(p.kg)
		if p.stamina >= cost {
			dir := moving ? move : facing_dir(p.facing)
			p.stamina -= cost
			p.regen_delay = 0.6
			p.dash_t = DASH_TIME
			// A bump out of a sprint keeps the extra speed.
			p.vel = dir * max(dash_speed(p.kg), length2(p.vel) + 2)
			p.facing = math.atan2(dir.x, dir.y)
			p.kg -= DASH_BURN
			p.wobble_vel -= 2
			burst({p.pos.x, p.height + 0.1, p.pos.y}, 6, 2, COLOR_DUST, 0.12)
		} else {
			hint("Too tired!")
		}
	}

	// Sprint: hold the button while moving.
	t := fatness(p.kg)
	if p.winded && p.stamina > 30 {
		p.winded = false
	}
	p.sprinting = button_down(.Sprint) && moving && grounded && can_act && !carrying && !p.pushups && p.eat_t <= 0 && !p.winded
	if p.sprinting {
		p.stamina -= sprint_drain(p.kg) * dt
		p.regen_delay = lerp(0.3, 1.0, t)
		p.kg -= SPRINT_BURN * dt
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
	} else if !p.dive {
		speed := walk_speed(p.kg)
		if p.sprinting {
			speed *= sprint_boost(p.kg)
		}
		// With a load, the same legs have more weight to move.
		speed *= p.kg / total_kg()
		target := move * speed
		if p.dazed_t > 0 || p.pushups || p.eat_t > 0 || p.lift_t > 0 {
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
		if moving && target != {} {
			if grounded {
				p.kg -= WALK_BURN * dt
			}
		}
	}
	p.pos += p.vel * dt
	if hit, n := collide_static(&p.pos, body_r, p.height); hit && !p.dive {
		into := dot2(p.vel, n)
		if p.dash_t > 0 && into < -2 {
			// Bumping a tree shakes it, and down come the apples.
			shake_trees_near(p.pos, body_r + 0.3, -into * p.kg / 60)
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

	// Stamina comes back much faster when he is lean.
	if p.dash_t <= 0 && !p.pushups && !p.sprinting && p.carry == .Nothing {
		p.regen_delay -= dt
		if p.regen_delay <= 0 {
			p.stamina = min(p.stamina + stamina_regen(p.kg) * dt, STAMINA_MAX)
		}
	}

	// The skinny door.
	near_door := abs(p.pos.x - g.door_pos.x) < 1.4 && p.pos.y > g.door_pos.y && p.pos.y - g.door_pos.y < 1.5
	if near_door && r > DOOR_GAP / 2 && button_down(.Up) {
		hint("I'm too chubby for this door!")
	}

	// The pressure plate.
	if !g.gates[0].open && !p.airborne && length2(p.pos - g.plate_pos) < 0.9 {
		if total_kg() >= PLATE_KG {
			g.gates[0].open = true
			g.shake = 0.5
			say("CLICK! Heavy enough!", 2)
			burst({g.plate_pos.x, 0.2, g.plate_pos.y}, 14, 4, COLOR_STAR, 0.12)
		} else {
			hint("I'm not heavy enough!")
		}
	}

	// Golden truffles.
	for &tr in g.truffles {
		if tr.visible && !tr.taken && length2(tr.pos - p.pos) < r + 0.5 {
			tr.taken = true
			g.truffle_count += 1
			say("A golden truffle!", 2.2)
			burst({tr.pos.x, 0.8, tr.pos.y}, 24, 5, COLOR_GOLD, 0.13)
		}
	}

	// Weight limits.
	p.kg = clamp(p.kg, KG_MIN, KG_MAX)
	if p.kg <= KG_MIN {
		p.fail = .Fainted
	} else if p.kg >= KG_MAX {
		p.fail = .Heart_Attack
	} else if p.kg < KG_MIN + KG_DANGER {
		hint("So hungry... I must eat!")
	} else if p.kg > KG_MAX - KG_DANGER {
		hint("So full... I must exercise!")
	}
	if p.fail != .None {
		if p.carry != .Nothing {
			drop_carry()
		}
		p.fail_t = 0
		p.bubble_t = 0
		p.pushups = false
		p.pushups_on = false
		p.sprinting = false
		p.dash_t = 0
		g.shake = 0.4
	}
}

// Falling, landing and following the ground under his feet.
prosio_vertical :: proc(dt: f32) {
	p := &g.prosio
	// An aimed jump off the tower lands on the catapult, never back on the tower.
	ground, seesaw := ground_at(p.pos, !p.dive)
	if p.airborne {
		p.vy -= GRAVITY * dt
		p.height += p.vy * dt
		if p.vy <= 0 && p.height <= ground {
			speed := -p.vy
			p.height = ground
			p.vy = 0
			p.airborne = false
			p.dive = false
			p.on_seesaw = seesaw
			prosio_lands(speed, seesaw)
		}
	} else if p.height - ground > DROP {
		// Walked off an edge.
		p.airborne = true
		p.vy = 0
		p.on_seesaw = -1
	} else {
		p.height = ground
		p.on_seesaw = seesaw
	}
}

// He hits the ground at this speed. The thump grows with weight times speed.
prosio_lands :: proc(speed: f32, seesaw: int) {
	p := &g.prosio
	if speed < 1.5 {
		return
	}
	impact := total_kg() * speed
	g.shake = max(g.shake, min(impact / 2500, 0.6))
	p.stretch_vel -= min(speed * 0.5, 5)
	p.wobble_vel += speed * 0.5 * fatness(p.kg)
	burst({p.pos.x, p.height + 0.1, p.pos.y}, 4 + int(impact / 150), 2 + impact / 600, COLOR_DUST, 0.12)
	if seesaw >= 0 {
		seesaw_impact(seesaw, speed)
	} else {
		stomp_enemies(speed)
	}
}
