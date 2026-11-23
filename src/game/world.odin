package game

import "core:math"

// How far beyond the edge of the meadow a place is (less than 0 inside).
beyond_edge :: proc(pos: Vec2) -> f32 {
	return max(abs(pos.x) - WORLD_HALF.x, abs(pos.y) - WORLD_HALF.y)
}

// How many of a thing the budget allows.
budget_count :: proc(item: Item) -> int {
	budget := item == .Mushroom ? MUSHROOM_BUDGET : FOOD_BUDGET
	return int(math.round(budget / RAW_KCAL[item]))
}

Round_Kind :: enum {
	Tree,
	Rock,
	Bush,
	Oven,
	Mill,
	Fire, // the cooking fire by the pond
	Churn,
	Block, // the chopping block by the fire, the stool by the churn
	Hive,
	Salt_Rock, // a big rock in the goat hills with rock salt growing on it
	Pebbles, // a patch of pebbles to fill the sack from; it lies flat, and nothing bumps into it
	Bench, // the workbench at home
	Scarecrow, // one he built and stood up (see workshop.odin)
	Larder, // one he built and stood up (see larder.odin)
	Stump, // a mossy stump or a fallen log in the forest (variant says which); low enough to jump
}

Tree_Species :: enum {
	Broadleaf,
	Apple,
	Blossom,
	Pine,
}

// A round obstacle.
Round :: struct {
	pos:     Vec2,
	r:       f32,
	kind:    Round_Kind,
	species: Tree_Species, // trees only
	fruit:   int, // apples on an apple tree, bunches of berries on a bush
	fruit_t: f32, // until the next apple or bunch starts (or a ripe apple falls)
	ripe:    f32, // how ripe its fruit is, 0 to 1
	mossy:   bool, // a rock with moss on it (most in the forest)
	variant: int, // a stump: 0 a mossy stump, 1 a plain one, 2 a fallen log
	shake_t: f32, // just shaken: the leaves are still trembling,
	shake_power: f32, // this hard (1 for a knock)
}

// The parts of the meadow, each with its own food. They are ellipses.
Region_Kind :: enum {
	Home,
	Forest,
	Fields,
	Garden,
	Turkeys,
	Hills,
	Pond,
	Bees,
}

Region :: struct {
	name:   cstring,
	about:  cstring, // what is found there
	centre: Vec2,
	radius: Vec2,
}

REGIONS := [Region_Kind]Region {
	.Home    = {"HOME", "the oven", HOME, {13, 11}},
	.Forest  = {"THE FOREST", "berries, apples, mushrooms, nuts... and foxes", {-62, -10}, {33, 50}},
	.Fields  = {"THE WHEAT FIELDS", "wheat, and the mill", {58, 26}, {27, 20}},
	.Garden  = {"THE GARDEN", "pumpkins, cabbages", {-14, 48}, {17, 15}},
	.Turkeys = {"TURKEY MEADOW", "eggs... and angry turkeys", {14, -46}, {25, 18}},
	.Hills   = {"GOAT HILLS", "rock salt, goats to milk, and the churn", {70, -42}, {26, 22}},
	.Pond    = {"THE POND", "water, fish, and the cooking fire", POND, {14, 11}},
	.Bees    = {"BEE MEADOW", "honey... and bees", {-50, 56}, {13, 9}},
}

// The region a place is in, if any.
region_at :: proc(pos: Vec2) -> (kind: Region_Kind, ok: bool) {
	for r, k in REGIONS {
		d := (pos - r.centre) / r.radius
		if d.x * d.x + d.y * d.y < 1 {
			return k, true
		}
	}
	return {}, false
}

// How deep inside a region a place is: 0 at its edge or outside, 1 at its centre.
inside_region :: proc(pos: Vec2, kind: Region_Kind) -> f32 {
	r := REGIONS[kind]
	d := (pos - r.centre) / r.radius
	return max(1 - math.sqrt(d.x * d.x + d.y * d.y), 0)
}

// A random place in a region, no further out than edge (1 is its edge).
spot_in :: proc(kind: Region_Kind, edge: f32 = 0.92) -> Vec2 {
	r := REGIONS[kind]
	a := random_range(0, math.TAU)
	k := math.sqrt(random()) * edge
	return r.centre + Vec2{math.cos(a), math.sin(a)} * r.radius * k
}

map_cell :: proc(pos: Vec2) -> (x, y: int) {
	return int((pos.x + WORLD_HALF.x) / MAP_CELL), int((pos.y + WORLD_HALF.y) / MAP_CELL)
}

explored :: proc(pos: Vec2) -> bool {
	x, y := map_cell(pos)
	return x >= 0 && x < MAP_W && y >= 0 && y < MAP_H && g.seen[y * MAP_W + x]
}

explore :: proc(pos: Vec2) {
	far := SIGHT * sight()
	reach := int(far / MAP_CELL) + 1
	cx, cy := map_cell(pos)
	for y in max(cy - reach, 0) ..= min(cy + reach, MAP_H - 1) {
		for x in max(cx - reach, 0) ..= min(cx + reach, MAP_W - 1) {
			centre := Vec2{(f32(x) + 0.5) * MAP_CELL, (f32(y) + 0.5) * MAP_CELL} - WORLD_HALF
			if length2(centre - pos) < far {
				g.seen[y * MAP_W + x] = true
			}
		}
	}
	if region, inside := region_at(pos); inside {
		g.seen_region[region] = true
	}
}

