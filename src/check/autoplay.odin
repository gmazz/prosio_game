package check

// A bot that plays the game for a long while, the way a child might: it
// wanders, picks food and wood, grabs and throws animals, stomps, eats,
// drinks, bakes and cooks, builds things at the workbench and puts them up,
// all chosen at random. It does not play well; it is there
// to go everywhere and press everything. As it plays, it watches for things
// that should never happen (see Anomaly), and keeps count of what happened,
// so that numbers worth tuning stand out. At the end it prints a report.

import game "../game"
import "core:fmt"
import "core:math"
import "core:slice"
import "core:strings"

Anomaly :: enum {
	Weight_Not_Sum, // his weight is not the sum of his parts
	Not_A_Number, // a position, speed or amount has gone to NaN
	Out_Of_Range, // stamina, a store, a trait or his fat outside its limits
	Inside_Something, // Prosio stuck inside a tree, rock or building
	Out_Of_Meadow, // Prosio or an animal beyond the fence
	Cannot_Move, // trying to walk, free to, and not getting anywhere
	F_Did_Not_Let_Go, // F with an animal in his hands, and still holding it a second later
	E_Did_Nothing, // E next to something it works on, and nothing came of it
	Hold_Mixup, // he holds an animal that is not held, or the other way round
	Animal_Inside_Something,
	Animal_Flying_Forever,
	Fox_Kept_Loot, // a fox carrying what it stole for over two minutes
	Over_Budget, // more of a food standing than its budget allows
	Through_A_Fence, // an animal on its feet went through a piece of fence
}

ANOMALY_TEXT := [Anomaly]string {
	.Weight_Not_Sum          = "his weight is not the sum of his parts",
	.Not_A_Number            = "a number went to NaN",
	.Out_Of_Range            = "a value went outside its limits",
	.Inside_Something        = "Prosio inside a tree, rock or building",
	.Out_Of_Meadow           = "something beyond the fence",
	.Cannot_Move             = "trying to walk and getting nowhere",
	.F_Did_Not_Let_Go        = "F did not let go of an animal",
	.E_Did_Nothing           = "E next to something did nothing",
	.Hold_Mixup              = "held and holding do not match",
	.Animal_Inside_Something = "an animal stuck inside a tree, rock or building",
	.Animal_Flying_Forever   = "an animal flying for over 10 s",
	.Fox_Kept_Loot           = "a fox kept stolen food for over 2 min",
	.Over_Budget             = "a food standing over its budget",
	.Through_A_Fence         = "an animal on its feet got through a fence",
}

MAX_EXAMPLES :: 4

Seen :: struct {
	count:    int,
	examples: [MAX_EXAMPLES]string,
}

Goal :: enum {
	Wander,
	Food,
	Plant, // a berry bush, hive or salt rock
	Animal,
	Station,
	Mill,
	Pond,
	Fire_Block, // taking a body to be chopped up
	Hold, // holding an animal, to bash or throw it
}

Bot :: struct {
	rng:          u32,
	goal:         Goal,
	target:       game.Vec2,
	index:        int,
	goal_t:       f32, // gives up on the goal when this runs out
	side_t:       f32, // stepping round something for this long
	side:         game.Vec2,
	last_pos:     game.Vec2,
	trying_t:     f32, // how long it has been trying to get somewhere without getting far
	release_t:    int, // frames until it checks that F let go (0: not checking)
	wind:         int, // frames it goes on holding F, winding up a throw
	release_idx:  int,
	release_grab: int, // g.grabs when F let go: more since means he took hold again
	built_t:      int, // frames until it looks whether Q put something up
	built_before: int, // how many things were standing before
	fences_before: int, // how many pieces of fence stood a frame ago
	e_t:          int, // frames until it checks that E did something
	e_before:     E_Snapshot,
	e_what:       string,
	menu_opened:  bool, // a station's menu came up since E was pressed
	e_answered:   bool, // he said something, or his sack changed, since E was pressed
	inside_t:     f32,
	animal_in_t:  [game.MAX_ENEMIES]f32,
	flying_t:     [game.MAX_ENEMIES]f32,
	loot_t:       [game.MAX_ENEMIES]f32,
	animal_was:   [game.MAX_ENEMIES]game.Vec2, // where each animal was a frame ago,
	animal_stood: [game.MAX_ENEMIES]bool, // and whether it was on its feet
	stuck_spots:  [dynamic]game.Vec2, // where Cannot_Move was reported, so each place is reported once
}

E_Snapshot :: struct {
	sack:      [game.Item]int,
	scene:     game.Scene,
	water:     f32,
	carry:     game.Carry,
	bubble_t:  f32,
	pick_t:    f32,
	baking:    [game.Station_Kind]bool,
	ready:     [game.Station_Kind]bool,
	mill:      [3]int,
}

Stats :: struct {
	frames:      int,
	state_t:     [game.Need][game.Need_State]f32,
	fails:       map[string]int,
	said:        map[string]int,
	sack_in:     [game.Item]int, // things that went into the sack
	eaten:       [game.Item]int,
	throws:      int, // animals it wound up and threw
	put_up:      int, // pieces of fence and scarecrows put up,
	taken_down:  int, // and taken down again
	most_fence:  int, // the most pieces standing at once
	most_penned: int, // the most animals penned at once
	penned_t:    f32, // animal-seconds spent penned
	most_bruised: f32,
	eaten_kg:    f32, // what the food he ate was worth, in kg of weight (its calories)
	grabs:       int,
	carried_t:   f32,
	sprint_t:    f32,
	dazed_t:     f32,
	thefts:      int,
	killed:      [game.Enemy_Kind]int,
	samples:     [dynamic][6]f32, // every 5 minutes: weight, fat, muscle, carbs, protein, stamina
	fat_low, fat_high, kg_low, kg_high: f32,
	muscle_high: f32,
	traits_high: [game.Trait]f32,
}

