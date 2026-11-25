package game

import "core:math"

// What things become, as rules: washed, mixed in a bowl for a time, shaped,
// then baked, grilled or boiled at a temperature for a time, or left to
// stand in a crock for days; and how many microorganisms they have, kept so
// long somewhere so warm (docs/plans/wd1b-quantities-times-effects.md and
// docs/plans/wd1c-real-food-rules.md). They are procedures with no state and
// no randomness: the same inputs always give the same result. Nothing in the
// game uses them yet; the next step puts a bowl by the oven. Every number is
// in data/tuning/food.json (MIXABLE, and the mixing section). To try a bowl
// from a shell:
//
//   tools/check.sh mix "500g flour, 300ml water" --mix 8 --bake 200 40
//
// A bowl holds amounts: grams, millilitres, eggs, pinches. Everything in it
// is weight, split into water, starch, sugar, fat, protein, fibre, salt,
// acid, alcohol and the rest, from each food's real calories to the gram
// (carbs and protein 4 kcal a gram, fat 9, fibre 2) and what they are made
// of, its water, the share of its carbs that is sugar and its acid. Its free
// liquid (free water, and half its fat) says how wet it is: crumbly,
// kneadable, pourable or runny. That, with whether there is flour, how much
// is vegetables and fruit, whether there are pieces and enough protein that
// sets, names the mix. Heating it dries it, browns the outside, warms the
// middle and kills microorganisms; past a point it burns. In a pot nothing
// burns, and starch takes up water. In a crock sugar turns to acid or
// alcohol, and alcohol to acid, as microorganisms grow. The best mixing
// time, temperature and cooking time follow from what is in the bowl, how
// much, and its shape. Charcoal (burnt through) and a brick (a dough or a
// slop dried right out) come of cooking badly, and cannot be eaten; nor will
// he eat what has spoiled.

Mixable :: enum u8 {
	Water, // not in the game yet: for the rules only, as everything from Chili on is
	Milk,
	Flour,
	Egg,
	Honey,
	Butter,
	Salt,
	Cheese,
	Berries,
	Apple,
	Pumpkin,
	Cabbage,
	Mushroom,
	Nuts,
	Fish,
	Meat,
	Chili,
	Dill,
	Potato,
	Onion,
	Carrot,
	Beetroot,
	Cucumber,
	Tomato,
	Cauliflower,
	Aubergine,
	Zucchini,
	Radicchio,
	Lemon,
	Orange,
	Peach,
	Pear,
	Plum,
	Cherry,
	Grapes,
	Banana,
}

// What a food is measured in.
Unit :: enum u8 {
	Gram,
	Millilitre, // weighs a gram
	Egg, // by number, ITEM_KG[.Egg] each
	Pinch, // PINCH_G
}

// What sort of thing a food is.
Mark :: enum u8 {
	Leafy, // a leafy vegetable: dry heat ruins it
	Firm, // a firm vegetable: it roasts well
	Fruit, // counts with vegetables towards a salad
	Ground, // grows in the ground: soil on it, wants washing
	Wants_Cooking, // raw it is hard to digest
	Pieces, // stays in pieces in a mix (a filling)
	Mashes, // in a bowl with flour it is mashed into it, starch and all
	Shell, // keeps in its shell until it is cracked into a bowl
}

// What a food is, beyond its calories and shares (MIXABLE).
Mixable_Data :: struct {
	item:                                               Item, // what it is in the sack,
	in_sack:                                            bool, // if it is there at all yet
	unit:                                               Unit,
	water, sugar, acid, bitter, heat, setting, microbes: f32,
	marks:                                              bit_set[Mark],
	waste:                                              f32, // the share of a piece in the sack not eaten
	kcal_100g:                                          f32, // its own calories and shares, for a food not in the sack
	shares:                                             Composition,
}

// What a weight of anything is made of.
Matter :: enum {
	Water,
	Starch,
	Sugar,
	Fat,
	Protein,
	Fibre,
	Salt,
	Acid,
	Alcohol,
	Other, // the rest: minerals, colour, smell
}

Grams :: [Matter]f32

Mix_Kind :: enum {
	Crumbs,
	Dough,
	Batter,
	Slop,
	Egg_Mix,
	Drink,
	Salad, // mostly vegetables and fruit, raw: a dish as it stands
	Pieces, // things in pieces that are not a salad: meat, fish, cheese, nuts
	Mush,
	Soup, // liquid with pieces in it
}

Consistency :: enum {
	Crumbly,
	Kneadable,
	Pourable,
	Runny,
}

// How a dough is shaped before it is cooked.
Dough_Shape :: enum {
	Loaf, // no shaping
	Flat,
	Wrapped, // round a filling
	Layered, // with a filling
	Strips,
	Lumps, // small lumps
}

Dish_Kind :: enum {
	Bread,
	Pie, // bread with pieces, or a flat dough with things on top
	Flatbread,
	Pasty, // a dough wrapped round a filling, baked
	Layered_Bake,
	Rolls,
	Cake,
	Muffins, // cake with pieces
	Pancake,
	Custard,
	Omelette,
	Porridge,
	Crackers,
	Baked, // pieces or a salad of firm vegetables, baked
	Grilled, // or grilled
	Soggy_Mess, // a salad of leaves, heated dry
	Mush, // mush, heated, is still mush
	Boiled, // pieces or vegetables, boiled
	Boiled_Lump, // a loaf of dough, boiled
	Dumplings,
	Noodles,
	Small_Dumplings,
	Boiled_Egg,
	Hot_Drink,
	Soup,
	Charcoal, // burnt through: cannot be eaten
	Brick, // a dough or a slop dried right out: cannot be eaten
	Boiled_Away, // a drink in the oven: nothing left
	Ran_Through, // on the fire: through the grill
	// Eaten as it stands, not heated.
	Salad,
	Drink,
	Raw, // anything else, raw
	Pickles,
	Wine,
	Vinegar,
}

Heating :: enum {
	Bake, // the oven
	Grill, // the fire, or his campfire
	Boil, // a pot of water on the fire
}

// The fire's three heights for the spit (SPIT_TEMP).
Spit :: enum {
	High,
	Middle,
	Low,
}

