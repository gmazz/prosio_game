package workbench

// The Mixing and cooking pane (see panes.odin): the rules of
// src/game/mixing.odin as they are (the game's bowl and oven do not use them
// yet), tried by hand. Choose up to BOWL_KINDS things and how much of each,
// washed or pressed, how long they are mixed, a shape for a dough, and how
// it is cooked: as it stands, in the oven at a temperature, on the fire at a
// spit height, or in a pot, for a time (or each at its best). See what the
// rules make of it: the mix (its weight, calories, how wet it is, what kind,
// how well mixed), and the dish (its kind, weight and calories, how done the
// middle and the outside are, how dry, its flaws, taste, texture, keeping,
// its microorganisms, the cooking bonus it got, how hard it is, the wood it
// burned), with bars. His baking and grilling skill set the intervals the
// game's editor would show for each setting (the bars under the sliders) and
// the cooking bonus. Every number of the rules is on a slider below.

import cmd "commands"
import game "../game"
import "core:fmt"
import "core:math"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

Cooking :: enum {
	Stands, // eaten as it stands
	Bake,
	Grill,
	Boil,
}

COOKING_NAMES := [Cooking]string{.Stands = "as it stands", .Bake = "oven", .Grill = "fire", .Boil = "pot"}
COOKING_HEAT := [Cooking]game.Heating{.Stands = .Bake, .Bake = .Bake, .Grill = .Grill, .Boil = .Boil}

Mixing_State :: struct {
	parts:     [game.BOWL_KINDS]game.Bowl_Part,
	n:         int,
	prep:      game.Prep,
	best_mix:  bool, // mixed for its best time
	shape:     game.Dough_Shape,
	how:       Cooking,
	temp:      f32, // the oven's
	spit:      game.Spit, // the fire's
	minutes:   f32, // cooked for
	best_cook: bool, // at its best temperature (or spit) and time
	picking:   int, // the part whose food is being chosen (-1: none)
	// Drying and milling: a food, so much of it, in the oven so hot for so long.
	dry:       game.Bowl_Part,
	dry_temp:  f32,
	dry_mins:  f32,
	dry_best:  bool, // until it mills
	dry_pick:  bool,
}

mixing := Mixing_State {
	parts     = {{food = .Flour, amount = 500}, {food = .Water, amount = 300}, {}, {}},
	n         = 2,
	prep      = {minutes = 8},
	best_mix  = true,
	how       = .Bake,
	temp      = 200,
	minutes   = 40,
	best_cook = true,
	picking   = -1,
	dry       = {food = .Potato, amount = 1000},
	dry_temp  = 60,
	dry_best  = true,
}

// What the rules make of the pane's bowl, as it is set.
Mixing_Result :: struct {
	m:              game.Mix,
	refused:        game.Bowl_Refusal,
	shape_refused:  game.Shape_Refusal,
	d:              game.Dish,
	cooked:         bool,
	temp, minutes:  f32,
	best_temp:      f32,
	best_minutes:   f32,
	best_mix:       f32,
	skill:          f32, // the skill that goes with this way of cooking
	bonus:          f32, // and the cooking bonus it gives
	key:            u32,
	mix_key:        u32, // (the mixing interval's, as tools/check.sh mix: the oven's, before shaping)
}

mixing_result :: proc() -> (r: Mixing_Result) {
	s := &mixing
	heat := COOKING_HEAT[s.how]
	station: game.Station_Kind = heat == .Bake ? .Oven : .Fire
	r.skill = game.g.prosio.trait[game.STATION_SKILL[station]]
	r.bonus = math.lerp(game.COOK_RANGE[station][0], game.COOK_RANGE[station][1], r.skill)
	prep := s.prep
	r.m, r.refused = game.mix_bowl(s.parts[:s.n], prep)
	if r.refused != .None {return}
	r.best_mix = game.best_mix_minutes(r.m)
	r.mix_key = game.recipe_key(r.m, .Bake)
	if s.best_mix {
		prep.minutes = r.best_mix
		r.m, r.refused = game.mix_bowl(s.parts[:s.n], prep)
	}
	if s.shape != .Loaf {
		shaped, why := game.shape_mix(r.m, s.shape)
		r.shape_refused = why
		if why == .None {r.m = shaped}
	}
	r.key = game.recipe_key(r.m, heat)
	if s.how == .Stands {
		r.d = game.as_it_stands(r.m)
		return
	}
	r.cooked = true
	r.best_temp, r.best_minutes = game.best_settings(r.m, heat)
	switch {
	case s.best_cook:
		r.temp, r.minutes = r.best_temp, r.best_minutes
		if heat == .Grill {s.spit = game.best_spit(r.m)}
	case heat == .Grill:
		r.temp, r.minutes = game.SPIT_TEMP[s.spit], s.minutes
	case heat == .Boil:
		r.temp, r.minutes = game.BOIL, s.minutes
	case:
		r.temp, r.minutes = s.temp, s.minutes
	}
	r.d = game.cook(r.m, heat, r.temp, r.minutes, r.bonus)
	return
}

