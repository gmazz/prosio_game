package workbench

// Seeing inside: switches (the "show" commands of the menu) that draw over
// the world what is normally hidden. They are drawn after the game, through
// the same camera, sharp over the pixel art.

import cmd "commands"
import game "../game"
import "core:fmt"
import "core:math"
import "core:strings"
import rl "vendor:raylib"

Overlay :: enum {
	Collisions, // circles things bump with; his grab reach; his grip point
	Animals, // what each is doing and how long for, where it is heading, its home
	Grid, // the fence grid round him, and the fences
	Regions, // the borders of the meadow's regions
	Growth, // how far each food has grown, and how long fallen ones last
	Body, // the 36 parts of his pose
	Timing, // the frame's time: updating and drawing
}

overlays: bit_set[Overlay]

// Time spent in a frame, for the Timing overlay.
update_ms, draw_ms: f32

OVERLAY_TEXT :: 15

show :: proc(name: string) -> string {
	o, ok := cmd.enum_named(Overlay, name)
	if !ok {
		names: [dynamic]string
		names.allocator = context.temp_allocator
		for v in Overlay {append(&names, strings.to_lower(fmt.tprintf("%v", v), context.temp_allocator))}
		return fmt.tprintf("show what? %s", strings.join(names[:], ", ", context.temp_allocator))
	}
	overlays ~= {o}
	return fmt.tprintf("%v %s", o, o in overlays ? "shown" : "hidden")
}

ground :: proc(p: game.Vec2, h: f32 = 0.05) -> rl.Vector3 {
	return {p.x, h, p.y}
}

circle :: proc(c: game.Vec2, r: f32, color: rl.Color, h: f32 = 0.05) {
	rl.DrawCircle3D(ground(c, h), r, {1, 0, 0}, 90, color)
}

// Text over a place in the world.
label_at :: proc(pos: rl.Vector3, text: string, color: rl.Color, cam: rl.Camera3D) {
	s := rl.GetWorldToScreen(pos, cam)
	w := f32(len(text)) * editor.cell * OVERLAY_TEXT / EDITOR_FONT_SIZE
	rl.DrawRectangleRec({s.x - w / 2 - 3, s.y - 2, w + 6, OVERLAY_TEXT + 4}, {10, 12, 16, 190})
	col := 0
	for r in text {
		rl.DrawTextCodepoint(editor.font, r, {s.x - w / 2 + f32(col) * editor.cell * OVERLAY_TEXT / EDITOR_FONT_SIZE, s.y}, OVERLAY_TEXT, color)
		col += 1
	}
}