// What standing in a crock made of it.
Crock :: enum {
	Nothing,
	Pickles, // soured, in salt
	Wine, // its sugar turned to alcohol
	Vinegar, // its alcohol turned to acid
	Rotten, // spoiled before it soured
}

Taste :: enum {
	Sweet,
	Salty,
	Fatty,
	Sour,
	Bitter,
	Hot,
}

Taste_Line :: struct {
	best, gain, most, loss: f32,
}

// What went wrong with a dish, by the worst of which he says so.
Flaw :: enum {
	Lumpy,
	Tough,
	Raw_Middle,
	Burnt_Crust,
	Curdled,
	Dry,
	Soggy, // leaves heated dry
	Falls_Apart, // boiled far too long
	Hard_To_Digest, // eaten raw, and it wants cooking
}

Texture :: enum {
	Runny,
	Soft,
	Firm,
	Hard,
	Brittle,
}

// The three settings he chooses.
Setting :: enum {
	Mixing,
	Cooking,
	Temperature,
}

Bowl_Part :: struct {
	food:   Mixable,
	amount: f32, // in the food's unit
}

// What is done to the things before and while they are mixed.
Prep :: struct {
	minutes:    f32, // mixed for
	washed:     bool, // washed first
	pressed:    bool, // fruit and vegetables pressed to juice
	kept_hours: f32, // kept whole this long before they went in (an egg in its shell),
	kept_temp:  f32, // at this temperature
}

// Why a bowl will not mix.
Bowl_Refusal :: enum {
	None,
	Empty,
	No_Amount, // a part of nothing, or less
	Not_Whole, // part of an egg
	Too_Many_Kinds, // more than BOWL_KINDS
	Too_Much, // more than BOWL_MOST_G
	Twice, // the same food in two parts
}

// Why a mix will not take a shape.
Shape_Refusal :: enum {
	None,
	Not_Dough, // only a dough is shaped
	Needs_Filling, // wrapped and layered need one
	No_Filling_Here, // a loaf, strips and lumps take none
}

Mix :: struct {
	parts:        [BOWL_KINDS]Bowl_Part, // what went in
	n:            int,
	prep:         Prep,
	foods:        bit_set[Mixable], // in it, the filling's too
	grams:        f32,
	matter:       Grams,
	filling_g:    f32, // of it in pieces
	veg_g:        f32, // vegetables and fruit (whole, not pressed)
	leafy_g:      f32, // leafy vegetables
	hard_g:       f32, // what wants cooking
	flour:        f32, // starch from flour (not in pieces, not vegetables), share of the weight
	free_starch:  f32, // starch free in the mix: flour's, and what is mashed in, share of the weight
	free_liquid:  f32, // share of the weight
	consistency:  Consistency,
	kind:         Mix_Kind,
	setting:      f32, // protein that sets, share of the weight
	bitter:       f32, // per gram
	heat:         f32, // chili per kilogram
	microbes:     f32, // per gram, a power of ten
	spoiled:      bool, // for good: cooking does not save it
	kcal:         f32,
	shares:       Composition, // of the calories
	minutes:      f32, // mixed for
	best_minutes: f32,
	mix_ok:       f32, // 0 to 1: how right the mixing is
	lumpy, tough: bool,
	shape:        Dough_Shape,
	filled:       bool, // shaped with a filling
	crock:        Crock, // what standing made of it
	gas_lost:     f32, // grams that went off as gas standing (or came from the air, less than nothing)
}

Dish :: struct {
	kind:         Dish_Kind,
	lost:         bool, // nothing came out
	inedible:     bool, // charcoal or a brick
	how:          Heating,
	heated:       bool, // not eaten as it stands
	temperature:  f32,
	minutes:      f32,
	inside:       f32, // the middle: done at 1
	outside:      f32, // golden at 1, burnt at BURNT_CRUST
	dried:        f32, // the share of its water it lost
	flaws:        bit_set[Flaw],
	water_lost:   f32, // grams driven off
	water_gained: f32, // grams taken up in the pot
	alcohol_lost: f32, // grams driven off
	poured_off:   f32, // grams of liquid that ran away (a soup heated dry)
	grams:        f32, // what is left: the weight
	matter:       Grams,
	kcal:         f32,
	shares:       Composition,
	heat:         f32, // chili per kilogram, carried through
	// The effects.
	microbes:     f32, // safety: a power of ten per gram
	unsafe:       bool, // a tummy ache
	spoiled:      bool, // he will not eat it
	hard:         bool, // wants cooking, and is not cooked: a tummy ache
	taste:        f32, // -1 to 1
	texture:      Texture,
	consistency:  f32, // 0 to 1: how right its texture is
	keeping:      f32, // 0 to 1: how fast microorganisms grow in it
	energy:       f32, // 0 to 1: how much of the cooking bonus it got
	hardness:     f32, // 0 to 1
	wood:         f32, // logs it burned
}

// ---- What a food is made of. ----

unit_grams :: proc(food: Mixable) -> f32 {
	switch MIXABLE[food].unit {
	case .Gram, .Millilitre:
		return 1
	case .Egg:
		return ITEM_KG[.Egg] * 1000
	case .Pinch:
		return PINCH_G
	}
	return 1
}

part_grams :: proc(part: Bowl_Part) -> f32 {
	return part.amount * unit_grams(part.food)
}

// Whether a food has calories and shares of its own, rather than those of
// the thing in the sack.
own_figures :: proc(food: Mixable) -> bool {
	f := MIXABLE[food]
	return !f.in_sack || f.kcal_100g > 0
}

food_kcal_per_g :: proc(food: Mixable) -> f32 {
	f := MIXABLE[food]
	if own_figures(food) {
		return f.kcal_100g / 100
	}
	return item_kcal(f.item) / (ITEM_KG[f.item] * 1000 * (1 - f.waste))
}

food_shares :: proc(food: Mixable) -> Composition {
	return own_figures(food) ? MIXABLE[food].shares : composition(MIXABLE[food].item)
}