seen: [Anomaly]Seen
stats: Stats
bot: Bot

rand :: proc() -> f32 {
	x := bot.rng
	x ~= x << 13
	x ~= x >> 17
	x ~= x << 5
	bot.rng = x
	return f32(x % 1000000) / 1000000
}

note :: proc(kind: Anomaly, detail: string) {
	s := &seen[kind]
	if s.count < MAX_EXAMPLES {
		p := &game.g.prosio
		s.examples[s.count] = strings.clone(fmt.tprintf("at %d:%02d, Prosio at (%.1f, %.1f): %s", int(game.g.time) / 60, int(game.g.time) % 60, p.pos.x, p.pos.y, detail))
	}
	s.count += 1
}

autoplay :: proc(minutes: int, seed: int) -> bool {
	fresh(u32(seed) * 7919)
	g := &game.g
	p := &g.prosio
	bot = {rng = u32(seed) * 2654435761 + 12345}
	if bot.rng == 0 {
		bot.rng = 1
	}
	stats = {fat_low = 999, kg_low = 999}
	stats.fails = make(map[string]int)
	stats.said = make(map[string]int)
	frames := minutes * 60 * 60
	killed_before: [game.MAX_ENEMIES]bool
	loot_before: [game.MAX_ENEMIES]bool
	sack_before := p.sack
	for frame in 0 ..< frames {
		stats.frames = frame
		down, tap := decide()
		bubble_before := p.bubble_t
		text_before := p.bubble
		game.forced_down = down
		game.forced_pressed = tap
		if game.scene == .Playing {
			game.simulate(1.0 / 60)
		}
		game.forced_down = {}
		game.forced_pressed = {}
		watch()
		// Count what happened.
		// (A line just said is a different line, or leaves his bubble with
		// more time on it than the frame alone would have.)
		if p.bubble != nil && (p.bubble != text_before || p.bubble_t > bubble_before - 1.0 / 60 + 0.004) && p.bubble_t > 0 {
			stats.said[strings.clone(string(game.expand_keys(p.bubble)))] += 1
			bot.e_answered = true
		}
		for n, item in p.sack {
			if n > sack_before[item] {
				stats.sack_in[item] += n - sack_before[item]
			}
			if n != sack_before[item] {
				bot.e_answered = true
			}
		}
		sack_before = p.sack
		for &e, i in g.enemies[:g.enemy_count] {
			dead := e.state == .Dead
			if dead && !killed_before[i] {
				stats.killed[e.kind] += 1
			}
			killed_before[i] = dead
			if e.has_loot && !loot_before[i] {
				stats.thefts += 1
			}
			loot_before[i] = e.has_loot
		}
		for n in game.Need {
			stats.state_t[n][game.need_state(n)] += 1.0 / 60
		}
		penned := 0
		for &e in g.enemies[:g.enemy_count] {
			penned += e.penned && e.state == .Chase ? 1 : 0
		}
		stats.most_penned = max(stats.most_penned, penned)
		stats.penned_t += f32(penned) / 60
		stats.most_fence = max(stats.most_fence, g.fence_count)
		if p.carry != .Nothing {
			stats.carried_t += 1.0 / 60
		}
		if p.sprinting {
			stats.sprint_t += 1.0 / 60
		}
		if p.dazed_t > 0 {
			stats.dazed_t += 1.0 / 60
		}
		if p.fail == .None {
			stats.fat_low = min(stats.fat_low, p.fat)
			stats.fat_high = max(stats.fat_high, p.fat)
			stats.kg_low = min(stats.kg_low, p.kg)
			stats.kg_high = max(stats.kg_high, p.kg)
			stats.muscle_high = max(stats.muscle_high, game.part_kg(.Muscle))
			stats.most_bruised = max(stats.most_bruised, p.bruises)
			for level, t in p.trait {
				stats.traits_high[t] = max(stats.traits_high[t], level)
			}
		}
		if frame % (5 * 60 * 60) == 0 {
			append(&stats.samples, [6]f32{p.kg, p.fat, game.part_kg(.Muscle), game.store_kg(.Carbs), game.store_kg(.Protein), p.stamina})
		}
	}
	append(&stats.samples, [6]f32{p.kg, p.fat, game.part_kg(.Muscle), game.store_kg(.Carbs), game.store_kg(.Protein), p.stamina})
	return report(minutes, seed)
}

