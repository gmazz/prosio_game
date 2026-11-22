package game

import "core:strconv"
import "core:strings"

// Which keys and which Xbox controller buttons do what, and the Controls
// panel of the M menu where they are changed. Each button the game knows
// (see Button in platform.odin) has up to two keys and one controller
// button. Moving (the left stick, the D-pad, WASD and the arrows),
// pausing, choosing in menus and waking up stay as they are, so no one can
// lock himself out; the rest can be changed, and the changes are kept in a
// small file of their own (not in the saved pig, so starting over keeps
// them).
//
// Texts on the screen name buttons by a word in braces, "{Action}: pick it",
// and are shown with the button of whichever was used last: "E: pick it" at
// the keyboard, "A: pick it" with the controller (see expand_keys).

// A keyboard key by raylib's number for it: letters and digits are the
// ASCII codes of their capitals.
Key :: distinct i32

KEY_NONE :: Key(0)
KEY_SPACE :: Key(32)
KEY_ESCAPE :: Key(256)
KEY_ENTER :: Key(257)
KEY_BACKSPACE :: Key(259)
KEY_RIGHT :: Key(262)
KEY_LEFT :: Key(263)
KEY_DOWN :: Key(264)
KEY_UP :: Key(265)
KEY_KP_0 :: Key(320)
KEY_KP_ENTER :: Key(335)
KEY_LEFT_SHIFT :: Key(340)
KEY_RIGHT_SHIFT :: Key(344)

// The controller's buttons, and its left stick pushed one way (for moving
// through menus; the stick itself moves him by how far it is pushed).
Pad :: enum u8 {
	None,
	A,
	B,
	X,
	Y,
	LB,
	RB,
	LT,
	RT,
	View,
	Start,
	L_Stick, // the left stick, clicked
	R_Stick,
	D_Up,
	D_Down,
	D_Left,
	D_Right,
	Stick_Up,
	Stick_Down,
	Stick_Left,
	Stick_Right,
}

PAD_NAME := [Pad]string {
	.None        = "-",
	.A           = "A",
	.B           = "B",
	.X           = "X",
	.Y           = "Y",
	.LB          = "LB",
	.RB          = "RB",
	.LT          = "LT",
	.RT          = "RT",
	.View        = "VIEW",
	.Start       = "MENU",
	.L_Stick     = "L-STICK",
	.R_Stick     = "R-STICK",
	.D_Up        = "D-PAD UP",
	.D_Down      = "D-PAD DOWN",
	.D_Left      = "D-PAD LEFT",
	.D_Right     = "D-PAD RIGHT",
	.Stick_Up    = "STICK UP",
	.Stick_Down  = "STICK DOWN",
	.Stick_Left  = "STICK LEFT",
	.Stick_Right = "STICK RIGHT",
}

// The controller buttons an action may be given.
PAD_ASSIGNABLE :: bit_set[Pad]{.A, .B, .X, .Y, .LB, .RB, .LT, .RT, .View, .L_Stick, .R_Stick}

Binding :: struct {
	keys: [2]Key,
	pad:  Pad,
}

DEFAULT_BINDINGS :: [Button]Binding {
	.Left      = {{Key('A'), KEY_LEFT}, .D_Left},
	.Right     = {{Key('D'), KEY_RIGHT}, .D_Right},
	.Up        = {{Key('W'), KEY_UP}, .D_Up},
	.Down      = {{Key('S'), KEY_DOWN}, .D_Down},
	.Jump      = {{Key('J'), Key('X')}, .RT},
	.Sprint    = {{KEY_LEFT_SHIFT, KEY_RIGHT_SHIFT}, .L_Stick},
	.Bump      = {{KEY_SPACE, KEY_NONE}, .X},
	.Action    = {{Key('E'), Key('K')}, .A},
	.Grab      = {{Key('F'), Key('L')}, .B},
	.Eat       = {{Key('Q'), KEY_NONE}, .Y},
	.Sack_Prev = {{Key('Z'), KEY_NONE}, .LB},
	.Sack_Next = {{Key('C'), KEY_NONE}, .RB},
	.Bag       = {{Key('M'), KEY_NONE}, .View},
	.Gas       = {{Key('G'), Key('V')}, .LT},
	.Restart   = {{KEY_ENTER, Key('R')}, .A},
	.Menu      = {{KEY_ESCAPE, Key('P')}, .Start},
	.Confirm   = {{KEY_ENTER, KEY_SPACE}, .A},
}