// What this many grams of a food are made of: each part of its calories at
// that part's calories to the gram, its water and acid, and the rest. Where
// the figures come to more than it weighs, the water gives way.
food_matter :: proc(food: Mixable, grams: f32) -> (m: Grams) {
	f := MIXABLE[food]
	kcal := food_kcal_per_g(food) * grams
	shares := food_shares(food)
	part :: proc(kcal: f32, shares: Composition, n: Nutrient) -> f32 {
		if NUTRIENT_KCAL[n] <= 0 {
			return 0
		}
		return kcal * shares[n] / 100 / NUTRIENT_KCAL[n]
	}
	carbs := part(kcal, shares, .Carbs)
	m[.Sugar] = carbs * f.sugar
	m[.Starch] = carbs - m[.Sugar]
	m[.Fat] = part(kcal, shares, .Fat)
	m[.Protein] = part(kcal, shares, .Protein)
	m[.Fibre] = part(kcal, shares, .Fibre)
	m[.Salt] = part(kcal, shares, .Electrolytes)
	m[.Acid] = f.acid * grams
	m[.Water] = f.water * grams
	rest := grams
	for v in m {
		rest -= v
	}
	if rest < 0 {
		m[.Water] = max(m[.Water] + rest, 0)
	} else {
		m[.Other] = rest
	}
	return
}

// How much more a food's figures come to than it weighs, as a share of its
// weight (0 if they fit).
food_overfull :: proc(food: Mixable) -> f32 {
	f := MIXABLE[food]
	m := food_matter(food, 100)
	dry: f32
	for v, k in m {
		if k != .Water && k != .Other {
			dry += v
		}
	}
	return max(dry + f.water * 100 - 100, 0) / 100
}

is_vegetable :: proc(food: Mixable) -> bool {
	return card(MIXABLE[food].marks & {.Leafy, .Firm, .Fruit}) > 0
}

// The microorganisms on a food as it goes in the bowl: washed, and kept
// whole so long.
food_microbes :: proc(food: Mixable, prep: Prep) -> f32 {
	f := MIXABLE[food]
	count := f.microbes
	if prep.washed && .Ground in f.marks {
		count = max(count - WASH_OFF, 0)
	}
	if prep.kept_hours > 0 {
		keeps := keeping(food_matter(food, 100), 100)
		if .Shell in f.marks {
			keeps *= SHELL_KEEPS
		}
		count = microbes_grown(count, prep.kept_temp, prep.kept_hours, keeps)
	}
	return count
}

// ---- Mixing. ----

bowl_refusal :: proc(parts: []Bowl_Part) -> Bowl_Refusal {
	if len(parts) == 0 {
		return .Empty
	}
	if len(parts) > BOWL_KINDS {
		return .Too_Many_Kinds
	}
	grams: f32
	for part, i in parts {
		if part.amount <= 0 {
			return .No_Amount
		}
		unit := MIXABLE[part.food].unit
		if unit == .Egg && part.amount != math.floor(part.amount) {
			return .Not_Whole
		}
		for other in parts[:i] {
			if other.food == part.food {
				return .Twice
			}
		}
		grams += part_grams(part)
	}
	if grams > BOWL_MOST_G {
		return .Too_Much
	}
	return .None
}

// How a food is in this bowl.
In_Bowl :: enum {
	Free, // all through it
	Pieces, // in pieces: FILLING_FREE of its water and fat free
	Mashed, // mashed in: its starch free, MASH_FREE of its water and fat
}

// What a bowl of these makes, prepared so. The order of the parts makes no
// difference.
mix_bowl :: proc(parts: []Bowl_Part, prep: Prep) -> (m: Mix, refused: Bowl_Refusal) {
	refused = bowl_refusal(parts)
	if refused != .None {
		return
	}
	m.n = len(parts)
	m.prep = prep
	// Flour first: whether there is any decides what mashes.
	total, flour: f32
	for part in parts {
		g := part_grams(part)
		total += g
		marks := MIXABLE[part.food].marks
		if card(marks & {.Pieces, .Mashes}) == 0 && !is_vegetable(part.food) {
			flour += food_matter(part.food, g)[.Starch]
		}
	}
	with_flour := flour / total >= FLOUR_LEAST
	free, set, count: f32
	for part, i in parts {
		m.parts[i] = part
		f := MIXABLE[part.food]
		g := part_grams(part)
		matter := food_matter(part.food, g)
		m.foods += {part.food}
		m.grams += g
		for v, k in matter {
			m.matter[k] += v
		}
		how := In_Bowl.Free
		switch {
		case prep.pressed && is_vegetable(part.food):
		case .Mashes in f.marks && with_flour:
			how = .Mashed
		case .Pieces in f.marks || .Mashes in f.marks:
			how = .Pieces
		}
		held: f32 = 1 // the share of it free in the mix
		switch how {
		case .Free:
			if !is_vegetable(part.food) || prep.pressed {
				m.free_starch += matter[.Starch]
			}
		case .Pieces:
			held = FILLING_FREE
			m.filling_g += g
		case .Mashed:
			held = MASH_FREE
			m.free_starch += matter[.Starch]
		}
		if is_vegetable(part.food) && !prep.pressed {
			m.veg_g += g
		}
		if .Leafy in f.marks {
			m.leafy_g += g
		}
		if .Wants_Cooking in f.marks {
			m.hard_g += g
		}
		free += held * (matter[.Water] + FAT_LIQUID * matter[.Fat])
		set += held * f.setting * matter[.Protein]
		m.bitter += f.bitter * g
		m.heat += f.heat * g
		microbes := food_microbes(part.food, prep)
		m.spoiled ||= microbes >= SPOILED_MICROBES
		count += math.pow(10, microbes) * g
		kcal := food_kcal_per_g(part.food) * g
		m.kcal += kcal
		m.shares += food_shares(part.food) * kcal
	}
	if m.kcal > 0 {
		m.shares /= m.kcal
	}
	m.flour = flour / m.grams
	m.free_liquid = free / m.grams
	m.free_starch /= m.grams
	m.setting = set / m.grams
	m.bitter /= m.grams
	m.heat = m.heat / m.grams * 1000
	m.microbes = math.log10(count / m.grams)
	switch {
	case m.free_liquid < CRUMBLY_BELOW:
		m.consistency = .Crumbly
	case m.free_liquid < KNEADABLE_BELOW:
		m.consistency = .Kneadable
	case m.free_liquid < POURABLE_BELOW:
		m.consistency = .Pourable
	case:
		m.consistency = .Runny
	}
	m.kind = mix_kind(m.consistency, with_flour, m.veg_g / m.grams, m.filling_g / m.grams, m.setting)
	m.best_minutes = best_mix_minutes(m)
	m.minutes = prep.minutes
	// One thing alone needs no mixing.
	if m.n == 1 {
		m.mix_ok = 1
		return
	}
	mixed := prep.minutes / m.best_minutes
	m.lumpy = mixed < MIX_RIGHT_LOW
	m.tough = m.kind == .Batter && mixed > TOUGH_AT
	if m.kind == .Batter {
		m.mix_ok = ramp(mixed, MIX_ZERO_LOW, MIX_RIGHT_LOW, TOUGH_AT, TOUGH_ZERO)
	} else {
		m.mix_ok = ramp(mixed, MIX_ZERO_LOW, MIX_RIGHT_LOW, math.F32_MAX, math.F32_MAX)
	}
	return
}

