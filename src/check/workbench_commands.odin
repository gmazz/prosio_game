package check

import game "../game"
import cmd "../workbench/commands"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

// The workbench's commands (src/workbench/commands), which replaced the Test
// Meadow: each changes the game as the game itself would, so what is set up
// with them is played with the real controls. (The check program may use
// them: it is not the game the players get.)
rules_workbench_commands :: proc() {
	section("the workbench's commands")
	fresh()
	p := &game.g.prosio
	run :: proc(line: string) -> bool {
		_, ok := cmd.run(line)
		return ok
	}
	first_kg := p.kg
	ok := run("fat 85") && run("trait arms 1") && run("trait legs -1") && run("trait lungs 0.75")
	check("the workbench's body commands change his body and weight as the game reckons them",
		ok && p.kg > first_kg && p.kg == game.body_kg() && p.trait[.Arms] == 1 && p.trait[.Legs] == -1 && p.trait[.Lungs] == .75 && p.fat == 85)

	fresh()
	fallen := run("clear animals") && run("put fallen-goat")
	step(1, {}, {.Grab})
	check("a goat put down fallen can be grabbed with the real controls", fallen && p.carry == .Enemy && game.g.enemies[p.carry_index].ko)

	fresh()
	apple := run("clear animals") && run("put apple")
	first_apples := p.sack[.Apple]
	step(1, {}, {.Action})
	check("an apple put down is gathered as any apple, and eating a pumpkin fills his belly",
		apple && p.sack[.Apple] > first_apples && run("eat pumpkin") && p.meal_target > 0)

	fresh()
	rock := run("clear animals") && run("put rock")
	target, close := game.grab_target()
	check("a rock put down is one he can grab", rock && close && target.kind == .Rock)

	fresh()
	answer, loaded := cmd.load_setup("meadow")
	oven := run("go oven")
	step(1, {}, {.Action})
	in_menu := game.scene == .Oven
	game.forced_pressed = {.Action}
	game.update_cook_menu(1.0 / 60)
	game.forced_pressed = {}
	check("the meadow set-up (the Test Meadow's scene) loads, and has what an apple pie needs at the oven",
		loaded && strings.contains(answer, "9 commands") && oven && in_menu && game.g.stations[.Oven].baking, fmt.tprintf("%s; at the oven %v, its menu %v, baking %v; he is at (%.2f, %.2f), the oven at (%.2f, %.2f)", answer, oven, in_menu, game.g.stations[.Oven].baking, p.pos.x, p.pos.y, game.g.stations[.Oven].pos.x, game.g.stations[.Oven].pos.y))

	fresh()
	cmd.reset()
	built := run("kg 110") && run("go hills") && run("put goat") && run("put rock") && run("trait legs 0.5") && run("sack apple 3")
	Snapshot :: struct {
		pos:     game.Vec2,
		kg:      f32,
		animals: int,
		legs:    f32,
		apples:  int,
		last:    game.Vec2,
	}
	snap :: proc() -> Snapshot {
		p := &game.g.prosio
		return {p.pos, p.kg, game.g.enemy_count, p.trait[.Legs], int(p.sack[.Apple]), game.g.enemies[game.g.enemy_count - 1].pos}
	}
	before := snap()
	recorded := strings.contains(cmd.setup_text(), "put goat at ")
	cmd.replay()
	check("a set-up replayed from a fresh scene gives the same scene, each command kept as it can be run again (\"put goat at X Y\")",
		built && recorded && snap() == before, fmt.tprintf("%d commands", len(cmd.setup)))

	unknown: [dynamic]string
	for c in cmd.COMMANDS {
		fresh()
		if said, _ := cmd.run(c.name); strings.has_prefix(said, "not a command") {
			append(&unknown, c.name)
		}
	}
	check("every command the menu lists is one the workbench knows", len(unknown) == 0,
		fmt.tprintf("%v", unknown))

	// Asked for more animals than there is room for, the commands stop at
	// the room the game has. (The first crowd command added its animals to
	// the 33 already there: crowd 12 wrote past the last of the 40 places,
	// and the workbench stopped dead; crash report workbench-...-032025.)
	fresh()
	room_ok := true
	_, _ = cmd.run("put crowd 60")
	room_ok &&= game.g.enemy_count == game.MAX_ENEMIES
	for _ in 0 ..< 20 {
		_, _ = cmd.run("put goat")
		_, _ = cmd.run("put pen")
		_, _ = cmd.run("put fallen-goat")
	}
	check("the workbench's commands never put more animals than the game has room for (put crowd 60, then goats, pens and fallen goats on top)",
		room_ok && game.g.enemy_count <= game.MAX_ENEMIES, fmt.tprintf("%d animals, room for %d", game.g.enemy_count, game.MAX_ENEMIES))

	// A swap is only as safe as what the libraries share and keep. Each
	// library exports only its wb_ procedures: anything else of Odin's runtime
	// it exported would be shared with the host and every earlier library,
	// as its eight thread-local slots were, which filled after seven swaps
	// (crash report workbench-...-031718: "no more thread-local cleaner slots"
	// as the eighth library started). And each library swapped out frees what
	// its runtime kept for the thread (about 11 MB a swap otherwise).
	host, _ := os.read_entire_file("src/workbench/host/main.odin", context.temp_allocator)
	lib, _ := os.read_entire_file("src/workbench/lib.odin", context.temp_allocator)
	h, l := string(host), string(lib)
	exports_only := strings.contains(h, "os.write_entire_file(exports_file, \"_wb_*\\n\")") && strings.contains(h, "-exported_symbols_list,")
	release := strings.index(h, "api.release()")
	released := release >= 0 && release < strings.index(h, "\tapi = next") && strings.contains(l, "wb_release :: proc() {\n\truntime.run_thread_local_cleaners()")
	check("each library the workbench swaps in exports only its wb_ procedures, and each one swapped out frees what its runtime kept for the thread",
		exports_only && released, fmt.tprintf("exports only wb_: %v; the old library released before the next takes over: %v", exports_only, released))
}

