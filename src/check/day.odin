package check

import game "../game"
import "core:fmt"
import "core:math"

// The day's budget (docs/plans/wd2-day-budget.md): a day is DAY_SECONDS of
// play; what he burns in it, what the meadow gives, his stomach, what an
// animal gives, the water in food, and how long cooking makes him wait.
rules_day_budget :: proc() {
	section("the day's budget")
	g := &game.g
	p := &g.prosio
	KCAL :: game.KCAL_PER_KG

	// The active day (30 minutes walking, 2 sprinting, 150 things picked,
	// 30 jumps, 30 bumps, grabs, bashes or throws, for an 80 kg Prosio with
	// ordinary muscle) burns 2,000 kcal; a day of rest 1,200. Worked out
	// from the numbers, and his muscles' share also by letting a day pass.
	muscle := game.ARMS_KG[1] + game.LEGS_KG[1]
	alive := game.BASAL * muscle * game.DAY_SECONDS * KCAL
	doing := (game.WALK_BURN * 30 * 60 + game.SPRINT_BURN * 2 * 60 + 150 * game.GATHER_BURN + 30 * game.JUMP_BURN + 30 * game.FIGHT_BURN) * KCAL
	fresh()
	g.enemy_count = 0
	p.need[.Protein] = 50 // (fed: his muscles neither waste nor grow)
	before := g.burned[.Muscle]
	for _ in 0 ..< int(game.DAY_SECONDS) * 60 {
		game.update_body(1.0 / 60)
	}
	rested := f32(g.burned[.Muscle] - before) * KCAL
	check("an active day burns about 2,000 kcal (within 3%), and a day of rest about 1,200: being alive 1,200, doing things 800",
		abs(alive + doing - 2000) < 60 && abs(alive - 1200) < 36 && abs(rested - alive) < 0.02 * alive,
		fmt.tprintf("being alive %.0f kcal (a day of rest, let pass: %.0f), doing things %.0f, an active day %.0f", alive, rested, doing, alive + doing))

	// The meadow: of each kind, at most a day's food stands at once, and
	// what is picked takes MEADOW_SLOW times as long to come back.
	slow := game.MEADOW_SLOW
	slowed := game.FOOD_REGROW[.Pumpkin] == {240 * slow, 540 * slow} && game.FOOD_GROW[.Pumpkin] == 300 * slow && game.BERRY_REGROW == {60 * slow, 160 * slow} && game.APPLE_REGROW == {120 * slow, 300 * slow} && game.FISH_BACK == {240 * slow, 480 * slow} && game.HONEY_REGROW == {240 * slow, 480 * slow} && game.MILK_EVERY == 180 * slow && game.PEN_EGG_EVERY == {60 * slow, 120 * slow}
	check("at most a day's food of each kind stands at once (2,000 kcal; mushrooms 600), and all that grows or comes back takes 15 times as long as it did",
		game.FOOD_BUDGET == 2000 && game.MUSHROOM_BUDGET == 600 && slow == 15 && slowed,
		fmt.tprintf("budget %.0f, mushrooms %.0f, %.0f times as long: %v (a pumpkin grows in %.0f minutes)", game.FOOD_BUDGET, game.MUSHROOM_BUDGET, slow, slowed, game.FOOD_GROW[.Pumpkin] / 60))

	// His stomach holds a litre and a half: a pumpkin (1.5 kg) fills it, and
	// then he cannot eat until some has gone on; it empties in 2 hours of
	// the game's day (5 minutes): half way through that, it is half empty.
	// A cabbage (1 kg) does not fill it.
	fresh()
	g.enemy_count = 0
	game.sack_add(.Pumpkin, 0)
	game.sack_add(.Pumpkin, 0)
	p.sack_sel = .Pumpkin
	step(1, {}, {.Eat})
	step(60)
	full := game.stomach_full()
	step(1, {}, {.Eat})
	refused := p.sack[.Pumpkin] == 1 && p.bubble == game.TEXT.stomach_full
	half_way := game.STOMACH_EMPTIES / 2
	step(int(half_way) * 60 - 61)
	halved := p.stomach
	step(1, {}, {.Eat})
	ate_again := p.sack[.Pumpkin] == 0
	fresh()
	game.sack_add(.Cabbage, 0)
	p.sack_sel = .Cabbage
	step(1, {}, {.Eat})
	cabbage_full := game.stomach_full()
	check("a pumpkin fills his stomach (a litre and a half) and he cannot eat more, saying so; it empties in 2 game hours, so half way through it is half empty and he can; a cabbage does not fill it",
		full && refused && abs(halved - 0.75) < 0.01 && ate_again && !cabbage_full && game.STOMACH_HOLDS == 1.5 && game.STOMACH_EMPTIES == 2.0 / 24 * game.DAY_SECONDS,
		fmt.tprintf("full %v, refused %v, after %.0f s %.2f litres, ate again %v; full after a cabbage %v", full, refused, half_way, halved, ate_again, cabbage_full))

	// The water in what he eats waters him: a cabbage, 0.92 of its kilogram
	// water, is that much of a drink, once he has digested it.
	fresh()
	game.sack_add(.Cabbage, 0)
	p.sack_sel = .Cabbage
	p.need[.Water] = 40
	step(1, {}, {.Eat})
	watered_kg := game.store_kg(.Water)
	digest_all()
	watered := game.store_kg(.Water) - watered_kg
	from_table := game.item_water(.Bread) == game.ITEM_WATER[.Bread] && game.item_water(.Fish) == game.MIXABLE[.Fish].water * 0.5
	check("the water in what he eats waters him: a cabbage puts 0.92 kg of water into him; a fish's counts only the half eaten",
		abs(watered - 0.92) < 0.03 && from_table, fmt.tprintf("a cabbage: %.2f kg of water; bread and fish from their tables %v", watered, from_table))

	// What an animal gives, in meat: 4% of its weight, to the nearest cut:
	// a turkey 3 cuts, a goat 12, the billy goat 20; a fox none. A fish is
	// 200 g of flesh. One killed comes back after about two days; one lost
	// in the fog sooner.
	pieces := [4]int{game.meat_pieces(.Turkey), game.meat_pieces(.Goat), game.meat_pieces(.Billy), game.meat_pieces(.Fox)}
	fish_flesh := game.ITEM_KG[.Fish] * (1 - game.MIXABLE[.Fish].waste)
	check("an animal gives 4% of its weight in meat, to the nearest cut: a turkey 3 cuts, a goat 12, the billy goat 20, a fox none; a fish 200 g",
		pieces == {3, 12, 20, 0} && game.MEAT_SHARE == 0.04 && abs(fish_flesh - 0.2) < 0.001,
		fmt.tprintf("cuts %v (a cut %.2f kg); a fish %.2f kg", pieces, game.ITEM_KG[.Meat], fish_flesh))
	fresh()
	g.enemy_count = 0
	game.add_enemy(.Turkey, {20, 20})
	game.add_enemy(.Turkey, {22, 20})
	game.leave(&g.enemies[0], true)
	game.leave(&g.enemies[1], false)
	killed_days := g.enemies[0].timer / game.DAY_SECONDS
	lost_minutes := g.enemies[1].timer / 60
	check("a turkey that was killed comes back after about two days (1.75 to 2.25); one lost in the fog after 75 to 120 minutes",
		killed_days >= 1.75 && killed_days <= 2.25 && lost_minutes >= 75 && lost_minutes <= 120,
		fmt.tprintf("killed: back in %.1f days; lost: in %.0f minutes", killed_days, lost_minutes))

	// Cooking waits: a dial minute is a quarter of a second, so a loaf of
	// bread (40 minutes at 200 degrees) waits about 10 s; nothing waits
	// more than 20 s; mixing takes 1 to 3 s.
	loaf, _ := game.shape_mix(bowl("500g flour, 300ml water, 10g salt"), .Loaf)
	_, bake := game.best_settings(loaf, .Bake)
	wait := game.cook_seconds(bake)
	check("a loaf of bread waits about 10 s in the oven, nothing more than 20 s, and mixing 1 to 3 s",
		wait > 9 && wait < 11 && game.cook_seconds(300) == 20 && game.mix_seconds(0.1) == 1 && game.mix_seconds(60) == 3,
		fmt.tprintf("bread %.0f minutes on the dial, %.1f s; five hours %.0f s; mixing %.0f to %.0f s", bake, wait, game.cook_seconds(300), game.mix_seconds(0.1), game.mix_seconds(60)))

	// Wine is 11 to 12% by volume; salt goes into a bowl by the gram.
	juice := bowl("500g grapes", {pressed = true})
	wine := game.stand(juice, 10, 20, false)
	strength := game.alcohol_by_volume(wine) * 100
	check("500 g grapes pressed and left 10 days make wine of 11 to 12% by volume; salt is weighed in grams",
		wine.crock == .Wine && strength >= 11 && strength <= 12 && game.MIXABLE[.Salt].unit == .Gram,
		fmt.tprintf("%v, %.1f%% by volume; salt in %v", wine.crock, strength, game.MIXABLE[.Salt].unit))
}