// A ploughed field of wheat or a pumpkin bed: bare soil in rows.
Field :: struct {
	lo, hi: Vec2,
	crop:   Food_Kind,
}

// Food is found, not served: wheat in the fields, pumpkins in the pumpkin
// patch, apples, berries and mushrooms in the forest, and eggs wherever the
// turkeys lay them. All of it goes into Prosio's sack (see kitchen.odin).
Food_Kind :: enum {
	Apple,
	Mushroom,
	Pumpkin,
	Wheat,
	Egg,
	Cabbage,
	Nuts, // a little heap under the forest trees; more drop on it with time
	// Not food, but lying on the ground to be picked up all the same:
	Wood, // a fallen branch under a forest tree; another falls after a while
	Spear, // a spear he threw, where it came down
}

Food :: struct {
	kind:    Food_Kind,
	pos:     Vec2,
	y, vy:   f32, // a falling apple's or egg's height and speed
	respawn: f32, // seconds until a new one sprouts; 0 means it is there
	grow:    f32, // how far it has grown, 0 (just sprouted) to 1 (full size)
	size:    f32, // its own full size, as a share of the usual
	fallen:  bool, // an apple off a tree or a laid egg: once taken (or gone off) it is gone for good
	gone:    bool, // this slot is free
	life:    f32, // a fallen apple rots away, and an egg goes, when this runs out
	tree:    int, // the tree a fallen apple came from
}

// What each becomes in the sack.
FOOD_ITEM := [Food_Kind]Item {
	.Apple    = .Apple,
	.Mushroom = .Mushroom,
	.Pumpkin  = .Pumpkin,
	.Wheat    = .Wheat,
	.Egg      = .Egg,
	.Cabbage  = .Cabbage,
	.Nuts     = .Nuts,
	.Wood     = .Wood,
	.Spear    = .Spear,
}

// Food lying on the ground, there to pick up (ripe or not).
food_ready :: proc(f: ^Food) -> bool {
	return !f.gone && f.respawn <= 0 && f.y <= 0.01
}

// The share of its full calories a thing has at this stage of growing.
ripeness :: proc(grow: f32) -> f32 {
	return lerp(UNRIPE, 1, clamp(grow, 0, 1))
}

random_size :: proc() -> f32 {
	return random_range(1 - SIZE_SPREAD, 1 + SIZE_SPREAD)
}

// The calories in this piece as it is now.
food_kcal :: proc(f: ^Food) -> f32 {
	return math.round(RAW_KCAL[FOOD_ITEM[f.kind]] * f.size * ripeness(f.grow))
}

// And in a bunch of berries picked from this bush now.
bush_kcal :: proc(b: ^Round) -> f32 {
	if b.kind == .Hive {
		return RAW_KCAL[.Honey]
	}
	if b.kind == .Salt_Rock {
		return RAW_KCAL[.Salt]
	}
	if b.kind == .Pebbles {
		return 0
	}
	return math.round(RAW_KCAL[.Berries] * ripeness(b.ripe))
}

Decor_Kind :: enum {
	Tuft, // a clump of grass (a grass model)
	Flower,
	Fern, // under the forest trees (a fern model)
	Shrub, // a low bush under the forest trees, nothing on it; he walks through
}

// Clumps of grass, flowers and ferns. Purely for looks.
Decor :: struct {
	pos:     Vec2,
	kind:    Decor_Kind,
	variant: int,
}

Particle :: struct {
	pos, vel: Vec3,
	life:     f32,
	max_life: f32,
	size:     f32,
	gravity:  f32,
	color:    Color,
}

// A rock: in the forest most are mossy, out in the open a few.
add_rock :: proc(pos: Vec2, r: f32) {
	if i := add_round(pos, r, .Rock); i >= 0 {
		g.rounds[i].mossy = (i % 4 != 0) == (inside_region(pos, .Forest) > 0)
	}
}

add_round :: proc(pos: Vec2, r: f32, kind: Round_Kind) -> int {
	if g.round_count >= MAX_ROUNDS {
		return -1
	}
	g.rounds[g.round_count] = Round{pos = pos, r = r, kind = kind}
	g.round_count += 1
	return g.round_count - 1
}

add_tree :: proc(pos: Vec2, species: Tree_Species) {
	i := add_round(pos, 0.32, .Tree)
	if i < 0 {
		return
	}
	t := &g.rounds[i]
	t.species = species
	if species == .Apple {
		t.fruit = 1 + int(random() * f32(MAX_APPLES))
		t.fruit_t = random_range(20, APPLE_REGROW.y)
		t.ripe = random_range(0.2, 1)
	}
}

// A forest tree: broadleaves and pines. (The few wild apple trees are
// planted separately, as many as the food budget allows.)
forest_species :: proc() -> Tree_Species {
	return random() < 0.42 ? .Pine : .Broadleaf
}

// A lone tree out in the meadow: no fruit out here.
meadow_species :: proc() -> Tree_Species {
	roll := random()
	switch {
	case roll < 0.25:
		return .Blossom
	case roll < 0.5:
		return .Pine
	}
	return .Broadleaf
}

