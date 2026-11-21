package game

import "core:math"

// Prosio is what he does. Besides his fat and what is in his stores (see
// diet.odin, where his weight is added up), he has seven traits: the muscle
// of his arms and of his legs, and five skills. Each is a level that follows
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
//   their ordinary size. Muscle that fades or wastes is not lost: it turns
//   back into carbs. Muscle is also heavy, and hungry: it burns a little
//   weight all the time.
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
	Cooking,
}

TRAIT_NAME := [Trait]cstring {
	.Arms    = "ARMS",
	.Legs    = "LEGS",
	.Lungs   = "LUNGS",
	.Hide    = "HIDE",
	.Gut     = "GUT",
	.Hooves  = "HOOVES",
	.Cooking = "COOKING",
}
// What trains each, and what it is good for.
TRAIT_GROWS := [Trait]cstring {
	.Arms    = "lifting, dragging, bashing, throwing (with protein)",
	.Legs    = "running, jumping, long walks (with protein)",
	.Lungs   = "sprinting",
	.Hide    = "taking pecks, butts and stings",
	.Gut     = "eating fibre",
	.Hooves  = "picking, fishing, milking",
	.Cooking = "baking, cooking, churning",
}
TRAIT_GIVES := [Trait]cstring {
	.Arms    = "he lifts and throws more",
	.Legs    = "he is faster and jumps higher",
	.Lungs   = "sprints cost less, breath comes back sooner",
	.Hide    = "knocks hurt less",
	.Gut     = "he holds his wind, and lets it go with G",
	.Hooves  = "quicker picking, a longer reach",
	.Cooking = "richer food, made faster",
}

// His muscles, in kg: wasted away, ordinary, and the most they can be.
ARMS_KG :: [3]f32{3, 5, 12}
LEGS_KG :: [3]f32{5, 8, 18}

FADE :: f32(0.00064) // the share of a trait lost every second it is not used: half in 18 minutes
WASTE :: f32(0.0015) // how fast muscle wastes each second without protein, or starving: ordinary to wasted in 11 minutes
RECOVER :: f32(0.002) // and how fast wasted muscle comes back to ordinary once he is fed
BULK :: f32(2) // full of protein, muscle builds this much faster
MUSCLE_UPKEEP :: f32(0.0005) // kg burned each second for every kg of muscle beyond the ordinary

// How much each thing he does trains (a trait gains this share of what it
// still lacks).
CARRY_WORK :: f32(0.004) // arms: each second of holding something of his own weight
SWING_WORK :: f32(0.02) // arms: each bash or throw of something of his own weight
SPRINT_WORK :: f32(0.004) // legs and lungs: each second of sprinting
WALK_WORK :: f32(0.0006) // legs: each second of walking
JUMP_WORK :: f32(0.015) // legs: each jump
DRAG_WORK :: f32(0.002) // legs: each second of dragging a body
KNOCK_WORK :: f32(0.04) // hide: each peck or butt
STING_WORK :: f32(0.01) // hide: each sting
GUT_WORK :: f32(0.2) // gut: each kg of fibre eaten
PICK_WORK :: f32(0.02) // hooves: each thing picked
FISH_WORK :: f32(0.04) // hooves: each grab for a fish
MILK_WORK :: f32(0.05) // hooves: each milking
COOK_WORK :: f32(0.06) // cooking: each thing made

// What each trait is worth at its most (and a muscle at its worst).
STRONG :: f32(1.8) // arms: how much more he lifts and how much harder he throws,
NOODLE_ARMS :: f32(0.6) // and with arms wasted away
LEG_SPEED :: f32(1.3) // legs: how much faster he walks and runs,
LEG_SPRING :: f32(2) // and how much more goes into a jump;
WEAK_LEGS :: f32(0.75) // both, with legs wasted away
LUNG_DRAIN :: f32(0.55) // lungs: the share of the usual stamina a sprint costs,
LUNG_REGEN :: f32(1.6) // and how much faster it comes back
THIN_SKIN :: f32(1.5) // the share of a knock he feels with no fat on him,
PADDED :: f32(0.5) // with all the fat he can carry,
TOUGH_HIDE :: f32(0.5) // and, on top of that, with the toughest hide
GUT_CONTROL :: f32(0.4) // gut: from this level he holds his wind until G is pressed,
GUT_HOLD :: f32(2) // seconds between two of them then,
GUT_REACH :: f32(1.5) // and how much further his wind reaches at the most
DEFT_PICK :: f32(0.5) // hooves: the share of the usual time picking takes,
DEFT_REACH :: f32(1.4) // and how much further he reaches for a fish or a leg
COOK_EXTRA :: f32(0.2) // cooking: what is added to the cooking bonus (1.4 becomes 1.6),
COOK_QUICK :: f32(0.5) // and the share of the usual time it takes

