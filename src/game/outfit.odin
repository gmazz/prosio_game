package game

import "core:math"

// Prosio's clothes, and the menu (M) where he looks in his sack, at his
// body, changes his clothes and looks at the map.
//
// Under everything he is a whole naked pig. Clothes go on in layers, each a
// little bigger than what is under it, so that nothing underneath ever pokes
// through: skin, then what is on his legs and his shirt, then whatever he
// wears over the shirt. One choice in each row; the rows are grouped by
// where they go on him, and any piece goes with any other. The first row
// puts on a whole outfit at once.

Hair :: enum u8 {
	Tuft,
	None,
	Long_Black,
	Shaggy,
	Bowl,
	Grey,
}
Hat :: enum u8 {
	Headband,
	None,
	Straw_Hat,
	Top_Hat,
	Beanie,
	Crown,
	Flying_Cap,
	Chef_Hat,
}
Glasses :: enum u8 {
	None,
	Round,
	Sunglasses,
	Monocle,
	Nerd,
	Eyepatch,
}
Face :: enum u8 {
	None,
	Moustache,
	Beard,
	Lipstick,
	Scar,
	Stubble,
}
Earrings :: enum u8 {
	None,
	Ears,
	Nose,
	Both,
}
Neck :: enum u8 {
	Kerchief,
	None,
	Scarf,
	Tie,
	Bow_Tie,
}
Shirt :: enum u8 {
	Jacket,
	None,
	T_Shirt,
	Sailor,
	Band_Tee,
	Computer_Tee,
	Turtleneck,
	White_Shirt,
	Pirate_Top,
	Chef_Jacket,
}
Over :: enum u8 {
	None,
	Gilet,
	Coat,
	Leather,
	Trench,
	Cape,
	Apron,
}
Legwear :: enum u8 {
	Shorts,
	None,
	Jeans,
	Skirt,
	Leather,
	Cords,
	Checks,
}
Footwear :: enum u8 {
	Hooves,
	Sneakers,
	Trainers,
	Boots,
	Black_Boots,
	Sandals,
}

Outfit :: struct {
	hair:     Hair,
	hat:      Hat,
	glasses:  Glasses,
	face:     Face,
	earrings: Earrings,
	neck:     Neck,
	shirt:    Shirt,
	over:     Over,
	legs:     Legwear,
	feet:     Footwear,
}

// What he wears. Kept outside Game, so it stays the same in a new game.
outfit: Outfit

// Whole outfits, put on with the first row. Any piece can then be changed.
Preset :: enum {
	Explorer,
	Metalhead,
	Eighties_Nerd,
	Keynote,
	Aviator,
	Space_Pirate,
	Chef,
	Bare,
}
PRESET_NAME := [Preset]cstring {
	.Explorer      = "Explorer",
	.Metalhead     = "Metalhead",
	.Eighties_Nerd = "80s computer kid",
	.Keynote       = "Black turtleneck",
	.Aviator       = "Aviator",
	.Space_Pirate  = "Space pirate",
	.Chef          = "Chef",
	.Bare          = "Bare pig",
}
PRESETS := [Preset]Outfit {
	.Explorer      = {},
	.Metalhead     = {hair = .Long_Black, hat = .None, earrings = .Both, neck = .None, shirt = .Band_Tee, over = .Leather, legs = .Leather, feet = .Black_Boots},
	.Eighties_Nerd = {hair = .Bowl, hat = .None, glasses = .Nerd, neck = .Bow_Tie, shirt = .Computer_Tee, legs = .Cords, feet = .Sneakers},
	.Keynote       = {hair = .Grey, hat = .None, glasses = .Round, face = .Stubble, neck = .None, shirt = .Turtleneck, legs = .Jeans, feet = .Trainers},
	.Aviator       = {hair = .None, hat = .Flying_Cap, glasses = .Sunglasses, face = .Moustache, neck = .Scarf, shirt = .White_Shirt, over = .Trench, legs = .Cords, feet = .Boots},
	.Space_Pirate  = {hair = .Shaggy, hat = .None, glasses = .Eyepatch, face = .Scar, neck = .None, shirt = .Pirate_Top, over = .Cape, legs = .Leather, feet = .Black_Boots},
	.Chef          = {hair = .None, hat = .Chef_Hat, face = .Moustache, neck = .Kerchief, shirt = .Chef_Jacket, over = .Apron, legs = .Checks, feet = .Sneakers},
	.Bare          = {hair = .Tuft, hat = .None, neck = .None, shirt = .None, legs = .None},
}

// Which whole outfit he has on, if it is exactly one of them.
worn_preset :: proc() -> (preset: Preset, whole: bool) {
	for look, which in PRESETS {
		if look == outfit {
			return which, true
		}
	}
	return {}, false
}

Outfit_Row :: enum {
	Preset,
	Hair,
	Hat,
	Glasses,
	Face,
	Earrings,
	Neck,
	Shirt,
	Over,
	Legs,
	Feet,
}

ROW_NAME := [Outfit_Row]cstring {
	.Preset   = "Whole outfit",
	.Hair     = "Hair",
	.Hat      = "Hat",
	.Glasses  = "Glasses",
	.Face     = "Face",
	.Earrings = "Rings",
	.Neck     = "Neck",
	.Shirt    = "Shirt",
	.Over     = "On top",
	.Legs     = "Legs",
	.Feet     = "Feet",
}
// The heading over the first row of each part of him.
ROW_SECTION := #partial [Outfit_Row]cstring {
	.Hair  = "HEAD",
	.Neck  = "TORSO",
	.Legs  = "LEGS",
	.Feet  = "FEET",
}

HAIR_NAME := [Hair]cstring{.Tuft = "A tuft", .None = "Bald", .Long_Black = "Long and black", .Shaggy = "Long and shaggy", .Bowl = "Bowl cut", .Grey = "Short and grey"}
HAT_NAME := [Hat]cstring{.Headband = "Headband", .None = "Nothing", .Straw_Hat = "Straw hat", .Top_Hat = "Top hat", .Beanie = "Woolly hat", .Crown = "Crown", .Flying_Cap = "Flying cap", .Chef_Hat = "Chef's hat"}
GLASSES_NAME := [Glasses]cstring{.None = "None", .Round = "Round glasses", .Sunglasses = "Sunglasses", .Monocle = "Monocle", .Nerd = "Big square glasses", .Eyepatch = "Eyepatch"}
FACE_NAME := [Face]cstring{.None = "Nothing", .Moustache = "Moustache", .Beard = "Beard", .Lipstick = "Lipstick", .Scar = "Scar", .Stubble = "Grey stubble"}
EARRINGS_NAME := [Earrings]cstring{.None = "None", .Ears = "Earrings", .Nose = "Nose ring", .Both = "Ears and nose"}
NECK_NAME := [Neck]cstring{.Kerchief = "Kerchief", .None = "Nothing", .Scarf = "White scarf", .Tie = "Red tie", .Bow_Tie = "Bow tie"}
SHIRT_NAME := [Shirt]cstring {
	.Jacket       = "Explorer jacket",
	.None         = "Nothing",
	.T_Shirt      = "Red T-shirt",
	.Sailor       = "Sailor shirt",
	.Band_Tee     = "Band T-shirt",
	.Computer_Tee = "Computer T-shirt",
	.Turtleneck   = "Black turtleneck",
	.White_Shirt  = "White shirt",
	.Pirate_Top   = "Skull and bones",
	.Chef_Jacket  = "Chef's jacket",
}
OVER_NAME := [Over]cstring{.None = "Nothing", .Gilet = "Gilet", .Coat = "Long coat", .Leather = "Leather jacket", .Trench = "Trench coat", .Cape = "Cape", .Apron = "Apron"}
LEGS_NAME := [Legwear]cstring{.Shorts = "Shorts", .None = "Nothing", .Jeans = "Jeans", .Skirt = "Skirt", .Leather = "Black leather", .Cords = "Brown cords", .Checks = "Grey checks"}
FEET_NAME := [Footwear]cstring{.Hooves = "Bare hooves", .Sneakers = "White sneakers", .Trainers = "Grey trainers", .Boots = "Brown boots", .Black_Boots = "Tall black boots", .Sandals = "Sandals"}

