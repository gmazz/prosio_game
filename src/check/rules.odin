package check

// The rules the game must keep, each checked by playing it out. Every rule
// here came from a decision about the design or from a bug that was found:
// keep them passing.

import game "../game"
import "core:fmt"
import "core:math"

passed, failed: int

check :: proc(name: string, ok: bool, detail: string = "") {
	if ok {
		passed += 1
		fmt.printf("PASS  %s", name)
	} else {
		failed += 1
		fmt.printf("FAIL  %s", name)
	}
	if detail != "" {
		fmt.printf("  (%s)", detail)
	}
	fmt.println()
}

section :: proc(name: string) {
	fmt.printf("\n== %s\n", name)
}

run_rules :: proc() -> int {
	rules_weight()
	rules_release()
	rules_diet()
	rules_energy()
	rules_body()
	rules_world()
	rules_kitchen()
	rules_animals()
	rules_fighting()
	rules_stones()
	rules_workshop()
	rules_saving()
	rules_moving()
	fmt.printf("\n%d passed, %d failed\n", passed, failed)
	return failed
}

// Muscle that comes back, where his weight goes, and the weight a test asks for.
rules_body :: proc() {
	section("body")
	g := &game.g
	p := &g.prosio

	// A wasted pig standing still, eating nothing: his muscle comes back out
	// of his protein, but never so fast that he ends up lacking protein and
	// loses it again.
	fresh()
	g.enemy_count = 0
	p.trait[.Arms], p.trait[.Legs] = -1, -1
	most, least_after: f32 = 0, 1000
	lacked := false
	for _ in 0 ..< 240 {
		p.need[.Water] = 80
		p.need[.Carbs] = 60
		step(60)
		muscle := game.part_kg(.Muscle)
		if muscle > most {
			most, least_after = muscle, muscle
		}
		least_after = min(least_after, muscle)
		lacked ||= game.lacks(.Protein)
	}
	check("wasted muscle comes back without wasting again", most > 8.3 && most - least_after < 0.05 && !lacked, fmt.tprintf("from 8.0 kg up to %.2f kg, lowest after that %.2f kg, protein %.0f%%", most, least_after, p.need[.Protein]))

	// Everything he burns is counted under what it went on.
	fresh()
	g.enemy_count = 0
	g.round_count = 0
	p.pos = {-60, -10}
	p.need[.Carbs] = 60
	before := game.energy_kg()
	step(1800, {.Right})
	counted: f32
	for kg in g.burned {
		counted += kg
	}
	lost := before - game.energy_kg()
	check("what he burns is counted by what it went on", g.burned[.Walking] > 0.3 && g.burned[.Muscle] > 0.05 && g.burned[.Fighting] == 0 && abs(counted - lost) < 0.15, fmt.tprintf("half a minute's walk: walking %.2f kg, muscle %.2f kg, counted %.2f kg, fat and carbs down %.2f kg", g.burned[.Walking], g.burned[.Muscle], counted, lost))

	// A test that asks for a weight gets it, whatever else it asks for.
	g.opts = {no_save = true, start_kg = 66, has_needs = true, needs = {95, 95, 90, 95, 50, 50}, has_traits = true, traits = {1, 1, 0.8, 1, 0.5, 0.3, 0.6, 0.6, 0.6}}
	game.scene = .Playing
	game.new_game()
	check("a test that asks for a weight gets that weight", abs(p.kg - 66) < 0.05 && abs(parts_kg() - 66) < 0.05, fmt.tprintf("asked for 66 kg with full stores and big muscles: %.1f kg", p.kg))
}

// Animal health, throws, flocks, bruises and milking by salt.
rules_fighting :: proc() {
	section("fighting")
	g := &game.g
	p := &g.prosio

	// Grabs the animal put before him and holds F for so many frames before
	// letting go. Says how fast it left his hands (0 if he just put it down).
	hold_and_let_go :: proc(e: ^game.Enemy, frames: int) -> (speed: f32) {
		p := &game.g.prosio
		step(2, {}, {.Grab})
		step(12)
		if p.carry != .Enemy {
			return -1
		}
		step(frames, {.Grab}, {.Grab})
		for _ in 0 ..< 120 {
			step(1)
			if e.state == .Flying {
				return length(e.vel)
			}
			if p.carry == .Nothing {
				return 0
			}
		}
		return -1
	}
	alone :: proc(kg: f32, arms: f32) {
		fresh()
		game.g.enemy_count = 0
		game.g.round_count = 0
		game.g.prosio.pos = {20, 20}
		game.g.prosio.trait[.Arms] = arms
		game.set_weight(kg)
	}

	alone(80, 0)
	e := animal_before_him(.Turkey)
	speed := hold_and_let_go(e, 2)
	check("a tap of F puts an animal down unhurt", speed == 0 && p.carry == .Nothing && e.health == game.ENEMY_HEALTH && e.state != .Flying, fmt.tprintf("left at %.1f m/s, health %.0f, %v", speed, e.health, e.state))

	speeds: [3]f32
	for frames, i in ([3]int{15, 36, 70}) {
		alone(80, 0)
		speeds[i] = hold_and_let_go(animal_before_him(.Turkey), frames)
	}
	check("the longer F is held, the harder the throw", speeds[0] > 3 && speeds[1] > speeds[0] * 1.3 && speeds[2] > speeds[1] * 1.3, fmt.tprintf("held 0.25, 0.6 and 1.2 s: %.1f, %.1f and %.1f m/s", speeds[0], speeds[1], speeds[2]))

	// How many full throws finish a turkey.
	throws_for :: proc(kg, arms: f32) -> (throws: int, first: f32) {
		alone(kg, arms)
		p := &game.g.prosio
		e := animal_before_him(.Turkey)
		for throws < 12 && !e.ko {
			e.state, e.vel, e.y, e.scared_t, e.hurt_t = .Chase, {}, 0, 0, 0
			e.pos = p.pos + {0, game.prosio_radius(p.kg) + game.ENEMY_RADIUS[.Turkey] + 0.3}
			p.facing, p.stamina = 0, 100
			was := e.health
			if hold_and_let_go(e, 70) <= 0 {
				break
			}
			throws += 1
			if throws == 1 {
				first = was - e.health
			}
		}
		return
	}
	start, start_first := throws_for(80, 0)
	strong, strong_first := throws_for(110, 1)
	check("no single throw finishes a healthy turkey", start >= 3 && start <= 4 && strong >= 2, fmt.tprintf("the pig he starts as: %d throws (the first took %.0f of 100); 110 kg with the strongest arms: %d (%.0f)", start, start_first, strong, strong_first))

	alone(80, 0)
	e = animal_before_him(.Turkey)
	game.hurt_enemy(e, 60)
	p.pos = {-40, 30} // out of its sight
	step(60 * 5)
	early := e.health
	step(60 * 40)
	check("a hurt animal mends when it is left alone", early < 41 && e.health > 70, fmt.tprintf("health 40 after the blow, %.0f five seconds on, %.0f after 45", early, e.health))

	// Bold or wary, by how dangerous he is.
	alone(40, -1)
	bold_weak, scatter_weak := game.boldness(.Turkey), 0
	for _ in 0 ..< 20 {
		g.enemy_count = 0 // (the same pig each time, so that each trial draws its own luck)
		for i in 0 ..< 6 {
			game.add_enemy(.Turkey, p.pos + game.facing_dir(f32(i)) * 4)
		}
		game.hurt_enemy(&g.enemies[0], 30)
		for &o in g.enemies[1:g.enemy_count] {
			scatter_weak += o.scared_t > 0 ? 1 : 0
		}
	}
	alone(110, 1)
	bold_strong, wary_strong, scatter_strong := game.boldness(.Turkey), game.wariness(.Turkey), 0
	for _ in 0 ..< 20 {
		g.enemy_count = 0
		for i in 0 ..< 6 {
			game.add_enemy(.Turkey, p.pos + game.facing_dir(f32(i)) * 4)
		}
		game.hurt_enemy(&g.enemies[0], 30)
		for &o in g.enemies[1:g.enemy_count] {
			scatter_strong += o.scared_t > 0 ? 1 : 0
		}
	}
	alone(80, 0)
	check("a weak pig makes them bold, a strong one wary", bold_weak > 0.9 && bold_strong == 0 && game.boldness(.Turkey) == 0 && wary_strong > 0.5, fmt.tprintf("boldness towards a 40 kg pig with wasted arms %.2f, the pig he starts as %.2f, 110 kg with the strongest arms %.2f (wariness %.2f)", bold_weak, game.boldness(.Turkey), bold_strong, wary_strong))
	check("when one is hurt, a strong pig's flock scatters and a weak pig's does not", scatter_strong > 80 && scatter_weak < 15, fmt.tprintf("of 100 flockmates: %d ran from the strong pig, %d from the weak one", scatter_strong, scatter_weak))

	// Far from home they give up.
	alone(80, 0)
	game.add_enemy(.Turkey, p.pos + {3, 0})
	e = &g.enemies[0]
	furthest: f32
	for _ in 0 ..< 60 * 50 {
		p.pos.x -= 2.4 / 60 // he walks off, slowly enough to be followed all the way
		p.bruises = 0
		step(1)
		furthest = max(furthest, length(e.pos - e.home))
	}
	check("an animal gives up the chase far from its home", furthest > game.LEASH[.Turkey] - 3 && furthest < game.LEASH[.Turkey] + 3, fmt.tprintf("followed him %.0f m from home at the most; he went 120 m", furthest))

	// A knock bruises; it does not take weight.
	alone(80, 0)
	for i in 0 ..< 6 {
		game.add_enemy(.Turkey, p.pos + game.facing_dir(f32(i)) * 3)
	}
	kg := p.fat + game.store_kg(.Carbs)
	knocks := 0
	was := p.bruises
	frames := 0
	for knocks < 3 && frames < 60 * 60 {
		step(1)
		frames += 1
		if p.bruises > was {
			knocks += 1
		}
		was = p.bruises
	}
	lost := kg - (p.fat + game.store_kg(.Carbs))
	resting := game.BASAL * game.part_kg(.Muscle) * f32(frames) / 60
	check("a knock leaves a bruise and takes no weight", knocks == 3 && p.bruises > 4 && lost < resting * 1.2 + 0.02 && game.stamina_top() < game.STAMINA_MAX, fmt.tprintf("3 knocks: %.1f points of bruises, top of his stamina %.0f, fat and carbs down %.3f kg (his muscle alone burned %.3f)", p.bruises, game.stamina_top(), lost, resting))

	g.enemy_count = 0
	before := p.bruises
	step(60 * 60)
	check("bruises mend when he is left alone", p.bruises < before - 5, fmt.tprintf("%.1f points, %.1f a minute later", before, p.bruises))

	alone(80, 0)
	game.bruise(500)
	top := game.stamina_top()
	step(2)
	beaten := p.fail == .Beaten
	step(70)
	step(1, {}, {.Restart})
	step(5)
	check("bruises never take more than three quarters of his stamina; bruised that far he is knocked out and wakes at home", abs(top - game.STAMINA_MAX * game.BRUISE_FLOOR) < 0.01 && beaten && p.fail == .None && p.bruises == 0, fmt.tprintf("top of his stamina %.0f, then %v; after waking: bruises %.0f", top, beaten ? "knocked out" : "still up", p.bruises))

	// Milking by salt.
	alone(80, 0)
	p.need[.Electrolytes] = 95
	e = animal_before_him(.Goat)
	licking := false
	for _ in 0 ..< 180 {
		p.need[.Electrolytes] = 95
		step(1)
		licking ||= e.licking
	}
	step(1, {}, {.Action})
	step(5)
	check("a salty pig can milk the goat that licks him, without grabbing it", licking && p.sack[.Milk] == 1 && p.carry == .Nothing && e.milk_t > 0, fmt.tprintf("licked %v, milk %d, carrying %v", licking, p.sack[.Milk], p.carry))

	// An animal before a rock.
	alone(80, 0)
	game.add_round(p.pos + {0, game.prosio_radius(p.kg) + 0.32}, 0.3, .Rock)
	e = animal_before_him(.Turkey)
	e.pos = p.pos + {game.prosio_radius(p.kg) + game.ENEMY_RADIUS[.Turkey] + 0.6, 0}
	step(2, {}, {.Grab})
	check("with an animal and a rock both in reach, F takes the animal", p.carry == .Enemy, fmt.tprintf("carrying %v", p.carry))
}

