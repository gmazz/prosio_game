package check

import game "../game"
import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:os"
import "core:path/filepath"
import "core:strings"

// Prosio's pose and the skin made in Blender that bends on it
// (prosio_pose.odin, prosio_base.odin).

// Prosio as the skin was made: 70 kg, standing still, facing +Z.
setup_prosio_sculpt_bind :: proc() {
	p := &game.g.prosio
	p.pos = {}
	p.facing = 0
	p.fat += game.PROSIO_BASE_PEC_MASS.x - p.kg
	p.kg = game.PROSIO_BASE_PEC_MASS.x
	game.g.time = 1
}

Bind_Piece :: struct {
	name, shape: string,
	frame:       [16]f32,
	color:       game.Color,
}

// assets/prosio_base/bind.json as his pose has it now: each part's frame at
// the bind pose (arms held out), and the eyes and mouth drawn on the skin.
prosio_bind_json :: proc() -> string {
	fresh()
	setup_prosio_sculpt_bind()
	pose := game.prosio_pose(true)
	pieces: [len(game.Prosio_Part)]Bind_Piece
	for part in game.Prosio_Part {
		piece := pose.pieces[part]
		pieces[int(part)] = {fmt.tprintf("%v", part), fmt.tprintf("%v", piece.shape), transmute([16]f32)piece.frame, piece.color}
	}
	details: [game.PROSIO_DETAILS_MAX]Bind_Piece
	for detail, i in pose.details[:pose.detail_count] {
		piece := detail.piece
		details[i] = {detail.name, fmt.tprintf("%v", piece.shape), transmute([16]f32)piece.frame, piece.color}
	}
	snapshot := struct {
		pieces:  []Bind_Piece,
		details: []Bind_Piece,
	}{pieces[:], details[:pose.detail_count]}
	data, err := json.marshal(snapshot, allocator = context.temp_allocator)
	assert(err == nil)
	return fmt.tprintf("%s\n", string(data))
}

export_prosio_base :: proc() {
	fmt.print(prosio_bind_json())
}

// The skin fits his pose only as long as his parts sit where they did when it
// was made: bind.json holds them, and must be what the pose gives now.
rules_prosio_bind :: proc() {
	want := prosio_bind_json()
	have, err := os.read_entire_file("assets/prosio_base/bind.json", context.temp_allocator)
	same := err == nil && string(have) == want
	detail := "byte for byte"
	if !same {
		Bind :: struct {
			pieces: []Bind_Piece,
		}
		a, b: Bind
		ea := json.unmarshal(have, &a, allocator = context.temp_allocator)
		eb := json.unmarshal(transmute([]byte)want, &b, allocator = context.temp_allocator)
		worst: f32
		part := "?"
		if ea == nil && eb == nil && len(a.pieces) == len(b.pieces) {
			for piece, i in a.pieces {
				for x, k in piece.frame {
					if d := abs(x - b.pieces[i].frame[k]); d > worst {
						worst, part = d, piece.name
					}
				}
			}
		}
		detail = fmt.tprintf("it is not (%s differs by %.4f): if his parts were moved on purpose, remake it with build/check/prosio-check export-prosio-base > assets/prosio_base/bind.json and fit the skin to it again in Blender", part, worst)
	}
	check("Prosio's skin fits his pose: assets/prosio_base/bind.json is what his pose gives at the bind pose", same, detail)
}