// The buttons the bot holds and presses this frame.
decide :: proc() -> (down, tap: bit_set[game.Button]) {
	g := &game.g
	p := &g.prosio
	r := game.prosio_radius(p.kg)

	// A station's menu is open: make something if it can, or close it.
	if game.scene == .Oven {
		bot.menu_opened = true
		buf: [len(game.RECIPES)]^game.Recipe
		recipes := game.station_recipes(game.cook_at, &buf)
		choice := -1
		for rec, i in recipes {
			if (rec.dish == .Rod || rec.dish == .Gate) && p.sack[rec.dish] > 0 || rec.dish == .Larder && (p.sack[.Larder] > 0 || game.larder_count() > 0) {
				continue // one rod, one gate at a time and one larder are enough
			}
			if game.max_batch(rec) > 0 && (choice < 0 || rand() < 0.5) {
				choice = i
			}
		}
		if choice >= 0 {
			game.cook_choice = choice
			game.cook_count = 1 + int(rand() * 3)
			game.forced_pressed = {.Confirm}
		} else {
			game.forced_pressed = {.Menu}
		}
		game.update_cook_menu(1.0 / 60)
		game.forced_pressed = {}
		game.scene = .Playing
		return
	}

	// A larder is open: put something in or take something out, now and
	// then all of a kind, and close it.
	if game.scene == .Larder {
		bot.menu_opened = true
		l := &g.larders[game.larder_open]
		buf: [len(game.Item)]game.Item
		rows := game.larder_rows(l, &buf)
		if len(rows) > 0 {
			game.larder_choice = int(rand() * f32(len(rows))) % len(rows)
			roll := rand()
			game.forced_pressed = roll < 0.4 ? {.Right} : (roll < 0.8 ? {.Left} : {.Confirm})
			game.update_larder_menu()
		}
		game.forced_pressed = {.Menu}
		game.update_larder_menu()
		game.forced_pressed = {}
		game.scene = .Playing
		return
	}

	// The game is over: lie there a moment, then wake up.
	if p.fail != .None {
		if p.fail_t > 0 && p.fail_t < 1.0 / 30 {
			cause := fmt.tprintf("%v", p.fail)
			if p.fail == .Diet {
				cause = fmt.tprintf("%s (out of %v)", game.ending().title, p.fail_need)
			}
			stats.fails[strings.clone(cause)] += 1
		}
		if p.fail_t > 1.5 {
			tap += {.Restart}
		}
		bot.goal_t = 0
		return
	}

	bot.goal_t -= 1.0 / 60
	can_act := p.dazed_t <= 0 && p.dash_t <= 0 && p.eat_t <= 0 && p.pick_t <= 0 && p.ache_t <= 0 && !p.airborne

	// A pebble now and then, at whatever is about.
	if can_act && p.carry == .Nothing && !p.winding && p.sack[.Pebble] > 0 && bot.wind == 0 && rand() < 0.004 {
		p.sack_sel = .Pebble
		tap += {.Grab}
		bot.wind = 5 + int(rand() * 60)
		down += {.Grab}
		return
	}

	// A spear now and then, the same way.
	if can_act && p.carry == .Nothing && !p.winding && p.sack[.Spear] > 0 && bot.wind == 0 && rand() < 0.004 {
		p.sack_sel = .Spear
		tap += {.Grab}
		bot.wind = 5 + int(rand() * 70)
		down += {.Grab}
		return
	}

	// What it has built goes up wherever it happens to be: a piece of fence
	// often joins the last one, so now and then a pen comes of it.
	if can_act && p.carry == .Nothing && !p.winding && bot.wind == 0 {
		for item in ([4]game.Item{.Fence, .Gate, .Scarecrow, .Larder}) {
			if p.sack[item] > 0 && rand() < (item == .Fence || item == .Gate ? 0.01 : 0.002) {
				standing := g.fence_count + game.scarecrow_count() + game.larder_count()
				p.sack_sel = item
				if rand() < 0.5 {
					p.facing += 1.5708 // the next piece at a corner to the last
				}
				tap += {.Eat}
				bot.built_before = standing
				bot.built_t = 3
				return
			}
		}
		// And comes down again, now and then, when it is standing at some.
		if what, _, _ := game.built_in_reach(); what != .Nothing && !game.throwable_chosen() && rand() < 0.002 {
			if _, grabbable := game.grab_target(); !grabbable && !game.pond_in_reach(p.pos, r) {
				tap += {.Grab}
				stats.taken_down += 1
				return
			}
		}
	}
	if bot.built_t > 0 {
		bot.built_t -= 1
		if bot.built_t == 0 && g.fence_count + game.scarecrow_count() + game.larder_count() > bot.built_before {
			stats.put_up += 1
		}
	}

	// Eat now and then, and always when running low.
	if can_act && p.carry == .Nothing && game.sack_has_food() && (p.fat < 30 || game.lacks(.Carbs) || rand() < 0.002) {
		buf: [len(game.Item)]game.Item
		owned := game.owned_items(&buf)
		for _ in 0 ..< 6 {
			pick := owned[int(rand() * f32(len(owned))) % len(owned)]
			if game.edible(pick) {
				p.sack_sel = pick
				stats.eaten[pick] += 1
				stats.eaten_kg += game.sack_piece_kcal(pick) / game.KCAL_PER_KG
				tap += {.Eat}
				return
			}
		}
	}

	// Holding something.
	if p.carry == .Enemy && bot.goal != .Hold && bot.goal != .Fire_Block {
		e := &g.enemies[p.carry_index]
		if e.ko && game.MEAT_FROM[e.kind] > 0 && rand() < 0.7 {
			bot.goal, bot.goal_t = .Fire_Block, 90
			bot.target = g.stations[.Fire].pos
		} else {
			bot.goal, bot.goal_t = .Hold, 0.5 + rand() * 3
		}
		stats.grabs += 1
	}
	if p.carry == .Rock && p.lift_t <= 0 && bot.wind == 0 && rand() < 0.02 {
		tap += {.Grab}
		bot.wind = rand() < 0.5 ? 0 : 15 + int(rand() * 60) // put it down, or wind up and throw
	}
	if bot.wind > 0 {
		bot.wind -= 1
		down += {.Grab}
	}

	// Holding on: the press that took hold (or a wind-up) is still down, so F
	// cannot be pressed again yet; a person would let it up first.
	still_down := bot.goal == .Hold && p.carry == .Enemy && (p.grab_spent || bot.wind > 0)
	if !still_down && (bot.goal_t <= 0 || bot.goal == .Hold && p.carry != .Enemy || bot.goal == .Fire_Block && p.carry != .Enemy) {
		if bot.goal == .Hold && p.carry == .Enemy {
			// Done holding: let go (a tap puts it down, a hold throws it),
			// and see that it did.
			tap += {.Grab}
			bot.wind = rand() < 0.4 ? 0 : 15 + int(rand() * 60)
			bot.release_t = 150 + bot.wind
			bot.release_idx = p.carry_index
			bot.release_grab = g.grabs
			stats.throws += bot.wind > 0 ? 1 : 0
		}
		choose_goal()
	}

	// Where it is going now.
	#partial switch bot.goal {
	case .Animal:
		e := &g.enemies[bot.index]
		if !game.on_ground(e) && e.state != .Dead {
			bot.goal_t = 0
		}
		bot.target = e.pos
	case .Food:
		if !game.food_ready(&g.foods[bot.index]) {
			bot.goal_t = 0
		}
	case .Hold:
		if rand() < 0.02 && !p.swinging {
			tap += {.Bump} // a bash
		}
	}

	// Walk there, stepping round whatever is in the way. It has arrived
	// when the thing is within reach (or, wandering, when it is there).
	to := bot.target - p.pos
	far := length(to)
	arrived := far < 0.8
	#partial switch bot.goal {
	case .Food:
		arrived = game.food_in_reach(p.pos, r + 0.75) != nil && far < 2.5
	case .Plant:
		arrived = game.bush_in_reach(p.pos, r + 0.6) != nil && far < 3.5
	case .Station:
		_, arrived = game.station_near(p.pos, r)
	case .Mill:
		arrived = game.mill_in_reach(p.pos, r)
	case .Pond:
		arrived = game.pond_in_reach(p.pos, r)
	case .Fire_Block:
		arrived = game.station_in_reach(.Fire, p.pos, r + 1.2)
	case .Animal:
		arrived = false
	}
	if bot.goal == .Hold {
		to = {math.cos(f32(stats.frames) * 0.01), math.sin(f32(stats.frames) * 0.013)}
		arrived = false
	}
	if !arrived {
		dir := to / max(length(to), 0.001)
		if bot.side_t > 0 {
			bot.side_t -= 1.0 / 60
			dir = bot.side
		}
		if dir.x < -0.38 {down += {.Left}}
		if dir.x > 0.38 {down += {.Right}}
		if dir.y < -0.38 {down += {.Up}}
		if dir.y > 0.38 {down += {.Down}}
		if far > 12 && p.stamina > 60 && p.carry == .Nothing {
			down += {.Sprint}
		}
		// Getting nowhere: step aside for a moment; after a few tries, give up.
		bot.trying_t += 1.0 / 60
		if bot.trying_t > 1.5 {
			if length(p.pos - bot.last_pos) < 0.5 && bot.goal != .Hold {
				bot.side = {-dir.y, dir.x} * (rand() < 0.5 ? -1 : 1)
				bot.side_t = 0.8
				if bot.goal_t > 6 {
					bot.goal_t = 6
				}
			}
			bot.trying_t = 0
			bot.last_pos = p.pos
		}
	}

	// Act when there.
	if !can_act {
		return
	}
	// (Food and plants are picked with empty hands: carrying a rock, E does
	// nothing there, and the game's prompt says to put it down or throw it.
	// The bot pressed it anyway on seed 4, and its E watch counted that.)
	switch bot.goal {
	case .Food:
		if p.carry == .Nothing && game.food_in_reach(p.pos, r + 0.75) != nil {
			press_e(&tap, "food")
		}
	case .Plant:
		if p.carry == .Nothing && game.bush_in_reach(p.pos, r + 0.6) != nil {
			press_e(&tap, "a bush, hive or salt rock")
		}
	case .Station:
		if _, near := game.station_near(p.pos, r); near && game.food_in_reach(p.pos, r + 0.75) == nil && game.bush_in_reach(p.pos, r + 0.6) == nil {
			press_e(&tap, "a station")
			bot.goal_t = min(bot.goal_t, 1)
		}
	case .Mill:
		if game.mill_in_reach(p.pos, r) && game.food_in_reach(p.pos, r + 0.75) == nil && game.bush_in_reach(p.pos, r + 0.6) == nil {
			if g.mill.grinding == 0 {
				press_e(&tap, "the mill")
				if p.sack[.Wheat] == 0 && g.mill.ready == 0 {
					bot.goal_t = min(bot.goal_t, 1) // nothing more to do here
				}
			}
		}
	case .Pond:
		if game.pond_in_reach(p.pos, r) {
			if rand() < 0.5 && p.need[.Water] < 90 {
				press_e(&tap, "the pond")
			} else if rand() < 0.02 {
				if p.sack[.Rod] > 0 && rand() < 0.7 {
					p.sack_sel = .Rod // a cast of the rod
				}
				tap += {.Grab} // a grab for a fish
			}
			bot.goal_t = min(bot.goal_t, 4)
		}
	case .Animal:
		e := &g.enemies[bot.index]
		gap := length(e.pos - p.pos) - r - game.ENEMY_RADIUS[e.kind]
		switch {
		case gap < game.GRAB_REACH * 0.8 && rand() < 0.1:
			tap += {.Grab}
		case gap < 1.5 && rand() < 0.01:
			tap += {.Jump} // a stomp
		case gap < 3 && rand() < 0.01:
			tap += {.Bump}
		}
	case .Fire_Block:
		if p.carry == .Enemy && game.station_in_reach(.Fire, p.pos, r + 1.2) {
			press_e(&tap, "the chopping block")
			bot.goal_t = 0
		}
	case .Hold, .Wander:
	}
	return
}