// Steps one row's choice on, or back, round in a circle.
cycle :: proc(value: ^$T, step: int) {
	n := len(T)
	value^ = T((int(value^) + step + n) % n)
}

change_outfit :: proc(row: Outfit_Row, step: int) {
	switch row {
	case .Preset:
		// On from the one he has on; from a mixture, to the first.
		which, whole := worn_preset()
		if whole {
			cycle(&which, step)
		}
		outfit = PRESETS[which]
	case .Hair:     cycle(&outfit.hair, step)
	case .Hat:      cycle(&outfit.hat, step)
	case .Glasses:  cycle(&outfit.glasses, step)
	case .Face:     cycle(&outfit.face, step)
	case .Earrings: cycle(&outfit.earrings, step)
	case .Neck:     cycle(&outfit.neck, step)
	case .Shirt:    cycle(&outfit.shirt, step)
	case .Over:     cycle(&outfit.over, step)
	case .Legs:     cycle(&outfit.legs, step)
	case .Feet:     cycle(&outfit.feet, step)
	}
}

outfit_choice :: proc(row: Outfit_Row) -> cstring {
	switch row {
	case .Preset:
		which, whole := worn_preset()
		return whole ? PRESET_NAME[which] : "A mixture"
	case .Hair:     return HAIR_NAME[outfit.hair]
	case .Hat:      return HAT_NAME[outfit.hat]
	case .Glasses:  return GLASSES_NAME[outfit.glasses]
	case .Face:     return FACE_NAME[outfit.face]
	case .Earrings: return EARRINGS_NAME[outfit.earrings]
	case .Neck:     return NECK_NAME[outfit.neck]
	case .Shirt:    return SHIRT_NAME[outfit.shirt]
	case .Over:     return OVER_NAME[outfit.over]
	case .Legs:     return LEGS_NAME[outfit.legs]
	case .Feet:     return FEET_NAME[outfit.feet]
	}
	return ""
}

// The menu: M opens and closes it, and the game waits meanwhile.
Bag_Tab :: enum {
	Sack,
	Body,
	Outfit,
	Map,
}
BAG_TAB_NAME := [Bag_Tab]cstring{.Sack = "SACK", .Body = "BODY", .Outfit = "OUTFIT", .Map = "MAP"}
bag_tab: Bag_Tab
bag_row: Outfit_Row
bag_item: Item
bag_facing: f32 // which way Prosio faced; he turns round to show his outfit
SACK_COLUMNS :: 8

open_bag :: proc() {
	scene = .Bag
	bag_item = g.prosio.sack_sel
	bag_facing = g.prosio.facing
}

close_bag :: proc() {
	scene = .Playing
	g.prosio.facing = bag_facing
}

update_bag :: proc(dt: f32) {
	if button_pressed(.Bag) || button_pressed(.Menu) {
		close_bag()
		return
	}
	if button_pressed(.Sack_Next) {
		cycle(&bag_tab, 1)
	}
	if button_pressed(.Sack_Prev) {
		cycle(&bag_tab, -1)
	}
	switch bag_tab {
	case .Sack:
		i := int(bag_item)
		n := len(Item)
		if button_pressed(.Right) {i = (i + 1) % n}
		if button_pressed(.Left) {i = (i + n - 1) % n}
		if button_pressed(.Down) && i + SACK_COLUMNS < n {i += SACK_COLUMNS}
		if button_pressed(.Up) && i - SACK_COLUMNS >= 0 {i -= SACK_COLUMNS}
		bag_item = Item(i)
		if button_pressed(.Confirm) || button_pressed(.Action) || button_pressed(.Eat) {
			if g.prosio.sack[bag_item] > 0 {
				g.prosio.sack_sel = bag_item
				eat_from_sack()
			}
		}
	case .Outfit:
		rows := len(Outfit_Row)
		if button_pressed(.Down) {bag_row = Outfit_Row((int(bag_row) + 1) % rows)}
		if button_pressed(.Up) {bag_row = Outfit_Row((int(bag_row) + rows - 1) % rows)}
		if button_pressed(.Right) {change_outfit(bag_row, 1)}
		if button_pressed(.Left) {change_outfit(bag_row, -1)}
		// He turns slowly round, to show himself off.
		g.prosio.facing += dt * 0.9
	case .Map, .Body:
	}
}

draw_bag :: proc() {
	sw, sh := screen_size()
	s := min(sw / 1280, sh / 720)
	x, y := 24 * s, 24 * s
	w, h := 520 * s, sh - 48 * s
	ui_round_rect(x, y, w, h, {28, 36, 32, 225}, 0.05)

	// The tabs.
	tx := x + 20 * s
	for tab in Bag_Tab {
		name := BAG_TAB_NAME[tab]
		tw := ui_text_width(name, 24 * s) + 28 * s
		if tab == bag_tab {
			ui_round_rect(tx, y + 16 * s, tw, 40 * s, {250, 172, 182, 235}, 0.4)
			ui_text(name, tx + 14 * s, y + 25 * s, 24 * s, UI_DARK)
		} else {
			label(name, tx + 14 * s, y + 25 * s, 24 * s, {200, 200, 200, 255})
		}
		tx += tw + 8 * s
	}

	top := y + 80 * s
	switch bag_tab {
	case .Sack:
		draw_bag_sack(x + 20 * s, top, w - 40 * s, s)
		label_centred("ARROWS: choose    E: eat    Z / C: other panel    M: close", x + w / 2, y + h - 36 * s, 15 * s, UI_YELLOW)
	case .Outfit:
		draw_bag_outfit(x + 20 * s, top, w - 40 * s, s)
		label_centred("UP/DOWN: row    LEFT/RIGHT: change    Z/C: panel    M: close", x + w / 2, y + h - 36 * s, 15 * s, UI_YELLOW)
	case .Body:
		draw_bag_body(x + 20 * s, top, w - 40 * s, s)
		label_centred("Z / C: other panel    M: close", x + w / 2, y + h - 36 * s, 15 * s, UI_YELLOW)
	case .Map:
		draw_bag_map(x + 20 * s, top, w - 40 * s, s)
		label_centred("Z / C: other panel    M: close", x + w / 2, y + h - 36 * s, 15 * s, UI_YELLOW)
	}
}

MAP_FOG :: Color{24, 28, 34, 255}
MAP_GRASS :: Color{98, 152, 76, 255}
MAP_FOREST :: Color{58, 96, 56, 255}
MAP_HILLS :: Color{156, 152, 104, 255}
MAP_PATH :: Color{196, 172, 124, 255}
MAP_SOIL :: Color{132, 96, 64, 255}
MAP_WHEAT :: Color{214, 178, 88, 255}
MAP_WATER :: Color{80, 150, 210, 255}