// The index (src/workbench/commands/index.odin): what moves, draws, tunes and
// makes each kind of thing, for the workbench to open. Every kind has an
// entry (the tables are indexed by the game's kinds, so the workbench would
// not build without one), and every entry leads to something that is there.
rules_workbench_index :: proc() {
	bad: [dynamic]string
	kinds := 0
	look :: proc(name: string, entries: []cmd.Entry, bad: ^[dynamic]string, kinds: ^int) {
		kinds^ += 1
		codes := 0
		if len(entries) == 0 {append(bad, fmt.tprintf("%s has no entry", name))}
		for e in entries {
			if e.file == "" {
				codes += 1
				if e.at.line <= 0 || !os.exists(e.at.file_path) {append(bad, fmt.tprintf("%s: %s leads nowhere", name, e.label))}
				continue
			}
			text, err := os.read_entire_file(e.file, context.temp_allocator)
			if err != nil {
				append(bad, fmt.tprintf("%s: %s, %s is not there", name, e.label, e.file))
			} else if e.find != "" && !strings.contains(string(text), e.find) {
				append(bad, fmt.tprintf("%s: %s, %q is not in %s", name, e.label, e.find, e.file))
			}
		}
		if codes == 0 {append(bad, fmt.tprintf("%s has no procedure", name))}
	}
	for k in cmd.Other {look(fmt.tprintf("%v", k), cmd.index_of(k), &bad, &kinds)}
	for k in game.Enemy_Kind {look(fmt.tprintf("%v", k), cmd.index_of(k), &bad, &kinds)}
	for k in game.Round_Kind {look(fmt.tprintf("%v", k), cmd.index_of(k), &bad, &kinds)}
	for k in game.Food_Kind {look(fmt.tprintf("%v", k), cmd.index_of(k), &bad, &kinds)}
	for k in game.Pest_Kind {look(fmt.tprintf("%v", k), cmd.index_of(k), &bad, &kinds)}
	for k in game.Decor_Kind {look(fmt.tprintf("%v", k), cmd.index_of(k), &bad, &kinds)}
	check("the workbench's index says, for every kind of thing in the game, what moves, draws and tunes it, and every entry leads to a procedure or file that is there",
		len(bad) == 0, len(bad) > 0 ? fmt.tprintf("%d wrong, such as %s", len(bad), bad[0]) : fmt.tprintf("%d kinds", kinds))
}