// A berry bush, picked from where it stands.
add_bush :: proc(pos: Vec2) {
	i := add_round(pos, random_range(0.45, 0.6), .Bush)
	if i >= 0 {
		g.rounds[i].fruit = 1 + int(random() * f32(MAX_BERRIES))
		g.rounds[i].fruit_t = random_range(BERRY_REGROW.x, BERRY_REGROW.y)
		g.rounds[i].ripe = random_range(0.2, 1)
	}
}

add_food :: proc(kind: Food_Kind, pos: Vec2) -> ^Food {
	slot := -1
	for &f, i in g.foods[:g.food_count] {
		if f.gone {
			slot = i
			break
		}
	}
	if slot < 0 {
		if g.food_count >= MAX_FOODS {
			return nil
		}
		slot = g.food_count
		g.food_count += 1
	}
	g.foods[slot] = Food{kind = kind, pos = pos, tree = -1, grow = 1, size = random_size()}
	return &g.foods[slot]
}

// A small field with this many plants, in rows; at the start they are at
// every stage of growing.
add_field :: proc(lo, hi: Vec2, crop: Food_Kind, columns, rows: int) {
	g.fields[g.field_count] = Field{lo, hi, crop}
	g.field_count += 1
	size := hi - lo
	for row in 0 ..< rows {
		for column in 0 ..< columns {
			at := lo + size * Vec2{(f32(column) + 0.5) / f32(columns), (f32(row) + 0.5) / f32(rows)}
			if f := add_food(crop, at + {random_range(-0.1, 0.1), random_range(-0.08, 0.08)}); f != nil {
				f.grow = random_range(0.15, 1)
			}
		}
	}
}

in_field :: proc(pos: Vec2, margin: f32) -> bool {
	for f in g.fields[:g.field_count] {
		if pos.x > f.lo.x - margin && pos.x < f.hi.x + margin && pos.y > f.lo.y - margin && pos.y < f.hi.y + margin {
			return true
		}
	}
	return false
}

