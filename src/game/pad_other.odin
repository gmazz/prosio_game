#+build !darwin
package game

// Elsewhere than on a Mac the controller is read through raylib (see
// pad_darwin.odin for why the Mac is different).
system_pad_read :: proc() -> (down: bit_set[Pad], left: Vec2, ok: bool) {
	return
}
