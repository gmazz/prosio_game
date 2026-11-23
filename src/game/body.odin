package game

import "core:math"

// Prosio is what he does. Besides his fat and what is in his stores (see
// diet.odin, where his weight is added up), he has nine traits: the muscle
// of his arms and of his legs, four skills of the body and three of the
// kitchen (which, being in his head, never fade). Each is a level that follows
// what he has been doing lately.
//
//   Doing the thing that trains a trait raises it, by less the higher it
//   already is. Left alone it fades, losing half in 18 minutes of play. So a
//   habit shows on him after a few minutes, and he cannot keep everything up
//   at once.
//
//   Muscle is built out of protein, kilogram for kilogram: training takes
//   it from the protein in him, and with little there it builds little.
//   When he lacks protein, or is starving, his muscles waste away below
//   their ordinary size. Muscle that wastes or fades simply goes, the way
//   burned fat goes: it is not something to live on. Muscle is also heavy,
//   and hungry: every kilogram of it
//   burns energy all the time (BASAL), carbs first and then fat, so a
//   muscular pig needs feeding more than a lean one.
//
// A trait's level is 0 when ordinary and 1 at the most it can be; a muscle
// can go below 0, down to -1, when it has wasted away.
Trait :: enum {
	Arms,
	Legs,
	Lungs,
	Hide,
	Gut,
	Hooves,
	// The skills of the kitchen: one for each place where food is made.
	// These are in his head, not his body, and do not fade (see is_mental).
	Baking, // at the oven
	Grilling, // at the cooking fire
	Dairy, // at the churn
}

TRAIT_NAME := [Trait]cstring {
	.Arms    = "ARMS",
	.Legs    = "LEGS",
	.Lungs   = "LUNGS",
	.Hide    = "HIDE",
	.Gut     = "GUT",
	.Hooves  = "HOOVES",
	.Baking   = "BAKING",
	.Grilling = "GRILLING",
	.Dairy    = "DAIRY",
}
// What trains each, and what it is good for.
TRAIT_GROWS := [Trait]cstring {
	.Arms    = "lifting, dragging, bashing, throwing (with protein)",
	.Legs    = "running, jumping, long walks (with protein)",
	.Lungs   = "sprinting",
	.Hide    = "taking pecks, butts and stings",
	.Gut     = "eating fibre",
	.Hooves  = "picking, fishing, milking",
	.Baking   = "baking at the oven",
	.Grilling = "cooking at the fire",
	.Dairy    = "churning",
}
TRAIT_GIVES := [Trait]cstring {
	.Arms    = "he lifts and throws more",
	.Legs    = "he is faster and jumps higher",
	.Lungs   = "sprints cost less, breath comes back sooner",
	.Hide    = "knocks hurt less",
	.Gut     = "he holds his wind, and lets it go with {Gas}",
	.Hooves  = "quicker picking, a longer reach",
	.Baking   = "richer bakes (+15% to +80%), sooner",
	.Grilling = "richer grills (+0% to +50%), sooner",
	.Dairy    = "more butter and cheese (+0% to +25%)",
}

is_muscle :: proc(t: Trait) -> bool {
	return t == .Arms || t == .Legs
}

// What he knows how to do stays with him: only what is in his body fades.
is_mental :: proc(t: Trait) -> bool {
	return t == .Baking || t == .Grilling || t == .Dairy
}

muscle_kg :: proc(t: Trait) -> f32 {
	kg := t == .Arms ? ARMS_KG : LEGS_KG
	level := g.prosio.trait[t]
	return level >= 0 ? lerp(kg[1], kg[2], level) : lerp(kg[1], kg[0], -level)
}

// How many kg a muscle gains or loses for a whole step of its level: more
// above the ordinary than below.
muscle_span :: proc(t: Trait) -> f32 {
	kg := t == .Arms ? ARMS_KG : LEGS_KG
	return g.prosio.trait[t] >= 0 ? kg[2] - kg[1] : kg[1] - kg[0]
}

// What he weighs with this much fat on him: everything else as it is.
weight_with :: proc(fat: f32) -> f32 {
	return body_kg() - g.prosio.fat + fat
}

// Sets his fat so that he weighs this.
set_weight :: proc(kg: f32) {
	p := &g.prosio
	p.fat = clamp(kg - weight_with(0), 1, FAT_MAX - 1)
	p.kg = weight_with(p.fat)
}

