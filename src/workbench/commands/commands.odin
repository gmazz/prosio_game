package workbench_commands

// The workbench's commands: what the command menu offers (../menu.odin), what
// set-ups are made of, and what can be given from outside (the host's command
// file). Each is a line of words, such as "kg 120", "go hills" or
// "put goat". They change the game the way a tester would want, not the way a
// player can; they are only in the workbench's build.
//
// Nothing here draws or reads the keyboard, so the check program can run
// these commands without a window (see src/check).
//
// A set-up is the list of commands run since the last reset, each written as
// it can be run again ("put goat" is kept as "put goat at 3.20 5.10"). It is
// replayed when the game's state changes shape, and can be saved under a name
// in src/workbench/setups/ and loaded again.

import game "../../game"
import "core:fmt"
import "core:math"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"

SETUP_DIR :: "src/workbench/setups"

// Where things are put: tried in turn round a circle in front of him, this
// many places, leaving this much room.
PLACE_STEPS :: 16
PLACE_GAP :: f32(0.34)
APPLE_RADIUS :: f32(0.25)
ROCK_RADIUS :: f32(0.62)
// The portrait: as close as the camera comes.
PORTRAIT_ZOOM :: f32(0.29)

Command :: struct {
	group, name, args, help: string,
}

// What the menu lists (the words a command starts with, what follows, and
// what it does).
COMMANDS := []Command {
	{"Go", "go", "home | oven | fire | churn | a region | goat | billy | fox | turkey | X Y", "Prosio there (an animal: to the nearest of them)"},
	{"Go", "go mouse", "", "Prosio where the mouse points"},
	{"Put", "put", "goat | billy | fox | turkey | fallen-goat | rock | scarecrow | larder | a food", "in front of him (or: ... at X Y)"},
	{"Put", "put pen", "", "a turkey in a pen beside him, its near side a gate"},
	{"Put", "put crowd", "N", "the animals replaced by N goats, billy goats and foxes round him"},
	{"Put", "clear animals", "", "no animals"},
	{"Him", "kg", "N", "his weight, his fat making up the difference"},
	{"Him", "fat", "N", "his fat, in kg"},
	{"Him", "trait", "arms | legs | lungs | ... N", "a muscle (-1 to 1) or skill (0 to 1)"},
	{"Him", "need", "carbs | protein | ... N", "one of his stores and needs (0 to 100)"},
	{"Him", "bruises", "N", "this many points off the top of his stamina"},
	{"Him", "stamina", "N", "his stamina"},
	{"Him", "sack", "ITEM [N] | pie | full | empty", "things into his sack (pie: what an apple pie needs)"},
	{"Him", "choose", "ITEM", "this chosen in his sack"},
	{"Him", "outfit", "explorer | metalhead | ... | bare", "a whole outfit"},
	{"Make happen", "wind", "", "he passes wind"},
	{"Make happen", "hiccup", "", "a hiccup"},
	{"Make happen", "tipsy", "", "the tipsy stagger"},
	{"Make happen", "eat", "ITEM", "he eats one (put in his sack first)"},
	{"Make happen", "dizzy", "", "he is dazed for a moment"},
	{"Make happen", "faint", "", "he faints (the game is over)"},
	{"Make happen", "animal", "chase | dizzy | dead | swim", "the nearest animal does it"},
	{"Time", "pause", "", "the game stands still (or goes on again)"},
	{"Time", "step", "[N]", "one frame on (or N), when paused"},
	{"Time", "speed", "1 | 0.5 | 0.25 | 0.1 | 2 | 4", "slow motion or fast forward"},
	{"Look", "zoom", "N | game", "the camera further (more than 1) or closer; game: as the game has it"},
	{"Look", "portrait", "", "the camera in close on him (or back)"},
	{"Look", "free camera", "", "arrows move the camera, Prosio stands; again to end"},
	{"Look", "follow", "him | goat | billy | fox | turkey", "the camera on him, or on the nearest animal"},
	{"Set-ups", "reset", "", "a fresh meadow and a fresh Prosio"},
	{"Set-ups", "save", "NAME", "the current set-up, under this name"},
	{"Set-ups", "load", "NAME", "a saved set-up: a fresh scene, and its commands"},
	{"Set-ups", "replay", "", "the current set-up again, from a fresh scene (F5)"},
	{"Set-ups", "setups", "", "the saved set-ups"},
	{"Editor", "edit", "", "the editor shown or hidden (F2)"},
	{"Editor", "open", "PATH[:LINE]", "a file in the editor, at a line"},
	{"Show", "show", "collisions | animals | grid | regions | growth | body | timing", "draws what is hidden over the world (again to hide)"},
	{"Show", "set", "FIELD VALUE", "a number, flag or choice of the selected thing (or click it in the inspector)"},
	{"Workbench", "skin", "on | off", "Prosio's skin made in Blender on the bare pig (rebuilds)"},
	{"Workbench", "state", "", "how he is, in numbers"},
}

