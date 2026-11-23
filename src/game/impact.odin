package game

import "core:math"
import "core:math/linalg"

IMPACT_UP :: quaternion128(1)

Impact_Kind :: enum {None, Push, Stumble, Fall, Launch}
Impact_Phase :: enum {Brace, Air, Tumble, Settle, Down, Rise}

Enemy_Impact :: struct {
	kind: Impact_Kind,
	phase: Impact_Phase,
	age, duration: f32,
	rotation, from, side: quaternion128,
	axis: Vec3, // in the animal's frame before the impact
	spin: f32,
	bend, bend_from: f32,
}

impact_kind :: proc(speed: f32) -> Impact_Kind {
	if speed >= IMPACT_LAUNCH_SPEED {
		return .Launch
	}
	if speed >= IMPACT_FALL_SPEED {
		return .Fall
	}
	if speed >= IMPACT_STUMBLE_SPEED {
		return .Stumble
	}
	return .Push
}

impact_turn :: proc(axis: Vec3, angle: f32) -> quaternion128 {
	v := axis * math.sin(angle * 0.5)
	return quaternion(w=math.cos(angle * 0.5), x=v.x, y=v.y, z=v.z)
}

enemy_impact :: proc(e: ^Enemy, dir: Vec2, speed: f32, hurts := true) -> Impact_Kind {
	kind := impact_kind(speed)
	if hurts && kind == .Launch {
		hurt_enemy(e, blow_damage(e.kind, speed))
	}
	if e.ko && kind < .Fall {
		kind = .Fall
	}
	// Another light blow can slide an animal while it is getting up.
	if e.impact.kind >= .Fall && kind < .Fall {
		e.vel += dir * speed
		return kind
	}
	begin_enemy_impact(e, dir, speed, kind)
	return kind
}

begin_enemy_impact :: proc(e: ^Enemy, direction: Vec2, speed: f32, kind: Impact_Kind) {
	drop_loot(e)
	old := e.impact
	ahead := facing_dir(e.facing)
	dir := direction == {} ? ahead : direction
	local := Vec2{dot2(dir, {ahead.y, -ahead.x}), dot2(dir, ahead)}
	side := local.x < 0 ? f32(-1) : f32(1)
	// A side hit rolls the animal. An end-on hit pitches it over.
	axis := linalg.normalize(Vec3{local.y, 0, -local.x})
	e.impact = {
		kind = kind, axis = axis, rotation = IMPACT_UP,
		side = impact_turn({0, 0, 1}, -side * IMPACT_SIDE_ANGLE),
	}
	i := &e.impact
	if old.kind != .None {
		i.rotation, i.bend = old.rotation, old.bend
	}
	i.from, i.bend_from = i.rotation, i.bend
	e.skip = false
	e.timer = 0
	e.vel = dir * max(speed, IMPACT_MIN_PUSH)
	e.state = .Dizzy
	e.vy = 0
	switch kind {
	case .None:
	case .Push, .Stumble:
		i.phase = .Brace
		i.duration = IMPACT_BRACE_TIME[kind]
	case .Fall:
		i.phase = .Tumble
		i.duration = IMPACT_FALL_TIP_TIME
		i.axis = linalg.normalize(axis + Vec3{0, 0, -side * IMPACT_SIDE_BIAS})
		i.spin = min(speed * IMPACT_SPIN_PER_SPEED, IMPACT_MAX_SPIN)
	case .Launch:
		e.state = .Flying
		e.vel = dir * speed
		e.vy = min(speed * IMPACT_RISE_SHARE, IMPACT_MAX_RISE)
		i.phase = .Air
		i.spin = min(speed * IMPACT_SPIN_PER_SPEED, IMPACT_MAX_SPIN)
	}
}

spin_enemy_impact :: proc(i: ^Enemy_Impact, dt: f32) {
	i.rotation = linalg.normalize(impact_turn(i.axis, i.spin * dt) * i.rotation)
	i.bend = min(i.bend + dt / IMPACT_BEND_TIME, 1)
}