// How freely he can build muscle from the protein in him: nothing when he
// is close to lacking it, all he likes from about half full.
protein_to_spare :: proc() -> f32 {
	return clamp((g.prosio.need[.Protein] - NEED_LOW) / 30, 0, 1)
}

// He has done something that trains a trait.
train :: proc(t: Trait, work: f32) {
	p := &g.prosio
	gain := work * (1 - p.trait[t])
	if is_muscle(t) {
		// Muscle is built out of the protein in him, kilogram for kilogram:
		// little to spare, little muscle; none, none.
		supply := protein_to_spare() * (full_of(.Protein) ? BULK : 1)
		kg := min(gain * supply * muscle_span(t), store_kg(.Protein))
		store_add(.Protein, -kg)
		gain = kg / muscle_span(t)
	}
	p.trait[t] = min(p.trait[t] + gain, 1)
}

update_body :: proc(dt: f32) {
	p := &g.prosio
	hungry := starving()
	for t in Trait {
		level := p.trait[t]
		change: f32
		switch {
		case is_muscle(t) && (lacks(.Protein) || hungry):
			change = max(level - WASTE * dt, -1) - level
		case is_mental(t):
		case level > 0:
			change = -level * FADE * dt
		case level < 0:
			change = min(level + RECOVER * dt, 0) - level
		}
		if is_muscle(t) {
			// Muscle that goes simply goes; muscle that comes back is made of
			// protein.
			kg := change * muscle_span(t)
			if kg > 0 {
				// Only as fast as he has protein to spare, like any muscle he
				// builds: coming back must not leave him lacking it, which
				// would waste the same muscle again.
				kg = min(kg * protein_to_spare(), store_kg(.Protein))
				store_add(.Protein, -kg)
				change = kg / muscle_span(t)
			}
		}
		p.trait[t] = level + change
	}
	// His muscles keep burning, the more of them the more: carbs first.
	burn(BASAL * part_kg(.Muscle) * dt, .Muscle, true)
	p.fat = clamp(p.fat, 0, FAT_MAX)
	p.kg = body_kg()

	// Which way each is going, for the body panel: looked at every few seconds.
	p.trend_t -= dt
	if p.trend_t <= 0 {
		p.trend_t = 5
		for level, t in p.trait {
			p.trend[t] = level - p.trait_was[t]
			p.trait_was[t] = level
		}
		p.fat_trend = p.fat - p.fat_was
		p.fat_was = p.fat
	}
}

// What a muscle's level does to something: nothing when ordinary, up to
// strong at its most, down to weak when wasted away.
tone :: proc(t: Trait, weak, strong: f32) -> f32 {
	level := g.prosio.trait[t]
	return level >= 0 ? lerp(1, strong, level) : lerp(1, weak, -level)
}

// How strong his arms are: what he can lift, and how hard he throws.
strength :: proc() -> f32 {
	return tone(.Arms, NOODLE_ARMS, STRONG)
}

// The share of a peck, a butt or a sting that he feels: fat pads him, and a
// tough hide helps on top.
knock :: proc() -> f32 {
	return lerp(THIN_SKIN, PADDED, fatness()) * lerp(1, TOUGH_HIDE, g.prosio.trait[.Hide])
}

// How long picking something up takes him.
pick_time :: proc() -> f32 {
	return PICK_TIME * lerp(1, DEFT_PICK, g.prosio.trait[.Hooves]) * stiffness()
}

// How much further than usual he reaches for a fish or a leg.
deft_reach :: proc() -> f32 {
	return lerp(1, DEFT_REACH, g.prosio.trait[.Hooves])
}

// How far his wind reaches.
gas_reach :: proc() -> f32 {
	return GAS_REACH * lerp(1, GUT_REACH, g.prosio.trait[.Gut])
}

// What a station's cooking is worth with his skill, and how long it takes.
// How much richer what he makes here is: from the least, for a beginner,
// to the most, for a master (see COOK_RANGE).
cook_bonus :: proc(at: Station_Kind) -> f32 {
	return lerp(COOK_RANGE[at][0], COOK_RANGE[at][1], g.prosio.trait[STATION_SKILL[at]])
}

// What he is called at a station, by how good he has got there.
cook_title :: proc(at: Station_Kind) -> cstring {
	level := g.prosio.trait[STATION_SKILL[at]]
	rank := level < 0.25 ? 0 : (level < 0.5 ? 1 : (level < 0.85 ? 2 : 3))
	return COOK_TITLE[at][rank]
}