// The meadow from above. Only what Prosio has seen is shown; the rest is
// dark. On what he has seen: the ground of each part of the meadow, paths
// and fields, and where the trees, bushes, rocks, pumpkins and the oven are,
// with the names of the parts he has been to, and himself.
draw_bag_map :: proc(x, y, w, s: f32) {
	cell := w / MAP_W
	to_map :: proc(pos: Vec2, x, y, cell: f32) -> Vec2 {
		return {x, y} + (pos + WORLD_HALF) / MAP_CELL * cell
	}
	ui_rect(x - 3 * s, y - 3 * s, w + 6 * s, cell * MAP_H + 6 * s, UI_DARK)
	for cy in 0 ..< MAP_H {
		for cx in 0 ..< MAP_W {
			color := MAP_FOG
			if g.seen[cy * MAP_W + cx] {
				centre := Vec2{(f32(cx) + 0.5) * MAP_CELL, (f32(cy) + 0.5) * MAP_CELL} - WORLD_HALF
				color = MAP_GRASS
				if region, inside := region_at(centre); inside {
					#partial switch region {
					case .Forest:
						color = MAP_FOREST
					case .Hills:
						color = MAP_HILLS
					}
				}
				for kind in Region_Kind {
					if kind != .Home && near_segment(centre, HOME, PATH_ENDS[kind], 1.4) {
						color = MAP_PATH
					}
				}
				if length2(centre - HOME) < 4.5 {
					color = MAP_PATH
				}
				if length2(centre - POND) < POND_RADIUS {
					color = MAP_WATER
				}
				for f in g.fields[:g.field_count] {
					if centre.x > f.lo.x && centre.x < f.hi.x && centre.y > f.lo.y && centre.y < f.hi.y {
						color = f.crop == .Wheat ? MAP_WHEAT : MAP_SOIL
					}
				}
			}
			ui_rect(x + f32(cx) * cell, y + f32(cy) * cell, cell + 0.5, cell + 0.5, color)
		}
	}
	// What stands on the ground he has seen.
	for r in g.rounds[:g.round_count] {
		if r.r <= 0 || !explored(r.pos) {
			continue
		}
		at := to_map(r.pos, x, y, cell)
		switch r.kind {
		case .Tree:
			ui_circle(at.x, at.y, 2.6 * s, r.species == .Pine ? Color{30, 76, 58, 255} : Color{40, 104, 50, 255})
			if r.species == .Apple {
				ui_circle(at.x, at.y, 1.2 * s, {222, 44, 48, 255})
			}
		case .Bush:
			ui_circle(at.x, at.y, 2 * s, {76, 130, 64, 255})
			ui_circle(at.x, at.y, 0.9 * s, BERRY_COLOR)
		case .Rock:
			ui_circle(at.x, at.y, max(r.r / MAP_CELL * cell, 1.5 * s), {160, 164, 158, 255})
		case .Oven:
			ui_rect(at.x - 4 * s, at.y - 4 * s, 8 * s, 8 * s, BRICK)
		case .Mill:
			ui_rect(at.x - 4 * s, at.y - 4 * s, 8 * s, 8 * s, COLOR_WHITE)
		case .Fire:
			ui_rect(at.x - 4 * s, at.y - 4 * s, 8 * s, 8 * s, FLAME)
		case .Churn:
			ui_rect(at.x - 4 * s, at.y - 4 * s, 8 * s, 8 * s, COLOR_PLANK)
		case .Hive:
			ui_circle(at.x, at.y, 3 * s, HONEY_GOLD)
		case .Salt_Rock:
			ui_circle(at.x, at.y, 3.5 * s, {160, 164, 158, 255})
			ui_rect(at.x - 2 * s, at.y - 2 * s, 4 * s, 4 * s, SALT_PINK)
		case .Block:
		}
	}
	for &f in g.foods[:g.food_count] {
		if !food_ready(&f) || !explored(f.pos) {
			continue
		}
		at := to_map(f.pos, x, y, cell)
		#partial switch f.kind {
		case .Pumpkin:
			ui_circle(at.x, at.y, 1.6 * s, {242, 142, 42, 255})
		case .Cabbage:
			ui_circle(at.x, at.y, 1.4 * s, {176, 216, 124, 255})
		}
	}
	// The names of the parts of the meadow he has been to.
	for r, kind in REGIONS {
		if g.seen_region[kind] {
			at := to_map(r.centre, x, y, cell)
			label_centred(r.name, at.x, at.y - 7 * s, 14 * s, UI_WHITE)
		}
	}
	// And himself, blinking.
	p := &g.prosio
	at := to_map(p.pos, x, y, cell)
	ui_circle(at.x, at.y, 6 * s, UI_DARK)
	ui_circle(at.x, at.y, 4.5 * s, math.mod(g.time, 0.8) < 0.5 ? Color{250, 172, 182, 255} : UI_WHITE)
	ahead := at + facing_dir(p.facing) * 9 * s
	ui_circle(ahead.x, ahead.y, 2 * s, UI_DARK)

	label("The dark parts are still to explore.", x, y + cell * MAP_H + 14 * s, 18 * s, {200, 200, 200, 255})
}

// Everything that can be in the sack, gathered or baked, and how many.
draw_bag_sack :: proc(x, y, w, s: f32) {
	p := &g.prosio
	size := 50 * s
	gap := (w - size * SACK_COLUMNS) / (SACK_COLUMNS - 1)
	for it in Item {
		i := int(it)
		bx := x + f32(i % SACK_COLUMNS) * (size + gap)
		by := y + f32(i / SACK_COLUMNS) * (size + 28 * s)
		count := p.sack[it]
		if it == bag_item {
			ui_round_rect(bx - 5 * s, by - 5 * s, size + 10 * s, size + 10 * s, UI_YELLOW, 0.2)
		}
		ui_round_rect(bx, by, size, size, count > 0 ? SACK_BOX : Color{120, 116, 108, 255}, 0.2)
		draw_icon(it, bx + 5 * s, by + 5 * s, size - 10 * s)
		if count == 0 {
			ui_round_rect(bx, by, size, size, {60, 60, 60, 140}, 0.2) // none yet: greyed
		}
		label_centred(ui_format("%d", i32(count)), bx + size / 2, by + size + 4 * s, 16 * s, count > 0 ? UI_WHITE : Color{150, 150, 150, 255})
	}
	// The chosen one: what it is worth, and what is in it.
	rows := (len(Item) + SACK_COLUMNS - 1) / SACK_COLUMNS
	info := y + f32(rows) * (size + 28 * s) + 10 * s
	defer draw_content(bag_item, x, info + 100 * s, w, s)
	label(ITEM_NAME[bag_item], x, info, 28 * s)
	kcal := sack_piece_kcal(bag_item)
	label(ui_format("%d kcal", i32(kcal)), x, info + 36 * s, 22 * s, UI_YELLOW)
	switch {
	case !edible(bag_item):
		how: cstring = "Not to eat raw: the fire by the pond cooks it"
		if bag_item == .Wheat {
			how = "Not to eat: the mill grinds it into flour"
		} else if bag_item == .Flour {
			how = "Not to eat: bake it in the oven"
		}
		label(how, x, info + 66 * s, 18 * s, {220, 200, 180, 255})
	case:
		// What it weighs going in: the sum of what is listed below.
		// (Each part rounded as it is shown below, so that they add up.)
		meal := piece_meal(bag_item)
		grams: i32
		for kg in ([5]f32{meal.carbs, meal.fat, meal.protein, meal.fibre, meal.water}) {
			grams += i32(math.round(kg * 100))
		}
		label(ui_format2(grams < 0 ? "-%d.%02d kg" : "+%d.%02d kg", abs(grams) / 100, abs(grams) % 100), x + 170 * s, info + 36 * s, 22 * s, grams < 0 ? UI_RED : UI_GREEN)
		if bag_item >= FIRST_DISH && STATION_BONUS[recipe_for(bag_item).at] > 1 {
			label("Cooked: +40% kcal", x, info + 66 * s, 18 * s, {220, 200, 180, 255})
		}
	}
}

// What one piece of this puts into him: the kilograms of each part, which
// add up to what it weighs going in, and the two things that weigh nothing.
draw_content :: proc(item: Item, x, y, w, s: f32) {
	if !edible(item) {
		return
	}
	m := piece_meal(item)
	label("IN ONE OF THESE:", x, y, 16 * s, UI_ORANGE)
	Line :: struct {
		name:  cstring,
		kg:    f32,
		color: Color,
	}
	lines := [?]Line {
		{"CARBS", m.carbs, PART_COLOR[.Carbs]},
		{"FAT", m.fat, PART_COLOR[.Fat]},
		{"PROTEIN", m.protein, PART_COLOR[.Protein]},
		{"FIBRE", m.fibre, PART_COLOR[.Fibre]},
		{"WATER", m.water, PART_COLOR[.Water]},
	}
	shown := 0
	place :: proc(shown: int, x, y, w, s: f32) -> (cx, cy: f32) {
		return x + f32(shown % 2) * w / 2, y + 26 * s + f32(shown / 2) * 24 * s
	}
	for line in lines {
		hundredths := i32(math.round(line.kg * 100))
		if hundredths == 0 {
			continue
		}
		cx, cy := place(shown, x, y, w, s)
		ui_rect(cx, cy + 4 * s, 10 * s, 10 * s, line.color)
		label(line.name, cx + 16 * s, cy, 18 * s)
		sign: cstring = hundredths < 0 ? "-%d.%02d kg" : "+%d.%02d kg"
		label(ui_format2(sign, abs(hundredths) / 100, abs(hundredths) % 100), cx + 122 * s, cy, 18 * s, hundredths > 0 ? UI_GREEN : UI_RED)
		shown += 1
	}
	points := [2]f32{m.vitamins, m.salts}
	names := [2]cstring{"VITAMINS", "ELECTROLYTES"}
	for amount, i in points {
		if i32(math.round(amount)) == 0 {
			continue
		}
		cx, cy := place(shown, x, y, w, s)
		label(names[i], cx, cy, 18 * s)
		label(ui_format("%+d", i32(math.round(amount))), cx + 172 * s, cy, 18 * s, UI_GREEN)
		shown += 1
	}
	if shown == 0 {
		label("nothing much", x, y + 26 * s, 18 * s, {200, 200, 200, 255})
	}
}

