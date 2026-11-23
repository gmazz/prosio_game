package game

import "core:math"

// Food is gathered, not eaten on the spot: E puts it in Prosio's sack, and
// he eats from the sack when he likes (Q), choosing what with Z and C.
// Whatever he eats puts on weight by its calories, slowly: food has to be
// gathered steadily to make up for what walking, picking things up and
// fighting burn (see the *_BURN numbers in prosio.odin).
//
// Some food has to be made into something else first, and each process has
// its own place, far from the others: the oven at home bakes pies, muffins
// and bread; the fire by the pond fries eggs, grills fish and roasts meat;
// the churn in the goat hills makes butter and cheese of milk. Cooking makes
// more of the calories in food available to the body, and the better he is
// at it the more: each place has a skill of its own, which grows with every
// dish made there and never fades, and the calories of what he makes there
// are those of what went in times a bonus between the two of COOK_RANGE.
//
// A fire needs wood. Every dish from the oven or the cooking fire takes
// logs with it, more for a bigger dish (they are in the recipes); the churn
// and the mill need none. Wood lies under the forest trees (workshop.odin).

Item :: enum u8 {
	Apple,
	Berries,
	Mushroom,
	Pumpkin,
	Cabbage,
	Nuts, // a handful
	Wheat, // not edible as it is: the mill grinds it
	Egg,
	Flour, // ground at the mill; not edible until baked
	Salt, // a lump of rock salt, to lick: no calories at all
	Fish, // caught in the pond; raw until grilled
	Meat, // chopped from a turkey or a goat at the fire; raw until roasted
	Milk, // from a goat
	Honey, // from the hives in the bee meadow
	Pebble, // for throwing: not food
	// Made at the oven, the fire or the churn:
	Apple_Pie,
	Pumpkin_Pie,
	Berry_Muffins,
	Mushroom_Pie,
	Nut_Cake,
	Bread,
	Fried_Egg,
	Grilled_Fish,
	Roast,
	Butter,
	Cheese,
	// Not food at all: what things are made of, and what he makes of it at
	// the workbench (see workshop.odin). New things go at the end, so that a
	// saved sack keeps its places.
	Wood, // a fallen branch: for the oven, the fire and the workbench
	Fence, // a piece of fence, two metres long
	Scarecrow,
	Rod, // a fishing rod
	Spear,
	Gate, // a piece of fence that opens
	Larder, // a cupboard for food, stood up with Q (see larder.odin)
	Campfire, // a ring of stones and a spit, set up with Q: a cooking fire of his own (see workshop.odin)
}
FIRST_DISH :: Item.Apple_Pie
FIRST_TOOL :: Item.Wood

// Something with calories in it (though it may want cooking first).
is_food :: proc(item: Item) -> bool {
	return item < FIRST_TOOL && item != .Pebble
}

// Something made of food at the oven, the fire or the churn.
is_dish :: proc(item: Item) -> bool {
	return item >= FIRST_DISH && item < FIRST_TOOL
}

ITEM_NAME := [Item]cstring {
	.Apple         = "APPLE",
	.Berries       = "BERRIES",
	.Mushroom      = "MUSHROOM",
	.Pumpkin       = "PUMPKIN",
	.Cabbage       = "CABBAGE",
	.Nuts          = "NUTS",
	.Wheat         = "WHEAT",
	.Egg           = "EGG",
	.Flour         = "FLOUR",
	.Salt          = "ROCK SALT",
	.Fish          = "RAW FISH",
	.Meat          = "RAW MEAT",
	.Milk          = "MILK",
	.Honey         = "HONEY",
	.Pebble        = "PEBBLE",
	.Apple_Pie     = "APPLE PIE",
	.Pumpkin_Pie   = "PUMPKIN PIE",
	.Berry_Muffins = "BERRY MUFFINS",
	.Mushroom_Pie  = "MUSHROOM PIE",
	.Nut_Cake      = "NUT CAKE",
	.Bread         = "BREAD",
	.Fried_Egg     = "FRIED EGG",
	.Grilled_Fish  = "GRILLED FISH",
	.Roast         = "ROAST MEAT",
	.Butter        = "BUTTER",
	.Cheese        = "CHEESE",
	.Wood          = "WOOD",
	.Fence         = "FENCE PIECE",
	.Scarecrow     = "SCARECROW",
	.Rod           = "FISHING ROD",
	.Spear         = "SPEAR",
	.Gate          = "GATE",
	.Larder        = "LARDER",
	.Campfire      = "CAMPFIRE KIT",
}

// What is in the sack weighs, and the room it takes.
sack_kg :: proc() -> (sum: f32) {
	for count, item in g.prosio.sack {
		sum += f32(count) * ITEM_KG[item]
	}
	return
}

sack_litres :: proc() -> (sum: f32) {
	for count, item in g.prosio.sack {
		sum += f32(count) * ITEM_LITRES[item]
	}
	return
}

// How full the sack is, from 0 to 1 (what the player sees, as a per cent).
sack_full :: proc() -> f32 {
	return sack_litres() / SACK_LITRES
}

// How many more of this would fit.
sack_room :: proc(item: Item) -> int {
	return int(math.floor((SACK_LITRES - sack_litres()) / ITEM_LITRES[item] + 0.001))
}

// Some things have to be made into something else first.
edible :: proc(item: Item) -> bool {
	#partial switch item {
	case .Wheat, .Flour, .Egg, .Fish, .Meat, .Pebble:
		return false
	}
	return item < FIRST_TOOL
}

GATHER_TEXT := #partial [Item]cstring {
	.Apple    = "An apple for the sack!",
	.Berries  = "Berries for the sack!",
	.Mushroom = "A mushroom for the sack!",
	.Pumpkin  = "A pumpkin for the sack!",
	.Cabbage  = "A cabbage for the sack!",
	.Nuts     = "Nuts for the sack!",
	.Salt     = "A lump of salt for the sack!",
	.Honey    = "Honey for the sack!",
	.Pebble   = "Pebbles! Good for throwing.",
	.Wheat    = "Wheat for the sack!",
	.Egg      = "An egg for the sack!",
	.Wood     = "A good dry branch for the sack!",
	.Spear    = "Got my spear back!",
}

EAT_TEXT := [Item]cstring {
	.Apple         = "Crunch! Yum!",
	.Berries       = "Berries! Yum!",
	.Mushroom      = "Mmm, mushroom!",
	.Pumpkin       = "A whole pumpkin! Burp!",
	.Cabbage       = "Crunch crunch... cabbage!",
	.Nuts          = "Crack! Nutty nuts!",
	.Salt          = "Lick, lick... SO salty!",
	.Fish          = "Raw fish? Blergh! The fire by the pond grills it.",
	.Meat          = "Raw meat? No! The fire by the pond roasts it.",
	.Milk          = "Glug glug... creamy milk!",
	.Honey         = "Sticky, sweet honey! Mmm!",
	.Pebble        = "I can't eat a pebble! Hold {Grab} to throw one.",
	.Wheat         = "I can't eat raw wheat! The mill makes flour of it.",
	.Egg           = "A raw egg? Yuck! The fire by the pond fries it.",
	.Flour         = "Dry flour? Blergh! It wants baking.",
	.Apple_Pie     = "Apple pie! Heavenly!",
	.Pumpkin_Pie   = "Pumpkin pie! BURP!",
	.Berry_Muffins = "Muffins! So fluffy!",
	.Mushroom_Pie  = "Mushroom pie! Mmm!",
	.Nut_Cake      = "Nut cake! So rich!",
	.Fried_Egg     = "A fried egg! Sunny side up!",
	.Grilled_Fish  = "Grilled fish! Crispy!",
	.Roast         = "Roast meat! What a feast!",
	.Butter        = "A whole pat of butter! Slurp!",
	.Cheese        = "Cheese! Squeaky and salty!",
	.Bread         = "Warm bread! Yum!",
	.Wood          = "I can't eat wood! It is for fires, and for building.",
	.Fence         = "No room for a fence here!",
	.Scarecrow     = "No room for a scarecrow here!",
	.Rod           = "My fishing rod! {Grab} at the pond casts it.",
	.Spear         = "My spear! Hold {Grab} to throw it.",
	.Gate          = "A gate! {Eat} puts it up in a fence.",
	.Larder        = "A larder! {Eat} stands it up.",
	.Campfire      = "My campfire kit! {Eat} sets it up.",
}

