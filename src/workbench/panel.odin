package workbench

// The workbench's own drawing, over the game. (The workbench may call raylib
// itself; the game keeps raylib to platform.odin.)

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

PANEL_TEXT :: 20 // text size, in pixels of the window
PANEL_PAD :: 8

// One line along the bottom: what the workbench is doing. When the last build
// failed, the compiler's errors over the left of the window: the game behind
// them is still the last one that built.
draw_status :: proc() {
	w := rl.GetScreenWidth()
	h := rl.GetScreenHeight()
	avg: f32
	for ms in frame_ms {avg += ms / FRAME_SAMPLES}
	line: cstring
	color := rl.Color{230, 230, 220, 255}
	switch status.phase {
	case .Running:
		if status.swaps == 0 {
			line = fmt.ctprintf("workbench · %.1f ms a frame · save a file to rebuild", avg)
		} else {
			line = fmt.ctprintf("workbench · %.1f ms a frame · swap %d: built in %.2f s, on screen %.2f s after the save%s",
				avg, status.swaps, status.build_s, status.swap_ms / 1000, status.fresh ? " · the state changed shape: a fresh scene" : "")
		}
	case .Building:
		line = fmt.ctprintf("workbench · %.1f ms a frame · building...", avg)
		color = {250, 210, 90, 255}
	case .Failed:
		line = fmt.ctprintf("workbench · %.1f ms a frame · the build failed: the game is the last one that built", avg)
		color = {255, 120, 110, 255}
	}
	// (Over the left half only, when the editor is open over the right.)
	bar_w := editor.visible ? w / 2 : w
	rl.BeginScissorMode(0, 0, bar_w, h)
	defer rl.EndScissorMode()
	rl.DrawRectangle(0, h - PANEL_TEXT - 2 * PANEL_PAD, bar_w, PANEL_TEXT + 2 * PANEL_PAD, {20, 22, 26, 220})
	rl.DrawText(line, PANEL_PAD, h - PANEL_TEXT - PANEL_PAD, PANEL_TEXT, color)
	if status.phase == .Failed {
		// (Over the left half when the editor is open. A click on an error
		// opens its file at its line.)
		pw := editor.visible ? w / 2 : w
		lines := strings.split_lines(status.text, context.temp_allocator)
		shown := min(len(lines), int((h - 3 * PANEL_TEXT) / (PANEL_TEXT + 4)) - 2)
		box_h := i32(shown) * (PANEL_TEXT + 4) + 2 * PANEL_PAD
		rl.DrawRectangle(0, 0, pw, box_h, {40, 14, 14, 235})
		m := rl.GetMousePosition()
		for i in 0 ..< shown {
			y := PANEL_PAD + i32(i) * (PANEL_TEXT + 4)
			over := m.y >= f32(y) && m.y < f32(y + PANEL_TEXT + 4) && m.x < f32(pw)
			if over && rl.IsMouseButtonPressed(.LEFT) {open_error_line(lines[i])}
			rl.DrawText(strings.clone_to_cstring(lines[i], context.temp_allocator), PANEL_PAD, y, PANEL_TEXT, over ? rl.Color{255, 240, 200, 255} : rl.Color{255, 200, 190, 255})
		}
	}
}

// A line of the compiler's errors, clicked: its file opened at its line.
open_error_line :: proc(line: string) {
	for e in editor.errors {
		if strings.contains(line, fmt.tprintf("%s(%d:%d)", e.path, e.line, e.col)) {
			editor_open(e.path, e.line, e.col)
			return
		}
	}
}