// Pebbles, thrown stones, aiming, and what they do to animals and crows.
rules_stones :: proc() {
	section("stones")
	g := &game.g
	p := &g.prosio
	alone :: proc() {
		fresh()
		game.g.enemy_count = 0
		game.g.round_count = 0
		game.g.prosio.pos = {20, 20}
		game.g.prosio.facing = 0
	}
	// Winds up for so many frames with hands free and lets go; then lets the stone fly.
	throw :: proc(frames: int, after := 90) {
		step(frames, {.Grab}, {.Grab})
		step(after)
	}
	pebbles :: proc(n: int) {
		for _ in 0 ..< n {
			game.sack_add(.Pebble, 0)
		}
		game.g.prosio.sack_sel = .Pebble
	}

	fresh()
	patches, hidden := 0, 0
	first := -1
	for rd, i in g.rounds[:g.round_count] {
		if rd.kind == .Pebbles {
			patches += 1
			hidden += game.hidden_by_tree(rd.pos) || game.in_field(rd.pos, 0.5) ? 1 : 0
			if first < 0 {
				first = i
			}
		}
	}
	check("there are patches of pebbles about the meadow, none hidden by a tree or in a field", patches == 9 && hidden == 0, fmt.tprintf("%d patches, %d hidden", patches, hidden))

	g.enemy_count = 0
	patch := &g.rounds[first]
	p.pos = patch.pos + {0, 0.9}
	step(2, {}, {.Action})
	step(90)
	got, left := p.sack[.Pebble], patch.fruit
	p.sack_sel = .Pebble
	kg := p.kg
	step(2, {}, {.Eat})
	step(20)
	check("pebbles come by the handful, weigh nothing in him and cannot be eaten", got == game.PEBBLE_HANDFUL && left == game.MAX_PEBBLES - game.PEBBLE_HANDFUL && p.sack[.Pebble] == got && abs(p.kg - kg) < 0.05, fmt.tprintf("%d in the sack, %d left on the patch; after trying to eat one: %d", got, left, p.sack[.Pebble]))

	alone()
	light, small, big := game.stone_speed(game.PEBBLE_KG), game.stone_speed(10), game.stone_speed(82)
	p.trait[.Arms] = 1
	strong := game.stone_speed(10)
	check("the lighter the stone, the faster it leaves his hoof, and strong arms throw faster", light > small * 1.5 && small > big * 2 && strong > small * 1.2 && light <= game.ARM_SPEED + 0.01, fmt.tprintf("a pebble %.0f, a 10 kg rock %.1f, an 82 kg rock %.1f m/s; the 10 kg rock with the strongest arms %.1f", light, small, big, strong))

	alone()
	pebbles(5)
	game.add_enemy(.Turkey, p.pos + {0, 6})
	e := &g.enemies[0]
	e.timer = 100 // it stands where it is
	flew := false
	step(40, {.Grab}, {.Grab})
	aimed := p.aim.kind == .Enemy
	for _ in 0 ..< 90 {
		step(1)
		flew ||= e.state == .Flying
	}
	check("a pebble stings a turkey and sends it off, without knocking it over", aimed && p.sack[.Pebble] == 4 && e.health < game.ENEMY_HEALTH && e.health > game.ENEMY_HEALTH - 10 && !flew && e.scared_t > 0, fmt.tprintf("aimed at it %v, health %.1f, knocked over %v, running for %.1f s more, %d pebbles left", aimed, e.health, flew, max(e.scared_t, 0), p.sack[.Pebble]))

	alone()
	pebbles(3)
	game.add_enemy(.Fox, p.pos + {0, 5})
	e = &g.enemies[0]
	e.home = e.pos + {0, 60}
	e.has_loot, e.loot, e.loot_kcal = true, .Apple, 95
	e.timer = 100
	throw(30)
	check("a pebble makes a fox drop what it stole", !e.has_loot && p.sack[.Apple] == 1, fmt.tprintf("fox still has it %v, apples in the sack %d", e.has_loot, p.sack[.Apple]))

	alone()
	pebbles(3)
	game.add_enemy(.Turkey, p.pos + {0, 5})
	game.add_enemy(.Turkey, p.pos + {5, 0})
	g.enemies[0].timer, g.enemies[1].timer = 100, 100
	step(10, {.Grab}, {.Grab})
	first_aim := p.aim
	step(10, {.Grab, .Right}, {.Right})
	second_aim := p.aim
	facing := game.facing_dir(p.facing)
	step(60)
	check("winding up he aims at what is in front, and a direction button moves the aim that way", first_aim == game.Aim{.Enemy, 0} && second_aim == game.Aim{.Enemy, 1} && facing.x > 0.9 && g.enemies[1].health < game.ENEMY_HEALTH && g.enemies[0].health == game.ENEMY_HEALTH && length(p.pos - {20, 20}) < 0.3, fmt.tprintf("first %v, after RIGHT %v, facing (%.1f, %.1f); health of the two: %.0f and %.1f; he moved %.2f m", first_aim, second_aim, facing.x, facing.y, g.enemies[0].health, g.enemies[1].health, length(p.pos - {20, 20})))

	// A crow at the wheat, eight metres off.
	fresh()
	g.enemy_count = 0
	wheat := -1
	for &f, i in g.foods[:g.food_count] {
		if f.kind == .Wheat && game.food_ready(&f) {
			wheat = i
			break
		}
	}
	crow := &g.pests[2]
	crow.state, crow.food, crow.t, crow.y = .Eating, wheat, 14, 0.45
	crow.pos = g.foods[wheat].pos
	p.pos = crow.pos + {0, -8}
	p.facing = 0
	pebbles(3)
	step(30, {.Grab}, {.Grab})
	at_crow := p.aim.kind == .Pest
	step(60)
	check("a pebble sends a crow off the wheat, to stay away longer", at_crow && crow.state == .Fleeing && crow.stoned, fmt.tprintf("aimed at it %v, crow %v, driven off with a stone %v", at_crow, crow.state, crow.stoned))

	// A rock, lifted and thrown at a turkey.
	alone()
	game.add_round(p.pos + {0, game.prosio_radius(p.kg) + 0.35}, 0.3, .Rock)
	step(2, {}, {.Grab})
	step(80)
	carrying := p.carry == .Rock
	game.add_enemy(.Turkey, p.pos + {0, 4})
	e = &g.enemies[0]
	e.timer = 100
	flew = false
	step(70, {.Grab}, {.Grab})
	for _ in 0 ..< 120 {
		step(1)
		flew ||= e.state == .Flying
	}
	check("a thrown rock bowls a turkey over and hurts it more than a pebble", carrying && p.carry == .Nothing && flew && e.health < game.ENEMY_HEALTH - 15 && !e.ko, fmt.tprintf("lifted %v, turkey knocked over %v, health %.0f", carrying, flew, e.health))

	// A pig saved before there were pebbles.
	fresh()
	g.opts.no_save = false
	old := new(game.Save_3)
	old.version, old.size, old.fat = 3, size_of(game.Save_3), 52
	old.need = p.need
	old.sack[int(game.Item.Honey)] = 2
	old.sack[int(game.Item.Apple_Pie) - 1] = 1 // where the pie was, one place earlier
	old.sack_sel = u8(int(game.Item.Bread) - 1)
	game.store_write(([^]u8)(old)[:size_of(game.Save_3)])
	fresh()
	g.opts.no_save = false
	loaded := game.load_game()
	check("a Prosio saved before there were pebbles is carried over", loaded && abs(p.fat - 52) < 0.01 && p.sack[.Honey] == 2 && p.sack[.Apple_Pie] == 1 && p.sack[.Pebble] == 0 && p.sack_sel == .Bread, fmt.tprintf("loaded %v, fat %.0f, honey %d, apple pie %d, pebbles %d, chosen %v", loaded, p.fat, p.sack[.Honey], p.sack[.Apple_Pie], p.sack[.Pebble], p.sack_sel))
	g.opts.no_save = true
	free(old)

	// A pig saved before gates and the three kitchen skills: his one cooking
	// skill becomes all three, and his fences come back.
	fresh()
	g.opts.no_save = false
	old5 := new(game.Save_5)
	old5.version, old5.size, old5.fat = 5, size_of(game.Save_5), 44
	old5.need = p.need
	old5.trait[6] = 0.6 // cooking
	old5.trait[1] = 0.3 // legs
	old5.sack[int(game.Item.Fence)] = 2
	old5.sack_kcal[int(game.Item.Honey)] = 300
	old5.sack[int(game.Item.Honey)] = 1
	old5.knows[int(game.Item.Fence)] = true
	old5.fence_count = 1
	old5.fences[0] = {50, 30, 1}
	game.store_write(([^]u8)(old5)[:size_of(game.Save_5)])
	fresh()
	g.opts.no_save = false
	loaded = game.load_game()
	check("a Prosio saved before gates is carried over: his cooking skill is all three kitchen skills now", loaded && abs(p.fat - 44) < 0.01 && p.trait[.Legs] == 0.3 && p.trait[.Baking] == 0.6 && p.trait[.Grilling] == 0.6 && p.trait[.Dairy] == 0.6 && p.sack[.Fence] == 2 && p.sack[.Honey] == 1 && p.knows[.Gate] && g.fence_count == 1 && game.gate_state({50, 30, .South}) == 0, fmt.tprintf("loaded %v, fat %.0f, legs %.2f, baking %.2f grilling %.2f dairy %.2f, fence %d, knows the gate %v, fences %d", loaded, p.fat, p.trait[.Legs], p.trait[.Baking], p.trait[.Grilling], p.trait[.Dairy], p.sack[.Fence], p.knows[.Gate], g.fence_count))
	g.opts.no_save = true
	free(old5)
}