// The kind of mix: a salad if it is mostly vegetables and fruit, without
// flour; else by its consistency, whether there is flour, pieces, and how
// much of it sets (the tables in wd1b, section 4, and wd1c, section 3).
mix_kind :: proc(consistency: Consistency, flour: bool, veg, pieces, setting: f32) -> Mix_Kind {
	if veg >= SALAD_LEAST && !flour {
		return .Salad
	}
	has_pieces := pieces >= PIECES_LEAST
	switch consistency {
	case .Crumbly, .Kneadable:
		if flour {
			return consistency == .Crumbly ? .Crumbs : .Dough
		}
		return has_pieces ? .Pieces : .Mush
	case .Pourable:
		if flour {
			return setting >= BATTER_SET ? .Batter : .Slop
		}
		return setting >= EGG_SET ? .Egg_Mix : (has_pieces ? .Soup : .Mush)
	case .Runny:
		if flour {
			return .Slop
		}
		return setting >= EGG_SET ? .Egg_Mix : (has_pieces ? .Soup : .Drink)
	}
	return .Mush
}

// 1 between right_low and right_high, falling to 0 at zero_low and zero_high.
ramp :: proc(x, zero_low, right_low, right_high, zero_high: f32) -> f32 {
	if x < right_low {
		return clamp((x - zero_low) / (right_low - zero_low), 0, 1)
	}
	if x > right_high {
		return clamp((zero_high - x) / (zero_high - right_high), 0, 1)
	}
	return 1
}

// The best mixing time, minutes: long for a stiff flour and water dough,
// short for a rich batter, shortest for a drink.
best_mix_minutes :: proc(m: Mix) -> f32 {
	rich := (m.matter[.Fat] + m.matter[.Sugar]) / m.grams
	stiff := math.pow(max(1 - m.free_liquid, 0), MIX_STIFFNESS)
	return min(MIX_LEAST + MIX_DEVELOP * m.free_starch * stiff * max(0, 1 - MIX_RICH * rich) + MIX_PER_SET * m.setting, MIX_MOST)
}

// ---- Shaping. ----

shape_refusal :: proc(m: Mix, shape: Dough_Shape, filled: bool) -> Shape_Refusal {
	if shape == .Loaf && !filled {
		return .None
	}
	if m.kind != .Dough {
		return .Not_Dough
	}
	switch shape {
	case .Wrapped, .Layered:
		if !filled {return .Needs_Filling}
	case .Loaf, .Strips, .Lumps:
		if filled {return .No_Filling_Here}
	case .Flat:
	}
	return .None
}

// A dough shaped, wrapped round or layered with (or, flat, topped with) a
// filling: one thing to cook, the filling in pieces in it.
shape_mix :: proc(dough: Mix, shape: Dough_Shape, filling: ^Mix = nil) -> (m: Mix, refused: Shape_Refusal) {
	refused = shape_refusal(dough, shape, filling != nil)
	if refused != .None {
		return
	}
	m = dough
	m.shape = shape
	if filling == nil {
		return
	}
	f := filling^
	m.filled = true
	grams := m.grams + f.grams
	m.foods += f.foods
	m.matter += f.matter
	m.filling_g += f.grams
	m.veg_g += f.veg_g
	m.leafy_g += f.leafy_g
	m.hard_g += f.hard_g
	m.bitter = (m.bitter * m.grams + f.bitter * f.grams) / grams
	m.heat = (m.heat * m.grams + f.heat * f.grams) / grams
	m.microbes = math.log10((math.pow(10, m.microbes) * m.grams + math.pow(10, f.microbes) * f.grams) / grams)
	m.spoiled ||= f.spoiled
	m.shares = (m.shares * m.kcal + f.shares * f.kcal) / max(m.kcal + f.kcal, 1e-6)
	m.kcal += f.kcal
	m.grams = grams
	return
}

// ---- Heating. ----

// The best temperature: hot for a bread dough, gentle for an egg mix, lower
// the sweeter. In a pot, the boil.
best_temperature :: proc(m: Mix) -> f32 {
	t := TEMP_HOTTEST - TEMP_PER_SUGAR * m.matter[.Sugar] / m.grams - TEMP_PER_SET * m.setting
	return clamp(t, TEMP_LEAST, TEMP_HOTTEST)
}

// Degrees either side of the best that count as right: fat forgives.
temperature_right :: proc(m: Mix) -> f32 {
	return TEMP_RIGHT + TEMP_FAT_FORGIVES * m.matter[.Fat] / m.grams
}

// The spit height nearest the best temperature.
best_spit :: proc(m: Mix) -> (best: Spit) {
	want := best_temperature(m)
	for spit in Spit {
		if abs(SPIT_TEMP[spit] - want) < abs(SPIT_TEMP[best] - want) {
			best = spit
		}
	}
	return
}