Ingredient :: struct {
	item:  Item,
	count: int, // 0: unused
}

// Where things are made.
Station_Kind :: enum {
	Oven, // at home
	Fire, // by the pond
	Churn, // in the goat hills
	Bench, // the workbench at home, where things are built of wood
	Camp, // his own campfire, wherever he set it up: cooks what the fire does (see camp_up)
}

STATION_NAME := [Station_Kind]cstring{.Oven = "THE OVEN", .Fire = "THE COOKING FIRE", .Churn = "THE CHURN", .Bench = "THE WORKBENCH", .Camp = "MY CAMPFIRE"}
STATION_LABEL := [Station_Kind]cstring{.Oven = "OVEN", .Fire = "FIRE", .Churn = "CHURN", .Bench = "WORKBENCH", .Camp = "CAMPFIRE"}
STATION_ABOUT := [Station_Kind]cstring {
	.Oven  = "The better the baker, the richer the bake",
	.Fire  = "The better the cook, the richer the dish",
	.Churn = "The better the dairy pig, the more butter and cheese",
	.Bench = "Wood from the forest, made into useful things.",
	.Camp  = "The better the cook, the richer the dish",
}
STATION_BUSY := [Station_Kind]cstring{.Oven = "BAKING... %d", .Fire = "COOKING... %d", .Churn = "CHURNING... %d", .Bench = "BUILDING... %d", .Camp = "COOKING... %d"}
COOK_TITLE := [Station_Kind][4]cstring {
	.Oven  = {"Beginner baker", "Apprentice baker", "Baker", "Master baker"},
	.Fire  = {"Beginner cook", "Apprentice cook", "Cook", "Master of the grill"},
	.Camp  = {"Beginner cook", "Apprentice cook", "Cook", "Master of the grill"},
	.Churn = {"Beginner dairy pig", "Apprentice dairy pig", "Dairy pig", "Master cheesemaker"},
	.Bench = {},
}
STATION_ROUND := [Station_Kind]Round_Kind{.Oven = .Oven, .Fire = .Fire, .Churn = .Churn, .Bench = .Bench, .Camp = .Fire}
// What he says as he starts something there, while it is not done, when it
// is, and as he takes it.
STATION_START := [Station_Kind]cstring{.Oven = "Into the oven it goes!", .Fire = "On the fire it goes!", .Churn = "Round and round goes the churn!", .Bench = "Saw, saw... knock, knock!", .Camp = "On my campfire it goes!"}
STATION_WAIT := [Station_Kind]cstring{.Oven = "Still baking... it smells so good!", .Fire = "Still sizzling... not yet!", .Churn = "Still churning... round and round!", .Bench = "Not finished... one more nail!", .Camp = "Still sizzling... not yet!"}
STATION_DONE := [Station_Kind]cstring{.Oven = "Ding! The oven is ready!", .Fire = "Sizzle! It's cooked!", .Churn = "The churn is done!", .Bench = "There! All built!", .Camp = "Sizzle! It's cooked!"}
STATION_TAKE := [Station_Kind]cstring{.Oven = "Into the sack, still warm!", .Fire = "Into the sack, still warm!", .Churn = "Into the sack, fresh from the churn!", .Bench = "Into the sack! I made that!", .Camp = "Into the sack, still warm!"}

Recipe :: struct {
	at:    Station_Kind,
	dish:  Item,
	needs: []Ingredient, // (as many as it takes)
}

// An oven, a fire or a churn: it makes one kind of thing at a time, one or
// several of it in a batch.
Station :: struct {
	pos:     Vec2,
	baking:  bool,
	ready:   bool, // what it made is waiting there
	dish:    Item,
	count:   int, // how many of it
	kcal:    f32, // the calories in all of them, from what went in
	bake_t:  f32,
	smoke_t: f32,
}

// Whose menu is open, which recipe it points at, how many to make, and a
// moment of "not enough".
cook_at: Station_Kind
cook_choice: int
cook_count: int
cook_refused_t: f32

recipe_for :: proc(dish: Item) -> ^Recipe {
	for &r in RECIPES {
		if r.dish == dish {
			return &r
		}
	}
	return nil
}

// The recipes of one station that he knows, in order. (For now he knows
// them all from the start; later a recipe or a plan may have to be found
// first. See knows in Prosio.)
station_recipes :: proc(at: Station_Kind, buf: ^[len(RECIPES)]^Recipe) -> []^Recipe {
	n := 0
	for &r in RECIPES {
		if (r.at == at || (at == .Camp && r.at == .Fire)) && g.prosio.knows[r.dish] {
			buf[n] = &r
			n += 1
		}
	}
	return buf[:n]
}

// The calories in what went into a recipe, raw.
raw_kcal :: proc(r: ^Recipe) -> (sum: f32) {
	for n in r.needs {
		sum += RAW_KCAL[n.item] * f32(n.count)
	}
	return
}

item_kcal :: proc(item: Item) -> f32 {
	if item >= FIRST_TOOL {
		return 0
	}
	if item < FIRST_DISH {
		return RAW_KCAL[item]
	}
	r := recipe_for(item)
	return math.round(raw_kcal(r) * COOK_RANGE[r.at][0]) // as a beginner makes it
}

// What is in the sack is not all alike: an apple picked green has fewer
// calories than a ripe one. So the sack keeps the calories of each kind of
// thing in it, and one piece taken out is an average one.
sack_add :: proc(item: Item, kcal: f32, fresh: f32 = 1) {
	p := &g.prosio
	p.sack_fresh[item] = (p.sack_fresh[item] * f32(p.sack[item]) + fresh) / f32(p.sack[item] + 1)
	p.sack[item] += 1
	p.sack_kcal[item] += kcal
}

// Takes this many out, and says how many calories went with them.
sack_take :: proc(item: Item, count: int) -> f32 {
	p := &g.prosio
	if p.sack[item] <= 0 {
		return 0
	}
	n := min(count, p.sack[item])
	kcal := p.sack_kcal[item] * f32(n) / f32(p.sack[item])
	p.sack[item] -= n
	p.sack_kcal[item] = p.sack[item] > 0 ? p.sack_kcal[item] - kcal : 0
	return kcal
}

// The calories in one piece of this in the sack (or the usual, with none).
sack_piece_kcal :: proc(item: Item) -> f32 {
	p := &g.prosio
	if p.sack[item] <= 0 {
		return item_kcal(item)
	}
	return math.round(p.sack_kcal[item] / f32(p.sack[item]))
}

// What one of a recipe would give, made from what is in the sack now.
recipe_kcal :: proc(r: ^Recipe) -> (sum: f32) {
	for n in r.needs {
		sum += sack_piece_kcal(n.item) * f32(n.count)
	}
	return math.round(sum * cook_bonus(r.at))
}

// How many of a recipe the sack has the makings of, and room for.
max_batch :: proc(r: ^Recipe) -> int {
	// Room for what comes out, once what goes in has left the sack.
	free := SACK_LITRES - sack_litres()
	used: f32
	for n in r.needs {
		used += ITEM_LITRES[n.item] * f32(n.count)
	}
	most := BATCH_MOST
	if grows := ITEM_LITRES[r.dish] - used; grows > 0 {
		most = min(most, int(math.floor(free / grows + 0.001)))
	}
	for n in r.needs {
		if n.count > 0 {
			most = min(most, g.prosio.sack[n.item] / n.count)
		}
	}
	return max(most, 0)
}

// The things in the sack, in order.
owned_items :: proc(buf: ^[len(Item)]Item) -> []Item {
	n := 0
	for it in Item {
		if g.prosio.sack[it] > 0 {
			buf[n] = it
			n += 1
		}
	}
	return buf[:n]
}

// Moves the choice in the sack by step (0 just makes sure it points at
// something that is there).
sack_step :: proc(step: int) {
	p := &g.prosio
	buf: [len(Item)]Item
	owned := owned_items(&buf)
	if len(owned) == 0 {
		return
	}
	at := -1
	for it, i in owned {
		if it == p.sack_sel {
			at = i
		}
	}
	if at < 0 {
		// What was chosen is used up: take the next one along.
		for it in owned {
			if it > p.sack_sel {
				p.sack_sel = it
				return
			}
		}
		p.sack_sel = owned[len(owned) - 1]
		return
	}
	p.sack_sel = owned[(at + step + len(owned)) % len(owned)]
}

