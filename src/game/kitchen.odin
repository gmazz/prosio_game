package game

import "core:math"

// Food is gathered, not eaten on the spot: E puts it in Prosio's sack, and
// he eats from the sack when he likes (Q), choosing what with Z and C.
// Whatever he eats puts on weight by its calories, slowly: food has to be
// gathered steadily to make up for what walking, picking things up and
// fighting burn (see the *_BURN numbers in prosio.odin).
//
// At the oven he bakes what he has gathered into pies, muffins and bread.
// Cooking makes more of the calories in food available to the body, so a
// baked dish counts COOK_BONUS times the calories of what went into it.

KCAL_PER_KG :: f32(200) // calories eaten for each kilogram he puts on
COOK_BONUS :: f32(1.4)
SACK_MAX :: 9 // of each thing
BAKE_TIME :: f32(6)
OVEN_RADIUS :: f32(1.15)

Item :: enum u8 {
	Apple,
	Berries,
	Mushroom,
	Pumpkin,
	Wheat,
	Egg,
	// Baked in the oven:
	Apple_Pie,
	Pumpkin_Pie,
	Berry_Muffins,
	Mushroom_Pie,
	Bread,
}
FIRST_DISH :: Item.Apple_Pie

ITEM_NAME := [Item]cstring {
	.Apple         = "APPLE",
	.Berries       = "BERRIES",
	.Mushroom      = "MUSHROOM",
	.Pumpkin       = "PUMPKIN",
	.Wheat         = "WHEAT",
	.Egg           = "EGG",
	.Apple_Pie     = "APPLE PIE",
	.Pumpkin_Pie   = "PUMPKIN PIE",
	.Berry_Muffins = "BERRY MUFFINS",
	.Mushroom_Pie  = "MUSHROOM PIE",
	.Bread         = "BREAD",
}

// Calories in one of each raw thing. A dish's are worked out from its recipe.
RAW_KCAL := #partial [Item]f32 {
	.Apple    = 95,
	.Berries  = 50, // a bunch
	.Mushroom = 30,
	.Pumpkin  = 400,
	.Wheat    = 340, // a sheaf, about a cup of flour
	.Egg      = 130,
}

GATHER_TEXT := #partial [Item]cstring {
	.Apple    = "An apple for the sack!",
	.Berries  = "Berries for the sack!",
	.Mushroom = "A mushroom for the sack!",
	.Pumpkin  = "A pumpkin for the sack!",
	.Wheat    = "Wheat for the sack!",
	.Egg      = "An egg for the sack!",
}

// The colour of each, for the thing in his hoof as he picks it up.
ITEM_COLOR := #partial [Item]Color {
	.Apple    = {222, 44, 48, 255},
	.Berries  = {124, 62, 176, 255},
	.Mushroom = {196, 64, 46, 255},
	.Pumpkin  = {232, 128, 40, 255},
	.Wheat    = {230, 190, 88, 255},
	.Egg      = {246, 236, 214, 255},
}

EAT_TEXT := [Item]cstring {
	.Apple         = "Crunch! Yum!",
	.Berries       = "Berries! Yum!",
	.Mushroom      = "Mmm, mushroom!",
	.Pumpkin       = "A whole pumpkin! Burp!",
	.Wheat         = "Crunchy... raw grain!",
	.Egg           = "A raw egg... gulp!",
	.Apple_Pie     = "Apple pie! Heavenly!",
	.Pumpkin_Pie   = "Pumpkin pie! BURP!",
	.Berry_Muffins = "Muffins! So fluffy!",
	.Mushroom_Pie  = "Mushroom pie! Mmm!",
	.Bread         = "Warm bread! Yum!",
}

Ingredient :: struct {
	item:  Item,
	count: int, // 0: unused
}

Recipe :: struct {
	dish:  Item,
	needs: [3]Ingredient,
}

