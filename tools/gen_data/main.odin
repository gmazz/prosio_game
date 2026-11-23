package gen_data

// Turns the game's data files into Odin code, when the game is built.
//
//   data/tuning/<subject>.json  ->  src/game/gen_<subject>.odin
//
// The game itself never reads JSON: everything that shapes it is in these
// files, and this tool writes them out as the constants and tables the code
// uses, so a value used as the size of an array can live here too, a typo
// in a name stops the build, and nothing is read or allocated while playing.
//
// A tuning file is an object. Its "_about" is a note on the whole file. A
// key in CAPITALS is a value; any other key is a section, an object of more
// values (with its own "_about"). A value is an object with its type as the
// key and the value under it, a line saying what it is, and optionally
// whether it is a table the code may change ("const": false) or a table
// that leaves some entries out ("partial": true):
//
//   "NEED_LOW": { "f32": 15, "about": "below this he lacks it" }
//   "TREE_HEIGHT": { "[Tree_Species]f32": { "Broadleaf": 5.4, "Pine": 5.8 } }
//
// Inside a value: a key or a word with a capital and small letters is a
// name from an enum ("Wood" is .Wood); a key in small letters is a field of
// a struct; any other text (a name in CAPITALS, "math.PI / 6", "Key('A')")
// is written into the code as it is. A plain type (f32, int, i32, u8, u32,
// bool, or "untyped" for a bare number) makes a constant; any other type a
// table, which is a constant only with "const": true.
//
//   tools/gen_data.sh     (the build scripts run it)

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strconv"
import "core:strings"

main :: proc() {
	root := len(os.args) > 1 ? os.args[1] : "."
	tuning := path_join(root, "data", "tuning")
	out_dir := path_join(root, "src", "game")
	matches, _ := filepath.glob(path_join(tuning, "*.json"))
	slice.sort(matches)
	failed := false
	written: [dynamic]string
	for path in matches {
		subject := strings.trim_suffix(filepath.base(path), ".json")
		out := path_join(out_dir, fmt.tprintf("gen_%s.odin", subject))
		code, ok := generate_tuning(path)
		if !ok {
			failed = true
			continue
		}
		append(&written, filepath.base(out))
		old, _ := os.read_entire_file(out, context.allocator)
		if string(old) != code {
			if os.write_entire_file(out, code) != nil {
				fmt.eprintfln("gen_data: could not write %s", out)
				failed = true
			}
		}
	}
	// A generated file whose data file is gone goes too.
	if existing, err := filepath.glob(path_join(out_dir, "gen_*.odin")); err == nil {
		for path in existing {
			if !slice.contains(written[:], filepath.base(path)) && !strings.has_prefix(filepath.base(path), "gen_text") {
				os.remove(path)
			}
		}
	}
	os.exit(failed ? 1 : 0)
}

path_join :: proc(parts: ..string) -> string {
	joined, _ := filepath.join(parts)
	return joined
}

// ---- Reading JSON, keeping the order of keys and where each one is. ----

Node :: struct {
	kind:   enum {Null, Number, String, Bool, Array, Object},
	text:   string, // a number as written, or a string
	truth:  bool,
	items:  [dynamic]Node, // an array's
	keys:   [dynamic]string, // an object's, in order,
	values: [dynamic]Node, // with their values
	line:   int,
}

Reader :: struct {
	src:  string,
	at:   int,
	line: int,
	file: string,
	bad:  bool,
}

complain :: proc(r: ^Reader, format: string, args: ..any) {
	if !r.bad {
		fmt.eprintf("%s:%d: ", r.file, r.line)
		fmt.eprintfln(format, ..args)
	}
	r.bad = true
}

skip_space :: proc(r: ^Reader) {
	for r.at < len(r.src) {
		switch r.src[r.at] {
		case '\n':
			r.line += 1
			r.at += 1
		case ' ', '\t', '\r':
			r.at += 1
		case:
			return
		}
	}
}