// (A row out of sight is only counted, not drawn: the pane is long.)
// A bar: where a value is between lo and hi, with a span marked as right
// (or the interval the game's editor would show), and the best.
pane_bar :: proc(label: string, value, lo, hi: f32, good_lo, good_hi: f32, best := f32(-1e9), text := "", about := "") {
	y := row.y
	if !row_shown() {
		row.y += PANE_LINE
		return
	}
	if row_live({row.x + 4, y, row.w - 8, PANE_LINE}) && about != "" {pane.about_name, pane.about = label, about}
	text_at(fmt.tprintf("  %s", label), row.x + 6, y, INK, LABEL_COLS + 2)
	x0 := row.x + 16 + f32(LABEL_COLS + 2) * editor.cell
	x1 := row.x + row.w - BOX_W - 18
	at :: proc(v, lo, hi, x0, x1: f32) -> f32 {return x0 + clamp(hi > lo ? (v - lo) / (hi - lo) : 0, 0, 1) * (x1 - x0)}
	rl.DrawRectangleRec({x0, y + 7, x1 - x0, 8}, {50, 54, 64, 255})
	if good_hi > good_lo {
		a, b := at(good_lo, lo, hi, x0, x1), at(good_hi, lo, hi, x0, x1)
		rl.DrawRectangleRec({a, y + 7, max(b - a, 2), 8}, {90, 140, 80, 255})
	}
	if best > -1e8 {
		bx := at(best, lo, hi, x0, x1)
		rl.DrawRectangleRec({bx - 1, y + 3, 2, 16}, {150, 230, 140, 255})
	}
	vx := at(value, lo, hi, x0, x1)
	rl.DrawRectangleRec({vx - 3, y + 4, 6, 14}, AMBER)
	text_at(text != "" ? text : cmd.number_text(f32(math.round(value * 100) / 100)), x1 + 10, y, TYPE, int((BOX_W + 8) / editor.cell))
	row.y += PANE_LINE
}

UNIT_NAMES := [game.Unit]string{.Gram = " g", .Millilitre = " ml", .Egg = " eggs", .Pinch = " pinches"}
UNIT_MOST := [game.Unit]f32{.Gram = 1000, .Millilitre = 1000, .Egg = 12, .Pinch = 20}

