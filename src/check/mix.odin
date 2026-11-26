package check

// Tries bowls from a shell (see src/game/mixing.odin):
//
//   tools/check.sh mix "500g flour, 300ml water" "250g flour, 2 eggs, 300ml milk"
//   tools/check.sh mix "500g flour, 300ml water" --mix 8 --bake 200 40 --grill low 15
//   tools/check.sh mix "300g cabbage, 100g carrot" --wash
//   tools/check.sh mix "100g flour, 60ml water" --shape wrapped --fill "60g cheese" --boil 8
//   tools/check.sh mix "500g cucumber, 500ml water, 15g salt" --stand 7 20
//   tools/check.sh mix "500g grapes" --press --stand 10 20 --stand 30 20 --air
//   tools/check.sh mix "300g meat" --keep-before 24 4 --keep 48 24
//   tools/check.sh mix --walk
//
// A bowl is one argument: parts split by commas, each a food and how much
// of it (500g, 300ml, 2 eggs, 3 pinches; a bare number is in the food's own
// unit). Names in any case, a plural left on or not. --wash washes it first,
// --press presses its fruit and vegetables to juice; --keep-before HOURS
// DEGREES keeps the foods that long, whole (an egg in its shell), before
// they go in. --mix MINUTES mixes it so long (else at its best). --shape
// loaf|flat|wrapped|layered|strips|lumps shapes a dough, round or with
// --fill "a bowl" (mixed at its best). --stand DAYS DEGREES leaves it in a
// crock, with --air open to the air (each --stand goes on from the last).
// Then it is shown as it stands, and in the oven, on the fire and in a pot
// at their best; --bake DEGREES MINUTES, --grill DEGREES|high|middle|low
// MINUTES and --boil MINUTES choose instead, and show only those. --keep
// HOURS DEGREES keeps what comes out, to see its microorganisms. --skill S
// (0 to 1) shows the editor's intervals at that skill as well as a
// beginner's and a master's. --walk tries a grid of bowls and says how many
// come out as each kind, and the range of their best settings.

import game "../game"
import "core:fmt"
import "core:reflect"
import "core:strconv"
import "core:strings"

MIX_MOST_PARTS :: 8 // read, so that a bowl over the limit can be shown refused
STANDS_MOST :: 4

Stand_Option :: struct {
	days, temp: f32,
	air:        bool,
}

Mix_Options :: struct {
	mix:          f32, // < 0: the best
	prep:         game.Prep,
	shape:        game.Dough_Shape,
	fill:         string,
	stands:       [STANDS_MOST]Stand_Option,
	n_stands:     int,
	chosen:       bit_set[game.Heating], // none: all, at their best
	temp, time:   [game.Heating]f32, // < 0: the best
	keep:         [2]f32,
	skill:        f32, // < 0: none asked
	dry:          bool, // dried and milled instead
	dry_temp:     f32, // < 0: DRY_TEMP
	dry_minutes:  f32, // < 0: until it mills
}

// Reads one bowl. A part that names nothing known is an error.
parse_bowl :: proc(text: string, parts: ^[MIX_MOST_PARTS]game.Bowl_Part) -> (n: int, err: string) {
	rest := text
	for piece in strings.split_iterator(&rest, ",") {
		words := strings.fields(piece, context.temp_allocator)
		if len(words) == 0 {
			continue
		}
		amount: f32 = 1
		unit := ""
		name := strings.builder_make(context.temp_allocator)
		for word in words {
			lower := strings.to_lower(word, context.temp_allocator)
			// A number, maybe with its unit stuck on.
			digits := 0
			for digits < len(lower) && (lower[digits] >= '0' && lower[digits] <= '9' || lower[digits] == '.') {
				digits += 1
			}
			if digits > 0 {
				v, _ := strconv.parse_f32(lower[:digits])
				amount = v
				if digits < len(lower) {
					unit = lower[digits:]
				}
				continue
			}
			switch lower {
			case "g", "gram", "grams", "ml", "millilitre", "millilitres", "pinch", "pinches":
				unit = lower
				continue
			case "of", "pepper":
				continue
			}
			if strings.builder_len(name) > 0 {
				strings.write_byte(&name, '_')
			}
			strings.write_string(&name, word)
		}
		food, known := mixable_named(strings.to_string(name))
		// "potato flour": a potato dried until it mills, and milled.
		milled := false
		if !known && strings.has_suffix(strings.to_lower(strings.to_string(name), context.temp_allocator), "_flour") {
			food, known = mixable_named(strings.to_string(name)[:strings.builder_len(name) - len("_flour")])
			milled = known
		}
		if !known {
			return n, fmt.tprintf("no food called \"%s\"", strings.trim_space(piece))
		}
		if n == MIX_MOST_PARTS {
			return n, fmt.tprintf("more than %d parts", MIX_MOST_PARTS)
		}
		grams: f32 = -1
		switch unit {
		case "g", "gram", "grams", "ml", "millilitre", "millilitres":
			grams = amount
		case "pinch", "pinches":
			grams = amount * game.PINCH_G
		case "", "egg", "eggs":
		case:
			return n, fmt.tprintf("no unit called \"%s\"", unit)
		}
		if milled {
			flour, _, why := game.flour_of(food, grams >= 0 ? grams : amount)
			if why != .None {
				return n, fmt.tprintf("%s will not make a flour: %s", lower_text(food), game.TEXT.mill_refused[why])
			}
			parts[n] = flour
			n += 1
			continue
		}
		if grams >= 0 {
			amount = grams / game.unit_grams(food)
		}
		parts[n] = {food = food, amount = amount}
		n += 1
	}
	return
}