// His weight is the sum of his parts, always.
rules_weight :: proc() {
	section("weight is the sum of his parts")
	g := &game.g
	p := &g.prosio
	fresh()
	check("a new Prosio weighs 80 kg, the sum of his parts", abs(p.kg - 80) < 0.01 && abs(parts_kg() - p.kg) < 0.001, fmt.tprintf("%.2f kg, parts %.2f", p.kg, parts_kg()))

	// Each food puts on exactly what it weighs.
	worst: f32
	worst_item: game.Item
	for item in game.Item {
		if !game.edible(item) {
			continue
		}
		fresh()
		g.enemy_count = 0
		before := game.body_kg()
		m := game.item_meal(item, game.item_kcal(item))
		game.eat(m)
		off := abs((game.body_kg() - before) - game.meal_kg(m))
		if off > worst {
			worst, worst_item = off, item
		}
	}
	check("every food adds exactly what it weighs to a fresh Prosio", worst < 0.02, fmt.tprintf("worst %v, off by %.3f kg", worst_item, worst))

	// A food's composition is shares of its calories, adding up to 100; and
	// a piece puts into him just those shares of its calories.
	worst = 0
	sums_wrong := 0
	for item in game.Item {
		if !game.is_food(item) {
			continue
		}
		c := game.composition(item)
		total: f32
		for share in c {
			total += share
		}
		if abs(total - 100) > 0.01 {
			sums_wrong += 1
		}
		m := game.item_meal(item, game.item_kcal(item))
		back := (m.carbs + m.fat + m.protein) * game.KCAL_PER_KG + m.fibre * game.FIBRE_KCAL + m.vitamins * game.VITAMIN_KCAL + m.salts * game.SALT_KCAL
		off := abs(back - game.item_kcal(item))
		if off > worst {
			worst, worst_item = off, item
		}
	}
	check("every food is made of shares of its calories that add up to 100%, and puts all of them into him", sums_wrong == 0 && worst < 1, fmt.tprintf("%d foods' shares do not add up; worst %v, off by %.1f kcal", sums_wrong, worst_item, worst))

	// Half the calories, half of everything; and nothing it is not made of.
	whole := game.item_meal(.Cabbage, 250)
	half := game.item_meal(.Cabbage, 125)
	fish := game.item_meal(.Fish, 200)
	check("a piece half as rich puts in half of each thing, and a food puts in nothing it is not made of", abs(half.fibre * 2 - whole.fibre) < 0.001 && abs(half.vitamins * 2 - whole.vitamins) < 0.01 && abs(half.carbs * 2 - whole.carbs) < 0.001 && fish.carbs == 0 && fish.fibre == 0, fmt.tprintf("cabbage, whole and half: fibre %.3f and %.3f kg, vitamins %.1f and %.1f; fish: carbs %.3f, fibre %.3f", whole.fibre, half.fibre, whole.vitamins, half.vitamins, fish.carbs, fish.fibre))

	// A sack of three apples worth 150, 100 and 50: one eaten is worth the
	// average, 100.
	fresh()
	for kcal in ([3]f32{150, 100, 50}) {
		game.sack_add(.Apple, kcal)
	}
	one := game.sack_piece_kcal(.Apple)
	ate := game.sack_take(.Apple, 1)
	check("the sack keeps the calories of each kind of food all together: a piece taken out is worth the average", one == 100 && ate == 100 && p.sack_kcal[.Apple] == 200, fmt.tprintf("a piece is shown as %.0f kcal, one taken out held %.0f, %.0f left in two", one, ate, p.sack_kcal[.Apple]))

	// The sack holds 30 litres, whatever is in it; what is in it he carries.
	fresh()
	g.enemy_count = 0
	room := game.sack_room(.Pumpkin)
	for _ in 0 ..< room {
		game.sack_add(.Pumpkin, 400)
	}
	check("the sack holds 30 litres: five pumpkins fill it, or two hundred mushrooms", room == 5 && game.sack_room(.Mushroom) == 0 && game.sack_room(.Apple) == 0 && abs(game.total_kg() - p.kg - 20) < 0.01, fmt.tprintf("room for %d pumpkins; then for %d mushrooms; carrying %.1f kg", room, game.sack_room(.Mushroom), game.total_kg() - p.kg))

	// A load costs and trains: ten seconds' walk empty-handed, then with 16
	// kg of wood on his back.
	walk :: proc(logs: int) -> (burned, legs: f32) {
		g := &game.g
		fresh()
		g.enemy_count = 0
		g.round_count = 0
		g.prosio.pos = {20, 20}
		for _ in 0 ..< logs {
			game.sack_add(.Wood, 0)
		}
		before := g.burned[.Walking]
		step(600, {.Right})
		return g.burned[.Walking] - before, g.prosio.trait[.Legs]
	}
	burn_light, legs_light := walk(0)
	burn_heavy, legs_heavy := walk(8)
	check("walking with a load of a fifth of his weight burns a fifth more, and trains his legs faster", burn_heavy > burn_light * 1.15 && burn_heavy < burn_light * 1.25 && legs_heavy > legs_light * 1.4, fmt.tprintf("burned walking %.3f kg empty, %.3f kg with 16 kg; legs %.4f and %.4f", burn_light, burn_heavy, legs_light, legs_heavy))

	// Protein makes no carbs: not as it is eaten, with his protein full,
	// and not as it is used up.
	fresh()
	g.enemy_count = 0
	p.need[.Protein] = 100
	p.need[.Carbs] = 50
	carbs := game.store_kg(.Carbs)
	for item in ([?]game.Item{.Roast, .Grilled_Fish, .Fried_Egg, .Cheese, .Butter}) {
		feed(item)
	}
	eaten := game.store_kg(.Carbs) - carbs
	p.need[.Protein] = 90
	faded: f32
	for _ in 0 ..< 60 * 60 {
		p.need[.Carbs] = 50 // the same each frame, to see whether any come in
		before_fade := game.store_kg(.Carbs)
		game.update_diet(1.0 / 60)
		faded += game.store_kg(.Carbs) - before_fade
	}
	check("protein foods put next to no carbs into him, and protein never turns into carbs", eaten < 0.15 && abs(faded) < 0.001, fmt.tprintf("a roast, a grilled fish, a fried egg, a cheese and a butter added %.2f kg of carbs; a minute of protein being used up added %.3f kg", eaten, faded))

	// A busy quarter of an hour.
	fresh()
	g.enemy_count = 0
	g.round_count = 0
	foods := [?]game.Item{.Roast, .Bread, .Cabbage, .Fried_Egg, .Pumpkin, .Nuts, .Apple_Pie, .Salt, .Milk, .Grilled_Fish}
	most: f32
	for sec in 0 ..< 900 {
		p.pos = {0, 20}
		if sec % 40 == 0 {
			feed(foods[(sec / 40) % len(foods)])
		}
		if sec % 300 == 299 {
			p.need[.Water] = 100
		}
		step(60, sec % 7 < 3 ? {.Right, .Sprint} : {.Left})
		most = max(most, abs(parts_kg() - p.kg))
	}
	check("weight stays the sum of his parts through 15 busy minutes", most < 0.001, fmt.tprintf("most apart %.4f kg", most))
}

// F always lets go of an animal, at once.
rules_release :: proc() {
	section("letting go")
	g := &game.g
	p := &g.prosio
	Shape :: enum {Alive, Dizzy, Dead}
	stuck, cases := 0, 0
	first: string
	for kind in game.Enemy_Kind {
		for shape in Shape {
			if shape == .Dead && kind == .Fox {
				continue // a fox is never left dead
			}
			for stamina in ([?]f32{100, 40, 15, 6}) {
				for wait in ([?]int{20, 90}) {
					for moving in ([?]bool{false, true}) {
						fresh()
						g.enemy_count = 0
						g.round_count = 0
						p.pos = {20, 20}
						e := animal_before_him(kind)
						switch shape {
						case .Alive:
						case .Dizzy:
							e.state, e.timer = .Dizzy, 5
						case .Dead:
							e.state, e.ko, e.body_t = .Dead, true, 200
						}
						step(2, {}, {.Grab})
						if p.carry != .Enemy {
							continue
						}
						p.stamina = stamina
						down: bit_set[game.Button] = moving ? {.Down} : {}
						step(wait, down)
						if p.carry == .Nothing {
							continue // it got away first
						}
						cases += 1
						step(1, down, {.Grab})
						frames := 0
						for p.carry != .Nothing && frames < 180 {
							step(1, down)
							frames += 1
						}
						if frames > 60 {
							stuck += 1
							if first == "" {
								first = fmt.tprintf("%v %v, stamina %.0f", kind, shape, stamina)
							}
						}
					}
				}
			}
		}
	}
	check("F lets go within a second, for every animal, state and stamina", stuck == 0, fmt.tprintf("%d of %d stuck%s", stuck, cases, first != "" ? fmt.tprintf(", first: %s", first) : ""))

	fresh()
	g.enemy_count = 0
	g.round_count = 0
	p.pos = {20, 20}
	animal_before_him(.Fox)
	step(2, {}, {.Grab})
	step(20)
	frames := 0
	for p.carry != .Nothing && frames < 300 {
		step(1, {}, frames % 6 == 0 ? {.Grab} : {})
		frames += 1
	}
	check("pressing F over and over does not hold up a throw", frames < 36, fmt.tprintf("let go after %.2f s", f32(frames) / 60))

	// A rock, too.
	fresh()
	g.enemy_count = 0
	g.round_count = 0
	p.pos = {20, 20}
	p.facing = 0
	game.add_round(p.pos + {0, game.prosio_radius(p.kg) + 0.6}, 0.45, .Rock)
	step(2, {}, {.Grab})
	held := p.carry == .Rock
	step(40)
	step(1, {}, {.Grab})
	step(60)
	check("a lifted rock is thrown with F", held && p.carry == .Nothing)
}