// Something in the sack he could eat right now.
sack_has_food :: proc() -> bool {
	for n, item in g.prosio.sack {
		if n > 0 && edible(item) {
			return true
		}
	}
	return false
}

// Something in the sack a fox would take.
sack_has_loot :: proc() -> bool {
	for n, item in g.prosio.sack {
		if n > 0 && is_food(item) {
			return true
		}
	}
	return false
}

// E next to food: into the sack it goes.
gather :: proc(food: ^Food, bush: ^Round) {
	p := &g.prosio
	item := Item.Berries
	if food != nil {
		item = FOOD_ITEM[food.kind]
	} else if bush.kind == .Hive {
		item = .Honey
	} else if bush.kind == .Salt_Rock {
		item = .Salt
	} else if bush.kind == .Pebbles {
		item = .Pebble
	}
	if sack_room(item) < 1 {
		answer("My sack is full!")
		return
	}
	at: Vec2
	unripe := false
	if food != nil {
		sack_add(item, food_kcal(food))
		unripe = food.grow < 0.6
		if food.fallen {
			food.gone = true
		} else {
			// Another will sprout here, but not for a good while.
			food.respawn = random_range(FOOD_REGROW[food.kind].x, FOOD_REGROW[food.kind].y)
		}
		at = food.pos
		burst({at.x, 0.4, at.y}, 6, 2, food.kind == .Wheat ? Color{226, 186, 84, 255} : (FOOD_ITEM[food.kind] >= FIRST_TOOL ? COLOR_TRUNK : COLOR_LEAF_LIGHT), 0.06)
	} else {
		sack_add(item, bush_kcal(bush))
		unripe = bush.ripe < 0.6
		if bush.fruit == plant_max(bush.kind) {
			bush.fruit_t = random_range(plant_regrow(bush.kind).x, plant_regrow(bush.kind).y)
		}
		bush.fruit -= 1
		if bush.kind == .Pebbles {
			// A handful at a stoop, as many as there are and the sack has room for.
			for _ in 1 ..< PEBBLE_HANDFUL {
				if bush.fruit > 0 && sack_room(item) > 0 {
					sack_add(item, 0)
					bush.fruit -= 1
				}
			}
		}
		bush.shake_t = 0.4
		at = bush.pos
		burst({at.x, 0.9, at.y}, 6, 2, ITEM_COLOR[item], 0.06)
	}
	sack_step(0)
	say(unripe ? "Not ripe yet... into the sack anyway." : GATHER_TEXT[item], 1.2)
	p.pick_t = pick_time() // a moment to stoop and pick it up
	p.pick_total = p.pick_t
	train(.Hooves, PICK_WORK)
	p.pick_item = item
	p.drinking = false
	p.vel = {}
	burn(GATHER_BURN, .Gathering)
	to := at - p.pos
	p.facing = math.atan2(to.x, to.y)
}

// Q: eat what is chosen in the sack, or, if it is something he built, put
// it up in front of him.
eat_from_sack :: proc() {
	p := &g.prosio
	item := p.sack_sel
	if p.sack[item] <= 0 {
		answer("My sack is empty! {Action} picks food up.")
		return
	}
	if item == .Fence || item == .Scarecrow || item == .Gate || item == .Larder || item == .Campfire {
		put_up(item)
		return
	}
	if !edible(item) {
		answer(EAT_TEXT[item])
		return
	}
	eat(item_meal(item, sack_take(item, 1)))
	sack_step(0)
	say(EAT_TEXT[item])
	p.eat_t = 0.5
	p.wobble_vel += 2.5
	crumbs := is_dish(item) ? Color{226, 178, 104, 255} : COLOR_CRUMB
	burst({p.pos.x, p.height + 1.3 * PROSIO_SIZE, p.pos.y}, 8, 2.5, crumbs, 0.07)
}

station_in_reach :: proc(at: Station_Kind, pos: Vec2, r: f32) -> bool {
	return station_standing(at) && length2(g.stations[at].pos - pos) < STATION_RADIUS[at] + r + 0.7
}

// Every station stands where it was built, but his campfire only while it
// is set up.
station_standing :: proc(at: Station_Kind) -> bool {
	return at != .Camp || g.camp_up
}

// A fire he can cook and chop meat at within reach: the cooking fire by
// the pond, or his campfire.
fire_in_reach :: proc(pos: Vec2, r: f32) -> (at: Station_Kind, ok: bool) {
	for kind in ([2]Station_Kind{.Fire, .Camp}) {
		if station_in_reach(kind, pos, r) {
			return kind, true
		}
	}
	return .Fire, false
}

// The station he is standing at, if any.
station_near :: proc(pos: Vec2, r: f32) -> (at: Station_Kind, ok: bool) {
	for kind in Station_Kind {
		if station_standing(kind) && station_in_reach(kind, pos, r) {
			return kind, true
		}
	}
	return {}, false
}

// E at a station: take what is ready, or choose something to make.
use_station :: proc(at: Station_Kind) {
	p := &g.prosio
	o := &g.stations[at]
	to := o.pos - p.pos
	p.facing = math.atan2(to.x, to.y)
	switch {
	case o.ready:
		taken := 0
		for o.count > 0 && sack_room(o.dish) > 0 {
			share := o.kcal / f32(o.count)
			sack_add(o.dish, share)
			o.kcal -= share
			o.count -= 1
			taken += 1
		}
		if taken == 0 {
			answer("No room in my sack for it!")
			return
		}
		p.sack_sel = o.dish
		o.ready = o.count > 0
		say(STATION_TAKE[at], 1.6)
		burst({o.pos.x, 0.9, o.pos.y + STATION_RADIUS[at]}, 10, 2.5, COLOR_STAR, 0.08)
	case o.baking:
		answer(STATION_WAIT[at])
	case:
		buf: [len(RECIPES)]^Recipe
		if len(station_recipes(at, &buf)) == 0 {
			answer("I don't know how to make anything here yet!")
			return
		}
		scene = .Oven
		cook_at = at
		cook_choice = 0
		cook_count = 1
		cook_refused_t = 0
		// Point at the first thing he can make, if any.
		for r, i in station_recipes(at, &buf) {
			if max_batch(r) > 0 {
				cook_choice = i
				break
			}
		}
	}
}

// A station's menu, shown with the game paused.
update_cook_menu :: proc(dt: f32) {
	buf: [len(RECIPES)]^Recipe
	recipes := station_recipes(cook_at, &buf)
	n := len(recipes)
	cook_refused_t -= dt
	if button_pressed(.Down) {
		cook_choice = (cook_choice + 1) % n
		cook_count = 1
	}
	if button_pressed(.Up) {
		cook_choice = (cook_choice + n - 1) % n
		cook_count = 1
	}
	r := recipes[cook_choice]
	most := max_batch(r)
	if button_pressed(.Right) {
		cook_count += 1
	}
	if button_pressed(.Left) {
		cook_count -= 1
	}
	cook_count = clamp(cook_count, 1, max(most, 1))
	if button_pressed(.Menu) || button_pressed(.Grab) {
		scene = .Playing
		return
	}
	if button_pressed(.Confirm) || button_pressed(.Action) {
		if most == 0 {
			cook_refused_t = 1.2
			return
		}
		o := &g.stations[cook_at]
		o.kcal = 0
		for need in r.needs {
			o.kcal += sack_take(need.item, need.count * cook_count)
		}
		o.kcal = math.round(o.kcal * cook_bonus(cook_at))
		train(STATION_SKILL[cook_at], COOK_WORK * f32(cook_count))
		sack_step(0)
		o.baking = true
		o.dish = r.dish
		o.count = cook_count
		o.bake_t = cook_time(cook_at)
		scene = .Playing
		say(STATION_START[cook_at], 1.4)
	}
}