// Time and the camera, as the commands leave them. The workbench applies
// them each frame.
View :: struct {
	paused:   bool,
	steps:    int, // frames to run while paused
	speed:    f32,
	zoom:     f32, // 0: the game's own
	portrait: bool,
	free:     bool, // the camera moved by the arrows
	at:       game.Vec2, // where a free camera looks
	follow:   int, // the animal the camera is on (-1: him)
}

view := View{speed = 1, follow = -1}
setup: [dynamic]string

// Runs a command. ok: it did something. With record, a command that changes
// the game is added to the current set-up, as it can be run again.
run :: proc(line: string, record := true) -> (answer: string, ok: bool) {
	words := strings.fields(strings.to_lower(line, context.temp_allocator), context.temp_allocator)
	if len(words) == 0 {
		return "", false
	}
	p := &game.g.prosio
	replay_as := strings.join(words, " ", context.temp_allocator)
	changes := true // a command that changes the game, and so belongs in a set-up
	switch words[0] {
	case "go":
		if len(words) < 2 {
			return "go where?", false
		}
		to, found := place_named(words[1:])
		if !found {
			return fmt.tprintf("no place called %s", strings.join(words[1:], " ", context.temp_allocator)), false
		}
		move_him(to)
		replay_as = fmt.tprintf("go %v %v", to.x, to.y) // (exactly, so a replay puts him just there)
		answer = fmt.tprintf("at (%.2f, %.2f)", to.x, to.y)
	case "put":
		if len(words) < 2 {
			return "put what?", false
		}
		if words[1] == "crowd" {
			n := len(words) > 2 ? int_of(words[2], 9) : 9
			answer = put_crowd(n)
			break
		}
		if words[1] == "pen" {
			answer, ok = put_pen()
			if !ok {
				return
			}
			break
		}
		at, given := at_of(words)
		answer, ok = put_thing(words[1], at, given)
		if !ok {
			return
		}
		replay_as = answer
	case "clear":
		game.g.enemy_count = 0
		answer = "no animals"
	case "kg":
		game.set_weight(f32_of(words, 1, p.kg))
		answer = fmt.tprintf("%.1f kg", p.kg)
	case "fat":
		p.fat = clamp(f32_of(words, 1, p.fat), 1, game.FAT_MAX - 1)
		p.kg = game.body_kg()
		answer = fmt.tprintf("%.1f kg of fat, %.1f kg in all", p.fat, p.kg)
	case "trait":
		t, found := enum_named(game.Trait, len(words) > 1 ? words[1] : "")
		if !found {
			return "which trait?", false
		}
		p.trait[t] = clamp(f32_of(words, 2, p.trait[t]), -1, 1)
		p.trait_was = p.trait
		p.kg = game.body_kg()
		answer = fmt.tprintf("%v %.2f", t, p.trait[t])
	case "need":
		n, found := enum_named(game.Need, len(words) > 1 ? words[1] : "")
		if !found {
			return "which need?", false
		}
		p.need[n] = clamp(f32_of(words, 2, p.need[n]), 0, 100)
		p.kg = game.body_kg()
		answer = fmt.tprintf("%v %.0f", n, p.need[n])
	case "bruises":
		game.bruise(f32_of(words, 1, 0))
		answer = "bruised"
	case "stamina":
		p.stamina = f32_of(words, 1, p.stamina)
		answer = fmt.tprintf("stamina %.0f", p.stamina)
	case "sack":
		answer, ok = fill_sack(words[1:])
		if !ok {
			return
		}
	case "choose":
		it, found := enum_named(game.Item, len(words) > 1 ? words[1] : "")
		if !found || p.sack[it] == 0 {
			return "not in his sack", false
		}
		p.sack_sel = it
		answer = fmt.tprintf("%v chosen", it)
	case "outfit":
		preset, found := enum_named(game.Preset, len(words) > 1 ? words[1] : "")
		if !found {
			return "which outfit?", false
		}
		game.outfit = game.PRESETS[preset]
		answer = fmt.tprintf("%v", preset)
	case "wind", "hiccup", "tipsy":
		if p.fail != .None || p.airborne || (words[0] == "hiccup" && p.carry != .Nothing) {
			return "not now (in the air, holding something, or the game is over)", false
		}
		switch words[0] {
		case "wind": game.pass_gas()
		case "hiccup": game.start_hiccup()
		case "tipsy": p.tipsy_pose_t = game.PROSIO_REACTION_TIME.z
		}
		answer = words[0]
	case "eat":
		it, found := enum_named(game.Item, len(words) > 1 ? words[1] : "pumpkin")
		if !found {
			return "eat what?", false
		}
		if p.fail != .None || p.eat_t > 0 || p.carry != .Nothing {
			return "not now", false
		}
		if p.sack[it] == 0 {
			game.sack_add(it, game.item_kcal(it))
		}
		p.sack_sel = it
		game.eat_from_sack()
		answer = fmt.tprintf("he eats %v", it)
	case "dizzy":
		p.dazed_t = 2
		answer = "dazed"
	case "faint":
		p.fail, p.fail_t = .Fainted, 0
		answer = "fainted"
	case "animal":
		i := nearest_animal(nil)
		if i < 0 {
			return "no animal", false
		}
		e := &game.g.enemies[i]
		switch len(words) > 1 ? words[1] : "" {
		case "chase": e.state = .Chase
		case "dizzy": e.state, e.timer = .Dizzy, 3
		case "dead": e.state, e.ko, e.health, e.body_t = .Dead, true, 0, game.BODY_LIFE
		case "swim":
			e.pos = game.POND
			e.state = .Swimming
		case: return "chase, dizzy, dead or swim?", false
		}
		replay_as = fmt.tprintf("animal %s", words[1])
		answer = fmt.tprintf("the %v %s", e.kind, words[1])
	case "pause":
		view.paused = !view.paused
		changes = false
		answer = view.paused ? "paused" : "going on"
	case "step":
		view.paused = true
		view.steps += len(words) > 1 ? int_of(words[1], 1) : 1
		changes = false
		answer = fmt.tprintf("%d frames on", view.steps)
	case "speed":
		view.speed = clamp(f32_of(words, 1, 1), 0.05, 8)
		changes = false
		answer = fmt.tprintf("speed %.2f", view.speed)
	case "zoom":
		changes = false
		if len(words) > 1 && words[1] == "game" {
			view.zoom = 0
			return "the game's zoom", true
		}
		view.zoom = clamp(f32_of(words, 1, 1), 0.2, 4)
		view.portrait = false
		answer = fmt.tprintf("zoom %.2f", view.zoom)
	case "portrait":
		view.portrait = !view.portrait
		changes = false
		answer = view.portrait ? "portrait" : "portrait off"
	case "free":
		view.free = !view.free
		view.at = game.g.camera
		changes = false
		answer = view.free ? "free camera: the arrows move it" : "the camera follows again"
	case "follow":
		changes = false
		view.free = false
		if len(words) < 2 || words[1] == "him" {
			view.follow = -1
			return "following him", true
		}
		kind, found := enum_named(game.Enemy_Kind, words[1])
		if !found {
			return "follow whom?", false
		}
		view.follow = nearest_animal(&kind)
		if view.follow < 0 {
			return "none about", false
		}
		answer = fmt.tprintf("following a %v", kind)
	case "reset":
		reset()
		return "a fresh scene", true
	case "save":
		if len(words) < 2 {
			return "save it as what?", false
		}
		return save_setup(words[1])
	case "load":
		if len(words) < 2 {
			return "load which?", false
		}
		return load_setup(words[1])
	case "replay":
		return replay(), true
	case "setups":
		return list_setups(), true
	case "skin", "edit", "open", "show", "set":
		return "(the workbench's window does this)", false
	case "state":
		changes = false
		answer = fmt.tprintf("frame %d, at (%.2f, %.2f), %.1f kg (fat %.1f), stamina %.0f, %d animals, %v, %v",
			game.g.frame, p.pos.x, p.pos.y, p.kg, p.fat, p.stamina, game.g.enemy_count, game.scene, view.paused ? "paused" : "running")
	case:
		return fmt.tprintf("not a command: %s", words[0]), false
	}
	if record && changes {
		append(&setup, strings.clone(replay_as))
	}
	return answer, true
}