// E, and a check a moment later that something came of it.
press_e :: proc(tap: ^bit_set[game.Button], what: string) {
	g := &game.g
	p := &g.prosio
	if bot.e_t > 0 || p.lift_t > 0 || p.swinging {
		return // one press at a time, and not in the instant he is taking hold or swinging
	}
	tap^ += {.Action}
	bot.e_t = 40
	bot.menu_opened = false
	bot.e_answered = false
	bot.e_what = strings.clone(fmt.tprintf("%s (carrying %v, sack %v)", what, p.carry, p.sack[p.sack_sel]))
	bot.e_before = snapshot()
}

snapshot :: proc() -> E_Snapshot {
	g := &game.g
	p := &g.prosio
	s := E_Snapshot {
		sack     = p.sack,
		scene    = game.scene,
		water    = p.need[.Water],
		carry    = p.carry,
		bubble_t = p.bubble_t,
		pick_t   = p.pick_t,
		mill     = {g.mill.grinding, g.mill.ready, 0},
	}
	for st, at in g.stations {
		s.baking[at], s.ready[at] = st.baking, st.ready
	}
	return s
}

choose_goal :: proc() {
	g := &game.g
	p := &g.prosio
	bot.goal_t = 25 + rand() * 20
	bot.trying_t = 0
	bot.last_pos = p.pos
	if p.need[.Water] < 35 {
		bot.goal = .Pond
		bot.target = game.POND
		bot.goal_t = 120
		return
	}
	// Short of wood, with a forest to fetch it from: off for a branch.
	if p.sack[.Wood] < 4 && rand() < 0.25 {
		if i, ok := nearest_wood(); ok {
			bot.goal, bot.index, bot.target = .Food, i, g.foods[i].pos
			bot.goal_t = 100
			return
		}
	}
	roll := rand()
	switch {
	case roll < 0.32:
		// Food on the ground, one of the nearest few.
		if i, ok := nearest_food(); ok {
			bot.goal, bot.index, bot.target = .Food, i, g.foods[i].pos
			return
		}
	case roll < 0.52:
		if i, ok := nearest_plant(); ok {
			bot.goal, bot.index, bot.target = .Plant, i, g.rounds[i].pos
			return
		}
	case roll < 0.68:
		if i, ok := nearest_animal(); ok {
			bot.goal, bot.index, bot.target = .Animal, i, g.enemies[i].pos
			bot.goal_t = 20
			return
		}
	case roll < 0.78:
		for at in game.Station_Kind {
			if at == .Bench && p.sack[.Wood] < 5 && !g.stations[at].ready {
				continue // the little wood it has is kept for the oven and the fire
			}
			buf: [len(game.RECIPES)]^game.Recipe
			for rec in game.station_recipes(at, &buf) {
				if game.max_batch(rec) > 0 || g.stations[at].ready {
					st := g.stations[at]
					bot.goal, bot.target = .Station, st.pos
					bot.goal_t = 90
					return
				}
			}
		}
	case roll < 0.84:
		if p.sack[.Wheat] > 0 || g.mill.ready > 0 {
			bot.goal, bot.target = .Mill, g.mill.pos
			bot.goal_t = 90
			return
		}
	case roll < 0.88:
		bot.goal = .Pond
		bot.target = game.POND
		return
	}
	// Otherwise wander somewhere in the meadow, often into one of its parts.
	bot.goal = .Wander
	if rand() < 0.7 {
		kinds := [?]game.Region_Kind{.Forest, .Fields, .Garden, .Turkeys, .Hills, .Pond, .Bees, .Home}
		bot.target = game.REGIONS[kinds[int(rand() * len(kinds)) % len(kinds)]].centre + {rand() * 16 - 8, rand() * 12 - 6}
	} else {
		bot.target = {rand() * 190 - 95, rand() * 130 - 65}
	}
}