bindings := DEFAULT_BINDINGS

// The actions the Controls panel can change, in its order, and what it
// calls them.
REMAPPABLE := [?]Button{.Jump, .Sprint, .Bump, .Action, .Grab, .Eat, .Sack_Prev, .Sack_Next, .Bag, .Gas}
CONTROL_NAME := [Button]string {
	.Left      = "Left",
	.Right     = "Right",
	.Up        = "Up",
	.Down      = "Down",
	.Jump      = "Jump",
	.Sprint    = "Sprint",
	.Bump      = "Bump (belly charge)",
	.Action    = "Pick up, use, drink",
	.Grab      = "Grab, throw",
	.Eat       = "Eat, put up",
	.Sack_Prev = "Sack: back",
	.Sack_Next = "Sack: on",
	.Bag       = "This menu",
	.Gas       = "Let his wind go",
	.Restart   = "Wake up",
	.Menu      = "Pause",
	.Confirm   = "Choose",
}

// The word each button goes by in a saved file and in texts on the screen.
BUTTON_WORD := [Button]string {
	.Left      = "Left",
	.Right     = "Right",
	.Up        = "Up",
	.Down      = "Down",
	.Jump      = "Jump",
	.Sprint    = "Sprint",
	.Bump      = "Bump",
	.Action    = "Action",
	.Grab      = "Grab",
	.Eat       = "Eat",
	.Sack_Prev = "Prev",
	.Sack_Next = "Next",
	.Bag       = "Bag",
	.Gas       = "Gas",
	.Restart   = "Restart",
	.Menu      = "Menu",
	.Confirm   = "Confirm",
}

// True once the controller was the last thing touched: the screen then
// names its buttons. Set by the platform as it reads the buttons.
pad_in_use: bool

// With the sprint on a stick, a click starts a sprint that lasts until he
// stops moving (holding a stick in while steering is hard for small hands).
sprint_latched: bool

// How far the left stick is pushed, 0 to 1 each way, after its dead middle
// (with the keyboard off, as in test runs, this stands in for it).
forced_stick: Vec2

// Keys the Controls panel will not give an action: they move him, pause,
// or set the pixel size.
key_reserved :: proc(k: Key) -> bool {
	switch k {
	case Key('W'), Key('A'), Key('S'), Key('D'), KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_ESCAPE, Key('P'), KEY_BACKSPACE:
		return true
	}
	return (k >= Key('1') && k <= Key('6')) || (k >= KEY_KP_0 + 1 && k <= KEY_KP_0 + 6)
}

