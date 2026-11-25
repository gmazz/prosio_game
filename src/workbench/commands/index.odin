package workbench_commands

// The index: for each kind of thing in the game, what moves it, draws it,
// tunes it and makes it, so that the workbench can open the code behind
// whatever is selected. The game has no script per thing (a goat's behaviour
// is spread over several procedures), so this table says where to look.
//
// Each code entry names a procedure, and Odin itself gives its file and line
// (#location), so the index stays right as the code moves. The tables are
// indexed by the game's own kinds, so a new animal, round thing, food or
// pest cannot be added to the game without an entry here: the workbench
// would not build. A rule in tools/check.sh also checks every entry leads to
// a file that is there.

import game "../../game"
import "base:runtime"

Entry :: struct {
	label: string,
	at:    runtime.Source_Code_Location, // a procedure (file_path and line)
	file:  string, // or a file: tuning, a model
	find:  string, // where in the file (the first line with this), if a file
}

code :: proc "contextless" (label: string, at: runtime.Source_Code_Location) -> Entry {
	return {label = label, at = at}
}

file :: proc "contextless" (label, path: string, find := "") -> Entry {
	return {label = label, file = path, find = find}
}

// Things that are not kinds of something else in the game.
Other :: enum {
	Prosio,
	Field,
	Fish,
	Fence,
	Thrown_Rock,
}

// What a thing in the world is, for selecting and the index.
Thing :: union {
	Other,
	game.Enemy_Kind,
	game.Round_Kind,
	game.Food_Kind,
	game.Pest_Kind,
	game.Decor_Kind,
}

index_of :: proc(t: Thing) -> []Entry {
	switch k in t {
	case Other: return OTHER_INDEX[k]
	case game.Enemy_Kind: return ENEMY_INDEX[k]
	case game.Round_Kind: return ROUND_INDEX[k]
	case game.Food_Kind: return FOOD_INDEX[k]
	case game.Pest_Kind: return PEST_INDEX[k]
	case game.Decor_Kind: return DECOR_INDEX[k]
	}
	return nil
}