// The diet is forgiving: too much never kills; only running right out does.
rules_diet :: proc() {
	section("diet")
	g := &game.g
	p := &g.prosio
	binges := [?]game.Item{.Bread, .Egg, .Salt, .Berries, .Cabbage, .Butter, .Roast, .Honey, .Cheese}
	deaths: [dynamic]string
	for item in binges {
		fresh()
		g.enemy_count = 0
		for sec in 0 ..< 600 {
			if sec < 240 && sec % 12 == 0 {
				game.eat(game.item_meal(item, game.item_kcal(item))) // twenty in four minutes, raw or not
			}
			p.fat = 45
			p.need[.Water] = max(p.need[.Water], 40)
			step(60)
		}
		if p.fail != .None {
			append(&deaths, fmt.tprintf("%v", item))
		}
	}
	check("twenty of any one food in four minutes never ends the game", len(deaths) == 0, fmt.tprintf("%v", deaths[:]))

	fresh()
	g.enemy_count = 0
	minute := 0
	for minute < 30 && p.fail == .None {
		for _ in 0 ..< 60 {
			p.need[.Water] = 80
			step(60)
		}
		minute += 1
	}
	check("eating nothing (but drinking), he lasts at least 30 minutes", p.fail == .None, fmt.tprintf("game over after %d min: %v", minute, p.fail))

	fresh()
	g.enemy_count = 0
	p.need[.Vitamins] = 0
	step(60 * 60)
	alive_a_minute := p.fail == .None
	step(60 * 150)
	check("with no vitamins the countdown takes 3 minutes", alive_a_minute && p.fail == .Diet, fmt.tprintf("after 1 min %v, after 3.5 min %v", alive_a_minute, p.fail))

	fresh()
	g.enemy_count = 0
	p.need[.Water] = 50
	p.need[.Electrolytes] = 97
	p.pos = game.POND + {0, game.POND_RADIUS + 0.3}
	step(30, {.Up})
	step(1, {}, {.Action})
	step(30)
	check("a drink at the pond washes out too much salt", !game.too_much(.Electrolytes) && p.need[.Water] > 90)
}

// A muscular pig burns more; carbs go before fat; with neither he faints.
rules_energy :: proc() {
	section("energy")
	g := &game.g
	p := &g.prosio
	burned: [3]f32
	levels := [3]f32{-1, 0, 1}
	for level, i in levels {
		fresh()
		g.enemy_count = 0
		for _ in 0 ..< 600 {
			p.trait[.Arms], p.trait[.Legs] = level, level
			p.need[.Water] = 80
			before := p.fat + game.store_kg(.Carbs)
			step(60)
			burned[i] += before - (p.fat + game.store_kg(.Carbs))
		}
	}
	check("the more muscle, the more he burns at rest", burned[0] < burned[1] && burned[1] < burned[2], fmt.tprintf("wasted %.2f, ordinary %.2f, most muscle %.2f kg in 10 min", burned[0], burned[1], burned[2]))

	fresh()
	g.enemy_count = 0
	g.round_count = 0
	fat := p.fat
	for _ in 0 ..< 20 {
		p.pos = {0, 20}
		p.stamina = 100
		p.winded = false
		step(60, {.Right, .Sprint})
	}
	check("sprinting takes carbs before fat", p.fat == fat && game.store_kg(.Carbs) < 3, fmt.tprintf("fat %.2f -> %.2f, carbs 3 -> %.2f kg", fat, p.fat, game.store_kg(.Carbs)))

	fresh()
	g.enemy_count = 0
	p.fat = 0
	p.need[.Carbs] = 100
	step(60 * 60 * 5)
	check("with no fat he lives on his carbs", p.fail == .None, fmt.tprintf("after 5 min %v, carbs %.1f kg", p.fail, game.store_kg(.Carbs)))

	fresh()
	g.enemy_count = 0
	p.fat = 0
	p.need[.Carbs] = 0
	p.need[.Protein] = 0
	step(10)
	check("with no fat and no carbs he faints", p.fail == .Fainted, fmt.tprintf("%v", p.fail))
}

// Trees keep out of the way, and food stays within its budget.
rules_world :: proc() {
	section("the meadow")
	for seed in ([?]u32{0, 11, 23}) {
		fresh(seed)
		g := &game.g
		hidden := 0
		what: string
		for rd in g.rounds[:g.round_count] {
			if rd.kind != .Tree && rd.kind != .Rock && game.hidden_by_tree(rd.pos) {
				hidden += 1
				what = fmt.tprintf("%v at %.0f %.0f", rd.kind, rd.pos.x, rd.pos.y)
			}
		}
		for &f in g.foods[:g.food_count] {
			if !f.gone && game.hidden_by_tree(f.pos) {
				hidden += 1
				what = fmt.tprintf("%v at %.0f %.0f", f.kind, f.pos.x, f.pos.y)
			}
		}
		for kind in game.Region_Kind {
			if kind == .Home {
				continue
			}
			to := game.PATH_ENDS[kind]
			n := int(length(to))
			for i in 0 ..= n {
				q := to * (f32(i) / f32(n))
				if game.hidden_by_tree(q) {
					hidden += 1
					what = fmt.tprintf("the path to %v", kind)
				}
			}
		}
		check(fmt.tprintf("meadow %d: no tree in front of paths, buildings or food", seed), hidden == 0, hidden > 0 ? fmt.tprintf("%d, e.g. %s", hidden, what) : "")

		astray := 0
		for f in g.foods[:g.food_count] {
			want: game.Region_Kind = .Forest
			#partial switch f.kind {
			case .Wheat:
				want = .Fields
			case .Pumpkin, .Cabbage:
				want = .Garden
			case .Egg, .Apple:
				continue // eggs go where the turkeys go; apples fall round their tree
			}
			if r, ok := game.region_at(f.pos); !ok || r != want {
				astray += 1
			}
		}
		check(fmt.tprintf("meadow %d: each food grows in its own part of the meadow", seed), astray == 0, fmt.tprintf("%d astray", astray))

		// The forest: trees all through it, none crowding the next, and its
		// clearings open.
		trees, crowded, in_clearings := 0, 0, 0
		for a, i in g.rounds[:g.round_count] {
			if a.kind != .Tree || a.species == .Apple || game.inside_region(a.pos, .Forest) <= 0 {
				continue
			}
			trees += 1
			if game.in_clearing(a.pos, 0) {
				in_clearings += 1
			}
			for b, j in g.rounds[:g.round_count] {
				if j > i && b.kind == .Tree && game.inside_region(b.pos, .Forest) > 0 && length(a.pos - b.pos) < game.FOREST_SPACING - 0.01 {
					crowded += 1
				}
			}
		}
		check(fmt.tprintf("meadow %d: the forest has trees all through it, each apart from the next, and open clearings", seed), trees >= 150 && crowded == 0 && in_clearings == 0, fmt.tprintf("%d forest trees, %d pairs too close, %d in a clearing", trees, crowded, in_clearings))
	}

	// Twelve minutes of growing: nothing over its budget.
	fresh()
	g := &game.g
	g.prosio.pos = {0, 60}
	worst: f32
	worst_item: game.Item
	for _ in 0 ..< 12 {
		step(60 * 60)
		g.prosio.fat = 45
		kcal: [game.Item]f32
		for &f in g.foods[:g.food_count] {
			if game.food_ready(&f) && f.kind != .Egg {
				kcal[game.FOOD_ITEM[f.kind]] += game.food_kcal(&f)
			}
		}
		for &r in g.rounds[:g.round_count] {
			if r.kind == .Bush {
				kcal[.Berries] += f32(r.fruit) * game.bush_kcal(&r)
			}
			if r.kind == .Tree && r.species == .Apple {
				kcal[.Apple] += f32(r.fruit) * game.RAW_KCAL[.Apple] * game.ripeness(r.ripe)
			}
		}
		for k, item in kcal {
			budget := item == .Mushroom ? game.MUSHROOM_BUDGET : game.FOOD_BUDGET
			if k / budget > worst {
				worst, worst_item = k / budget, item
			}
		}
	}
	check("no food ever stands at more than its budget (allowing for size)", worst <= 1 + game.SIZE_SPREAD, fmt.tprintf("most: %v at %.0f%% of its budget", worst_item, worst * 100))
	eggs := game.eggs_lying()
	check("eggs lying about stay under their cap", eggs <= game.MAX_EGGS, fmt.tprintf("%d", eggs))

	fresh()
	salt := 0
	for rd in game.g.rounds[:game.g.round_count] {
		if rd.kind == .Salt_Rock && rd.fruit > 0 {
			salt += 1
		}
	}
	check("the goat hills have salt rocks with salt on them", salt == game.SALT_ROCKS, fmt.tprintf("%d of %d", salt, game.SALT_ROCKS))
}