// One of the nearest few of something, by the distance this gives (negative: not wanted).
pick_near :: proc(count: int, dist: proc(i: int) -> f32) -> (int, bool) {
	best: [5]int
	best_d: [5]f32 = 1e9
	for i in 0 ..< count {
		d := dist(i)
		if d < 0 {
			continue
		}
		for k in 0 ..< 5 {
			if d < best_d[k] {
				for j := 4; j > k; j -= 1 {
					best[j], best_d[j] = best[j - 1], best_d[j - 1]
				}
				best[k], best_d[k] = i, d
				break
			}
		}
	}
	n := 0
	for d in best_d {
		if d < 1e9 {
			n += 1
		}
	}
	if n == 0 {
		return 0, false
	}
	return best[int(rand() * f32(n)) % n], true
}

nearest_food :: proc() -> (int, bool) {
	return pick_near(game.g.food_count, proc(i: int) -> f32 {
		f := &game.g.foods[i]
		if !game.food_ready(f) || game.sack_room(game.FOOD_ITEM[f.kind]) < 1 {
			return -1 // not there, or no room in the sack for it
		}
		return length(f.pos - game.g.prosio.pos)
	})
}

nearest_wood :: proc() -> (int, bool) {
	return pick_near(game.g.food_count, proc(i: int) -> f32 {
		f := &game.g.foods[i]
		if f.kind != .Wood || !game.food_ready(f) {
			return -1
		}
		return length(f.pos - game.g.prosio.pos)
	})
}