when game.PROSIO_BASE_DATA {
	rules_prosio_base :: proc() {
		section("Prosio's skin")
		vertices := game.PROSIO_BASE_VERTICES
		indices := game.PROSIO_BASE_INDICES
		valid := len(vertices) > 0 && len(vertices) <= game.PROSIO_BASE_VERTEX_CAPACITY &&
			len(vertices) == len(game.PROSIO_BASE_PAINT) && len(indices) > 0 &&
			len(vertices) == len(game.PROSIO_BASE_FACE_DELTA) &&
			len(indices) % 3 == 0 && len(game.PROSIO_BASE_REST) == len(game.Prosio_Part)
		for index in indices { valid = valid && int(index) < len(vertices) }
		for vertex in vertices {
			total: f32
			for joint, k in vertex.joints {
				w := vertex.weights[k]
				valid = valid && int(joint) < len(game.Prosio_Part) && w >= 0
				total += w
			}
			valid = valid && abs(total - 1) < 0.0002 && linalg.length(vertex.normal) > 0.99
		}
		check("the continuous Prosio skin has valid triangles, normals and part weights", valid)
		if valid { rules_prosio_base_deformation() }
	}

	rules_prosio_base_deformation :: proc() {
		fresh()
		p := &game.g.prosio
		setup_prosio_sculpt_bind()
		pose := game.prosio_pose(true)
		game.prosio_base_skin(&pose)
		bind_error: f32
		for v, i in game.PROSIO_BASE_VERTICES {
			bind_error = max(bind_error, linalg.length(game.prosio_base_positions[i] - v.pos))
		}
		check("the game reproduces the editable Blender skin at its bind pose", bind_error < 0.00002,
			fmt.tprintf("max distance %.7f m", bind_error))

		pose = game.prosio_pose()
		belly := linalg.length(pose.pieces[.Belly].frame[0])
		hand := pose.pieces[.Hand_L].frame
		p.vel = {0, 2}
		p.walk_phase = math.PI / 2
		p.meal_fill = 1
		pose = game.prosio_pose()
		game.prosio_base_skin(&pose)
		finite := true
		for v in game.prosio_base_positions[:len(game.PROSIO_BASE_VERTICES)] {
			for x in v { finite = finite && abs(x) < 10 }
		}
		check("the continuous skin follows the original step and meal growth", finite &&
			pose.pieces[.Hand_L].frame != hand && linalg.length(pose.pieces[.Belly].frame[0]) > belly)
		rules_prosio_sculpt_pose()
		rules_prosio_fixed_limbs()
	}

	rules_prosio_sculpt_pose :: proc() {
		fresh()
		setup_prosio_sculpt_bind()
		p := &game.g.prosio
		rest := game.prosio_pose()

		p.hiccup_pose_t = game.PROSIO_REACTION_TIME.y
		expression := game.prosio_pose()
		p.hiccup_pose_t = 0

		p.airborne, p.height, p.vy = true, 0.44, -2
		airborne := game.prosio_pose()
		p.airborne, p.height, p.vy = false, 0, 0

		p.kg += game.PROSIO_BASE_PEC_MASS.y
		p.fat += game.PROSIO_BASE_PEC_MASS.y
		heavier := game.prosio_pose()

		in_head :: proc(pose: ^game.Prosio_Pose, part: game.Prosio_Part) -> f32 {
			frame := linalg.inverse(pose.pieces[.Head].frame) * pose.pieces[part].frame
			return (frame * [4]f32{0, 0, 0, 1}).y
		}
		brows_lift, ears_lift := true, true
		for side in ([2]f32{-1, 1}) {
			brow := game.prosio_side_part(.Brow_L, side)
			ear := game.prosio_side_part(.Ear_L, side)
			brows_lift = brows_lift && in_head(&expression, brow) - in_head(&rest, brow) > 0.04 &&
				rest.pieces[brow].color == rest.pieces[.Head].color
			ears_lift = ears_lift && in_head(&airborne, ear) - in_head(&rest, ear) > 0.20
		}
		check("both skin-tone brows follow a hiccup expression", brows_lift)
		check("both folded ears lift relative to the head while airborne", ears_lift)
		pec_depth := linalg.length(rest.pieces[.Pec_L].frame[2])
		heavy_depth := linalg.length(heavier.pieces[.Pec_L].frame[2])
		check("the 70 kg chest has more pectoral definition than the heavier chest", pec_depth > heavy_depth)
		check("facial fullness leaves the head and its features in place",
			abs(rest.face_fat) < 0.001 && heavier.face_fat > 0.5 &&
			rest.pieces[.Head].frame == heavier.pieces[.Head].frame &&
			rest.pieces[.Snout].frame == heavier.pieces[.Snout].frame &&
			game.prosio_face_fat(game.PROSIO_BASE_FACE_FAT.x + 1) < 0.002)
		head_inverse := linalg.inverse(rest.pieces[.Head].frame)
		forehead_change, jaw_change: f32
		for delta, i in game.PROSIO_BASE_FACE_DELTA {
			d := linalg.length(delta.xyz)
			pos := game.PROSIO_BASE_VERTICES[i].pos
			in_skull := head_inverse * [4]f32{pos.x, pos.y, pos.z, 1}
			if in_skull.y > 0.1 {
				forehead_change = max(forehead_change, d)
			} else {
				jaw_change = max(jaw_change, d)
			}
		}
		check("the packed facial shape adds volume to the jaw while keeping the forehead stable",
			jaw_change > 0.02 && forehead_change < 0.001)
		eyes, glints := 0, 0
		for item in heavier.details[:heavier.detail_count] {
			if item.name == "Eye.L" || item.name == "Eye.R" {
				if item.piece.color == game.COLOR_BLACK { eyes += 1 }
			}
			if item.name == "Catchlight" || item.name == "SmallCatchlight" { glints += 1 }
		}
		check("both kawaii eyes are black with two catchlights each", eyes == 2 && glints == 4)
	}

	rules_prosio_fixed_limbs :: proc() {
		segments := [?]game.Prosio_Part {
			.Upper_Arm_L, .Upper_Arm_R, .Forearm_L, .Forearm_R,
			.Thigh_L, .Thigh_R, .Shin_L, .Shin_R,
		}
		fresh()
		setup_prosio_sculpt_bind()
		p := &game.g.prosio
		rest := game.prosio_pose()
		pose: game.Prosio_Pose
		neutral := p^
		error: f32
		for kg in ([?]f32{70, 95, 132}) {
			for phase in 0..<16 {
				p^ = neutral
				p.trait[.Arms] = f32(phase % 3) * 0.5
				p.trait[.Legs] = f32(phase % 5) * 0.25
				game.set_weight(kg)
				game.g.time = 1 + f32(phase) * 0.11
				p.walk_phase = f32(phase) * 0.2
				p.stretch = f32(phase % 3 - 1) * 0.29
				p.vel = {0, 2}
				switch phase % 8 {
				case 0: p.tipsy_pose_t = 3
				case 1: p.hiccup_pose_t = game.PROSIO_REACTION_TIME.y
				case 2: p.airborne, p.height, p.vy = true, 0.65, 2
				case 3: p.eat_t, p.meal_fill = 0.25, 1
				case 4: p.dash_t = 0.5
				case 5: p.pick_t, p.pick_total = 0.3, 0.8
				case 6: p.shake_t, p.shake_power = 0.6, 1
				case 7: p.sprinting = true
				}
				pose = game.prosio_pose()
				for part in segments {
					expected := linalg.length(rest.pieces[part].frame[1])
					current := linalg.length(pose.pieces[part].frame[1])
					error = max(error, abs(expected - current))
				}
			}
		}
		check("all four limb segments retain their lengths through actions, mass and training",
			error < 0.00001, fmt.tprintf("maximum difference %.7f m", error))
		p^ = neutral
		p.trait[.Arms], p.trait[.Legs] = 1, 1
		pose = game.prosio_pose()
		check("muscle increases girth without changing palm or hoof length",
			linalg.length(pose.pieces[.Upper_Arm_L].frame[0]) > linalg.length(rest.pieces[.Upper_Arm_L].frame[0]) &&
			linalg.length(pose.pieces[.Thigh_L].frame[0]) > linalg.length(rest.pieces[.Thigh_L].frame[0]) &&
			abs(linalg.length(pose.pieces[.Hand_L].frame[1]) - linalg.length(rest.pieces[.Hand_L].frame[1])) < 0.00001 &&
			abs(linalg.length(pose.pieces[.Toe_Inner_L].frame[1]) - linalg.length(rest.pieces[.Toe_Inner_L].frame[1])) < 0.00001)
		near := game.Vec3{0.15, -0.19, 0.18}
		_, palm := game.prosio_arm({}, {0.2, -0.10, 0}, near, 1)
		_, capped := game.prosio_arm({}, {0.2, -0.10, 0}, near * 4, 1)
		check("the hand hits reachable grip targets and stays within the arm's reach on distant targets",
			linalg.length(palm - near) < 0.00001 &&
			linalg.length(capped) < game.PROSIO_BASE_ARM_LENGTHS.x + game.PROSIO_BASE_ARM_LENGTHS.y)
	}
}