reset :: proc() {
	game.new_game()
	game.explore(game.g.prosio.pos)
	game.scene = .Playing
	clear(&setup)
	view.follow = -1
	view.free = false
}

// A fresh scene, then the current set-up again.
replay :: proc() -> string {
	lines := slice.clone(setup[:], context.temp_allocator)
	reset()
	failed := 0
	for line in lines {
		if _, ok := run(line); !ok {
			failed += 1
		}
	}
	return fmt.tprintf("replayed %d commands%s", len(lines), failed > 0 ? fmt.tprintf(", %d did nothing", failed) : "")
}

// The current set-up as text, a command a line (for saving, and for handing
// to the next library when the state changes shape).
setup_text :: proc() -> string {
	b := strings.builder_make(context.temp_allocator)
	for line in setup {
		strings.write_string(&b, line)
		strings.write_byte(&b, '\n')
	}
	return strings.to_string(b)
}

// A fresh scene and these commands.
run_setup :: proc(text: string) -> (done, failed: int) {
	reset()
	for line in strings.split_lines(text, context.temp_allocator) {
		trimmed := strings.trim_space(line)
		if trimmed == "" || strings.has_prefix(trimmed, "#") {
			continue
		}
		if _, ok := run(trimmed); ok {
			done += 1
		} else {
			failed += 1
		}
	}
	return
}

