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
// Food is made of the same stuff. A piece's calories are its carbs, fat and
// protein (KCAL_PER_KG to the kilogram); it may hold fibre and water too.
// Eating puts each into the part of him that is the same thing:
//
//   carbs    into his carbs; what will not fit turns to fat
//   fat      straight onto his fat
//   protein  into his protein; what will not fit turns to carbs
//   fibre and water into his; what will not fit passes through
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

NEED_NAME := [Need]cstring {
	.Carbs        = "CARBS",
	.Protein      = "PROTEIN",
	.Fibre        = "FIBRE",
	.Water        = "WATER",
	.Vitamins     = "VITAMINS",
	.Electrolytes = "ELECTROLYTES",
}

FRAME :: f32(12.5) // kg of him that never change: bones, and the rest
// What each store weighs when it is full, in kg. (Vitamins and electrolytes
// weigh nothing.)
STORE_KG := [Need]f32 {
	.Carbs        = 6,
	.Protein      = 3,
	.Fibre        = 2,
	.Water        = 5,
	.Vitamins     = 0,
	.Electrolytes = 0,
}
// Having run right out of these ends the game, if it lasts.
DEADLY := [Need]bool {
	.Carbs        = false,
	.Protein      = false,
	.Fibre        = false,
	.Water        = true,
	.Vitamins     = true,
	.Electrolytes = true,
}

NEED_START :: f32(50)
WATER_START :: f32(80)
NEED_EMPTY :: f32(4) // below this he has run out
NEED_LOW :: f32(15) // below this he lacks it
NEED_HIGH :: f32(70) // above this he is full of it
NEED_OVER :: f32(90) // above this it is too much
WATER_LOW :: f32(25)
NEED_FADE :: f32(0.001) // the share of each level used up every second, at rest: half of it in 11 minutes
SHED :: f32(6) // above NEED_OVER it moves on this many times as fast
THIRST :: f32(0.1) // water level used up every second: a full drink lasts a good quarter of an hour
TOO_LONG :: f32(180) // seconds without water, vitamins or electrolytes before the game is over

// What full and lacking do, in numbers.
RUSH_SPEED :: f32(1.25) // sugar rush: how much faster he walks and runs,
RUSH_DRAIN :: f32(0.3) // and the share of the usual stamina a sprint costs
CRASH_TIME :: f32(8) // seconds of sugar crash when the rush wears off,
CRASH_SPEED :: f32(0.6) // and how slow he is meanwhile
NO_FUEL :: f32(0.5) // lacking carbs: the share of his stamina that comes back
GAS_EVERY :: Vec2{5, 8} // seconds between his winds
GAS_REACH :: f32(7.5) // animals this near run from it,
GAS_SCARE :: f32(5) // for this long
GAS_COST :: f32(1.5) // the fibre level each one lets out
ACHE_EVERY :: Vec2{10, 16} // seconds between tummy aches,
ACHE_TIME :: f32(1) // and how long one stops him
EAGLE_SIGHT :: f32(1.8) // eagle eyes: how much further he sees,
EAGLE_ZOOM :: f32(1.3) // and how far the camera pulls back
DIM_SIGHT :: f32(0.6)
DIM_ZOOM :: f32(0.85)
SALTY_THIRST :: f32(2.5) // salty: how much faster he gets thirsty
LICK :: f32(0.25) // electrolytes the goats lick off him each second
CRAMP_AFTER :: f32(2.5) // lacking electrolytes: seconds of sprinting that bring on a cramp,
CRAMP_JUMP :: f32(0.6) // and the share of his jump he still has
BULK_BURN :: f32(1.4) // full of protein: how much more everything burns (how much faster muscle builds is BULK in body.odin)
THIRSTY_STAMINA :: f32(50) // thirsty: his stamina only comes back this far
DRINK_TIME :: f32(0.9)
// Too much of each:
HICCUP_EVERY :: Vec2{1.5, 3.5} // seconds between hiccups
GAS_STORM :: Vec2{1.2, 2.5} // seconds between winds in a gas storm, each letting out twice the fibre
GLOW_NOTICE :: f32(1.5) // glowing: how much further off the turkeys spot him
PARCHED_THIRST :: f32(5) // parched: how much faster his water goes
STIFF :: f32(1.6) // stiff: how much longer a swing or a stoop takes

