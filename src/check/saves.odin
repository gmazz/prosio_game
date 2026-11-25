package check

import game "../game"
import "core:fmt"
import "core:os"
import "core:path/filepath"

// Where the check program's saved game and backups are: beside the program.
SAVE_FILE :: "build/check/prosio.sav"
SAVES_DIR :: "build/check/" + game.BACKUP_FOLDER

// Backups of the saved game and LOAD (game/saves.odin): Restart and Load each
// first copy the saved game, byte for byte, to a backup named for when it
// was saved; the list is newest first by the time in the names, at most
// BACKUP_LIST long; a loaded backup gives back the same Prosio; a misnamed
// or damaged file is ignored or cannot be chosen; nothing is written or
// listed under no_save.
rules_backups :: proc() {
	section("backups and loading")
	g := &game.g
	p := &g.prosio
	empty_saves()
	defer {
		empty_saves()
		game.clock_fixed = nil
		game.saved_at = nil
	}

	// A Prosio with things to lose: weight, skills, the sack, a hat, a fence
	// and a larder with honey in it.
	fresh()
	g.opts.no_save = false
	p.fat = 61.5
	p.trait[.Legs] = 0.4
	p.trait[.Baking] = 0.7
	game.sack_add(.Honey, 300)
	hat := game.outfit.hat
	game.outfit.hat = .Crown
	game.set_fence({20, 20, .East}, true)
	game.add_larder({8, 8})
	for &l in g.larders {
		if l.used {
			l.stock[.Apple] = 3
		}
	}
	step(1)
	fat, legs, baking := p.fat, p.trait[.Legs], p.trait[.Baking]
	game.clock_fixed = game.Clock{2026, 11, 25, 23, 15, 7}
	game.save_game()
	before, _ := os.read_entire_file(SAVE_FILE, context.temp_allocator)

	// Restart, from the pause menu.
	choose(.Paused, .Restart)
	backup, read_err := os.read_entire_file(SAVES_DIR + "/prosio_251126_231507.sav", context.temp_allocator)
	check("Restart first keeps the saved game as a backup, byte for byte, named for when it was saved",
		read_err == nil && len(before) > 0 && string(backup) == string(before) && p.fat != fat,
		fmt.tprintf("backup %d bytes, the save %d; after Restart fat %.1f", len(backup), len(before), p.fat))

	// The new Prosio plays on and is saved later; then the first is loaded.
	p.fat = 30
	step(1)
	game.clock_fixed = game.Clock{2026, 11, 26, 8, 0, 0}
	game.save_game()
	second, _ := os.read_entire_file(SAVE_FILE, context.temp_allocator)
	shown := false
	for item in game.menu_items() {
		shown ||= item == .Load
	}
	choose(.Paused, .Load)
	listed := game.scene == .Load && game.backup_count == 1
	press(.Confirm)
	larder_apples := 0
	for l in g.larders {
		if l.used {larder_apples += l.stock[.Apple]}
	}
	same := abs(p.fat - fat) < 0.01 && p.trait[.Legs] == legs && p.trait[.Baking] == baking && p.sack[.Honey] == 1 && game.outfit.hat == .Crown && game.fence_there({20, 20, .East}) && larder_apples == 3
	check("a loaded backup gives back the same Prosio: weight, skills, sack, hat, fences and larder", shown && listed && game.scene == .Playing && same,
		fmt.tprintf("LOAD shown %v, listed %v, fat %.1f (was %.1f), honey %d, hat %v, larder apples %d", shown, listed, p.fat, fat, p.sack[.Honey], game.outfit.hat, larder_apples))
	kept, _ := os.read_entire_file(SAVES_DIR + "/prosio_261126_080000.sav", context.temp_allocator)
	check("Load first keeps the game it replaces as a backup too", len(second) > 0 && string(kept) == string(second), fmt.tprintf("%d bytes kept of %d", len(kept), len(second)))

	// Order by the time in the name: 1 January 2027 is newer than 31
	// December 2026, though "0101..." comes first as text. A name that is
	// not a backup's is left out; a damaged backup is listed, cannot be
	// loaded, and loading it changes nothing.
	put_backup("prosio_311226_235959.sav", before)
	put_backup("prosio_010127_000000.sav", before)
	put_backup("prosio_020127_000000.sav", transmute([]u8)string("not a saved game"))
	put_backup("prosio_badname.sav", before)
	put_backup("notes.txt", before)
	put_backup("prosio_321326_000000.sav", before) // no 32nd of a 13th month
	game.list_backups()
	order := ""
	for &b in game.backups[:game.backup_count] {
		order = fmt.tprintf("%s %s", order, string(b.name[7:13]))
	}
	check("the LOAD list is newest first by the time in the names, and other files are left out",
		order == " 020127 010127 311226 261126 251126", order)
	current, _ := os.read_entire_file(SAVE_FILE, context.temp_allocator)
	damaged_ok := !game.backups[0].readable && game.backups[1].readable
	loaded := game.load_backup(0)
	after, _ := os.read_entire_file(SAVE_FILE, context.temp_allocator)
	check("a damaged backup is marked, cannot be loaded, and changes nothing", damaged_ok && !loaded && string(after) == string(current) && abs(p.fat - fat) < 0.01,
		fmt.tprintf("marked %v, loaded %v", damaged_ok, loaded))

	// At most BACKUP_LIST are listed, the newest; every one is kept.
	for i in 0 ..< game.BACKUP_LIST + 5 {
		buf: [game.BACKUP_NAME_SIZE]u8
		put_backup(game.backup_name({2030, 1, 1 + i / 24, i % 24, 0, 0}, &buf), before)
	}
	game.list_backups()
	files, _ := filepath.glob(SAVES_DIR + "/*.sav", context.temp_allocator)
	newest := game.backups[0].saved
	check("the LOAD list shows the newest BACKUP_LIST backups and keeps them all",
		game.backup_count == game.BACKUP_LIST && newest == game.Clock{2030, 1, 3, 6, 0, 0} && len(files) > game.BACKUP_LIST + 5,
		fmt.tprintf("%d listed of %d files, newest %v", game.backup_count, len(files), newest))

	// A test run, a program playing or the workbench: nothing written or listed.
	empty_saves()
	fresh()
	game.save_game()
	made := game.back_up_save()
	game.list_backups()
	there, _ := filepath.glob(SAVES_DIR + "/*", context.temp_allocator)
	check("with no_save no backup is made or listed", !made && game.backup_count == 0 && len(there) == 0, fmt.tprintf("made %v, listed %d, files %d", made, game.backup_count, len(there)))
	game.outfit.hat = hat
}

// Opens a menu and picks one of its choices with Confirm, as a player does.
choose :: proc(menu: game.Scene, item: game.Menu_Item) {
	game.scene = menu
	game.menu_choice = 0
	for it, i in game.menu_items() {
		if it == item {game.menu_choice = i}
	}
	press(.Confirm)
}

// One frame of whichever menu is open, with this button pressed.
press :: proc(b: game.Button) {
	game.forced_pressed = {b}
	#partial switch game.scene {
	case .Menu, .Paused: game.update_menu()
	case .Load: game.update_load_list()
	}
	game.forced_pressed = {}
}

put_backup :: proc(name: string, data: []u8) {
	os.make_directory(SAVES_DIR)
	_ = os.write_entire_file(fmt.tprintf("%s/%s", SAVES_DIR, name), data)
}

empty_saves :: proc() {
	files, _ := filepath.glob(SAVES_DIR + "/*", context.temp_allocator)
	for f in files {
		os.remove(f)
	}
}