// What Prosio is made of and what he has got good at: his fat, his two
// muscles and his skills, each with which way it is going, what makes it
// grow and what it is good for.
draw_bag_body :: proc(x, y, w, s: f32) {
	p := &g.prosio
	GREY :: Color{200, 200, 200, 255}
	trend_word :: proc(change: f32, x, y, size: f32) {
		if change > 0.0005 {
			label("growing", x, y, size, UI_GREEN)
		} else if change < -0.0005 {
			label("fading", x, y, size, UI_ORANGE)
		}
	}
	// What he weighs, as the sum of his parts: the bar, and each part's
	// kilograms under it.
	label(weight_text("HE WEIGHS %d.%d kg"), x, y, 22 * s)
	label("the sum of:", x + 248 * s, y + 5 * s, 15 * s, GREY)
	draw_weight_stack(x, y + 30 * s, w, 14 * s, s)
	for part in Part {
		i := int(part)
		px := x + f32(i % 4) * w / 4
		py := y + 52 * s + f32(i / 4) * 19 * s
		ui_rect(px, py + 3 * s, 9 * s, 9 * s, PART_COLOR[part])
		label(PART_NAME[part], px + 13 * s, py, 11 * s, GREY)
		label(kg_text(part_kg(part)), px + 70 * s, py, 12 * s)
	}
	if p.fat_trend > 0.01 {
		label("getting fatter", x + w - 100 * s, y + 5 * s, 13 * s, UI_ORANGE)
	} else if p.fat_trend < -0.01 {
		label("getting thinner", x + w - 108 * s, y + 5 * s, 13 * s, UI_GREEN)
	}

	ry := y + 94 * s
	bar_x := x + 108 * s
	bar_w := 190 * s
	for t in Trait {
		if t == .Arms {
			label("MUSCLE", x, ry, 15 * s, UI_ORANGE)
			ry += 21 * s
		}
		if t == .Lungs {
			label("SKILLS", x, ry, 15 * s, UI_ORANGE)
			ry += 21 * s
		}
		level := p.trait[t]
		label(TRAIT_NAME[t], x, ry, 18 * s)
		ui_rect(bar_x - 2 * s, ry + 2 * s, bar_w + 4 * s, 13 * s, UI_DARK)
		if is_muscle(t) {
			// Wasted at the left, ordinary at the mark, built to the right.
			ordinary := bar_x + bar_w * 0.25
			ui_rect(bar_x, ry + 4 * s, bar_w * 0.25, 9 * s, UI_ORANGE)
			ui_rect(ordinary, ry + 4 * s, bar_w * 0.75, 9 * s, {96, 110, 120, 255})
			if level > 0 {
				ui_rect(ordinary, ry + 4 * s, bar_w * 0.75 * level, 9 * s, MUSCLE_RED)
			}
			at := level >= 0 ? ordinary + bar_w * 0.75 * level : ordinary + bar_w * 0.25 * level
			ui_rect(at - 1.5 * s, ry + 1 * s, 3 * s, 15 * s, UI_WHITE)
			kg := muscle_kg(t)
			label(ui_format2("%d.%d kg", i32(kg), i32(kg * 10) % 10), bar_x + bar_w + 10 * s, ry, 16 * s)
		} else {
			ui_rect(bar_x, ry + 4 * s, bar_w, 9 * s, {96, 110, 120, 255})
			ui_rect(bar_x, ry + 4 * s, bar_w * level, 9 * s, NEED_POWER)
		}
		trend_word(p.trend[t], x + w - 66 * s, ry + 1 * s, 15 * s)
		label(TRAIT_GROWS[t], x + 10 * s, ry + 21 * s, 13 * s, GREY)
		label(TRAIT_GIVES[t], x + 10 * s, ry + 36 * s, 13 * s, UI_YELLOW)
		ry += 54 * s
	}
}

// The outfit, row by row, grouped by where it goes on him.
draw_bag_outfit :: proc(x, y, w, s: f32) {
	ry := y - 6 * s
	for row in Outfit_Row {
		if section := ROW_SECTION[row]; section != nil {
			label(section, x, ry + 4 * s, 15 * s, UI_ORANGE)
			ry += 22 * s
		}
		chosen := row == bag_row
		if chosen {
			ui_round_rect(x - 8 * s, ry - 5 * s, w + 16 * s, 33 * s, {118, 78, 60, 255}, 0.3)
		}
		size := 19 * s
		label(ROW_NAME[row], x + 10 * s, ry + 1 * s, size, chosen ? UI_YELLOW : UI_WHITE)
		choice := outfit_choice(row)
		cw := ui_text_width(choice, size)
		right := x + w - 10 * s
		label(choice, right - 26 * s - cw, ry + 1 * s, size, row == .Preset ? UI_GREEN : UI_WHITE)
		if chosen {
			label("<", right - 50 * s - cw, ry + 1 * s, size, UI_YELLOW)
			label(">", right - 12 * s, ry + 1 * s, size, UI_YELLOW)
		}
		ry += (row == .Preset ? 44 : 35) * s
	}
}

// Colours of his clothes.
STRAW :: Color{232, 200, 120, 255}
HAT_BLACK :: Color{48, 44, 52, 255}
WOOL :: Color{86, 140, 210, 255}
GLASS_FRAME :: Color{52, 44, 48, 255}
HAIR :: Color{122, 78, 58, 255}
HAIR_BLACK :: Color{42, 38, 46, 255}
HAIR_GREY :: Color{176, 176, 184, 255}
LIPSTICK :: Color{214, 40, 70, 255}
TSHIRT :: Color{214, 72, 62, 255}
SAILOR :: Color{246, 244, 236, 255}
NAVY :: Color{50, 70, 130, 255}
GILET :: Color{142, 96, 62, 255}
COAT :: Color{82, 116, 88, 255}
DENIM :: Color{76, 104, 156, 255}
SKIRT :: Color{226, 120, 150, 255}
SNEAKER :: Color{246, 244, 238, 255}
BOOT :: Color{112, 74, 52, 255}
LEATHER :: Color{46, 42, 50, 255}
TRENCH :: Color{198, 166, 114, 255}
CORDS :: Color{150, 100, 62, 255}
CHECKS :: Color{170, 172, 182, 255}
TEE_BLACK :: Color{40, 38, 46, 255}
TEE_CREAM :: Color{238, 228, 204, 255}
CAPE_RED :: Color{176, 42, 50, 255}
TRAINER :: Color{152, 156, 166, 255}
SOLE :: Color{70, 60, 60, 255}

LAYER :: f32(0.02) // how much bigger each layer of clothes is than what is under it

Sleeves :: enum {
	None,
	Short,
	Long,
}

// What each shirt is like: its colour and its hem's, its sleeves, whether it
// comes down over his belly (the others stop above it, and his belly pokes
// out), and how the shader paints it.
Shirt_Look :: struct {
	color, hem: Color,
	sleeves:    Sleeves,
	long:       bool,
	surface:    Surface,
}
SHIRT_LOOK := [Shirt]Shirt_Look {
	.Jacket       = {COLOR_SHIRT, {175, 115, 60, 255}, .Short, false, .Jacket},
	.None         = {},
	.T_Shirt      = {TSHIRT, {172, 58, 50, 255}, .Short, false, .Solid},
	.Sailor       = {SAILOR, NAVY, .Short, false, .Stripes},
	.Band_Tee     = {TEE_BLACK, TEE_BLACK, .Short, true, .Solid},
	.Computer_Tee = {TEE_CREAM, TEE_CREAM, .Short, true, .Solid},
	.Turtleneck   = {TEE_BLACK, TEE_BLACK, .Long, true, .Solid},
	.White_Shirt  = {SAILOR, SAILOR, .Long, true, .Solid},
	.Pirate_Top   = {LEATHER, LEATHER, .Long, true, .Solid},
	.Chef_Jacket  = {SAILOR, SAILOR, .Long, true, .Solid},
}