key_name :: proc(k: Key) -> string {
	LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	DIGITS := "0123456789"
	switch {
	case k >= Key('A') && k <= Key('Z'):
		i := int(k - Key('A'))
		return LETTERS[i:i + 1]
	case k >= Key('0') && k <= Key('9'):
		i := int(k - Key('0'))
		return DIGITS[i:i + 1]
	case k >= KEY_KP_0 && k <= KEY_KP_0 + 9:
		NUMPAD := [10]string{"PAD 0", "PAD 1", "PAD 2", "PAD 3", "PAD 4", "PAD 5", "PAD 6", "PAD 7", "PAD 8", "PAD 9"}
		return NUMPAD[k - KEY_KP_0]
	case k >= 290 && k <= 301:
		F := [12]string{"F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12"}
		return F[k - 290]
	}
	switch k {
	case KEY_NONE:        return "-"
	case KEY_SPACE:       return "SPACE"
	case KEY_ESCAPE:      return "ESC"
	case KEY_ENTER:       return "ENTER"
	case 258:             return "TAB"
	case KEY_BACKSPACE:   return "BACKSPACE"
	case 260:             return "INSERT"
	case 261:             return "DELETE"
	case KEY_RIGHT:       return "RIGHT"
	case KEY_LEFT:        return "LEFT"
	case KEY_DOWN:        return "DOWN"
	case KEY_UP:          return "UP"
	case 266:             return "PAGE UP"
	case 267:             return "PAGE DOWN"
	case 268:             return "HOME"
	case 269:             return "END"
	case 280:             return "CAPS LOCK"
	case KEY_KP_ENTER:    return "PAD ENTER"
	case KEY_LEFT_SHIFT:  return "SHIFT"
	case 341:             return "CTRL"
	case 342:             return "ALT"
	case 343:             return "LEFT CMD"
	case KEY_RIGHT_SHIFT: return "RIGHT SHIFT"
	case 345:             return "RIGHT CTRL"
	case 346:             return "RIGHT ALT"
	case 347:             return "RIGHT CMD"
	case 39:              return "'"
	case 44:              return ","
	case 45:              return "-"
	case 46:              return "."
	case 47:              return "/"
	case 59:              return ";"
	case 61:              return "="
	case 91:              return "["
	case 92:              return "\\"
	case 93:              return "]"
	case 96:              return "`"
	}
	return "?"
}

// What a button is called on the screen: its first key, or its controller
// button once the controller is in use.
button_word :: proc(b: Button) -> string {
	if pad_in_use {
		if b == .Sprint && (bindings[b].pad == .L_Stick || bindings[b].pad == .R_Stick) {
			return bindings[b].pad == .L_Stick ? "click L-STICK" : "click R-STICK"
		}
		return PAD_NAME[bindings[b].pad]
	}
	return key_name(bindings[b].keys[0])
}

// Texts with buttons named in braces, written out for whichever was used
// last. Besides the buttons' own words (BUTTON_WORD): {Move}, {Aim}, {Sack}
// (both sack buttons) and {Close} (what closes a station's menu).
@(private = "file")
expanded: [4][512]u8
@(private = "file")
expanded_next: int

expand_keys :: proc(text: cstring) -> cstring {
	s := string(text)
	if strings.index_byte(s, '{') < 0 {
		return text
	}
	buf := &expanded[expanded_next]
	expanded_next = (expanded_next + 1) % len(expanded)
	n := 0
	for i := 0; i < len(s); {
		if s[i] == '{' {
			if end := strings.index_byte(s[i:], '}'); end > 0 {
				if put_word(buf, &n, s[i + 1:i + end]) {
					i += end + 1
					continue
				}
			}
		}
		put_text(buf, &n, s[i:i + 1])
		i += 1
	}
	buf[n] = 0
	return cstring(raw_data(buf[:]))
}

@(private = "file")
put_text :: proc(buf: ^[512]u8, n: ^int, s: string) {
	for i in 0 ..< len(s) {
		if n^ < len(buf) - 1 {
			buf[n^] = s[i]
			n^ += 1
		}
	}
}

@(private = "file")
put_word :: proc(buf: ^[512]u8, n: ^int, word: string) -> bool {
	switch word {
	case "Move":
		put_text(buf, n, pad_in_use ? "L-STICK" : "WASD")
		return true
	case "Sack":
		put_text(buf, n, button_word(.Sack_Prev))
		put_text(buf, n, " / ")
		put_text(buf, n, button_word(.Sack_Next))
		return true
	case "Aim":
		put_text(buf, n, pad_in_use ? "stick" : "arrows")
		return true
	case "Close":
		put_text(buf, n, pad_in_use ? PAD_NAME[bindings[.Grab].pad] : "ESC")
		return true
	}
	for b in Button {
		if BUTTON_WORD[b] == word {
			put_text(buf, n, button_word(b))
			return true
		}
	}
	return false
}

