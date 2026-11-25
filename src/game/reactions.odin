package game

import "core:math"

// How his body reacts for a moment to what he does and eats: wind and
// hiccups (from too much of some foods, see diet.odin), tipsiness, and the
// belly that stays full for a while after a meal. The game sets the timers;
// here they run down, and the pose (prosio_pose.odin) shows them.

Prosio_Reaction :: struct {
	gas, hiccup, tipsy, sway: f32,
}

update_prosio_reactions :: proc(p: ^Prosio, dt: f32) {
	p.gas_pose_t = max(p.gas_pose_t - dt, 0)
	p.hiccup_pose_t = max(p.hiccup_pose_t - dt, 0)
	p.tipsy_pose_t = max(p.tipsy_pose_t - dt, 0)
	p.meal_hold_t = max(0, p.meal_hold_t - dt)
	if p.meal_hold_t == 0 {
		p.meal_target *= math.exp(-dt * PROSIO_MEAL_VISUAL.z)
	}
	if p.eat_t <= PROSIO_MEAL_EAT_TIME * PROSIO_MEAL_SWALLOW {
		p.meal_fill = lerp(p.meal_fill, p.meal_target, 1 - math.exp(-dt * PROSIO_MEAL_EASE))
	}
}

// How strongly each reaction shows now (0 to 1; the sway goes from -1 to 1).
prosio_reaction :: proc(p: ^Prosio, time: f32) -> Prosio_Reaction {
	if p.fail != .None {
		return {}
	}
	gas := clamp(p.gas_pose_t / PROSIO_REACTION_TIME.x, 0, 1)
	hiccup := clamp(p.hiccup_pose_t / PROSIO_REACTION_TIME.y, 0, 1)
	tipsy := clamp(p.tipsy_pose_t / PROSIO_REACTION_TIME.z, 0, 1)
	strength := smooth(min(tipsy * PROSIO_TIPSY_FADE.y, (1 - tipsy) * PROSIO_TIPSY_FADE.x, 1))
	return {gas = math.sin(math.PI * gas) * math.sqrt(gas), hiccup = smooth(hiccup),
		tipsy = strength, sway = strength * math.sin(time * PROSIO_REACTION_SWAY.x)}
}