cook_time :: proc(at: Station_Kind) -> f32 {
	// (At the workbench it is deft hooves that make quick work.)
	return STATION_TIME[at] * lerp(1, COOK_QUICK, g.prosio.trait[STATION_SKILL[at]])
}

// The game was over; he comes round at home. See WAKE_FAT.
wake_up :: proc() {
	old := g.prosio
	reset_prosio()
	p := &g.prosio
	p.trait = old.trait
	for &level, t in p.trait {
		if is_muscle(t) {
			level = level > 0 ? level * (1 - WAKE_MUSCLE_LOSS) : 0
		}
	}
	p.trait_was = p.trait
	p.fat = clamp(old.fat, WAKE_FAT.x, WAKE_FAT.y)
	p.fat_was = p.fat
	p.kg = weight_with(p.fat)
	say("Where... where is my sack?", 2.4)
}

// The moment he goes down, what is kept is the pig who will wake up at home.
// So leaving the game while he lies there (by the menu, or by closing it)
// does not undo it.
save_fallen :: proc() {
	lying := g.prosio
	wake_up()
	save_game()
	g.prosio = lying
}

// What is kept between one sitting and the next: Prosio himself, what he
// carries, wears and knows, what he has seen of the meadow, and what he has
// built in it: his fences, his scarecrows, and the animals in his pens. The
// rest of the meadow starts afresh each time.
SAVE_VERSION :: u32(7)
MAX_PENNED :: 12 // penned animals kept

Fence_Saved :: struct {
	x, y, way: u8, // way: bit 0 which way it runs; bit 1 a gate; bit 2 an open gate
}

Penned_Saved :: struct {
	kind: Enemy_Kind,
	pos:  Vec2,
}

// A larder and what is in it.
Larder_Saved :: struct {
	used:  bool,
	pos:   Vec2,
	stock: [Item]int,
	kcal:  [Item]f32,
	fresh: [Item]f32,
}

Save :: struct {
	version:         u32,
	size:            u32,
	fat:             f32,
	trait:           [Trait]f32,
	need:            [Need]f32,
	sack:            [Item]int,
	sack_kcal:       [Item]f32,
	sack_sel:        Item,
	outfit:          Outfit,
	seen:            [MAP_W * MAP_H]bool,
	seen_region:     [Region_Kind]bool,
	knows:           [Item]bool,
	fence_count:     i32,
	fences:          [MAX_FENCES]Fence_Saved,
	scarecrow_count: i32,
	scarecrows:      [MAX_SCARECROWS]Vec2,
	penned_count:    i32,
	penned:          [MAX_PENNED]Penned_Saved,
	sack_fresh:      [Item]f32,
	larders:         [MAX_LARDERS]Larder_Saved,
	camp_up:         bool, // his campfire, if it is set up, and where
	camp_pos:        Vec2,
}

// Version 6 was the same from before the campfire, with one thing fewer in
// the sack (ITEMS_6 of them), and no campfire.
ITEMS_6 :: 33
Larder_Saved_6 :: struct {
	used:  bool,
	pos:   Vec2,
	stock: [ITEMS_6]int,
	kcal:  [ITEMS_6]f32,
	fresh: [ITEMS_6]f32,
}
Save_6 :: struct {
	version:         u32,
	size:            u32,
	fat:             f32,
	trait:           [Trait]f32,
	need:            [Need]f32,
	sack:            [ITEMS_6]int,
	sack_kcal:       [ITEMS_6]f32,
	sack_sel:        u8,
	outfit:          Outfit,
	seen:            [MAP_W * MAP_H]bool,
	seen_region:     [Region_Kind]bool,
	knows:           [ITEMS_6]bool,
	fence_count:     i32,
	fences:          [MAX_FENCES]Fence_Saved,
	scarecrow_count: i32,
	scarecrows:      [MAX_SCARECROWS]Vec2,
	penned_count:    i32,
	penned:          [MAX_PENNED]Penned_Saved,
	sack_fresh:      [ITEMS_6]f32,
	larders:         [MAX_LARDERS]Larder_Saved_6,
}

