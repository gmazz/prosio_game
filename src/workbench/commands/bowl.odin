package workbench_commands

// A bowl in words, for the Mixing pane's "mixing bowl" command: parts split
// by commas, each an amount and a food: "500g flour, 300ml water, 2 eggs,
// 3 pinches salt" (a bare number is in the food's own unit). As
// tools/check.sh mix reads one, more briefly.

import game "../../game"
import "core:fmt"
import "core:reflect"
import "core:strconv"
import "core:strings"

parse_bowl :: proc(text: string) -> (parts: [game.BOWL_KINDS]game.Bowl_Part, n: int, err: string) {
	rest := text
	for piece in strings.split_iterator(&rest, ",") {
		words := strings.fields(strings.to_lower(piece, context.temp_allocator), context.temp_allocator)
		if len(words) == 0 {continue}
		amount: f32 = 1
		unit, name := "", ""
		for word in words {
			digits := 0
			for digits < len(word) && (word[digits] >= '0' && word[digits] <= '9' || word[digits] == '.') {digits += 1}
			switch {
			case digits > 0:
				amount, _ = strconv.parse_f32(word[:digits])
				unit = word[digits:]
			case word == "g" || word == "ml" || word == "pinch" || word == "pinches" || word == "egg" || word == "eggs" && name != "":
				unit = word
			case word == "of":
			case:
				name = name == "" ? word : fmt.tprintf("%s_%s", name, word)
			}
		}
		if name == "" && (unit == "egg" || unit == "eggs") {name = "egg"}
		food, known := food_named(name)
		milled := false
		if !known && strings.has_suffix(name, "_flour") {
			food, known = food_named(name[:len(name) - len("_flour")])
			milled = known
		}
		if !known {return parts, n, fmt.tprintf("no food called \"%s\"", strings.trim_space(piece))}
		if n == game.BOWL_KINDS {return parts, n, fmt.tprintf("more than %d things", game.BOWL_KINDS)}
		if milled {
			flour, _, why := game.flour_of(food, unit == "" || unit == "g" || unit == "ml" ? amount : amount * game.PINCH_G)
			if why != .None {return parts, n, fmt.tprintf("%v will not make a flour: %s", food, game.TEXT.mill_refused[why])}
			parts[n] = flour
			n += 1
			continue
		}
		switch unit {
		case "g", "ml": amount /= game.unit_grams(food)
		case "pinch", "pinches": amount = amount * game.PINCH_G / game.unit_grams(food)
		}
		parts[n] = {food = food, amount = amount}
		n += 1
	}
	return
}

food_named :: proc(name: string) -> (game.Mixable, bool) {
	tries := [3]string{name, strings.trim_suffix(name, "s"), strings.trim_suffix(name, "es")}
	for try in tries {
		for field, i in reflect.enum_field_names(game.Mixable) {
			if strings.equal_fold(try, field) {return game.Mixable(reflect.enum_field_values(game.Mixable)[i]), true}
		}
	}
	if strings.has_suffix(name, "ies") {return food_named(fmt.tprintf("%sy", name[:len(name) - 3]))}
	return {}, false
}