mixable_named :: proc(name: string) -> (food: game.Mixable, ok: bool) {
	ies := strings.has_suffix(name, "ies") ? fmt.tprintf("%sy", name[:len(name) - 3]) : name
	tries := [5]string{name, strings.trim_suffix(name, "s"), strings.trim_suffix(name, "es"), ies, name == "chilli" ? "chili" : name}
	for try in tries {
		for field, i in reflect.enum_field_names(game.Mixable) {
			if strings.equal_fold(try, field) {
				return game.Mixable(reflect.enum_field_values(game.Mixable)[i]), true
			}
		}
	}
	return
}

amount_text :: proc(part: game.Bowl_Part) -> string {
	name := lower_text(part.food)
	if part.milled {
		return fmt.tprintf("%s g %s flour", num(part.amount), name)
	}
	switch game.MIXABLE[part.food].unit {
	case .Gram:
		return fmt.tprintf("%s g %s", num(part.amount), name)
	case .Millilitre:
		return fmt.tprintf("%s ml %s", num(part.amount), name)
	case .Egg:
		return fmt.tprintf("%s %s%s", num(part.amount), name, part.amount == 1 ? "" : "s")
	case .Pinch:
		return fmt.tprintf("%s pinch%s %s", num(part.amount), part.amount == 1 ? "" : "es", name)
	}
	return ""
}

bowl_text :: proc(parts: []game.Bowl_Part) -> string {
	b := strings.builder_make(context.temp_allocator)
	for part, i in parts {
		if i > 0 {
			strings.write_string(&b, ", ")
		}
		strings.write_string(&b, amount_text(part))
	}
	return strings.to_string(b)
}

// A number as short as it can be written: 3, 1.5, 0.25.
num :: proc(v: f32) -> string {
	if v == f32(i64(v)) {
		return fmt.tprintf("%d", i64(v))
	}
	s := fmt.tprintf("%.2f", v)
	s = strings.trim_right(s, "0")
	return strings.trim_suffix(s, ".")
}

kind_text :: proc(kind: $T) -> string {
	s, _ := strings.replace_all(strings.to_upper(fmt.tprint(kind), context.temp_allocator), "_", " ", context.temp_allocator)
	return s
}

lower_text :: proc(v: $T) -> string {
	s, _ := strings.replace_all(strings.to_lower(fmt.tprint(v), context.temp_allocator), "_", " ", context.temp_allocator)
	return s
}

REFUSAL_TEXT := [game.Bowl_Refusal]string {
	.None           = "",
	.Empty          = "the bowl is empty",
	.No_Amount      = "a part of nothing",
	.Not_Whole      = "part of an egg",
	.Too_Many_Kinds = "more kinds of food than a bowl takes",
	.Too_Much       = "more than a bowl holds",
	.Twice          = "the same food twice",
}

SHAPE_REFUSAL_TEXT := [game.Shape_Refusal]string {
	.None            = "",
	.Not_Dough       = "only a dough takes a shape",
	.Needs_Filling   = "that shape needs a filling (--fill)",
	.No_Filling_Here = "that shape takes no filling",
}

Mix_Row :: struct {
	text:    string,
	refused: game.Bowl_Refusal,
	mix:     game.Mix,
	raw:     game.Dish,
	dishes:  [game.Heating]game.Dish,
}

