#+build darwin
package game

// The controller on a Mac. macOS keeps Xbox controllers to itself: the
// library raylib reads controllers with sees one plugged in but none of its
// buttons, so on a Mac the controller is read through Apple's own
// GameController framework instead (see poll_input in platform.odin).

import "base:intrinsics"
import NS "core:sys/darwin/Foundation"

@(require)
foreign import game_controller "system:GameController.framework"

@(private = "file")
Obj :: ^NS.Object

@(private = "file")
gc_get :: proc(o: Obj, $selector: string) -> Obj {
	if o == nil {
		return nil
	}
	return intrinsics.objc_send(Obj, o, selector)
}

@(private = "file")
gc_down :: proc(button: Obj) -> bool {
	return button != nil && intrinsics.objc_send(NS.BOOL, button, "isPressed")
}

@(private = "file")
gc_value :: proc(o: Obj) -> f32 {
	return o == nil ? 0 : intrinsics.objc_send(f32, o, "value")
}

// The first controller macOS knows of: its buttons, its triggers pulled past
// TRIGGER_PRESS, and its left stick (y down, as raylib has it). ok is false
// when there is none.
system_pad_read :: proc() -> (down: bit_set[Pad], left: Vec2, ok: bool) {
	pool := NS.AutoreleasePool.alloc()->init()
	defer pool->drain()
	class := intrinsics.objc_find_class("GCController")
	controllers := intrinsics.objc_send(Obj, Obj(rawptr(class)), "controllers")
	if controllers == nil || intrinsics.objc_send(NS.UInteger, controllers, "count") == 0 {
		return
	}
	controller := intrinsics.objc_send(Obj, controllers, "objectAtIndex:", NS.UInteger(0))
	pad := gc_get(controller, "extendedGamepad")
	if pad == nil {
		return
	}
	if gc_down(gc_get(pad, "buttonA")) {down += {.A}}
	if gc_down(gc_get(pad, "buttonB")) {down += {.B}}
	if gc_down(gc_get(pad, "buttonX")) {down += {.X}}
	if gc_down(gc_get(pad, "buttonY")) {down += {.Y}}
	if gc_down(gc_get(pad, "leftShoulder")) {down += {.LB}}
	if gc_down(gc_get(pad, "rightShoulder")) {down += {.RB}}
	if gc_value(gc_get(pad, "leftTrigger")) > TRIGGER_PRESS {down += {.LT}}
	if gc_value(gc_get(pad, "rightTrigger")) > TRIGGER_PRESS {down += {.RT}}
	if gc_down(gc_get(pad, "buttonOptions")) {down += {.View}}
	if gc_down(gc_get(pad, "buttonMenu")) {down += {.Start}}
	if gc_down(gc_get(pad, "leftThumbstickButton")) {down += {.L_Stick}}
	if gc_down(gc_get(pad, "rightThumbstickButton")) {down += {.R_Stick}}
	dpad := gc_get(pad, "dpad")
	if gc_down(gc_get(dpad, "up")) {down += {.D_Up}}
	if gc_down(gc_get(dpad, "down")) {down += {.D_Down}}
	if gc_down(gc_get(dpad, "left")) {down += {.D_Left}}
	if gc_down(gc_get(dpad, "right")) {down += {.D_Right}}
	stick := gc_get(pad, "leftThumbstick")
	left = {gc_value(gc_get(stick, "xAxis")), -gc_value(gc_get(stick, "yAxis"))}
	return down, left, true
}
