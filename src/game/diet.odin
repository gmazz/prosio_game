package game

import "core:math"

// What Prosio is made of, what he eats, and how the one turns into the
// other. There is one set of books, in kilograms.
//
// His weight is nothing but the sum of his parts:
//
//   frame     bones and the rest: FRAME, which never changes
//   fat       his reserve of energy
//   muscle    his arms and legs (see body.odin)
//   carbs     quick fuel: what he has eaten and not yet burned
//   protein   what muscle is built from, waiting to be used
//   fibre     roughage on its way through him
//   water
//
// Every bar on the screen is one of these parts, with its kilograms beside
// it, and the weight bar is the same parts laid end to end. Two more things
// he needs weigh nothing: vitamins and electrolytes.
//
// Food is made of the same stuff: each food's calories are shared between
// carbs, fat, protein, fibre, vitamins and electrolytes, in the proportions
// of its row in COMPOSITION below. Eating puts each into the part of him
// that is the same thing:
//
//   carbs    into his carbs; what will not fit turns to fat
//   fat      straight onto his fat
//   protein  into his protein; what will not fit passes through
//   fibre    into his; what will not fit passes through
//
// (Protein never turns into carbs. Water he drinks at the pond, and gets
// from the water in what he eats: see swallow.)
//
// What he burns comes out of his carbs and his fat. His muscle burns all
// the time, in proportion to how much of it there is, and that, with
// sprinting, jumping and fighting, takes carbs first and only then fat;
// walking, picking and being hurt take from both, carbs in proportion to
// how full they are. With no fat left he lives on his carbs, and with
// neither he faints. Training turns protein into muscle, kilogram for
// kilogram; muscle that fades or wastes goes, as burned fat does. So nothing
// appears from nowhere, and nothing he has can be at odds with what he
// weighs.
//
// The four stores (carbs, protein, fibre, water) and the two weightless
// needs are each kept as a level from 0 to 100, a store's level being how
// full it is (STORE_KG when full). In the middle a level does nothing.
// Below NEED_LOW he lacks it, a nuisance; above NEED_HIGH he is full of it,
// funny and useful as well as a nuisance; above NEED_OVER it is too much,
// funnier and soon over, as the surplus moves on.
//
//                 lacking it                  full of it                                      too much
//   carbs         stamina comes back slowly   sugar rush: fast, tireless... then a crash      hiccups, while the surplus turns to fat
//   protein       his muscles waste away      bulking: muscle builds fast, but he burns more  stiff as a board: slow to swing and stoop
//   fibre         tummy aches stop him        gassy: his wind scares the animals away         a gas storm, one after another
//   water         short of breath             (there is no such thing as too much)
//   vitamins      he sees only close by       eagle eyes: he sees much further                he glows orange: he is spotted from afar
//   electrolytes  cramps when he runs         salty: goats lick him, but he is thirsty        parched: his water runs away
//
// Too much of anything never ends the game. Running right out of water,
// vitamins or electrolytes does, if it lasts TOO_LONG; running out of carbs,
// protein or fibre is only ever a nuisance, since his fat keeps him going.
// (His fat has limits of its own: see prosio.odin.)
Need :: enum {
	Carbs,
	Protein,
	Fibre,
	Water,
	Vitamins,
	Electrolytes,
}


// What each food is made of: the share of its calories that is carbs, fat,
// protein, fibre, vitamins and electrolytes, in per cent (they add up to
// 100). A piece puts into him those shares of its calories and nothing else:
// a piece twice as rich puts in twice as much of each. (So a food's calories
// count all of it, not only what can make him fatter: only the carbs, fat
// and protein in it are energy. The water in a food is not among its
// calories: see item_water and swallow.)
//
// Into him each share goes at a fixed rate: carbs, fat and protein at
// KCAL_PER_KG to the kilogram, fibre at FIBRE_KCAL to the kilogram, and
// vitamins and electrolytes at a point of their level for every calorie.
Nutrient :: enum {
	Carbs,
	Fat,
	Protein,
	Fibre,
	Vitamins,
	Electrolytes,
}


// Shares in per cent, in the order of Nutrient (index it with int(n)).
Composition :: [len(Nutrient)]f32

