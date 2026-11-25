package check

// The forager: autoplay's bot told to play sensibly, to measure the day's
// budget (docs/plans/wd2-day-budget.md). It gathers what is ripe when its
// food runs short, cooks at the oven, the fire and the churn when the sack
// holds the makings, grinds wheat, fetches wood for the cooking, drinks when
// thirsty, eats to keep him at the weight he started at (a few meals a day),
// and otherwise rests at home. It does not hunt, fish, rob hives or build:
// what it measures is what the meadow and the stations give a pig who goes
// out for it.
//
//   tools/check.sh autoplay --forager --minutes 180 --seed 1
//
// At the end of each day (DAY_SECONDS of play) it notes what he burned
// (being alive, and doing things), what he brought in for each minute spent
// gathering and cooking, what he ate and in how many meals, his weight, how
// often his stomach stopped him, and what stood ripe in the meadow.

import game "../game"
import "core:fmt"

Forager_Day :: struct {
	burned:        [game.Burn_For]f64, // kg, by what it went on
	gathered_kcal: f32, // into the sack: picked, ground, and what cooking added
	work_s:        f32, // seconds spent gathering and cooking (going to it included)
	water_s:       f32, // seconds spent going for a drink
	eaten_kcal:    f32,
	lost_kcal:     f32, // gone out of the sack by going off
	fox_kcal:      f32, // and taken by a fox
	thefts:        int,
	eaten_litres:  f32, // the room what he ate took in his stomach
	bites:         int,
	meals:         int,
	refused:       int, // times he would have eaten but his stomach was full
	beaten:        int, // game overs
	kg, fat, muscle, stomach: f32, // at the end of the day
	standing:      [game.Item]f32, // kcal ripe in the meadow at the end of the day
}

Forager :: struct {
	on:         bool,
	days:       [dynamic]Forager_Day,
	today:      Forager_Day,
	burned_at:  [game.Burn_For]f64, // g.burned when the day began
	sack_kcal:  f32, // the food in the sack a frame ago, in kcal
	last_bite:  f32, // g.time of the last bite
	last_refused: f32, // and of the last time his stomach stopped him
	thefts:     int, // stats.thefts a frame ago
	eating:     bool, // this frame's Q was a bite (so the sack going down is not counted as cooking)
	want_food:  f32, // gathers until the sack holds this much food
}

forager: Forager

// The kcal of the food in his sack.
sack_food_kcal :: proc() -> (sum: f32) {
	for item in game.Item {
		if game.is_food(item) {
			sum += game.g.prosio.sack_kcal[item]
		}
	}
	return
}

// Called once a frame, after the game has moved on.
forager_tick :: proc(frame: int) {
	g := &game.g
	p := &g.prosio
	t := &forager.today
	dt: f32 = 1.0 / 60
	// What came into the sack: picking, grinding and cooking. Eating takes
	// out (counted as eaten), and so does putting the makings into the oven
	// (taken off what it brings in, so a dish counts only what cooking
	// added). Going off takes a little all the time (not counted).
	now := sack_food_kcal()
	change := now - forager.sack_kcal
	if forager.eating {
		change = 0
	}
	stolen := stats.thefts > forager.thefts
	forager.thefts = stats.thefts
	switch {
	case stolen:
		t.fox_kcal -= min(change, 0)
		t.thefts += 1
	case bot.goal == .Station || bot.goal == .Mill || change > 0:
		t.gathered_kcal += change
	case:
		t.lost_kcal -= change
	}
	forager.sack_kcal = now
	forager.eating = false
	#partial switch bot.goal {
	case .Food, .Plant, .Station, .Mill:
		t.work_s += dt
	case .Pond:
		t.water_s += dt
	}
	if p.fail != .None && p.fail_t > 0 && p.fail_t < 1.0 / 30 {
		t.beaten += 1
	}
	if (frame + 1) % (int(game.DAY_SECONDS) * 60) == 0 {
		for kg, why in g.burned {
			t.burned[why] = kg - forager.burned_at[why]
		}
		forager.burned_at = g.burned
		t.kg, t.fat, t.muscle, t.stomach = p.kg, p.fat, game.part_kg(.Muscle), p.stomach
		t.standing = meadow_standing()
		append(&forager.days, t^)
		t^ = {}
	}
}