spit_named :: proc(word: string) -> (temp: f32, ok: bool) {
	for spit in game.Spit {
		if strings.equal_fold(word, fmt.tprint(spit)) {
			return game.SPIT_TEMP[spit], true
		}
	}
	v, parsed := strconv.parse_f32(word)
	return v, parsed
}

shape_named :: proc(word: string) -> (shape: game.Dough_Shape, ok: bool) {
	for s in game.Dough_Shape {
		if strings.equal_fold(word, fmt.tprint(s)) {
			return s, true
		}
	}
	return
}

mix_command :: proc(args: []string) -> int {
	if len(args) == 1 && args[0] == "--walk" {
		return walk_command()
	}
	opts := Mix_Options {
		mix   = -1,
		skill = -1,
		temp  = {.Bake = -1, .Grill = -1, .Boil = -1},
		time  = {.Bake = -1, .Grill = -1, .Boil = -1},
	}
	bowls := make([dynamic]string, context.temp_allocator)
	number :: proc(args: []string, i: int) -> f32 {
		if i >= len(args) {
			return -1
		}
		v, _ := strconv.parse_f32(args[i])
		return v
	}
	usage := false
	for i := 0; i < len(args); i += 1 {
		switch args[i] {
		case "--mix":
			opts.mix = number(args, i + 1)
			i += 1
		case "--wash":
			opts.prep.washed = true
		case "--press":
			opts.prep.pressed = true
		case "--keep-before":
			opts.prep.kept_hours, opts.prep.kept_temp = number(args, i + 1), number(args, i + 2)
			i += 2
		case "--shape":
			ok: bool
			if i + 1 < len(args) {
				opts.shape, ok = shape_named(args[i + 1])
			}
			usage ||= !ok
			i += 1
		case "--fill":
			if i + 1 < len(args) {
				opts.fill = args[i + 1]
			}
			i += 1
		case "--stand":
			if opts.n_stands < STANDS_MOST {
				opts.stands[opts.n_stands] = {number(args, i + 1), number(args, i + 2), false}
				opts.n_stands += 1
			}
			i += 2
		case "--air":
			if opts.n_stands > 0 {
				opts.stands[opts.n_stands - 1].air = true
			}
		case "--bake":
			opts.chosen += {.Bake}
			opts.temp[.Bake], opts.time[.Bake] = number(args, i + 1), number(args, i + 2)
			i += 2
		case "--grill":
			opts.chosen += {.Grill}
			if i + 1 < len(args) {
				opts.temp[.Grill], _ = spit_named(args[i + 1])
			}
			opts.time[.Grill] = number(args, i + 2)
			i += 2
		case "--boil":
			opts.chosen += {.Boil}
			opts.time[.Boil] = number(args, i + 1)
			i += 1
		case "--keep":
			opts.keep = {number(args, i + 1), number(args, i + 2)}
			i += 2
		case "--dry":
			opts.dry = true
			opts.dry_temp, opts.dry_minutes = number(args, i + 1), number(args, i + 2)
			if opts.dry_temp >= 0 {i += 1}
			if opts.dry_minutes >= 0 {i += 1}
		case "--skill":
			opts.skill = number(args, i + 1)
			i += 1
		case:
			if strings.has_prefix(args[i], "--") {
				usage = true
			} else {
				append(&bowls, args[i])
			}
		}
	}
	if len(bowls) == 0 || usage {
		fmt.println(`tools/check.sh mix "500g flour, 300ml water" [--wash] [--press] [--keep-before H DEG] [--mix MIN]`)
		fmt.println(`    [--shape loaf|flat|wrapped|layered|strips|lumps [--fill "60g cheese"]] [--stand DAYS DEG [--air]]...`)
		fmt.println(`    [--bake DEG MIN] [--grill DEG|high|middle|low MIN] [--boil MIN] [--keep H DEG] [--skill S]`)
		fmt.println(`tools/check.sh mix "1000g potato" --dry [DEG [MIN]]   (dried, cut thin, and milled; "200g potato flour" in a bowl is that flour)`)
		fmt.println(`tools/check.sh mix --walk`)
		fmt.print("Foods: ")
		for food in game.Mixable {
			fmt.printf("%s%s (%s)", int(food) > 0 ? ", " : "", lower_text(food), lower_text(game.MIXABLE[food].unit))
		}
		fmt.println()
		return 1
	}
	bad := 0
	rows := make([dynamic]Mix_Row, context.temp_allocator)
	for text in bowls {
		parts: [MIX_MOST_PARTS]game.Bowl_Part
		n, err := parse_bowl(text, &parts)
		if err != "" {
			fmt.printf("%s\n  cannot read it: %s\n\n", text, err)
			bad += 1
			continue
		}
		row := Mix_Row {
			text = bowl_text(parts[:n]),
		}
		fmt.println(row.text)
		if opts.dry {
			dry_report(parts[:n], opts.dry_temp, opts.dry_minutes)
			continue
		}
		_, row.refused = game.mix_bowl(parts[:n], opts.prep)
		if row.refused != .None {
			fmt.printf("  refused: %s (at most %d kinds, %s g)\n\n", REFUSAL_TEXT[row.refused], game.BOWL_KINDS, num(game.BOWL_MOST_G))
			append(&rows, row)
			bad += 1
			continue
		}
		ok: bool
		row.mix, row.raw, row.dishes, ok = show_bowl(parts[:n], opts)
		if !ok {
			bad += 1
		}
		append(&rows, row)
	}
	if len(rows) > 1 {
		mix_table(rows[:], opts)
	}
	return bad
}

