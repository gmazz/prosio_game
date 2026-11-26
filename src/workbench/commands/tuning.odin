package workbench_commands

// Writing a tuned value back into its data file (data/tuning/*.json), for
// the workbench's panes: only the value itself changes, everything else in
// the file (its "about"s, its layout) stays as it was. A value written as a
// sum ("ENEMY_HEALTH / 30") becomes the number it came to.

import game "../../game"
import "core:c/libc"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strings"
import "core:time"

// The text with the value of NAME (or of its entry KEY, in a table) set to
// this number. ok: it was found.
json_set_value :: proc(text, name, key: string, value: f32) -> (out: string, ok: bool) {
	start, stop, found := json_value_span(text, name, key)
	if !found {
		return text, false
	}
	return strings.concatenate({text[:start], number_text(value), text[stop:]}, context.temp_allocator), true
}

// The value of NAME (or of its entry KEY) as the file writes it: a number,
// or a sum in quotes.
json_get_value :: proc(text, name, key: string) -> (string, bool) {
	start, stop, found := json_value_span(text, name, key)
	return found ? text[start:stop] : "", found
}

// Where the value of NAME (or of its entry KEY) is in the text.
json_value_span :: proc(text, name, key: string) -> (start, stop: int, ok: bool) {
	at := strings.index(text, fmt.tprintf("\"%s\":", name))
	if at < 0 {
		return
	}
	// Within the entry: the first "f32": for a single value, or "KEY": in
	// its table.
	look := key == "" ? "\"f32\":" : fmt.tprintf("\"%s\":", key)
	end := entry_end(text, at)
	inside := strings.index(text[at:end], look)
	if inside < 0 {
		return
	}
	start = at + inside + len(look)
	for start < len(text) && (text[start] == ' ' || text[start] == '\t' || text[start] == '\n') {
		start += 1
	}
	stop = start
	if stop < len(text) && text[stop] == '"' {
		stop += 1
		for stop < len(text) && text[stop] != '"' {stop += 1}
		stop += 1
	} else {
		for stop < len(text) && strings.contains_rune("0123456789.eE+-", rune(text[stop])) {stop += 1}
	}
	return start, stop, stop > start
}

// Where the entry starting at `at` ends: its closing brace.
@(private = "file")
entry_end :: proc(text: string, at: int) -> int {
	depth := 0
	quoted := false
	for i := at; i < len(text); i += 1 {
		c := text[i]
		switch {
		case quoted && c == '\\': i += 1
		case c == '"': quoted = !quoted
		case quoted:
		case c == '{': depth += 1
		case c == '}':
			depth -= 1
			if depth == 0 {return i + 1}
		}
	}
	return len(text)
}

// A number as the data files write it: no more digits than it needs (six
// at most that mean something).
number_text :: proc(v: f32) -> string {
	s := fmt.tprintf("%.6g", v)
	if strings.contains(s, "e") {
		return s
	}
	if strings.contains(s, ".") {
		s = strings.trim_right(s, "0")
		s = strings.trim_suffix(s, ".")
	}
	return s
}

// ---- Backups of the parameters. ----
//
// Before a pane's Save writes into data/tuning, the files as they were last
// saved are copied, every one of them, into a folder named for when that
// was, in the manner of the game's own backups (prosio_DDMMYY_HHMMSS.sav):
// tuning_backups/tuning_DDMMYY_HHMMSS/ (local time). Every one is kept; the
// workbench lists the newest TUNING_BACKUP_LIST, newest first, and loads one
// into the running game to try. They are the person's own, like the saved
// games: git leaves them out (.gitignore).

TUNING_DIR :: "data/tuning"
TUNING_BACKUPS :: "tuning_backups"
TUNING_BACKUP_LIST :: game.BACKUP_LIST // (as many as the game's LOAD list shows)

// A backup's name for parameters saved then: tuning_261126_143015 for
// 26 November 2026 at 14:30:15.
tuning_backup_name :: proc(c: game.Clock) -> string {
	return fmt.tprintf("tuning_%02d%02d%02d_%02d%02d%02d", c.day, c.month, c.year % 100, c.hour, c.minute, c.second)
}

// When the parameters in a backup were saved, from its name.
tuning_backup_time :: proc(name: string) -> (c: game.Clock, ok: bool) {
	if len(name) != len("tuning_DDMMYY_HHMMSS") || !strings.has_prefix(name, "tuning_") {
		return {}, false
	}
	// (The game's own reading of a backup's name, on the same digits.)
	return game.backup_time(fmt.tprintf("prosio_%s.sav", name[7:]))
}

// The backups there are, newest first, the newest TUNING_BACKUP_LIST.
list_tuning_backups :: proc() -> []string {
	out: [dynamic]string
	out.allocator = context.temp_allocator
	entries, err := os.read_all_directory_by_path(TUNING_BACKUPS, context.temp_allocator)
	if err != nil {
		return nil
	}
	for e in entries {
		if _, ok := tuning_backup_time(e.name); ok && e.type == .Directory {
			append(&out, e.name)
		}
	}
	order :: proc(name: string) -> i64 {
		c, _ := tuning_backup_time(name)
		return game.clock_order(c)
	}
	slice.sort_by(out[:], proc(a, b: string) -> bool {return order(a) > order(b)})
	return out[:min(len(out), TUNING_BACKUP_LIST)]
}

// Copies every file of data/tuning, as it is, into a backup named for when
// the newest of them was saved (so the same files are never backed up
// twice). The backup's name, or what went wrong.
backup_tuning :: proc() -> (name: string, ok: bool) {
	files, _ := filepath.glob(TUNING_DIR + "/*.json", context.temp_allocator)
	if len(files) == 0 {
		return "no files in " + TUNING_DIR, false
	}
	newest: time.Time
	for f in files {
		if t, err := os.modification_time_by_path(f); err == nil && time.diff(newest, t) > 0 {
			newest = t
		}
	}
	name = tuning_backup_name(clock_at(newest))
	dir := fmt.tprintf("%s/%s", TUNING_BACKUPS, name)
	if os.exists(dir) {
		return name, true // (these files are backed up already)
	}
	if os.make_directory_all(dir) != nil {
		return fmt.tprintf("could not make %s", dir), false
	}
	for f in files {
		data, err := os.read_entire_file(f, context.temp_allocator)
		if err != nil || os.write_entire_file(fmt.tprintf("%s/%s", dir, filepath.base(f)), data) != nil {
			return fmt.tprintf("could not copy %s", f), false
		}
	}
	return name, true
}

// A moment, as the clock on the wall here showed it.
clock_at :: proc(t: time.Time) -> game.Clock {
	secs := libc.time_t(time.time_to_unix(t))
	tm := libc.localtime(&secs)
	if tm == nil {
		return {}
	}
	return {int(tm.tm_year) + 1900, int(tm.tm_mon) + 1, int(tm.tm_mday), int(tm.tm_hour), int(tm.tm_min), int(tm.tm_sec)}
}