build_world :: proc() {
	// First everything that is built or sown, so that the trees can keep
	// out of its way. The places where things are made, each in its own part
	// of the meadow: the oven at home, the fire by the pond, the churn in
	// the goat hills, the mill by the wheat.
	g.stations[.Oven].pos = HOME + {-4, -2.5}
	g.stations[.Fire].pos = POND + {10.5, 4.5}
	g.stations[.Churn].pos = {55, -33}
	g.stations[.Bench].pos = HOME + BENCH_PLACE
	g.camp_round, g.camp_block = -1, -1 // his campfire is not set up yet (see set_up_camp)
	for st, kind in g.stations {
		if kind != .Bench && kind != .Camp { // the workbench came later: it is put in last (below)
			add_round(st.pos, STATION_RADIUS[kind], STATION_ROUND[kind])
		}
	}
	add_round(g.stations[.Fire].pos + FIRE_BLOCK.xz, BLOCK_RADIUS, .Block)
	add_round(g.stations[.Churn].pos + CHURN_STOOL.xz, 0.3, .Block)
	g.mill.pos = {43, 22}
	add_round(g.mill.pos, MILL_RADIUS, .Mill)
	// The wheat fields and the garden beds: small, as the budget allows a
	// dozen sheaves, ten pumpkins and sixteen cabbages.
	add_field({47, 13}, {52, 17}, .Wheat, 2, 2)
	add_field({56, 19}, {61, 23}, .Wheat, 2, 2)
	add_field({48, 25}, {53, 29}, .Wheat, 2, 2)
	add_field({-22, 41}, {-15, 46}, .Pumpkin, 3, 2)
	add_field({-9, 44}, {-4, 48}, .Pumpkin, 2, 2)
	add_field({-20, 51}, {-12, 57}, .Cabbage, 4, 4)
	// The bee meadow's three hives.
	for pos, i in ([MAX_HIVES]Vec2{{-54, 54}, {-46.5, 58}, {-50, 51}}) {
		add_hive(i, pos)
	}

	// The forest is trees all through, each a little way from the next,
	// thinning out towards its edge, with a trail from the path from home to
	// three clearings. The wild apple trees and most of the berry bushes are
	// in the clearings; mushrooms, nuts and fallen branches lie at the foot
	// of the trees, on the side the camera is on. (Where a tree stands in
	// front of him, it turns see-through: see tree_fade in draw.odin.)
	for placed, tries := 0, 0; placed < FOREST_TREES && tries < 30000; tries += 1 {
		pos := spot_in(.Forest, 1)
		if random() > clamp(FOREST_EDGE + inside_region(pos, .Forest) * 2.5, 0, 1) || in_clearing(pos, 1) {
			continue
		}
		if species := forest_species(); tree_spot(pos, 0.75, species) {
			add_tree(pos, species)
			placed += 1
		}
	}
	for placed, tries := 0, 0; placed < budget_count(.Apple) / MAX_APPLES && tries < 6000; tries += 1 {
		// In a clearing, or failing that anywhere in the forest.
		pos := tries < 4000 ? CLEARINGS[tries % len(CLEARINGS)] + random_in_circle(CLEARING_RADIUS - 1.5) : spot_in(.Forest, 0.95)
		if tree_spot(pos, 3, .Apple) && !hidden_by_tree(pos) {
			add_tree(pos, .Apple)
			placed += 1
		}
	}
	for placed, tries := 0, 0; placed < budget_count(.Berries) / MAX_BERRIES && tries < 8000; tries += 1 {
		// Two in three round the clearings, the rest wherever there is light.
		pos := placed % 3 != 2 ? CLEARINGS[tries % len(CLEARINGS)] + random_in_circle(CLEARING_RADIUS + 2) : spot_in(.Forest, 1.02)
		if clear_spot(pos, 1.1) && !hidden_by_tree(pos) {
			add_bush(pos)
			placed += 1
		}
	}
	scatter_under_trees(.Mushroom, budget_count(.Mushroom))
	scatter_under_trees(.Nuts, budget_count(.Nuts))

	// Mossy stumps and fallen logs between the forest trees, off the paths
	// and out of the clearings.
	for placed, tries := 0, 0; placed < FOREST_STUMPS && tries < 4000; tries += 1 {
		pos := spot_in(.Forest, 0.95)
		probe := pos
		if in_clearing(pos, 2) || on_a_path(pos, 2.2) || length2(pos - HOME) < 15 {
			continue
		}
		if hit, _ := collide_static(&probe, STUMP_RADIUS + 0.8, 0, true); hit {
			continue
		}
		if i := add_round(pos, STUMP_RADIUS, .Stump); i >= 0 {
			g.rounds[i].variant = placed % 3
			placed += 1
		}
	}

	// A few shady trees round the fields.
	for placed, tries := 0, 0; placed < 8 && tries < 800; tries += 1 {
		pos := spot_in(.Fields, 1.05)
		if tree_spot(pos, 2, .Broadleaf) {
			add_tree(pos, .Broadleaf)
			placed += 1
		}
	}

	// The goat hills: rocks large and small, a few pines, and the big rocks
	// the salt grows on, out in the open.
	for placed, tries := 0, 0; placed < 34 && tries < 2000; tries += 1 {
		pos := spot_in(.Hills, 0.98)
		size := random() < 0.3 ? random_range(0.9, 1.5) : random_range(0.35, 0.8)
		if clear_spot(pos, size + 1.2) {
			add_rock(pos, size)
			placed += 1
		}
	}
	for placed, tries := 0, 0; placed < 10 && tries < 800; tries += 1 {
		pos := spot_in(.Hills, 0.95)
		if tree_spot(pos, 2, .Pine) {
			add_tree(pos, .Pine)
			placed += 1
		}
	}
	for placed, tries := 0, 0; placed < SALT_ROCKS && tries < 800; tries += 1 {
		pos := spot_in(.Hills, 0.8)
		if clear_spot(pos, SALT_ROCK_RADIUS + 1.5) && !hidden_by_tree(pos) {
			if i := add_round(pos, SALT_ROCK_RADIUS, .Salt_Rock); i >= 0 {
				g.rounds[i].fruit = 1 + placed % MAX_SALT
				g.rounds[i].fruit_t = random_range(SALT_REGROW.x, SALT_REGROW.y)
				g.rounds[i].ripe = 1
			}
			placed += 1
		}
	}

	// A few blossom trees in the bee meadow.
	for placed, tries := 0, 0; placed < 4 && tries < 800; tries += 1 {
		pos := spot_in(.Bees, 1)
		if tree_spot(pos, 3.5, .Blossom) {
			add_tree(pos, .Blossom)
			placed += 1
		}
	}

	// The pond, with a few trees leaning over it.
	for placed, tries := 0, 0; placed < 5 && tries < 800; tries += 1 {
		pos := spot_in(.Pond, 1)
		if length2(pos - POND) > POND_RADIUS + 1.5 && tree_spot(pos, 2, .Broadleaf) {
			add_tree(pos, .Broadleaf)
			placed += 1
		}
	}

	// Turkey meadow: open grass with a few shady trees.
	for placed, tries := 0, 0; placed < 9 && tries < 800; tries += 1 {
		pos := spot_in(.Turkeys, 0.95)
		if species := meadow_species(); tree_spot(pos, 3, species) {
			add_tree(pos, species)
			placed += 1
		}
	}

	// The open meadow in between: lone trees and rocks, but no food.
	for placed, tries := 0, 0; placed < 60 && tries < 4000; tries += 1 {
		pos := random_spot()
		species := meadow_species()
		if _, in_region := region_at(pos); !in_region && tree_spot(pos, 2.5, species) {
			add_tree(pos, species)
			placed += 1
		}
	}
	for placed, tries := 0, 0; placed < 40 && tries < 3000; tries += 1 {
		pos := random_spot()
		if region, in_region := region_at(pos); (!in_region || region == .Turkeys) && clear_spot(pos, 2) {
			add_rock(pos, random_range(0.3, 0.7))
			placed += 1
		}
	}

	spawn_enemies()
	spawn_fish()
	spawn_pests()

	// Patches of pebbles, last of all, so that they change nothing else about
	// the meadow.
	for count, kind in PEBBLE_PATCHES {
		for placed, tries := 0, 0; placed < count && tries < 400; tries += 1 {
			pos := kind == .Home ? HOME + facing_dir(random_range(0, math.TAU)) * random_range(13.5, 17) : spot_in(kind, 0.85)
			if kind == .Pond {
				pos = POND + facing_dir(random_range(0, math.TAU)) * (POND_RADIUS + random_range(1.5, 3))
			}
			if (kind == .Home || clear_spot(pos, PEBBLE_PATCH_RADIUS + 0.8)) && !hidden_by_tree(pos) && !in_field(pos, 1) {
				if i := add_round(pos, PEBBLE_PATCH_RADIUS, .Pebbles); i >= 0 {
					g.rounds[i].fruit = MAX_PEBBLES
					g.rounds[i].ripe = 1
				}
				placed += 1
			}
		}
	}

	// Fallen branches under the forest trees, and the workbench at home:
	// they too came after everything else, and leave it as it was.
	scatter_under_trees(.Wood, WOOD_LYING)
	add_round(g.stations[.Bench].pos, STATION_RADIUS[.Bench], .Bench)

	// Scatter grass, flowers and, in the forest, ferns where nothing else
	// stands (and grass and ferns not on the paths).
	w := WORLD_HALF
	for tries := 0; g.decor_count < MAX_DECOR && tries < MAX_DECOR * 3; tries += 1 {
		pos := Vec2{random_range(-w.x + 0.5, w.x - 0.5), random_range(-w.y + 0.5, w.y - 0.5)}
		probe := pos
		if hit, _ := collide_static(&probe, 0.5, 0, true); hit || in_field(pos, 0.3) {
			continue
		}
		roll := g.decor_count % 20
		kind: Decor_Kind = roll < 6 ? .Flower : .Tuft
		if inside_region(pos, .Forest) > 0 {
			kind = roll < 2 ? .Flower : (roll < 10 ? .Fern : (roll < 13 ? .Shrub : .Tuft)) // the forest floor is mostly ferns, with low bushes
		}
		if inside_region(pos, .Bees) > 0 {
			kind = .Flower // the bee meadow is all flowers
		}
		if kind != .Flower && on_a_path(pos, 1.6) {
			continue
		}
		g.decor[g.decor_count] = Decor {
			pos     = pos,
			kind    = kind,
			variant = g.decor_count,
		}
		g.decor_count += 1
	}
}