// What a food is made of, in per cent of its calories. A dish without a
// row of its own is the mix of what went into it, each part counted by its
// calories (so wood, with none, changes nothing). Cooking makes a dish
// richer, but not different: more of everything in it.
composition :: proc(item: Item) -> (c: Composition) {
	if COMPOSITION[item] != {} || !is_dish(item) {
		return COMPOSITION[item]
	}
	total: f32
	for part in recipe_for(item).needs {
		kcal := RAW_KCAL[part.item] * f32(part.count)
		if part.count == 0 || kcal <= 0 {
			continue
		}
		total += kcal
		c += composition(part.item) * kcal
	}
	return total > 0 ? c / total : {}
}

// What a piece of food puts into him: kg of each part, and points of the
// two weightless needs.
Meal :: struct {
	carbs, fat, protein, fibre: f32,
	vitamins, salts:            f32,
}

// What it weighs going in.
meal_kg :: proc(m: Meal) -> f32 {
	return m.carbs + m.fat + m.protein + m.fibre
}

// A piece of this holding this many calories: those calories shared out as
// its composition says.
item_meal :: proc(item: Item, kcal: f32) -> Meal {
	c := composition(item) * (kcal / 100)
	return {
		carbs = c[Nutrient.Carbs] / KCAL_PER_KG,
		fat = c[Nutrient.Fat] / KCAL_PER_KG,
		protein = c[Nutrient.Protein] / KCAL_PER_KG,
		fibre = c[Nutrient.Fibre] / FIBRE_KCAL,
		vitamins = c[Nutrient.Vitamins] / VITAMIN_KCAL,
		salts = c[Nutrient.Electrolytes] / SALT_KCAL,
	}
}

// One piece of this out of the sack.
piece_meal :: proc(item: Item) -> Meal {
	return item_meal(item, sack_piece_kcal(item))
}

// How many kg are in a store now.
store_kg :: proc(n: Need) -> f32 {
	return g.prosio.need[n] * STORE_KG[n] / 100
}

// Puts this many kg into a store (or takes them out), and says how many
// would not fit.
store_add :: proc(n: Need, kg: f32) -> (over: f32) {
	room := STORE_KG[n]
	have := store_kg(n) + kg
	over = max(have - room, 0)
	g.prosio.need[n] = clamp(have, 0, room) / room * 100
	return
}

// He has eaten this: each part of it goes to the same part of him.
eat :: proc(m: Meal) {
	p := &g.prosio
	fat_add(m.fat)
	fat_add(store_add(.Carbs, m.carbs)) // what his carbs cannot hold turns to fat
	store_add(.Protein, m.protein) // spare protein passes through him, as spare fibre does
	store_add(.Fibre, m.fibre)
	for points, n in ([Need]f32{.Carbs = 0, .Protein = 0, .Fibre = 0, .Water = 0, .Vitamins = m.vitamins, .Electrolytes = m.salts}) {
		gain := points
		if gain > 0 && p.need[n] > NEED_START {
			// The fuller he is of it, the less of it he takes in.
			gain *= (100 - p.need[n]) / (100 - NEED_START)
		}
		p.need[n] = clamp(p.need[n] + gain, 0, 100)
	}
	train(.Gut, GUT_WORK * m.fibre)
}

// The share of a thing's weight that is water: from its row in MIXABLE
// (less what is not eaten of it), or for a dish or wheat from ITEM_WATER.
item_water :: proc(item: Item) -> f32 {
	for m in MIXABLE {
		if m.in_sack && m.item == item && m.unit != .Pinch {
			return m.water * (1 - m.waste)
		}
	}
	return ITEM_WATER[item]
}

// The room a piece of this takes in his stomach, in litres.
stomach_room :: proc(item: Item) -> f32 {
	return ITEM_KG[item] * STOMACH_K
}

// Full: he cannot eat anything more until some of it has gone on.
stomach_full :: proc() -> bool {
	return g.prosio.stomach >= STOMACH_HOLDS * STOMACH_FULL
}