from_save_6 :: proc(old: ^Save_6, save: ^Save) {
	save^ = {
		version         = SAVE_VERSION,
		size            = size_of(Save),
		fat             = old.fat,
		trait           = old.trait,
		need            = old.need,
		sack_sel        = Item(min(int(old.sack_sel), ITEMS_6 - 1)),
		outfit          = old.outfit,
		seen            = old.seen,
		seen_region     = old.seen_region,
		fence_count     = old.fence_count,
		fences          = old.fences,
		scarecrow_count = old.scarecrow_count,
		scarecrows      = old.scarecrows,
		penned_count    = old.penned_count,
		penned          = old.penned,
	}
	for i in 0 ..< ITEMS_6 {
		save.sack[Item(i)] = old.sack[i]
		save.sack_kcal[Item(i)] = old.sack_kcal[i]
		save.sack_fresh[Item(i)] = old.sack_fresh[i]
		save.knows[Item(i)] = old.knows[i]
	}
	for r in RECIPES {
		if int(r.dish) >= ITEMS_6 {
			save.knows[r.dish] = true // a plan that came later: he knows it, as he knows them all
		}
	}
	for l, k in old.larders {
		save.larders[k].used, save.larders[k].pos = l.used, l.pos
		for i in 0 ..< ITEMS_6 {
			save.larders[k].stock[Item(i)] = l.stock[i]
			save.larders[k].kcal[Item(i)] = l.kcal[i]
			save.larders[k].fresh[Item(i)] = l.fresh[i]
		}
	}
}

// The saves of earlier versions, each carried over to the next: the same
// pig, his things in their new places. Version 5 was from before gates and
// the larder, with one skill for all cooking (TRAITS_5 of them). Version 4
// was from before wood and the workbench: Prosio, his sack (of ITEMS_4
// kinds of thing), his outfit and his map. Version 3 was the same from
// before pebbles, with one thing fewer in the sack.
TRAITS_5 :: 7
ITEMS_5 :: 31
ITEMS_4 :: 26
ITEMS_3 :: 25
Save_5 :: struct {
	version:         u32,
	size:            u32,
	fat:             f32,
	trait:           [TRAITS_5]f32,
	need:            [Need]f32,
	sack:            [ITEMS_5]int,
	sack_kcal:       [ITEMS_5]f32,
	sack_sel:        u8,
	outfit:          Outfit,
	seen:            [MAP_W * MAP_H]bool,
	seen_region:     [Region_Kind]bool,
	knows:           [ITEMS_5]bool,
	fence_count:     i32,
	fences:          [MAX_FENCES]Fence_Saved,
	scarecrow_count: i32,
	scarecrows:      [MAX_SCARECROWS]Vec2,
	penned_count:    i32,
	penned:          [MAX_PENNED]Penned_Saved,
}
Save_4 :: struct {
	version:     u32,
	size:        u32,
	fat:         f32,
	trait:       [TRAITS_5]f32,
	need:        [Need]f32,
	sack:        [ITEMS_4]int,
	sack_kcal:   [ITEMS_4]f32,
	sack_sel:    u8,
	outfit:      Outfit,
	seen:        [MAP_W * MAP_H]bool,
	seen_region: [Region_Kind]bool,
}
Save_3 :: struct {
	version:     u32,
	size:        u32,
	fat:         f32,
	trait:       [TRAITS_5]f32,
	need:        [Need]f32,
	sack:        [ITEMS_3]int,
	sack_kcal:   [ITEMS_3]f32,
	sack_sel:    u8,
	outfit:      Outfit,
	seen:        [MAP_W * MAP_H]bool,
	seen_region: [Region_Kind]bool,
}

// The number a thing had in a version 3 save, as it was in version 4.
item_3 :: proc(old: int) -> int {
	return old < int(Item.Pebble) ? old : old + 1
}

from_save_3 :: proc(old: ^Save_3, save: ^Save_4) {
	save^ = {
		version     = 4,
		size        = size_of(Save_4),
		fat         = old.fat,
		trait       = old.trait,
		need        = old.need,
		sack_sel    = u8(item_3(int(old.sack_sel))),
		outfit      = old.outfit,
		seen        = old.seen,
		seen_region = old.seen_region,
	}
	for count, i in old.sack {
		save.sack[item_3(i)] = count
		save.sack_kcal[item_3(i)] = old.sack_kcal[i]
	}
}

// (The things of version 4 kept their numbers: the new ones came after them.)
from_save_4 :: proc(old: ^Save_4, save: ^Save_5) {
	save^ = {
		version     = 5,
		size        = size_of(Save_5),
		fat         = old.fat,
		trait       = old.trait,
		need        = old.need,
		sack_sel    = u8(min(int(old.sack_sel), ITEMS_4 - 1)),
		outfit      = old.outfit,
		seen        = old.seen,
		seen_region = old.seen_region,
	}
	for count, i in old.sack {
		save.sack[i] = count
		save.sack_kcal[i] = old.sack_kcal[i]
	}
	for &known in save.knows {
		known = true // he knew all there was to know (the plans of the time are set again below)
	}
}

