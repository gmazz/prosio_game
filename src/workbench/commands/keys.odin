package workbench_commands

// The workbench's own keys as src/workbench/keys.txt writes them (each line:
// an action, then a key such as Shift+1, Cmd+K or F1), read into raylib's
// numbers for keys (the window, keys.odin in the workbench, does the rest).

import "core:fmt"
import "core:strings"

Bench_Action :: enum {
	Menu,
	Editor,
	Replay,
	Pause,
	Step,
}

Bench_Key :: struct {
	code:                  int, // raylib's number for the key
	shift, ctrl, alt, cmd: bool,
}

KEYS_PER_ACTION :: 4

Bench_Keys :: struct {
	keys:  [Bench_Action][KEYS_PER_ACTION]Bench_Key,
	count: [Bench_Action]int,
}

DEFAULT_KEYS := [Bench_Action]Bench_Key {
	.Menu = {code = '1', shift = true},
	.Editor = {code = '2', shift = true},
	.Replay = {code = '3', shift = true},
	.Pause = {code = '4', shift = true},
	.Step = {code = '5', shift = true},
}

KEY_F1 :: 290 // raylib's F1; F2 to F12 follow it

// Reads keys.txt. An action it gives no key keeps its default; what it gets
// wrong (the last thing) is in `trouble`.
parse_keys :: proc(text: string) -> (out: Bench_Keys, trouble: string) {
	s := text
	number := 0
	for line in strings.split_lines_iterator(&s) {
		number += 1
		words := strings.fields(strip_comment(line), context.temp_allocator)
		if len(words) == 0 {
			continue
		}
		action, known := action_named(words[0])
		key: Bench_Key
		ok := false
		if len(words) == 2 {
			key, ok = key_named(words[1])
		}
		switch {
		case !known:
			trouble = fmt.tprintf("keys.txt line %d: no action %q (menu, editor, replay, pause, step)", number, words[0])
		case !ok:
			trouble = fmt.tprintf("keys.txt line %d: %q is not a key (say Shift+1, Cmd+K or F1)", number, len(words) > 1 ? words[1] : "")
		case out.count[action] < KEYS_PER_ACTION:
			out.keys[action][out.count[action]] = key
			out.count[action] += 1
		}
	}
	for action in Bench_Action {
		if out.count[action] == 0 {
			out.keys[action][0] = DEFAULT_KEYS[action]
			out.count[action] = 1
		}
	}
	return
}

@(private = "file")
strip_comment :: proc(line: string) -> string {
	// A comment starts at a # at the start or after a space, so that a key
	// may be a # itself.
	for i in 0 ..< len(line) {
		if line[i] == '#' && (i == 0 || line[i - 1] == ' ' || line[i - 1] == '\t') {
			return line[:i]
		}
	}
	return line
}

action_named :: proc(name: string) -> (Bench_Action, bool) {
	for action in Bench_Action {
		if strings.equal_fold(name, fmt.tprintf("%v", action)) {
			return action, true
		}
	}
	return {}, false
}

// A key as keys.txt writes it: Shift+1, Cmd+K, F1, Ctrl+Alt+P.
key_named :: proc(name: string) -> (k: Bench_Key, ok: bool) {
	parts := strings.split(name, "+", context.temp_allocator)
	if len(parts) == 0 || parts[len(parts) - 1] == "" {
		return {}, false
	}
	for mod in parts[:len(parts) - 1] {
		switch strings.to_lower(mod, context.temp_allocator) {
		case "shift": k.shift = true
		case "ctrl", "control": k.ctrl = true
		case "alt", "option", "opt": k.alt = true
		case "cmd", "command", "super": k.cmd = true
		case: return {}, false
		}
	}
	last := strings.to_upper(parts[len(parts) - 1], context.temp_allocator)
	if len(last) == 1 {
		// Letters, digits and the punctuation keys are their own characters.
		if strings.index_byte("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-=[];',./\\`", last[0]) >= 0 {
			k.code = int(last[0])
			return k, true
		}
		return {}, false
	}
	if last[0] == 'F' {
		n := 0
		for c in last[1:] {
			if c < '0' || c > '9' {
				return {}, false
			}
			n = n * 10 + int(c - '0')
		}
		if n >= 1 && n <= 12 {
			k.code = KEY_F1 + n - 1
			return k, true
		}
	}
	for named in NAMED_KEYS {
		if named.name == last {
			k.code = named.code
			return k, true
		}
	}
	return {}, false
}

@(private = "file")
NAMED_KEYS := [?]struct {
	name: string,
	code: int,
}{{"SPACE", 32}, {"ENTER", 257}, {"RETURN", 257}, {"TAB", 258}, {"BACKSPACE", 259}, {"PAGEUP", 266}, {"PAGEDOWN", 267}, {"HOME", 268}, {"END", 269}}

// A key as keys.txt writes it, for the hints: Shift+2.
key_text :: proc(k: Bench_Key) -> string {
	b := strings.builder_make(context.temp_allocator)
	if k.ctrl {strings.write_string(&b, "Ctrl+")}
	if k.alt {strings.write_string(&b, "Alt+")}
	if k.cmd {strings.write_string(&b, "Cmd+")}
	if k.shift {strings.write_string(&b, "Shift+")}
	switch {
	case k.code >= KEY_F1 && k.code < KEY_F1 + 12:
		fmt.sbprintf(&b, "F%d", k.code - KEY_F1 + 1)
	case k.code > 32 && k.code < 128:
		strings.write_byte(&b, u8(k.code))
	case:
		for named in NAMED_KEYS {
			if named.code == k.code {
				strings.write_string(&b, named.name)
				break
			}
		}
	}
	return strings.to_string(b)
}