Over_Look :: struct {
	color:   Color,
	sleeves: Sleeves,
}
OVER_LOOK := [Over]Over_Look {
	.None    = {},
	.Gilet   = {GILET, .None},
	.Coat    = {COAT, .Long},
	.Leather = {LEATHER, .Long},
	.Trench  = {TRENCH, .Long},
	.Cape    = {LEATHER, .None},
	.Apron   = {SAILOR, .None},
}

LEG_COLOR := [Legwear]Color {
	.Shorts  = COLOR_SHORTS,
	.None    = {},
	.Jeans   = DENIM,
	.Skirt   = SKIRT,
	.Leather = LEATHER,
	.Cords   = CORDS,
	.Checks  = CHECKS,
}

long_trousers :: proc() -> bool {
	return outfit.legs == .Jeans || outfit.legs == .Leather || outfit.legs == .Cords || outfit.legs == .Checks
}

// A coat that closes right round him, down past his hips.
closed_coat :: proc() -> bool {
	return outfit.over == .Coat || outfit.over == .Trench
}

// How far his outermost clothes stand out from his body: for what he
// carries on his back.
clothes_thickness :: proc() -> f32 {
	layers: f32 = outfit.shirt != .None ? 1 : 0
	if outfit.over != .None && outfit.over != .Apron {
		layers += 1.5
	}
	return layers * LAYER
}

// Letters three squares wide and five high, a bit a square, top row first.
glyph :: proc(letter: u8) -> [5]u8 {
	switch letter {
	case 'T': return {0b111, 0b010, 0b010, 0b010, 0b010}
	case 'O': return {0b111, 0b101, 0b101, 0b101, 0b111}
	case 'L': return {0b100, 0b100, 0b100, 0b100, 0b111}
	case 'C': return {0b111, 0b100, 0b100, 0b100, 0b111}
	case '6': return {0b111, 0b100, 0b111, 0b101, 0b111}
	case '4': return {0b101, 0b101, 0b111, 0b001, 0b001}
	}
	return {}
}

// A word printed across his chest in little squares, following the curve of
// the cloth: at x from the middle the cloth is at z_centre + z_radius *
// sqrt(1 - (x / x_radius)^2). (Squares that fall under a jacket are hidden
// by it.)
draw_print :: proc(frame: Mat4, text: string, y, square, z_centre, z_radius, x_radius: f32, color: Color) {
	outlines_enabled = false
	defer outlines_enabled = true
	columns := len(text) * 4 - 1
	for i in 0 ..< len(text) {
		rows := glyph(text[i])
		for row, j in rows {
			for bit in 0 ..< 3 {
				if row & (0b100 >> uint(bit)) == 0 {
					continue
				}
				x := (f32(i * 4 + bit) - f32(columns - 1) / 2) * square
				along := x / x_radius
				z := z_centre + z_radius * math.sqrt(max(1 - along * along, 0))
				box(frame, {x, y + (2 - f32(j)) * square, z}, {square * 1.05, square * 1.05, square * 0.6}, color)
			}
		}
	}
}