// One food dried in the oven, cut thin (at DRY_TEMP until it mills, unless
// told), and milled: how dry it came out, and the flour, with what it is
// made of and how much a kilogram gives.
dry_report :: proc(parts: []game.Bowl_Part, temp, minutes: f32) {
	if len(parts) != 1 {
		fmt.printf("  --dry dries one food at a time\n\n")
		return
	}
	m, refused := game.mix_bowl(parts, {})
	if refused != .None {
		fmt.printf("  refused: %s\n\n", REFUSAL_TEXT[refused])
		return
	}
	t := temp >= 0 ? temp : game.DRY_TEMP
	mins := minutes >= 0 ? minutes : max(game.drying_minutes(m, t), 0)
	_, d, _ := game.dry_food(parts[0], t, mins)
	fmt.printf("  dried    cut thin, at %.0f° for %.0f min (%.1f h): %.0f g left, %.0f%% of its water gone, water now %.1f%% of it (it mills at %.0f%% or less); outside %.2f, %s\n",
		t, mins, mins / 60, d.grams, 100 * d.dried, 100 * d.matter[.Water] / max(d.grams, 1e-6), 100 * game.MILL_WATER_MOST, d.outside, kind_text(d.kind))
	part, why := game.mill(m, d)
	if why != .None {
		fmt.printf("  milled   no: %s\n\n", game.TEXT.mill_refused[why])
		return
	}
	flour := game.part_matter(part)
	fmt.printf("  milled   %.0f g of %s flour from %.0f g: %.0f g a kilogram\n", part.amount, lower_text(part.food), m.grams, part.amount * 1000 / m.grams)
	fmt.print("  in 100 g")
	for v, k in flour {
		if v >= 0.05 {fmt.printf(" %s %s", lower_text(k), num_g(v * 100 / part.amount))}
	}
	fmt.printf("  (%.0f kcal; gluten %.1f g)\n\n", game.part_kcal(part) * 100 / part.amount, game.part_gluten(part, flour) * 100 / part.amount)
}

// A bowl mixed at its best, or for so many minutes.
mixed :: proc(parts: []game.Bowl_Part, prep: game.Prep, minutes: f32 = -1) -> game.Mix {
	p := prep
	probe, _ := game.mix_bowl(parts, p)
	p.minutes = minutes >= 0 ? minutes : probe.best_minutes
	m, _ := game.mix_bowl(parts, p)
	return m
}