// What each raw food is made of. Its calories (RAW_KCAL in kitchen.odin)
// are shared between carbs, fat and protein as the first three say (they
// add up to 1); then the fibre and water in one full-grown piece, in kg, and
// its vitamins and electrolytes, in points of those levels.
Stuff :: struct {
	carbs, fat, protein: f32,
	fibre, water:        f32,
	vitamins, salts:     f32,
}
STUFF := #partial [Item]Stuff {
	.Apple    = {1, 0, 0, 0.08, 0.2, 6, 1},
	.Berries  = {1, 0, 0, 0.04, 0.15, 9, 0},
	.Mushroom = {0.35, 0, 0.65, 0.06, 0.05, 2, 4},
	.Pumpkin  = {0.9, 0, 0.1, 0.2, 0.3, 12, 6},
	.Cabbage  = {0.8, 0, 0.2, 0.7, 0.25, 12, 4},
	.Nuts     = {0.05, 0.75, 0.2, 0.06, 0, 0, 1},
	.Wheat    = {0.85, 0.03, 0.12, 0.08, 0, 0, 0},
	.Egg      = {0, 0.55, 0.45, 0, 0, 3, 1},
	.Flour    = {0.85, 0.03, 0.12, 0.08, 0, 0, 0},
	.Salt     = {0, 0, 0, 0, -0.75, 0, 30}, // salt makes him thirsty
	.Fish     = {0, 0.3, 0.7, 0, 0, 3, 3},
	.Meat     = {0, 0.4, 0.6, 0, 0, 1, 2},
	.Milk     = {0.25, 0.45, 0.3, 0, 0.5, 2, 3},
	.Honey    = {1, 0, 0, 0, 0, 1, 1},
	// The churn changes what milk is, so these two are given outright:
	.Butter   = {0, 1, 0, 0, 0, 2, 1},
	.Cheese   = {0, 0.55, 0.45, 0, 0, 2, 9},
}

// What a piece of food puts into him: kg of each part, and points of the
// two weightless needs.
Meal :: struct {
	carbs, fat, protein, fibre, water: f32,
	vitamins, salts:                   f32,
}

// What it weighs going in (less than nothing, for salt: it takes water out
// of him).
meal_kg :: proc(m: Meal) -> f32 {
	return m.carbs + m.fat + m.protein + m.fibre + m.water
}