// He has swallowed a piece of this: it takes room in his stomach, and the
// water in it waters him.
swallow :: proc(item: Item) {
	p := &g.prosio
	p.stomach += stomach_room(item)
	store_add(.Water, ITEM_KG[item] * item_water(item))
}

// Weight burned, as energy. Muscle work (carbs_first: his muscles keeping
// going, sprinting, jumping, fighting) takes carbs first, and fat only when
// they are gone; anything else takes carbs in proportion to how full they
// are, and the rest off his fat. With his fat gone, the rest comes out of
// whatever carbs he has; with both gone there is nothing left to burn (and
// he faints: see update_prosio). Fights and knocks are the dearest; see the
// *_BURN numbers in prosio.odin. Full of protein, his body is busy building
// and burns more of everything.
burn :: proc(kg: f32, why: Burn_For, carbs_first := false) {
	p := &g.prosio
	cost := kg * (full_of(.Protein) ? BULK_BURN : 1)
	share := carbs_first ? 1 : p.need[.Carbs] / 100
	from_carbs := min(cost * share, store_kg(.Carbs))
	store_add(.Carbs, -from_carbs)
	cost -= from_carbs
	from_fat := min(cost, max(p.fat, 0))
	fat_add(-from_fat)
	cost -= from_fat
	last := min(cost, store_kg(.Carbs))
	store_add(.Carbs, -last)
	g.burned[why] += f64(from_carbs + from_fat + last)
}

// Adds to his fat (or takes from it), keeping what rounding leaves out for
// next time. A frame's burning is a few hundred-thousandths of a kilogram,
// smaller than the steps a number the size of his fat can take: without
// this his fat would come off a few per cent too fast or too slow,
// depending on how much of it there is.
fat_add :: proc(kg: f32) {
	p := &g.prosio
	want := kg + p.fat_carry
	was := p.fat
	p.fat = was + want
	p.fat_carry = want - (p.fat - was)
}

// What the burning was for. The kilograms that went on each are added up
// in g.burned as the game goes on, for the testing tools: they report where
// his weight went.
Burn_For :: enum {
	Muscle, // keeping his muscle, whatever he does
	Walking,
	Sprinting,
	Jumping,
	Gathering,
	Fighting, // bumps, grabs, bashes and throws
}

// What he has left to burn: his fat and his carbs.
energy_kg :: proc() -> f32 {
	return max(g.prosio.fat, 0) + store_kg(.Carbs)
}

// Nearly out of anything to burn: next to no fat, and few carbs.
starving :: proc() -> bool {
	return g.prosio.fat < FAT_DANGER && lacks(.Carbs)
}

// What his stores weigh, all together.
stores_kg :: proc() -> (sum: f32) {
	for n in Need {
		sum += store_kg(n)
	}
	return
}

Need_State :: enum {
	Fine,
	Low,
	Empty, // run right out
	High,
	Over, // too much
}

need_state :: proc(n: Need) -> Need_State {
	v := g.prosio.need[n]
	if n == .Water {
		return v <= 0 ? .Empty : (v < WATER_LOW ? .Low : .Fine)
	}
	switch {
	case v < NEED_EMPTY:
		return .Empty
	case v < NEED_LOW:
		return .Low
	case v > NEED_OVER:
		return .Over
	case v > NEED_HIGH:
		return .High
	}
	return .Fine
}

too_much :: proc(n: Need) -> bool {
	return need_state(n) == .Over
}

lacks :: proc(n: Need) -> bool {
	s := need_state(n)
	return s == .Low || s == .Empty
}

full_of :: proc(n: Need) -> bool {
	s := need_state(n)
	return s == .High || s == .Over
}



// What he says as a level changes, if anything.
state_text :: proc(n: Need, s: Need_State) -> cstring {
	switch s {
	case .Low:
		return TEXT.say_low[n]
	case .Empty:
		return TEXT.say_empty[n]
	case .High:
		return TEXT.say_high[n]
	case .Over:
		return TEXT.say_over[n]
	case .Fine:
	}
	return nil
}

// How the game ends when he has run right out of something for too long
// (the words are TEXT.ending).
Ending :: struct {
	title, line: cstring,
}

ending :: proc() -> Ending {
	return TEXT.ending[g.prosio.fail_need]
}

