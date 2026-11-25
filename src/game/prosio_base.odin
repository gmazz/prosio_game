package game

@(require) import "core:math/linalg" // (used only when the skin is built in)

// Prosio's skin: one mesh made in Blender (assets/prosio_base/prosio_base.glb,
// packed by tools/pack_assets), bent on the 36 parts of his pose
// (prosio_pose.odin), with his eyes and mouth drawn on it. Its placement and
// shape numbers are in data/tuning/prosio_look.json.
//
// Drawn on the Bare pig in place of the body of shapes. Off in the game (its
// art is not ready to show); on in the workbench with its "skin on" command
// (tools/workbench.sh --skin), or in a build with -define:PROSIO_BASE=true.
// PROSIO_BASE_DATA builds its data in without showing it: tools/check.sh sets
// it, so the skin's rules run against the game as it is played.
PROSIO_BASE :: #config(PROSIO_BASE, false)
PROSIO_BASE_DATA :: PROSIO_BASE || #config(PROSIO_BASE_DATA, false)

prosio_base_visible :: proc() -> bool {
	return PROSIO_BASE && outfit == PRESETS[.Bare]
}

// How much higher the skin's head sits than the head of shapes (for what is
// drawn above it).
prosio_base_head_lift :: proc() -> f32 {
	return prosio_base_visible() ? PROSIO_BASE_HEAD_LIFT : 0
}

when PROSIO_BASE_DATA {
	Prosio_Base_Vertex :: struct {
		pos, normal: Vec3,
		joints:      [4]u8, // parts, strongest first
		weights:     [4]f32,
	}
	PROSIO_BASE_VERTICES := #load("../../assets/prosio_base/vertices.bin", []Prosio_Base_Vertex)
	PROSIO_BASE_INDICES := #load("../../assets/prosio_base/indices.bin", []u16)
	PROSIO_BASE_REST := #load("../../assets/prosio_base/rest.bin", []Mat4)
	PROSIO_BASE_PAINT := #load("../../assets/prosio_base/paint.bin", []Color)
	PROSIO_BASE_FACE_DELTA := #load("../../assets/prosio_base/face_fat.bin", [][6]f32)
	PROSIO_BASE_VERTEX_CAPACITY :: 1 << (size_of(u16) * 8)
	prosio_base_positions: [PROSIO_BASE_VERTEX_CAPACITY]Vec3
	prosio_base_normals: [PROSIO_BASE_VERTEX_CAPACITY]Vec3

	// Bends the skin on the pose, into prosio_base_positions and _normals.
	prosio_base_skin :: proc(pose: ^Prosio_Pose) {
		frames, normals: [Prosio_Part]Mat4
		for part in Prosio_Part {
			frame := pose.pieces[part].frame * PROSIO_BASE_REST[int(part)]
			frames[part] = frame
			normals[part] = linalg.transpose(linalg.inverse(frame))
		}
		for v, i in PROSIO_BASE_VERTICES {
			face := PROSIO_BASE_FACE_DELTA[i]
			pos := v.pos + face.xyz * pose.face_fat
			normal := v.normal + Vec3{face[3], face[4], face[5]} * pose.face_fat
			p, n: Vec3
			for weight, k in v.weights {
				if weight <= 0 { break }
				j := Prosio_Part(v.joints[k])
				p += weight * (frames[j] * [4]f32{pos.x, pos.y, pos.z, 1}).xyz
				n += weight * (normals[j] * [4]f32{normal.x, normal.y, normal.z, 0}).xyz
			}
			prosio_base_positions[i] = p
			prosio_base_normals[i] = linalg.normalize0(n)
		}
	}
}

when PROSIO_BASE {
	// The skin as the pose has it: what he picked up, in his hoof; his eyes
	// and mouth; the skin itself.
	draw_prosio_skin :: proc(pose: ^Prosio_Pose) {
		// (The belly button of the body of shapes, as before the skin had one.)
		covered := SHIRT_LOOK[outfit.shirt].long || closed_coat() || outfit.over == .Apron
		if pose.t > 0.25 && !covered {
			ball(pose.torso, {0, pose.belly_mid - 0.08, pose.belly_out + pose.belly_w}, {0.045, 0.045, 0.03}, pose.skin_dark)
		}
		if pose.item_shown {
			ball(pose.root, pose.arms[pose.item_side].hand + {0, 0.1, 0.04}, {0.11, 0.11, 0.11}, pose.item_color)
		}
		for d in pose.details[:pose.detail_count] {
			draw_shape(d.piece.shape, d.piece.frame, d.piece.color)
		}
		prosio_base_skin(pose)
		draw_prosio_base_mesh(pose.skin)
	}
}