save_setup :: proc(name: string) -> (string, bool) {
	_ = os.make_directory_all(SETUP_DIR)
	path := fmt.tprintf("%s/%s.txt", SETUP_DIR, name)
	if err := os.write_entire_file(path, transmute([]byte)setup_text()); err != nil {
		return fmt.tprintf("cannot write %s", path), false
	}
	return fmt.tprintf("saved %d commands as %s", len(setup), path), true
}

load_setup :: proc(name: string) -> (string, bool) {
	path := fmt.tprintf("%s/%s.txt", SETUP_DIR, name)
	text, err := os.read_entire_file(path, context.temp_allocator)
	if err != nil {
		return fmt.tprintf("no set-up %s", path), false
	}
	done, failed := run_setup(string(text))
	return fmt.tprintf("%s: %d commands%s", name, done, failed > 0 ? fmt.tprintf(", %d did nothing", failed) : ""), true
}

list_setups :: proc() -> string {
	entries, err := os.read_all_directory_by_path(SETUP_DIR, context.temp_allocator)
	if err != nil || len(entries) == 0 {
		return "none saved"
	}
	names: [dynamic]string
	for e in entries {
		if strings.has_suffix(e.name, ".txt") {
			append(&names, strings.trim_suffix(e.name, ".txt"))
		}
	}
	slice.sort(names[:])
	return strings.join(names[:], ", ", context.temp_allocator)
}

// Places by name: home, a station, a region, the nearest of an animal kind,
// or X Y.
place_named :: proc(words: []string) -> (to: game.Vec2, found: bool) {
	p := &game.g.prosio
	r := game.prosio_radius(p.kg)
	if len(words) >= 2 {
		x, okx := strconv.parse_f32(words[0])
		y, oky := strconv.parse_f32(words[1])
		if okx && oky {
			return {x, y}, true
		}
	}
	if s, ok := enum_named(game.Station_Kind, words[0]); ok {
		return place_round(game.g.stations[s].pos, game.STATION_RADIUS[s] + r + PLACE_GAP, r)
	}
	if words[0] == "pond" {
		return place_round(game.POND, game.POND_RADIUS + r + PLACE_GAP, r)
	}
	if region, ok := enum_named(game.Region_Kind, words[0]); ok {
		return place_round(game.REGIONS[region].centre, 0, r)
	}
	if kind, ok := enum_named(game.Enemy_Kind, words[0]); ok {
		i := nearest_animal(&kind)
		if i < 0 {
			return {}, false
		}
		e := game.g.enemies[i]
		return place_round(e.pos, game.ENEMY_RADIUS[e.kind] + r + PLACE_GAP, r)
	}
	return {}, false
}

move_him :: proc(to: game.Vec2) {
	p := &game.g.prosio
	p.pos, p.vel, p.height, p.vy, p.airborne = to, {}, 0, 0, false
	game.g.camera = to
	game.explore(to)
	view.free = false
}

// A free spot this far from centre, tried round a circle, nearest first to
// the way he faces; at the centre itself when distance is 0.
place_round :: proc(centre: game.Vec2, distance, radius: f32) -> (game.Vec2, bool) {
	if distance == 0 && free(centre, radius) {
		return centre, true
	}
	for ring in 0 ..< 6 {
		d := max(distance, 0.5) + f32(ring) * 1.5
		for i in 0 ..< PLACE_STEPS {
			angle := game.g.prosio.facing + f32((i + 1) / 2) * f32(1 - 2 * (i % 2)) * math.TAU / PLACE_STEPS
			spot := centre + game.facing_dir(angle) * d
			if free(spot, radius) {
				return spot, true
			}
		}
	}
	return {}, false
}