// The ripe food in the meadow, kcal by kind.
meadow_standing :: proc() -> (kcal: [game.Item]f32) {
	g := &game.g
	for &f in g.foods[:g.food_count] {
		if game.food_ready(&f) && f.kind != .Wood && f.kind != .Spear {
			kcal[game.FOOD_ITEM[f.kind]] += game.food_kcal(&f)
		}
	}
	for &r in g.rounds[:g.round_count] {
		if r.kind == .Bush || r.kind == .Hive {
			kcal[r.kind == .Bush ? .Berries : .Honey] += f32(r.fruit) * game.bush_kcal(&r)
		}
		if r.kind == .Tree && r.species == .Apple {
			kcal[.Apple] += f32(r.fruit) * game.RAW_KCAL[.Apple] * game.ripeness(r.ripe)
		}
	}
	return
}

// Whether he should eat now: lighter than he started, his stomach with room,
// and food in the sack. (A bite at a time; a meal is the bites taken with
// less than five minutes between them.)
forager_eat :: proc(tap: ^bit_set[game.Button]) -> bool {
	g := &game.g
	p := &g.prosio
	hungry := p.kg < game.KG_START || game.lacks(.Carbs)
	if !hungry || !game.sack_has_food() {
		return false
	}
	if game.stomach_full() {
		if g.time - forager.last_refused > 60 {
			forager.today.refused += 1 // (once a minute at most)
			forager.last_refused = g.time
		}
		return false
	}
	// What it lacks most, if anything, else the richest for the room it
	// takes in his stomach.
	want := game.Need.Carbs
	short := false
	for n in ([3]game.Need{.Protein, .Vitamins, .Fibre}) {
		if game.lacks(n) {
			want, short = n, true
		}
	}
	best: game.Item
	best_score: f32 = -1
	for n, item in p.sack {
		if n <= 0 || !game.edible(item) || item == .Salt {
			continue
		}
		score := game.sack_piece_kcal(item) / game.stomach_room(item)
		if short {
			c := game.composition(item)
			share := c[game.Nutrient.Protein]
			#partial switch want {
			case .Vitamins: share = c[game.Nutrient.Vitamins]
			case .Fibre: share = c[game.Nutrient.Fibre]
			}
			score *= 1 + share
		}
		if score > best_score {
			best, best_score = item, score
		}
	}
	if best_score < 0 {
		return false
	}
	if game.lacks(.Electrolytes) && p.sack[.Salt] > 0 {
		best = .Salt
	}
	p.sack_sel = best
	t := &forager.today
	if g.time - forager.last_bite > 300 {
		t.meals += 1
	}
	forager.last_bite = g.time
	t.bites += 1
	t.eaten_kcal += game.sack_piece_kcal(best)
	t.eaten_litres += game.stomach_room(best)
	stats.eaten[best] += 1
	stats.eaten_kg += game.sack_piece_kcal(best) / game.KCAL_PER_KG
	forager.eating = true
	tap^ += {.Eat}
	return true
}

// Its next goal.
forager_goal :: proc() {
	g := &game.g
	p := &g.prosio
	bot.goal_t = 60
	bot.trying_t = 0
	bot.last_pos = p.pos
	if p.need[.Water] < 40 {
		bot.goal, bot.target, bot.goal_t = .Pond, game.POND, 120
		return
	}
	// A dish ready: fetch it.
	for st, at in g.stations {
		if st.ready && at != .Bench && at != .Camp {
			bot.goal, bot.target, bot.goal_t = .Station, st.pos, 90
			return
		}
	}
	// The makings of something, with the wood for it: off to cook it.
	for at in ([3]game.Station_Kind{.Oven, .Fire, .Churn}) {
		if g.stations[at].baking {
			continue
		}
		buf: [len(game.RECIPES)]^game.Recipe
		for rec in game.station_recipes(at, &buf) {
			if game.is_food(rec.dish) && game.max_batch(rec) > 0 {
				bot.goal, bot.target, bot.goal_t = .Station, g.stations[at].pos, 90
				return
			}
		}
	}
	if p.sack[.Wheat] > 0 || g.mill.ready > 0 {
		bot.goal, bot.target, bot.goal_t = .Mill, g.mill.pos, 90
		return
	}
	// Short of food in the sack: gather. (Wood for the cooking, too.)
	if sack_food_kcal() < forager.want_food {
		if p.sack[.Wood] < 4 {
			if i, ok := nearest_wood(); ok {
				bot.goal, bot.index, bot.target, bot.goal_t = .Food, i, g.foods[i].pos, 100
				return
			}
		}
		food, food_d := ripe_food()
		plant, plant_d := ripe_plant()
		if food >= 0 && (plant < 0 || food_d <= plant_d) {
			bot.goal, bot.index, bot.target = .Food, food, g.foods[food].pos
			return
		}
		if plant >= 0 {
			bot.goal, bot.index, bot.target = .Plant, plant, g.rounds[plant].pos
			return
		}
	}
	// Nothing to do: rest at home.
	bot.goal, bot.target, bot.goal_t = .Wander, game.HOME + {2, 3}, 20
}