// How much faster or slower his diet makes him walk.
diet_speed :: proc() -> f32 {
	p := &g.prosio
	k: f32 = 1
	if p.crash_t > 0 {
		k = CRASH_SPEED
	} else if p.rush {
		k = RUSH_SPEED
	}
	return k
}

// How much longer a swing or a stoop takes: too much protein makes him stiff.
stiffness :: proc() -> f32 {
	return too_much(.Protein) ? STIFF : 1
}

// How far he sees, as a share of the usual, and how far back the camera sits.
sight :: proc() -> f32 {
	return full_of(.Vitamins) ? EAGLE_SIGHT : (lacks(.Vitamins) ? DIM_SIGHT : 1)
}

view_zoom :: proc() -> f32 {
	return full_of(.Vitamins) ? EAGLE_ZOOM : (lacks(.Vitamins) ? DIM_ZOOM : 1)
}

// Goats would sooner lick a salty pig than butt him.
salty :: proc() -> bool {
	return full_of(.Electrolytes) && g.prosio.fail == .None
}

update_diet :: proc(dt: f32) {
	p := &g.prosio
	// At rest everything is slowly used up; too much of anything moves on
	// faster. Protein goes on mending him (it is burned, for his muscle);
	// fibre, vitamins and electrolytes pass out of him. Carbs are not used up here: his muscles burn them (see
	// update_body), unless there are too many, when the surplus turns to fat.
	for n in Need {
		if n == .Water || (n == .Carbs && !too_much(n)) {
			continue
		}
		used := p.need[n] * (too_much(n) ? SHED : NEED_FADE) * dt
		kg := used * STORE_KG[n] / 100
		surplus := too_much(n)
		p.need[n] -= used
		#partial switch n {
		case .Carbs:
			if surplus {
				fat_add(kg)
			}
		case .Protein:
			g.burned[.Muscle] += f64(kg)
		}
	}
	thirst := THIRST
	if p.sprinting {
		thirst *= 2
	}
	if too_much(.Electrolytes) {
		thirst *= PARCHED_THIRST
	} else if full_of(.Electrolytes) {
		thirst *= SALTY_THIRST
	}
	p.need[.Water] = max(p.need[.Water] - thirst * dt, 0)
	// His stomach empties at a steady pace.
	p.stomach = max(p.stomach - STOMACH_HOLDS / STOMACH_EMPTIES * dt, 0)

	for n in Need {
		state := need_state(n)
		if state != p.need_was[n] {
			if text := state_text(n, state); text != nil {
				say(text, 2.6)
			}
			p.need_was[n] = state
		}
		// Only having run right out of water, vitamins or electrolytes is
		// dangerous.
		if state == .Empty && DEADLY[n] {
			p.extreme_t[n] += dt
			if p.extreme_t[n] >= TOO_LONG && p.fail == .None {
				p.fail = .Diet
				p.fail_need = n
			}
		} else {
			p.extreme_t[n] = max(p.extreme_t[n] - 2 * dt, 0)
		}
	}

	// Sugar: a rush while he is full of it, and a crash when it wears off.
	rush := full_of(.Carbs)
	if p.rush && !rush {
		p.crash_t = CRASH_TIME
		say(TEXT.sugar_crash, 2.4)
	}
	p.rush = rush
	p.crash_t -= dt
	if p.rush && length2(p.vel) > 2 {
		p.dust_t -= dt
		if p.dust_t <= 0 {
			p.dust_t = 0.08
			spawn_particle({p.pos.x, p.height + random_range(0.4, 1.4), p.pos.y}, {0, 0.6, 0}, 0.35, 0.07, COLOR_STAR, 0)
		}
	}

	// Too much sugar: hiccups, each a little jump he did not mean to make.
	grounded := !p.airborne
	if too_much(.Carbs) && grounded && p.carry == .Nothing {
		p.hiccup_t -= dt
		if p.hiccup_t <= 0 {
			p.hiccup_t = random_range(HICCUP_EVERY.x, HICCUP_EVERY.y)
			start_hiccup()
		}
	}

	// Fibre: wind when he is full of it, tummy aches when he lacks it.
	p.ache_t -= dt
	// With a trained gut he holds it in until G is pressed; but too much
	// fibre is a storm nobody could hold.
	trained := p.trait[.Gut] >= GUT_CONTROL && !too_much(.Fibre)
	if full_of(.Fibre) && grounded {
		p.gas_t -= dt
		if p.gas_t <= 0 && (!trained || pressed(.Gas)) {
			pass_gas()
		}
	} else if pressed(.Gas) && !full_of(.Fibre) {
		answer(TEXT.no_fibre)
	}
	if lacks(.Fibre) {
		p.ache_cd -= dt
		if p.ache_cd <= 0 && grounded && p.carry == .Nothing {
			p.ache_cd = random_range(ACHE_EVERY.x, ACHE_EVERY.y)
			p.ache_t = ACHE_TIME
			say(TEXT.tummy, 1.2)
		}
	} else {
		p.ache_cd = ACHE_EVERY.x
	}

	// Electrolytes: without them a sprint ends in a cramp.
	if lacks(.Electrolytes) && p.sprinting {
		p.cramp_t += dt
		if p.cramp_t > CRAMP_AFTER {
			p.cramp_t = 0
			p.ache_t = ACHE_TIME
			p.vel *= 0.3
			say(TEXT.cramp, 1.2)
		}
	} else {
		p.cramp_t = max(p.cramp_t - dt, 0)
	}
}