// Lets his stomach empty, with nothing else going on: no thirst, no
// burning, nothing fading.
digest_all :: proc() {
	for game.g.prosio.stomach > 0 {
		game.digest(1.0 / 60)
	}
	game.digest(1.0 / 60)
}

// What he eats goes into his stomach, and from there into him as it
// empties; his water lasts a quarter of the day; his stomach is saved.
rules_digestion :: proc() {
	section("digestion")
	g := &game.g
	p := &g.prosio

	// Nothing is lost or made on the way: a meal eaten and digested puts
	// into him, to the gram, what it would have put in at once.
	MEAL :: [?]game.Item{.Cabbage, .Berries, .Berries, .Nuts, .Bread, .Honey, .Salt}
	Stores :: struct {
		kg:     [game.Need]f32,
		level:  [game.Need]f32,
		fat:    f32,
	}
	stores :: proc() -> (s: Stores) {
		for n in game.Need {
			s.kg[n], s.level[n] = game.store_kg(n), game.g.prosio.need[n]
		}
		s.fat = game.g.prosio.fat
		return
	}
	start :: proc() {
		fresh()
		game.g.enemy_count = 0
		game.g.prosio.need[.Water] = 20 // (room for all the water in it)
	}
	start()
	for item in MEAL {
		m := game.item_meal(item, game.item_kcal(item))
		m.water = game.ITEM_KG[item] * game.item_water(item)
		game.eat(m)
	}
	at_once := stores()
	start()
	before := stores()
	for item in MEAL {
		game.swallow(item, game.item_meal(item, game.item_kcal(item)))
	}
	right_after := stores()
	digest_all()
	digested := stores()
	worst_kg, worst_level: f32
	for n in game.Need {
		worst_kg = max(worst_kg, abs(digested.kg[n] - at_once.kg[n]))
		worst_level = max(worst_level, abs(digested.level[n] - at_once.level[n]))
	}
	worst_kg = max(worst_kg, abs(digested.fat - at_once.fat))
	untouched := right_after == before
	check("a meal eaten and digested puts into him, to the gram, what it would have put in at once; until it is digested, none of it has",
		worst_kg < 0.001 && worst_level < 0.01 && untouched && p.stomach == 0 && p.gut == {},
		fmt.tprintf("cabbage, berries, nuts, bread, honey, salt: off by at most %.4f kg and %.4f points; nothing in him before digesting %v", worst_kg, worst_level, untouched))

	// What is in his stomach counts in his weight, as a part of its own,
	// and goes into him as it empties: half empty, half of it has.
	fresh()
	g.enemy_count = 0
	game.sack_add(.Cabbage, game.item_kcal(.Cabbage))
	p.sack_sel = .Cabbage
	kg := game.body_kg()
	fibre := p.need[.Fibre]
	m := game.item_meal(.Cabbage, game.item_kcal(.Cabbage))
	step(1, {}, {.Eat})
	in_stomach := game.part_kg(.Stomach)
	expected := game.meal_kg(m) + game.ITEM_KG[.Cabbage] * game.item_water(.Cabbage)
	parts: f32
	for part in game.Part {
		parts += game.part_kg(part)
	}
	heavier := game.body_kg() - kg
	fibre_now := p.need[.Fibre] - fibre
	adds_up := parts == game.body_kg() && abs(p.kg - game.body_kg()) < 0.01
	ate := p.stomach
	for p.stomach > ate / 2 {
		game.digest(1.0 / 60)
	}
	half := 1 - game.part_kg(.Stomach) / in_stomach
	check("what is in his stomach is a part of his weight (a cabbage 2.67 kg: what it puts into him, its water too), and goes into him as his stomach empties: half empty, half of it has",
		abs(in_stomach - expected) < 0.001 && abs(heavier - expected) < 0.01 && adds_up && fibre_now < 0.1 && abs(half - 0.5) < 0.01,
		fmt.tprintf("in his stomach %.2f kg (expected %.2f), he weighs %.2f kg more; his fibre up %.2f points a frame after; half empty, %.2f of it gone in", in_stomach, expected, heavier, fibre_now, half))

	// His water: from where it starts to thirsty in 15 minutes at rest, a
	// quarter of the day; the store holds 2 kg.
	fresh()
	g.enemy_count = 0
	frames := 0
	for p.need[.Water] >= game.WATER_LOW {
		game.update_diet(1.0 / 60)
		frames += 1
	}
	took := f32(frames) / 60 / 60
	check("his water goes from where it starts to thirsty in about 15 minutes at rest (a quarter of the day), and holds 2 kg",
		abs(took - 15) < 0.2 && game.STORE_KG[.Water] == 2 && game.THIRST == (game.WATER_START - game.WATER_LOW) / (game.DAY_SECONDS / 4),
		fmt.tprintf("%.1f minutes; the store %.0f kg", took, game.STORE_KG[.Water]))

	// The stomach is saved with him; a pig saved before it held anything
	// loads with it empty.
	fresh()
	g.enemy_count = 0
	game.sack_add(.Bread, 0)
	p.sack_sel = .Bread
	step(1, {}, {.Eat})
	litres, gut := p.stomach, p.gut
	g.opts.no_save = false
	game.save_game()
	fresh()
	g.opts.no_save = false
	loaded := game.load_game()
	kept := loaded && p.stomach == litres && p.gut == gut && litres > 0
	old := new(game.Save_7)
	old.version, old.size, old.fat = 7, size_of(game.Save_7), 47
	old.need = p.need
	old.sack[.Honey] = 1
	old.sack_kcal[.Honey] = 300
	game.store_write(([^]u8)(old)[:size_of(game.Save_7)])
	fresh()
	g.opts.no_save = false
	loaded_7 := game.load_game()
	g.opts.no_save = true
	free(old)
	check("what is in his stomach is saved with him; a Prosio saved before it held anything loads with it empty",
		kept && loaded_7 && abs(p.fat - 47) < 0.01 && p.sack[.Honey] == 1 && p.stomach == 0 && p.gut == {},
		fmt.tprintf("kept %v (%.2f litres); version 7 loaded %v, fat %.0f, honey %d, stomach %.2f", kept, litres, loaded_7, p.fat, p.sack[.Honey], p.stomach))
}