// Gives an action a key (slot 0 or 1). An action that had that key already
// swaps: it gets the one this action had. Says why not, if it cannot be.
assign_key :: proc(b: Button, slot: int, k: Key) -> (ok: bool, why: string) {
	if key_reserved(k) {
		return false, "That key is kept for moving, pausing or the pixel size."
	}
	old := bindings[b].keys[slot]
	if k == old {
		return true, ""
	}
	if bindings[b].keys[1 - slot] == k {
		bindings[b].keys[1 - slot], bindings[b].keys[slot] = old, k
		tidy_keys(b)
		return true, ""
	}
	for c in REMAPPABLE {
		if c == b {
			continue
		}
		for t in 0 ..< 2 {
			if bindings[c].keys[t] == k && old == KEY_NONE && bindings[c].keys[1 - t] == KEY_NONE {
				return false, "That is the only key of another action: give it another key first."
			}
		}
	}
	for c in REMAPPABLE {
		if c == b {
			continue
		}
		for t in 0 ..< 2 {
			if bindings[c].keys[t] == k {
				bindings[c].keys[t] = old
				tidy_keys(c)
			}
		}
	}
	bindings[b].keys[slot] = k
	tidy_keys(b)
	return true, ""
}

// An action with only a second key has it as its first.
@(private = "file")
tidy_keys :: proc(b: Button) {
	if bindings[b].keys[0] == KEY_NONE {
		bindings[b].keys[0], bindings[b].keys[1] = bindings[b].keys[1], KEY_NONE
	}
}

// Takes an action's second key away.
clear_second_key :: proc(b: Button) {
	bindings[b].keys[1] = KEY_NONE
}

// Gives an action a controller button; an action that had it swaps.
assign_pad :: proc(b: Button, p: Pad) -> (ok: bool, why: string) {
	if p not_in PAD_ASSIGNABLE {
		return false, "The D-pad moves him and MENU pauses: choose another button."
	}
	old := bindings[b].pad
	for c in REMAPPABLE {
		if c != b && bindings[c].pad == p {
			bindings[c].pad = old
		}
	}
	bindings[b].pad = p
	return true, ""
}

reset_controls :: proc() {
	bindings = DEFAULT_BINDINGS
}

// The changeable controls as text, a line for each: its word, its two keys
// and its controller button, as in "Jump 74 88 RT".
CONTROLS_TEXT_ROOM :: 512

encode_controls :: proc(out: []u8) -> int {
	n := 0
	put :: proc(out: []u8, n: ^int, s: string) {
		for i in 0 ..< len(s) {
			if n^ < len(out) {
				out[n^] = s[i]
				n^ += 1
			}
		}
	}
	number: [16]u8
	for b in REMAPPABLE {
		put(out, &n, BUTTON_WORD[b])
		for k in bindings[b].keys {
			put(out, &n, " ")
			put(out, &n, strconv.write_int(number[:], i64(k), 10))
		}
		put(out, &n, " ")
		put(out, &n, PAD_NAME[bindings[b].pad])
		put(out, &n, "\n")
	}
	return n
}