draw_mixing :: proc() {
	s := &mixing
	p := &game.g.prosio

	pane_heading("The bowl")
	for i := 0; i < s.n; i += 1 {
		part := &s.parts[i]
		unit := game.MIXABLE[part.food].unit
		switch pane_buttons({part_name(part^), "take it out"}, {s.picking == i, false}, "click the name to choose another food; take it out: out of the bowl") {
		case 0: s.picking = s.picking == i ? -1 : i
		case 1:
			for j in i ..< s.n - 1 {s.parts[j] = s.parts[j + 1]}
			s.n -= 1
			s.picking = -1
			i -= 1
			continue
		}
		if s.picking == i {
			if f, ok := pick_food(); ok {
				part.food, part.milled = f, false
				s.picking = -1
			}
		}
		pane_number(fmt.tprintf("amount %d", i), "how much", &part.amount, 0, part.milled ? 1000 : UNIT_MOST[unit], false, "how much of it goes in, in its own unit (a flour in grams)", part.milled ? " g" : UNIT_NAMES[unit])
	}
	if s.n < game.BOWL_KINDS {
		if pane_buttons({"add a thing"}) == 0 {
			s.parts[s.n] = {food = .Water, amount = 100}
			s.n += 1
			s.picking = s.n - 1
		}
	}
	switch pane_buttons({s.prep.washed ? "washed" : "not washed", s.prep.pressed ? "pressed to juice" : "not pressed"}, {s.prep.washed, s.prep.pressed}, "washed first (takes microorganisms off), or its fruit and vegetables pressed to juice") {
	case 0: s.prep.washed = !s.prep.washed
	case 1: s.prep.pressed = !s.prep.pressed
	}

	draw_drying()
	r := mixing_result()
	baking := p.trait[.Baking]
	pane_heading("Mixing")
	mixed := s.best_mix ? r.best_mix : s.prep.minutes
	if pane_number("mix minutes", s.best_mix ? "mixed (its best)" : "mixed for", &mixed, 0, max(2 * r.best_mix, 1), false, "how long it is mixed, in minutes (setting it leaves \"at its best\")", " min") {
		s.prep.minutes = max(mixed, 0)
		s.best_mix = false
	}
	if r.refused == .None {
		lo, hi := game.setting_interval(r.best_mix, .Mixing, baking, r.mix_key)
		pane_bar("the editor shows", mixed, 0, max(2 * r.best_mix, 1), lo, hi, r.best_mix, fmt.tprintf("%.1f-%.1f", lo, hi), "the interval the game's editor would show for the mixing time at his baking skill (green), and the best (the bright tick)")
	}
	if pane_buttons({"at its best"}, {s.best_mix}) == 0 {s.best_mix = true}
	shapes := []string{"no shape (a loaf)", "flat", "strips", "lumps"}
	shape_of := [4]game.Dough_Shape{.Loaf, .Flat, .Strips, .Lumps}
	if k := pane_buttons(shapes, {s.shape == .Loaf, s.shape == .Flat, s.shape == .Strips, s.shape == .Lumps}, "a dough shaped (wrapped and layered want a filling, which this pane does not make)"); k >= 0 {
		s.shape = shape_of[k]
	}

	pane_heading("Cooking")
	names := []string{COOKING_NAMES[.Stands], COOKING_NAMES[.Bake], COOKING_NAMES[.Grill], COOKING_NAMES[.Boil]}
	if k := pane_buttons(names, {s.how == .Stands, s.how == .Bake, s.how == .Grill, s.how == .Boil}); k >= 0 {s.how = Cooking(k)}
	if s.how != .Stands && r.refused == .None {
		grilling := p.trait[.Grilling]
		skill := s.how == .Bake ? baking : grilling
		switch s.how {
		case .Bake:
			temp := r.temp
			if pane_number("oven", "oven", &temp, 100, 300, false, "the oven's temperature, degrees (setting it leaves \"at its best\")", "°") {
				s.temp, s.minutes, s.best_cook = temp, r.minutes, false
			}
			lo, hi := game.setting_interval(r.best_temp, .Temperature, skill, r.key)
			pane_bar("the editor shows", r.temp, 100, 300, lo, hi, r.best_temp, fmt.tprintf("%.0f-%.0f", lo, hi), "the interval the game's editor would show for the temperature at his baking skill, and the best")
		case .Grill:
			spits := []string{"high", "middle", "low"}
			if k := pane_buttons(spits, {s.spit == .High, s.spit == .Middle, s.spit == .Low}, "the spit's height over the fire (SPIT_TEMP)"); k >= 0 {
				s.spit, s.minutes, s.best_cook = game.Spit(k), r.minutes, false
			}
			pane_text(fmt.tprintf("the %v spit: %.0f°; its best the %v spit", s.spit, r.temp, game.best_spit(r.m)), DIM)
		case .Boil, .Stands:
			pane_text("at the boil", DIM)
		}
		minutes := r.minutes
		if pane_number("cook minutes", s.best_cook ? "cooked (its best)" : "cooked for", &minutes, 0, max(2 * r.best_minutes, 1), false, "how long it is cooked, in minutes (setting it leaves \"at its best\")", " min") {
			s.minutes, s.temp, s.best_cook = max(minutes, 0), r.temp, false
		}
		lo, hi := game.setting_interval(r.best_minutes, .Cooking, skill, r.key)
		pane_bar("the editor shows", r.minutes, 0, max(2 * r.best_minutes, 1), lo, hi, r.best_minutes, fmt.tprintf("%.1f-%.1f", lo, hi), "the interval the game's editor would show for the cooking time at his skill, and the best")
		if pane_buttons({"at its best"}, {s.best_cook}) == 0 {s.best_cook = true}
	}
	pane_heading("His skill")
	if pane_number("baking", "baking", &p.trait[.Baking], 0, 1, false, "his baking skill, 0 to 1: the oven's cooking bonus (COOK_RANGE), and how narrow the editor's intervals are for the oven and for mixing") {
		p.trait[.Baking] = clamp(p.trait[.Baking], 0, 1)
	}
	if pane_number("grilling", "grilling", &p.trait[.Grilling], 0, 1, false, "his grilling skill, 0 to 1: the fire's cooking bonus, and how narrow the editor's intervals are for the fire and the pot") {
		p.trait[.Grilling] = clamp(p.trait[.Grilling], 0, 1)
	}

	draw_mixing_result(r)
	draw_formulas("mixing")
}