// The best cooking time at the best temperature: longer for more of it, and
// for more water to drive off; shorter for a thin shape; on the fire it is
// cooked thin. In a pot: more of it takes longer, a liquid less.
base_minutes :: proc(m: Mix, how: Heating) -> f32 {
	kg := math.pow(m.grams / 1000, 2.0 / 3)
	if how == .Boil {
		t := BOIL_PER_KG * kg * SHAPE_TIME[m.shape]
		return m.kind == .Drink || m.kind == .Soup ? t * BOIL_LIQUID : t
	}
	t := TIME_PER_KG * kg * (1 + TIME_PER_WATER * m.matter[.Water] / m.grams) * SHAPE_TIME[m.shape]
	return how == .Grill ? t * FIRE_TIME : t
}

// The best cooking time at this temperature: when the middle is done.
best_minutes_at :: proc(m: Mix, how: Heating, temperature: f32) -> f32 {
	if how == .Boil {
		return base_minutes(m, how)
	}
	best := best_temperature(m)
	if temperature <= ROOM_TEMP + 1 {
		return math.F32_MAX
	}
	return base_minutes(m, how) * math.pow((best - ROOM_TEMP) / (temperature - ROOM_TEMP), INSIDE_HEAT_POWER)
}

// The best settings for heating a mix here: a temperature (on the fire, the
// best spit's; in a pot, the boil) and the time the middle is done at it.
best_settings :: proc(m: Mix, how: Heating) -> (temperature, minutes: f32) {
	if m.kind == .Soup && how != .Boil {
		if solid, ok := soup_pieces(m); ok {
			return best_settings(solid, how)
		}
	}
	switch how {
	case .Bake:
		temperature = best_temperature(m)
	case .Grill:
		temperature = SPIT_TEMP[best_spit(m)]
	case .Boil:
		temperature = BOIL
	}
	return temperature, best_minutes_at(m, how, temperature)
}

// The middle's temperature after so many minutes: warming towards the heat
// around it (never above BOIL while wet), reaching CORE_DONE when done.
core_temperature :: proc(temperature, done_minutes, minutes: f32) -> f32 {
	top := min(temperature, BOIL)
	if top <= ROOM_TEMP {
		return ROOM_TEMP
	}
	tau := done_minutes
	if top > CORE_DONE + 0.5 {
		tau = done_minutes / math.ln((top - ROOM_TEMP) / (top - CORE_DONE))
	}
	return top - (top - ROOM_TEMP) * math.exp(-minutes / tau)
}

// What heating a mix makes. bonus is what the station's cooking bonus is
// for him (see cook_bonus); the dish gets as much of it as the mixing and
// the cooking were right. In a pot the temperature is the boil, whatever is
// asked.
cook :: proc(m: Mix, how: Heating, temperature, minutes: f32, bonus: f32) -> (d: Dish) {
	temperature := temperature
	if how == .Boil {
		temperature = BOIL
	}
	d.how = how
	d.heated = true
	d.temperature = temperature
	d.minutes = minutes
	d.wood = wood_logs(temperature, minutes)
	d.spoiled = m.spoiled
	if how != .Boil {
		switch m.kind {
		case .Drink:
			d.kind = how == .Bake ? .Boiled_Away : .Ran_Through
			d.lost = true
			return
		case .Soup:
			return cook_soup_dry(m, how, temperature, minutes, bonus)
		case .Crumbs, .Dough, .Batter, .Slop, .Egg_Mix, .Salad, .Pieces, .Mush:
		}
	}
	best := best_temperature(m)
	base := base_minutes(m, how)
	done := best_minutes_at(m, how, temperature)
	d.inside = minutes / done
	top := min(temperature, BOIL)
	if top <= CORE_DONE + 0.5 {
		// Never hot enough for the middle to be done.
		d.inside = min(d.inside, 0.99 * (core_temperature(temperature, done, minutes) - ROOM_TEMP) / (CORE_DONE - ROOM_TEMP))
	}
	liquid := m.kind == .Drink || m.kind == .Soup
	if how == .Boil {
		// Nothing burns in water. Starch takes it up; a liquid boils down.
		if liquid {
			d.water_lost = m.matter[.Water] * min(BOIL_OFF * minutes, BOIL_OFF_MOST)
		} else {
			d.water_gained = BOIL_ABSORB * m.matter[.Starch] * min(d.inside, 1)
		}
		d.dried = d.water_lost / max(m.matter[.Water], 1e-6)
	} else {
		d.outside = minutes / base * math.pow(2, (temperature - best) / BROWN_DOUBLING)
		warmth := max(temperature - ROOM_TEMP, 0) / (best - ROOM_TEMP)
		d.dried = 1 - math.exp(math.ln(1 - DRY_AT_BEST) * minutes / base * warmth)
		d.water_lost = m.matter[.Water] * d.dried
	}

	d.kind = dish_kind(m, how)
	if how != .Boil {
		switch {
		case d.outside >= CHAR_AT[how] && d.inside >= 1:
			d.kind = .Charcoal
		case (m.kind == .Dough || m.kind == .Slop) && d.dried >= BRICK_DRY:
			d.kind = .Brick
		}
	}
	d.inedible = d.kind == .Charcoal || d.kind == .Brick

	if m.lumpy {d.flaws += {.Lumpy}}
	if m.tough {d.flaws += {.Tough}}
	if d.inside < TIME_RIGHT[0] {d.flaws += {.Raw_Middle}}
	if d.outside >= BURNT_CRUST {d.flaws += {.Burnt_Crust}}
	if m.kind == .Egg_Mix && how != .Boil && temperature > best + CURDLE_OVER {d.flaws += {.Curdled}}
	if how != .Boil && d.dried > DRY_RIGHT {d.flaws += {.Dry}}
	if how == .Boil && !liquid && d.inside > BOIL_APART {d.flaws += {.Falls_Apart}}
	leafy := m.leafy_g / max(m.veg_g, 1e-6)
	if how != .Boil && m.leafy_g > 0 && (m.kind == .Salad || m.kind == .Pieces) {d.flaws += {.Soggy}}
	d.hard = m.hard_g / m.grams >= HARD_LEAST && d.inside < TIME_RIGHT[0]
	if d.hard {d.flaws += {.Hard_To_Digest}}

	// What is left: all of it but the water and alcohol driven off, and the
	// water taken up.
	d.matter = m.matter
	d.matter[.Water] += d.water_gained - d.water_lost
	d.alcohol_lost = m.matter[.Alcohol] * (1 - math.exp(-ALCOHOL_OFF * minutes))
	d.matter[.Alcohol] -= d.alcohol_lost
	d.grams = m.grams + d.water_gained - d.water_lost - d.alcohol_lost
	d.shares = m.shares
	d.heat = m.heat * m.grams / d.grams

	// Safety: what the middle's heat left alive. Spoiled stays spoiled.
	d.microbes = max(m.microbes - core_kill(temperature, done, minutes), 0)
	d.unsafe = !d.inedible && d.microbes > UNSAFE_MICROBES

	// Energy: as much of the bonus as the mixing and the cooking were right.
	time_ok := ramp(minutes / done, TIME_ZERO[0], TIME_RIGHT[0], TIME_RIGHT[1], TIME_ZERO[1])
	temp_ok: f32 = 1
	if how != .Boil {
		aim := how == .Bake ? best : SPIT_TEMP[best_spit(m)]
		off := abs(temperature - aim)
		right := temperature_right(m)
		temp_ok = ramp(-off, -(right + TEMP_ZERO), -right, 0, 1)
	}
	d.energy = (m.mix_ok + min(time_ok, temp_ok)) / 2
	if !d.inedible {
		d.kcal = m.kcal * (1 + (bonus - 1) * d.energy)
		d.kcal -= ALCOHOL_KCAL * d.alcohol_lost
	}
	dish_effects(&d, m, leafy)
	return
}

