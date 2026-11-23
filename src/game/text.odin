package game

// The words the game shows live in data/text/<language>.json, one file to a
// language, and reach the code as one struct of texts: TEXT.sack_full,
// TEXT.item_name[.Apple] (see gen_text.odin, made from those files when the
// game is built). The code holds no text of its own a player could read.
//
// A text can have names in braces. Those with a capital are buttons, written
// out when the text is drawn ("{Action}: pick it", see expand_keys); those
// in small letters are filled in here, by name, so a language can put them
// in whatever order it needs:
//
//   fill(TEXT.pick_kcal, {"kcal", 120})        "{Action}: pick it (120 kcal)"

import "core:strconv"

// A number with a fixed count of places after the point, in whole units of
// the last place: Decimal{125, 2} is 1.25 (with the language's own point).
Decimal :: struct {
	units:  int,
	places: int,
}

Arg :: struct {
	name:  string,
	value: union {
		int,
		cstring,
		Decimal,
	},
}

// The filled texts last until a few more are made: one drawn this frame, or
// one kept by copying it (see say_filled).
@(private = "file")
filled: [8][256]u8
@(private = "file")
filled_next: int

fill :: proc(format: cstring, args: ..Arg) -> cstring {
	buf := &filled[filled_next]
	filled_next = (filled_next + 1) % len(filled)
	n := 0
	put :: proc(buf: ^[256]u8, n: ^int, s: string) {
		for i in 0 ..< len(s) {
			if n^ < len(buf) - 1 {
				buf[n^] = s[i]
				n^ += 1
			}
		}
	}
	s := string(format)
	outer: for i := 0; i < len(s); {
		if s[i] == '{' {
			end := i + 1
			for end < len(s) && s[end] != '}' {
				end += 1
			}
			if end < len(s) {
				for a in args {
					if a.name != s[i + 1:end] {
						continue
					}
					number: [32]u8
					switch v in a.value {
					case int:
						put(buf, &n, strconv.write_int(number[:], i64(v), 10))
					case cstring:
						put(buf, &n, string(v))
					case Decimal:
						scale := 1
						for _ in 0 ..< v.places {
							scale *= 10
						}
						units := v.units
						if units < 0 {
							put(buf, &n, "-")
							units = -units
						}
						put(buf, &n, strconv.write_int(number[:], i64(units / scale), 10))
						if v.places > 0 {
							put(buf, &n, string(TEXT.decimal_point))
							part := strconv.write_int(number[:], i64(scale + units % scale), 10)
							put(buf, &n, part[1:]) // (with its leading zeros)
						}
					}
					i = end + 1
					continue outer
				}
			}
		}
		put(buf, &n, s[i:i + 1])
		i += 1
	}
	buf[n] = 0
	return cstring(raw_data(buf[:]))
}

// A whole number, as a text.
number_text :: proc(n: int) -> cstring {
	return fill("{n}", {"n", n})
}

// He says a filled text: it is kept here, as the filled one does not last.
@(private = "file")
said: [256]u8
say_filled :: proc(text: cstring, seconds: f32 = 2) {
	s := string(text)
	n := min(len(s), len(said) - 1)
	copy(said[:n], s[:n])
	said[n] = 0
	say(cstring(&said[0]), seconds)
}
