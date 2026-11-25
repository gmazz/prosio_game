package workbench

// The workbench's own keys (menu, editor, replay, pause, step), from
// src/workbench/keys.txt (read by commands/keys.odin): read when the
// workbench starts, on every reload, and when the file is saved. They act
// only while the game has the keys; wherever you are typing (the menu, the
// editor, a field of the inspector) they type themselves, and Esc gives the
// keys back first. On the frame one acts the game is given no keys, so
// Shift+1 does not also set the pixel size, and the character it types goes
// nowhere.

import cmd "commands"
import "core:os"
import "core:time"
import rl "vendor:raylib"

KEYS_FILE :: "src/workbench/keys.txt"

bench_keys: cmd.Bench_Keys
keys_saved: time.Time // when keys.txt was last saved, as last read
keys_looked: f64 // when keys.txt was last looked at

load_keys :: proc() -> (trouble: string) {
	keys_saved, _ = os.modification_time_by_path(KEYS_FILE)
	text, err := os.read_entire_file(KEYS_FILE, context.temp_allocator)
	bench_keys, trouble = cmd.parse_keys(string(text))
	if err != nil {
		trouble = KEYS_FILE + " is not there: the keys are Shift+1 to Shift+5"
	}
	if trouble != "" {
		say(trouble)
	}
	return
}

// Reads keys.txt again if it has been saved since (looked at once a second).
keys_follow_file :: proc() {
	now := rl.GetTime()
	if now - keys_looked < 1 {
		return
	}
	keys_looked = now
	saved, err := os.modification_time_by_path(KEYS_FILE)
	if err == nil && time.diff(keys_saved, saved) != 0 {
		if load_keys() == "" {
			say("keys.txt read again")
		}
	}
}

// The first key of an action, as keys.txt writes it, for the hints.
key_text :: proc(action: cmd.Bench_Action) -> string {
	return cmd.key_text(bench_keys.keys[action][0])
}

// The workbench key pressed this frame, if any.
bench_key_pressed :: proc() -> (cmd.Bench_Action, bool) {
	shift := rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)
	ctrl := rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL)
	alt := rl.IsKeyDown(.LEFT_ALT) || rl.IsKeyDown(.RIGHT_ALT)
	super := rl.IsKeyDown(.LEFT_SUPER) || rl.IsKeyDown(.RIGHT_SUPER)
	for action in cmd.Bench_Action {
		for k in bench_keys.keys[action][:bench_keys.count[action]] {
			if rl.IsKeyPressed(rl.KeyboardKey(k.code)) && k.shift == shift && k.ctrl == ctrl && k.alt == alt && k.cmd == super {
				return action, true
			}
		}
	}
	return {}, false
}