// Reads what encode_controls wrote; a line it cannot make sense of is left
// out, and that action keeps what it has.
decode_controls :: proc(data: []u8) {
	text := string(data)
	for line in strings.split_lines_iterator(&text) {
		fields: [4]string
		count := 0
		rest := line
		for field in strings.fields_iterator(&rest) {
			if count < len(fields) {
				fields[count] = field
			}
			count += 1
		}
		if count != 4 {
			continue
		}
		b, found := Button.Left, false
		for c in REMAPPABLE {
			if BUTTON_WORD[c] == fields[0] {
				b, found = c, true
			}
		}
		k0, ok0 := strconv.parse_int(fields[1])
		k1, ok1 := strconv.parse_int(fields[2])
		pad, pad_found := Pad.None, false
		for p in Pad {
			if PAD_NAME[p] == fields[3] && p in PAD_ASSIGNABLE {
				pad, pad_found = p, true
			}
		}
		if !found || !ok0 || !ok1 || !pad_found || k0 <= 0 || key_reserved(Key(k0)) || (k1 != 0 && key_reserved(Key(k1))) {
			continue
		}
		bindings[b] = {{Key(k0), Key(k1)}, pad}
	}
}

save_controls :: proc() {
	if !keyboard_enabled {
		return // test runs never touch the real settings
	}
	data: [CONTROLS_TEXT_ROOM]u8
	n := encode_controls(data[:])
	store_write(data[:n], .Controls)
}

load_controls :: proc() {
	if !keyboard_enabled {
		return
	}
	data: [CONTROLS_TEXT_ROOM]u8
	if n := store_read(data[:], .Controls); n > 0 {
		decode_controls(data[:n])
	}
}

// The Controls panel of the M menu: a row for each action, and a last row
// that puts everything back. The columns are the controller button and the
// two keys. Choosing a cell waits for the new button.
CONTROLS_WAIT :: f32(6) // seconds it waits for a button before giving up
controls_row: int // 0 to len(REMAPPABLE): the last is "back to the defaults"
controls_col: int // 0 the controller, 1 the key, 2 the other key
controls_waiting: bool
controls_wait_t: f32
controls_note: string
controls_note_t: f32

update_controls_panel :: proc(dt: f32) {
	controls_note_t -= dt
	rows := len(REMAPPABLE) + 1
	if controls_waiting {
		controls_wait_t -= dt
		b := REMAPPABLE[min(controls_row, len(REMAPPABLE) - 1)]
		key := key_hit_now()
		pad := pad_hit_now()
		switch {
		case key == KEY_ESCAPE || pad == .Start || controls_wait_t <= 0:
			controls_waiting = false
		case controls_col == 0 && pad != .None:
			ok, why := assign_pad(b, pad)
			note(ok ? "" : why)
			controls_waiting = false
		case controls_col > 0 && key == KEY_BACKSPACE:
			if controls_col == 2 || bindings[b].keys[1] != KEY_NONE {
				if controls_col == 1 {
					bindings[b].keys[0] = bindings[b].keys[1]
				}
				clear_second_key(b)
			} else {
				note("Every action keeps one key at least.")
			}
			controls_waiting = false
		case controls_col > 0 && key != KEY_NONE:
			ok, why := assign_key(b, controls_col - 1, key)
			note(ok ? "" : why)
			controls_waiting = false
		}
		if !controls_waiting {
			save_controls()
		}
		return
	}
	if button_pressed(.Down) {controls_row = (controls_row + 1) % rows}
	if button_pressed(.Up) {controls_row = (controls_row + rows - 1) % rows}
	if button_pressed(.Right) {controls_col = (controls_col + 1) % 3}
	if button_pressed(.Left) {controls_col = (controls_col + 2) % 3}
	if button_pressed(.Confirm) {
		if controls_row == len(REMAPPABLE) {
			reset_controls()
			save_controls()
			note("Back to the buttons it started with.")
		} else {
			controls_waiting = true
			controls_wait_t = CONTROLS_WAIT
		}
	}
}

@(private = "file")
note :: proc(text: string) {
	controls_note = text
	controls_note_t = 3
}