// Prints one bowl: what it is made of, the mix, what is done to it, and
// what it is as it stands and in the oven, on the fire and in a pot.
show_bowl :: proc(parts: []game.Bowl_Part, opts: Mix_Options) -> (m: game.Mix, raw: game.Dish, dishes: [game.Heating]game.Dish, ok: bool) {
	m = mixed(parts, opts.prep, opts.mix)
	ok = true
	show_matter("  parts   ", m.matter, m.grams, m.kcal)
	if opts.prep.washed || opts.prep.pressed || opts.prep.kept_hours > 0 {
		fmt.print("  before  ")
		if opts.prep.kept_hours > 0 {
			fmt.printf(" kept %s h at %s° (whole)", num(opts.prep.kept_hours), num(opts.prep.kept_temp))
		}
		if opts.prep.washed {fmt.print(" washed")}
		if opts.prep.pressed {fmt.print(" pressed")}
		fmt.println()
	}
	fmt.printf("  mix      free liquid %.0f%%: %s, so %s", m.free_liquid * 100, lower_text(m.consistency), kind_text(m.kind))
	fmt.printf("  (starch %.0f%% (free in the mix %.0f%%), from flours %.0f%%, gluten %.1f%% (strength %.2f); vegetables and fruit %.0f%%, pieces %.0f%%, sets %.1f%%", 100 * m.matter[.Starch] / m.grams, 100 * m.free_starch, 100 * m.flour, 100 * m.gluten, game.gluten_strength(m), 100 * m.veg_g / m.grams, 100 * m.filling_g / m.grams, 100 * m.setting)
	if m.matter[.Acid] > 0 {fmt.printf(", acid %.2f%%", 100 * m.matter[.Acid] / m.grams)}
	if m.bitter > 0 {fmt.printf(", bitter %.4f/g", m.bitter)}
	if m.heat > 0 {fmt.printf(", chili %.1f/kg", m.heat)}
	fmt.println(")")
	verdict := m.n == 1 ? "one thing: nothing to mix" : (m.lumpy ? "LUMPY" : (m.tough ? "TOUGH" : "right"))
	fmt.printf("  mixing   best %.1f min; mixed %.1f: %s (%.2f)\n", m.best_minutes, m.minutes, verdict, m.mix_ok)
	intervals("           editor:", m.best_minutes, .Mixing, game.recipe_key(m, .Bake), opts.skill)
	if opts.shape != .Loaf || opts.fill != "" {
		filling: game.Mix
		fill: ^game.Mix
		if opts.fill != "" {
			fparts: [MIX_MOST_PARTS]game.Bowl_Part
			fn, err := parse_bowl(opts.fill, &fparts)
			if err != "" {
				fmt.printf("  filling  cannot read it: %s\n\n", err)
				return m, raw, dishes, false
			}
			if _, why := game.mix_bowl(fparts[:fn], opts.prep); why != .None {
				fmt.printf("  filling  refused: %s\n\n", REFUSAL_TEXT[why])
				return m, raw, dishes, false
			}
			filling = mixed(fparts[:fn], opts.prep)
			fill = &filling
		}
		shaped, why := game.shape_mix(m, opts.shape, fill)
		if why != .None {
			fmt.printf("  shape    refused: %s\n\n", SHAPE_REFUSAL_TEXT[why])
			return m, raw, dishes, false
		}
		fmt.printf("  shaped   %s", lower_text(opts.shape))
		if fill != nil {
			fmt.printf(", with %s (a %s, %.0f g)", bowl_text(filling.parts[:filling.n]), lower_text(filling.kind), filling.grams)
		}
		fmt.printf(": %.0f g in all\n", shaped.grams)
		m = shaped
	}
	for i in 0 ..< opts.n_stands {
		st := opts.stands[i]
		before := m
		m = game.stand(m, st.days, st.temp, st.air)
		fmt.printf("  crock    %s days at %s°%s: %s;  microbes 10^%.1f to 10^%.1f a gram", num(st.days), num(st.temp), st.air ? ", open to the air" : "", kind_text(m.crock), before.microbes, m.microbes)
		fmt.printf(";  acid %.2f%%, alcohol %.2f%%, sugar %.2f%%", 100 * m.matter[.Acid] / m.grams, 100 * m.matter[.Alcohol] / m.grams, 100 * m.matter[.Sugar] / m.grams)
		fmt.printf(";  %.0f g (%+.0f as gas)\n", m.grams, -(m.gas_lost - before.gas_lost))
	}
	raw = game.as_it_stands(m)
	fmt.printf("  as it is %s", kind_text(raw.kind))
	if raw.kind == .Raw {
		fmt.printf(" (%s)", lower_text(m.kind))
	}
	fmt.println()
	show_effects(raw, raw, opts)
	key: [game.Heating]u32
	for how in game.Heating {
		key[how] = game.recipe_key(m, how)
		if opts.chosen == {} || how in opts.chosen {
			dishes[how] = show_heat(m, how, opts, key[how])
		}
	}
	fmt.println()
	return
}

show_matter :: proc(label: string, matter: game.Grams, grams, kcal: f32) {
	fmt.print(label)
	for v, k in matter {
		if v >= 0.05 || k == .Water {
			fmt.printf(" %s %s", lower_text(k), num_g(v))
		}
	}
	fmt.printf("  (%.0f g, %.0f kcal)\n", grams, kcal)
}

// Grams, to a tenth under 10.
num_g :: proc(v: f32) -> string {
	return v < 10 ? fmt.tprintf("%.1f", v) : fmt.tprintf("%.0f", v)
}