// What is made where, and what it is worth.
rules_kitchen :: proc() {
	section("kitchen")
	g := &game.g
	p := &g.prosio
	fresh()
	g.enemy_count = 0
	for _ in 0 ..< 4 {
		game.sack_add(.Wheat, 300)
	}
	p.sack_sel = .Wheat
	step(1, {}, {.Eat})
	step(10)
	check("wheat cannot be eaten", p.sack[.Wheat] == 4)

	p.pos = g.mill.pos + {0, game.MILL_RADIUS + 1.1}
	step(1, {}, {.Action})
	step(60 * 11)
	step(1, {}, {.Action})
	step(40)
	check("the mill grinds wheat into flour", p.sack[.Flour] == 4 && abs(p.sack_kcal[.Flour] - 1200) < 1, fmt.tprintf("%d flour, %.0f kcal", p.sack[.Flour], p.sack_kcal[.Flour]))

	cook(.Oven, .Bread, 1)
	game.scene = .Playing
	check("the oven bakes nothing without wood", p.sack[.Bread] == 0 && p.sack[.Flour] == 4 && !g.stations[.Oven].baking, fmt.tprintf("%d bread, %d flour left", p.sack[.Bread], p.sack[.Flour]))
	for _ in 0 ..< 3 {
		game.sack_add(.Wood, 0)
	}
	cook(.Oven, .Bread, 1)
	check("a beginner baker's bread is worth 1.15 times its flour, and takes a log to bake", p.sack[.Bread] == 1 && abs(p.sack_kcal[.Bread] - 690) < 1 && p.sack[.Wood] == 2, fmt.tprintf("%d bread, %.0f kcal, %d logs left of 3", p.sack[.Bread], p.sack_kcal[.Bread], p.sack[.Wood]))

	fresh()
	g.enemy_count = 0
	for _ in 0 ..< 3 {
		game.sack_add(.Egg, 130)
		game.sack_add(.Milk, 150)
	}
	p.sack_sel = .Egg
	step(1, {}, {.Eat})
	step(10)
	check("a raw egg cannot be eaten", p.sack[.Egg] == 3)
	game.sack_add(.Wood, 0)
	game.sack_add(.Wood, 0)
	cook(.Fire, .Fried_Egg, 2)
	check("the fire fries eggs, two at once, a log each", p.sack[.Fried_Egg] == 2 && p.sack[.Egg] == 1 && p.sack[.Wood] == 0, fmt.tprintf("%d fried, %d left, %d logs left of 2", p.sack[.Fried_Egg], p.sack[.Egg], p.sack[.Wood]))
	cook(.Churn, .Butter, 1)
	check("the churn makes butter of two jugs of milk, and needs no wood", p.sack[.Butter] == 1 && p.sack[.Milk] == 1)

	// Each place has its own skill: a beginner gets +15% at the oven and
	// nothing extra at the fire or the churn; a master +80%, +50% and +25%.
	fresh()
	beginner := [3]f32{game.cook_bonus(.Oven), game.cook_bonus(.Fire), game.cook_bonus(.Churn)}
	p.trait[.Baking], p.trait[.Grilling], p.trait[.Dairy] = 1, 1, 1
	master := [3]f32{game.cook_bonus(.Oven), game.cook_bonus(.Fire), game.cook_bonus(.Churn)}
	check("cooking skills go from +15% to +80% at the oven, +0% to +50% at the fire, +0% to +25% at the churn", abs(beginner[0] - 1.15) < 0.001 && beginner[1] == 1 && beginner[2] == 1 && abs(master[0] - 1.8) < 0.001 && abs(master[1] - 1.5) < 0.001 && abs(master[2] - 1.25) < 0.001, fmt.tprintf("beginner %.2f %.2f %.2f, master %.2f %.2f %.2f", beginner[0], beginner[1], beginner[2], master[0], master[1], master[2]))

	// Baking grows dish by dish, quickly at first; and what he knows how to
	// do does not fade, where his legs do.
	fresh()
	g.enemy_count = 0
	titles: [2]cstring
	titles[0] = game.cook_title(.Oven)
	for _ in 0 ..< 11 {
		game.train(.Baking, game.COOK_WORK)
	}
	half := p.trait[.Baking]
	titles[1] = game.cook_title(.Oven)
	p.trait[.Legs] = 0.5
	for _ in 0 ..< 60 * 60 * 20 {
		game.update_body(1.0 / 60)
	}
	check("eleven bakes take him half way to master baker; a cooking skill never fades, though his legs do", half > 0.45 && half < 0.55 && abs(p.trait[.Baking] - half) < 0.0001 && p.trait[.Legs] < 0.3 && titles[0] == "Beginner baker" && titles[1] == "Apprentice baker", fmt.tprintf("baking %.2f after 11, %.2f twenty minutes later; legs 0.50 to %.2f; called %s, then %s", half, p.trait[.Baking], p.trait[.Legs], titles[0], titles[1]))
}

// Animals do what they are for.
rules_animals :: proc() {
	section("animals")
	g := &game.g
	p := &g.prosio

	// Thrown into the pond: dropped in (unhurt) at a place, then left for a
	// minute. What became of it, and where it ended up.
	Wet :: struct {
		swam, drowned, ashore: bool,
		health:                f32,
	}
	dunk :: proc(kind: game.Enemy_Kind, from_middle: f32) -> (w: Wet) {
		g := &game.g
		fresh()
		g.enemy_count = 0
		g.prosio.pos = game.POND + {0, game.POND_RADIUS + 6}
		game.add_enemy(kind, game.POND + {from_middle, 0})
		e := &g.enemies[0]
		e.home = game.POND + {0, 30}
		game.launch_enemy(e, {1, 0}, 0.1, false)
		e.y = 0.5
		for _ in 0 ..< 60 * 60 {
			step(1)
			w.swam ||= e.state == .Swimming
		}
		w.drowned = e.ko
		w.ashore = !game.in_pond(e.pos) && e.state != .Swimming
		w.health = e.health
		return
	}
	far_turkey := dunk(.Turkey, 0)
	near_turkey := dunk(.Turkey, game.POND_RADIUS - 1.5)
	goat := dunk(.Goat, 0)
	wet_fox := dunk(.Fox, 0)
	check("thrown in the pond, an animal swims for the bank: a goat or a fox gets out, a turkey only from near the edge, and one that drowns floats ashore", far_turkey.swam && far_turkey.drowned && far_turkey.ashore && near_turkey.ashore && !near_turkey.drowned && goat.ashore && !goat.drowned && wet_fox.ashore && !wet_fox.drowned && wet_fox.health == game.ENEMY_HEALTH, fmt.tprintf("turkey from the middle: swam %v, drowned %v, ashore %v; from near the edge: drowned %v (health %.0f), ashore %v; goat: drowned %v (health %.0f), ashore %v; fox: health %.0f, ashore %v", far_turkey.swam, far_turkey.drowned, far_turkey.ashore, near_turkey.drowned, near_turkey.health, near_turkey.ashore, goat.drowned, goat.health, goat.ashore, wet_fox.health, wet_fox.ashore))

	fresh()
	g.enemy_count = 0
	g.round_count = 0
	p.pos = {20, 20}
	animal_before_him(.Goat)
	step(2, {}, {.Grab})
	step(30)
	step(1, {}, {.Action})
	step(5)
	first := p.sack[.Milk]
	p.hint_cd = 0
	step(1, {}, {.Action})
	step(5)
	check("a held goat gives a jug of milk, and not another straight away", first == 1 && p.sack[.Milk] == 1)

	for kind in ([?]game.Enemy_Kind{.Turkey, .Goat, .Billy}) {
		fresh()
		g.enemy_count = 0
		fire := g.stations[.Fire].pos
		p.pos = fire + {0, 4}
		e := animal_before_him(kind)
		e.state, e.ko, e.body_t = .Dead, true, 200
		step(2, {}, {.Grab})
		step(20) // taking hold
		p.pos = fire + game.FIRE_BLOCK.xz + {0, 1.6}
		step(1, {}, {.Action})
		step(5)
		check(fmt.tprintf("a dead %v is chopped into %d pieces of meat at the fire", kind, game.MEAT_FROM[kind]), p.sack[.Meat] == game.MEAT_FROM[kind] && p.carry == .Nothing, fmt.tprintf("%d meat", p.sack[.Meat]))
	}

	fresh()
	g.enemy_count = 0
	g.round_count = 0
	p.pos = {-60, -10}
	p.facing = 0
	game.sack_add(.Apple, 95)
	game.sack_add(.Apple_Pie, 1057)
	game.add_enemy(.Fox, p.pos + {0, -30})
	fox := &g.enemies[0]
	fox.pos = p.pos + {0, -9}
	for _ in 0 ..< 8 {
		step(60)
	}
	stole := fox.has_loot && fox.loot == .Apple_Pie
	fox.pos = p.pos + {3, 0}
	p.need[.Fibre] = 85
	p.gas_t = 0
	step(30)
	check("a fox steals the richest thing in the sack, and drops it at his wind", stole && !fox.has_loot && p.sack[.Apple_Pie] == 1, fmt.tprintf("stole %v, has it back %v", stole, p.sack[.Apple_Pie] == 1))

	fresh()
	g.enemy_count = 0
	p.pos = game.POND + {0, game.POND_RADIUS + 0.3}
	step(30, {.Up})
	caught := 0
	for _ in 0 ..< 60 {
		step(60)
		if game.fish_in_reach() {
			step(1, {}, {.Grab})
			step(45)
			caught = p.sack[.Fish]
			break
		}
	}
	check("standing still on the bank, a fish can be caught within a minute", caught == 1)
}