// A soup in the oven or on the fire: its liquid goes, and its pieces are
// baked or grilled, at the best for them.
soup_pieces :: proc(m: Mix) -> (solid: Mix, ok: bool) {
	pieces: [BOWL_KINDS]Bowl_Part
	n := 0
	for i in 0 ..< m.n {
		part := m.parts[i]
		if .Pieces in MIXABLE[part.food].marks || .Mashes in MIXABLE[part.food].marks {
			pieces[n] = part
			n += 1
		}
	}
	refused: Bowl_Refusal
	solid, refused = mix_bowl(pieces[:n], m.prep)
	return solid, refused == .None
}

cook_soup_dry :: proc(m: Mix, how: Heating, temperature, minutes, bonus: f32) -> (d: Dish) {
	solid, ok := soup_pieces(m)
	if !ok {
		d.kind = how == .Bake ? .Boiled_Away : .Ran_Through
		d.lost = true
		d.how = how
		d.heated = true
		return
	}
	d = cook(solid, how, temperature, minutes, bonus)
	d.poured_off = m.grams - solid.grams
	return
}

// Taste, texture, keeping and hardness, from what the dish is made of.
dish_effects :: proc(d: ^Dish, m: Mix, leafy: f32) {
	d.taste = dish_taste(d^, m, leafy)
	// What is in pieces holds most of its water.
	water := d.matter[.Water] / d.grams * (1 - (1 - TEXTURE_PIECES) * min(m.filling_g / m.grams, 1))
	set := m.setting * m.grams / d.grams >= SET_FIRM && (!d.heated || d.inside >= TIME_RIGHT[0])
	d.texture = .Brittle
	for texture in Texture {
		if water > TEXTURE_WATER[texture] && !(texture == .Runny && set && d.heated) {
			d.texture = texture
			break
		}
	}
	d.consistency = 1
	for flaw in d.flaws {
		d.consistency -= flaw == .Soggy ? CONSISTENCY_FLAWS[flaw] * leafy : CONSISTENCY_FLAWS[flaw]
	}
	d.consistency = clamp(d.consistency, 0, 1)
	d.keeping = keeping(d.matter, d.grams)
	d.hardness = clamp((HARD_WET - d.matter[.Water] / d.grams) / (HARD_WET - HARD_DRY), 0, 1)
	d.spoiled ||= d.microbes >= SPOILED_MICROBES
}

// The dish a mix makes, cooked right.
dish_kind :: proc(m: Mix, how: Heating) -> Dish_Kind {
	pieces := m.filling_g / m.grams >= PIECES_LEAST
	switch m.kind {
	case .Dough:
		switch how {
		case .Bake, .Grill:
			switch m.shape {
			case .Loaf:
				return how == .Grill ? .Flatbread : (pieces ? .Pie : .Bread)
			case .Flat:
				return m.filled ? .Pie : .Flatbread
			case .Wrapped:
				return .Pasty
			case .Layered:
				return .Layered_Bake
			case .Strips:
				return .Crackers
			case .Lumps:
				return .Rolls
			}
		case .Boil:
			return BOILED_SHAPE[m.shape]
		}
	case .Batter:
		switch how {
		case .Bake:
			return pieces ? .Muffins : .Cake
		case .Grill:
			return .Pancake
		case .Boil:
			return .Small_Dumplings
		}
	case .Egg_Mix:
		kinds := [Heating]Dish_Kind{.Bake = .Custard, .Grill = .Omelette, .Boil = .Boiled_Egg}
		return kinds[how]
	case .Slop:
		return .Porridge
	case .Crumbs:
		return how == .Boil ? .Porridge : .Crackers
	case .Salad, .Pieces:
		if how == .Boil {
			return .Boiled
		}
		if m.kind == .Salad && m.leafy_g / max(m.veg_g, 1e-6) >= SOGGY_LEAFY {
			return .Soggy_Mess
		}
		return how == .Bake ? .Baked : .Grilled
	case .Mush:
		return .Mush
	case .Drink:
		kinds := [Heating]Dish_Kind{.Bake = .Boiled_Away, .Grill = .Ran_Through, .Boil = .Hot_Drink}
		return kinds[how]
	case .Soup:
		return .Soup
	}
	return .Mush
}

// What a dough boiled is, by its shape.
BOILED_SHAPE := [Dough_Shape]Dish_Kind {
	.Loaf    = .Boiled_Lump,
	.Flat    = .Noodles,
	.Wrapped = .Dumplings,
	.Layered = .Boiled_Lump,
	.Strips  = .Noodles,
	.Lumps   = .Small_Dumplings,
}