update_stations :: proc(dt: f32) {
	for &o, at in g.stations {
		// The fire always smokes a little; the oven only while it bakes.
		o.smoke_t -= dt
		if o.smoke_t <= 0 && (at == .Fire || (at == .Camp && g.camp_up) || (at == .Oven && o.baking)) {
			o.smoke_t = o.baking ? 0.12 : 0.5
			from := at == .Oven ? Vec3{o.pos.x - 0.4, 2.15, o.pos.y - 0.35} : Vec3{o.pos.x, 0.9, o.pos.y}
			vel := Vec3{random_range(-0.2, 0.2) + 0.25, random_range(0.9, 1.4), random_range(-0.2, 0.2)}
			grey := u8(random_range(190, 235))
			spawn_particle(from, vel, random_range(1.2, 2), random_range(0.1, 0.17), {grey, grey, grey, 255}, -0.3)
		}
		if !o.baking {
			continue
		}
		o.bake_t -= dt
		if o.bake_t <= 0 {
			o.baking = false
			o.ready = true
			if length2(g.prosio.pos - o.pos) < 25 {
				say(STATION_DONE[at], 2)
			}
			burst({o.pos.x, 1.2, o.pos.y + STATION_RADIUS[at]}, 12, 3, COLOR_STAR, 0.09)
		}
	}
}

// A round brick oven on a stone base, its mouth facing the camera, with a
// chimney and a pile of logs.
draw_oven :: proc() {
	o := &g.stations[.Oven]
	if !on_screen(o.pos, 3) {
		return
	}
	m := translate({o.pos.x, 0, o.pos.y})
	set_surface(.Stone)
	tube(m, {}, OVEN_RADIUS + 0.1, 0.5, COLOR_ROCK)
	set_surface(.Solid)
	draw_shape(.Hemisphere, m * translate({0, 0.5, 0}) * scale({OVEN_RADIUS, 1.2, OVEN_RADIUS}), BRICK)
	// Rows of darker bricks round the dome.
	for row in 0 ..< 4 {
		y := 0.72 + f32(row) * 0.26
		ring := OVEN_RADIUS * math.sqrt(max(1 - ((y - 0.5) / 1.2) * ((y - 0.5) / 1.2), 0))
		for k in 0 ..< 12 {
			a := f32(k) * math.TAU / 12 + f32(row) * 0.26
			if row < 2 && math.abs(angle_diff(a, math.PI / 2)) < 0.55 {
				continue // the mouth is there
			}
			box(m * translate({math.cos(a) * ring, y, math.sin(a) * ring}) * rot_y(-a), {}, {0.06, 0.05, 0.2}, BRICK_LINE)
		}
	}
	// The mouth: an arch of dark bricks round a dark opening.
	mouth := m * translate({0, 0.5, OVEN_RADIUS - 0.2}) * rot_x(math.PI / 2)
	draw_shape(.Cylinder, mouth * scale({0.62, 0.32, 0.72}), BRICK_DARK)
	draw_shape(.Cylinder, mouth * translate({0, 0.06, 0}) * scale({0.46, 0.32, 0.56}), {44, 28, 26, 255})
	// Fire inside while it bakes.
	if o.baking {
		for k in 0 ..< 3 {
			flick := 0.75 + 0.25 * math.sin(g.time * (11 + f32(k) * 3) + f32(k))
			x := (f32(k) - 1) * 0.16
			ball(m, {x, 0.6, OVEN_RADIUS + 0.02}, {0.11 * flick, 0.17 * flick, 0.06}, k == 1 ? Color{255, 220, 90, 255} : Color{246, 120, 40, 255})
		}
	}
	// What is ready waits on the sill.
	if o.ready {
		draw_dish(m * translate({0, 0.5, OVEN_RADIUS + 0.14}), o.dish)
	}
	// Chimney at the back.
	tube(m, {-0.4, 1.25, -0.35}, 0.17, 0.9, BRICK_DARK)
	tube(m, {-0.4, 2.1, -0.35}, 0.22, 0.08, BRICK_DARK)
}

// The cooking fire, by the pond: a ring of stones round the fire, a spit
// over it on two forked sticks, and a chopping block with a cleaver, where
// what he has hunted is cut into meat. His campfire, where he set it up, is
// drawn the same.
draw_fire :: proc(at: Station_Kind = .Fire) {
	o := &g.stations[at]
	if !station_standing(at) || !on_screen(o.pos, 3) {
		return
	}
	m := translate({o.pos.x, 0, o.pos.y})
	set_surface(.Stone)
	for k in 0 ..< 8 {
		a := f32(k) * math.TAU / 8
		ball(m, {math.cos(a) * 0.62, 0.1, math.sin(a) * 0.62}, {0.2, 0.16, 0.2}, k % 2 == 0 ? COLOR_ROCK : COLOR_ROCK_LIGHT)
	}
	set_surface(.Solid)
	for k in 0 ..< 3 {
		box(m * rot_y(f32(k) * 1.05), {0, 0.1, 0}, {0.9, 0.12, 0.14}, COLOR_TRUNK)
	}
	// The flames leap up when something is cooking.
	big: f32 = o.baking ? 1.5 : 1
	for k in 0 ..< 4 {
		flick := 0.75 + 0.25 * math.sin(g.time * (11 + f32(k) * 3) + f32(k))
		ball(m, {(f32(k) - 1.5) * 0.14, 0.2 + 0.15 * flick * big, 0.06 * f32(k % 2)}, {0.12 * flick, 0.27 * flick * big, 0.12 * flick}, k % 2 == 1 ? FLAME_HOT : FLAME)
	}
	for side in ([2]f32{-1, 1}) {
		box(m, {side * 0.88, 0.5, 0}, {0.07, 1.0, 0.07}, COLOR_TRUNK)
	}
	box(m, {0, 0.98, 0}, {1.95, 0.05, 0.05}, COLOR_TRUNK)
	// What is cooking, or cooked, hangs over the fire.
	if o.baking || o.ready {
		draw_dish(m * translate({0, 1.0, 0}), o.dish)
	}
	block := m * translate(FIRE_BLOCK)
	set_surface(.Bark)
	tube(block, {}, BLOCK_RADIUS, 0.45, COLOR_TRUNK)
	set_surface(.Solid)
	tube(block, {0, 0.45, 0}, BLOCK_RADIUS - 0.03, 0.03, COLOR_PLANK)
	cleaver := block * translate({0.03, 0.47, 0}) * rot_z(0.5)
	box(cleaver, {0.1, 0.16, 0}, {0.3, 0.22, 0.03}, STEEL)
	box(cleaver, {-0.17, 0.2, 0}, {0.26, 0.06, 0.05}, COLOR_HOOF)
}

// The churn, in the goat hills: a tall wooden tub with a plunger that goes
// up and down as it churns, and a stool beside it where what it made waits.
draw_churn :: proc() {
	o := &g.stations[.Churn]
	if !on_screen(o.pos, 3) {
		return
	}
	m := translate({o.pos.x, 0, o.pos.y})
	wood := COLOR_PLANK
	draw_shape(.Frustum, m * scale({0.5, 1.1, 0.5}), wood)
	tube(m, {0, 0.2, 0}, 0.485, 0.07, COLOR_HOOF)
	tube(m, {0, 0.75, 0}, 0.39, 0.07, COLOR_HOOF)
	tube(m, {0, 1.1, 0}, 0.33, 0.05, COLOR_TRUNK)
	plunge: f32 = o.baking ? 0.18 * math.sin(g.time * 9) : 0
	tube(m, {0, 1.0 + plunge, 0}, 0.04, 0.85, COLOR_TRUNK)
	box(m, {0, 1.86 + plunge, 0}, {0.3, 0.06, 0.06}, COLOR_TRUNK)
	if o.baking && math.mod(g.time, 0.35) < 0.02 {
		burst({o.pos.x, 1.2, o.pos.y}, 1, 1.2, COLOR_WHITE, 0.05)
	}
	stool := m * translate(CHURN_STOOL)
	tube(stool, {0, 0.3, 0}, 0.3, 0.05, wood)
	for k in 0 ..< 3 {
		a := f32(k) * math.TAU / 3
		limb(stool, {math.cos(a) * 0.1, 0.3, math.sin(a) * 0.1}, {math.cos(a) * 0.26, 0, math.sin(a) * 0.26}, 0.03, COLOR_TRUNK)
	}
	if o.ready {
		draw_dish(stool * translate({0, 0.36, 0}), o.dish)
	}
}