draw_overlays :: proc() {
	if overlays == {} {return}
	g := &game.g
	p := &g.prosio
	cam := view_camera()
	near :: proc(a, b: game.Vec2) -> bool {return game.length2(a - b) < 40}

	rl.BeginMode3D(cam)
	if .Collisions in overlays {
		circle(p.pos, game.prosio_radius(p.kg), {255, 220, 90, 255})
		circle(p.pos, game.prosio_radius(p.kg) + game.GRAB_REACH, {255, 140, 60, 200})
		rl.DrawSphereWires(p.hand, 0.08, 6, 6, {255, 80, 80, 255})
		for e in g.enemies[:g.enemy_count] {
			if e.state != .Gone && near(e.pos, p.pos) {circle(e.pos, game.ENEMY_RADIUS[e.kind], {120, 220, 255, 255}, e.y + 0.05)}
		}
		for r in g.rounds[:g.round_count] {
			if near(r.pos, p.pos) {circle(r.pos, r.r, {180, 255, 160, 200})}
		}
		if target, found := game.grab_target(); found {
			at: game.Vec2
			shown := true
			#partial switch target.kind {
			case .Enemy: at = g.enemies[target.index].pos
			case .Rock: at = g.rounds[target.index].pos
			case: shown = false
			}
			if shown {rl.DrawSphereWires(ground(at, 0.4), 0.25, 6, 6, {255, 80, 80, 255})}
		}
	}
	if .Animals in overlays {
		for e in g.enemies[:g.enemy_count] {
			if e.state == .Gone || !near(e.pos, p.pos) {continue}
			rl.DrawLine3D(ground(e.pos, 0.3), ground(e.pos + e.vel * 0.8, 0.3), {120, 220, 255, 255})
			rl.DrawLine3D(ground(e.pos, 0.1), ground(e.home, 0.1), {120, 140, 180, 120})
			circle(e.home, 0.3, {120, 140, 180, 200})
		}
	}
	if .Grid in overlays {
		cx, cy := game.fence_cell(p.pos)
		for dy in -6 ..= 6 {
			for dx in -6 ..= 6 {
				for way in game.Fence_Way {
					f := game.Fence_At{cx + dx, cy + dy, way}
					if !game.fence_valid(f) {continue}
					a, b := game.fence_ends(f)
					there := game.fence_there(f)
					rl.DrawLine3D(ground(a, there ? 0.6 : 0.03), ground(b, there ? 0.6 : 0.03), there ? rl.Color{255, 200, 80, 255} : rl.Color{200, 200, 200, 70})
				}
			}
		}
	}
	if .Regions in overlays {
		for region, kind in game.REGIONS {
			_ = kind
			steps :: 64
			for i in 0 ..< steps {
				a := f32(i) / steps * math.TAU
				b := f32(i + 1) / steps * math.TAU
				pa := region.centre + {math.cos(a) * region.radius.x, math.sin(a) * region.radius.y}
				pb := region.centre + {math.cos(b) * region.radius.x, math.sin(b) * region.radius.y}
				rl.DrawLine3D(ground(pa, 0.1), ground(pb, 0.1), {255, 120, 220, 220})
			}
		}
	}
	if .Body in overlays {
		pose := game.prosio_pose()
		for piece in pose.pieces {
			m := piece.frame
			o := rl.Vector3{m[0, 3], m[1, 3], m[2, 3]}
			rl.DrawLine3D(o, o + {m[0, 0], m[1, 0], m[2, 0]}, {255, 90, 90, 255})
			rl.DrawLine3D(o, o + {m[0, 1], m[1, 1], m[2, 1]}, {90, 255, 90, 255})
			rl.DrawLine3D(o, o + {m[0, 2], m[1, 2], m[2, 2]}, {90, 140, 255, 255})
		}
	}
	rl.EndMode3D()

	// The words, over that.
	if .Animals in overlays {
		for e in g.enemies[:g.enemy_count] {
			if e.state == .Gone || !near(e.pos, p.pos) {continue}
			label_at({e.pos.x, e.y + 1.6, e.pos.y}, fmt.tprintf("%v %v %.1fs hp %.0f", e.kind, e.state, e.timer, e.health), {200, 235, 255, 255}, cam)
		}
	}
	if .Regions in overlays {
		for region, kind in game.REGIONS {
			label_at(ground(region.centre, 0.5), fmt.tprintf("%v", kind), {255, 170, 230, 255}, cam)
		}
	}
	if .Growth in overlays {
		for f in g.foods[:g.food_count] {
			if f.gone || !near(f.pos, p.pos) {continue}
			text := f.fallen ? fmt.tprintf("%v lasts %.0fs", f.kind, f.life) : fmt.tprintf("%v %.0f%%", f.kind, f.grow * 100)
			label_at({f.pos.x, f.y + 0.6, f.pos.y}, text, {190, 255, 170, 255}, cam)
		}
	}
	if .Body in overlays {
		pose := game.prosio_pose()
		for piece, part in pose.pieces {
			m := piece.frame
			if part == .Head || part == .Belly || part == .Pelvis || part == .Hand_L || part == .Hand_R {
				label_at({m[0, 3], m[1, 3] + 0.1, m[2, 3]}, fmt.tprintf("%v", part), {255, 255, 255, 255}, cam)
			}
		}
	}
	if .Timing in overlays {
		avg_work: f32
		for ms in work_ms {avg_work += ms / FRAME_SAMPLES}
		text := fmt.tprintf("update %.2f ms   draw %.2f ms   whole frame's work %.2f ms   (skinning is inside drawing)", update_ms, draw_ms, avg_work)
		w := f32(len(text)) * editor.cell
		x := f32(rl.GetScreenWidth()) / (editor.visible ? 4 : 2) - w / 2
		rl.DrawRectangleRec({x - 6, 92, w + 12, editor.line_h + 6}, {10, 12, 16, 210})
		draw_mono(text, x, 95, {250, 210, 90, 255})
	}
}
