package check

import game "../game"
import "core:math"

// His reactions (reactions.odin): the belly after a meal, hiccups, wind,
// tipsiness.
rules_prosio_reactions :: proc() {
	fresh()
	p := &game.g.prosio
	game.sack_add(.Pumpkin, game.item_kcal(.Pumpkin))
	p.sack_sel = .Pumpkin
	game.eat_from_sack()
	big := p.meal_target
	game.update_prosio_reactions(p, 0.05)
	waited := p.meal_fill == 0
	p.eat_t = 0
	game.update_prosio_reactions(p, 0.5)
	filled := p.meal_fill
	game.update_prosio_reactions(p, 8)
	settled := p.meal_fill
	fresh()
	game.sack_add(.Apple, game.item_kcal(.Apple))
	p.sack_sel = .Apple
	game.eat_from_sack()
	check("swallowing fills the belly for a while, with more room for a large meal",
		waited && filled > p.meal_target && filled > 0.1 && big > p.meal_target && settled < filled * 0.1)

	fresh()
	p.need[.Carbs] = 100
	step(1)
	hiccup := p.airborne && p.hiccup_pose_t > 0 && game.prosio_reaction(p, 0).hiccup > 0.9
	fresh()
	p.need[.Fibre] = 100
	step(1)
	game.update_prosio_reactions(p, game.PROSIO_REACTION_TIME.x * 0.4)
	gas := p.gas_pose_t > 0 && game.prosio_reaction(p, 0).gas > 0.5
	game.update_prosio_reactions(p, 1)
	check("real hiccups launch a startle, and real wind starts a recoil that settles",
		hiccup && gas && game.prosio_reaction(p, 0).gas == 0)

	p.tipsy_pose_t = game.PROSIO_REACTION_TIME.z * 0.5
	a := game.prosio_reaction(p, math.PI / (2 * game.PROSIO_REACTION_SWAY.x))
	b := game.prosio_reaction(p, 3 * math.PI / (2 * game.PROSIO_REACTION_SWAY.x))
	game.update_prosio_reactions(p, game.PROSIO_REACTION_TIME.z)
	check("the tipsy presentation sways both ways and fades back to idle",
		a.sway > 0.9 && b.sway < -0.9 && a.tipsy > 0.9 && game.prosio_reaction(p, 0).tipsy == 0)
}