// Things that lie on the forest floor at the foot of the trees: always on
// the side the camera is on, and never behind another tree.
scatter_under_trees :: proc(kind: Food_Kind, count: int) {
	for placed, tries := 0, 0; placed < count && tries < 6000; tries += 1 {
		t := g.rounds[int(random() * f32(g.round_count)) % g.round_count]
		if t.kind != .Tree || inside_region(t.pos, .Forest) <= 0 {
			continue
		}
		pos := t.pos + Vec2{random_range(-1.4, 1.4), random_range(0.7, 1.9)}
		if region, ok := region_at(pos); !ok || region != .Forest {
			continue // (a tree at the forest's edge: its foot is out in the meadow)
		}
		if clear_spot(pos, 0.3) && !hidden_by_tree(pos) && food_in_reach(pos, 0.4) == nil {
			if f := add_food(kind, pos); f != nil {
				f.grow = random_range(0.15, 1)
			}
			placed += 1
		}
	}
}

in_clearing :: proc(pos: Vec2, margin: f32) -> bool {
	for c in CLEARINGS {
		if length2(pos - c) < CLEARING_RADIUS + margin {
			return true
		}
	}
	return false
}

// On a path from home, or on a forest trail, with this much to spare.
on_a_path :: proc(pos: Vec2, reach: f32) -> bool {
	for kind in Region_Kind {
		if kind != .Home && near_segment(pos, HOME, PATH_ENDS[kind], reach) {
			return true
		}
	}
	for t in TRAILS {
		if near_segment(pos, t[0], t[1], reach - 0.6) {
			return true
		}
	}
	return false
}

random_in_circle :: proc(r: f32) -> Vec2 {
	a := random_range(0, math.TAU)
	return Vec2{math.cos(a), math.sin(a)} * r * math.sqrt(random())
}

// The strip a tree hides: from near to far north of its trunk, and this far
// to either side.
tree_cover :: proc(t: Tree_Shape) -> (near, far, half_width: f32) {
	low, high := foliage(t)
	if t.species == .Pine {
		// A pine's tip is too thin to hide much.
		return low * VIEW_SLOPE - 0.4, high * 0.86 * VIEW_SLOPE, t.canopy * 0.75 + 0.3
	}
	return low * VIEW_SLOPE - 0.6, high * VIEW_SLOPE, t.canopy + 0.4
}

// Would a tree of this species, planted here next, hide something?
hides_something :: proc(pos: Vec2, species: Tree_Species) -> bool {
	near, far, half := tree_cover(tree_shape_of(species, g.round_count))
	for d := near; d <= far; d += 1 {
		behind := pos - {0, d} // a spot its leaves would cover
		if in_field(behind, half - 0.5) {
			return true
		}
		for kind in Region_Kind {
			// (A forest trail may run under the trees: they turn see-through
			// round him as he walks it.)
			if kind != .Home && near_segment(behind, HOME, PATH_ENDS[kind], half) {
				return true
			}
		}
		if species != .Apple && in_clearing(behind, half - 1) {
			return true // a clearing stays in view, with its apple trees and bushes
		}
		for rd in g.rounds[:g.round_count] {
			if rd.kind != .Tree && rd.kind != .Rock && length2(behind - rd.pos) < rd.r + half {
				return true
			}
		}
		for &f in g.foods[:g.food_count] {
			if !f.gone && length2(behind - f.pos) < half {
				return true
			}
		}
	}
	return false
}

hidden_by_tree :: proc(pos: Vec2) -> bool {
	for rd, i in g.rounds[:g.round_count] {
		if rd.kind != .Tree || abs(rd.pos.x - pos.x) > 3 {
			continue
		}
		near, far, half := tree_cover(tree_shape(i))
		south := rd.pos.y - pos.y
		if south > near && south < far && abs(rd.pos.x - pos.x) < half {
			return true
		}
	}
	return false
}