part_name :: proc(part: game.Bowl_Part) -> string {
	return part.milled ? fmt.tprintf("%v flour", part.food) : fmt.tprintf("%v", part.food)
}

// Drying a food in a low oven, cut thin, and milling it into a flour for the
// bowl (mill in mixing.odin).
draw_drying :: proc() {
	s := &mixing
	pane_heading("Dry and mill")
	if pane_buttons({fmt.tprintf("%v", s.dry.food)}, {s.dry_pick}, "the food to dry and mill: click to choose another") == 0 {s.dry_pick = !s.dry_pick}
	if s.dry_pick {
		if f, ok := pick_food(); ok {
			s.dry.food, s.dry_pick = f, false
		}
	}
	unit := game.MIXABLE[s.dry.food].unit
	pane_number("dry amount", "how much", &s.dry.amount, 0, UNIT_MOST[unit] * 2, false, "how much of it is dried, in its own unit", UNIT_NAMES[unit])
	pane_number("dry temp", "low oven", &s.dry_temp, 30, 150, false, "the oven's temperature for drying, degrees (DRY_TEMP is the rules' own: dries without browning)", "°")
	parts := [1]game.Bowl_Part{s.dry.food == .Egg ? {food = .Egg, amount = max(math.round(s.dry.amount), 1)} : s.dry}
	m, refused := game.mix_bowl(parts[:], {})
	if refused != .None {
		pane_text(fmt.tprintf("will not go in: %v", refused), CHANGED)
		return
	}
	until := game.drying_minutes(m, s.dry_temp)
	mins := s.dry_best ? until : s.dry_mins
	if pane_number("dry minutes", s.dry_best ? "dried (until it mills)" : "dried for", &mins, 0, max(2 * until, 60), false, "how long it dries, in minutes, cut thin (setting it leaves \"until it mills\")", " min") {
		s.dry_mins, s.dry_best = max(mins, 0), false
	}
	if pane_buttons({"until it mills"}, {s.dry_best}) == 0 {s.dry_best = true}
	_, d, _ := game.dry_food(parts[0], s.dry_temp, mins)
	water := d.grams > 0 ? d.matter[.Water] / d.grams : 0
	pane_text(fmt.tprintf("%.1f h: %.0f g left, %.0f%% of its water gone, water %.1f%% of it (mills at %.0f%%); outside %.2f", mins / 60, d.grams, 100 * d.dried, 100 * water, 100 * game.MILL_WATER_MOST, d.outside), DIM)
	part, why := game.mill(m, d)
	if why != .None {
		pane_text(fmt.tprintf("he says: %s", game.TEXT.mill_refused[why]), CHANGED)
		return
	}
	flour := game.part_matter(part)
	pane_text(fmt.tprintf("%.0f g of %v flour (%.0f g a kilogram): starch %.0f%%, sugar %.0f%%, fibre %.0f%%, protein %.0f%%, fat %.0f%%", part.amount, part.food, part.amount * 1000 / m.grams, 100 * flour[.Starch] / part.amount, 100 * flour[.Sugar] / part.amount, 100 * flour[.Fibre] / part.amount, 100 * flour[.Protein] / part.amount, 100 * flour[.Fat] / part.amount), TYPE)
	if s.n < game.BOWL_KINDS {
		if pane_buttons({"into the bowl"}, nil, "the flour into the bowl, all of it (its amount can be changed there)") == 0 {
			s.parts[s.n] = part
			s.n += 1
		}
	}
}