// A mix eaten as it stands: a salad, a drink, pickles, wine; anything else
// raw.
as_it_stands :: proc(m: Mix) -> (d: Dish) {
	switch m.crock {
	case .Pickles:
		d.kind = .Pickles
	case .Wine:
		d.kind = .Wine
	case .Vinegar:
		d.kind = .Vinegar
	case .Nothing, .Rotten:
		#partial switch m.kind {
		case .Salad:
			d.kind = .Salad
		case .Drink:
			d.kind = .Drink
		case:
			d.kind = .Raw
		}
	}
	d.spoiled = m.spoiled
	d.matter = m.matter
	d.grams = m.grams
	d.shares = m.shares
	d.kcal = m.kcal
	d.heat = m.heat
	d.microbes = m.microbes
	d.unsafe = d.microbes > UNSAFE_MICROBES
	d.hard = m.hard_g / m.grams >= HARD_LEAST
	if m.lumpy {d.flaws += {.Lumpy}}
	if d.hard {d.flaws += {.Hard_To_Digest}}
	d.energy = m.mix_ok / 2
	dish_effects(&d, m, 0)
	return
}

// How good it tastes, -1 to 1: the balance of sweet, salty, fatty, sour,
// bitter and hot, less its flaws. Burning adds to the bitter.
dish_taste :: proc(d: Dish, m: Mix, leafy: f32) -> f32 {
	amount: [Taste]f32 = {
		.Sweet  = d.matter[.Sugar] / d.grams,
		.Salty  = d.matter[.Salt] / d.grams,
		.Fatty  = d.matter[.Fat] / d.grams,
		.Sour   = d.matter[.Acid] / d.grams,
		.Bitter = m.bitter * m.grams / d.grams + BURN_BITTER * max(d.outside - 1, 0),
		.Hot    = d.heat,
	}
	taste := TASTE_PLAIN
	for line, t in TASTES {
		taste += line.gain * min(amount[t] / line.best, 1)
		taste -= line.loss * max(amount[t] - line.most, 0)
	}
	for flaw in d.flaws {
		taste -= flaw == .Soggy ? TASTE_FLAWS[flaw] * leafy : TASTE_FLAWS[flaw]
	}
	return clamp(taste, -1, 1)
}

// Whether a dish is good: eaten, it does him no harm, nothing went wrong
// with it, and it tastes of something.
dish_good :: proc(d: Dish) -> bool {
	return !d.lost && !d.inedible && !d.spoiled && !d.unsafe && !d.hard && d.flaws == {} && d.taste > 0
}

// The wood a bake, a grilling or a boiling burns.
wood_logs :: proc(temperature, minutes: f32) -> f32 {
	return WOOD_PER_HOUR * minutes / 60 * max(temperature - ROOM_TEMP, 0) / (WOOD_AT - ROOM_TEMP)
}

// A drink's alcohol by volume, as on a bottle: the alcohol's millilitres
// to the drink's, a gram of the drink taken as a millilitre.
alcohol_by_volume :: proc(m: Mix) -> f32 {
	return m.grams > 0 ? m.matter[.Alcohol] / ALCOHOL_DENSITY / m.grams : 0
}

// Real seconds the wait takes: for cooking, and for mixing.
cook_seconds :: proc(minutes: f32) -> f32 {
	return min(minutes * DIAL_MINUTE_SECONDS, COOK_WAIT_MOST)
}

mix_seconds :: proc(minutes: f32) -> f32 {
	return clamp(minutes * MIX_WAIT_PER_MINUTE, MIX_WAIT_LEAST, MIX_WAIT_MOST)
}

// ---- Leaving to stand, in a crock. ----

// So many days at a temperature, with air (an open crock) or without. Its
// microorganisms grow as anywhere, and as they do (if it is FERMENT_COLDEST
// or warmer): in salt (between
// SOUR_SALT_LEAST and SOUR_SALT_MOST of its water) its sugar turns to acid,
// which in the end stops them (pickles); a sweet drink without salt turns
// its sugar to alcohol (wine); and with air, alcohol turns to acid (vinegar).
// If they reach SPOILED_MICROBES first, it rots.
stand :: proc(m: Mix, days, temperature: f32, air: bool) -> (s: Mix) {
	s = m
	hours := days * DAY_HOURS
	steps := int(math.ceil(hours / STAND_STEP))
	dt := hours / f32(max(steps, 1))
	soured, turned: bool
	for _ in 0 ..< steps {
		rate := growth_rate(temperature) * dt
		water := s.matter[.Water]
		salt := share_of_water(s.matter[.Salt], water)
		switch {
		case temperature < FERMENT_COLDEST:
		case salt >= SOUR_SALT_LEAST && salt <= SOUR_SALT_MOST:
			used := s.matter[.Sugar] * min(SOUR_RATE * rate, 1)
			s.matter[.Sugar] -= used
			s.matter[.Acid] += ACID_PER_SUGAR * used
			s.matter[.Other] += (1 - ACID_PER_SUGAR) * used
			s.kcal += (ACID_KCAL * ACID_PER_SUGAR - NUTRIENT_KCAL[.Carbs]) * used
			soured ||= used > 0
		case salt < SOUR_SALT_LEAST && s.kind == .Drink && share_of_water(s.matter[.Alcohol], water) < ALCOHOL_YEAST_MOST:
			used := s.matter[.Sugar] * min(YEAST_RATE * rate, 1)
			s.matter[.Sugar] -= used
			s.matter[.Alcohol] += ALCOHOL_PER_SUGAR * used
			s.gas_lost += (1 - ALCOHOL_PER_SUGAR) * used
			s.kcal += (ALCOHOL_KCAL * ALCOHOL_PER_SUGAR - NUTRIENT_KCAL[.Carbs]) * used
		}
		if air && s.matter[.Alcohol] > 0 && temperature >= FERMENT_COLDEST {
			used := s.matter[.Alcohol] * min(VINEGAR_RATE * rate, 1)
			s.matter[.Alcohol] -= used
			s.matter[.Acid] += ACID_PER_ALCOHOL * used
			s.matter[.Water] += WATER_PER_ALCOHOL * used
			s.gas_lost -= (ACID_PER_ALCOHOL + WATER_PER_ALCOHOL - 1) * used // from the air
			s.kcal += (ACID_KCAL * ACID_PER_ALCOHOL - ALCOHOL_KCAL) * used
			turned ||= used > 0
		}
		s.microbes = microbes_grown(s.microbes, temperature, dt, keeping(s.matter, s.grams - s.gas_lost))
		s.spoiled ||= s.microbes >= SPOILED_MICROBES
	}
	s.grams -= s.gas_lost - m.gas_lost
	// The calories that moved: what was sugar is acid or alcohol now, both
	// counted with the carbs.
	if m.kcal > 0 && s.kcal > 0 {
		carbs := s.kcal - m.kcal * (1 - m.shares[Nutrient.Carbs] / 100)
		s.shares = m.shares * m.kcal / s.kcal
		s.shares[Nutrient.Carbs] = 100 * max(carbs, 0) / s.kcal
	}
	alcohol := s.matter[.Alcohol] / s.grams
	acid := s.matter[.Acid] / s.grams
	switch {
	case s.spoiled:
		s.crock = .Rotten
	case acid >= VINEGAR_ACID && alcohol < WINE_ALCOHOL && (turned || m.crock == .Vinegar):
		s.crock = .Vinegar
	case alcohol >= WINE_ALCOHOL:
		s.crock = .Wine
	case (soured || m.crock == .Pickles) && acid >= PICKLED_ACID:
		s.crock = .Pickles
	case:
		s.crock = m.crock
	}
	return
}