start_hiccup :: proc() {
	p := &g.prosio
	a := random_range(0, math.TAU)
	p.vel += Vec2{math.cos(a), math.sin(a)} * 2.5
	p.vy = 3.5
	p.airborne = true
	p.peak = p.height
	p.stretch_vel += 4
	p.hiccup_pose_t = PROSIO_REACTION_TIME.y
	say(TEXT.hic, 0.5)
}

// A mighty wind: a green cloud behind him, a little hop forwards, and every
// animal near enough takes to its heels.
pass_gas :: proc() {
	p := &g.prosio
	p.gas_pose_t = PROSIO_REACTION_TIME.x
	if too_much(.Fibre) {
		p.gas_t = random_range(GAS_STORM.x, GAS_STORM.y)
		p.need[.Fibre] -= GAS_COST * 2
	} else {
		p.gas_t = p.trait[.Gut] >= GUT_CONTROL ? GUT_HOLD : random_range(GAS_EVERY.x, GAS_EVERY.y)
		p.need[.Fibre] -= GAS_COST
	}
	forward := facing_dir(p.facing)
	behind := p.pos - forward * prosio_radius(p.kg)
	for _ in 0 ..< 12 {
		a := random_range(0, math.TAU)
		vel := Vec3{-forward.x * 2 + math.cos(a), random_range(0.3, 1.1), -forward.y * 2 + math.sin(a)}
		spawn_particle({behind.x, p.height + 0.6, behind.y}, vel, random_range(0.9, 1.6), random_range(0.24, 0.4), GAS_GREEN, -0.4)
	}
	p.vel += forward * 2.5
	p.stretch_vel += 3
	p.wobble_vel += 3
	g.shake = max(g.shake, 0.15)
	say(TEXT.wind, 0.9)
	for &e in g.enemies[:g.enemy_count] {
		if on_ground(&e) && length2(e.pos - p.pos) < gas_reach() {
			e.scared_t = GAS_SCARE
			drop_loot(&e) // a fox lets go of what it stole
		}
	}
	for &c in g.pests {
		if length2(c.pos - p.pos) < gas_reach() {
			scare_pest(&c)
		}
	}
	calm_bees()
}

