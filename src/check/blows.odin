package check

// The blows table: what each blow takes from each kind of animal, for three
// Prosios, now and as it was before (the energy rule as it first stood: pure
// energy, a fall counted by GRAVITY, hard 1, sharp 13.3 and no hide; kept
// here only for that comparison). The same table, for whatever Prosio is set
// there, is in the workbench's Attacks pane (game.test_blow).
//
//   tools/check.sh blows

import game "../game"
import "core:fmt"

// What a blow took under the energy rule as it first stood.
first_harm :: proc(row: game.Test_Blow, kind: game.Enemy_Kind) -> f32 {
	took :: proc(kind: game.Enemy_Kind, joules, factor: f32) -> f32 {
		return game.ENEMY_HEALTH * joules * factor / (game.BLOW_TAKES * game.ENEMY_KG[kind] * game.ENEMY_TOUGH[kind])
	}
	switch row {
	case .Bump, .Throw:
		return game.test_blow(row, kind) // (soft blows: unchanged)
	case .Stomp:
		return took(kind, game.total_kg() * game.GRAVITY * (game.jump_height(game.total_kg()) + game.STOMP_SINK), 1)
	case .Pebble:
		return took(kind, game.kinetic(game.PEBBLE_KG, game.stone_speed(game.PEBBLE_KG)), 1)
	case .Stone:
		return took(kind, game.kinetic(2, game.stone_speed(2)), 1)
	case .Rock:
		most := game.lift_most()
		return took(kind, game.kinetic(most, game.stone_speed(most)), 1)
	case .Spear:
		return took(kind, game.kinetic(game.SPEAR_KG, game.stone_speed(game.SPEAR_KG)), 13.3)
	}
	return 0
}

blows_command :: proc() {
	Pig :: struct {
		name:       string,
		kg:         f32,
		arms, legs: f32,
	}
	pigs := [?]Pig{{"ordinary, 80 kg", 80, 0, 0}, {"lean and strong, 66 kg, the most muscle", 66, 1, 1}, {"heavy, 120 kg, ordinary muscle", 120, 0, 0}}
	fmt.println("Each blow: the share of the animal's health it takes, in per cent, now (and before this change), and how many such blows bring it down.")
	fmt.printfln("Stones and rocks: %.0f%% by momentum; falls counted at %.1f m/s2; hard %.2f, sharp %.2f, soft %.2f.", game.STONE_MOMENTUM_SHARE * 100, game.FALL_GRAVITY, game.BLOW_FACTOR[.Hard], game.BLOW_FACTOR[.Sharp], game.BLOW_FACTOR[.Soft])
	for pig in pigs {
		fresh()
		p := &game.g.prosio
		p.trait[.Arms], p.trait[.Legs] = pig.arms, pig.legs
		game.set_weight(pig.kg)
		most := game.lift_most()
		jump := game.jump_height(game.total_kg())
		fmt.printfln("\n== %s: arm muscle %.1f kg, legs %.1f kg; jumps %.2f m; lifts a rock of up to %.0f kg, thrown at %.1f m/s; a stomp %.0f J, pins for %.1f s",
			pig.name, game.muscle_kg(.Arms), game.muscle_kg(.Legs), jump, most, game.stone_speed(most), game.stomp_energy(jump), game.stomp_pin(jump))
		fmt.printf("%-26s", "")
		for kind in game.Enemy_Kind {
			fmt.printf("  %-24v", kind)
		}
		fmt.println()
		for row in game.Test_Blow {
			name := fmt.tprintf("%v", row)
			#partial switch row {
			case .Bump: name = "bump at a run"
			case .Throw: name = "throw it (wound up)"
			case .Stone: name = "a 2 kg stone"
			case .Rock: name = fmt.tprintf("the heaviest rock (%.0f kg)", most)
			}
			fmt.printf("%-26s", name)
			for kind in game.Enemy_Kind {
				now := game.test_blow(row, kind)
				n := game.blows_needed(now)
				count := n > 0 ? fmt.tprintf("%d", n) : "-"
				fmt.printf("  %5.1f (%5.1f) %4s blows", now, first_harm(row, kind), count)
			}
			fmt.println()
		}
	}
}