// A baked dish, as it comes out of the oven.
draw_dish :: proc(m: Mat4, dish: Item) {
	#partial switch dish {
	case .Apple_Pie:
		// A golden crust with a lattice over red apple filling.
		tube(m, {}, 0.27, 0.09, CRUST)
		tube(m, {}, 0.22, 0.1, {200, 52, 48, 255})
		for k in 0 ..< 3 {
			off := (f32(k) - 1) * 0.12
			box(m, {off, 0.105, 0}, {0.045, 0.02, 0.42}, CRUST)
			box(m, {0, 0.11, off}, {0.42, 0.02, 0.045}, CRUST)
		}
	case .Pumpkin_Pie:
		// Orange filling in a crust, with a dollop of cream.
		tube(m, {}, 0.27, 0.09, CRUST)
		tube(m, {}, 0.23, 0.1, {226, 124, 40, 255})
		ball(m, {0, 0.13, 0}, {0.08, 0.06, 0.08}, COLOR_WHITE)
	case .Berry_Muffins:
		// Three muffins in pink paper cups, dotted with berries.
		for k in 0 ..< 3 {
			a := f32(k) * math.TAU / 3 + 0.5
			c := m * translate({math.cos(a) * 0.15, 0, math.sin(a) * 0.15})
			draw_shape(.Frustum, c * translate({0, 0.12, 0}) * rot_x(math.PI) * scale({0.1, 0.12, 0.1}), {244, 156, 176, 255})
			ball(c, {0, 0.14, 0}, {0.11, 0.08, 0.11}, {204, 142, 82, 255})
			ball(c, {0.04, 0.2, 0.03}, {0.025, 0.025, 0.025}, {124, 62, 176, 255})
			ball(c, {-0.04, 0.19, -0.02}, {0.025, 0.025, 0.025}, {124, 62, 176, 255})
		}
	case .Mushroom_Pie:
		// A domed crust with a mushroom on top.
		tube(m, {}, 0.27, 0.06, CRUST_DARK)
		draw_shape(.Hemisphere, m * translate({0, 0.05, 0}) * scale({0.25, 0.14, 0.25}), CRUST)
		tube(m, {0, 0.17, 0}, 0.03, 0.06, {240, 228, 206, 255})
		draw_shape(.Hemisphere, m * translate({0, 0.22, 0}) * scale({0.07, 0.05, 0.07}), {196, 64, 46, 255})
	case .Nut_Cake:
		// A round brown cake with nuts on top.
		tube(m, {}, 0.25, 0.15, {150, 100, 62, 255})
		tube(m, {0, 0.15, 0}, 0.25, 0.02, {196, 150, 96, 255})
		for k in 0 ..< 5 {
			a := f32(k) * math.TAU / 5
			ball(m, {math.cos(a) * 0.14, 0.19, math.sin(a) * 0.14}, {0.05, 0.04, 0.05}, {120, 78, 48, 255})
		}
	case .Fried_Egg:
		// Sunny side up.
		ball(m, {0, 0.02, 0}, {0.22, 0.03, 0.19}, COLOR_WHITE)
		ball(m, {0.02, 0.05, 0}, {0.08, 0.05, 0.08}, {250, 196, 60, 255})
	case .Grilled_Fish:
		// A browned fish, stripes from the grill across it.
		ball(m, {0, 0.07, 0}, {0.28, 0.08, 0.12}, {196, 140, 80, 255})
		draw_shape(.Cone, m * translate({-0.4, 0.07, 0}) * rot_z(-math.PI / 2) * scale({0.12, 0.18, 0.04}), {176, 120, 66, 255})
		for k in 0 ..< 3 {
			box(m, {(f32(k) - 1) * 0.12, 0.13, 0}, {0.03, 0.03, 0.2}, {96, 62, 44, 255})
		}
	case .Roast:
		// A big browned joint on the bone.
		ball(m, {0, 0.12, 0}, {0.2, 0.15, 0.17}, {176, 104, 60, 255})
		ball(m, {0.04, 0.2, 0.03}, {0.1, 0.06, 0.09}, {206, 136, 80, 255})
		limb(m, {-0.15, 0.1, 0}, {-0.36, 0.1, 0}, 0.035, COLOR_WHITE)
		ball(m, {-0.38, 0.1, 0}, {0.06, 0.06, 0.06}, COLOR_WHITE)
	case .Butter:
		// A yellow pat on a little dish.
		tube(m, {}, 0.22, 0.03, COLOR_WHITE)
		box(m, {0, 0.1, 0}, {0.28, 0.13, 0.17}, {250, 222, 110, 255})
	case .Cheese:
		// A wedge with holes in it.
		wedge := m * translate({0, 0.02, 0}) * rot_y(0.4)
		draw_shape(.Cylinder, wedge * scale({0.25, 0.17, 0.25}), {246, 200, 76, 255})
		for k in 0 ..< 3 {
			a := f32(k) * 2.1 + 0.4
			ball(wedge, {math.cos(a) * 0.12, 0.19, math.sin(a) * 0.12}, {0.035, 0.012, 0.035}, {206, 156, 50, 255})
		}
	case .Bread:
		// A long loaf with slashes across the top.
		ball(m, {0, 0.1, 0}, {0.17, 0.12, 0.3}, {216, 160, 92, 255})
		for k in 0 ..< 3 {
			box(m * translate({0, 0.2, (f32(k) - 1) * 0.12}) * rot_y(0.5), {}, {0.16, 0.02, 0.03}, CRUST_DARK)
		}
	}
}