// E at the pond: a long drink.
drink :: proc() {
	p := &g.prosio
	to := POND - p.pos
	p.facing = math.atan2(to.x, to.y)
	// A good drink washes out whatever fibre, vitamins or electrolytes there
	// are too much of. (Too many carbs or too much protein move on by
	// themselves: see update_diet.)
	washed := false
	for n in ([?]Need{.Fibre, .Vitamins, .Electrolytes}) {
		if too_much(n) {
			p.need[n] = NEED_OVER - 8
			washed = true
		}
	}
	salt_before := p.need[.Electrolytes]
	if p.need[.Water] > 95 && !washed && !full_of(.Electrolytes) {
		answer(TEXT.not_thirsty)
		return
	}
	// Water washes some salt out of him too (enough that the goats lose
	// interest), but never so much that he is short of it.
	if p.need[.Electrolytes] > DRINK_SALT_FLOOR {
		p.need[.Electrolytes] = max(p.need[.Electrolytes] - DRINK_SALT, DRINK_SALT_FLOOR)
		washed ||= salt_before > NEED_HIGH
	}
	p.need[.Water] = 100
	p.pick_t = DRINK_TIME
	p.pick_total = DRINK_TIME
	p.drinking = true
	p.vel = {}
	say(washed ? TEXT.drink_washed : TEXT.drink, 1.8)
	at := p.pos + normalize2(to) * (prosio_radius(p.kg) + 0.5)
	burst({at.x, 0.2, at.y}, 10, 2, POND_SPLASH, 0.07)
}

// The parts his weight is made of, each with its own colour wherever it is
// shown.
Part :: enum {
	Fat,
	Muscle,
	Carbs,
	Protein,
	Fibre,
	Water,
	Frame,
}
PART_NEED := #partial [Part]Need {
	.Carbs   = .Carbs,
	.Protein = .Protein,
	.Fibre   = .Fibre,
	.Water   = .Water,
}

part_kg :: proc(part: Part) -> f32 {
	switch part {
	case .Fat:
		return g.prosio.fat
	case .Muscle:
		return muscle_kg(.Arms) + muscle_kg(.Legs)
	case .Frame:
		return FRAME
	case .Carbs, .Protein, .Fibre, .Water:
		return store_kg(PART_NEED[part])
	}
	return 0
}

// What he weighs: his parts, added up. This is the only place his weight
// comes from.
body_kg :: proc() -> (sum: f32) {
	for part in Part {
		sum += part_kg(part)
	}
	return
}

// Kilograms are shown to a tenth. So that what is shown always adds up, his
// weight is shown as the sum of his parts as they are shown.
tenths :: proc(kg: f32) -> i32 {
	return i32(math.round(kg * 10))
}

kg_text :: proc(kg: f32) -> cstring {
	return fill(TEXT.kg, {"kg", Decimal{int(tenths(kg)), 1}})
}

// A text with his whole weight in it, as {kg}.
weight_text :: proc(format: cstring) -> cstring {
	sum: i32
	for part in Part {
		sum += tenths(part_kg(part))
	}
	return fill(format, {"kg", Decimal{int(sum), 1}})
}

// His weight as its parts laid end to end, each in its own colour.
draw_weight_stack :: proc(x, y, w, h, s: f32) {
	ui_rect(x - 2 * s, y - 2 * s, w + 4 * s, h + 4 * s, UI_DARK)
	ui_rect(x, y, w, h, {70, 76, 84, 255})
	at := x
	for part in Part {
		wide := w * part_kg(part) / WEIGHT_SCALE
		ui_rect(at, y, min(wide, x + w - at), h, PART_COLOR[part])
		at += wide
	}
}