free :: proc(spot: game.Vec2, radius: f32) -> bool {
	probe := spot
	hit, _ := game.collide_static(&probe, radius, 0, true)
	if hit || game.in_pond(spot) || game.beyond_edge(spot) + radius >= 0 {
		return false
	}
	for e in game.g.enemies[:game.g.enemy_count] {
		if game.length2(spot - e.pos) < radius + game.ENEMY_RADIUS[e.kind] {
			return false
		}
	}
	return true
}

// Something put in front of him (or at the place given). The answer is the
// command as it can be run again.
put_thing :: proc(what: string, at: game.Vec2, given: bool) -> (string, bool) {
	p := &game.g.prosio
	front :: proc(r: f32) -> (game.Vec2, bool) {
		p := &game.g.prosio
		return place_round(p.pos, game.prosio_radius(p.kg) + r + PLACE_GAP, r)
	}
	name := strings.to_lower(what, context.temp_allocator)
	if name == "fallen-goat" || name == "fallen_goat" {
		name = "goat"
	}
	if kind, ok := enum_named(game.Enemy_Kind, name); ok {
		if game.g.enemy_count == len(game.g.enemies) {
			return "no room for another animal", false
		}
		pos, found := at, given
		if !given {
			pos, found = front(game.ENEMY_RADIUS[kind])
		}
		if !found {
			return "no room in front of him", false
		}
		game.add_enemy(kind, pos)
		if what == "fallen-goat" || what == "fallen_goat" {
			e := &game.g.enemies[game.g.enemy_count - 1]
			e.state, e.ko, e.health, e.body_t = .Dead, true, 0, game.BODY_LIFE
		}
		return fmt.tprintf("put %s at %v %v", what, pos.x, pos.y), true
	}
	r: f32 = name == "rock" ? ROCK_RADIUS : APPLE_RADIUS
	pos, found := at, given
	if !given {
		pos, found = front(r)
	}
	if !found {
		return "no room in front of him", false
	}
	switch name {
	case "rock":
		if game.add_round(pos, r, .Rock) < 0 {
			return "no room for another rock", false
		}
	case "scarecrow":
		if !game.add_scarecrow(pos) {
			return "it will not stand there", false
		}
	case "larder":
		if !game.add_larder(pos) {
			return "it will not stand there", false
		}
	case:
		kind, ok := enum_named(game.Food_Kind, name)
		if !ok {
			return fmt.tprintf("nothing called %s to put", what), false
		}
		f := game.add_food(kind, pos)
		if f == nil {
			return "no room for more", false
		}
		f.fallen, f.life, f.size = true, 1e9, 1
	}
	_ = p
	return fmt.tprintf("put %s at %v %v", what, pos.x, pos.y), true
}

put_crowd :: proc(count: int) -> string {
	p := &game.g.prosio
	n := clamp(count, 0, game.MAX_ENEMIES)
	game.g.enemy_count = 0
	kinds := [3]game.Enemy_Kind{.Goat, .Billy, .Fox}
	for i in 0 ..< n {
		angle := f32(i) * 2.399
		game.add_enemy(kinds[i % 3], p.pos + {math.cos(angle), math.sin(angle)} * (2.5 + f32(i) * 0.35))
	}
	return fmt.tprintf("%d animals round him", game.g.enemy_count)
}

// A turkey in a pen of one square beside him, its near side a gate.
put_pen :: proc() -> (string, bool) {
	p := &game.g.prosio
	x, y := game.fence_cell(p.pos + {3, 0})
	for f in ([4]game.Fence_At{{x, y, .East}, {x, y + 1, .East}, {x, y, .South}, {x + 1, y, .South}}) {
		game.set_fence(f, true)
	}
	game.set_gate({x, y + 1, .East}, game.GATE_SHUT)
	corner, _ := game.fence_ends({x, y, .East})
	if game.g.enemy_count == len(game.g.enemies) {
		return "no room for the turkey", false
	}
	game.add_enemy(.Turkey, corner + {game.FENCE_LEN, game.FENCE_LEN} / 2)
	return "a turkey in a pen", true
}