// Fighting by the energy of the blow, the hunt's chopping and roasting, and
// protein that lasts a third of a day.
rules_blows_by_energy :: proc() {
	section("fighting by the energy of the blow")
	g := &game.g
	p := &g.prosio
	ordinary :: proc() {
		fresh()
		game.g.enemy_count = 0
		game.g.round_count = 0
		game.g.prosio.pos = {20, 20}
		game.g.prosio.facing = 0
	}

	// What a blow takes is its energy times the factor for its kind, out of
	// BLOW_TAKES joules a kilogram of the animal times its toughness.
	ordinary()
	e := animal_before_him(.Goat)
	joules: f32 = 500
	expected := game.ENEMY_HEALTH * joules * game.BLOW_FACTOR[.Hard] / (game.BLOW_TAKES * game.ENEMY_KG[.Goat] * game.ENEMY_TOUGH[.Goat])
	by_rule := game.blow_harm(.Goat, joules, .Hard) == expected
	kinds_in_order := game.BLOW_FACTOR[.Soft] < game.BLOW_FACTOR[.Hard] && game.BLOW_FACTOR[.Hard] < game.BLOW_FACTOR[.Sharp]
	stone := game.stone_damage(2, 10, .Turkey) == game.blow_harm(.Turkey, game.stone_joules(2, 10), .Hard)
	spear := game.spear_damage(.Goat, 20) == game.blow_harm(.Goat, game.kinetic(game.SPEAR_KG, 20), .Sharp) && game.blow_harm(.Goat, 100, .Sharp) == game.ENEMY_HIDE[.Goat] * game.ENEMY_HEALTH * 100 * game.BLOW_FACTOR[.Sharp] / (game.BLOW_TAKES * game.ENEMY_KG[.Goat] * game.ENEMY_TOUGH[.Goat])
	thrown := game.blow_damage(.Turkey, 8) == game.blow_harm(.Turkey, game.kinetic(game.ENEMY_KG[.Turkey], 8), .Soft)
	check("a blow takes its energy times the factor for its kind (soft under hard under sharp), out of what the animal can take: joules a kilogram of it times its toughness; a stone and a rock are hard, a spear sharp (and only so much of it gets through the hide, ENEMY_HIDE), a thrown or bumped animal soft",
		by_rule && kinds_in_order && stone && spear && thrown && e.health == game.ENEMY_HEALTH,
		fmt.tprintf("500 J of a hard blow on a goat: %.1f; factors %v; stone %v, spear %v, thrown %v", expected, game.BLOW_FACTOR, stone, spear, thrown))

	// Calibrated for an ordinary Prosio (Gio's counts): spears at full arm
	// speed four for a turkey, five for a goat or a fox, eight for the billy
	// goat; a bump at a run on a turkey as before (a quarter of what it took
	// before the blows went by energy, 29 of 100); the heaviest rock he can
	// lift (40 kg) a seventh of a turkey (the momentum share at 0), a 2 kg stone
	// about a tenth.
	count :: proc(harm: f32) -> int {return game.blows_needed(harm)}
	height := game.jump_height(game.total_kg())
	arm := game.stone_speed(game.SPEAR_KG)
	spears := [4]int{count(game.spear_damage(.Turkey, arm)), count(game.spear_damage(.Goat, arm)), count(game.spear_damage(.Fox, arm)), count(game.spear_damage(.Billy, arm))}
	bump := game.blow_damage(.Turkey, game.bump_speed(p.kg * game.dash_speed(), .Turkey))
	rock := game.test_blow(.Rock, .Turkey)
	stone2 := game.test_blow(.Stone, .Turkey)
	check("an ordinary Prosio needs 4 spears thrown as hard as an arm can for a turkey, 5 for a goat or a fox and 8 for the billy goat; a bump at a run takes what it did (about 7 of a turkey's 100); the heaviest rock he lifts (40 kg) a seventh of a turkey (the momentum share at 0), a 2 kg stone about a tenth",
		spears == {4, 5, 5, 8} && abs(bump - 29.3 / 4) < 1 && abs(arm - game.ARM_SPEED) < 0.01 && abs(game.lift_most() - 40) < 0.01 && rock > 13 && rock < 15 && stone2 > 9 && stone2 < 12,
		fmt.tprintf("spears (turkey, goat, fox, billy) %v (at %.0f m/s), a bump %.1f, the 40 kg rock %.1f, a 2 kg stone %.1f", spears, arm, bump, rock, stone2))

	// A stone or a rock harms part by its energy, part by its momentum
	// (STONE_MOMENTUM_SHARE): at 0 by its energy alone, as physics has it;
	// thrown at ARM_SPEED the same at any share; a heavy, slow rock gains.
	pure := game.stone_share_joules(40, 5, 0) == game.kinetic(40, 5)
	fast := abs(game.stone_share_joules(2, game.ARM_SPEED, 0) - game.stone_share_joules(2, game.ARM_SPEED, 1)) < 0.01
	slow_gains := game.stone_share_joules(40, 5, 1) > 2 * game.stone_share_joules(40, 5, 0)
	check("a stone or a rock harms by a share of its momentum and the rest by its energy: at share 0 by its energy alone, a stone thrown at ARM_SPEED the same at any share, a heavy slow rock more the more the share; it starts at 0, as Gio set it",
		pure && fast && slow_gains && game.STONE_MOMENTUM_SHARE == 0,
		fmt.tprintf("pure energy at 0 %v; the same at ARM_SPEED %v; a 40 kg rock at 5 m/s: %.0f J at 0, %.0f at 1", pure, fast, game.stone_share_joules(40, 5, 0), game.stone_share_joules(40, 5, 1)))

	// A rock that comes down on an animal from above counts its fall by
	// FALL_GRAVITY (not the GRAVITY it falls by), and presses on as it sinks
	// in, as a stomp does.
	ordinary()
	e = animal_before_him(.Turkey)
	p.pos = e.pos + {50, 0} // far off: it rests where it is
	step(5)
	rock_kg := f32(10)
	g.thrown[0] = {active = true, round = -1, r = 0.3, kg = rock_kg, pos = e.pos, y = 3}
	before := e.health
	for _ in 0 ..< 60 {
		if e.health < before {break}
		step(1)
	}
	dropped := before - e.health
	fell := 3 - 2 * game.ENEMY_RADIUS[.Turkey] // (it hits once it is that low)
	counted := game.stone_damage(rock_kg, math.sqrt(2 * game.FALL_GRAVITY * fell), .Turkey, true)
	real_g := game.stone_damage(rock_kg, math.sqrt(2 * game.GRAVITY * fell), .Turkey, true)
	check("a rock dropped onto an animal from above harms by its fall counted with FALL_GRAVITY, and presses on as it sinks into it (STOMP_SINK)",
		dropped > counted * 0.9 && dropped < counted * 1.15 && dropped < real_g * 0.9,
		fmt.tprintf("a 10 kg rock from 3 m on a turkey took %.1f (by FALL_GRAVITY about %.1f; by GRAVITY it would be %.1f)", dropped, counted, real_g))

	// A real stomp: he comes down on a turkey from the top of his jump, and
	// it takes what the energy says, and stays flattened by his momentum.
	ordinary()
	e = animal_before_him(.Turkey)
	e.pos = p.pos
	p.airborne, p.height, p.peak, p.vy = true, height, height, -1.5
	step(20)
	took := game.ENEMY_HEALTH - e.health
	pinned := e.timer
	check("coming down on a turkey from the top of his jump takes what the energy of it says (his weight times gravity times the height and 0.15 m more), and pins it by his momentum, about 2 s",
		abs(took - game.stomp_harm(.Turkey, height)) < 0.5 && e.state == .Dizzy && abs(game.stomp_pin(height) - 2) < 0.2,
		fmt.tprintf("it took %.1f (expected %.1f); pinned %.1f s on, %.1f s in all", took, game.stomp_harm(.Turkey, height), pinned, game.stomp_pin(height)))

	// With the same legs a heavier Prosio jumps lower but stomps harder (he
	// presses on as he sinks); stronger legs jump higher and stomp harder;
	// an ordinary 80 kg Prosio jumps 0.45 m.
	ordinary()
	game.set_weight(80)
	h80, e80 := game.jump_height(game.total_kg()), game.stomp_energy(game.jump_height(game.total_kg()))
	game.set_weight(120)
	h120, e120 := game.jump_height(game.total_kg()), game.stomp_energy(game.jump_height(game.total_kg()))
	game.set_weight(80)
	p.trait[.Legs] = 1
	game.set_weight(80)
	hstrong, estrong := game.jump_height(game.total_kg()), game.stomp_energy(game.jump_height(game.total_kg()))
	check("with the same legs, a heavier Prosio jumps lower but stomps harder; stronger legs jump higher and stomp harder; an ordinary 80 kg Prosio jumps 0.45 m",
		h120 < h80 && e120 > e80 && hstrong > h80 && estrong > e80 && abs(h80 - 0.45) < 0.005,
		fmt.tprintf("80 kg: %.2f m, %.0f J; 120 kg: %.2f m, %.0f J; 80 kg with the strongest legs: %.2f m, %.0f J", h80, e80, h120, e120, hstrong, estrong))

	// A rock heavier than his arms can lift stays on the ground; the
	// strongest arms lift it, and heaving it up takes a while.
	ordinary()
	r := math.cbrt(f32(50) / game.ROCK_DENSITY) // a 50 kg rock
	game.add_round(p.pos + {0, game.prosio_radius(p.kg) + r + 0.1}, r, .Rock)
	step(2, {}, {.Grab})
	refused := p.carry == .Nothing && p.bubble == game.TEXT.way_too_heavy_lift
	p.trait[.Arms] = 1
	p.bubble_t = 0
	step(2, {}, {.Grab})
	lifted := p.carry == .Rock
	heave := p.lift_total
	check("a rock heavier than his arm muscle can lift (8 kg a kg of it: 40 kg for an ordinary Prosio) stays on the ground, and he says so; with the strongest arms (96 kg) he heaves it up, slowly",
		refused && lifted && abs(heave - game.HEAVE_TIME * 50 / 96) < 0.05 && abs(game.lift_most() - 96) < 0.01,
		fmt.tprintf("ordinary: refused %v; strongest arms: lifted %v, heaving it up %.2f s", refused, lifted, heave))

	section("the hunt's meat")
	// Chopping is done with E held, a cut every 3 s; letting go stops it,
	// what is cut is in the sack, and the rest stays on the body, the cut
	// he was at as far as it got; a knock stops it too; and he can finish.
	fresh()
	g.enemy_count = 0
	fire := g.stations[.Fire].pos
	p.pos = fire + {0, 4}
	body := animal_before_him(.Turkey)
	body.state, body.ko, body.body_t = .Dead, true, game.BODY_LIFE
	step(2, {}, {.Grab})
	step(20)
	p.pos = fire + game.FIRE_BLOCK.xz + {0, 1.6}
	step(int(game.CHOP_TIME * 1.5 * 60), {.Action}, {.Action})
	one_cut := p.sack[.Meat] == 1 && body.cut == 1 && p.carry == .Enemy
	step(30)
	stopped := !p.chopping && p.sack[.Meat] == 1 && abs(body.chop_t - game.CHOP_TIME / 2) < 0.1
	step(1, {.Action}, {.Action})
	game.bruise(2)
	step(30)
	knocked := !p.chopping && p.sack[.Meat] == 1
	step(int(game.CHOP_TIME * 2 * 60), {.Action}, {.Action})
	finished := p.sack[.Meat] == 3 && p.carry == .Nothing && body.state == .Gone
	check("chopping goes on while E is held, a cut every 3 s; letting go or a knock stops it with what is cut in the sack and the rest on the body, and holding E again finishes it",
		one_cut && stopped && knocked && finished,
		fmt.tprintf("after 4.5 s: a cut %v; let go: stopped half way into the next %v; knocked: stopped %v; finished: %v (%d cuts)", one_cut, stopped, knocked, finished, p.sack[.Meat]))

	// The spit takes four cuts at most, 5 s each.
	fresh()
	for _ in 0 ..< 6 {
		game.sack_add(.Meat, 300)
		game.sack_add(.Wood, 0)
	}
	roast: ^game.Recipe
	for &rec in game.RECIPES {
		if rec.dish == .Roast {
			roast = &rec
		}
	}
	most := game.max_batch(roast)
	check("meat roasts four cuts at most on the spit at once, 5 s a cut (for a beginner)",
		most == 4 && game.batch_time(.Fire, .Roast, 4) == 20 && game.batch_time(.Fire, .Fried_Egg, 4) == game.cook_time(.Fire),
		fmt.tprintf("at most %d at once; four take %.0f s; four fried eggs %.0f s", most, game.batch_time(.Fire, .Roast, 4), game.batch_time(.Fire, .Fried_Egg, 4)))

	// His protein falls by half in a third of a day at rest; his fibre,
	// vitamins and electrolytes in a day.
	fresh()
	g.enemy_count = 0
	p.need[.Protein], p.need[.Fibre] = 60, 60
	for _ in 0 ..< int(game.DAY_SECONDS / 3) * 60 {
		game.update_diet(1.0 / 60)
	}
	check("his protein falls by half in a third of a day (20 minutes) at rest; his fibre in a day",
		abs(p.need[.Protein] - 30) < 0.5 && abs(p.need[.Fibre] - 60 * math.pow(f32(0.5), 1.0 / 3)) < 0.5,
		fmt.tprintf("from 60 after 20 minutes: protein %.1f, fibre %.1f", p.need[.Protein], p.need[.Fibre]))
}