// Small pixel pictures of everything that goes in the sack: 12 by 12, one
// letter per pixel (see icon_color).
ICONS := [Item][12]string {
	.Apple = {
		"....kk......",
		".....kbk.kk.",
		"..kkkkbkkggk",
		".krrrrkrrkk.",
		"krhrrrrrrrrk",
		"krhhrrrrrrrk",
		"krhrrrrrrrRk",
		"krrrrrrrrrRk",
		"kRrrrrrrrRRk",
		".kRrrrrrRRk.",
		"..kRRkkRRk..",
		"...kk..kk...",
	},
	.Berries = {
		".....gg.....",
		"....gGgg....",
		".....kk.....",
		"..kkkppkkk..",
		".kphpkkphpk.",
		".kpppkkpppk.",
		".kPppkkPppk.",
		"..kkkppkkk..",
		"...kphppk...",
		"...kpppPk...",
		"....kPPk....",
		".....kk.....",
	},
	.Mushroom = {
		"....kkkk....",
		"..kkrrrrkk..",
		".krrwwrrrrk.",
		".krwwrrrwwk.",
		"krrrrrrrwwrk",
		"kRrrwwrrrrRk",
		".kkkkkkkkkk.",
		"....kcck....",
		"....kcwk....",
		"....kcck....",
		"...kcccck...",
		"....kkkk....",
	},
	.Pumpkin = {
		".....kk.....",
		".....kgk....",
		"..kkkkgkkk..",
		".kooOooOook.",
		"kohoOooOoook",
		"kohoOooOoOok",
		"kooOooOooOok",
		"kooOooOooOok",
		"kOoOooOoOOOk",
		".kOOooOOOOk.",
		"..kkkkkkkk..",
		"............",
	},
	.Cabbage = {
		"............",
		"...kkkkkk...",
		".kkgGggGgkk.",
		"kGgglllggGgk",
		"kgglhlllgggk",
		"kGglllGllgGk",
		"kgglGllllggk",
		"kGgglllGggGk",
		".kGggggggGk.",
		"..kkGGGGkk..",
		"....kkkk....",
		"............",
	},
	.Nuts = {
		"............",
		"....kkk.....",
		"...knnnk....",
		"..knhnTnk...",
		"..knnTnnkkk.",
		"..kTnnnknnnk",
		"...kkkknhnTk",
		".kkk..knnTnk",
		"knnnk.kTnnnk",
		"knhTk..kkkk.",
		".kkk........",
		"............",
	},
	.Pebble = {
		"............",
		"............",
		"....kkkk....",
		"...keeeek...",
		"..keweeeEk..",
		"..keeeeEEk..",
		"..kEeeEEEk..",
		"...kEEEEk...",
		"....kkkk....",
		"............",
		"............",
		"............",
	},
	.Salt = {
		"............",
		".....kk.....",
		"....kwwk....",
		"...kwhwsk...",
		"..kwwwwssk..",
		".kkwwwsskkk.",
		"kwwkwsskwwsk",
		"kwhwkkkwhwsk",
		"kwwwwskwwssk",
		"kwwsssskwssk",
		".kkkkkkkkkk.",
		"............",
	},
	.Fish = {
		"............",
		"............",
		"...kkkk....k",
		".kkooookk.kk",
		"koooooooOkOk",
		"kokoooooOOOk",
		"koooooowOOOk",
		"kwwwwwwwOkOk",
		".kkwwwwkk.kk",
		"...kkkk....k",
		"............",
		"............",
	},
	.Meat = {
		"............",
		"..kkkkk.....",
		".krrrrrkk...",
		"krrmmrrrrk..",
		"krmmrrrRRk..",
		"krrrrrRRRk..",
		".kRrrRRRkkk.",
		"..kkRRRkwwwk",
		"....kkkkkwwk",
		".......kwwkk",
		"........kk..",
		"............",
	},
	.Milk = {
		"...kkkkkk...",
		"...kwwwwk...",
		"...kkkkkk...",
		"..kwwwwwwk..",
		".kwwwwwwwwk.",
		".kwuuuuuuwk.",
		".kwuwuuwuwk.",
		".kwuuuuuuwk.",
		".kwwwwwwwwk.",
		".kwwwwwwcck.",
		"..kkkkkkkk..",
		"............",
	},
	.Honey = {
		"............",
		"...kkkkkk...",
		"..kbbbbbbk..",
		"..kkkkkkkk..",
		".kyyyyyyyyk.",
		"kyhyyyyyyYYk",
		"kyhyyyyyyYYk",
		"kyyyyyyyYYYk",
		"kyyyyyyYYYYk",
		".kYYYYYYYYk.",
		"..kkkkkkkk..",
		"............",
	},
	.Fried_Egg = {
		"............",
		"............",
		"...kkkkk....",
		".kkwwwwwkk..",
		"kwwwwyywwwk.",
		"kwwwyyyywwwk",
		"kwwwyhyywwwk",
		"kwwwwyywwwck",
		".kwwwwwwwcck",
		"..kkwwwwckk.",
		"....kkkkk...",
		"............",
	},
	.Grilled_Fish = {
		"............",
		"............",
		"...kkkk....k",
		".kkttttkk.kk",
		"kttkttkttkTk",
		"ktkttkttkTTk",
		"kttkttkttTTk",
		"kTTTTTTTTkTk",
		".kkTTTTkk.kk",
		"...kkkk....k",
		"............",
		"............",
	},
	.Roast = {
		"............",
		"....kkkk....",
		"..kkttttkk..",
		".kttthtttTk.",
		"kttthttttTTk",
		"ktttttttTTTk",
		"kTtttttTTTTk",
		".kTTTTTTTTk.",
		"..kkkTTkkk..",
		".....kwk....",
		"....kwwwk...",
		".....kkk....",
	},
	.Butter = {
		"............",
		"............",
		"............",
		"..kkkkkkkk..",
		".kyyyyyyyYk.",
		".kyhyyyyyYk.",
		".kyyyyyyyYk.",
		".kYYYYYYYYk.",
		"kkkkkkkkkkkk",
		"kwwwwwwwwwck",
		".kkkkkkkkkk.",
		"............",
	},
	.Cheese = {
		"............",
		"............",
		".......kkk..",
		".....kkyyyk.",
		"...kkyyyyyk.",
		".kkyyyyyyyyk",
		"kyyyYyyyyyyk",
		"kyyyyyyYyyyk",
		"kyYyyyyyyyYk",
		"kyyyyyYyyyyk",
		"kkkkkkkkkkkk",
		"............",
	},
	.Wheat = {
		".y...y...y..",
		"yYy.yYy.yYy.",
		"yYy.yYy.yYy.",
		".Y...Y...Y..",
		"..Y..Y..Y...",
		"...Y.Y.Y....",
		"...kbbbbk...",
		"...Y.Y.Y....",
		"..Y..Y..Y...",
		".Y...Y...Y..",
		"Y....Y....Y.",
		"............",
	},
	.Egg = {
		"....kkkk....",
		"...kcccck...",
		"..kchcccck..",
		"..khcccdck..",
		".kchcccccck.",
		".kcccdcccck.",
		".kccccccdck.",
		".kcdcccccck.",
		".kcccccdcck.",
		"..kcccccck..",
		"...kkkkkk...",
		"............",
	},
	.Flour = {
		"....kkkk....",
		"...kwwwwk...",
		"..kkbbbbkk..",
		".kwwwwwwwwk.",
		"kwwwwwwwwwwk",
		"kwwwyywwwwwk",
		"kwwyYYywwwwk",
		"kwwwyywwwwck",
		"kwwwwwwwwcck",
		".kwwwwwwcck.",
		"..kkkkkkkk..",
		"............",
	},
	.Apple_Pie = {
		"............",
		"..kkkkkkkk..",
		".kttTttTttk.",
		"ktrTrrTrrTtk",
		"kTTTTTTTTTTk",
		"ktrTrrTrrTtk",
		"ktrTrrTrrTtk",
		"kTTTTTTTTTTk",
		".kttttttttk.",
		".kTTTTTTTTk.",
		"..kkkkkkkk..",
		"............",
	},
	.Pumpkin_Pie = {
		"............",
		"kk..........",
		"kTkk........",
		"kootkk......",
		"kooootkk....",
		"kooohootkk..",
		"koooooooootk",
		"kooooooooook",
		"kOOOOOOOOOOk",
		"kTTTTTTTTTTk",
		"kkkkkkkkkkkk",
		"............",
	},
	.Berry_Muffins = {
		"...kkkkk....",
		"..knnpnnkk..",
		".knpnnnnpnk.",
		"knnnnpnnnnnk",
		"knpnnnnnpnnk",
		"kkkkkkkkkkkk",
		".kmMmMmMmMk.",
		".kmMmMmMmMk.",
		"..kmMmMmMk..",
		"..kmMmMmMk..",
		"...kkkkkk...",
		"............",
	},
	.Mushroom_Pie = {
		"....kkkk....",
		"...krwrrk...",
		"....kcck....",
		"..kkkkkkkk..",
		".kttttttttk.",
		"kttTttttTttk",
		"ktttttttttTk",
		"kTttTttttTTk",
		"kTTTTTTTTTTk",
		".kkkkkkkkkk.",
		"............",
		"............",
	},
	.Nut_Cake = {
		"............",
		"............",
		"..kkkkkkkk..",
		".ktTtnTtntk.",
		"ktntTttnTttk",
		"kTTTTTTTTTTk",
		"kbbbbbbbbbbk",
		"kbTbbbbbbTbk",
		"kbbbbTbbbbbk",
		".kbbbbbbbbk.",
		"..kkkkkkkk..",
		"............",
	},
	.Bread = {
		"............",
		"............",
		"...kkkkkk...",
		"..kttttttk..",
		".ktTttTttTk.",
		"kttTttTttTtk",
		"ktttttttttTk",
		"kttttttttTTk",
		"kTttttttTTTk",
		".kTTTTTTTTk.",
		"..kkkkkkkk..",
		"............",
	},
	.Wood = {
		"............",
		"............",
		".kkk........",
		"kctbkkkkkk..",
		"kcTbbbbbbbkk",
		"ktTbbbnbbbbk",
		".kkbbbbbbkbk",
		"..kkkkkkknbk",
		"kkkkkkkkkbkk",
		"kcTbbbbnbbbk",
		"kctbbbbbbbkk",
		".kkkkkkkkk..",
	},
	.Fence = {
		"............",
		".kk......kk.",
		"kttk....kttk",
		"kttkkkkkkttk",
		"kttttttttttk",
		"kTTkkkkkkTTk",
		"kttk....kttk",
		"kttkkkkkkttk",
		"kttttttttttk",
		"kTTkkkkkkTTk",
		"kttk....kttk",
		"kkkk....kkkk",
	},
	.Campfire = {
		"............",
		".....kk.....",
		"....kok.....",
		"...koyok....",
		"...koyyok...",
		"..koyyyok...",
		"..kbbybbk...",
		".kkbbbbbkk..",
		"keEkEkEkEek.",
		"kEeEeEeEeEk.",
		".kkkkkkkkk..",
		"............",
	},
	.Larder = {
		"....kkkk....",
		"...kTTTTk...",
		"..kTTTTTTk..",
		".kkkkkkkkkk.",
		".kttttttttk.",
		".ktkkkkkktk.",
		".ktkttttktk.",
		".ktkttkkktk.",
		".ktkttttktk.",
		".ktkkkkkktk.",
		".kkkkkkkkkk.",
		".kk......kk.",
	},
	.Gate = {
		"............",
		".kk......kk.",
		"kTTkkkkkkTTk",
		"kTktttttttTk",
		"kTkkkkkkktTk",
		"kTk...kktkTk",
		"kTk.kktkk.Tk",
		"kTkktkk...Tk",
		"kTktkkkkkkTk",
		"kTktttttttTk",
		"kTTkkkkkkTTk",
		"kkkk....kkkk",
	},
	.Scarecrow = {
		"....kkkk....",
		"...kbbbbk...",
		"..kkkkkkkk..",
		"...kyyyyk...",
		"...kykyky...",
		"k..kyyyyk..k",
		"kkkkrrrrkkkk",
		"yyyrrrrrryyy",
		"kkkkrrrrkkkk",
		"....krrk....",
		".....bb.....",
		".....bb.....",
	},
	.Rod = {
		".........kk.",
		"........kbk.",
		".......kbkw.",
		"......kbk.w.",
		".....kbk..w.",
		"....kbk...w.",
		"...kbk....w.",
		"..kbk.....w.",
		".kbk.....kkk",
		"kbk......kok",
		"kk.......kkk",
		"............",
	},
	.Spear = {
		".........kk.",
		"........keek",
		".......keeEk",
		"......kkeEk.",
		".....kbkkk..",
		"....kbk.....",
		"...kbk......",
		"..kbk.......",
		".kbk........",
		"kbk.........",
		"kk..........",
		"............",
	},
}