// The workbench's own keys (src/workbench/keys.txt): every line of it reads,
// and as it stands it gives Shift+1 to Shift+6 (! @ # $ % ^: a compact keyboard
// has no F keys) to the menu, the editor, replaying, pausing, stepping and the pane.
// The game is given no keys on the frame one of them acts (menu.odin).
rules_workbench_keys :: proc() {
	text, err := os.read_entire_file("src/workbench/keys.txt", context.temp_allocator)
	keys, trouble := cmd.parse_keys(string(text))
	given := ""
	for action in cmd.Bench_Action {
		given = fmt.tprintf("%s%s%v %s", given, given == "" ? "" : ", ", action, cmd.key_text(keys.keys[action][0]))
	}
	check("src/workbench/keys.txt reads, and gives Shift+1 to Shift+6 to the workbench's menu, editor, replay, pause, step and pane",
		err == nil && trouble == "" && given == "Menu Shift+1, Editor Shift+2, Replay Shift+3, Pause Shift+4, Step Shift+5, Panes Shift+6", trouble != "" ? trouble : given)
	_, bad := cmd.parse_keys("menu Shift+F13\nlook F1")
	check("a key keys.txt cannot read is said, not taken", bad != "", bad)
}

// The workbench's panes (src/workbench/panes.odin): the numbers marked
// "tune" in data/tuning/*.json can be turned while the game runs, in the
// workbench's build only (there they are variables; in the game the players
// get they are constants, as every other); Save writes a number back into its
// file and changes nothing else in it; and the pane's test rig (a stand, an
// animal held still, no mending, a jump set by hand) is not in the players'
// game at all.
rules_workbench_panes :: proc() {
	section("the workbench's panes")
	// Every value marked "tune" is listed for the panes, and a single one is
	// a variable only in the workbench's build.
	tuning, _ := filepath.glob("data/tuning/*.json", context.temp_allocator)
	listing, _ := os.read_entire_file("src/game/gen_tune.odin", context.temp_allocator)
	marked, missing := 0, ""
	for path in tuning {
		text, _ := os.read_entire_file(path, context.temp_allocator)
		subject := strings.trim_suffix(filepath.base(path), ".json")
		generated, _ := os.read_entire_file(fmt.tprintf("src/game/gen_%s.odin", subject), context.temp_allocator)
		for line in strings.split_lines(string(text), context.temp_allocator) {
			if !strings.contains(line, "\"tune\":") {continue}
			start := strings.index_byte(line, '"')
			name := line[start + 1:][:strings.index_byte(line[start + 1:], '"')]
			marked += 1
			listed := strings.contains(string(listing), fmt.tprintf("{{\"%s\", \"%s\"", name, subject))
			both := strings.contains(string(generated), fmt.tprintf("%s := [", name)) || strings.contains(string(generated), fmt.tprintf("%s := #partial [", name)) || strings.contains(string(generated), fmt.tprintf("when WORKBENCH {{\n\t%s: f32 = ", name)) && strings.contains(string(generated), fmt.tprintf("\t%s :: f32(", name))
			if !listed || !both {missing = name}
		}
	}
	check("every number marked \"tune\" in data/tuning is listed for the workbench's panes, and is a variable there and a constant in the game the players get",
		marked >= 20 && missing == "", missing != "" ? fmt.tprintf("%s is not", missing) : fmt.tprintf("%d marked", marked))

	// Save: only the number changes, a single value, an entry of a table, or
	// a sum (which becomes the number it came to).
	sample := "{\n  \"a\": {\n    \"HEAL_RAMP\": {\"f32\": 20, \"tune\": \"attacks\", \"about\": \"the \\\"Goat\\\": 1 of it\"},\n    \"ENEMY_HIDE\": {\"[Enemy_Kind]f32\": {\"Turkey\": 1, \"Goat\": 0.8}, \"about\": \"x\"},\n    \"HEAL_RATE\": {\"f32\": \"ENEMY_HEALTH / 30\", \"about\": \"y\"}\n  }\n}\n"
	one, ok1 := cmd.json_set_value(sample, "HEAL_RAMP", "", 25)
	two, ok2 := cmd.json_set_value(one, "ENEMY_HIDE", "Goat", 0.6)
	three, ok3 := cmd.json_set_value(two, "HEAL_RATE", "", 4.5)
	_, none := cmd.json_set_value(sample, "NOT_THERE", "", 1)
	want := "{\n  \"a\": {\n    \"HEAL_RAMP\": {\"f32\": 25, \"tune\": \"attacks\", \"about\": \"the \\\"Goat\\\": 1 of it\"},\n    \"ENEMY_HIDE\": {\"[Enemy_Kind]f32\": {\"Turkey\": 1, \"Goat\": 0.6}, \"about\": \"x\"},\n    \"HEAL_RATE\": {\"f32\": 4.5, \"about\": \"y\"}\n  }\n}\n"
	check("a pane's Save writes a number into its data file and changes nothing else there: a single value, an entry of a table, a sum (which becomes its number); a name not there is said",
		ok1 && ok2 && ok3 && !none && three == want && cmd.number_text(0.0053) == "0.0053" && cmd.number_text(600) == "600", three)

	// The test rig is the workbench's: in the players' game nothing of it acts.
	check("the pane's test rig is not in the game the players get: no stand, no animal held still, mending always on, his jump his own",
		!game.WORKBENCH && game.floor_at({0, 0}) == 0 && !game.held_still(0) && game.mends() && game.jump_set(0.45) == 0.45)
}