read_value :: proc(r: ^Reader) -> (n: Node) {
	skip_space(r)
	n.line = r.line
	if r.at >= len(r.src) {
		complain(r, "the file ends where a value should be")
		return
	}
	c := r.src[r.at]
	switch {
	case c == '{':
		n.kind = .Object
		r.at += 1
		skip_space(r)
		if r.at < len(r.src) && r.src[r.at] == '}' {
			r.at += 1
			return
		}
		for !r.bad {
			skip_space(r)
			if r.at >= len(r.src) || r.src[r.at] != '"' {
				complain(r, "expected a key in quotes")
				return
			}
			key := read_string(r)
			if slice.contains(n.keys[:], key) {
				complain(r, "\"%s\" is given twice", key)
				return
			}
			skip_space(r)
			if r.at >= len(r.src) || r.src[r.at] != ':' {
				complain(r, "expected : after \"%s\"", key)
				return
			}
			r.at += 1
			append(&n.keys, key)
			append(&n.values, read_value(r))
			skip_space(r)
			if r.at < len(r.src) && r.src[r.at] == ',' {
				r.at += 1
				continue
			}
			if r.at < len(r.src) && r.src[r.at] == '}' {
				r.at += 1
				return
			}
			complain(r, "expected , or } after the value of \"%s\" (a missing comma?)", key)
			return
		}
	case c == '[':
		n.kind = .Array
		r.at += 1
		skip_space(r)
		if r.at < len(r.src) && r.src[r.at] == ']' {
			r.at += 1
			return
		}
		for !r.bad {
			append(&n.items, read_value(r))
			skip_space(r)
			if r.at < len(r.src) && r.src[r.at] == ',' {
				r.at += 1
				continue
			}
			if r.at < len(r.src) && r.src[r.at] == ']' {
				r.at += 1
				return
			}
			complain(r, "expected , or ] in a list (a missing comma?)")
			return
		}
	case c == '"':
		n.kind = .String
		n.text = read_string(r)
	case c == '-' || (c >= '0' && c <= '9'):
		n.kind = .Number
		start := r.at
		r.at += 1
		for r.at < len(r.src) && strings.contains_rune("0123456789.eE+-", rune(r.src[r.at])) {
			r.at += 1
		}
		n.text = r.src[start:r.at]
		if _, ok := strconv.parse_f64(n.text); !ok {
			complain(r, "\"%s\" is not a number", n.text)
		}
	case strings.has_prefix(r.src[r.at:], "true"):
		n.kind, n.truth = .Bool, true
		r.at += 4
	case strings.has_prefix(r.src[r.at:], "false"):
		n.kind = .Bool
		r.at += 5
	case strings.has_prefix(r.src[r.at:], "null"):
		n.kind = .Null
		r.at += 4
	case:
		complain(r, "unexpected '%c'", c)
	}
	return
}

read_string :: proc(r: ^Reader) -> string {
	r.at += 1 // the opening quote
	b := strings.builder_make()
	for r.at < len(r.src) {
		c := r.src[r.at]
		switch c {
		case '"':
			r.at += 1
			return strings.to_string(b)
		case '\n':
			complain(r, "a string runs on past the end of its line")
			return strings.to_string(b)
		case '\\':
			r.at += 1
			if r.at >= len(r.src) {
				break
			}
			switch r.src[r.at] {
			case 'n':
				strings.write_byte(&b, '\n')
			case 't':
				strings.write_byte(&b, '\t')
			case 'u':
				if r.at + 4 < len(r.src) {
					code, _ := strconv.parse_int(r.src[r.at + 1:r.at + 5], 16)
					strings.write_rune(&b, rune(code))
					r.at += 4
				}
			case:
				strings.write_byte(&b, r.src[r.at])
			}
			r.at += 1
		case:
			strings.write_byte(&b, c)
			r.at += 1
		}
	}
	complain(r, "a string never ends")
	return strings.to_string(b)
}

read_file :: proc(path: string) -> (root: Node, ok: bool) {
	data, err := os.read_entire_file(path, context.allocator)
	if err != nil {
		fmt.eprintfln("%s: cannot be read", path)
		return
	}
	r := Reader{src = string(data), line = 1, file = path}
	root = read_value(&r)
	skip_space(&r)
	if !r.bad && r.at < len(r.src) {
		complain(&r, "something follows the end of the data")
	}
	return root, !r.bad
}

// ---- Writing tuning values as Odin. ----

SCALARS :: []string{"f32", "f64", "int", "i32", "u8", "u32", "bool", "untyped"}