nearest_plant :: proc() -> (int, bool) {
	return pick_near(game.g.round_count, proc(i: int) -> f32 {
		rd := &game.g.rounds[i]
		if (rd.kind != .Bush && rd.kind != .Hive && rd.kind != .Salt_Rock) || rd.fruit <= 0 {
			return -1
		}
		return length(rd.pos - game.g.prosio.pos)
	})
}

nearest_animal :: proc() -> (int, bool) {
	return pick_near(game.g.enemy_count, proc(i: int) -> f32 {
		e := &game.g.enemies[i]
		if !game.on_ground(e) && e.state != .Dead {
			return -1
		}
		return length(e.pos - game.g.prosio.pos)
	})
}

nan :: proc(values: ..f32) -> bool {
	for v in values {
		if math.is_nan(v) || math.is_inf(v) {
			return true
		}
	}
	return false
}

// Looks at everything after each frame for what should never happen.
watch :: proc() {
	g := &game.g
	p := &g.prosio
	dt: f32 = 1.0 / 60

	if abs(game.body_kg() - p.kg) > 0.01 {
		note(.Weight_Not_Sum, fmt.tprintf("weighs %.2f, parts add up to %.2f", p.kg, game.body_kg()))
	}
	if nan(p.pos.x, p.pos.y, p.vel.x, p.vel.y, p.kg, p.fat, p.stamina, p.height) {
		note(.Not_A_Number, fmt.tprintf("pos %v vel %v kg %v fat %v", p.pos, p.vel, p.kg, p.fat))
	}
	if p.stamina < -0.01 || p.stamina > game.STAMINA_MAX + 0.01 {
		note(.Out_Of_Range, fmt.tprintf("stamina %.1f", p.stamina))
	}
	for v, n in p.need {
		if v < -0.01 || v > 100.01 || nan(v) {
			note(.Out_Of_Range, fmt.tprintf("%v at %.2f", n, v))
		}
	}
	for v, t in p.trait {
		if v < -1.001 || v > 1.001 || nan(v) {
			note(.Out_Of_Range, fmt.tprintf("trait %v at %.3f", t, v))
		}
	}
	if p.fail == .None && (p.fat < -0.01 || p.fat > game.FAT_MAX + 0.01) {
		note(.Out_Of_Range, fmt.tprintf("fat %.2f", p.fat))
	}
	half := game.WORLD_HALF
	if abs(p.pos.x) > half.x + 0.5 || abs(p.pos.y) > half.y + 0.5 {
		note(.Out_Of_Meadow, "Prosio")
	}

	// Inside something: what keeps things apart would push him a long way out.
	if !p.airborne && p.fail == .None {
		probe := p.pos
		game.collide_static(&probe, game.prosio_radius(p.kg) * 0.7, p.height)
		if length(probe - p.pos) > 0.15 {
			bot.inside_t += dt
			if bot.inside_t > 1 {
				note(.Inside_Something, fmt.tprintf("pushed %.2f m out", length(probe - p.pos)))
				bot.inside_t = -30
			}
		} else if bot.inside_t > 0 {
			bot.inside_t = 0
		} else {
			bot.inside_t = min(bot.inside_t + dt, 0)
		}
	}

	// Trying to walk, free to, and getting nowhere for 4 seconds.
	free := p.fail == .None && p.dazed_t <= 0 && p.pick_t <= 0 && p.eat_t <= 0 && p.ache_t <= 0 && p.lift_t <= 0 && p.carry == .Nothing && game.scene == .Playing
	moving := game.forced_down & {.Left, .Right, .Up, .Down} != {}
	@(static) still_t: f32
	@(static) still_from: game.Vec2
	if free && moving {
		still_t += dt
		if still_t > 4 {
			if length(p.pos - still_from) < 0.3 {
				known := false
				for spot in bot.stuck_spots {
					if length(spot - p.pos) < 3 {
						known = true
					}
				}
				if !known {
					append(&bot.stuck_spots, p.pos)
					what := "nothing in particular"
					if region, inside := game.region_at(p.pos); inside {
						what = fmt.tprintf("in %v", region)
					}
					note(.Cannot_Move, fmt.tprintf("held a direction 4 s and moved %.2f m (%s); speed %.2f", length(p.pos - still_from), what, length(p.vel)))
				}
			}
			still_t = 0
			still_from = p.pos
		}
	} else {
		still_t = 0
		still_from = p.pos
	}

	// F let go?
	if bot.release_t > 0 {
		bot.release_t -= 1
		if p.carry != .Enemy || p.carry_index != bot.release_idx || g.grabs != bot.release_grab {
			bot.release_t = 0 // it let go (and may grab the same animal again: that is not this)
		} else if bot.release_t == 0 {
			e := &g.enemies[p.carry_index]
			note(.F_Did_Not_Let_Go, fmt.tprintf("%v (%v, ko %v), stamina %.0f; winding %v for %.2f s, the grabbing press still down %v, swinging %v (a throw %v), lifting %.2f, held for %.1f s", e.kind, e.state, e.ko, p.stamina, p.winding, p.wind_t, p.grab_spent, p.swinging, p.swing_throw, max(p.lift_t, 0), p.held_t))
		}
	}

	// E did something?
	if bot.e_t > 0 {
		bot.e_t -= 1
		if bot.e_t == 0 {
			now := snapshot()
			before := bot.e_before
			changed := bot.menu_opened || bot.e_answered || now.sack != before.sack || now.scene != before.scene || now.carry != before.carry || abs(now.water - before.water) > 1 || now.baking != before.baking || now.ready != before.ready || now.mill != before.mill || p.pick_t > 0
			if !changed {
				near := "no food in reach now"
				if f := game.food_in_reach(p.pos, game.prosio_radius(p.kg) + 0.75); f != nil {
					near = fmt.tprintf("a %v in reach now (%d of those in the sack)", f.kind, p.sack[game.FOOD_ITEM[f.kind]])
				}
				note(.E_Did_Nothing, fmt.tprintf("at %s; now carrying %v, lifting %.2f, swinging %v, picking %.2f, dazed %.2f, winding %v, aching %.2f; %s; his bubble \"%s\" has %.2f s left", bot.e_what, p.carry, max(p.lift_t, 0), p.swinging, max(p.pick_t, 0), max(p.dazed_t, 0), p.winding, max(p.ache_t, 0), near, p.bubble, p.bubble_t))
			}
		}
	}

	// Holding and held must match.
	if p.carry == .Enemy && g.enemies[p.carry_index].state != .Held {
		note(.Hold_Mixup, fmt.tprintf("holding a %v that is %v", g.enemies[p.carry_index].kind, g.enemies[p.carry_index].state))
	}
	for &e, i in g.enemies[:g.enemy_count] {
		if e.state == .Held && (p.carry != .Enemy || p.carry_index != i) {
			note(.Hold_Mixup, fmt.tprintf("a %v is held, but not by him", e.kind))
			e.state = .Dizzy // so it is reported once
		}
		if nan(e.pos.x, e.pos.y, e.y) {
			note(.Not_A_Number, fmt.tprintf("a %v at %v", e.kind, e.pos))
		}
		// On its feet a frame ago and now, and a piece of fence between the
		// two places (that stood there both times: bot.fences_before).
		stands := game.on_ground(&e)
		if stands && bot.animal_stood[i] && g.fence_count == bot.fences_before && length(e.pos - bot.animal_was[i]) < 1 && game.crosses_fence(bot.animal_was[i], e.pos) {
			note(.Through_A_Fence, fmt.tprintf("a %v (%v) from (%.2f, %.2f) to (%.2f, %.2f)", e.kind, e.state, bot.animal_was[i].x, bot.animal_was[i].y, e.pos.x, e.pos.y))
		}
		bot.animal_stood[i], bot.animal_was[i] = stands, e.pos
		if animal_beyond_fence(e) {
			note(.Out_Of_Meadow, fmt.tprintf("a %v (%v) at (%.1f, %.1f)", e.kind, e.state, e.pos.x, e.pos.y))
		}
		if game.on_ground(&e) {
			probe := e.pos
			game.collide_static(&probe, game.ENEMY_RADIUS[e.kind] * 0.6, 0, true)
			if length(probe - e.pos) > 0.15 {
				bot.animal_in_t[i] += dt
				if bot.animal_in_t[i] > 2 {
					note(.Animal_Inside_Something, fmt.tprintf("a %v at (%.1f, %.1f)", e.kind, e.pos.x, e.pos.y))
					bot.animal_in_t[i] = -60
				}
			} else if bot.animal_in_t[i] > 0 {
				bot.animal_in_t[i] = 0
			} else {
				bot.animal_in_t[i] = min(bot.animal_in_t[i] + dt, 0)
			}
		}
		if e.state == .Flying {
			bot.flying_t[i] += dt
			if bot.flying_t[i] > 10 {
				note(.Animal_Flying_Forever, fmt.tprintf("a %v at height %.1f, speed %.1f", e.kind, e.y, length(e.vel)))
				bot.flying_t[i] = -60
			}
		} else {
			bot.flying_t[i] = min(bot.flying_t[i], 0)
		}
		if e.has_loot {
			bot.loot_t[i] += dt
			if bot.loot_t[i] > 120 {
				note(.Fox_Kept_Loot, fmt.tprintf("with %v, %.0f m from its den; it is %v at (%.1f, %.1f), den (%.1f, %.1f), speed %.1f, frightened for %.1f s more, health %.0f, %.0f m from Prosio", e.loot, length(e.pos - e.home), e.state, e.pos.x, e.pos.y, e.home.x, e.home.y, length(e.vel), max(e.scared_t, 0), e.health, length(e.pos - p.pos)))
				bot.loot_t[i] = -600
			}
		} else {
			bot.loot_t[i] = min(bot.loot_t[i], 0)
		}
	}

	bot.fences_before = g.fence_count

	// Budgets, once a minute.
	if stats.frames % 3600 == 0 {
		count: [game.Food_Kind]int
		for &f in g.foods[:g.food_count] {
			if game.food_ready(&f) {
				count[f.kind] += 1
			}
		}
		for n, kind in count {
			if !game.is_food(game.FOOD_ITEM[kind]) {
				continue // branches and spears have no budget
			}
			limit := kind == .Egg ? game.MAX_EGGS : game.budget_count(game.FOOD_ITEM[kind])
			if kind == .Apple {
				limit = game.budget_count(.Apple) // with those still on the trees, but those are not counted here
			}
			if n > limit {
				note(.Over_Budget, fmt.tprintf("%d %v standing, limit %d", n, kind, limit))
			}
		}
	}
}