draw_body_panel :: proc(x, y, s: f32) -> (width, height: f32) {
	p := &g.prosio
	pad := 10 * s
	icon := HUD_ICON * s
	gap := 12 * s
	bar_h := 6 * s
	width = 6 * icon + 5 * gap
	weight_y := y + icon + 5 * s + bar_h + 12 * s
	stamina_y := weight_y + 22 * s
	stomach_y := stamina_y + 22 * s
	height = stomach_y + 14 * s - y
	ui_round_rect(x - pad, y - pad, width + 2 * pad, height + 2 * pad, UI_PANEL, 0.15)
	blink := math.mod(g.time, 0.6) < 0.3
	for n, k in HUD_NEEDS {
		ix := x + f32(k) * (icon + gap)
		state := need_state(n)
		bar := NEED_BAR[n]
		#partial switch state {
		case .Low:
			bar = UI_ORANGE
		case .Empty:
			bar = UI_RED
		case .Over:
			bar = NEED_SILLY
		}
		if state == .Empty || (state == .Low && blink) {
			ui_round_rect(ix - 4 * s, y - 4 * s, icon + 8 * s, icon + 8 * s, bar, 0.3)
		}
		draw_pixels(NEED_ICONS[n], ix, y, icon)
		by := y + icon + 5 * s
		ui_rect(ix, by, icon, bar_h, UI_DARK)
		ui_rect(ix + 1 * s, by + 1 * s, (icon - 2 * s) * clamp(p.need[n] / 100, 0, 1), bar_h - 2 * s, bar)
	}

	// His weight: where his fat puts him among the bands, with a white mark,
	// and at the end of it his weight in kilograms (room kept for the most
	// he can weigh, so the bar does not jump as the number grows).
	draw_pixels(SCALE_ICON, x, weight_y - 2 * s, 16 * s)
	kg_size := 14 * s
	kg_w := ui_text_width(fill(TEXT.kg_whole, {"kg", 188}), kg_size)
	kg := fill(TEXT.kg_whole, {"kg", int(math.round(p.kg))})
	label(kg, x + width - ui_text_width(kg, kg_size), weight_y - 1 * s, kg_size, UI_WHITE)
	bar_x := x + 22 * s
	bar_w := width - 22 * s - 24 * s - kg_w - 4 * s // (room at the end for the heart, and the number)
	for band in WEIGHT_BANDS {
		from := bar_x + bar_w * band.from / FAT_MAX
		to := bar_x + bar_w * band.to / FAT_MAX
		ui_rect(from, weight_y, to - from, 12 * s, band.color)
	}
	mark := bar_x + bar_w * clamp(p.fat / FAT_MAX, 0, 1)
	ui_rect(mark - 3 * s, weight_y - 3 * s, 6 * s, 18 * s, UI_DARK)
	ui_rect(mark - 1.5 * s, weight_y - 1.5 * s, 3 * s, 15 * s, UI_WHITE)
	if (p.fat > FAT_MAX - FAT_DANGER || starving()) && blink {
		draw_pixels(HEART_ICON, bar_x + bar_w + 3 * s, weight_y - 3 * s, 18 * s)
	}

	// Stamina, with his bruises taking the top off it.
	draw_pixels(BOLT_ICON, x, stamina_y - 2 * s, 16 * s)
	bar_w = width - 22 * s
	ui_rect(bar_x, stamina_y, bar_w, 12 * s, UI_DARK)
	ui_rect(bar_x + 2 * s, stamina_y + 2 * s, (bar_w - 4 * s) * clamp(p.stamina / STAMINA_MAX, 0, 1), 8 * s, (p.winded || p.stamina < 25) ? UI_RED : UI_BLUE)
	if p.bruises > 0.5 {
		bw := (bar_w - 4 * s) * clamp(p.bruises / STAMINA_MAX, 0, 1)
		ui_rect(bar_x + bar_w - 2 * s - bw, stamina_y + 2 * s, bw, 8 * s, UI_BRUISE)
	}

	// How full his stomach is: when the bar is full he cannot eat more.
	draw_pixels(STOMACH_ICON, x, stomach_y - 2 * s, 16 * s)
	ui_rect(bar_x, stomach_y, bar_w, 12 * s, UI_DARK)
	ui_rect(bar_x + 2 * s, stomach_y + 2 * s, (bar_w - 4 * s) * clamp(p.stomach / STOMACH_HOLDS, 0, 1), 8 * s, stomach_full() ? UI_ORANGE : STOMACH_BAR)
	return
}

STOMACH_BAR :: Color{204, 142, 82, 255}

// The bands of the weight bar, by his fat (kg, out of FAT_MAX): starving at
// the thin end, lean, chubby, huge, and too fat for his heart.
Weight_Band :: struct {
	from, to: f32,
	color:    Color,
}