RECIPES := [?]Recipe {
	{.Apple_Pie, {{.Apple, 3}, {.Wheat, 1}, {.Egg, 1}}},
	{.Pumpkin_Pie, {{.Pumpkin, 1}, {.Wheat, 1}, {.Egg, 1}}},
	{.Berry_Muffins, {{.Berries, 3}, {.Wheat, 1}, {.Egg, 1}}},
	{.Mushroom_Pie, {{.Mushroom, 3}, {.Wheat, 1}, {.Egg, 1}}},
	{.Bread, {{.Wheat, 2}, {}, {}}},
}

Oven :: struct {
	pos:     Vec2,
	baking:  bool,
	ready:   bool, // a dish is waiting inside
	dish:    Item,
	bake_t:  f32,
	smoke_t: f32,
	baked:   int, // dishes baked this game
}

// Which recipe the oven's menu points at, and a moment of "not enough".
oven_choice: int
oven_refused_t: f32

recipe_for :: proc(dish: Item) -> ^Recipe {
	for &r in RECIPES {
		if r.dish == dish {
			return &r
		}
	}
	return nil
}

// The calories in what went into a recipe, raw.
raw_kcal :: proc(r: ^Recipe) -> (sum: f32) {
	for n in r.needs {
		sum += RAW_KCAL[n.item] * f32(n.count)
	}
	return
}

item_kcal :: proc(item: Item) -> f32 {
	if item < FIRST_DISH {
		return RAW_KCAL[item]
	}
	return math.round(raw_kcal(recipe_for(item)) * COOK_BONUS)
}

