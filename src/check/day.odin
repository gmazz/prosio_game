package check

import game "../game"
import "core:fmt"

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

	// His stomach: a cabbage (1 kg) fills it, and then he cannot eat until
	// some has gone on; it empties in 5 hours of the game's day (12.5
	// minutes): half way through that, it is half empty.
	// A pumpkin (1.5 kg) into an empty stomach fills it past full.
	fresh()
	g.enemy_count = 0
	game.sack_add(.Cabbage, 0)
	game.sack_add(.Cabbage, 0)
	p.sack_sel = .Cabbage
	step(1, {}, {.Eat})
	step(60)
	full := game.stomach_full()
	step(1, {}, {.Eat})
	refused := p.sack[.Cabbage] == 1 && p.bubble == game.TEXT.stomach_full
	half_way := game.STOMACH_EMPTIES / 2
	step(int(half_way) * 60)
	halved := p.stomach
	step(1, {}, {.Eat})
	ate_again := p.sack[.Cabbage] == 0
	fresh()
	game.sack_add(.Pumpkin, 0)
	p.sack_sel = .Pumpkin
	step(1, {}, {.Eat})
	over := p.stomach
	check("a cabbage fills his stomach (1 litre) and he cannot eat more, saying so; it empties in 5 game hours, so half way through it is half empty and he can; a pumpkin into an empty stomach fills it past full",
		full && refused && abs(halved - 0.5) < 0.01 && ate_again && abs(over - 1.5) < 0.01 && game.STOMACH_EMPTIES == 5.0 / 24 * game.DAY_SECONDS,
		fmt.tprintf("full %v, refused %v, after %.0f s %.2f litres, ate again %v; a pumpkin %.2f litres", full, refused, half_way, halved, ate_again, over))

	// The water in what he eats waters him: a cabbage, 0.92 of its kilogram
	// water, is that much of a drink.
	fresh()
	game.sack_add(.Cabbage, 0)
	p.sack_sel = .Cabbage
	p.need[.Water] = 40
	step(1, {}, {.Eat})
	watered := (p.need[.Water] - 40) / 100 * game.STORE_KG[.Water]
	from_table := game.item_water(.Bread) == game.ITEM_WATER[.Bread] && game.item_water(.Fish) == game.MIXABLE[.Fish].water * 0.5
	check("the water in what he eats waters him: a cabbage puts 0.92 kg of water into him; a fish's counts only the half eaten",
		abs(watered - 0.92) < 0.03 && from_table, fmt.tprintf("a cabbage: %.2f kg of water; bread and fish from their tables %v", watered, from_table))

	// What an animal gives, in meat: a turkey 3 kg, a goat 10, the billy
	// goat 16; a fish is 200 g of flesh. One killed comes back after about
	// a season; one lost in the fog sooner.
	pieces := [3]int{game.meat_pieces(.Turkey), game.meat_pieces(.Goat), game.meat_pieces(.Billy)}
	kg := [3]f32{f32(pieces[0]) * game.ITEM_KG[.Meat], f32(pieces[1]) * game.ITEM_KG[.Meat], f32(pieces[2]) * game.ITEM_KG[.Meat]}
	fish_flesh := game.ITEM_KG[.Fish] * (1 - game.MIXABLE[.Fish].waste)
	check("a turkey gives 3 kg of meat, a goat 10, the billy goat 16 (to the nearest piece); a fish 200 g",
		abs(kg[0] - 3) < 0.1 && abs(kg[1] - 10) < 0.1 && abs(kg[2] - 16) < 0.1 && abs(fish_flesh - 0.2) < 0.001,
		fmt.tprintf("%v pieces: %.2f, %.2f, %.2f kg; a fish %.2f kg", pieces, kg[0], kg[1], kg[2], fish_flesh))
	fresh()
	g.enemy_count = 0
	game.add_enemy(.Turkey, {20, 20})
	game.add_enemy(.Turkey, {22, 20})
	game.leave(&g.enemies[0], true)
	game.leave(&g.enemies[1], false)
	killed_days := g.enemies[0].timer / game.DAY_SECONDS
	lost_minutes := g.enemies[1].timer / 60
	check("a turkey that was killed comes back after about a season (7 days); one lost in the fog after 75 to 120 minutes",
		killed_days >= 6.5 && killed_days <= 7.5 && lost_minutes >= 75 && lost_minutes <= 120,
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