// The foods to choose from, in a grid; the one clicked.
pick_food :: proc() -> (game.Mixable, bool) {
	names: [len(game.Mixable)]string
	for f in game.Mixable {names[int(f)] = fmt.tprintf("%v", f)}
	k := pane_buttons(names[:], nil, "the food for this part")
	return game.Mixable(max(k, 0)), k >= 0
}

draw_mixing_result :: proc(r: Mixing_Result) {
	m, d := r.m, r.d
	pane_heading("What the rules make of it")
	if r.refused != .None {
		pane_text(fmt.tprintf("the bowl will not mix: %v", r.refused), CHANGED)
		return
	}
	pane_text(fmt.tprintf("the mix: %v, %v; %.0f g, %.0f kcal", m.kind, m.consistency, m.grams, m.kcal), TYPE)
	pane_text(fmt.tprintf("free liquid %.0f%%; starch %.0f%% (free %.0f%%), from flours %.0f%%; vegetables %.0f g%s%s", m.free_liquid * 100, 100 * m.matter[.Starch] / m.grams, 100 * m.free_starch, m.flour * 100, m.veg_g, m.lumpy ? ", lumpy" : "", m.tough ? ", tough" : ""), DIM)
	pane_bar("gluten strength", game.gluten_strength(m), 0, 1, game.GLUTEN_DOUGH, 1, game.GLUTEN_LOAF, fmt.tprintf("%.2f (%.1f%%)", game.gluten_strength(m), 100 * m.gluten), "the gluten in its flour against wheat's (0 to 1): from GLUTEN_DOUGH (green) a dough that rises, below it a paste; under GLUTEN_LOAF (the tick) a loaf comes out dense")
	if r.shape_refused != .None {
		pane_text(fmt.tprintf("not shaped: %v", r.shape_refused), CHANGED)
	}
	pane_bar("how well mixed", m.mix_ok, 0, 1, 0, 0, 1, "", "0 to 1: how right the mixing time is for this mix")
	pane_text(fmt.tprintf("the dish: %v%s%s", d.kind, d.lost ? ": nothing left" : "", d.inedible ? ": cannot be eaten" : ""), AMBER)
	if d.lost {return}
	if r.cooked {
		pane_text(fmt.tprintf("at %.0f° for %.1f min: %.0f g, %.0f kcal; %.1f logs of wood; cooking bonus %.2f", r.temp, r.minutes, d.grams, d.kcal, d.wood, r.bonus), DIM)
		pane_bar("the middle", d.inside, 0, 2, game.TIME_RIGHT[0], game.TIME_RIGHT[1], 1, "", "how done the middle is: done at 1; right between TIME_RIGHT's two")
		if d.how != .Boil {
			pane_bar("the outside", d.outside, 0, game.BURNT_CRUST * 1.2, 0, 0, 1, "", "how brown the outside is: golden at 1, burnt at BURNT_CRUST")
			pane_bar("dried", d.dried, 0, 1, 0, game.DRY_RIGHT, game.DRY_AT_BEST, fmt.tprintf("%.0f%%", d.dried * 100), "the share of its water it lost")
		}
	} else {
		pane_text(fmt.tprintf("as it stands: %.0f g, %.0f kcal", d.grams, d.kcal), DIM)
	}
	if d.flaws != {} {
		names: [dynamic]string
		names.allocator = context.temp_allocator
		for f in d.flaws {append(&names, strings.to_lower(fmt.tprintf("%v", f), context.temp_allocator))}
		pane_text(fmt.tprintf("flaws: %s", strings.join(names[:], ", ", context.temp_allocator)), CHANGED)
	}
	pane_bar("taste", d.taste, -1, 1, 0, 0, -1e9, "", "-1 to 1: how good it tastes")
	pane_bar("consistency", d.consistency, 0, 1, 0, 0, 1, fmt.tprintf("%.2f %v", d.consistency, d.texture), "0 to 1: how right its texture is (and the texture)")
	pane_bar("microorganisms", d.microbes, 0, game.MICROBES_MOST, 0, game.UNSAFE_MICROBES, -1e9, fmt.tprintf("10^%.1f/g", d.microbes), "its microorganisms, a power of ten per gram: a tummy ache from UNSAFE_MICROBES, spoiled from SPOILED_MICROBES")
	pane_bar("keeping", d.keeping, 0, 1, 0, 0, -1e9, "", "0 to 1: how fast microorganisms grow in it (low keeps well)")
	pane_bar("hardness", d.hardness, 0, 1, 0, 0, -1e9, "", "0 to 1: how hard it is")
	if d.heated {
		pane_bar("cooking bonus got", d.energy, 0, 1, 0, 0, 1, "", "0 to 1: how much of the cooking bonus it got")
	}
	effects := strings.builder_make(context.temp_allocator)
	if d.unsafe {strings.write_string(&effects, "a tummy ache (its microorganisms); ")}
	if d.hard {strings.write_string(&effects, "a tummy ache (it wants cooking); ")}
	if d.spoiled {strings.write_string(&effects, "spoiled: he will not eat it; ")}
	if d.inedible {strings.write_string(&effects, "cannot be eaten; ")}
	said := strings.trim_suffix(strings.to_string(effects), "; ")
	pane_text(strings.builder_len(effects) > 0 ? said : "safe to eat", strings.builder_len(effects) > 0 ? CHANGED : TYPE)
}

