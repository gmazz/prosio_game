package main_web

// Entry point for the browser. The page calls these procedures:
// main_start once, then main_update every frame.

import game "../game"
import "base:runtime"
import "core:c"

@(private = "file")
web_context: runtime.Context

@(export)
main_start :: proc "c" () {
	context = runtime.default_context()
	// The game allocates no memory of its own, so it needs no allocator here.
	context.allocator = runtime.nil_allocator()
	context.temp_allocator = runtime.nil_allocator()
	web_context = context
	game.init({})
}

@(export)
main_update :: proc "c" () -> bool {
	context = web_context
	game.frame()
	return game.running()
}

@(export)
main_end :: proc "c" () {
	context = web_context
	game.shutdown()
}

@(export)
web_window_size_changed :: proc "c" (w: c.int, h: c.int) {
	context = web_context
	game.set_window_size(int(w), int(h))
}