OTHER_INDEX := [Other][]Entry {
	.Prosio = {
		code("Moving, jumping, stamina", #location(game.update_prosio)),
		code("His body: muscles, skills, waking up", #location(game.update_body)),
		code("Eating and his needs", #location(game.update_diet)),
		code("Grabbing and throwing", #location(game.update_grab)),
		code("His pose (both bodies)", #location(game.prosio_pose)),
		code("Being drawn", #location(game.draw_prosio)),
		code("His clothes", #location(game.draw_torso_outfit)),
		file("His numbers", "data/tuning/prosio.json"),
		file("How he looks", "data/tuning/prosio_look.json"),
		file("His skin's model", "assets/prosio_base/prosio_base.glb"),
	},
	.Field = {
		code("Growing", #location(game.update_world)),
		code("Being drawn (the ground)", #location(game.draw_ground)),
		file("Its numbers", "data/tuning/world.json", "growing"),
	},
	.Fish = {
		code("Swimming", #location(game.update_fish)),
		code("Being caught", #location(game.grab_fish)),
		code("Being drawn", #location(game.draw_fish)),
		file("Its numbers", "data/tuning/critters.json", "fish"),
	},
	.Fence = {
		code("Being drawn", #location(game.draw_fences)),
		code("A gate", #location(game.draw_gate)),
		file("Its numbers", "data/tuning/building.json", "fences"),
	},
	.Thrown_Rock = {
		code("Flying", #location(game.update_thrown)),
		code("Being thrown", #location(game.throw_rock)),
		file("Its numbers", "data/tuning/handling.json", "throwing"),
	},
}

ENEMY_INDEX := [game.Enemy_Kind][]Entry {
	.Turkey = {
		code("Deciding what to do", #location(game.update_enemies)),
		code("Being bumped or thrown", #location(game.step_enemy_impact)),
		code("Being held", #location(game.update_grab)),
		code("Being drawn", #location(game.draw_turkey)),
		file("Its numbers", "data/tuning/animals.json", "Turkey"),
	},
	.Goat = {
		code("Deciding what to do", #location(game.update_enemies)),
		code("Feet on the ground", #location(game.quad_update_motion)),
		code("Being bumped or thrown", #location(game.step_enemy_impact)),
		code("Being held", #location(game.update_grab)),
		code("Being dragged", #location(game.quad_drag_skin)),
		code("Being drawn", #location(game.draw_quad_enemy)),
		file("Its numbers", "data/tuning/animals.json", "Goat"),
		file("Its model", "assets/goat/goat.glb"),
	},
	.Billy = {
		code("Deciding what to do", #location(game.update_enemies)),
		code("Feet on the ground", #location(game.quad_update_motion)),
		code("Being bumped or thrown", #location(game.step_enemy_impact)),
		code("Being held", #location(game.update_grab)),
		code("Being dragged", #location(game.quad_drag_skin)),
		code("Being drawn", #location(game.draw_quad_enemy)),
		file("Its numbers", "data/tuning/animals.json", "Billy"),
		file("Its model", "assets/billy/billy.glb"),
	},
	.Fox = {
		code("Deciding what to do", #location(game.update_enemies)),
		code("Feet on the ground", #location(game.quad_update_motion)),
		code("Being bumped or thrown", #location(game.step_enemy_impact)),
		code("Being held", #location(game.update_grab)),
		code("Being dragged", #location(game.quad_drag_skin)),
		code("Being drawn", #location(game.draw_quad_enemy)),
		file("Its numbers", "data/tuning/animals.json", "Fox"),
		file("Its model", "assets/packfox/packfox.glb"),
	},
}

ROUND_INDEX := [game.Round_Kind][]Entry {
	.Tree = {
		code("Being drawn", #location(game.draw_tree)),
		code("Its model, chosen and shaped", #location(game.draw_packed_tree)),
		code("Being shaken, apples", #location(game.update_world)),
		file("Its numbers", "data/tuning/world.json", "trees"),
		file("Its models", "assets/trees/broad1.glb"),
	},
	.Rock = {
		code("Being drawn", #location(game.draw_rock)),
		code("Being lifted and thrown", #location(game.update_grab)),
		file("Its numbers", "data/tuning/handling.json", "rocks"),
		file("Its models", "assets/trees/rock1.glb"),
	},
	.Bush = {
		code("Being drawn", #location(game.draw_bush)),
		code("Its berries", #location(game.update_world)),
		file("Its numbers", "data/tuning/world.json", "growing"),
	},
	.Oven = {
		code("Baking", #location(game.update_stations)),
		code("Its menu", #location(game.update_cook_menu)),
		code("Being drawn", #location(game.draw_oven)),
		file("Its numbers", "data/tuning/food.json", "STATION_TIME"),
	},
	.Mill = {
		code("Grinding", #location(game.update_mill)),
		code("Being drawn", #location(game.draw_mill)),
		file("Its numbers", "data/tuning/food.json", "MILL"),
	},
	.Fire = {
		code("Cooking", #location(game.update_stations)),
		code("Its menu", #location(game.update_cook_menu)),
		code("Being drawn", #location(game.draw_fire)),
		file("Its numbers", "data/tuning/food.json", "STATION_TIME"),
	},
	.Churn = {
		code("Churning", #location(game.update_stations)),
		code("Being drawn", #location(game.draw_churn)),
		file("Its numbers", "data/tuning/food.json", "STATION_TIME"),
	},
	.Block = {
		code("Being drawn (with the stations)", #location(game.draw_world)),
		file("Its numbers", "data/tuning/food.json", "STATION_RADIUS"),
	},
	.Hive = {
		code("Bees and honey", #location(game.update_bees)),
		code("Being drawn", #location(game.draw_hive)),
		file("Its numbers", "data/tuning/critters.json", "bees"),
	},
	.Salt_Rock = {
		code("Being drawn", #location(game.draw_salt_rock)),
		code("Salt growing on it", #location(game.update_world)),
		file("Its numbers", "data/tuning/world.json", "salt"),
	},
	.Pebbles = {
		code("Being drawn (with the world)", #location(game.draw_world)),
		code("Filling the sack", #location(game.update_grab)),
		file("Its numbers", "data/tuning/world.json", "PEBBLE"),
	},
	.Bench = {
		code("Being drawn", #location(game.draw_bench)),
		file("Its numbers", "data/tuning/building.json", "wood_and_bench"),
	},
	.Scarecrow = {
		code("Being drawn", #location(game.draw_scarecrow)),
		code("Scaring pests", #location(game.update_pests)),
		file("Its numbers", "data/tuning/building.json", "scarecrow"),
	},
	.Larder = {
		code("Food keeping in it", #location(game.update_spoil)),
		code("Its menu", #location(game.update_larder_menu)),
		code("Being drawn", #location(game.draw_larder)),
		file("Its numbers", "data/tuning/building.json", "larder"),
	},
	.Stump = {
		code("Being drawn", #location(game.draw_stump)),
		file("Its numbers", "data/tuning/world.json", "plants"),
		file("Its models", "assets/trees/stump1.glb"),
	},
}

FOOD_INDEX := [game.Food_Kind][]Entry {
	.Apple = {code("Growing and falling", #location(game.update_world)), code("Being drawn", #location(game.draw_food)), file("Its numbers", "data/tuning/food.json", "Apple")},
	.Mushroom = {code("Growing", #location(game.update_world)), code("Being drawn", #location(game.draw_food)), file("Its numbers", "data/tuning/food.json", "Mushroom")},
	.Pumpkin = {code("Growing", #location(game.update_world)), code("Being drawn", #location(game.draw_food)), file("Its numbers", "data/tuning/food.json", "Pumpkin")},
	.Wheat = {code("Growing", #location(game.update_world)), code("Being drawn", #location(game.draw_food)), file("Its numbers", "data/tuning/food.json", "Flour")},
	.Egg = {code("Being laid", #location(game.update_enemies)), code("Being drawn", #location(game.draw_food)), file("Its numbers", "data/tuning/food.json", "Egg")},
	.Cabbage = {code("Growing", #location(game.update_world)), code("Being drawn", #location(game.draw_food)), file("Its numbers", "data/tuning/food.json", "Cabbage")},
	.Nuts = {code("Dropping", #location(game.update_world)), code("Being drawn", #location(game.draw_food)), file("Its numbers", "data/tuning/food.json", "Nuts")},
	.Wood = {code("Falling", #location(game.update_world)), code("Being drawn", #location(game.draw_food)), file("Its numbers", "data/tuning/building.json", "WOOD")},
	.Spear = {code("Flying and landing", #location(game.update_thrown)), code("Being drawn", #location(game.draw_spear)), file("Its numbers", "data/tuning/building.json", "SPEAR")},
}

PEST_INDEX := [game.Pest_Kind][]Entry {
	.Rabbit = {code("Coming, eating, fleeing", #location(game.update_pests)), code("Being drawn", #location(game.draw_pests)), file("Its numbers", "data/tuning/critters.json", "pests")},
	.Crow = {code("Coming, eating, fleeing", #location(game.update_pests)), code("Being drawn", #location(game.draw_pests)), file("Its numbers", "data/tuning/critters.json", "pests")},
}

DECOR_INDEX := [game.Decor_Kind][]Entry {
	.Tuft = {code("Being drawn", #location(game.draw_plant)), file("Its numbers", "data/tuning/world.json", "plants")},
	.Flower = {code("Being drawn", #location(game.draw_plant)), file("Its numbers", "data/tuning/world.json", "plants")},
	.Fern = {code("Being drawn", #location(game.draw_plant)), file("Its numbers", "data/tuning/world.json", "plants")},
	.Shrub = {code("Being drawn", #location(game.draw_plant)), file("Its numbers", "data/tuning/world.json", "plants")},
}
