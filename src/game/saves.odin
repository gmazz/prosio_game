package game

// Backups of the saved game, and loading one (see the README, "Saving,
// backups and loading"). The saved game (body.odin) is written every
// SAVE_EVERY seconds while he plays, and when the game is paused or left for
// the menu. Before Restart or Load throws the game away, the saved game as
// it stands is first copied to a backup named for when it was saved,
// prosio_DDMMYY_HHMMSS.sav (local time), in BACKUP_FOLDER beside it (on the
// web, in the browser's storage, the newest WEB_BACKUPS). Every backup is
// kept; LOAD on the main and pause menus lists the newest BACKUP_LIST,
// newest first, and puts the one chosen in a freshly built meadow. So
// nothing is ever lost by starting over or loading. Test runs, programs
// playing and the workbench (no_save) neither make nor list backups.

import "core:fmt"

BACKUP_NAME_SIZE :: len("prosio_DDMMYY_HHMMSS.sav")

Backup :: struct {
	name:     [BACKUP_NAME_SIZE]u8,
	saved:    Clock, // when the game in it was saved, read from its name
	readable: bool, // a saved game this version can load
}

// The newest backups, newest first (list_backups fills it).
backups: [BACKUP_LIST]Backup
backup_count: int
// When the saved game was last written in this sitting (save_game).
saved_at: Maybe(Clock)
// A backup read from its file, apart from the saved game's own bytes.
backup_bytes: [SAVE_ROOM]u8

backups_allowed :: proc() -> bool {
	return g.opts.shot_path == nil && !g.opts.no_save
}

// A backup's file name for a game saved then: prosio_251126_231507.sav for
// 25 November 2026 at 23:15:07.
backup_name :: proc(c: Clock, buf: ^[BACKUP_NAME_SIZE]u8) -> string {
	return fmt.bprintf(buf[:], "prosio_%02d%02d%02d_%02d%02d%02d.sav", c.day, c.month, c.year % 100, c.hour, c.minute, c.second)
}

// When the game in a backup was saved, from its file name; false for a name
// that is not a backup's.
backup_time :: proc(name: string) -> (c: Clock, ok: bool) {
	if len(name) != BACKUP_NAME_SIZE || name[:7] != "prosio_" || name[13] != '_' || name[20:] != ".sav" {
		return {}, false
	}
	two :: proc(s: string) -> (int, bool) {
		if s[0] < '0' || s[0] > '9' || s[1] < '0' || s[1] > '9' {
			return 0, false
		}
		return int(s[0] - '0') * 10 + int(s[1] - '0'), true
	}
	ok1, ok2, ok3, ok4, ok5, ok6: bool
	c.day, ok1 = two(name[7:9])
	c.month, ok2 = two(name[9:11])
	c.year, ok3 = two(name[11:13])
	c.hour, ok4 = two(name[14:16])
	c.minute, ok5 = two(name[16:18])
	c.second, ok6 = two(name[18:20])
	c.year += 2000
	ok = ok1 && ok2 && ok3 && ok4 && ok5 && ok6 && c.month >= 1 && c.month <= 12 && c.day >= 1 && c.day <= 31 && c.hour <= 23 && c.minute <= 59 && c.second <= 59
	return
}

// A number that grows with the time, for putting backups in order (their
// names, day first, do not sort as text).
clock_order :: proc(c: Clock) -> i64 {
	return ((((i64(c.year) * 100 + i64(c.month)) * 100 + i64(c.day)) * 100 + i64(c.hour)) * 100 + i64(c.minute)) * 100 + i64(c.second)
}

// Lists the backups there are: the newest BACKUP_LIST, newest first, each
// marked whether it can be loaded. A file whose name is not a backup's is
// left out.
list_backups :: proc() {
	backup_count = 0
	if !backups_allowed() {
		return
	}
	backup_each(proc(name: string) {
		saved, ok := backup_time(name)
		if !ok {
			return
		}
		// Into its place, newest first; past the end of the list it is not shown.
		at := backup_count
		for at > 0 && clock_order(backups[at - 1].saved) < clock_order(saved) {
			at -= 1
		}
		if at >= BACKUP_LIST {
			return
		}
		last := min(backup_count, BACKUP_LIST - 1)
		for i := last; i > at; i -= 1 {
			backups[i] = backups[i - 1]
		}
		backups[at] = {saved = saved}
		copy(backups[at].name[:], name)
		backup_count = min(backup_count + 1, BACKUP_LIST)
	})
	for &b in backups[:backup_count] {
		n := backup_read(string(b.name[:]), backup_bytes[:])
		b.readable = read_save(backup_bytes[:n])
	}
}