icon_color :: proc(c: u8) -> (Color, bool) {
	switch c {
	case 'k': return {52, 40, 44, 255}, true
	case 'r': return {222, 44, 48, 255}, true
	case 'R': return {150, 30, 40, 255}, true
	case 'h': return {255, 214, 214, 255}, true
	case 'g': return {110, 180, 76, 255}, true
	case 'G': return {62, 124, 62, 255}, true
	case 'b': return {122, 82, 52, 255}, true
	case 'p': return {124, 62, 176, 255}, true
	case 'P': return {72, 36, 112, 255}, true
	case 'w': return {255, 255, 255, 255}, true
	case 'c': return {246, 236, 214, 255}, true
	case 'd': return {176, 136, 104, 255}, true
	case 'o': return {242, 142, 42, 255}, true
	case 'O': return {200, 100, 30, 255}, true
	case 'y': return {248, 210, 96, 255}, true
	case 'Y': return {196, 150, 50, 255}, true
	case 't': return {230, 182, 108, 255}, true
	case 'T': return {176, 120, 60, 255}, true
	case 'n': return {204, 142, 82, 255}, true
	case 'm': return {244, 156, 176, 255}, true
	case 'M': return {212, 112, 142, 255}, true
	case 'l': return {190, 226, 140, 255}, true
	case 's': return {236, 196, 204, 255}, true
	case 'u': return {110, 170, 230, 255}, true
	case 'e': return {168, 170, 166, 255}, true
	case 'E': return {116, 118, 120, 255}, true
	case 'a': return {204, 76, 30, 255}, true // steak
	case 'A': return {150, 48, 35, 255}, true // its marbling
	case 'f': return {248, 178, 130, 255}, true // its side
	case 'F': return {236, 138, 70, 255}, true // its side in shade
	}
	return {}, false
}

draw_icon :: proc(item: Item, x, y, size: f32) {
	draw_pixels(ICONS[item], x, y, size)
}

// A 12 by 12 picture, a letter a pixel (see icon_color), size across.
draw_pixels :: proc(rows: [12]string, x, y, size: f32) {
	px := size / 12
	for row, j in rows {
		for i in 0 ..< min(len(row), 12) {
			if c, ok := icon_color(row[i]); ok {
				ui_rect(x + f32(i) * px, y + f32(j) * px, px + 0.5, px + 0.5, c)
			}
		}
	}
}

SACK_SLOTS :: 6 // boxes shown at most; beyond that the sack scrolls round

// The sack, at the top of the screen from x: a box for each kind of thing
// in it, with how many under the box, and the chosen one's name and
// calories above. With more kinds than fit, the boxes go round in a circle,
// the chosen one always third.
draw_sack :: proc(x, y, s: f32) {
	p := &g.prosio
	buf: [len(Item)]Item
	owned := owned_items(&buf)
	n := len(owned)
	size := 34 * s
	gap := 6 * s
	pad := 9 * s
	text := 16 * s
	arrow := 14 * s
	scrolling := n > SACK_SLOTS
	slots := clamp(n, 1, SACK_SLOTS)

	// Wide enough for the longest name.
	widest: f32
	for it in Item {
		widest = max(widest, ui_text_width(ITEM_NAME[it], text))
	}
	boxes := f32(slots) * size + f32(slots - 1) * gap + (scrolling ? 2 * arrow : 0)
	width := max(widest, boxes) + 2 * pad
	height := pad + text + 6 * s + size + text + pad
	if n > 0 {
		height += 10 * s // how full it is
	}
	ui_round_rect(x, y, width, height, UI_PANEL, 0.2)
	centre := x + width / 2
	if n == 0 {
		label_centred("SACK: empty", centre, y + height / 2 - text / 2, text, UI_WHITE)
		return
	}

	// The name of what is chosen (its calories are on the SACK page of the
	// M menu).
	label_centred(ITEM_NAME[p.sack_sel], centre, y + pad, text)

	at := 0
	for it, i in owned {
		if it == p.sack_sel {
			at = i
		}
	}
	first := scrolling ? at - 2 : 0
	top := y + pad + text + 6 * s
	bx := centre - boxes / 2 + (scrolling ? arrow : 0)
	if scrolling {
		label("<", bx - arrow, top + size / 2 - text / 2, text, UI_YELLOW)
		label(">", bx + f32(slots) * (size + gap) - gap + 4 * s, top + size / 2 - text / 2, text, UI_YELLOW)
	}
	for k in 0 ..< slots {
		it := owned[((first + k) % n + n) % n]
		chosen := it == p.sack_sel
		if chosen {
			ui_round_rect(bx - 3 * s, top - 3 * s, size + 6 * s, size + 6 * s, UI_YELLOW, 0.25)
		}
		ui_round_rect(bx, top, size, size, SACK_BOX, 0.2)
		draw_icon(it, bx + 4 * s, top + 4 * s, size - 8 * s)
		label_centred(ui_format("%d", i32(p.sack[it])), bx + size / 2, top + size + 3 * s, text * 0.9, chosen ? UI_YELLOW : UI_WHITE)
		bx += size + gap
	}
	// How full it is: a bar along the bottom, orange when full or when the
	// load is heavy for him.
	full := clamp(sack_full(), 0, 1)
	heavy := full >= 0.99 || sack_kg() / g.prosio.kg > LOAD_HEAVY
	bar_y := top + size + text + 6 * s
	ui_rect(x + pad, bar_y, width - 2 * pad, 6 * s, UI_DARK)
	ui_rect(x + pad + 1 * s, bar_y + 1 * s, (width - 2 * pad - 2 * s) * full, 4 * s, heavy ? UI_ORANGE : Color{200, 200, 200, 255})
}