intervals :: proc(label: string, best: f32, setting: game.Setting, key: u32, skill: f32) {
	b0, b1 := game.setting_interval(best, setting, 0, key)
	m0, m1 := game.setting_interval(best, setting, 1, key)
	fmt.printf("%s beginner %.0f to %.0f, master %.1f to %.1f", label, b0, b1, m0, m1)
	if skill >= 0 {
		s0, s1 := game.setting_interval(best, setting, skill, key)
		fmt.printf(", at %s %.1f to %.1f", num(skill), s0, s1)
	}
	fmt.println()
}

HEAT_NAME := [game.Heating]string {
	.Bake  = "oven",
	.Grill = "fire",
	.Boil  = "pot ",
}

STATION := [game.Heating]game.Station_Kind {
	.Bake  = .Oven,
	.Grill = .Fire,
	.Boil  = .Fire,
}

show_heat :: proc(m: game.Mix, how: game.Heating, opts: Mix_Options, key: u32) -> game.Dish {
	best_temp, best_time := game.best_settings(m, how)
	switch how {
	case .Bake:
		fmt.printf("  oven     best %.0f° (right ±%.0f), %.1f min", best_temp, game.temperature_right(m), best_time)
	case .Grill:
		fmt.printf("  fire     best the %s spit (%.0f°; ideal %.0f°), %.1f min", lower_text(game.best_spit(m)), best_temp, game.best_temperature(m), best_time)
	case .Boil:
		fmt.printf("  pot      best %.1f min at the boil", best_time)
	}
	fmt.printf(" (right %.1f to %.1f)\n", best_time * game.TIME_RIGHT[0], best_time * game.TIME_RIGHT[1])
	intervals("           editor, time:", best_time, .Cooking, key, opts.skill)
	if how == .Bake {
		intervals("           editor, degrees:", best_temp, .Temperature, key, opts.skill)
	}
	t := opts.temp[how] >= 0 ? opts.temp[how] : best_temp
	mins := opts.time[how] >= 0 ? opts.time[how] : (opts.temp[how] >= 0 ? game.best_minutes_at(m, how, t) : best_time)
	beginner := game.cook(m, how, t, mins, game.COOK_RANGE[STATION[how]][0])
	master := game.cook(m, how, t, mins, game.COOK_RANGE[STATION[how]][1])
	d := beginner
	fmt.printf("    at %.0f° for %.1f min: %s", d.temperature, mins, kind_text(d.kind))
	if d.lost {
		fmt.println(": nothing left")
		return d
	}
	fmt.printf("   middle %.2f", d.inside)
	if how != .Boil {
		fmt.printf(", outside %.2f, dried %.0f%%", d.outside, d.dried * 100)
	}
	if d.water_gained > 0 {fmt.printf(", took up %.0f g of water", d.water_gained)}
	if d.water_held > 0 {fmt.printf(", %.0f g of water held by its starch (thickened)", d.water_held)}
	if how == .Boil && d.water_lost > 0 {fmt.printf(", boiled down %.0f g", d.water_lost)}
	if d.poured_off > 0 {fmt.printf(", its liquid (%.0f g) gone", d.poured_off)}
	if d.alcohol_lost > 0 {fmt.printf(", alcohol %.1f g driven off", d.alcohol_lost)}
	fmt.println()
	show_effects(d, master, opts)
	return d
}