// Copies the saved game, as it stands, to a backup named for when it was
// saved. False if there is nothing to copy (or backups are not made here).
// A backup that is already there with the same bytes is not made again; one
// of the same name and other bytes (two saves in one second) gets the next
// free second.
back_up_save :: proc() -> bool {
	if !backups_allowed() {
		return false
	}
	n := store_read(save_bytes[:])
	if n == 0 {
		return false
	}
	saved, known := saved_at.?
	if !known {
		saved, known = store_saved_at()
	}
	if !known {
		saved = clock_now()
	}
	buf: [BACKUP_NAME_SIZE]u8
	for _ in 0 ..< 60 {
		name := backup_name(saved, &buf)
		m := backup_read(name, backup_bytes[:])
		if m == 0 {
			ok := backup_write(name, save_bytes[:n])
			list_backups()
			return ok
		}
		if m == n && string(backup_bytes[:m]) == string(save_bytes[:n]) {
			return true // already kept
		}
		if saved.second == 59 {
			break
		}
		saved.second += 1
	}
	return false
}

// Loads the backup at this place in the list into a freshly built meadow,
// after backing up the game it replaces. False (and nothing changed) if it
// cannot be read.
load_backup :: proc(index: int) -> bool {
	if index < 0 || index >= backup_count || !backups_allowed() {
		return false
	}
	chosen := backups[index]
	n := backup_read(string(chosen.name[:]), backup_bytes[:])
	if !read_save(backup_bytes[:n]) {
		return false
	}
	// (Kept apart: backing up the game now uses backup_bytes.)
	@(static) loading: [SAVE_ROOM]u8
	copy(loading[:], backup_bytes[:n])
	back_up_save()
	store_write(loading[:n])
	saved_at = chosen.saved
	continue_game()
	has_save = true
	list_backups()
	return true
}

// The LOAD list: where it was opened from, and which backup is chosen.
load_from: Scene
load_choice: int
LOAD_ROWS :: 8 // backups shown at once; the list scrolls past them

update_load_list :: proc() {
	if button_pressed(.Menu) || backup_count == 0 {
		scene = load_from
		return
	}
	if button_pressed(.Down) {
		load_choice = (load_choice + 1) % backup_count
	}
	if button_pressed(.Up) {
		load_choice = (load_choice + backup_count - 1) % backup_count
	}
	if button_pressed(.Confirm) && backups[load_choice].readable && load_backup(load_choice) {
		menu_choice = 0
		scene = .Playing
	}
}

// When the game in a backup was saved, as the list shows it: 25 November
// 2026, 23:15:07.
backup_when :: proc(c: Clock) -> cstring {
	@(static) time: [16]u8
	time = {}
	fmt.bprintf(time[:len(time) - 1], "%02d:%02d:%02d", c.hour, c.minute, c.second)
	return fill(TEXT.load_when, {"day", c.day}, {"month", TEXT.month_name[clamp(c.month, 1, 12) - 1]}, {"year", c.year}, {"time", cstring(&time[0])})
}

draw_load_list :: proc() {
	sw, sh := screen_size()
	s := min(sw / 1280, sh / 720)
	ui_rect(0, 0, sw, sh, {10, 24, 20, 170})
	top := sh * 0.12
	label_centred(TEXT.load_title, sw / 2, top, 56 * s)
	first := clamp(load_choice - LOAD_ROWS / 2, 0, max(backup_count - LOAD_ROWS, 0))
	y := top + 100 * s
	for i in first ..< min(first + LOAD_ROWS, backup_count) {
		b := backups[i]
		text := backup_when(b.saved)
		if !b.readable {
			text = fill(TEXT.load_broken, {"when", text})
		}
		chosen := i == load_choice
		size := (chosen ? 34 : 28) * s
		size = fit_size(text, size, sw - 120 * s)
		w := ui_text_width(text, size)
		color := b.readable ? UI_WHITE : Color{150, 150, 150, 255}
		if chosen {
			ui_round_rect(sw / 2 - w / 2 - 24 * s, y - 6 * s, w + 48 * s, size + 12 * s, b.readable ? Color{250, 172, 182, 235} : Color{120, 120, 120, 220})
			ui_text(text, sw / 2 - w / 2, y, size, UI_DARK)
		} else {
			label_centred(text, sw / 2, y, size, color)
		}
		y += 44 * s
	}
	if first > 0 {
		label_centred("^", sw / 2, top + 72 * s, 20 * s, UI_YELLOW)
	}
	if first + LOAD_ROWS < backup_count {
		label_centred("v", sw / 2, y, 20 * s, UI_YELLOW)
	}
	label_fitted(TEXT.load_note, sw / 2, sh - 110 * s, 20 * s, sw - 80 * s, UI_YELLOW)
	label_fitted(TEXT.load_help, sw / 2, sh - 70 * s, 18 * s, sw - 80 * s)
}

// For pictures of the LOAD list (the tour, --load-list): example backups,
// in memory only, one of them unreadable. With --menu the main menu shows
// LOAD; otherwise the list is open.
show_load_examples :: proc() {
	backup_count = 0
	for i in 0 ..< 12 {
		b := &backups[backup_count]
		b.saved = {2026, 11, 25 - i / 3, 23 - (i % 3) * 5, 59 - i * 4, (i * 17) % 60}
		buf: [BACKUP_NAME_SIZE]u8
		copy(b.name[:], backup_name(b.saved, &buf))
		b.readable = i != 4
		backup_count += 1
	}
	if scene != .Menu {
		load_from, load_choice = .Menu, 1
		scene = .Load
	}
}