can_bake :: proc(r: ^Recipe) -> bool {
	for n in r.needs {
		if g.prosio.sack[n.item] < n.count {
			return false
		}
	}
	return true
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

sack_has_food :: proc() -> bool {
	for n in g.prosio.sack {
		if n > 0 {
			return true
		}
	}
	return false
}

// E next to food: into the sack it goes.
gather :: proc(food: ^Food, bush: ^Round) {
	p := &g.prosio
	item := food != nil ? FOOD_ITEM[food.kind] : Item.Berries
	if p.sack[item] >= SACK_MAX {
		hint("No room in my sack for more of these!")
		return
	}
	p.sack[item] += 1
	sack_step(0)
	at: Vec2
	if food != nil {
		if food.fallen {
			food.gone = true
		} else {
			food.respawn = FOOD_RESPAWN[food.kind]
		}
		at = food.pos
		burst({at.x, 0.4, at.y}, 6, 2, food.kind == .Wheat ? Color{226, 186, 84, 255} : COLOR_LEAF_LIGHT, 0.06)
	} else {
		bush.fruit -= 1
		bush.fruit_t = BERRY_REGROW
		bush.shake_t = 0.4
		at = bush.pos
		burst({at.x, 0.7, at.y}, 6, 2, BERRY_COLOR, 0.06)
	}
	say(GATHER_TEXT[item], 1.2)
	p.pick_t = PICK_TIME // a moment to stoop and pick it up
	p.pick_item = item
	p.vel = {}
	burn(GATHER_BURN)
	to := at - p.pos
	p.facing = math.atan2(to.x, to.y)
}

// Q: eat what is chosen in the sack.
eat_from_sack :: proc() {
	p := &g.prosio
	item := p.sack_sel
	if p.sack[item] <= 0 {
		hint("My sack is empty! E picks food up.")
		return
	}
	p.sack[item] -= 1
	sack_step(0)
	p.kg += item_kcal(item) / KCAL_PER_KG
	say(EAT_TEXT[item])
	p.eat_t = 0.5
	p.wobble_vel += 2.5
	crumbs := item >= FIRST_DISH ? Color{226, 178, 104, 255} : COLOR_CRUMB
	burst({p.pos.x, p.height + 1.3, p.pos.y}, 8, 2.5, crumbs, 0.07)
}

oven_in_reach :: proc(pos: Vec2, r: f32) -> bool {
	return length2(g.oven.pos - pos) < OVEN_RADIUS + r + 0.7
}

// E at the oven: take out what is ready, or choose something to bake.
use_oven :: proc() {
	p := &g.prosio
	o := &g.oven
	switch {
	case o.ready:
		if p.sack[o.dish] >= SACK_MAX {
			hint("No room in my sack for it!")
			return
		}
		p.sack[o.dish] += 1
		p.sack_sel = o.dish
		o.ready = false
		say("Into the sack, still warm!", 1.6)
		burst({o.pos.x, 0.9, o.pos.y + OVEN_RADIUS}, 10, 2.5, COLOR_STAR, 0.08)
	case o.baking:
		hint("Still baking... it smells so good!")
	case:
		scene = .Oven
		oven_refused_t = 0
		// Point at the first thing he can bake, if any.
		for &r, i in RECIPES {
			if can_bake(&r) {
				oven_choice = i
				break
			}
		}
	}
	to := o.pos - p.pos
	p.facing = math.atan2(to.x, to.y)
}

// The oven's menu, shown with the game paused.
update_oven_menu :: proc(dt: f32) {
	n := len(RECIPES)
	oven_refused_t -= dt
	if button_pressed(.Down) {
		oven_choice = (oven_choice + 1) % n
	}
	if button_pressed(.Up) {
		oven_choice = (oven_choice + n - 1) % n
	}
	if button_pressed(.Menu) || button_pressed(.Grab) {
		scene = .Playing
		return
	}
	if button_pressed(.Confirm) || button_pressed(.Action) {
		r := &RECIPES[oven_choice]
		if !can_bake(r) {
			oven_refused_t = 1.2
			return
		}
		for need in r.needs {
			g.prosio.sack[need.item] -= need.count
		}
		sack_step(0)
		o := &g.oven
		o.baking = true
		o.dish = r.dish
		o.bake_t = BAKE_TIME
		scene = .Playing
		say("Into the oven it goes!", 1.4)
	}
}

update_oven :: proc(dt: f32) {
	o := &g.oven
	if !o.baking {
		return
	}
	o.bake_t -= dt
	o.smoke_t -= dt
	if o.smoke_t <= 0 {
		o.smoke_t = 0.12
		chimney := Vec3{o.pos.x - 0.4, 2.15, o.pos.y - 0.35}
		vel := Vec3{random_range(-0.2, 0.2) + 0.25, random_range(0.9, 1.4), random_range(-0.2, 0.2)}
		grey := u8(random_range(190, 235))
		spawn_particle(chimney, vel, random_range(1.2, 2), random_range(0.1, 0.17), {grey, grey, grey, 255}, -0.3)
	}
	if o.bake_t <= 0 {
		o.baking = false
		o.ready = true
		o.baked += 1
		say("Ding! The oven is ready!", 2)
		burst({o.pos.x, 1.2, o.pos.y + OVEN_RADIUS}, 12, 3, COLOR_STAR, 0.09)
	}
}

BRICK :: Color{190, 96, 70, 255}
BRICK_DARK :: Color{142, 66, 52, 255}
BRICK_LINE :: Color{168, 80, 60, 255}

// A round brick oven on a stone base, its mouth facing the camera, with a
// chimney and a pile of logs.
draw_oven :: proc() {
	o := &g.oven
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

CRUST :: Color{230, 182, 108, 255}
CRUST_DARK :: Color{190, 130, 66, 255}

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
	}
	return {}, false
}

draw_icon :: proc(item: Item, x, y, size: f32) {
	px := size / 12
	for row, j in ICONS[item] {
		for i in 0 ..< min(len(row), 12) {
			if c, ok := icon_color(row[i]); ok {
				ui_rect(x + f32(i) * px, y + f32(j) * px, px + 0.5, px + 0.5, c)
			}
		}
	}
}