// Waking up at home after the game was over: his fat is brought back inside
// these, he has lost this share of the muscle he had built, and his sack is
// gone. What he has learnt stays.
WAKE_FAT :: Vec2{25, 70}
WAKE_MUSCLE_LOSS :: f32(0.35)

is_muscle :: proc(t: Trait) -> bool {
	return t == .Arms || t == .Legs
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

// He has done something that trains a trait.
train :: proc(t: Trait, work: f32) {
	p := &g.prosio
	gain := work * (1 - p.trait[t])
	if is_muscle(t) {
		// Muscle is built out of the protein in him, kilogram for kilogram:
		// little to spare, little muscle; none, none.
		supply := clamp((p.need[.Protein] - NEED_LOW) / 30, 0, 1) * (full_of(.Protein) ? BULK : 1)
		kg := min(gain * supply * muscle_span(t), store_kg(.Protein))
		store_add(.Protein, -kg)
		gain = kg / muscle_span(t)
	}
	p.trait[t] = min(p.trait[t] + gain, 1)
}

update_body :: proc(dt: f32) {
	p := &g.prosio
	starving := p.fat < FAT_DANGER
	for t in Trait {
		level := p.trait[t]
		change: f32
		switch {
		case is_muscle(t) && (lacks(.Protein) || starving):
			change = max(level - WASTE * dt, -1) - level
		case level > 0:
			change = -level * FADE * dt
		case level < 0:
			change = min(level + RECOVER * dt, 0) - level
		}
		if is_muscle(t) {
			// Muscle that goes turns into carbs (and what they cannot hold,
			// into fat); muscle that comes back is made of protein.
			kg := change * muscle_span(t)
			if kg < 0 {
				p.fat += store_add(.Carbs, -kg)
			} else {
				kg = min(kg, store_kg(.Protein))
				store_add(.Protein, -kg)
				change = kg / muscle_span(t)
			}
		}
		p.trait[t] = level + change
	}
	// Muscle beyond the ordinary has to be fed.
	extra := max(muscle_kg(.Arms) - ARMS_KG[1], 0) + max(muscle_kg(.Legs) - LEGS_KG[1], 0)
	burn(MUSCLE_UPKEEP * extra * dt)
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
cook_bonus :: proc(at: Station_Kind) -> f32 {
	base := STATION_BONUS[at]
	return base > 1 ? base + COOK_EXTRA * g.prosio.trait[.Cooking] : base
}

cook_time :: proc(at: Station_Kind) -> f32 {
	return STATION_TIME[at] * lerp(1, COOK_QUICK, g.prosio.trait[.Cooking])
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

// What is kept between one sitting and the next: Prosio himself, what he
// carries and wears, and what he has seen of the meadow. The meadow itself
// starts afresh each time.
SAVE_VERSION :: u32(3)
Save :: struct {
	version:     u32,
	size:        u32,
	fat:         f32,
	trait:       [Trait]f32,
	need:        [Need]f32,
	sack:        [Item]int,
	sack_kcal:   [Item]f32,
	sack_sel:    Item,
	outfit:      Outfit,
	seen:        [MAP_W * MAP_H]bool,
	seen_region: [Region_Kind]bool,
}

has_save: bool
save_t: f32 // until the next save

save_game :: proc() {
	if g.opts.shot_path != nil || g.prosio.fail != .None {
		return // not in test runs, and not while he lies there
	}
	p := &g.prosio
	save := Save {
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
	}
	store_write(([^]u8)(&save)[:size_of(Save)])
	has_save = true
}

// Puts a saved Prosio into the game just built. False if there is none (or
// it is from another version of the game).
load_game :: proc() -> bool {
	if g.opts.shot_path != nil {
		return false
	}
	save: Save
	n := store_read(([^]u8)(&save)[:size_of(Save)])
	if n != size_of(Save) || save.version != SAVE_VERSION || save.size != size_of(Save) {
		return false
	}
	if math.is_nan(save.fat) || save.fat <= 0 || save.fat >= FAT_MAX {
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
	p.sack_sel = save.sack_sel
	p.kg = weight_with(p.fat)
	outfit = save.outfit
	g.seen = save.seen
	g.seen_region = save.seen_region
	has_save = true
	return true
}