// How Prosio's looks sit in the game: the skin kept out of the game as it is
// played, the pack on every outfit but the bare pig, the pose worked out
// apart from drawing, and the look numbers in a file of their own.
rules_prosio_look :: proc() {
	fresh()
	saved := game.outfit
	game.outfit = game.PRESETS[.Bare]
	check("the skin made in Blender is not shown in the game as played: the bare pig is drawn from shapes (it is on only in the workbench, with its skin command)",
		!game.PROSIO_BASE && !game.prosio_base_visible() && game.prosio_base_head_lift() == 0)
	packs := 0
	bare_pack := false
	for preset in game.Preset {
		game.outfit = game.PRESETS[preset]
		if game.prosio_wears_pack() {
			packs += 1
			if preset == .Bare {bare_pack = true}
		}
	}
	game.outfit = saved
	check("he carries his pack in every outfit but the bare pig", !bare_pack && packs == len(game.Preset) - 1,
		fmt.tprintf("%d of %d outfits", packs, len(game.Preset)))

	fresh()
	p := &game.g.prosio
	p.vel, p.walk_phase, p.hiccup_pose_t, p.eat_t = {0, 2}, 1, 0.2, 0.2
	before := p^
	time := game.g.time
	a := game.prosio_pose()
	b := game.prosio_pose()
	check("working out his pose changes nothing in the game, and gives the same pose each time",
		p^ == before && game.g.time == time && a.pieces == b.pieces && a.face_fat == b.face_fat && a.detail_count == b.detail_count)

	stray: [dynamic]string
	files, _ := filepath.glob("data/tuning/*.json", context.temp_allocator)
	for path in files {
		if filepath.base(path) == "prosio_look.json" {continue}
		text, err := os.read_entire_file(path, context.temp_allocator)
		if err != nil {continue}
		for key in ([]string{"\"PROSIO_BASE_", "\"PROSIO_FACE_", "\"PROSIO_BLINK\""}) {
			if strings.contains(string(text), key) {
				append(&stray, fmt.tprintf("%s in %s", key, filepath.base(path)))
			}
		}
	}
	check("his look (the parts' placement and sizes, his face, the skin) is tuned in data/tuning/prosio_look.json and nowhere else",
		len(stray) == 0, len(stray) > 0 ? stray[0] : "")
}