// The shirt over his chest (and, if it is a long one, his belly), and
// whatever he wears over the shirt. skin is his own colour, for what shows
// where a jacket hangs open over nothing.
draw_torso_outfit :: proc(m, jacket: Mat4, jacket_w, jacket_h, chest, belly_w, belly_y, belly_mid, belly_out, hips, swing: f32, skin: Color) {
	shirt := SHIRT_LOOK[outfit.shirt]
	// Where the front of his clothes is, for what is worn or printed on it:
	// see draw_print.
	front_y := jacket_h * 0.42
	z_centre, z_radius, x_radius: f32 = 0, jacket_w * 0.91 + 0.004, jacket_w * 0.91
	if outfit.shirt != .None {
		set_surface(shirt.surface)
		draw_shape(.Hemisphere, jacket * scale({jacket_w, jacket_h, jacket_w}), shirt.color)
		set_surface(.Solid)
		if shirt.long {
			ball(m, {0, belly_mid, belly_out}, {belly_w + LAYER, belly_y + LAYER, belly_w + LAYER}, shirt.color)
		} else {
			draw_shape(.Cylinder, jacket * scale({jacket_w, 0.044, jacket_w}), shirt.hem)
		}
	}
	#partial switch outfit.shirt {
	case .Sailor:
		ball(m, {0, 1.36, -chest * 0.5}, {chest * 0.8, 0.07, chest * 0.5}, NAVY) // the square collar behind
	case .Turtleneck:
		tube(m, {0, 1.37, 0.02}, chest * 0.5, 0.11, shade(TEE_BLACK, 1.12)) // the roll neck
	case .White_Shirt:
		for side in ([2]f32{-1, 1}) {
			ball(jacket, {side * jacket_w * 0.2, jacket_h * 0.9, jacket_w * 0.38}, {0.1, 0.05, 0.09}, COLOR_WHITE) // collar points
		}
	case .Chef_Jacket:
		// Two rows of buttons down the front.
		for k in 0 ..< 6 {
			y := jacket_h * (0.62 - 0.2 * f32(k / 2))
			r := jacket_w * math.sqrt(max(1 - (y / jacket_h) * (y / jacket_h), 0))
			x := (f32(k % 2) - 0.5) * jacket_w * 0.44
			ball(jacket, {x, y, math.sqrt(max(r * r - x * x, 0)) + 0.005}, {0.028, 0.028, 0.02}, {96, 100, 112, 255})
		}
	}

	// What goes over the shirt. An open jacket shows what is under it down
	// the front; a closed coat covers him right down past his hips.
	under := outfit.shirt != .None ? shirt.color : skin
	w2, h2 := jacket_w + 2 * LAYER, jacket_h + LAYER
	over := OVER_LOOK[outfit.over]
	switch outfit.over {
	case .None:
	case .Gilet, .Leather:
		draw_shape(.Hemisphere, jacket * scale({w2, h2, w2}), over.color)
		draw_shape(.Cylinder, jacket * scale({w2, 0.05, w2}), shade(over.color, 0.75))
		// (A leather jacket hangs wide open, a gilet only a little.)
		gap: f32 = outfit.over == .Leather ? 0.62 : 0.4
		ball(jacket, {0, h2 * 0.4, w2 * 0.62}, {w2 * gap, h2 * 0.55, w2 * 0.42}, under)
		z_centre, z_radius, x_radius = w2 * 0.62, w2 * 0.42 + 0.004, w2 * gap
		if outfit.over == .Leather {
			// Lapels and a turned-up collar.
			for side in ([2]f32{-1, 1}) {
				lapel := jacket * translate({side * w2 * 0.62, h2 * 0.62, w2 * 0.68}) * rot_z(-side * 0.35)
				ball(lapel, {}, {0.07, 0.17, 0.05}, shade(LEATHER, 1.5))
				ball(m, {side * chest * 0.5, 1.41, -0.02}, {0.13, 0.08, 0.15}, shade(LEATHER, 1.5))
			}
		}
	case .Coat, .Trench:
		reach := belly_w + 2 * LAYER
		draw_shape(.Hemisphere, jacket * scale({w2, h2, w2}), over.color)
		ball(m, {0, belly_mid - 0.02, belly_out}, {reach, belly_y + 2 * LAYER + 0.02, reach}, over.color)
		// The skirts of the coat, down to his knees.
		r := max(reach, hips * 1.3, chest + 0.06)
		draw_shape(.Frustum, m * translate({0, 0.3, belly_out * 0.5}) * scale({r * 1.12, 0.62, r * 1.08}), over.color)
		for side in ([2]f32{-1, 1}) {
			ball(m, {side * chest * 0.5, 1.41, 0.04}, {0.14, outfit.over == .Trench ? f32(0.13) : 0.08, 0.16}, shade(over.color, 0.8)) // collar
		}
		for k in 0 ..< 3 {
			// Buttons down the front.
			y := belly_mid + (f32(k) - 0.6) * belly_y * 0.55
			across := (y - belly_mid + 0.02) / (belly_y + 2 * LAYER + 0.02)
			ball(m, {0, y, belly_out + reach * math.sqrt(max(1 - across * across, 0)) + 0.004}, {0.03, 0.03, 0.02}, shade(over.color, 0.55))
		}
		if outfit.over == .Trench {
			// Belted at the waist.
			ball(m, {0, belly_mid - 0.02, belly_out}, {reach + 0.012, 0.05, reach + 0.012}, shade(TRENCH, 0.7))
			box(m, {0, belly_mid - 0.02, belly_out + reach + 0.012}, {0.09, 0.08, 0.03}, COLOR_GOLD)
		}
	case .Cape:
		// From his shoulders down his back nearly to the ground, flying out
		// behind him as he walks: black outside, red inside, a high collar.
		back := m * translate({0, 1.36, -chest * 0.62 - clothes_thickness()}) * rot_x(-0.14 - 0.16 * abs(swing))
		draw_shape(.Frustum, back * translate({0, -1.2, -0.05}) * scale({chest * 1.45 + 0.1, 1.22, 0.1}), LEATHER)
		draw_shape(.Frustum, back * translate({0, -1.17, 0}) * scale({chest * 1.36 + 0.08, 1.17, 0.08}), CAPE_RED)
		ball(m, {0, 1.34, -0.06}, {chest * 1.2, 0.1, chest * 0.85}, LEATHER) // across his shoulders
		for side in ([2]f32{-1, 1}) {
			collar := m * translate({side * chest * 0.62, 1.48, -0.1}) * rot_z(-side * 0.3)
			ball(collar, {}, {0.1, 0.2, 0.15}, LEATHER)
			ball(collar, {-side * 0.03, 0, 0.03}, {0.07, 0.17, 0.12}, CAPE_RED)
		}
		box(m, {0, 1.35, chest * 0.62}, {0.09, 0.07, 0.04}, COLOR_GOLD) // the clasp
	case .Apron:
		ball(jacket, {0, jacket_h * 0.34, jacket_w * 0.62}, {jacket_w * 0.5, jacket_h * 0.5, jacket_w * 0.44}, SAILOR)
		ball(m, {0, belly_mid - 0.03, belly_out + 0.045}, {belly_w * 0.88, belly_y, belly_w + LAYER}, SAILOR)
	}

	// What is printed on the shirt, where the shirt can be seen.
	shows := outfit.over == .None || outfit.over == .Gilet || outfit.over == .Leather || outfit.over == .Cape
	if shows {
		#partial switch outfit.shirt {
		case .Band_Tee:
			draw_print(jacket, "TOOL", front_y, min(jacket_w * 0.092, x_radius * 0.125), z_centre, z_radius, x_radius, COLOR_WHITE)
		case .Computer_Tee:
			draw_print(jacket, "C64", front_y + jacket_w * 0.06, jacket_w * 0.11, z_centre, z_radius, x_radius, NAVY)
			// And a rainbow under it, across the top of his belly.
			stripes := [?]Color{{220, 60, 60, 255}, {240, 150, 50, 255}, {240, 210, 70, 255}, {90, 180, 90, 255}, {70, 130, 210, 255}}
			outlines_enabled = false
			for color, k in stripes {
				rise := 0.4 - 0.13 * f32(k)
				ring := (belly_w + LAYER) * math.sqrt(1 - rise * rise)
				for step in -4 ..= 4 {
					x := f32(step) * ring * 0.12
					box(m, {x, belly_mid + (belly_y + LAYER) * rise, belly_out + math.sqrt(max(ring * ring - x * x, 0)) + 0.004}, {ring * 0.13, belly_y * 0.125, 0.025}, color)
				}
			}
			outlines_enabled = true
		case .Pirate_Top:
			// A skull over crossed bones.
			at := Vec3{0, front_y, z_centre + z_radius}
			ball(jacket, at + {0, 0.05, 0}, {0.09, 0.085, 0.03}, COLOR_WHITE)
			ball(jacket, at + {0, -0.03, 0.002}, {0.055, 0.045, 0.03}, COLOR_WHITE)
			for side in ([2]f32{-1, 1}) {
				ball(jacket, at + {side * 0.035, 0.055, 0.02}, {0.022, 0.026, 0.015}, LEATHER)
				limb(jacket, at + {side * 0.15, -0.14, -0.03}, at + {-side * 0.15, -0.03, 0}, 0.022, COLOR_WHITE)
			}
		}
	}

	// Round his neck. A tie hangs down the front of whatever is outermost
	// there (under a closed coat only its knot shows).
	switch outfit.neck {
	case .None:
	case .Kerchief:
		ball(m, {0, 1.40, 0.03}, {chest * 0.74 + clothes_thickness(), 0.095, chest * 0.72 + clothes_thickness()}, COLOR_HEADBAND)
		knot := m * translate({chest * 0.56, 1.39, 0.11}) * rot_z(0.44)
		ball(knot, {0, -0.06, 0.035}, {0.07, 0.14, 0.055}, COLOR_HEADBAND)
	case .Scarf:
		// Wound round, with one long end flying out behind.
		ball(m, {0, 1.41, 0.02}, {chest * 0.8 + clothes_thickness(), 0.11, chest * 0.78 + clothes_thickness()}, COLOR_WHITE)
		flutter := 0.06 * math.sin(g.time * 5) + 0.1 * abs(swing)
		limb(m, {chest * 0.5, 1.4, -0.1}, {chest * 0.7, 1.3 + flutter, -0.55}, 0.07, COLOR_WHITE)
		limb(m, {chest * 0.7, 1.3 + flutter, -0.55}, {chest * 0.6, 1.2 + flutter * 2, -0.95}, 0.06, COLOR_WHITE)
	case .Tie:
		ball(jacket, {0, jacket_h * 0.9, jacket_w * 0.4 + 2 * LAYER}, {0.05, 0.045, 0.04}, CAPE_RED)
		if !closed_coat() && outfit.over != .Apron {
			top := Vec3{0, jacket_h * 0.84, jacket_w * 0.52 + 2 * LAYER}
			tip := Vec3{0, jacket_h * 0.1, z_centre + z_radius + 0.012}
			mid := Vec3{0, jacket_h * 0.5, z_centre + z_radius * 0.9 + 0.012}
			limb(jacket, top, mid, 0.035, CAPE_RED)
			limb(jacket, mid, tip, 0.045, CAPE_RED)
		}
	case .Bow_Tie:
		at := Vec3{0, jacket_h * 0.9, jacket_w * 0.42 + 2 * LAYER}
		ball(jacket, at, {0.035, 0.035, 0.03}, shade(CAPE_RED, 0.8))
		for side in ([2]f32{-1, 1}) {
			ball(jacket, at + {side * 0.08, 0, -0.005}, {0.07, 0.05, 0.025}, CAPE_RED)
		}
	}
}

// One arm's sleeve: that of the outermost thing he wears that has sleeves.
// (The points are the arm's, in the body's frame.)
draw_sleeve :: proc(m: Mat4, shoulder, elbow, hand: Vec3, arm_r: f32) {
	kind := SHIRT_LOOK[outfit.shirt].sleeves
	color := SHIRT_LOOK[outfit.shirt].color
	thick: f32 = 1
	if outfit.shirt == .None {
		kind = .None
	}
	if over := OVER_LOOK[outfit.over]; over.sleeves != .None {
		kind, color, thick = over.sleeves, over.color, 1.12
	}
	switch kind {
	case .None:
	case .Short:
		ball(m, shoulder, {arm_r * 1.8, arm_r * 1.8, arm_r * 1.8} * thick, color)
		taper(m, shoulder, shoulder + (elbow - shoulder) * 0.42, arm_r * 1.97 * thick, color)
	case .Long:
		ball(m, shoulder, {arm_r * 1.85, arm_r * 1.85, arm_r * 1.85} * thick, color)
		taper(m, shoulder, elbow, arm_r * 2.02 * thick, color)
		ball(m, elbow, {arm_r * 1.3, arm_r * 1.3, arm_r * 1.3} * thick, color)
		taper(m, elbow, elbow + (hand - elbow) * 0.86, arm_r * 1.4 * thick, color)
	}
}