// What crosses a swap: the bowl and how it is cooked.
mixing_text :: proc() -> string {
	s := mixing
	b := strings.builder_make(context.temp_allocator)
	fmt.sbprintf(&b, "#mix %d %v %v %v %v %d %d %v %d %v %v", s.n, s.prep.minutes, s.best_mix, s.prep.washed, s.prep.pressed, int(s.shape), int(s.how), s.temp, int(s.spit), s.minutes, s.best_cook)
	for part in s.parts[:s.n] {fmt.sbprintf(&b, " %d %v %v %v %v", int(part.food), part.amount, part.milled, part.water, part.microbes)}
	strings.write_byte(&b, '\n')
	return strings.to_string(b)
}

take_mixing_text :: proc(line: string) {
	w := strings.fields(line, context.temp_allocator)
	if len(w) < 12 || w[0] != "#mix" {return}
	f :: proc(s: string) -> f32 {v, _ := strconv.parse_f32(s); return v}
	n :: proc(s: string) -> int {v, _ := strconv.parse_int(s); return v}
	s := &mixing
	count := clamp(n(w[1]), 0, game.BOWL_KINDS)
	if len(w) < 12 + 5 * count {return}
	s.n = count
	s.prep.minutes, s.best_mix, s.prep.washed, s.prep.pressed = f(w[2]), w[3] == "true", w[4] == "true", w[5] == "true"
	s.shape = game.Dough_Shape(clamp(n(w[6]), 0, len(game.Dough_Shape) - 1))
	s.how = Cooking(clamp(n(w[7]), 0, len(Cooking) - 1))
	s.temp, s.spit, s.minutes, s.best_cook = f(w[8]), game.Spit(clamp(n(w[9]), 0, len(game.Spit) - 1)), f(w[10]), w[11] == "true"
	for i in 0 ..< count {
		at := 12 + 5 * i
		s.parts[i] = {food = game.Mixable(clamp(n(w[at]), 0, len(game.Mixable) - 1)), amount = f(w[at + 1]), milled = w[at + 2] == "true", water = f(w[at + 3]), microbes = f(w[at + 4])}
	}
}