is_capitals :: proc(s: string) -> bool {
	if len(s) == 0 || !(s[0] >= 'A' && s[0] <= 'Z') {
		return false
	}
	for c in s {
		if !((c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_') {
			return false
		}
	}
	return true
}

// A name from an enum, as written in the data: a capital, then letters,
// digits or underscores, with at least one small letter (so not CAPITALS).
is_enum_name :: proc(s: string) -> bool {
	if len(s) == 0 || !(s[0] >= 'A' && s[0] <= 'Z') {
		return false
	}
	small := false
	for c in s {
		switch {
		case c >= 'a' && c <= 'z':
			small = true
		case (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_':
		case:
			return false
		}
	}
	return small
}

is_field_name :: proc(s: string) -> bool {
	if len(s) == 0 || !(s[0] >= 'a' && s[0] <= 'z') {
		return false
	}
	for c in s {
		if !((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '_') {
			return false
		}
	}
	return true
}

write_literal :: proc(b: ^strings.Builder, n: Node) {
	switch n.kind {
	case .Null:
		strings.write_string(b, "{}")
	case .Number:
		strings.write_string(b, n.text)
	case .Bool:
		strings.write_string(b, n.truth ? "true" : "false")
	case .String:
		if is_enum_name(n.text) {
			strings.write_byte(b, '.')
		}
		strings.write_string(b, n.text)
	case .Array:
		strings.write_byte(b, '{')
		for item, i in n.items {
			if i > 0 {
				strings.write_string(b, ", ")
			}
			write_literal(b, item)
		}
		strings.write_byte(b, '}')
	case .Object:
		strings.write_byte(b, '{')
		for key, i in n.keys {
			if i > 0 {
				strings.write_string(b, ", ")
			}
			switch {
			case is_enum_name(key):
				fmt.sbprintf(b, ".%s = ", key)
			case is_field_name(key):
				fmt.sbprintf(b, "%s = ", key)
			case:
				fmt.sbprintf(b, "%s = ", key) // (written as it is)
			}
			write_literal(b, n.values[i])
		}
		strings.write_byte(b, '}')
	}
}

write_comment :: proc(b: ^strings.Builder, text, indent: string) {
	for line in strings.split_lines(text) {
		fmt.sbprintfln(b, "%s// %s", indent, line)
	}
}

generate_tuning :: proc(path: string) -> (code: string, ok: bool) {
	root, read := read_file(path)
	if !read {
		return
	}
	if root.kind != .Object {
		fmt.eprintfln("%s: the file must be one object", path)
		return
	}
	b := strings.builder_make()
	body := strings.builder_make()
	ok = true
	write_section(&body, root, path, &ok)
	fmt.sbprintfln(&b, "package game\n")
	fmt.sbprintfln(&b, "// Made by tools/gen_data from data/tuning/%s: do not edit; edit that file.\n", filepath.base(path))
	if strings.contains(strings.to_string(body), "math.") {
		fmt.sbprintfln(&b, "import \"core:math\"\n")
		fmt.sbprintfln(&b, "_ :: math\n")
	}
	strings.write_string(&b, strings.to_string(body))
	return strings.to_string(b), ok
}

write_section :: proc(b: ^strings.Builder, section: Node, path: string, ok: ^bool) {
	for key, i in section.keys {
		value := section.values[i]
		switch {
		case key == "_about":
			if value.kind == .String {
				write_comment(b, value.text, "")
				strings.write_byte(b, '\n')
			}
		case is_capitals(key):
			write_entry(b, key, value, path, ok)
		case value.kind == .Object:
			fmt.sbprintfln(b, "// ---- %s ----", key)
			write_section(b, value, path, ok)
			strings.write_byte(b, '\n')
		case:
			fmt.eprintfln("%s:%d: \"%s\": a value's name is in CAPITALS; any other key is a section (an object)", path, value.line, key)
			ok^ = false
		}
	}
}

write_entry :: proc(b: ^strings.Builder, name: string, entry: Node, path: string, ok: ^bool) {
	if entry.kind != .Object {
		fmt.eprintfln("%s:%d: %s: write it as { \"type\": value, \"about\": \"...\" }", path, entry.line, name)
		ok^ = false
		return
	}
	type, about := "", ""
	value: Node
	constant, partial, has_constant := false, false, false
	for key, i in entry.keys {
		v := entry.values[i]
		switch key {
		case "about":
			about = v.text
		case "const":
			constant, has_constant = v.truth, true
		case "partial":
			partial = v.truth
		case:
			if type != "" {
				fmt.eprintfln("%s:%d: %s has two types, %s and %s", path, v.line, name, type, key)
				ok^ = false
				return
			}
			type, value = key, v
		}
	}
	if type == "" {
		fmt.eprintfln("%s:%d: %s has no type (such as \"f32\": 1.5)", path, entry.line, name)
		ok^ = false
		return
	}
	if about != "" {
		write_comment(b, about, "")
	}
	literal := strings.builder_make()
	write_literal(&literal, value)
	lit := strings.to_string(literal)
	scalar := slice.contains(SCALARS, type)
	switch {
	case type == "untyped":
		fmt.sbprintfln(b, "%s :: %s", name, value.kind == .String ? value.text : lit)
	case scalar:
		fmt.sbprintfln(b, "%s :: %s(%s)", name, type, value.kind == .String ? value.text : lit)
	case value.kind == .String:
		fmt.sbprintfln(b, "%s %s %s", name, constant ? "::" : ":=", value.text) // an expression, as it is
	case:
		if !has_constant {
			constant = false
		}
		fmt.sbprintfln(b, "%s %s %s%s%s", name, constant ? "::" : ":=", partial ? "#partial " : "", type, lit)
	}
}