// What is round his hips (in the body's frame), over his own bottom.
draw_hips_outfit :: proc(m: Mat4, hips: f32) {
	color := LEG_COLOR[outfit.legs]
	switch outfit.legs {
	case .None:
	case .Shorts, .Jeans, .Leather, .Cords, .Checks:
		ball(m, {0, 0.6, 0.05}, {hips * 0.95, 0.2, hips * 0.8}, color)
		for side in ([2]f32{-1, 1}) {
			ball(m, {side * hips * 0.42, 0.57, -hips * 0.25}, {hips * 0.58, 0.21, hips * 0.62}, color)
		}
		if outfit.legs == .Cords || outfit.legs == .Leather {
			ball(m, {0, 0.72, 0.04}, {hips * 0.93, 0.045, hips * 0.8}, shade(color, 0.6)) // a belt
		}
	case .Skirt:
		draw_shape(.Frustum, m * translate({0, 0.34, 0.04}) * scale({hips * 1.5, 0.4, hips * 1.4}), color)
		draw_shape(.Cylinder, m * translate({0, 0.7, 0.04}) * scale({hips * 0.95, 0.05, hips * 0.88}), shade(color, 0.8))
	}
}

// One leg's clothes and footwear (in the leg's frame, from the hip down).
draw_leg_outfit :: proc(hip: Mat4, leg_r: f32, knee, ankle: Vec3) {
	color := LEG_COLOR[outfit.legs]
	switch {
	case outfit.legs == .Shorts:
		taper(hip, {0, 0.1, 0}, {0, -0.08, 0.02}, leg_r * 1.8, color)
	case long_trousers():
		taper(hip, {0, 0.1, 0}, knee, leg_r * 1.75, color)
		ball(hip, knee, {leg_r * 1.12, leg_r * 1.12, leg_r * 1.12}, color)
		taper(hip, knee, ankle + {0, 0.05, 0}, leg_r * 1.18, color)
	}
	sole := Vec3{0, -0.42 * LEG_SCALE, 0.05}
	// A shoe: a rounded upper on a darker sole that shows as a rim round it.
	shoe :: proc(hip: Mat4, sole: Vec3, leg_r: f32, upper, under: Color) {
		ball(hip, sole + {0, -0.012, 0.02}, {leg_r * 1.38, 0.06, leg_r * 2.0}, under)
		ball(hip, sole + {0, 0.03, 0.02}, {leg_r * 1.3, 0.085, leg_r * 1.9}, upper)
	}
	switch outfit.feet {
	case .Hooves, .Sandals:
		for toe in ([2]f32{-1, 1}) {
			ball(hip, sole + {toe * leg_r * 0.42, 0, 0}, {leg_r * 0.64, 0.075, leg_r * 1.2}, COLOR_HOOF)
		}
		if outfit.feet == .Sandals {
			ball(hip, sole + {0, -0.03, 0.01}, {leg_r * 1.3, 0.035, leg_r * 1.7}, BOOT)
			ball(hip, sole + {0, 0.045, 0.03}, {leg_r * 1.15, 0.03, leg_r * 0.4}, BOOT)
		}
	case .Sneakers:
		shoe(hip, sole, leg_r, SNEAKER, {200, 60, 56, 255})
	case .Trainers:
		shoe(hip, sole, leg_r, TRAINER, COLOR_WHITE)
		ball(hip, sole + {0, 0.06, leg_r * 0.6}, {leg_r * 0.9, 0.05, leg_r * 0.5}, shade(TRAINER, 0.8))
	case .Boots:
		taper(hip, ankle + {0, 0.14, 0}, ankle + {0, -0.02, 0}, leg_r * 1.3, BOOT)
		shoe(hip, sole, leg_r, BOOT, shade(BOOT, 0.6))
	case .Black_Boots:
		// Up to the knee, with a turned-down top.
		taper(hip, knee + {0, -0.03, 0}, ankle + {0, -0.02, 0}, leg_r * 1.34, LEATHER)
		ball(hip, knee + {0, -0.04, 0}, {leg_r * 1.42, 0.05, leg_r * 1.42}, shade(LEATHER, 1.5))
		shoe(hip, sole, leg_r, LEATHER, SOLE)
	}
}

// His hair, under whatever hat he has on.
draw_hair :: proc(h: Mat4, cheeks, head, swing: f32) {
	cap :: proc(h: Mat4, cheeks, head: f32, color: Color, down: f32) {
		draw_shape(.Hemisphere, h * translate({0, down, -0.03}) * scale({cheeks * 0.985, 0.47 - down, head * 0.99}), color)
	}
	switch outfit.hair {
	case .None:
	case .Tuft:
		// A swept forelock gives his head an asymmetric outline in profile.
		if shows_forelock() {
			lock := h * translate({-0.075, 0.34, -0.028}) * rot_z(0.64)
			ball(lock, {}, {0.098, 0.143, 0.12}, {165, 104, 82, 255})
			limb(lock, {0, 0.006, 0}, {-0.065, 0.152, -0.039}, 0.047, {165, 104, 82, 255})
		}
	case .Long_Black, .Shaggy:
		black := outfit.hair == .Long_Black
		color := black ? HAIR_BLACK : HAIR
		cap(h, cheeks, head, color, 0.13)
		// Locks down his back and behind his ears, swinging as he walks.
		length: f32 = black ? 0.85 : 0.6
		ball(h, {0, -0.02, -head * 0.74}, {cheeks * 0.86, 0.36, 0.17}, shade(color, 0.9))
		for k in 0 ..< 7 {
			a := math.PI + (f32(k) - 3) * 0.36
			sway := 0.07 * swing * math.sin(f32(k) * 1.7) + (black ? 0 : 0.05 * math.sin(f32(k) * 2.3))
			top := Vec3{math.sin(a) * cheeks * 0.8, 0.2, math.cos(a) * head * 0.8}
			end := Vec3{math.sin(a) * (cheeks + 0.06) + sway, 0.2 - length * (black ? 1 : 0.75 + 0.25 * f32(k % 2)), math.cos(a) * (head + 0.1) - 0.06}
			limb(h, top, end, black ? 0.105 : 0.12, k % 2 == 0 ? color : shade(color, 0.86))
		}
		if !black {
			// And a lock over one eye.
			limb(h, {-0.12, 0.36, 0.26}, {-0.3, 0.05, 0.42}, 0.07, color)
		}
	case .Bowl:
		// Cut straight round, as if round a pudding basin.
		cap(h, cheeks, head, HAIR, 0.06)
		draw_shape(.Cylinder, h * translate({0, 0.05, -0.03}) * scale({cheeks * 1.0, 0.09, head * 1.0}), shade(HAIR, 0.85))
	case .Grey:
		// Short, and only at the back and sides.
		ball(h, {0, 0.12, -0.13}, {cheeks * 0.93, 0.3, head * 0.84}, HAIR_GREY)
	}
}

