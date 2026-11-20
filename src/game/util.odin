package game

import "core:math"
import "core:math/linalg"

IDENTITY :: linalg.MATRIX4F32_IDENTITY

translate :: proc(v: Vec3) -> Mat4 {
	return linalg.matrix4_translate_f32(v)
}

scale :: proc(v: Vec3) -> Mat4 {
	return linalg.matrix4_scale_f32(v)
}

rot_x :: proc(angle: f32) -> Mat4 {
	return linalg.matrix4_rotate_f32(angle, {1, 0, 0})
}

rot_y :: proc(angle: f32) -> Mat4 {
	return linalg.matrix4_rotate_f32(angle, {0, 1, 0})
}

rot_z :: proc(angle: f32) -> Mat4 {
	return linalg.matrix4_rotate_f32(angle, {0, 0, 1})
}

length2 :: proc(v: Vec2) -> f32 {
	return math.sqrt(v.x * v.x + v.y * v.y)
}

normalize2 :: proc(v: Vec2) -> Vec2 {
	l := length2(v)
	if l < 1e-5 {
		return {}
	}
	return v / l
}

dot2 :: proc(a, b: Vec2) -> f32 {
	return a.x * b.x + a.y * b.y
}

lerp :: proc(a, b, t: f32) -> f32 {
	return a + (b - a) * t
}

smooth :: proc(t: f32) -> f32 {
	x := clamp(t, 0, 1)
	return x * x * (3 - 2 * x)
}

// Moves v towards target by at most max_step.
approach2 :: proc(v, target: Vec2, max_step: f32) -> Vec2 {
	d := target - v
	l := length2(d)
	if l <= max_step {
		return target
	}
	return v + d / l * max_step
}

// Turns an angle towards target by at most max_step, the short way round.
approach_angle :: proc(angle, target, max_step: f32) -> f32 {
	d := math.mod(target - angle + math.PI, math.TAU)
	if d < 0 {
		d += math.TAU
	}
	d -= math.PI
	return angle + clamp(d, -max_step, max_step)
}

// Direction on the ground for a facing angle; angle 0 looks towards the camera.
facing_dir :: proc(angle: f32) -> Vec2 {
	return {math.sin(angle), math.cos(angle)}
}

// Small deterministic random generator, so the game needs no system calls.
random :: proc() -> f32 {
	g.rng ~= g.rng << 13
	g.rng ~= g.rng >> 17
	g.rng ~= g.rng << 5
	return f32(g.rng & 0xffffff) / f32(0x1000000)
}

random_range :: proc(lo, hi: f32) -> f32 {
	return lo + (hi - lo) * random()
}

// Pushes a circle out of a box. Returns the push direction if they touched.
push_out_box :: proc(pos: ^Vec2, r: f32, lo, hi: Vec2) -> (hit: bool, normal: Vec2) {
	closest := Vec2{clamp(pos.x, lo.x, hi.x), clamp(pos.y, lo.y, hi.y)}
	d := pos^ - closest
	dist := length2(d)
	if dist >= r {
		return false, {}
	}
	if dist > 1e-5 {
		normal = d / dist
		pos^ += normal * (r - dist)
		return true, normal
	}
	// The centre is inside the box: leave through the nearest side.
	left := pos.x - lo.x
	right := hi.x - pos.x
	top := pos.y - lo.y
	bottom := hi.y - pos.y
	m := min(left, right, top, bottom)
	if m == left {
		normal = {-1, 0}
		pos.x = lo.x - r
	} else if m == right {
		normal = {1, 0}
		pos.x = hi.x + r
	} else if m == top {
		normal = {0, -1}
		pos.y = lo.y - r
	} else {
		normal = {0, 1}
		pos.y = hi.y + r
	}
	return true, normal
}

// Pushes a circle out of another fixed circle.
push_out_circle :: proc(pos: ^Vec2, r: f32, centre: Vec2, centre_r: f32) -> (hit: bool, normal: Vec2) {
	d := pos^ - centre
	dist := length2(d)
	if dist >= r + centre_r {
		return false, {}
	}
	normal = dist > 1e-5 ? d / dist : Vec2{0, 1}
	pos^ = centre + normal * (r + centre_r)
	return true, normal
}