// A piece of this holding this many calories. A raw thing's calories are
// shared out as STUFF says; a dish is the sum of what went into it, with the
// calories cooking added shared out the same way.
item_meal :: proc(item: Item, kcal: f32) -> (m: Meal) {
	full := item_kcal(item)
	size := full > 0 ? kcal / full : 1 // picked small, it has less of everything
	if item < FIRST_DISH || STUFF[item] != {} {
		s := STUFF[item]
		energy := kcal / KCAL_PER_KG
		return {energy * s.carbs, energy * s.fat, energy * s.protein, s.fibre * size, s.water * size, s.vitamins * size, s.salts * size}
	}
	raw: f32
	for part in recipe_for(item).needs {
		if part.count == 0 {
			continue
		}
		piece := item_meal(part.item, RAW_KCAL[part.item])
		n := f32(part.count)
		raw += RAW_KCAL[part.item] * n
		m.carbs += piece.carbs * n
		m.fat += piece.fat * n
		m.protein += piece.protein * n
		m.fibre += piece.fibre * n * size
		m.water += piece.water * n * size
		m.vitamins += piece.vitamins * n * size
		m.salts += piece.salts * n * size
	}
	richer := raw > 0 ? kcal / raw : 1
	m.carbs *= richer
	m.fat *= richer
	m.protein *= richer
	return
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
	p.fat += m.fat
	p.fat += store_add(.Carbs, m.carbs) // what his carbs cannot hold turns to fat
	spare := store_add(.Protein, m.protein) // and spare protein to carbs
	p.fat += store_add(.Carbs, spare)
	store_add(.Fibre, m.fibre)
	store_add(.Water, m.water)
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

// Weight burned, as energy. Muscle work (carbs_first: his muscles keeping
// going, sprinting, jumping, fighting) takes carbs first, and fat only when
// they are gone; anything else takes carbs in proportion to how full they
// are, and the rest off his fat. With his fat gone, the rest comes out of
// whatever carbs he has; with both gone there is nothing left to burn (and
// he faints: see update_prosio). Fights and knocks are the dearest; see the
// *_BURN numbers in prosio.odin. Full of protein, his body is busy building
// and burns more of everything.
burn :: proc(kg: f32, carbs_first := false) {
	p := &g.prosio
	cost := kg * (full_of(.Protein) ? BULK_BURN : 1)
	share := carbs_first ? 1 : p.need[.Carbs] / 100
	from_carbs := min(cost * share, store_kg(.Carbs))
	store_add(.Carbs, -from_carbs)
	cost -= from_carbs
	from_fat := min(cost, max(p.fat, 0))
	p.fat -= from_fat
	cost -= from_fat
	store_add(.Carbs, -min(cost, store_kg(.Carbs)))
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

// What he says as a level changes: lacking, run out, full, too much.
STATE_TEXT := [Need][Need_State]cstring {
	.Carbs = {.Fine = nil, .Low = "No fuel... I need bread, honey or fruit.", .Empty = "Running on fat alone! Bread, honey or fruit!", .High = "Wheee! Sugar rush!", .Over = "Hic! Too much sugar! Hic! It's turning to fat!"},
	.Protein = {.Fine = nil, .Low = "My muscles are wasting... I need eggs, fish or meat.", .Empty = "No protein left! Eggs, fish or meat!", .High = "Full of protein! Now to build some muscle!", .Over = "Too much protein! I'm stiff as a board!"},
	.Fibre = {.Fine = nil, .Low = "Ooh, my tummy... I need cabbage or pumpkin.", .Empty = "My tummy is in knots! Cabbage, quick!", .High = "Uh oh... I feel gassy!", .Over = "Too much fibre! Stand back, everybody!"},
	.Water = {.Fine = nil, .Low = "So thirsty... the pond is up the north-west path!", .Empty = "I'm drying out! Water, now!", .High = nil, .Over = nil},
	.Vitamins = {.Fine = nil, .Low = "It's getting dim... I need berries or greens.", .Empty = "I can hardly see! Berries, quick!", .High = "I can see for miles!", .Over = "So many vitamins... I'm glowing orange!"},
	.Electrolytes = {.Fine = nil, .Low = "Cramps... I need some rock salt.", .Empty = "Everything is cramping! Salt, quick!", .High = "I'm so salty... and so thirsty!", .Over = "Too much salt! Water! WATER!"},
}

// The same, as a word or two beside the level's bar.
LOW_NAME := [Need]cstring {
	.Carbs        = "NO FUEL",
	.Protein      = "WASTING",
	.Fibre        = "TUMMY ACHE",
	.Water        = "THIRSTY",
	.Vitamins     = "DIM EYES",
	.Electrolytes = "CRAMPS",
}
HIGH_NAME := [Need]cstring {
	.Carbs        = "SUGAR RUSH",
	.Protein      = "BULKING",
	.Fibre        = "GASSY",
	.Water        = "",
	.Vitamins     = "EAGLE EYES",
	.Electrolytes = "SALTY",
}
TOO_MUCH_NAME := [Need]cstring {
	.Carbs        = "HICCUPS",
	.Protein      = "STIFF",
	.Fibre        = "GAS STORM",
	.Water        = "",
	.Vitamins     = "GLOWING",
	.Electrolytes = "PARCHED",
}
// What to eat for more of each: shown when he lacks it.
NEED_EAT := [Need]cstring {
	.Carbs        = "bread, honey, fruit, pumpkin",
	.Protein      = "eggs, fish, meat, nuts",
	.Fibre        = "cabbage, pumpkin, apples",
	.Water        = "a drink at the pond",
	.Vitamins     = "berries, cabbage, pumpkin",
	.Electrolytes = "rock salt, cheese, mushrooms",
}

// How the game ends when he has run right out of something for too long.
Ending :: struct {
	title, line: cstring,
}
ENDINGS := [Need]Ending {
	.Carbs        = {},
	.Protein      = {},
	.Fibre        = {},
	.Water        = {"DRIED OUT!", "He needed a drink from the pond."},
	.Vitamins     = {"NO VITAMINS!", "Everything went dark. He needed fruit and greens."},
	.Electrolytes = {"CRAMPED UP!", "With no salt every muscle seized up."},
}

ending :: proc() -> Ending {
	return ENDINGS[g.prosio.fail_need]
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
	// faster. Protein turns to carbs; fibre, vitamins and electrolytes pass
	// out of him. Carbs are not used up here: his muscles burn them (see
	// update_body), unless there are too many, when the surplus turns to fat.
	for n in Need {
		if n == .Water || (n == .Carbs && !too_much(n)) {
			continue
		}
		used := p.need[n] * NEED_FADE * (too_much(n) ? SHED : 1) * dt
		kg := used * STORE_KG[n] / 100
		surplus := too_much(n)
		p.need[n] -= used
		#partial switch n {
		case .Carbs:
			if surplus {
				p.fat += kg
			}
		case .Protein:
			p.fat += store_add(.Carbs, kg)
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

	for n in Need {
		state := need_state(n)
		if state != p.need_was[n] {
			if text := STATE_TEXT[n][state]; text != nil {
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
		say("Sugar crash... so sleepy...", 2.4)
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
			a := random_range(0, math.TAU)
			p.vel += Vec2{math.cos(a), math.sin(a)} * 2.5
			p.vy = 3.5
			p.airborne = true
			p.peak = p.height
			p.stretch_vel += 4
			say("Hic!", 0.5)
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
		hint("Nothing in there... I need more fibre!")
	}
	if lacks(.Fibre) {
		p.ache_cd -= dt
		if p.ache_cd <= 0 && grounded && p.carry == .Nothing {
			p.ache_cd = random_range(ACHE_EVERY.x, ACHE_EVERY.y)
			p.ache_t = ACHE_TIME
			say("Ooh... my tummy!", 1.2)
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
			say("Ow ow ow! Cramp!", 1.2)
		}
	} else {
		p.cramp_t = max(p.cramp_t - dt, 0)
	}
}

GAS_GREEN :: Color{176, 204, 96, 255}

// A mighty wind: a green cloud behind him, a little hop forwards, and every
// animal near enough takes to its heels.
pass_gas :: proc() {
	p := &g.prosio
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
	say("PRRRRT!", 0.9)
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
	if p.need[.Water] > 95 && !washed {
		hint("I'm not thirsty!")
		return
	}
	p.need[.Water] = 100
	p.pick_t = DRINK_TIME
	p.pick_total = DRINK_TIME
	p.drinking = true
	p.vel = {}
	say(washed ? "Glug glug glug... that washed it out!" : "Glug glug glug... aah!", 1.8)
	at := p.pos + normalize2(to) * (prosio_radius(p.kg) + 0.5)
	burst({at.x, 0.2, at.y}, 10, 2, POND_SPLASH, 0.07)
}

NEED_POWER :: Color{176, 140, 250, 255}
NEED_SILLY :: Color{240, 150, 220, 255}
MUSCLE_RED :: Color{232, 110, 96, 255}

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
PART_NAME := [Part]cstring {
	.Fat     = "FAT",
	.Muscle  = "MUSCLE",
	.Carbs   = "CARBS",
	.Protein = "PROTEIN",
	.Fibre   = "FIBRE",
	.Water   = "WATER",
	.Frame   = "BONES",
}
PART_COLOR := [Part]Color {
	.Fat     = {246, 206, 70, 255},
	.Muscle  = MUSCLE_RED,
	.Carbs   = {244, 150, 60, 255},
	.Protein = {236, 150, 190, 255},
	.Fibre   = {120, 196, 96, 255},
	.Water   = {80, 170, 240, 255},
	.Frame   = {168, 168, 178, 255},
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
	return ui_format2("%d.%d kg", tenths(kg) / 10, tenths(kg) % 10)
}

weight_text :: proc(format: cstring) -> cstring {
	sum: i32
	for part in Part {
		sum += tenths(part_kg(part))
	}
	return ui_format2(format, sum / 10, sum % 10)
}

WEIGHT_SCALE :: f32(160) // the weight bar is this many kg from end to end

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

// One row of the panel: a square of the part's colour, its name, a bar in
// that colour (with ticks where its states change), what it weighs, and what
// it is doing to him.
draw_part_row :: proc(x, y, s: f32, color: Color, name: cstring, fill: f32, ticks: []f32, kg: cstring, note: cstring, note_color: Color, blink := false) {
	text := 13 * s
	bar_x, bar_w, bar_h := x + 126 * s, 90 * s, 8 * s
	ui_rect(x, y + 3 * s, 8 * s, 8 * s, color)
	label(name, x + 13 * s, y, text, blink ? UI_RED : UI_WHITE)
	ui_rect(bar_x - 1.5 * s, y + 1.5 * s, bar_w + 3 * s, bar_h + 3 * s, UI_DARK)
	ui_rect(bar_x, y + 3 * s, bar_w, bar_h, {70, 76, 84, 255})
	ui_rect(bar_x, y + 3 * s, bar_w * clamp(fill, 0, 1), bar_h, color)
	for tick in ticks {
		ui_rect(bar_x + bar_w * tick - 0.5 * s, y + 3 * s, 1 * s, bar_h, UI_DARK)
	}
	if kg != nil {
		label(kg, bar_x + bar_w + 8 * s, y, text)
	}
	if note != nil {
		label(note, bar_x + bar_w + 66 * s, y, text, note_color)
	}
}

// The panel at the top left: what he weighs, as the sum of what he is made
// of; then each part by itself with its kilograms; the two needs that weigh
// nothing; his stamina; and a line of advice when he lacks something.
// Returns how wide and how tall it is.
draw_body_panel :: proc(x, y, s: f32) -> (width, height: f32) {
	p := &g.prosio
	pad := 9 * s
	row := 17 * s
	text := 13 * s
	width = 384 * s
	height = 270 * s
	ui_round_rect(x - pad, y - pad + 2 * s, width + pad, height, UI_PANEL, 0.08)

	// The weight, and the parts it is the sum of.
	label(weight_text("WEIGHS %d.%d kg"), x, y, 17 * s)
	if p.carry == .Rock {
		// What he carries counts as his weight when he jumps and lands.
		label(ui_format("+%d", i32(p.carry_kg + 0.5)), x + 170 * s, y + 1 * s, 15 * s, UI_YELLOW)
	}
	label("= the sum of:", x + width - pad - ui_text_width("= the sum of:", text), y + 3 * s, text, {200, 200, 200, 255})
	draw_weight_stack(x, y + 24 * s, width - pad - 2 * s, 12 * s, s)
	ry := y + 46 * s

	// Fat, with where lean, chubby and huge begin, and danger at both ends.
	zone: cstring = "CHUBBY"
	zone_color := UI_YELLOW
	switch {
	case starving():
		zone, zone_color = "STARVING!", UI_RED
	case p.fat < FAT_DANGER:
		zone, zone_color = "ON CARBS ONLY", UI_ORANGE
	case p.fat < FAT_LEAN:
		zone, zone_color = "LEAN", UI_GREEN
	case p.fat > FAT_MAX - FAT_DANGER:
		zone, zone_color = "TOO FAT!", UI_RED
	case p.fat >= FAT_HUGE:
		zone, zone_color = "HUGE", UI_ORANGE
	}
	fat_ticks := [?]f32{FAT_DANGER / FAT_MAX, FAT_LEAN / FAT_MAX, FAT_HUGE / FAT_MAX, 1 - FAT_DANGER / FAT_MAX}
	draw_part_row(x, ry, s, PART_COLOR[.Fat], "FAT", p.fat / FAT_MAX, fat_ticks[:], kg_text(p.fat), zone, zone_color)
	ry += row

	// Muscle: arms and legs together, from wasted to the most they can be,
	// with a tick at the ordinary.
	least := ARMS_KG[0] + LEGS_KG[0]
	most := ARMS_KG[2] + LEGS_KG[2]
	ordinary := ARMS_KG[1] + LEGS_KG[1]
	muscle := part_kg(.Muscle)
	built: cstring = nil
	built_color := NEED_POWER
	if muscle > ordinary + 2 {
		built = "STRONG"
	} else if muscle < ordinary - 1 {
		built, built_color = "WASTED", UI_ORANGE
	}
	muscle_ticks := [?]f32{(ordinary - least) / (most - least)}
	draw_part_row(x, ry, s, PART_COLOR[.Muscle], "MUSCLE", (muscle - least) / (most - least), muscle_ticks[:], kg_text(muscle), built, built_color)
	ry += row

	// The stores and the two weightless needs: each with ticks where
	// lacking, full and too much begin.
	advice: Need
	advised, urgent, over := false, false, false
	need_ticks := [?]f32{NEED_LOW / 100, NEED_HIGH / 100, NEED_OVER / 100}
	water_ticks := [?]f32{WATER_LOW / 100}
	for n in Need {
		if n == .Vitamins {
			ry += 5 * s
			label("AND, WEIGHING NOTHING:", x, ry, 11 * s, {200, 200, 200, 255})
			ry += 14 * s
		}
		state := need_state(n)
		danger := state == .Empty && DEADLY[n]
		blink := danger && math.mod(g.time, 0.5) < 0.25
		note: cstring = nil
		note_color := UI_ORANGE
		switch state {
		case .Fine:
		case .Low, .Empty:
			note = LOW_NAME[n]
			if danger {
				// Counting down to the end.
				note = ui_format("DANGER! %d", i32(math.ceil(TOO_LONG - p.extreme_t[n])))
				note_color = blink ? UI_WHITE : UI_RED
				advice, advised, urgent = n, true, true
			} else if !advised {
				advice, advised = n, true
			}
		case .High:
			note, note_color = HIGH_NAME[n], NEED_POWER
			if n == .Fibre && p.trait[.Gut] >= GUT_CONTROL {
				note = "GASSY (G)"
			}
		case .Over:
			note, note_color = TOO_MUCH_NAME[n], NEED_SILLY
			over = true
		}
		weighs := STORE_KG[n] > 0
		color := PART_COLOR[.Water]
		#partial switch n {
		case .Carbs:
			color = PART_COLOR[.Carbs]
		case .Protein:
			color = PART_COLOR[.Protein]
		case .Fibre:
			color = PART_COLOR[.Fibre]
		case .Vitamins:
			color = {250, 230, 110, 255}
		case .Electrolytes:
			color = {236, 236, 240, 255}
		}
		draw_part_row(x, ry, s, color, NEED_NAME[n], p.need[n] / 100, n == .Water ? water_ticks[:] : need_ticks[:], weighs ? kg_text(store_kg(n)) : nil, note, note_color, blink)
		ry += row
	}

	// Stamina. The notch shows how much one bump costs right now.
	ry += 6 * s
	label("STAMINA", x, ry, text)
	bar_x, bar_w := x + 126 * s, width - pad - 128 * s
	ui_rect(bar_x - 2 * s, ry + 1 * s, bar_w + 4 * s, 10 * s + 4 * s, UI_DARK)
	ui_rect(bar_x, ry + 3 * s, bar_w * p.stamina / STAMINA_MAX, 10 * s, (p.winded || p.stamina < 25) ? UI_RED : UI_BLUE)
	ui_rect(bar_x + bar_w * dash_cost() / STAMINA_MAX - 1 * s, ry + 3 * s, 2 * s, 10 * s, UI_DARK)
	ry += 22 * s

	// What to do about it: what to eat for the thing he lacks most.
	if starving() {
		label("EAT: anything! Nothing left to burn.", x, ry, text, UI_RED)
	} else if advised {
		label(ui_format_name("EAT: %s", NEED_EAT[advice]), x, ry, text, urgent ? UI_RED : UI_ORANGE)
	} else if over {
		label("Too much? It soon passes.", x, ry, text, NEED_SILLY)
	}
	return
}