// What a part of it is to its water: how salt the brine is, how sweet the
// syrup, how sour, how strong.
share_of_water :: proc(grams, water: f32) -> f32 {
	return grams / max(grams + water, 1e-6)
}

// ---- Microorganisms, per gram, as a power of ten. ----

// How fast they grow at a temperature, powers of ten an hour: nothing at
// freezing or under, slower in the cold, fastest at GROW_BEST, nothing again
// at GROW_HOTTEST.
growth_rate :: proc(temperature: f32) -> f32 {
	switch {
	case temperature <= GROW_COLDEST || temperature >= GROW_HOTTEST:
		return 0
	case temperature <= GROW_BEST:
		x := (temperature - GROW_COLDEST) / (GROW_BEST - GROW_COLDEST)
		return GROW_FASTEST * math.pow(x, GROW_POWER)
	}
	return GROW_FASTEST * (GROW_HOTTEST - temperature) / (GROW_HOTTEST - GROW_BEST)
}

// How freely they grow in this, 0 to 1: the water left free to them, and
// salt, sugar, acid and alcohol in that water each slowing them, to nothing
// at their own strength.
keeping :: proc(matter: Grams, grams: f32) -> f32 {
	water := matter[.Water]
	wet := clamp((water / grams - GROW_DRY) / (GROW_WET - GROW_DRY), 0, 1)
	slows :: proc(part, water, stops: f32) -> f32 {
		return clamp(1 - share_of_water(part, water) / stops, 0, 1)
	}
	return wet * slows(matter[.Salt], water, SALT_STOPS) * slows(matter[.Sugar], water, SUGAR_STOPS) * slows(matter[.Acid], water, ACID_STOPS) * slows(matter[.Alcohol], water, ALCOHOL_STOPS)
}

mix_keeping :: proc(m: Mix) -> f32 {
	return keeping(m.matter, m.grams)
}

// The count after so many hours kept at a temperature.
microbes_grown :: proc(count, temperature, hours, keeping: f32) -> f32 {
	if count >= MICROBES_MOST {
		return count
	}
	return min(count + growth_rate(temperature) * keeping * hours, MICROBES_MOST)
}

// How many powers of ten heat kills in a minute.
kill_rate :: proc(temperature: f32) -> f32 {
	return KILL_AT_70 * math.pow(10, (temperature - 70) / KILL_Z)
}

// The count after so many minutes at a temperature, right through.
microbes_heated :: proc(count, temperature, minutes: f32) -> f32 {
	return max(count - kill_rate(temperature) * minutes, 0)
}

// What the middle's heat kills over a cooking, as it warms.
core_kill :: proc(temperature, done_minutes, minutes: f32) -> (killed: f32) {
	STEPS :: 80
	dt := minutes / STEPS
	for i in 0 ..< STEPS {
		killed += kill_rate(core_temperature(temperature, done_minutes, (f32(i) + 0.5) * dt)) * dt
	}
	return
}

// Hours until it is over a line, kept at a temperature (0 if it is already;
// the largest number there is if never).
hours_until :: proc(line, count, temperature, keeping: f32) -> f32 {
	if count > line {
		return 0
	}
	rate := growth_rate(temperature) * keeping
	if rate <= 0 {
		return math.F32_MAX
	}
	return (line - count) / rate
}

hours_until_unsafe :: proc(count, temperature, keeping: f32) -> f32 {
	return hours_until(UNSAFE_MICROBES, count, temperature, keeping)
}

// ---- What the editor shows. ----

// What makes a recipe the same recipe: the foods in it, its shape and how
// it is cooked, whatever the amounts.
recipe_key :: proc(m: Mix, how: Heating) -> u32 {
	h := u32(2166136261)
	for food in m.foods {
		h = (h ~ u32(food)) * 16777619
	}
	h = (h ~ (u32(m.shape) << 8) ~ (m.filled ? 0x5a00 : 0)) * 16777619
	return (h ~ u32(how) ~ 0xa5) * 16777619
}

// The interval the editor shows for a setting, at a skill from 0 to 1: wide
// for a beginner, narrowing to the best for a master, with the best at a
// place inside it that is the same for the same recipe and never the middle.
setting_interval :: proc(best: f32, setting: Setting, skill: f32, key: u32) -> (low, high: f32) {
	s := clamp(skill, 0, 1)
	width := best * (SKILL_WIDE[setting] + (SKILL_NARROW[setting] - SKILL_WIDE[setting]) * s)
	h := (key ~ (u32(setting) + 1) * 0x9e3779b9) * 2654435761
	h ~= h >> 15
	u := f32(h % 10000) / 10000
	first := 0.5 - SKILL_NOT_MIDDLE - SKILL_PLACE[0]
	second := SKILL_PLACE[1] - 0.5 - SKILL_NOT_MIDDLE
	x := u * (first + second)
	place := x < first ? SKILL_PLACE[0] + x : 0.5 + SKILL_NOT_MIDDLE + (x - first)
	low = best - place * width
	return low, low + width
}