SACK_BOX :: Color{246, 236, 214, 255}
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

	// Wide enough for the longest name with its calories.
	widest: f32
	for it in Item {
		w := ui_text_width(ITEM_NAME[it], text) + 10 * s + ui_text_width(ui_format("%d kcal", i32(item_kcal(it))), text)
		widest = max(widest, w)
	}
	boxes := f32(slots) * size + f32(slots - 1) * gap + (scrolling ? 2 * arrow : 0)
	width := max(widest, boxes) + 2 * pad
	height := pad + text + 6 * s + size + text + pad
	ui_round_rect(x, y, width, height, UI_PANEL, 0.2)
	centre := x + width / 2
	if n == 0 {
		label_centred("SACK: empty", centre, y + height / 2 - text / 2, text, UI_WHITE)
		return
	}

	name := ITEM_NAME[p.sack_sel]
	kcal := ui_format("%d kcal", i32(item_kcal(p.sack_sel)))
	name_w := ui_text_width(name, text)
	left := centre - (name_w + 10 * s + ui_text_width(kcal, text)) / 2
	label(name, left, y + pad, text)
	label(kcal, left + name_w + 10 * s, y + pad, text, UI_YELLOW)

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
}

// The oven's menu: what can be baked, what it needs and what it is worth.
draw_oven_menu :: proc() {
	sw, sh := screen_size()
	s := min(sw / 1280, sh / 720)
	ui_rect(0, 0, sw, sh, {10, 24, 20, 130})
	pw, ph := 820 * s, 560 * s
	px, py := sw / 2 - pw / 2, sh / 2 - ph / 2
	ui_round_rect(px, py, pw, ph, {74, 46, 38, 240}, 0.08)
	label_centred("THE OVEN", sw / 2, py + 18 * s, 44 * s, UI_ORANGE)
	label_centred("Cooking makes food richer: +40% kcal!", sw / 2, py + 70 * s, 20 * s, UI_YELLOW)

	y := py + 108 * s
	row := 74 * s
	for &r, i in RECIPES {
		chosen := i == oven_choice
		ok := can_bake(&r)
		if chosen {
			ui_round_rect(px + 18 * s, y - 8 * s, pw - 36 * s, row - 6 * s, UI_YELLOW, 0.3)
			ui_round_rect(px + 21 * s, y - 5 * s, pw - 42 * s, row - 12 * s, {118, 78, 60, 255}, 0.3)
		}
		ui_round_rect(px + 34 * s, y, 54 * s, 54 * s, SACK_BOX, 0.2)
		draw_icon(r.dish, px + 39 * s, y + 5 * s, 44 * s)
		label(ITEM_NAME[r.dish], px + 102 * s, y + 2 * s, 24 * s, ok ? UI_WHITE : Color{200, 180, 170, 255})
		label(ui_format("%d kcal", i32(item_kcal(r.dish))), px + 102 * s, y + 31 * s, 20 * s, UI_YELLOW)
		label(ui_format("(raw %d)", i32(raw_kcal(&r))), px + 214 * s, y + 33 * s, 16 * s, {220, 200, 180, 255})
		x := px + 380 * s
		for need in r.needs {
			if need.count == 0 {
				continue
			}
			have := g.prosio.sack[need.item]
			draw_icon(need.item, x, y + 7 * s, 40 * s)
			label(ui_format2("%d/%d", i32(have), i32(need.count)), x + 46 * s, y + 18 * s, 22 * s, have >= need.count ? UI_GREEN : UI_RED)
			x += 140 * s
		}
		y += row
	}
	if oven_refused_t > 0 {
		label_centred("Not enough in the sack for that!", sw / 2, py + ph - 78 * s, 24 * s, UI_RED)
	}
	label_centred("UP / DOWN: choose     E or ENTER: bake     ESC: close", sw / 2, py + ph - 40 * s, 20 * s, UI_YELLOW)
}
