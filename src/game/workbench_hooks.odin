package game

// What the workbench (src/workbench, built by tools/workbench.sh) needs from
// the game, and only in its own build: the game the players get is built
// without WORKBENCH, so none of this is in it (a rule in tools/check.sh
// keeps it so).
//
// The workbench runs the game as a library it rebuilds and swaps in on every
// save. Two hooks let its panels run after the game's update and after its
// drawing; Kept is what lives outside g and must survive a swap.
WORKBENCH :: #config(WORKBENCH, false)

when WORKBENCH {
	workbench_after_update: proc()
	workbench_after_draw: proc()

	// Besides g: which screen is showing, his outfit, the language, the key
	// bindings and the pixel size. (Menu cursors and the like start again.)
	Kept :: struct {
		scene:       Scene,
		outfit:      Outfit,
		language:    Language,
		bindings:    type_of(bindings),
		pixel_level: int,
	}

	kept :: proc() -> Kept {
		return {scene, outfit, language, bindings, pixel_level}
	}

	restore_kept :: proc(k: Kept) {
		scene, outfit, bindings, pixel_level = k.scene, k.outfit, k.bindings, k.pixel_level
		set_language(k.language)
	}
}