// Pictures for his needs on the screen, a letter a pixel (see icon_color):
// a food group each, so a child sees what to eat: a slice of cake for energy
// (sweet things and bread), a steak for protein (meat, fish, eggs), a leaf
// for greens, an orange for vitamins (fruit), a salt shaker, a drop of water.
NEED_ICONS := [Need][12]string {
	.Carbs = { // a slice of cake: sweet things, bread, energy
		"............",
		"........kk..",
		".......krrk.",
		"......kkRrk.",
		"....kkwwkk..",
		"..kkwwwwwwk.",
		"kkwwwwwwwwwk",
		"kttttttttttk",
		"kmmmmmmmmmmk",
		"kttttttttttk",
		"kTTTTTTTTTTk",
		".kkkkkkkkkk.",
	},
	.Protein = { // a steak, with its fat and bone: meat, fish, eggs
		"...kkkk.....",
		"..kaaaakk...",
		".kaaaaAaak..",
		"kaAaAaaacak.",
		"kcaAaAacack.",
		"kfcaAaaacaak",
		"kFfcaaaaaack",
		".kFfccccccFk",
		"..kFffffFFFk",
		"...kFFFFFFk.",
		"....kkkkkk..",
		"............",
	},
	.Fibre = {
		"........kkkk",
		"......kkggGk",
		"....kkggglGk",
		"...kggggglk.",
		"..kgggglggk.",
		"..kgggGlggk.",
		"..kggGlgggk.",
		"..kgGlgggk..",
		"..kGlggkk...",
		".kkkkkk.....",
		"kG..........",
		"k...........",
	},
	.Vitamins = { // an orange: fruit and berries
		"......kk....",
		".....kGgk...",
		"....kkGkk...",
		"..kkooookk..",
		".kooywoooOk.",
		"kooywoooooOk",
		"koooooooooOk",
		"koooooooooOk",
		"kOoooooooOOk",
		".kOOooooOOk.",
		"..kkOOOOkk..",
		"....kkkk....",
	},
	.Electrolytes = { // a salt shaker, salt coming out
		"..w..w...w..",
		"....w..w....",
		"...kkkkkk...",
		"..keekeekk..",
		"..keeeeeek..",
		"..kkkkkkkk..",
		"..kwwwwwck..",
		"..kwwwwwck..",
		"..kwwwwwck..",
		"..kwwwwwck..",
		"..kwwwwcck..",
		"..kkkkkkkk..",
	},
	.Water = {
		".....kk.....",
		".....kk.....",
		"....kuuk....",
		"....kuuk....",
		"...kuuuuk...",
		"..kuwuuuuk..",
		"..kuwuuuuk..",
		".kuwuuuuuuk.",
		".kuuuuuuuuk.",
		".kuuuuuuuuk.",
		"..kuuuuuuk..",
		"...kkkkkk...",
	},
}

// Weight: a weight with a handle, "kg" on it. Stamina: a lightning bolt. In danger at
// either end of the weight bar: a heart.
SCALE_ICON := [12]string {
	"....kkkk....",
	"...kEEEEk...",
	"...kEkkEk...",
	"..kkkkkkkk..",
	"..kEeeeeEk..",
	".kEeeeeeeEk.",
	".kEewewweEk.",
	".kEeweweeEk.",
	"kEeeweweeeEk",
	"kEeeeeeeeeEk",
	"kEEEEEEEEEEk",
	".kkkkkkkkkk.",
}
// A bowl of food: how full his stomach is.
STOMACH_ICON := [12]string {
	"............",
	"............",
	"............",
	".kkkkkkkkkk.",
	".kttttttttk.",
	"kbbbbbbbbbbk",
	"kbnnnnnnnnbk",
	".kbnnnnnnbk.",
	"..kbbbbbbk..",
	"...kkkkkk...",
	"....kkkk....",
	"............",
}
BOLT_ICON := [12]string {
	"......kkkk..",
	".....kyyyk..",
	"....kyyyk...",
	"...kyyyk....",
	"..kyyyykkkk.",
	".kyyyyyyyyk.",
	".kkkkyyyyk..",
	"....kyyyk...",
	"...kyyyk....",
	"..kyyk......",
	".kyk........",
	".kk.........",
}
HEART_ICON := [12]string {
	"............",
	".kkk...kkk..",
	"kRrrk.krrrk.",
	"kRrwrkrrrrk.",
	"kRrrrrrrrrk.",
	"kRrrrrrrrrk.",
	".kRrrrrrrk..",
	"..kRrrrrk...",
	"...kRrrk....",
	"....kRk.....",
	".....k......",
	"............",
}