// Whatever is on his head. band is his head's frame, tilted like a headband.
draw_hat :: proc(h, band: Mat4, cheeks, head, swing: f32) {
	// Over a head of hair things sit a little wider.
	hairy: f32 = outfit.hair == .Long_Black || outfit.hair == .Shaggy || outfit.hair == .Bowl ? 1.07 : 1
	switch outfit.hat {
	case .Headband:
		// A vermilion head cloth, with a knot and two loose ends behind one ear.
		ball(band, {0, 0.195, -0.01}, {cheeks * 0.94 * hairy, 0.145, head * 0.97 * hairy}, COLOR_HEADBAND)
		ball(band, {0.34, 0.19, -0.23}, {0.087, 0.069, 0.083}, COLOR_HEADBAND)
		flutter := 0.036 * math.sin(g.time * 4.0) + 0.035 * swing
		limb(band, {0.35, 0.18, -0.24}, {0.48, 0.06 + flutter, -0.4}, 0.055, COLOR_HEADBAND)
		limb(band, {0.35, 0.18, -0.24}, {0.32, -0.04 - flutter, -0.43}, 0.049, COLOR_HEADBAND)
	case .None:
	case .Straw_Hat:
		hat := h * translate({0, 0.27, -0.02}) * rot_x(-0.08)
		tube(hat, {}, 0.68, 0.035, STRAW)
		tube(hat, {0, 0.03, 0}, 0.31, 0.22, STRAW)
		tube(hat, {0, 0.04, 0}, 0.32, 0.06, COLOR_HEADBAND)
	case .Top_Hat:
		hat := h * translate({0, 0.33, -0.04}) * rot_z(-0.1)
		tube(hat, {}, 0.38, 0.03, HAT_BLACK)
		tube(hat, {0, 0.02, 0}, 0.23, 0.44, HAT_BLACK)
		tube(hat, {0, 0.04, 0}, 0.235, 0.07, COLOR_HEADBAND)
	case .Beanie:
		draw_shape(.Hemisphere, h * translate({0, 0.1, -0.02}) * scale({cheeks * 0.99 * hairy, 0.4, head * 1.0 * hairy}), WOOL)
		draw_shape(.Cylinder, h * translate({0, 0.06, -0.02}) * scale({cheeks * 1.01 * hairy, 0.09, head * 1.02 * hairy}), shade(WOOL, 0.8))
		ball(h, {0, 0.52, -0.02}, {0.09, 0.09, 0.09}, COLOR_WHITE)
	case .Crown:
		tube(h, {0, 0.32, -0.02}, 0.22, 0.12, COLOR_GOLD)
		for k in 0 ..< 5 {
			a := f32(k) * math.TAU / 5 + math.PI / 2
			cone(h, {math.cos(a) * 0.2, 0.43, math.sin(a) * 0.2 - 0.02}, 0.055, 0.13, COLOR_GOLD)
		}
		ball(h, {0, 0.38, 0.21}, {0.04, 0.04, 0.03}, COLOR_HEART)
	case .Flying_Cap:
		// A leather cap with flaps over his ears, and goggles pushed up on
		// his forehead.
		draw_shape(.Hemisphere, h * translate({0, 0.08, -0.03}) * scale({cheeks * 1.0 * hairy, 0.42, head * 1.02 * hairy}), BOOT)
		draw_shape(.Cylinder, h * translate({0, 0.2, -0.03}) * scale({cheeks * 1.0 * hairy, 0.06, head * 1.02 * hairy}), shade(BOOT, 0.7))
		for side in ([2]f32{-1, 1}) {
			ball(h, {side * cheeks * 0.9, 0.04, -0.04}, {0.1, 0.2, 0.17}, BOOT)
			goggle := h * translate({side * 0.15, 0.31, 0.36}) * rot_x(-0.5)
			ball(goggle, {}, {0.11, 0.095, 0.05}, shade(BOOT, 0.6))
			ball(goggle, {0, 0, 0.025}, {0.08, 0.068, 0.035}, {150, 196, 214, 255})
		}
	case .Chef_Hat:
		tube(h, {0, 0.3, -0.02}, 0.29, 0.2, COLOR_WHITE)
		ball(h, {0, 0.64, -0.02}, {0.4, 0.2, 0.4}, COLOR_WHITE)
		for k in 0 ..< 5 {
			a := f32(k) * math.TAU / 5
			ball(h, {math.cos(a) * 0.24, 0.6, math.sin(a) * 0.24 - 0.02}, {0.2, 0.17, 0.2}, COLOR_WHITE)
		}
	}
}

// The tuft on his head shows unless a hat covers it.
shows_forelock :: proc() -> bool {
	return outfit.hat != .Top_Hat && outfit.hat != .Beanie && outfit.hat != .Flying_Cap && outfit.hat != .Chef_Hat
}

// Glasses, facial hair, lipstick and rings, on his head's frame.
draw_face_outfit :: proc(h: Mat4, cheeks: f32) {
	switch outfit.glasses {
	case .None:
	case .Round:
		for side in ([2]f32{-1, 1}) {
			draw_shape(.Torus, h * translate({side * 0.19, 0.04, 0.47}) * scale({0.085, 0.085, 0.06}), GLASS_FRAME)
			limb(h, {side * 0.3, 0.06, 0.44}, {side * cheeks * 0.86, 0.12, 0.1}, 0.014, GLASS_FRAME)
		}
		box(h, {0, 0.06, 0.49}, {0.1, 0.02, 0.02}, GLASS_FRAME)
	case .Sunglasses:
		for side in ([2]f32{-1, 1}) {
			ball(h, {side * 0.19, 0.04, 0.455}, {0.125, 0.1, 0.04}, {34, 34, 52, 255})
			ball(h, {side * 0.19 - 0.04, 0.075, 0.49}, {0.025, 0.015, 0.01}, COLOR_WHITE)
			limb(h, {side * 0.3, 0.06, 0.43}, {side * cheeks * 0.86, 0.12, 0.1}, 0.014, GLASS_FRAME)
		}
		box(h, {0, 0.06, 0.485}, {0.1, 0.025, 0.02}, GLASS_FRAME)
	case .Monocle:
		draw_shape(.Torus, h * translate({0.19, 0.04, 0.47}) * scale({0.09, 0.09, 0.06}), COLOR_GOLD)
		limb(h, {0.22, -0.07, 0.46}, {0.3, -0.35, 0.3}, 0.008, COLOR_GOLD)
	case .Nerd:
		// Big square frames, thick and dark, far too large for his face.
		for side in ([2]f32{-1, 1}) {
			at := Vec3{side * 0.2, 0.045, 0.475}
			box(h, at + {0, 0.115, 0}, {0.27, 0.04, 0.035}, GLASS_FRAME)
			box(h, at + {0, -0.115, 0}, {0.27, 0.04, 0.035}, GLASS_FRAME)
			box(h, at + {0.115, 0, 0}, {0.04, 0.24, 0.035}, GLASS_FRAME)
			box(h, at + {-0.115, 0, 0}, {0.04, 0.24, 0.035}, GLASS_FRAME)
			limb(h, {side * 0.33, 0.1, 0.45}, {side * cheeks * 0.86, 0.14, 0.1}, 0.02, GLASS_FRAME)
		}
		box(h, {0, 0.09, 0.485}, {0.14, 0.04, 0.03}, GLASS_FRAME)
	case .Eyepatch:
		ball(h, {0.19, 0.04, 0.44}, {0.13, 0.135, 0.045}, HAT_BLACK)
		limb(h, {0.26, 0.14, 0.42}, {cheeks * 0.84, 0.26, 0.12}, 0.016, HAT_BLACK)
		limb(h, {0.1, 0.14, 0.45}, {-cheeks * 0.8, 0.32, 0.16}, 0.016, HAT_BLACK)
	}
	switch outfit.face {
	case .None:
	case .Moustache:
		for side in ([2]f32{-1, 1}) {
			tash := h * translate({side * 0.1, -0.19, 0.5}) * rot_z(side * 0.3)
			ball(tash, {}, {0.11, 0.035, 0.04}, HAIR)
			ball(h, {side * 0.205, -0.15, 0.47}, {0.035, 0.035, 0.035}, HAIR)
		}
	case .Beard:
		ball(h, {0, -0.3, 0.24}, {0.24, 0.15, 0.2}, HAIR)
		cone(h * translate({0, -0.32, 0.32}) * rot_x(math.PI - 0.3), {}, 0.09, 0.2, HAIR)
	case .Lipstick:
		ball(h, {0, -0.225, 0.36}, {0.08, 0.025, 0.03}, LIPSTICK)
		ball(h, {0, -0.255, 0.355}, {0.07, 0.025, 0.03}, LIPSTICK)
	case .Scar:
		// An old cut across one cheek, with two stitches.
		scar := Color{176, 84, 92, 255}
		limb(h, {-0.34, 0.0, 0.36}, {-0.15, -0.16, 0.47}, 0.016, scar)
		limb(h, {-0.29, -0.09, 0.4}, {-0.24, -0.02, 0.43}, 0.012, scar)
		limb(h, {-0.22, -0.15, 0.44}, {-0.17, -0.08, 0.46}, 0.012, scar)
	case .Stubble:
		ball(h, {0, -0.27, 0.25}, {0.27, 0.12, 0.21}, shade(HAIR_GREY, 0.85))
	}
	if outfit.earrings == .Ears || outfit.earrings == .Both {
		for side in ([2]f32{-1, 1}) {
			// A ring in the tip of each floppy ear.
			draw_shape(.Torus, h * translate({side * (cheeks * 0.86 + 0.1), -0.14, 0.02}) * rot_y(math.PI / 2) * scale({0.045, 0.045, 0.045}), COLOR_GOLD)
		}
	}
	if outfit.earrings == .Nose || outfit.earrings == .Both {
		// A ring through both nostrils, hanging down in front of his snout.
		draw_shape(.Torus, h * translate({0, -0.135, 0.535}) * scale({0.075, 0.075, 0.05}), COLOR_GOLD)
	}
}