// The nearest food on the ground worth picking: grown, or fallen.
ripe_food :: proc() -> (int, f32) {
	g := &game.g
	best, best_d := -1, f32(1e9)
	for &f, i in g.foods[:g.food_count] {
		if !game.food_ready(&f) || f.kind == .Wood || f.kind == .Spear || (!f.fallen && f.grow < 0.95) || game.sack_room(game.FOOD_ITEM[f.kind]) < 1 {
			continue
		}
		if d := length(f.pos - g.prosio.pos); d < best_d {
			best, best_d = i, d
		}
	}
	return best, best_d
}

// The nearest berry bush with ripe berries on it, or a salt rock when he is
// short of salt. (Not a hive: the bees.)
ripe_plant :: proc() -> (int, f32) {
	g := &game.g
	p := &g.prosio
	best, best_d := -1, f32(1e9)
	for &r, i in g.rounds[:g.round_count] {
		ok := r.kind == .Bush && r.fruit > 0 && game.bush_kcal(&r) >= 0.95 * game.RAW_KCAL[.Berries]
		ok ||= r.kind == .Salt_Rock && r.fruit > 0 && p.need[.Electrolytes] < 45 && p.sack[.Salt] == 0
		if !ok {
			continue
		}
		if d := length(r.pos - p.pos); d < best_d {
			best, best_d = i, d
		}
	}
	return best, best_d
}

forager_report :: proc() {
	fmt.println("\n== The day's budget: the forager, a day (60 minutes of play) at a time")
	fmt.println("day  alive  doing  burned | in     work  kcal/min  off   fox (thefts) | eaten  litres meals bites  full | kg    fat   muscle | beaten")
	for d, i in forager.days {
		alive := f32(d.burned[.Muscle]) * game.KCAL_PER_KG
		doing: f32
		for kg, why in d.burned {
			if why != .Muscle {
				doing += f32(kg) * game.KCAL_PER_KG
			}
		}
		work := d.work_s / 60
		fmt.printf("%3d  %5.0f  %5.0f  %6.0f | %5.0f  %4.1f  %7.0f  %5.0f %5.0f (%3d)    | %5.0f  %5.1f  %4d %5d  %4d | %5.1f %5.1f %5.1f  | %d\n",
			i + 1, alive, doing, alive + doing, d.gathered_kcal, work, work > 0 ? d.gathered_kcal / work : 0, d.lost_kcal, d.fox_kcal, d.thefts, d.eaten_kcal, d.eaten_litres, d.meals, d.bites, d.refused, d.kg, d.fat, d.muscle, d.beaten)
	}
	fmt.println("(alive: what his muscles burn, with the protein used up; doing: walking, sprinting, jumps, picking, fights; in: kcal into the sack, cooking's gain included; work: minutes gathering and cooking, going there included, water trips not; off: kcal gone out of the sack by going off; fox: taken by foxes (how many times); litres: the room what he ate took in his stomach; full: minutes in which his stomach stopped him eating when he wanted to)")
	fmt.println("\nRipe in the meadow at the end of each day, kcal:")
	fmt.printf("%-14s", "")
	for _, i in forager.days {
		fmt.printf("  day %d", i + 1)
	}
	fmt.println()
	for item in game.Item {
		if !game.is_food(item) || game.is_dish(item) {
			continue
		}
		any := false
		for d in forager.days {
			any ||= d.standing[item] > 0
		}
		if !any {
			continue
		}
		fmt.printf("%-14v", item)
		for d in forager.days {
			fmt.printf(" %6.0f", d.standing[item])
		}
		fmt.println()
	}
}