// A free spot where a tree would be in nobody's way.
tree_spot :: proc(pos: Vec2, r: f32, species: Tree_Species) -> bool {
	if inside_region(pos, .Forest) > 0 {
		// In the forest no tree crowds the next.
		for rd in g.rounds[:g.round_count] {
			if rd.kind == .Tree && length2(rd.pos - pos) < FOREST_SPACING {
				return false
			}
		}
	}
	return clear_spot(pos, r) && !hides_something(pos, species)
}

random_spot :: proc() -> Vec2 {
	w := WORLD_HALF
	return {random_range(-w.x + 2, w.x - 2), random_range(-w.y + 2, w.y - 2)}
}

// True if a spot is free: nothing solid within r, not on a field, and not
// where home or the paths need to stay open.
clear_spot :: proc(pos: Vec2, r: f32) -> bool {
	if length2(pos - HOME) < 12 + r || in_field(pos, r + 0.5) {
		return false
	}
	if on_a_path(pos, 2.2 + r) {
		return false
	}
	for e in g.enemies[:g.enemy_count] {
		if length2(pos - e.home) < r + 1.5 {
			return false
		}
	}
	probe := pos
	hit, _ := collide_static(&probe, r, 0, true)
	return !hit
}

near_segment :: proc(p, a, b: Vec2, reach: f32) -> bool {
	ab := b - a
	t := clamp(dot2(p - a, ab) / max(dot2(ab, ab), 1e-6), 0, 1)
	return length2(p - (a + ab * t)) < reach
}

// Keeps a circle out of everything solid: trees, rocks, bushes, the oven,
// the mill, pumpkins, the pond, and the fence round the meadow.
//
// feet is how high off the ground the circle is: things fly or jump over
// obstacles lower than that.
//
// The fences he has put up stop animals, and whatever else is not Prosio
// (enemy is true for all of those), unless it is in the air above them or
// is being carried over (over_fences). He himself steps over them.
collide_static :: proc(pos: ^Vec2, r: f32, feet: f32, enemy := false, over_fences := false, wet := false, edge := true) -> (hit: bool, normal: Vec2) {
	// Two passes, so a push out of one thing cannot leave the circle inside another.
	for _ in 0 ..< 2 {
		if !over_fences && g.fence_count > 0 && feet < FENCE_TOP {
			if h, n := push_out_fences(pos, r); h {
				hit, normal = true, n
			}
		}
		for i in 0 ..< g.round_count {
			rd := &g.rounds[i]
			if rd.r <= 0 || abs(rd.pos.x - pos.x) > rd.r + r || abs(rd.pos.y - pos.y) > rd.r + r {
				continue
			}
			top: f32
			switch rd.kind {
			case .Tree:
				top = 3
			case .Rock:
				top = rd.r * 1.05
			case .Bush:
				top = 0.8
			case .Oven:
				top = 2.2
			case .Mill:
				top = 4
			case .Pebbles:
				continue // flat on the ground
			case .Fire, .Hive, .Salt_Rock, .Bench:
				top = 1.1
			case .Scarecrow:
				top = 1.9
			case .Larder:
				top = 1.4
			case .Churn:
				top = 1.3
			case .Block:
				top = 0.5
			case .Stump:
				top = FENCE_TOP // he jumps it as he jumps a fence
			}
			if feet >= top {
				continue
			}
			if h, n := push_out_circle(pos, r, rd.pos, rd.r); h {
				hit, normal = true, n
			}
		}
		for &f in g.foods[:g.food_count] {
			if f.kind != .Pumpkin || !food_ready(&f) || feet >= 0.6 {
				continue
			}
			if h, n := push_out_circle(pos, r, f.pos, FOOD_SIZE[f.kind] * lerp(0.5, 1, f.grow)); h {
				hit, normal = true, n
			}
		}
		if feet < 0.6 && !wet {
			// The water's edge: his toes get wet, no more. (Something thrown
			// can land in it: see Swimming in enemies.odin.)
			if h, n := push_out_circle(pos, r, POND, POND_RADIUS - 0.5); h {
				hit, normal = true, n
			}
		}
		lim := edge ? WORLD_HALF - {r, r} : Vec2{1e9, 1e9} // (a thrown animal may sail on into the fog)
		if pos.x < -lim.x {
			pos.x = -lim.x
			hit, normal = true, {1, 0}
		}
		if pos.x > lim.x {
			pos.x = lim.x
			hit, normal = true, {-1, 0}
		}
		if pos.y < -lim.y {
			pos.y = -lim.y
			hit, normal = true, {0, 1}
		}
		if pos.y > lim.y {
			pos.y = lim.y
			hit, normal = true, {0, -1}
		}
	}
	return
}

// The nearest food Prosio can reach, if any.
food_in_reach :: proc(pos: Vec2, reach: f32) -> ^Food {
	best: ^Food
	best_dist := reach
	for &f in g.foods[:g.food_count] {
		if !food_ready(&f) {
			continue
		}
		d := length2(f.pos - pos) - FOOD_SIZE[f.kind]
		if d < best_dist {
			best, best_dist = &f, d
		}
	}
	return best
}