draw_controls_panel :: proc(x, y, w, s: f32) {
	name_size := 17 * s
	row_h := 30 * s
	col_x := [3]f32{x + 215 * s, x + 318 * s, x + 400 * s}
	col_w := [3]f32{96 * s, 76 * s, 76 * s}
	header := [3]cstring{"XBOX", "KEY", "OR KEY"}
	for c in 0 ..< 3 {
		label(header[c], col_x[c] + 6 * s, y, 14 * s, {200, 200, 200, 255})
	}
	top := y + 24 * s
	for b, i in REMAPPABLE {
		ry := top + f32(i) * row_h
		chosen_row := i == controls_row
		label(control_cname(b), x, ry + 6 * s, name_size, chosen_row ? UI_WHITE : Color{210, 210, 210, 255})
		for c in 0 ..< 3 {
			text: string
			switch c {
			case 0:
				text = PAD_NAME[bindings[b].pad]
			case 1, 2:
				text = key_name(bindings[b].keys[c - 1])
				if c == 2 && bindings[b].keys[1] == KEY_NONE {
					text = "-"
				}
			}
			chosen := chosen_row && c == controls_col
			if chosen {
				ui_round_rect(col_x[c], ry, col_w[c], row_h - 4 * s, {250, 172, 182, 235}, 0.4)
			} else {
				ui_round_rect(col_x[c], ry, col_w[c], row_h - 4 * s, {255, 255, 255, 30}, 0.4)
			}
			if chosen && controls_waiting {
				text = int(controls_wait_t * 3) % 2 == 0 ? "..." : ""
			}
			cs := short_cstring(text)
			size := 16 * s
			for size > 9 * s && ui_text_width(cs, size) > col_w[c] - 8 * s {
				size -= 1 * s
			}
			ui_text(cs, col_x[c] + col_w[c] / 2 - ui_text_width(cs, size) / 2, ry + (row_h - 4 * s - size) / 2, size, chosen ? UI_DARK : UI_WHITE)
		}
	}
	// The last row: back to the defaults.
	ry := top + f32(len(REMAPPABLE)) * row_h + 8 * s
	reset: cstring = "BACK TO THE DEFAULTS"
	rw := ui_text_width(reset, 18 * s) + 28 * s
	if controls_row == len(REMAPPABLE) {
		ui_round_rect(x, ry, rw, row_h, {250, 172, 182, 235}, 0.4)
		ui_text(reset, x + 14 * s, ry + 6 * s, 18 * s, UI_DARK)
	} else {
		label(reset, x + 14 * s, ry + 6 * s, 18 * s, {210, 210, 210, 255})
	}

	info := ry + row_h + 16 * s
	label("Always: stick, D-pad, WASD or arrows move; MENU or ESC pauses;", x, info, 14 * s, {200, 200, 200, 255})
	label("A, ENTER or SPACE chooses. Clicking a stick to sprint keeps", x, info + 18 * s, 14 * s, {200, 200, 200, 255})
	label("him running until he stops; any other sprint button is held.", x, info + 36 * s, 14 * s, {200, 200, 200, 255})

	line: cstring
	switch {
	case controls_waiting && controls_col == 0:
		line = "Press a button on the controller   (MENU or ESC: cancel)"
	case controls_waiting:
		line = "Press a key   (BACKSPACE: none   ESC: cancel)"
	case controls_note_t > 0 && controls_note != "":
		line = short_cstring(controls_note)
	}
	if line != nil {
		label(line, x, info + 62 * s, 15 * s, controls_waiting ? UI_YELLOW : UI_ORANGE)
	}
}

control_cname :: proc(b: Button) -> cstring {
	return short_cstring(CONTROL_NAME[b])
}

// A short string as a cstring for drawing, in one of a few small buffers.
@(private = "file")
short_buffers: [8][96]u8
@(private = "file")
short_next: int

short_cstring :: proc(s: string) -> cstring {
	buf := &short_buffers[short_next]
	short_next = (short_next + 1) % len(short_buffers)
	n := min(len(s), len(buf) - 1)
	copy(buf[:n], s[:n])
	buf[n] = 0
	return cstring(raw_data(buf[:]))
}