// "mixing ..." from the menu or from outside.
mixing_command :: proc(words: []string, line: string) -> string {
	s := &mixing
	if len(words) < 2 {return "mixing bowl ... | minutes N | best | shape S | cook stands|oven|fire|pot | temp N | spit high|middle|low | time N | wash | press | result"}
	num := len(words) > 2 ? cmd.f32_of(words, 2, 0) : 0
	switch words[1] {
	case "bowl":
		i := strings.index(strings.to_lower(line, context.temp_allocator), "bowl")
		parts, count, err := cmd.parse_bowl(line[i + 4:])
		if err != "" {return err}
		s.parts, s.n, s.picking = parts, count, -1
	case "minutes": s.prep.minutes, s.best_mix = num, false
	case "best": s.best_mix, s.best_cook = true, true
	case "shape":
		if len(words) > 2 {
			if sh, ok := cmd.enum_named(game.Dough_Shape, words[2]); ok {s.shape = sh}
		}
	case "cook":
		switch len(words) > 2 ? words[2] : "" {
		case "stands", "raw": s.how = .Stands
		case "oven", "bake": s.how = .Bake
		case "fire", "grill": s.how = .Grill
		case "pot", "boil": s.how = .Boil
		}
	case "temp": s.temp, s.best_cook = num, false
	case "spit":
		if len(words) > 2 {
			if sp, ok := cmd.enum_named(game.Spit, words[2]); ok {s.spit, s.best_cook = sp, false}
		}
	case "time": s.minutes, s.best_cook = num, false
	case "wash": s.prep.washed = !s.prep.washed
	case "press": s.prep.pressed = !s.prep.pressed
	case "dry":
		if len(words) > 2 {
			if f, ok := cmd.food_named(words[2]); ok {s.dry.food = f}
		}
		if len(words) > 3 {s.dry.amount = cmd.f32_of(words, 3, s.dry.amount)}
		s.dry_best = true
		parts := [1]game.Bowl_Part{s.dry}
		m, _ := game.mix_bowl(parts[:], {})
		mins := game.drying_minutes(m, s.dry_temp)
		_, d, _ := game.dry_food(s.dry, s.dry_temp, mins)
		part, why := game.mill(m, d)
		if why != .None {return fmt.tprintf("dried %.1f h at %.0f°: %s", mins / 60, s.dry_temp, game.TEXT.mill_refused[why])}
		return fmt.tprintf("dried %.1f h at %.0f°: %.0f g of %v flour from %.0f g", mins / 60, s.dry_temp, part.amount, part.food, m.grams)
	case "mill":
		parts := [1]game.Bowl_Part{s.dry}
		m, _ := game.mix_bowl(parts[:], {})
		_, d, _ := game.dry_food(s.dry, s.dry_temp, s.dry_best ? game.drying_minutes(m, s.dry_temp) : s.dry_mins)
		part, why := game.mill(m, d)
		if why != .None {return fmt.tprintf("%s", game.TEXT.mill_refused[why])}
		if s.n >= game.BOWL_KINDS {return "the bowl is full"}
		s.parts[s.n] = part
		s.n += 1
	case "result":
	case: return "?"
	}
	r := mixing_result()
	if r.refused != .None {return fmt.tprintf("the bowl will not mix: %v", r.refused)}
	d := r.d
	return fmt.tprintf("%s; mix %v %v %.0f g, gluten %.1f%% strength %.2f, mixed %.1f min (best %.1f, ok %.2f); %s %v: %.0f g %.0f kcal, at %.0f° %.1f min (best %.0f° %.1f min), middle %.2f outside %.2f dried %.2f, taste %.2f, %v %.2f, microbes %.1f, keeping %.2f, energy %.2f, hardness %.2f, flaws %v%s",
		bowl_text(), r.m.kind, r.m.consistency, r.m.grams, 100 * r.m.gluten, game.gluten_strength(r.m), s.best_mix ? r.best_mix : s.prep.minutes, r.best_mix, r.m.mix_ok, COOKING_NAMES[s.how], d.kind, d.grams, d.kcal, r.temp, r.minutes, r.best_temp, r.best_minutes,
		d.inside, d.outside, d.dried, d.taste, d.texture, d.consistency, d.microbes, d.keeping, d.energy, d.hardness, d.flaws, d.unsafe ? ", unsafe" : "")
}

bowl_text :: proc() -> string {
	b := strings.builder_make(context.temp_allocator)
	for part, i in mixing.parts[:mixing.n] {
		fmt.sbprintf(&b, "%s%v%s %s", i > 0 ? ", " : "", cmd.number_text(part.amount), part.milled ? " g" : UNIT_NAMES[game.MIXABLE[part.food].unit], part_name(part))
	}
	return strings.to_string(b)
}