report :: proc(minutes, seed: int) -> bool {
	g := &game.g
	p := &g.prosio
	fmt.printf("AUTOPLAY REPORT: meadow and bot seed %d, %d minutes of game time\n", seed, minutes)
	odd := 0
	for s in seen {
		odd += s.count
	}

	fmt.println("\n== Anomalies (things that should never happen)")
	if odd == 0 {
		fmt.println("none")
	}
	for &s, kind in seen {
		if s.count == 0 {
			continue
		}
		fmt.printf("%s: %d time(s)\n", ANOMALY_TEXT[kind], s.count)
		for ex in s.examples[:min(s.count, MAX_EXAMPLES)] {
			fmt.printf("    %s\n", ex)
		}
	}

	fmt.println("\n== Game overs")
	if len(stats.fails) == 0 {
		fmt.println("none")
	}
	for cause, n in stats.fails {
		fmt.printf("%s: %d\n", cause, n)
	}

	fmt.println("\n== His body, every 5 minutes (weight, fat, muscle, carbs, protein in kg; stamina)")
	for row, i in stats.samples {
		fmt.printf("%3d min  %5.1f  %5.1f  %4.1f  %4.2f  %4.2f  %3.0f\n", min(i * 5, minutes), row[0], row[1], row[2], row[3], row[4], row[5])
	}
	fmt.printf("weight from %.1f to %.1f kg, fat from %.1f to %.1f kg, most muscle %.1f kg\n", stats.kg_low, stats.kg_high, stats.fat_low, stats.fat_high, stats.muscle_high)
	fmt.print("highest each trait reached:")
	for level, t in stats.traits_high {
		fmt.printf(" %v %.2f", t, level)
	}
	fmt.println()

	fmt.println("\n== Share of the time each store spent in each state")
	total := f32(minutes * 60)
	fmt.println("                 lacking  run out    fine    full  too much")
	for n in game.Need {
		t := stats.state_t[n]
		fmt.printf("%-14v %7.0f%% %7.0f%% %7.0f%% %7.0f%% %7.0f%%\n", n, t[.Low] / total * 100, t[.Empty] / total * 100, t[.Fine] / total * 100, t[.High] / total * 100, t[.Over] / total * 100)
	}

	fmt.println("\n== What happened")
	fmt.print("into the sack:")
	for n, item in stats.sack_in {
		if n > 0 {
			fmt.printf(" %v %d", item, n)
		}
	}
	fmt.print("\neaten:")
	for n, item in stats.eaten {
		if n > 0 {
			fmt.printf(" %v %d", item, n)
		}
	}
	fmt.printf("\nbuilt things put up %d, taken down %d; most fence standing at once %d pieces; most animals penned at once %d, %.0f animal-seconds penned in all", stats.put_up, stats.taken_down, stats.most_fence, stats.most_penned, stats.penned_t)
	fmt.printf("\nanimals thrown %d; most bruised %.0f of %.0f;", stats.throws, stats.most_bruised, game.BRUISE_MOST)
	fmt.printf("\nanimals grabbed %d, carried for %.0f s; sprinting %.0f s; dazed %.0f s; fox thefts %d\n", stats.grabs, stats.carried_t, stats.sprint_t, stats.dazed_t, stats.thefts)
	fmt.print("animals killed:")
	for n, kind in stats.killed {
		fmt.printf(" %v %d", kind, n)
	}
	fmt.println()

	fmt.println("\n== What his weight went on (kg of fat and carbs burned)")
	burned: f32
	for kg in g.burned {
		burned += kg
	}
	for kg, why in g.burned {
		fmt.printf("%-10v %6.1f kg  %3.0f%%\n", why, kg, burned > 0 ? kg / burned * 100 : 0)
	}
	fmt.printf("in all     %6.1f kg, %.2f kg a minute; the food he ate was worth %.1f kg\n", burned, burned / f32(minutes), stats.eaten_kg)

	fmt.println("\n== Everything he said, most often first (a line that comes up a lot points at something to tune; a rare one shows that a rare thing did happen)")
	Line :: struct {
		text: string,
		n:    int,
	}
	lines: [dynamic]Line
	for text, n in stats.said {
		append(&lines, Line{text, n})
	}
	slice.sort_by(lines[:], proc(a, b: Line) -> bool {return a.n > b.n})
	for line in lines {
		fmt.printf("%5d  %s\n", line.n, line.text)
	}
	_ = p
	return odd == 0
}

// An animal outside the meadow's fence, which should never be. One knocked
// or thrown over the edge sails out into the fog (Flying) and is lost there
// (Gone): it is no longer in the meadow, though it keeps the place where it
// was lost until another of its kind comes back at its home. Neither is
// counted; one that came down out there and stayed would be. (Before this,
// every turkey bumped into the fog was reported beyond the fence each frame
// until the next came back, as on seeds 1, 2, 6 and 8.)
animal_beyond_fence :: proc(e: game.Enemy) -> bool {
	half := game.WORLD_HALF
	return e.state != .Gone && e.state != .Flying && (abs(e.pos.x) > half.x + 0.5 || abs(e.pos.y) > half.y + 0.5)
}