land_enemy_impact :: proc(e: ^Enemy) {
	i := &e.impact
	e.state = .Dizzy
	e.skip = false
	e.vy = 0
	if i.kind == .None {
		e.timer = 0.6 // gentle placement over a fence
		return
	}
	i.phase, i.age, i.duration = .Tumble, 0, IMPACT_TUMBLE_TIME
}

// True after the animal has come to rest and, if awake, got back to its feet.
step_enemy_impact :: proc(e: ^Enemy, dt: f32) -> bool {
	i := &e.impact
	i.age += dt
	t := clamp(i.age / i.duration, 0, 1)
	if i.phase >= .Tumble {
		drag := IMPACT_TUMBLE_DRAG + IMPACT_SLIDE_DRAG * length2(e.vel)
		e.vel = approach2(e.vel, {}, drag * dt)
	}
	switch i.phase {
	case .Air:
		return false
	case .Brace:
		e.vel = approach2(e.vel, {}, IMPACT_BRACE_DRAG * dt)
		e.hop += length2(e.vel) * dt * math.TAU
		lean := impact_turn(i.axis, IMPACT_BRACE_LEAN[i.kind] * math.sin(math.PI * t))
		i.rotation = linalg.normalize(lean * linalg.quaternion_slerp(i.from, IMPACT_UP, smooth(t)))
		if t == 1 && e.ko {
			i.kind = .Fall
			i.phase, i.age, i.duration = .Settle, 0, IMPACT_SETTLE_TIME
			i.from, i.bend_from = i.rotation, i.bend
			return false
		}
	case .Tumble:
		spin_enemy_impact(i, dt)
		i.spin = max(i.spin - IMPACT_SPIN_DRAG * dt, 0)
		if t == 1 {
			// Settle on whichever flank is now nearest the ground.
			other := quaternion(w=i.side.w, x=-i.side.x, y=-i.side.y, z=-i.side.z)
			if abs(linalg.dot(i.rotation, other)) > abs(linalg.dot(i.rotation, i.side)) {
				i.side = other
			}
			i.phase, i.age, i.duration = .Settle, 0, IMPACT_SETTLE_TIME
			i.from, i.bend_from = i.rotation, i.bend
		}
		return false
	case .Settle:
		// The last of the tumble carries into the settling motion.
		drift := i.spin * i.duration * t * (1 - t) * (1 - t)
		settling := linalg.quaternion_slerp(i.from, i.side, smooth(t))
		i.rotation = linalg.normalize(impact_turn(i.axis, drift) * settling)
		i.bend = lerp(i.bend_from, 1, smooth(t))
		if t == 1 {
			i.phase, i.age, i.duration = .Down, 0, IMPACT_DOWN_TIME
		}
		return false
	case .Down:
		if t < 1 {
			return false
		}
		if !e.ko {
			i.phase, i.age, i.duration = .Rise, 0, IMPACT_GET_UP_TIME
			return false
		}
	case .Rise:
		if e.ko {
			i.phase, i.age, i.duration = .Settle, 0, IMPACT_SETTLE_TIME
			i.from, i.bend_from = i.rotation, i.bend
			return false
		}
		i.rotation = linalg.normalize(linalg.quaternion_slerp(i.side, IMPACT_UP, smooth(t)))
		i.bend = 1 - smooth(t)
	}
	return t == 1
}

// Match the model's support at contact. In flight its centre follows the
// ballistic arc, with a correction near the ground and a floor clamp.
impact_ground_lift :: proc(e: Enemy, low: f32) -> f32 {
	if e.impact.kind < .Fall {
		return max(-low, 0)
	}
	weight := 1 - smooth(clamp(e.y / IMPACT_GROUND_BLEND_HEIGHT, 0, 1))
	return max(-low, (e.y - low) * weight)
}