// A station's menu: what can be made there, what it needs and what it is
// worth, and how many to make at once.
draw_cook_menu :: proc() {
	sw, sh := screen_size()
	s := min(sw / 1280, sh / 720)
	ui_rect(0, 0, sw, sh, {10, 24, 20, 130})
	buf: [len(RECIPES)]^Recipe
	recipes := station_recipes(cook_at, &buf)
	row := 64 * s
	pw, ph := 940 * s, 208 * s + f32(len(recipes)) * row
	px, py := sw / 2 - pw / 2, sh / 2 - ph / 2
	ui_round_rect(px, py, pw, ph, {74, 46, 38, 240}, 0.08)
	label_centred(STATION_NAME[cook_at], sw / 2, py + 18 * s, 44 * s, UI_ORANGE)
	if cook_at != .Bench {
		// What he is called here, and how much richer that makes what he
		// makes; it grows a little with every dish, so it says how far it
		// can go.
		now := i32(math.round((cook_bonus(cook_at) - 1) * 100))
		most := i32(math.round((COOK_RANGE[cook_at][1] - 1) * 100))
		label_centred(ui_format_title("%s: +%d%% kcal   (up to +%d%%, the more you make)", cook_title(cook_at), now, most), sw / 2, py + 70 * s, 20 * s, UI_YELLOW)
	} else {
		label_centred(STATION_ABOUT[cook_at], sw / 2, py + 70 * s, 20 * s, UI_YELLOW)
	}

	y := py + 108 * s
	for r, i in recipes {
		chosen := i == cook_choice
		most := max_batch(r)
		if chosen {
			ui_round_rect(px + 18 * s, y - 7 * s, pw - 36 * s, row - 4 * s, UI_YELLOW, 0.3)
			ui_round_rect(px + 21 * s, y - 4 * s, pw - 42 * s, row - 10 * s, {118, 78, 60, 255}, 0.3)
		}
		ui_round_rect(px + 34 * s, y, 46 * s, 46 * s, SACK_BOX, 0.2)
		draw_icon(r.dish, px + 38 * s, y + 4 * s, 38 * s)
		label(ITEM_NAME[r.dish], px + 94 * s, y, 22 * s, most > 0 ? UI_WHITE : Color{200, 180, 170, 255})
		if r.at == .Bench {
			label(PLAN_ABOUT[r.dish], px + 94 * s, y + 28 * s, 14 * s, UI_YELLOW)
		} else {
			label(ui_format("%d kcal", i32(recipe_kcal(r))), px + 94 * s, y + 26 * s, 18 * s, UI_YELLOW)
		}
		if cook_bonus(r.at) != 1 {
			label(ui_format("(raw %d)", i32(recipe_kcal(r) / cook_bonus(r.at))), px + 198 * s, y + 28 * s, 14 * s, {220, 200, 180, 255})
		}
		// What it needs, for as many as are chosen.
		times := chosen ? cook_count : 1
		x := px + (r.at == .Bench ? 500 : 330) * s // (a plan has few parts, and a line saying what it is for)
		for need in r.needs {
			if need.count == 0 {
				continue
			}
			have := g.prosio.sack[need.item]
			draw_icon(need.item, x, y + 5 * s, 36 * s)
			label(ui_format2("%d/%d", i32(have), i32(need.count * times)), x + 42 * s, y + 14 * s, 20 * s, have >= need.count * times ? UI_GREEN : UI_RED)
			x += 112 * s
		}
		if chosen && most > 0 {
			// How many to make at once.
			cx := px + pw - 110 * s
			label("<", cx - 34 * s, y + 10 * s, 24 * s, cook_count > 1 ? UI_YELLOW : Color{150, 130, 120, 255})
			label_centred(ui_format("x %d", i32(cook_count)), cx + 10 * s, y + 10 * s, 24 * s)
			label(">", cx + 44 * s, y + 10 * s, 24 * s, cook_count < most ? UI_YELLOW : Color{150, 130, 120, 255})
		}
		y += row
	}
	if cook_refused_t > 0 {
		label_centred(cook_at == .Bench || cook_at == .Churn ? "Not enough in the sack for that!" : "Not enough in the sack for that! (A fire needs wood: branches lie under the forest trees.)", sw / 2, py + ph - 82 * s, 20 * s, UI_RED)
	}
	label_centred("UP / DOWN: choose     LEFT / RIGHT: how many     {Action}: make it     {Close}: close", sw / 2, py + ph - 42 * s, 18 * s, UI_YELLOW)
}

Mill :: struct {
	pos:      Vec2,
	grinding: int, // sheaves still to grind
	each:     f32, // the calories in each of them
	ready:    int, // sacks of flour waiting
	kcal:     f32, // the calories in them all
	t:        f32,
	spin:     f32, // how far round the sails are
}

mill_in_reach :: proc(pos: Vec2, r: f32) -> bool {
	return length2(g.mill.pos - pos) < MILL_RADIUS + r + 0.7
}

use_mill :: proc() {
	p := &g.prosio
	m := &g.mill
	to := m.pos - p.pos
	p.facing = math.atan2(to.x, to.y)
	switch {
	case m.ready > 0:
		taken := 0
		for m.ready > 0 && sack_room(.Flour) > 0 {
			share := m.kcal / f32(m.ready)
			sack_add(.Flour, share)
			m.kcal -= share
			m.ready -= 1
			taken += 1
		}
		if taken == 0 {
			answer("No room in my sack for flour!")
			return
		}
		p.sack_sel = .Flour
		say("Flour! Now to the oven.", 1.6)
		burst({m.pos.x, 0.8, m.pos.y + MILL_RADIUS}, 10, 2, COLOR_WHITE, 0.08)
	case m.grinding > 0:
		answer("Still grinding... round and round!")
	case p.sack[.Wheat] > 0:
		m.grinding = p.sack[.Wheat]
		m.each = sack_take(.Wheat, m.grinding) / f32(m.grinding)
		m.t = MILL_TIME
		sack_step(0)
		say("In goes the wheat!", 1.4)
	case:
		answer("The mill grinds wheat into flour. I have no wheat!")
	}
}

update_mill :: proc(dt: f32) {
	m := &g.mill
	m.spin += dt * (m.grinding > 0 ? 3.5 : 0.5)
	if m.grinding <= 0 {
		return
	}
	m.t -= dt
	if m.t <= 0 {
		m.t = MILL_TIME
		m.grinding -= 1
		m.ready += 1
		m.kcal += m.each
		burst({m.pos.x, 0.8, m.pos.y + MILL_RADIUS}, 5, 1.5, COLOR_WHITE, 0.07)
		if m.grinding == 0 && length2(g.prosio.pos - m.pos) < 14 {
			say("The flour is ready!", 1.6)
		}
	}
}

// A little windmill: a round whitewashed tower, a red cap, four sails that
// turn (fast when it is grinding), and the sacks of flour by the door.
draw_mill :: proc() {
	mill := &g.mill
	if !on_screen(mill.pos, 5) {
		return
	}
	m := translate({mill.pos.x, 0, mill.pos.y})
	set_surface(.Stone)
	tube(m, {}, MILL_RADIUS + 0.08, 0.35, COLOR_ROCK)
	set_surface(.Solid)
	draw_shape(.Frustum, m * translate({0, 0.3, 0}) * scale({MILL_RADIUS, 2.9, MILL_RADIUS}), MILL_WALL)
	cone(m, {0, 3.15, 0}, MILL_RADIUS * 0.82, 1.1, MILL_ROOF)
	// The door and a little window, facing the camera.
	box(m, {0, 0.85, MILL_RADIUS * 0.9}, {0.6, 1.1, 0.16}, COLOR_TRUNK)
	box(m, {0, 2.2, MILL_RADIUS * 0.72}, {0.32, 0.36, 0.14}, {70, 60, 62, 255})
	// The sails, on a hub at the front.
	hub := m * translate({0.0, 2.75, MILL_RADIUS * 0.72 + 0.28}) * rot_z(mill.spin)
	ball(hub, {}, {0.16, 0.16, 0.16}, COLOR_TRUNK)
	for k in 0 ..< 4 {
		sail := hub * rot_z(f32(k) * math.PI / 2)
		box(sail, {0, 1.0, 0}, {0.07, 2.0, 0.07}, COLOR_TRUNK)
		box(sail, {0.2, 1.2, 0.02}, {0.36, 1.45, 0.03}, COLOR_WHITE)
	}
	// Flour waiting to be fetched.
	for k in 0 ..< min(mill.ready, 4) {
		at := Vec3{-0.85 + f32(k) * 0.34, 0.2, MILL_RADIUS + 0.35 + 0.1 * f32(k % 2)}
		ball(m, at, {0.17, 0.22, 0.15}, COLOR_WHITE)
		ball(m, at + {0, 0.2, 0}, {0.07, 0.06, 0.07}, MILL_WALL)
	}
}