// At the water's edge, near enough to drink.
// In the water itself.
in_pond :: proc(pos: Vec2) -> bool {
	return length2(pos - POND) < POND_RADIUS - 0.4
}

pond_in_reach :: proc(pos: Vec2, r: f32) -> bool {
	return length2(POND - pos) < POND_RADIUS + r + 0.4
}

// The nearest bush with berries on it, hive with honey in it or rock with
// salt on it that Prosio can reach, if any.
bush_in_reach :: proc(pos: Vec2, reach: f32) -> ^Round {
	best: ^Round
	best_dist := reach
	for &b in g.rounds[:g.round_count] {
		if (b.kind != .Bush && b.kind != .Hive && b.kind != .Salt_Rock && b.kind != .Pebbles) || b.fruit <= 0 {
			continue
		}
		d := length2(b.pos - pos) - b.r
		if d < best_dist {
			best, best_dist = &b, d
		}
	}
	return best
}

// How many bunches, combs or lumps one bush, hive or salt rock holds, and how
// long until it has another.
plant_max :: proc(kind: Round_Kind) -> int {
	#partial switch kind {
	case .Hive:
		return MAX_HONEY
	case .Salt_Rock:
		return MAX_SALT
	case .Pebbles:
		return MAX_PEBBLES
	}
	return MAX_BERRIES
}

plant_regrow :: proc(kind: Round_Kind) -> Vec2 {
	#partial switch kind {
	case .Hive:
		return HONEY_REGROW
	case .Salt_Rock:
		return SALT_REGROW
	case .Pebbles:
		return PEBBLE_REGROW
	}
	return BERRY_REGROW
}

// An apple comes loose from tree t and falls from somewhere in its crown,
// on the side the camera is on, where it can be seen.
drop_apple :: proc(t: int) {
	tree := &g.rounds[t]
	if tree.fruit <= 0 {
		return
	}
	shape := tree_shape(t)
	for tries in 0 ..< 6 {
		a := random_range(0.2, math.PI - 0.2)
		pos := tree.pos + Vec2{math.cos(a), math.sin(a)} * random_range(0.6, shape.canopy * 0.85)
		probe := pos
		if hit, _ := collide_static(&probe, 0.15, 0, true); hit && tries < 5 {
			continue
		}
		f := add_food(.Apple, probe)
		if f == nil {
			return
		}
		f.fallen = true
		f.life = APPLE_LIFE
		f.tree = t
		f.grow = tree.ripe // an apple shaken down early is small and green
		f.y = shape.canopy_y - shape.canopy * 0.5
		tree.fruit -= 1
		return
	}
}

eggs_lying :: proc() -> (n: int) {
	for &f in g.foods[:g.food_count] {
		if !f.gone && f.kind == .Egg {
			n += 1
		}
	}
	return
}

// An egg drops from a turkey at this place and height.
drop_egg :: proc(pos: Vec2, height: f32) -> bool {
	if eggs_lying() >= MAX_EGGS {
		return false
	}
	probe := pos
	collide_static(&probe, 0.12, 0, true)
	f := add_food(.Egg, probe)
	if f == nil {
		return false
	}
	f.fallen = true
	f.life = EGG_LIFE
	f.y = max(height, 0.05)
	return true
}

// Something hit the trees near pos this hard: they shake, and apple trees
// drop some of their apples.
shake_trees_near :: proc(pos: Vec2, reach: f32, strength: f32) {
	for &t, i in g.rounds[:g.round_count] {
		if t.kind != .Tree || length2(t.pos - pos) > reach + t.r {
			continue
		}
		t.shake_t = 0.6
		t.shake_power = 1
		shape := tree_shape(i)
		burst({t.pos.x, shape.canopy_y, t.pos.y}, 6, 2, COLOR_LEAF, 0.09)
		for _ in 0 ..< min(t.fruit, 1 + int(strength / 4)) {
			drop_apple(i)
		}
	}
}

// The tree he is right up against and facing, if there is one.
tree_in_front :: proc(facing: Vec2) -> (index: int, ok: bool) {
	p := &g.prosio
	r := prosio_radius(p.kg)
	best := TREE_SHAKE_REACH
	for t, i in g.rounds[:g.round_count] {
		if t.kind != .Tree || t.r <= 0 {
			continue
		}
		to := t.pos - p.pos
		gap := length2(to) - t.r - r
		if gap > best || abs(angle_diff(math.atan2(to.x, to.y), math.atan2(facing.x, facing.y))) > TREE_SHAKE_ANGLE {
			continue
		}
		best, index, ok = gap, i, true
	}
	return
}

// He takes hold of the tree and shakes it, for this much stamina.
shake_tree :: proc(index: int, cost: f32) {
	p := &g.prosio
	t := &g.rounds[index]
	power := strength()
	to := t.pos - p.pos
	p.facing = math.atan2(to.x, to.y)
	p.vel = {}
	p.shake_t = TREE_SHAKE_TIME
	p.shake_power = power
	p.stamina -= cost
	p.regen_delay = 0.6
	burn(FIGHT_BURN, .Fighting, true)
	train(.Arms, SWING_WORK * 0.3)
	t.shake_t = TREE_SHAKE_TIME
	t.shake_power = 1.6 * power
	shape := tree_shape(index)
	burst({t.pos.x, shape.canopy_y, t.pos.y}, 4 + int(8 * power), 2 + power, COLOR_LEAF, 0.09)
	for _ in 0 ..< min(t.fruit, int(TREE_SHAKE_APPLES * power + 0.5)) {
		drop_apple(index)
	}
	say(power > 1.3 ? "SHAKE SHAKE SHAKE!" : (power < 0.8 ? "Shake... shake..." : "Shake shake!"), 1.2)
}