fill_sack :: proc(words: []string) -> (string, bool) {
	p := &game.g.prosio
	if len(words) == 0 {
		return "what into the sack?", false
	}
	switch words[0] {
	case "full":
		for it in game.Item {
			for _ in 0 ..< (it < game.FIRST_DISH || it == .Wood ? 3 : 1) {
				game.sack_add(it, game.item_kcal(it))
			}
		}
		return "a full sack", true
	case "empty":
		p.sack = {}
		return "an empty sack", true
	case "pie":
		for need in game.recipe_for(.Apple_Pie).needs {
			missing := max(0, need.count - p.sack[need.item]) // (worked out first: the sack fills as it goes)
			for _ in 0 ..< missing {
				game.sack_add(need.item, game.item_kcal(need.item))
			}
		}
		return "what an apple pie needs", true
	}
	it, found := enum_named(game.Item, words[0])
	if !found {
		return fmt.tprintf("no such thing: %s", words[0]), false
	}
	n := len(words) > 1 ? int_of(words[1], 1) : 1
	for _ in 0 ..< n {
		game.sack_add(it, game.item_kcal(it))
	}
	return fmt.tprintf("%d %v", n, it), true
}

// The nearest animal still about (of this kind, if one is given): -1 if none.
nearest_animal :: proc(kind: ^game.Enemy_Kind) -> int {
	p := &game.g.prosio
	best, best_d := -1, f32(math.F32_MAX)
	for e, i in game.g.enemies[:game.g.enemy_count] {
		if e.state == .Gone || (kind != nil && e.kind != kind^) {
			continue
		}
		if d := game.length2(e.pos - p.pos); d < best_d {
			best, best_d = i, d
		}
	}
	return best
}

// A value of an enum by its name, in any case, with - for _.
enum_named :: proc($E: typeid, name: string) -> (E, bool) {
	want, _ := strings.replace_all(name, "-", "_", context.temp_allocator)
	for v in E {
		if strings.equal_fold(fmt.tprintf("%v", v), want) {
			return v, true
		}
	}
	return {}, false
}

f32_of :: proc(words: []string, i: int, fallback: f32) -> f32 {
	if i >= len(words) {
		return fallback
	}
	v, ok := strconv.parse_f32(words[i])
	return ok ? v : fallback
}

int_of :: proc(word: string, fallback: int) -> int {
	v, ok := strconv.parse_int(word)
	return ok ? v : fallback
}

// "... at X Y" at the end of a command.
at_of :: proc(words: []string) -> (game.Vec2, bool) {
	for w, i in words {
		if w == "at" && i + 2 < len(words) {
			x, okx := strconv.parse_f32(words[i + 1])
			y, oky := strconv.parse_f32(words[i + 2])
			if okx && oky {
				return {x, y}, true
			}
		}
	}
	return {}, false
}

// What the camera does this frame, after the game has moved it: the
// workbench calls this once a frame.
apply_view :: proc(dt: f32) {
	g := &game.g
	if view.follow >= 0 && view.follow < g.enemy_count {
		g.camera = g.enemies[view.follow].pos
	}
	if view.free {
		g.camera = view.at
	}
	if view.portrait {
		g.camera = g.prosio.pos
		g.camera_zoom = PORTRAIT_ZOOM
	} else if view.zoom > 0 {
		g.camera_zoom = view.zoom
	}
}

// The workbench's own state, as text, to be handed to the next library on a
// swap (each library has its own): the set-up, a command a line, then the
// time and camera on a line of their own.
workbench_text :: proc() -> string {
	v := view
	return fmt.tprintf("%s#view %v %d %f %f %v %v %f %f %d\n", setup_text(), v.paused, v.steps, v.speed, v.zoom, v.portrait, v.free, v.at.x, v.at.y, v.follow)
}

take_workbench_text :: proc(text: string) {
	clear(&setup)
	for line in strings.split_lines(text, context.temp_allocator) {
		trimmed := strings.trim_space(line)
		if strings.has_prefix(trimmed, "#view ") {
			w := strings.fields(trimmed, context.temp_allocator)
			if len(w) == 10 {
				view.paused = w[1] == "true"
				view.steps = int_of(w[2], 0)
				view.speed = f32_of(w, 3, 1)
				view.zoom = f32_of(w, 4, 0)
				view.portrait = w[5] == "true"
				view.free = w[6] == "true"
				view.at = {f32_of(w, 7, 0), f32_of(w, 8, 0)}
				view.follow = int_of(w[9], -1)
			}
		} else if trimmed != "" {
			append(&setup, strings.clone(trimmed))
		}
	}
}