// A pane's Save reaches the real game: the number written into its data
// file is what tools/gen_data writes into the game's code (so the next
// build, desktop or web, plays with it); and before it writes, the files as
// they were last saved are backed up, named for when, as the game's own
// backups are, and can be listed newest first and loaded again.
rules_workbench_param_sets :: proc() {
	section("saved parameter sets")
	// Save, then the generator, on a copy of the data.
	ROOT :: "build/check/tune_root"
	root := ROOT
	os.remove_all(root)
	os.make_directory_all(ROOT + "/data/tuning")
	os.make_directory_all(ROOT + "/data/text")
	os.make_directory_all(ROOT + "/src/game")
	for dir in ([]string{"data/tuning", "data/text"}) {
		files, _ := filepath.glob(fmt.tprintf("%s/*.json", dir), context.temp_allocator)
		for f in files {
			data, _ := os.read_entire_file(f, context.temp_allocator)
			_ = os.write_entire_file(fmt.tprintf("%s/%s/%s", root, dir, filepath.base(f)), data)
		}
	}
	path := ROOT + "/data/tuning/animals.json"
	data, _ := os.read_entire_file(path, context.temp_allocator)
	saved, ok := cmd.json_set_value(string(data), "ENEMY_HIDE", "Goat", 0.625)
	_ = os.write_entire_file(path, transmute([]byte)saved)
	state, _, _, err := os.process_exec({command = {"build/tools/gen_data", root}}, context.temp_allocator)
	code, _ := os.read_entire_file(ROOT + "/src/game/gen_animals.odin", context.temp_allocator)
	reaches := ok && err == nil && state.exit_code == 0 && strings.contains(string(code), ".Goat = 0.625,")
	check("a number a pane saves into its data file is what tools/gen_data writes into the game's code, so the next build of the game, desktop or web, plays with it",
		reaches, fmt.tprintf("ENEMY_HIDE Goat saved as 0.625: in gen_animals.odin %v", reaches))
	os.remove_all(root)

	// The backups' names, as the game's: tuning_DDMMYY_HHMMSS.
	c := game.Clock{2026, 11, 26, 14, 30, 15}
	name := cmd.tuning_backup_name(c)
	back, read := cmd.tuning_backup_time(name)
	_, bad := cmd.tuning_backup_time("tuning_261126_1430")
	_, bad2 := cmd.tuning_backup_time("prosio_261126_143015")
	check("a backup of the parameters is named for when they were saved, as the game names its own (tuning_261126_143015: 26 November 2026, 14:30:15), and a name that is not one is not taken for one",
		name == "tuning_261126_143015" && read && back == c && !bad && !bad2 && game.clock_order({2026, 11, 26, 14, 30, 16}) > game.clock_order(c), name)
}