// Safety, taste, texture, keeping, energy, weight and hardness.
show_effects :: proc(d, master: game.Dish, opts: Mix_Options) {
	if d.flaws != {} {
		fmt.print("      ")
		first := true
		for flaw in d.flaws {
			fmt.printf("%s%s", first ? "" : ", ", lower_text(flaw))
			first = false
		}
		fmt.println()
	}
	safety := "safe"
	switch {
	case d.spoiled:
		safety = "SPOILED: he will not eat it"
	case d.unsafe && d.hard:
		safety = fmt.tprintf("UNSAFE (tummy ache %.1f), and hard to digest", d.microbes - game.UNSAFE_MICROBES)
	case d.unsafe:
		safety = fmt.tprintf("UNSAFE: tummy ache %.1f", d.microbes - game.UNSAFE_MICROBES)
	case d.hard:
		safety = "HARD TO DIGEST: tummy ache"
	}
	fmt.printf("      safety 10^%.1f/g %s;  taste %+.2f;  %s, consistency %.2f;  keeps %.2f", d.microbes, safety, d.taste, lower_text(d.texture), d.consistency, d.keeping)
	if d.microbes > game.UNSAFE_MICROBES {
	} else if hours := game.hours_until_unsafe(d.microbes, 20, d.keeping); hours < 1e6 {
		fmt.printf(" (unsafe after %s at 20°)", hours_text(hours))
	} else if d.microbes <= game.UNSAFE_MICROBES {
		fmt.print(" (never goes off at 20°)")
	}
	fmt.println()
	if d.inedible {
		fmt.printf("      CANNOT BE EATEN;  weight %.0f g;  hardness %.2f", d.grams, d.hardness)
	} else if d.heated {
		fmt.printf("      energy %.2f: %.0f kcal (beginner), %.0f (master);  weight %.0f g;  hardness %.2f", d.energy, d.kcal, master.kcal, d.grams, d.hardness)
	} else {
		fmt.printf("      %.0f kcal;  weight %.0f g;  hardness %.2f", d.kcal, d.grams, d.hardness)
	}
	if d.matter[.Alcohol] > 0.05 {fmt.printf(";  alcohol %.1f%% by weight, %.1f%% by volume", 100 * d.matter[.Alcohol] / d.grams, 100 * d.matter[.Alcohol] / game.ALCOHOL_DENSITY / d.grams)}
	if d.heat > 0 {fmt.printf(";  chili %.1f/kg", d.heat)}
	if d.heated {
		fmt.printf(";  %.2f logs, %.0f s wait", d.wood, game.cook_seconds(d.minutes))
	}
	fmt.println()
	if opts.keep[0] > 0 && !d.inedible {
		after := game.microbes_grown(d.microbes, opts.keep[1], opts.keep[0], d.keeping)
		state := after >= game.SPOILED_MICROBES ? "SPOILED" : (after > game.UNSAFE_MICROBES ? "UNSAFE" : "safe")
		fmt.printf("      kept %s at %s°: 10^%.1f/g, %s\n", hours_text(opts.keep[0]), num(opts.keep[1]), after, state)
	}
}

hours_text :: proc(hours: f32) -> string {
	if hours >= 48 {
		return fmt.tprintf("%.1f days", hours / game.DAY_HOURS)
	}
	return fmt.tprintf("%.0f h", hours)
}

// All the bowls, a line each.
mix_table :: proc(rows: []Mix_Row, opts: Mix_Options) {
	wide := len("bowl")
	for row in rows {
		wide = max(wide, len(row.text))
	}
	fmt.printf("%-*s  liquid  %-9s  mix   %-12s %-14s %-14s %-14s\n", wide, "bowl", "mix", "as it is", "oven", "fire", "pot")
	for row in rows {
		if row.refused != .None {
			fmt.printf("%-*s  refused: %s\n", wide, row.text, REFUSAL_TEXT[row.refused])
			continue
		}
		m := row.mix
		fmt.printf("%-*s  %4.0f%%   %-9s %4.1f   %-12s", wide, row.text, m.free_liquid * 100, kind_text(m.kind), m.best_minutes, dish_text(row.raw))
		for how in game.Heating {
			fmt.printf(" %-14s", opts.chosen == {} || how in opts.chosen ? dish_text(row.dishes[how]) : "")
		}
		fmt.println()
	}
	fmt.println("(! a tummy ache, x he will not eat it)")
}

dish_text :: proc(d: game.Dish) -> string {
	switch {
	case d.spoiled:
		return fmt.tprintf("%s x", kind_text(d.kind))
	case d.unsafe || d.hard:
		return fmt.tprintf("%s!", kind_text(d.kind))
	}
	return kind_text(d.kind)
}

// ---- The walk: a grid of bowls. ----

// Amounts tried of each food, by its unit.
WALK_AMOUNTS := [game.Unit][4]f32 {
	.Gram       = {50, 150, 400, 1000},
	.Millilitre = {50, 200, 500, 1500},
	.Egg        = {1, 2, 3, 6},
	.Pinch      = {1, 2, 5, 10},
}
WALK_KINDS :: 3 // of food in a bowl, at most

// Calls visit with every bowl of the grid: up to WALK_KINDS foods, each at
// one of its WALK_AMOUNTS; and, after the foods, potato flour (a potato dried
// and milled by the rules), by the gram, for a flour without gluten.
walk_flour: game.Bowl_Part