// The things of version 5 kept their numbers too. His one cooking skill
// becomes all three of the kitchen's skills; and he knows the plans that
// are new.
from_save_5 :: proc(old: ^Save_5, save: ^Save_6) {
	save^ = {
		version         = 6,
		size            = size_of(Save_6),
		fat             = old.fat,
		need            = old.need,
		sack_sel        = u8(min(int(old.sack_sel), ITEMS_5 - 1)),
		outfit          = old.outfit,
		seen            = old.seen,
		seen_region     = old.seen_region,
		fence_count     = old.fence_count,
		fences          = old.fences,
		scarecrow_count = old.scarecrow_count,
		scarecrows      = old.scarecrows,
		penned_count    = old.penned_count,
		penned          = old.penned,
	}
	for level, i in old.trait {
		if i < int(Trait.Baking) {
			save.trait[Trait(i)] = level
		} else {
			save.trait[.Baking], save.trait[.Grilling], save.trait[.Dairy] = level, level, level
		}
	}
	for count, i in old.sack {
		save.sack[i] = count
		save.sack_kcal[i] = old.sack_kcal[i]
		save.sack_fresh[i] = count > 0 ? 1 : 0 // (food did not go off then)
		save.knows[i] = old.knows[i]
	}
	for r in RECIPES {
		if int(r.dish) >= ITEMS_5 && int(r.dish) < ITEMS_6 {
			save.knows[int(r.dish)] = true
		}
	}
}

has_save: bool
save_t: f32 // until the next save
// The save is put together and read here, not on the stack: it is big.
save_buffer: Save
old_save_6: Save_6
old_save_5: Save_5
old_save_4: Save_4
old_save_3: Save_3

save_game :: proc() {
	if g.opts.shot_path != nil || g.opts.no_save || g.prosio.fail != .None {
		return // not in test runs, and not while he lies there
	}
	p := &g.prosio
	save := &save_buffer
	save^ = {
		version     = SAVE_VERSION,
		size        = size_of(Save),
		fat         = p.fat,
		trait       = p.trait,
		need        = p.need,
		sack        = p.sack,
		sack_kcal   = p.sack_kcal,
		sack_sel    = p.sack_sel,
		outfit      = outfit,
		seen        = g.seen,
		seen_region = g.seen_region,
		knows       = p.knows,
		sack_fresh  = p.sack_fresh,
	}
	for l, i in g.larders {
		save.larders[i] = {l.used, l.pos, l.stock, l.kcal, l.fresh}
	}
	save.camp_up, save.camp_pos = g.camp_up, g.stations[.Camp].pos
	for way in Fence_Way {
		for there, i in g.fences[way] {
			if there && save.fence_count < MAX_FENCES {
				gate := g.gates[way][i]
				save.fences[save.fence_count] = {u8(i % (FENCE_W + 1)), u8(i / (FENCE_W + 1)), u8(way) | (gate != 0 ? 2 : 0) | (gate == GATE_OPEN ? 4 : 0)}
				save.fence_count += 1
			}
		}
	}
	for rd in g.rounds[:g.round_count] {
		if rd.kind == .Scarecrow && rd.r > 0 && save.scarecrow_count < MAX_SCARECROWS {
			save.scarecrows[save.scarecrow_count] = rd.pos
			save.scarecrow_count += 1
		}
	}
	for &e in g.enemies[:g.enemy_count] {
		// (One he is holding, or has just thrown, is not in its pen now.)
		if e.penned && on_ground(&e) && !e.ko && save.penned_count < MAX_PENNED {
			save.penned[save.penned_count] = {e.kind, e.pos}
			save.penned_count += 1
		}
	}
	store_write(([^]u8)(save)[:size_of(Save)])
	has_save = true
}