// What he is is kept from one sitting to the next.
rules_saving :: proc() {
	section("saving and waking up")
	g := &game.g
	p := &g.prosio
	fresh()
	g.opts.no_save = false
	p.fat = 61.5
	p.trait[.Legs] = 0.4
	p.trait[.Baking] = 0.7
	p.need[.Fibre] = 77
	game.sack_add(.Honey, 300)
	g.seen[100] = true
	hat := game.outfit.hat
	game.outfit.hat = .Crown
	step(1)
	kg := p.kg
	legs, cooking := p.trait[.Legs], p.trait[.Baking]
	game.save_game()
	fresh()
	g.opts.no_save = false
	game.outfit.hat = .Headband
	loaded := game.load_game()
	check("a saved Prosio comes back as he was", loaded && abs(p.fat - 61.5) < 0.01 && p.trait[.Legs] == legs && p.trait[.Baking] == cooking && p.sack[.Honey] == 1 && g.seen[100] && game.outfit.hat == .Crown && abs(p.kg - kg) < 0.01, fmt.tprintf("loaded %v, fat %.1f, weighs %.1f (was %.1f)", loaded, p.fat, p.kg, kg))
	game.outfit.hat = hat
	g.opts.no_save = true

	fresh()
	g.enemy_count = 0
	p.trait[.Arms] = 0.8
	p.trait[.Hooves] = 0.6
	game.sack_add(.Apple, 95)
	p.fat = 0
	p.need[.Carbs] = 0
	p.need[.Protein] = 0
	step(90)
	fainted := p.fail == .Fainted
	step(1, {}, {.Restart})
	step(5)
	check("waking up costs the sack and some muscle, and keeps his skills", fainted && p.fail == .None && p.sack[.Apple] == 0 && p.trait[.Arms] < 0.8 && p.trait[.Arms] > 0.4 && p.trait[.Hooves] > 0.59 && p.fat >= game.WAKE_FAT.x, fmt.tprintf("arms %.2f, hooves %.2f, fat %.0f", p.trait[.Arms], p.trait[.Hooves], p.fat))

	// With no fat left he lives on his carbs: that pig is saved like any other.
	fresh()
	g.opts.no_save = false
	p.fat = 0
	p.need[.Carbs] = 60
	p.trait[.Baking] = 0.5
	step(1)
	game.save_game()
	fresh()
	g.opts.no_save = false
	loaded = game.load_game()
	check("a pig with no fat left is still there next time", loaded && p.fat < 0.01 && abs(p.trait[.Baking] - 0.5) < 0.01, fmt.tprintf("loaded %v, fat %.2f, cooking %.2f", loaded, p.fat, p.trait[.Baking]))
	g.opts.no_save = true

	// He goes down, and the game is left without pressing Enter: next time he
	// is the pig who woke up, not the one from before he fell.
	fresh()
	g.opts.no_save = false
	g.enemy_count = 0
	p.trait[.Arms] = 0.8
	game.sack_add(.Apple, 95)
	step(1)
	game.save_game()
	p.fat = 0
	p.need[.Carbs] = 0
	step(90)
	fainted = p.fail == .Fainted
	fresh()
	g.opts.no_save = false
	loaded = game.load_game()
	check("leaving the game while he lies there does not undo it", fainted && loaded && p.fail == .None && p.sack[.Apple] == 0 && p.trait[.Arms] < 0.8 && p.fat >= game.WAKE_FAT.x, fmt.tprintf("fainted %v, loaded %v, apples %d, arms %.2f, fat %.0f", fainted, loaded, p.sack[.Apple], p.trait[.Arms], p.fat))
	g.opts.no_save = true
}

// Weight makes him slower and shortens his sprint.
rules_moving :: proc() {
	section("moving")
	g := &game.g
	p := &g.prosio
	distance: [3]f32
	for kg, i in ([3]f32{50, 80, 120}) {
		fresh()
		g.enemy_count = 0
		g.round_count = 0
		p.pos = {-60, -10}
		start := p.pos
		frames := 0
		for !p.winded && frames < 6000 {
			game.set_weight(kg)
			step(1, {.Right, .Sprint})
			frames += 1
		}
		distance[i] = p.pos.x - start.x
	}
	check("the heavier he is, the shorter his sprint", distance[0] > distance[1] && distance[1] > distance[2], fmt.tprintf("50 kg %.0f m, 80 kg %.0f m, 120 kg %.0f m", distance[0], distance[1], distance[2]))
}