update_world :: proc(dt: f32) {
	for &f in g.foods[:g.food_count] {
		if f.gone {
			continue
		}
		if f.fallen {
			// Falling, with a little bounce, then lying until it goes.
			if f.y > 0 || f.vy != 0 {
				f.vy -= GRAVITY * dt
				f.y += f.vy * dt
				if f.y <= 0 {
					f.y = 0
					f.vy = f.vy < -3 ? -f.vy * 0.3 : 0
					if f.vy == 0 {
						burst({f.pos.x, 0.1, f.pos.y}, 2, 1, COLOR_DUST, 0.06)
					}
				}
			}
			f.life -= dt
			if f.life <= 0 {
				f.gone = true
			}
			continue
		}
		if f.respawn > 0 {
			f.respawn -= dt
			// Nothing sprouts under someone standing there.
			if f.respawn <= 0 {
				crowded := length2(g.prosio.pos - f.pos) < prosio_radius(g.prosio.kg) + FOOD_SIZE[f.kind] + 0.1
				for &e in g.enemies[:g.enemy_count] {
					if e.state != .Gone && length2(e.pos - f.pos) < ENEMY_RADIUS[e.kind] + FOOD_SIZE[f.kind] + 0.1 {
						crowded = true
					}
				}
				if crowded {
					f.respawn = 0.3
				} else {
					f.respawn = 0
					f.grow = FOOD_GROW[f.kind] > 0 ? 0 : 1
					f.size = random_size()
					burst({f.pos.x, 0.2, f.pos.y}, 4, 1.2, COLOR_LEAF_LIGHT, 0.06)
				}
			}
		} else if FOOD_GROW[f.kind] > 0 {
			f.grow = min(f.grow + dt / FOOD_GROW[f.kind], 1)
		}
	}
	// Berries and apples ripen where they hang. A picked bush starts another
	// bunch after a while; a tree starts another apple while it has fewer
	// than MAX_APPLES (counting those lying under it), and now and then a
	// ripe one drops.
	for &t, i in g.rounds[:g.round_count] {
		t.shake_t = max(t.shake_t - dt, 0)
		if t.kind == .Bush {
			if t.fruit > 0 {
				t.ripe = min(t.ripe + dt / BERRY_GROW, 1)
			}
			if t.fruit < MAX_BERRIES {
				t.fruit_t -= dt
				if t.fruit_t <= 0 {
					t.ripe = t.ripe * f32(t.fruit) / f32(t.fruit + 1) // the new bunch is green
					t.fruit += 1
					t.fruit_t = random_range(BERRY_REGROW.x, BERRY_REGROW.y)
				}
			}
		}
		if (t.kind == .Hive || t.kind == .Salt_Rock || t.kind == .Pebbles) && t.fruit < plant_max(t.kind) {
			// The bees fill another comb; another lump of salt grows.
			t.fruit_t -= dt
			if t.fruit_t <= 0 {
				t.fruit += 1
				t.fruit_t = random_range(plant_regrow(t.kind).x, plant_regrow(t.kind).y)
			}
		}
		if t.kind == .Tree && t.species == .Apple {
			if t.fruit > 0 {
				t.ripe = min(t.ripe + dt / APPLE_GROW, 1)
			}
			t.fruit_t -= dt
			if t.fruit_t <= 0 {
				t.fruit_t = random_range(APPLE_REGROW.x, APPLE_REGROW.y)
				lying := 0
				for &f in g.foods[:g.food_count] {
					if !f.gone && f.fallen && f.tree == i {
						lying += 1
					}
				}
				if t.fruit + lying < MAX_APPLES {
					t.ripe = t.ripe * f32(t.fruit) / f32(t.fruit + 1)
					t.fruit += 1
				} else if t.fruit > 0 && t.ripe >= 1 {
					drop_apple(i)
				}
			}
		}
	}
	update_stations(dt)
	update_critters(dt)
	update_mill(dt)
	g.shake = max(g.shake - dt * 2.5, 0)
}

spawn_particle :: proc(pos, vel: Vec3, life, size: f32, color: Color, gravity: f32 = 14) {
	g.particles[g.particle_next] = Particle{pos, vel, life, life, size, gravity, color}
	g.particle_next = (g.particle_next + 1) % MAX_PARTICLES
}

// A puff of particles flying outwards from a point.
burst :: proc(pos: Vec3, count: int, speed: f32, color: Color, size: f32) {
	for _ in 0 ..< count {
		a := random_range(0, math.TAU)
		s := random_range(0.4, 1) * speed
		vel := Vec3{math.cos(a) * s, random_range(0.5, 1.2) * speed, math.sin(a) * s}
		spawn_particle(pos, vel, random_range(0.4, 0.9), size * random_range(0.7, 1.3), color)
	}
}

update_particles :: proc(dt: f32) {
	for &p in g.particles {
		if p.life <= 0 {
			continue
		}
		p.life -= dt
		p.vel.y -= p.gravity * dt
		p.pos += p.vel * dt
		if p.pos.y < 0.05 {
			p.pos.y = 0.05
			p.vel = {}
		}
	}
}