// Puts a saved Prosio into the game just built, with what he had built in
// the meadow. False if there is none (or it is from a version of the game
// that cannot be carried over).
load_game :: proc() -> bool {
	if g.opts.shot_path != nil || g.opts.no_save {
		return false
	}
	save := &save_buffer
	save^ = {}
	bytes := ([^]u8)(save)[:size_of(Save)]
	n := store_read(bytes)
	if n == size_of(Save_3) && save.version == 3 {
		copy(([^]u8)(&old_save_3)[:size_of(Save_3)], bytes[:size_of(Save_3)])
		if old_save_3.size != size_of(Save_3) {
			return false
		}
		from_save_3(&old_save_3, &old_save_4)
		from_save_4(&old_save_4, &old_save_5)
		from_save_5(&old_save_5, &old_save_6)
		from_save_6(&old_save_6, save)
		n = size_of(Save)
	} else if n == size_of(Save_4) && save.version == 4 {
		copy(([^]u8)(&old_save_4)[:size_of(Save_4)], bytes[:size_of(Save_4)])
		if old_save_4.size != size_of(Save_4) {
			return false
		}
		from_save_4(&old_save_4, &old_save_5)
		from_save_5(&old_save_5, &old_save_6)
		from_save_6(&old_save_6, save)
		n = size_of(Save)
	} else if n == size_of(Save_5) && save.version == 5 {
		copy(([^]u8)(&old_save_5)[:size_of(Save_5)], bytes[:size_of(Save_5)])
		if old_save_5.size != size_of(Save_5) {
			return false
		}
		from_save_5(&old_save_5, &old_save_6)
		from_save_6(&old_save_6, save)
		n = size_of(Save)
	} else if n == size_of(Save_6) && save.version == 6 {
		copy(([^]u8)(&old_save_6)[:size_of(Save_6)], bytes[:size_of(Save_6)])
		if old_save_6.size != size_of(Save_6) {
			return false
		}
		from_save_6(&old_save_6, save)
		n = size_of(Save)
	}
	if n != size_of(Save) || save.version != SAVE_VERSION || save.size != size_of(Save) {
		return false
	}
	if math.is_nan(save.fat) || save.fat < 0 || save.fat >= FAT_MAX {
		return false
	}
	p := &g.prosio
	p.fat = save.fat
	p.trait = save.trait
	p.trait_was = save.trait
	p.fat_was = save.fat
	p.need = save.need
	for n in Need {
		p.need_was[n] = need_state(n)
	}
	p.sack = save.sack
	p.sack_kcal = save.sack_kcal
	for item in Item {
		// Salt picked before it counted its electrolytes as calories was
		// put in the sack with none.
		if p.sack[item] > 0 && p.sack_kcal[item] <= 0 && is_food(item) {
			p.sack_kcal[item] = item_kcal(item) * f32(p.sack[item])
		}
	}
	p.sack_fresh = save.sack_fresh
	p.sack_sel = save.sack_sel
	p.knows = save.knows
	p.kg = weight_with(p.fat)
	outfit = save.outfit
	g.seen = save.seen
	g.seen_region = save.seen_region
	// What he had built: the fences and scarecrows where they stood, and in
	// each pen the animals that were in it (the nearest of their kind are
	// fetched from the meadow).
	for f in save.fences[:clamp(save.fence_count, 0, MAX_FENCES)] {
		at := Fence_At{int(f.x), int(f.y), Fence_Way(f.way & 1)}
		set_fence(at, true)
		if f.way & 2 != 0 {
			set_gate(at, f.way & 4 != 0 ? GATE_OPEN : GATE_SHUT)
		}
	}
	for at in save.scarecrows[:clamp(save.scarecrow_count, 0, MAX_SCARECROWS)] {
		add_scarecrow(at)
	}
	for saved in save.larders {
		if saved.used && add_larder(saved.pos) {
			for &l in g.larders {
				if l.used && l.pos == saved.pos {
					l.stock, l.kcal, l.fresh = saved.stock, saved.kcal, saved.fresh
				}
			}
		}
	}
	if save.camp_up && !math.is_nan(save.camp_pos.x) && beyond_edge(save.camp_pos) < 0 {
		set_up_camp(save.camp_pos)
	}
	fetched: [MAX_ENEMIES]bool
	for pen in save.penned[:clamp(save.penned_count, 0, MAX_PENNED)] {
		if !fenced_in(pen.pos) {
			continue
		}
		best := -1
		for &e, i in g.enemies[:g.enemy_count] {
			if e.kind == pen.kind && !fetched[i] && (best < 0 || length2(e.pos - pen.pos) < length2(g.enemies[best].pos - pen.pos)) {
				best = i
			}
		}
		if best >= 0 {
			fetched[best] = true
			e := &g.enemies[best]
			e.pos = pen.pos
			look_for_pen(e)
		}
	}
	has_save = true
	return true
}