// The editor's tabs close: each has an x; closing one with unsaved changes
// asks once (save, discard or stay) and Cmd+Shift+W closes it throwing them
// away, the file untouched; Cmd+W no longer quietly takes away the unsaved
// mark. And one workbench runs to a folder, since two would take each
// other's commands. (Read in the code: the window cannot be had here.)
rules_workbench_editor_close :: proc() {
	section("the editor's tabs")
	ed, _ := os.read_entire_file("src/workbench/editor.odin", context.temp_allocator)
	host, _ := os.read_entire_file("src/workbench/host/main.odin", context.temp_allocator)
	e, h := string(ed), string(host)
	closes := strings.contains(e, "editor_close(editor.current, shift)") && strings.contains(e, "if t.dirty && !discard {") && strings.contains(e, "draw_mono(\"x\"") && strings.contains(e, "case rl.IsKeyPressed(.D): editor_answer(t, .Discard)") && !strings.contains(e, "t.dirty = false // (a second Cmd+W closes it)")
	alone := strings.contains(h, "if other := running_here(); other != \"\" {") && strings.contains(h, "WORKBENCH_OUT")
	check("an editor tab has an x; closing one with unsaved changes asks (save, discard or stay), Cmd+Shift+W closes it throwing them away; and a second workbench on the same folder says so and stops",
		closes && alone, fmt.tprintf("closing %v, one to a folder %v", closes, alone))
}

// An animal the Attacks pane holds still still meets him: he cannot walk
// into it, and his bumps land; it only does not come for him or shove him.
// (Read in the code: the hold is only in the workbench's build.)
rules_workbench_still_animal :: proc() {
	en, _ := os.read_entire_file("src/game/enemies.odin", context.temp_allocator)
	e := string(en)
	at := strings.index(e, "if held_still(index) {")
	end := at >= 0 ? strings.index(e[at:], "continue") : -1
	meets := at >= 0 && end >= 0 && strings.contains(e[at:][:end], "touch_prosio(&e, false)")
	check("an animal the workbench holds still still meets him (touch_prosio, without shoving): he cannot walk into it, and his bumps land", meets)
}

// The Mixing pane's bowl in words ("mixing bowl ..."), read as
// tools/check.sh mix reads one: amounts in grams, millilitres, eggs or
// pinches, a food named in any case, plural or not.
rules_workbench_bowl_words :: proc() {
	parts, n, err := cmd.parse_bowl("500g flour, 300 ml Water, 2 eggs, 3 pinches salt")
	_, _, bad := cmd.parse_bowl("100g unobtainium")
	_, _, too_many := cmd.parse_bowl("1g flour, 1g water, 1g salt, 1g honey, 1g milk")
	ok := err == "" && n == 4 && parts[0] == {food = .Flour, amount = 500 / game.unit_grams(.Flour)} && parts[1] == {food = .Water, amount = 300 / game.unit_grams(.Water)} && parts[2] == {food = .Egg, amount = 2} && parts[3].food == .Salt && abs(parts[3].amount * game.unit_grams(.Salt) - 3 * game.PINCH_G) < 0.001
	check("the Mixing pane reads a bowl in words as tools/check.sh mix does (grams, millilitres, eggs, pinches), and says what it cannot",
		ok && bad != "" && too_many != "", fmt.tprintf("%v %d %s; %s; %s", parts, n, err, bad, too_many))
}