each_bowl :: proc(visit: proc(parts: []game.Bowl_Part, data: rawptr), data: rawptr) {
	walk_flour, _, _ = game.flour_of(.Potato, 1)
	parts: [WALK_KINDS]game.Bowl_Part
	walk :: proc(parts: ^[WALK_KINDS]game.Bowl_Part, start, depth: int, visit: proc(parts: []game.Bowl_Part, data: rawptr), data: rawptr) {
		if depth > 0 {
			visit(parts[:depth], data)
		}
		if depth == WALK_KINDS {
			return
		}
		for f in start ..< len(game.Mixable) + 1 {
			if f == len(game.Mixable) {
				for amount in WALK_AMOUNTS[.Gram] {
					parts[depth] = walk_flour
					parts[depth].amount = amount
					walk(parts, f + 1, depth + 1, visit, data)
				}
				continue
			}
			food := game.Mixable(f)
			for amount in WALK_AMOUNTS[game.MIXABLE[food].unit] {
				parts[depth] = {food = food, amount = amount}
				walk(parts, f + 1, depth + 1, visit, data)
			}
		}
	}
	walk(&parts, 0, 0, visit, data)
}

Range :: struct {
	low, high: f32,
	any:       bool,
}

widen :: proc(r: ^Range, v: f32) {
	if !r.any {
		r^ = {v, v, true}
		return
	}
	r.low = min(r.low, v)
	r.high = max(r.high, v)
}

Kind_Census :: struct {
	bowls:   int,
	by_kind: [game.Mix_Kind]int,
	dishes:  [game.Heating][game.Dish_Kind]int,
	mixing:  [game.Mix_Kind]Range,
	temp:    [game.Mix_Kind]Range,
	minutes: [game.Heating][game.Mix_Kind]Range,
	example: [game.Mix_Kind]string, // the first the grid comes to
}

census_bowl :: proc(parts: []game.Bowl_Part, data: rawptr) {
	c := (^Kind_Census)(data)
	if _, refused := game.mix_bowl(parts, {}); refused != .None {
		return
	}
	m := mixed(parts, {})
	c.bowls += 1
	c.by_kind[m.kind] += 1
	if c.example[m.kind] == "" {
		c.example[m.kind] = strings.clone(bowl_text(parts))
	}
	widen(&c.mixing[m.kind], m.best_minutes)
	widen(&c.temp[m.kind], game.best_temperature(m))
	for how in game.Heating {
		t, minutes := game.best_settings(m, how)
		d := game.cook(m, how, t, minutes, 1)
		c.dishes[how][d.kind] += 1
		widen(&c.minutes[how][m.kind], minutes)
	}
}

walk_command :: proc() -> int {
	c := new(Kind_Census)
	each_bowl(census_bowl, c)
	fmt.printf("%d bowls: up to %d of the %d foods and potato flour, each at one of 4 amounts (grams %v, millilitres %v, eggs %v, pinches %v)\n\n", c.bowls, WALK_KINDS, len(game.Mixable), WALK_AMOUNTS[.Gram], WALK_AMOUNTS[.Millilitre], WALK_AMOUNTS[.Egg], WALK_AMOUNTS[.Pinch])
	fmt.printf("%-8s %7s %6s   %-11s %-9s %-11s %-11s %-11s  for example\n", "mix", "bowls", "", "mixing min", "degrees", "oven min", "fire min", "pot min")
	for kind in game.Mix_Kind {
		count := c.by_kind[kind]
		if count == 0 {
			fmt.printf("%-8s %7d\n", kind_text(kind), 0)
			continue
		}
		r :: proc(r: Range) -> string {return fmt.tprintf("%.1f-%.1f", r.low, r.high)}
		fmt.printf("%-8s %7d %5.1f%%   %-11s %-9s %-11s %-11s %-11s  %s\n", kind_text(kind), count, 100 * f32(count) / f32(c.bowls), r(c.mixing[kind]), fmt.tprintf("%.0f-%.0f", c.temp[kind].low, c.temp[kind].high), r(c.minutes[.Bake][kind]), r(c.minutes[.Grill][kind]), r(c.minutes[.Boil][kind]), c.example[kind])
	}
	places := [game.Heating]string{.Bake = "in the oven", .Grill = "on the fire", .Boil = "in a pot"}
	for how in game.Heating {
		fmt.printf("\nat their best, %s: ", places[how])
		first := true
		for count, kind in c.dishes[how] {
			if count > 0 {
				fmt.printf("%s%s %d", first ? "" : ", ", lower_text(kind), count)
				first = false
			}
		}
	}
	fmt.println()
	return 0
}