// Wood, the workbench, and what he builds: fences and pens, the scarecrow,
// the rod and the spear.
rules_workshop :: proc() {
	section("wood and the workshop")
	g := &game.g
	p := &g.prosio
	alone :: proc() {
		fresh()
		game.g.enemy_count = 0
		game.g.round_count = 0
		game.g.prosio.pos = {21, 21}
		game.g.prosio.facing = 0
	}
	give :: proc(item: game.Item, n: int) {
		for _ in 0 ..< n {
			game.sack_add(item, 0)
		}
	}
	// Fences all round a block of squares, w by h, whose top left square is (x, y).
	ring :: proc(x, y, w, h: int) {
		for i in 0 ..< w {
			game.set_fence({x + i, y, .East}, true)
			game.set_fence({x + i, y + h, .East}, true)
		}
		for j in 0 ..< h {
			game.set_fence({x, y + j, .South}, true)
			game.set_fence({x + w, y + j, .South}, true)
		}
	}
	// The middle of such a block.
	middle :: proc(x, y, w, h: int) -> game.Vec2 {
		a, _ := game.fence_ends({x, y, .East})
		return a + game.Vec2{f32(w), f32(h)} * game.FENCE_LEN / 2
	}

	fresh()
	branches, hidden := 0, 0
	first := -1
	for &f, i in g.foods[:g.food_count] {
		if f.kind == .Wood {
			branches += 1
			hidden += game.hidden_by_tree(f.pos) || game.inside_region(f.pos, .Forest) <= 0 && game.inside_region(f.pos + {0, -3}, .Forest) <= 0 ? 1 : 0
			if first < 0 {
				first = i
			}
		}
	}
	check("fallen branches lie under the forest trees, none hidden by a tree", branches == game.WOOD_LYING && hidden == 0, fmt.tprintf("%d branches, %d hidden or outside the forest", branches, hidden))

	// (One with nothing else to pick near it, so that E is for the branch.)
	for &f, i in g.foods[:g.food_count] {
		if f.kind != .Wood || f.gone {
			continue
		}
		alone_there := game.bush_in_reach(f.pos, 2) == nil
		for &other, k in g.foods[:g.food_count] {
			alone_there &&= k == i || other.gone || length(other.pos - f.pos) > 2
		}
		if alone_there {
			first = i
			break
		}
	}
	g.enemy_count = 0
	branch := &g.foods[first]
	p.pos = branch.pos + {0, 0.8}
	step(2, {}, {.Action})
	step(60)
	got, waiting := p.sack[.Wood], branch.respawn
	p.sack_sel = .Wood
	step(2, {}, {.Eat})
	step(20)
	check("E puts a branch in the sack; it cannot be eaten, and another falls there after a while", got == 1 && p.sack[.Wood] == 1 && waiting > 100 && waiting <= game.FOOD_REGROW[.Wood].y, fmt.tprintf("%d in the sack, the next in %.0f s; after trying to eat it: %d", got, waiting, p.sack[.Wood]))

	fresh()
	g.enemy_count = 0
	give(.Wood, 9)
	give(.Pebble, 1)
	for _ in 0 ..< 3 {
		game.sack_add(.Wheat, 300)
	}
	for plan in ([?]game.Item{.Scarecrow, .Rod, .Fence, .Spear}) { // (in an order that keeps room in the sack)
		cook(.Bench, plan, 1)
		game.scene = .Playing
	}
	check("the workbench makes a piece of fence, a scarecrow, a rod and a spear of wood", p.sack[.Fence] == 1 && p.sack[.Scarecrow] == 1 && p.sack[.Rod] == 1 && p.sack[.Spear] == 1 && p.sack[.Wood] == 0 && p.sack[.Wheat] == 0 && p.sack[.Pebble] == 0, fmt.tprintf("fence %d, scarecrow %d, rod %d, spear %d; left over: wood %d, wheat %d, pebbles %d", p.sack[.Fence], p.sack[.Scarecrow], p.sack[.Rod], p.sack[.Spear], p.sack[.Wood], p.sack[.Wheat], p.sack[.Pebble]))

	buf: [len(game.RECIPES)]^game.Recipe
	all := len(game.station_recipes(.Bench, &buf))
	p.knows[.Spear] = false
	listed := false
	for r in game.station_recipes(.Bench, &buf) {
		listed ||= r.dish == .Spear
	}
	check("he knows every recipe and plan from the start; one he did not know would not be on the menu", all == 6 && !listed, fmt.tprintf("%d plans at the workbench; the spear still listed when not known: %v", all, listed))

	alone()
	give(.Fence, 3)
	p.sack_sel = .Fence
	step(2, {}, {.Eat})
	step(50)
	up, left := g.fence_count, p.sack[.Fence]
	step(2, {}, {.Eat})
	step(50)
	again := g.fence_count
	step(2, {}, {.Grab})
	step(50)
	check("Q puts a piece of fence up in front of him, once in each place; F takes it down again", up == 1 && left == 2 && again == 1 && g.fence_count == 0 && p.sack[.Fence] == 3, fmt.tprintf("after Q: %d standing, %d in the sack; Q again: %d standing; after F: %d standing, %d in the sack", up, left, again, g.fence_count, p.sack[.Fence]))

	// He stands in a square of fence, with two turkeys, a goat and the billy
	// goat outside wanting to get at him, for a minute.
	alone()
	x, y := game.fence_cell(p.pos)
	ring(x, y, 1, 1)
	for kind, i in ([?]game.Enemy_Kind{.Turkey, .Turkey, .Goat, .Billy}) {
		game.add_enemy(kind, p.pos + game.facing_dir(f32(i) * 1.6) * 5)
	}
	nearest: f32 = 1e9
	got_in, crossed := false, false
	was: [4]game.Vec2
	for frame in 0 ..< 60 * 60 {
		step(1)
		for &e, i in g.enemies[:g.enemy_count] {
			nearest = min(nearest, length(e.pos - p.pos))
			ex, ey := game.fence_cell(e.pos)
			got_in ||= ex == x && ey == y
			crossed ||= frame > 0 && game.crosses_fence(was[i], e.pos)
			was[i] = e.pos
		}
	}
	bruises := p.bruises
	check("a fence keeps turkeys and goats out", !got_in && !crossed && nearest < 3 && bruises == 0, fmt.tprintf("one got in %v, one crossed a piece %v, the nearest came to %.1f m; bruises %.0f", got_in, crossed, nearest, bruises))

	// He cannot walk through one either; a jump takes him over, if he is
	// light enough.
	g.enemy_count = 0
	step(120, {.Right})
	walked := p.pos.x
	step(2, {.Right}, {.Jump})
	step(60, {.Right})
	jumped := p.pos.x
	check("a fence stops him walking; at 80 kg a jump takes him over it", walked < 22 && jumped > 23, fmt.tprintf("walking right he got to x %.1f, jumping to x %.1f (the fence is at 22)", walked, jumped))

	alone()
	game.set_weight(100)
	hx, hy := game.fence_cell(p.pos)
	ring(hx, hy, 1, 1)
	step(120, {.Right})
	step(2, {.Right}, {.Jump})
	step(60, {.Right})
	check("at 100 kg he cannot jump a fence: he is penned in until he takes a piece down", p.pos.x < 22, fmt.tprintf("he got to x %.1f (the fence is at 22); a jump takes him %.2f m up, a fence is %.2f m", p.pos.x, game.jump_height(game.total_kg()), game.FENCE_TOP))

	// A turkey with fences all round it.
	alone()
	x, y = game.fence_cell(p.pos + {6, 0})
	ring(x, y, 2, 2)
	game.add_enemy(.Turkey, middle(x, y, 2, 2))
	e := &g.enemies[0]
	e.home += {30, 0} // where it came from
	wild := e.home
	step(90)
	penned := e.penned
	p.pos = middle(x, y, 2, 2) + {-2.9, 0} // just outside
	stayed := true
	for _ in 0 ..< 60 * 30 {
		step(1)
		stayed &&= game.fenced_in(e.pos)
	}
	quiet := p.bruises == 0
	game.set_fence({x, y, .East}, false)
	step(90)
	check("an animal with fences all round it is penned: it stays and leaves him alone, until there is a gap", penned && stayed && quiet && !e.penned && e.home == wild, fmt.tprintf("penned %v, stayed in %v, bruises %.0f; with a piece taken out: penned %v, its home back in the wild %v", penned, stayed, p.bruises, e.penned, e.home == wild))

	// A penned turkey lays: within two minutes, an egg in the pen. Shaken,
	// a turkey hardly ever lets one go.
	alone()
	x, y = game.fence_cell(p.pos)
	ring(x + 3, y, 1, 1)
	game.add_enemy(.Turkey, middle(x + 3, y, 1, 1))
	step(60 * 125)
	laid := 0
	for &f in g.foods[:g.food_count] {
		laid += f.kind == .Egg && !f.gone && game.fenced_in(f.pos) ? 1 : 0
	}
	check("a penned turkey lays an egg in its pen every minute or two; shaking one hardly ever drops an egg", laid >= 1 && game.SHAKE_EGG <= 0.02, fmt.tprintf("%d eggs laid in the pen in two minutes; the chance an egg falls out at each swing is %.2f", laid, game.SHAKE_EGG))

	// The workbench stands across the yard from the oven.
	apart := length(g.stations[.Bench].pos - g.stations[.Oven].pos)
	check("the workbench stands well away from the oven", apart > 8, fmt.tprintf("%.1f m apart", apart))

	// At a fence, F lifts a turkey or a fox over it and sets it down on the
	// far side; a goat is too heavy, and is put down on his side.
	over: [2]bool
	for kind, i in ([2]game.Enemy_Kind{.Turkey, .Goat}) {
		alone()
		fx, fy := game.fence_cell(p.pos)
		game.set_fence({fx, fy + 1, .East}, true) // a piece across his way, below him
		line := f32(fy + 1) * game.FENCE_LEN - game.WORLD_HALF.y
		p.pos.y = line - 1.6
		p.facing = math.PI // up, away from the fence
		game.add_enemy(kind, p.pos - {0, game.prosio_radius(p.kg) + game.ENEMY_RADIUS[kind] + 0.3})
		held := &g.enemies[g.enemy_count - 1]
		held.facing = 0
		step(2, {}, {.Grab})
		step(40)
		step(12, {.Down}) // he turns round to the fence, the animal with him
		step(30)
		step(2, {}, {.Grab})
		step(120)
		over[i] = held.pos.y > line && held.state != .Held
	}
	check("at a fence F lifts a turkey over it, but not a goat", over[0] && !over[1], fmt.tprintf("the turkey went over %v, the goat %v (an 80 kg pig lifts up to %.0f kg)", over[0], over[1], game.hoist_most()))

	// A goat goes into a pen by the gate: he grabs it, E opens the gate with
	// the goat in his hooves, he drags it in and puts it down, comes out,
	// and E shuts the gate. It is penned, and stays.
	alone()
	gx, gy := game.fence_cell(p.pos)
	ring(gx, gy + 1, 2, 2)
	gate := game.Fence_At{gx, gy + 1, .East}
	game.set_gate(gate, game.GATE_SHUT)
	ga, gb := game.fence_ends(gate)
	mid := (ga + gb) / 2
	p.pos = mid - {0, 1.7}
	p.facing = math.PI
	game.add_enemy(.Goat, p.pos - {0, game.prosio_radius(p.kg) + game.ENEMY_RADIUS[.Goat] + 0.3})
	goat := &g.enemies[g.enemy_count - 1]
	goat.facing = 0
	goat.home += {-30, -30}
	step(2, {}, {.Grab})
	step(40)
	step(20, {.Down})
	step(10)
	turned_to, stood_at := p.facing, p.pos
	_, at_gate := game.gate_in_reach()
	step(2, {}, {.Action})
	opened := game.gate_state(gate) == game.GATE_OPEN && p.carry == .Enemy
	for _ in 0 ..< 200 {
		if p.pos.y > mid.y + 2.2 {
			break
		}
		step(1, {.Down})
	}
	step(2, {}, {.Grab})
	step(120)
	goat_in := game.fenced_in(goat.pos) && goat.state != .Held
	penned_open := goat.penned
	p.pos = mid - {0, 1.3}
	p.facing = 0
	step(2, {}, {.Action})
	shut := game.gate_state(gate) == game.GATE_SHUT
	goat_stayed := true
	for _ in 0 ..< 60 * 30 {
		step(1)
		goat_stayed &&= game.fenced_in(goat.pos)
	}
	check("E opens a gate with a goat in his hooves; dragged in through it, the goat is penned, and stays once the gate is shut", at_gate && opened && goat_in && penned_open && shut && goat_stayed && goat.penned, fmt.tprintf("at the gate %v (at %.1f, %.1f, facing %.2f; the gate at y %.1f), opened holding it %v, put down inside %v, penned with the gate open %v, shut %v, stayed %v", at_gate, stood_at.x, stood_at.y, turned_to, mid.y, opened, goat_in, penned_open, shut, goat_stayed))

	// Food goes off in the sack: a fish loses half in ten minutes and is
	// thrown out soon after; honey keeps. In a larder it keeps five times
	// as long.
	alone()
	game.sack_add(.Fish, 200)
	game.sack_add(.Honey, 300)
	minutes :: proc(n: int) {
		for _ in 0 ..< n {
			game.g.prosio.need = {.Carbs = 50, .Protein = 50, .Fibre = 50, .Water = 80, .Vitamins = 50, .Electrolytes = 50} // (kept fed and watered meanwhile)
			step(60 * 60)
		}
	}
	minutes(10)
	fish_half, fish_fresh := p.sack_kcal[.Fish], p.sack_fresh[.Fish]
	minutes(10)
	thrown := p.sack[.Fish] == 0
	honey := p.sack_kcal[.Honey]
	check("a fish in the sack loses half in ten minutes and is thrown out when it goes bad; honey keeps", abs(fish_half - 100) < 2 && abs(fish_fresh - 0.5) < 0.02 && thrown && honey == 300, fmt.tprintf("after 10 minutes %.0f kcal, freshness %.2f; after 20 thrown out %v; honey %.0f kcal", fish_half, fish_fresh, thrown, honey))

	// The workbench makes a larder of wood and salt; Q stands it up, E opens
	// it, and a fish put in it keeps; F takes it down only when it is empty.
	alone()
	give(.Wood, 4)
	for _ in 0 ..< 2 {
		game.sack_add(.Salt, 30)
	}
	cook(.Bench, .Larder, 1)
	game.scene = .Playing
	built_larder := p.sack[.Larder] == 1 && p.sack[.Wood] == 0 && p.sack[.Salt] == 0
	p.sack_sel = .Larder
	step(2, {}, {.Eat})
	step(60)
	larder_stood := game.larder_count() == 1 && p.sack[.Larder] == 0
	game.sack_add(.Fish, 200)
	reach, stooping := game.larder_in_reach(), p.pick_t
	step(2, {}, {.Action})
	larder_opened := game.scene == .Larder
	for b in ([2]game.Button{.Right, .Menu}) { // (menus are run by the frame, not by step)
		game.forced_pressed = {b}
		game.update_larder_menu()
	}
	game.forced_pressed = {}
	l := &g.larders[0]
	stored := l.stock[.Fish] == 1 && p.sack[.Fish] == 0 && game.scene == .Playing
	step(2, {}, {.Grab})
	step(30)
	kept_up := game.larder_count() == 1
	minutes(10)
	larder_fresh := l.fresh[.Fish]
	check("the workbench makes a larder of 4 logs and 2 salt; Q stands it, E opens it, food keeps five times as long in it, and F will not take it down full", built_larder && larder_stood && larder_opened && stored && kept_up && abs(larder_fresh - 0.87) < 0.02, fmt.tprintf("built %v, stood up %v (in reach: larder %d, stooping %.2f), opened %v, fish put in %v, still standing after F %v; the fish's freshness after 10 minutes in it %.2f", built_larder, larder_stood, reach, stooping, larder_opened, stored, kept_up, larder_fresh))

	// Meat from a body that has lain a long while is poorer, and nearer
	// going off.
	alone()
	g.round_count = 0
	p.pos = g.stations[.Fire].pos + {0, 1.6}
	fresh_meat: [2]f32
	for lain, i in ([2]f32{0, 200}) {
		g.enemy_count = 0
		body := animal_before_him(.Turkey)
		body.state, body.ko, body.health, body.body_t = .Dead, true, 0, game.BODY_LIFE - lain
		p.facing = 0
		step(2, {}, {.Grab})
		step(40)
		before := p.sack_kcal[.Meat]
		step(2, {}, {.Action})
		step(10)
		fresh_meat[i] = (p.sack_kcal[.Meat] - before) / 2
	}
	check("meat chopped from a body that has lain a long while is poorer", fresh_meat[0] == 300 && fresh_meat[1] < 150, fmt.tprintf("a piece from a fresh body %.0f kcal, from one that lay 200 s %.0f kcal", fresh_meat[0], fresh_meat[1]))

	// He throws a turkey over a fence into a pen, jumps in after it (he
	// cannot jump with an animal in his hooves), and throws it out again.
	alone()
	x, y = game.fence_cell(p.pos)
	ring(x - 1, y + 1, 2, 2)
	p.pos.x = middle(x - 1, y + 1, 2, 2).x // its middle is straight below him
	e = animal_before_him(.Turkey)
	step(2, {}, {.Grab})
	step(30)
	step(30, {.Grab}, {.Grab})
	step(300)
	carried_in := e.penned
	step(90, {.Down})
	step(2, {.Down}, {.Jump})
	step(30, {.Down})
	inside := game.fenced_in(p.pos)
	p.facing = 0
	p.pos = e.pos - {0, game.prosio_radius(p.kg) + game.ENEMY_RADIUS[.Turkey] + 0.3}
	step(2, {}, {.Grab})
	step(30)
	step(70, {.Grab}, {.Grab})
	step(400)
	check("a thrown animal goes over a fence into a pen, he jumps in after it, and throws it out again", inside && carried_in && !e.penned && !game.fenced_in(e.pos), fmt.tprintf("thrown in, it was penned %v; he jumped into the pen %v; thrown out, it is penned %v, at (%.1f, %.1f)", carried_in, inside, e.penned, e.pos.x, e.pos.y))

	// A goat in a pen.
	alone()
	x, y = game.fence_cell(p.pos)
	ring(x, y, 2, 2)
	game.add_enemy(.Goat, middle(x, y, 2, 2) + {0.6, 0})
	e = &g.enemies[0]
	e.home = {60, 20} // where it came from
	step(90)
	for _ in 0 ..< 600 {
		p.pos = e.pos + {-(game.prosio_radius(p.kg) + game.ENEMY_RADIUS[.Goat] + 0.2), 0}
		step(1)
	}
	step(1, {}, {.Action})
	step(5)
	check("a goat in a pen stands to be milked with E, and does not butt him", e.penned && p.sack[.Milk] == 1 && p.bruises == 0, fmt.tprintf("penned %v, milk %d, bruises %.0f", e.penned, p.sack[.Milk], p.bruises))

	// The end of a penned animal: the next of its kind comes back in the wild.
	game.leave(e)
	check("a penned animal that is killed does not come back in the pen", !e.penned && !game.fenced_in(e.home), fmt.tprintf("penned %v, its home fenced in %v", e.penned, game.fenced_in(e.home)))

	// A crow at the wheat, and a scarecrow stood up seven metres off.
	fresh()
	g.enemy_count = 0
	g.round_count = 0
	wheat := -1
	for &f, i in g.foods[:g.food_count] {
		if f.kind == .Wheat && game.food_ready(&f) {
			wheat = i
			break
		}
	}
	crow := &g.pests[2]
	crow.state, crow.food, crow.t, crow.y = .Eating, wheat, 14, 0.45
	crow.pos = g.foods[wheat].pos
	p.pos = crow.pos + {0, 7}
	p.facing = 0
	give(.Scarecrow, 1)
	p.sack_sel = .Scarecrow
	step(2, {}, {.Eat})
	step(60)
	stood, fled := game.scarecrow_count(), crow.state != .Eating
	for &f in g.foods[:g.food_count] {
		if f.kind == .Wheat {
			f.grow = 1
		}
	}
	p.pos = {-60, 0}
	crow.state = .Away
	next := game.pest_target(crow)
	safe := next < 0 || !game.scarecrow_near(g.foods[next].pos)
	p.pos = g.foods[wheat].pos + {0, 7}
	p.facing = 0
	step(2, {}, {.Grab})
	step(50)
	check("a scarecrow sends the crow off the wheat near it and keeps crows away; F takes it down", stood == 1 && fled && safe && game.scarecrow_near(g.foods[wheat].pos) == false && p.sack[.Scarecrow] == 1, fmt.tprintf("scarecrows standing %d, the crow fled %v, its next choice is away from the scarecrow %v; after F: %d standing, %d in the sack", stood, fled, safe, game.scarecrow_count(), p.sack[.Scarecrow]))

	// A cabbage with fences all round it.
	fresh()
	cabbage := -1
	for &f, i in g.foods[:g.food_count] {
		if f.kind == .Cabbage {
			f.grow = i == cabbage || cabbage < 0 ? 1 : 0.1 // only the one is worth a raid
			if cabbage < 0 {
				cabbage = i
			}
		}
	}
	p.pos = {60, -40}
	rabbit := &g.pests[0]
	before := game.pest_target(rabbit)
	x, y = game.fence_cell(g.foods[cabbage].pos)
	ring(x, y, 1, 1)
	after := game.pest_target(rabbit)
	check("a rabbit will not go for a cabbage that is fenced in", before == cabbage && after != cabbage, fmt.tprintf("its choice before the fence: the cabbage %v; after: the cabbage %v", before == cabbage, after == cabbage))

	// The rod.
	fresh()
	g.enemy_count = 0
	p.pos = game.POND + {0, game.POND_RADIUS + 0.3}
	for &f, i in g.fish {
		f.pos = p.pos + {f32(i) * 0.5 - 1.2, -3.5 - 0.2 * f32(i)}
		f.dart_t, f.shy_t, f.away_t = 0, 0, 0
	}
	by_hoof := game.fish_in_reach()
	give(.Rod, 1)
	p.sack_sel = .Rod
	by_rod := game.fish_in_reach()
	step(1, {}, {.Grab})
	step(45)
	frightened := 0
	for f in g.fish {
		frightened += f.away_t <= 0 && (f.shy_t > 0 || f.dart_t > 0) ? 1 : 0
	}
	check("with the rod he catches a fish beyond his hoof's reach, and the others take no fright", !by_hoof && by_rod && p.sack[.Fish] == 1 && frightened == 0 && p.sack[.Rod] == 1, fmt.tprintf("in reach by hoof %v, by rod %v; fish caught %d, others frightened %d", by_hoof, by_rod, p.sack[.Fish], frightened))

	// The spear.
	alone()
	give(.Spear, 2)
	p.sack_sel = .Spear
	game.add_enemy(.Turkey, p.pos + {0, 6})
	e = &g.enemies[0]
	e.timer = 100
	flew := false
	step(70, {.Grab}, {.Grab})
	for _ in 0 ..< 90 {
		step(1)
		flew ||= e.state == .Flying
	}
	after_one := e.health
	lying := -1
	for &f, i in g.foods[:g.food_count] {
		if f.kind == .Spear && game.food_ready(&f) {
			lying = i
		}
	}
	in_sack := p.sack[.Spear]
	if lying >= 0 {
		p.pos = g.foods[lying].pos + {0, 0.7}
		step(2, {}, {.Action})
		step(60)
	}
	check("a spear takes far more from a turkey than a stone, lies where it came down, and is picked up again", after_one < game.ENEMY_HEALTH - 40 && after_one > 20 && !flew && in_sack == 1 && lying >= 0 && p.sack[.Spear] == 2, fmt.tprintf("the turkey's health after one: %.0f, bowled over %v; spears in the sack %d, lying %v; after E: %d", after_one, flew, in_sack, lying >= 0, p.sack[.Spear]))

	// What he built is there next time.
	fresh()
	g.opts.no_save = false
	x, y = game.fence_cell({12, 12})
	ring(x, y, 2, 2)
	turkey := -1
	for &t, i in g.enemies[:g.enemy_count] {
		if t.kind == .Turkey {
			turkey = i
			break
		}
	}
	g.enemies[turkey].pos = middle(x, y, 2, 2)
	game.add_scarecrow({50, 21})
	p.knows[.Spear] = false
	give(.Wood, 4)
	step(90)
	was_penned := g.enemies[turkey].penned
	game.save_game()
	fresh()
	g.opts.no_save = false
	loaded := game.load_game()
	back := 0
	for &t in g.enemies[:g.enemy_count] {
		back += t.kind == .Turkey && t.penned && game.fenced_in(t.pos) ? 1 : 0
	}
	check("his fences, his scarecrows, the animals in his pens and what he knows are there next time", was_penned && loaded && g.fence_count == 8 && game.scarecrow_count() == 1 && back == 1 && !p.knows[.Spear] && p.knows[.Fence] && p.sack[.Wood] == 4, fmt.tprintf("penned before %v, loaded %v; %d pieces of fence, %d scarecrows, %d turkeys in the pen, wood %d", was_penned, loaded, g.fence_count, game.scarecrow_count(), back, p.sack[.Wood]))
	g.opts.no_save = true

	// A larder and what is in it, and how fresh his food is, are kept.
	fresh()
	g.opts.no_save = false
	game.add_larder({30, 30})
	g.larders[0].stock[.Cheese], g.larders[0].kcal[.Cheese], g.larders[0].fresh[.Cheese] = 2, 600, 0.9
	game.sack_add(.Fish, 150, 0.6)
	game.save_game()
	fresh()
	g.opts.no_save = false
	larder_loaded := game.load_game()
	check("a larder and what is in it are saved, and how fresh the food in the sack is", larder_loaded && game.larder_count() == 1 && g.larders[0].stock[.Cheese] == 2 && abs(g.larders[0].fresh[.Cheese] - 0.9) < 0.001 && p.sack[.Fish] == 1 && abs(p.sack_fresh[.Fish] - 0.6) < 0.001, fmt.tprintf("loaded %v, larders %d, cheese in it %d, fish in the sack %d at freshness %.2f", larder_loaded, game.larder_count(), g.larders[0].stock[.Cheese], p.sack[.Fish], p.sack_fresh[.Fish]))
	g.opts.no_save = true

	// A pig saved before there was wood.
	fresh()
	g.opts.no_save = false
	old := new(game.Save_4)
	old.version, old.size, old.fat = 4, size_of(game.Save_4), 48
	old.need = p.need
	old.sack[int(game.Item.Pebble)] = 4
	old.sack[int(game.Item.Cheese)] = 1
	old.sack_sel = u8(game.Item.Bread)
	game.store_write(([^]u8)(old)[:size_of(game.Save_4)])
	fresh()
	g.opts.no_save = false
	loaded = game.load_game()
	check("a Prosio saved before there was wood is carried over, knowing every plan", loaded && abs(p.fat - 48) < 0.01 && p.sack[.Pebble] == 4 && p.sack[.Cheese] == 1 && p.sack[.Wood] == 0 && p.sack_sel == .Bread && p.knows[.Fence] && p.knows[.Bread] && g.fence_count == 0, fmt.tprintf("loaded %v, fat %.0f, pebbles %d, cheese %d, wood %d, chosen %v, knows the fence %v", loaded, p.fat, p.sack[.Pebble], p.sack[.Cheese], p.sack[.Wood], p.sack_sel, p.knows[.Fence]))
	g.opts.no_save = true
	free(old)
}
