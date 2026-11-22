package game

// Made by tools/pack_quadrupeds.sh from the animated animal pack: do not edit.

Quad_Kind :: enum {Goat, Billy, Packfox}
QUAD_MAX_BONES :: 51
QUAD_MAX_VERTS :: 7140
QUAD_MAX_GROUPS :: 9

when PACK_FOX {
	QUAD_PACKFOX_MESH := #load("../../assets/packfox/mesh.bin", []Quad_Vertex)
	QUAD_PACKFOX_REST := #load("../../assets/packfox/rest.bin", [][16]f32)
	QUAD_PACKFOX_FRAMES := #load("../../assets/packfox/frames.bin", [][12]f32)
} else {
	QUAD_PACKFOX_MESH: []Quad_Vertex
	QUAD_PACKFOX_REST: [][16]f32
	QUAD_PACKFOX_FRAMES: [][12]f32
}

QUAD_MODELS := [Quad_Kind]Quad_Model {
	.Goat = {
		name = "goat", // from Deer.blend
		bones = []string{"Body", "Back", "Torso", "Torso2", "Torso3", "Neck1", "Neck2", "Neck3", "Head", "Ear1.L", "Ear2.L", "Ear3.L", "Ear4.L", "Ear1.R", "Ear2.R", "Ear3.R", "Ear4.R", "FrontShoulder.L", "FrontUpperLeg.L", "FrontLowerLeg.L", "FrontShoulder.R", "FrontUpperLeg.R", "FrontLowerLeg.R", "BackShoulder.L", "BackLeg.L", "BackUpperLeg.L", "BackLowerLeg.L", "BackShoulder.R", "BackLeg.R", "BackUpperLeg.R", "BackLowerLeg.R", "Tail1", "Tail2", "Tail3", "PoleTargetBack.L", "PoleTarget.L", "PoleTargetBack.R", "PoleTarget.R", "IKBackLeg.L", "FFB.L", "IKFrontLeg.L", "FF.L", "IKBackLeg.R", "FFB.R", "IKFrontLeg.R", "FF.R"},
		parents = []int{-1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 8, 13, 14, 15, 3, 17, 18, 3, 20, 21, 1, 23, 24, 25, 1, 27, 28, 29, 1, 31, 32, 0, 0, 0, 0, -1, 38, -1, 40, -1, 42, -1, 44},
		front = []bool{false, false, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, false, false, false, false, false, false, false, false, false, false, false, true, false, true, false, false, true, true, false, false, true, true},
		groups = []Quad_Group{{"Beard", 0, 138}, {"Eye_Black", 138, 132}, {"Eye_Lighter", 270, 240}, {"Eye_White", 510, 12}, {"Hooves", 522, 534}, {"Horn", 1056, 348}, {"Main", 1404, 3930}, {"Main_Dark", 5334, 228}, {"Main_Light", 5562, 1218}},
		clips = []Quad_Clip{{"Idle", 0, 67, 20, true, 0}, {"Walk", 67, 23, 20, true, 2.1099}, {"Gallop", 90, 11, 20, true, 3.4926}, {"Eating", 101, 120, 20, true, 0}, {"Idle_HitReact_Left", 221, 10, 20, false, 0}, {"Death", 231, 18, 20, false, 0}, {"Attack_Headbutt", 249, 17, 20, false, 0}, {"Gallop_Jump", 266, 29, 20, false, 0}},
		sockets = []Quad_Socket{{"eye_L", {0.1725, 1.7335, 0.8761}, {0.9445, 0.0086, 0.1755}, 8}, {"eye_R", {-0.2589, 1.6966, 0.8392}, {-0.948, -0.154, 0.0131}, 8}, {"hip_L", {0.2286, 1.0896, -0.7353}, {0, 0, 1}, 24}, {"hip_R", {-0.2286, 1.0896, -0.7353}, {0, 0, 1}, 28}, {"hoof_L", {0.2286, 0.1758, -0.8731}, {0, 0, 1}, 39}, {"hoof_R", {-0.2286, 0.1758, -0.8731}, {0, 0, 1}, 43}, {"mouth", {0, 1.4195, 1.4533}, {0, 0, 1}, 8}, {"tail_root", {-0, 1.1181, -0.8772}, {0, 0, 1}, 31}, {"tail_tip", {0.0133, 1.0579, -1.0806}, {0, 0, 1}, 33}, {"udder", {0, 0.638, -0.5853}, {0, 0, 1}, 2}},
		mesh = #load("../../assets/goat/mesh.bin", []Quad_Vertex),
		rest = #load("../../assets/goat/rest.bin", [][16]f32),
		frames = #load("../../assets/goat/frames.bin", [][12]f32),
	},
	.Billy = {
		name = "billy", // from Deer.blend
		bones = []string{"Body", "Back", "Torso", "Torso2", "Torso3", "Neck1", "Neck2", "Neck3", "Head", "Ear1.L", "Ear2.L", "Ear3.L", "Ear4.L", "Ear1.R", "Ear2.R", "Ear3.R", "Ear4.R", "FrontShoulder.L", "FrontUpperLeg.L", "FrontLowerLeg.L", "FrontShoulder.R", "FrontUpperLeg.R", "FrontLowerLeg.R", "BackShoulder.L", "BackLeg.L", "BackUpperLeg.L", "BackLowerLeg.L", "BackShoulder.R", "BackLeg.R", "BackUpperLeg.R", "BackLowerLeg.R", "Tail1", "Tail2", "Tail3", "PoleTargetBack.L", "PoleTarget.L", "PoleTargetBack.R", "PoleTarget.R", "IKBackLeg.L", "FFB.L", "IKFrontLeg.L", "FF.L", "IKBackLeg.R", "FFB.R", "IKFrontLeg.R", "FF.R"},
		parents = []int{-1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 8, 13, 14, 15, 3, 17, 18, 3, 20, 21, 1, 23, 24, 25, 1, 27, 28, 29, 1, 31, 32, 0, 0, 0, 0, -1, 38, -1, 40, -1, 42, -1, 44},
		front = []bool{false, false, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, false, false, false, false, false, false, false, false, false, false, false, true, false, true, false, false, true, true, false, false, true, true},
		groups = []Quad_Group{{"Beard", 0, 138}, {"Eye_Black", 138, 132}, {"Eye_Lighter", 270, 240}, {"Eye_White", 510, 12}, {"Hooves", 522, 534}, {"Horn", 1056, 708}, {"Main", 1764, 3930}, {"Main_Dark", 5694, 228}, {"Main_Light", 5922, 1218}},
		clips = []Quad_Clip{{"Idle", 0, 67, 20, true, 0}, {"Walk", 67, 23, 20, true, 2.1604}, {"Gallop", 90, 11, 20, true, 3.5379}, {"Eating", 101, 120, 20, true, 0}, {"Idle_HitReact_Left", 221, 10, 20, false, 0}, {"Death", 231, 18, 20, false, 0}, {"Attack_Headbutt", 249, 17, 20, false, 0}, {"Gallop_Jump", 266, 29, 20, false, 0}},
		sockets = []Quad_Socket{{"eye_L", {0.1645, 1.8294, 0.906}, {0.9432, 0.0085, 0.1865}, 8}, {"eye_R", {-0.2505, 1.7939, 0.8706}, {-0.9486, -0.1541, 0.0241}, 8}, {"hip_L", {0.2471, 1.1777, -0.7283}, {0, 0, 1}, 24}, {"hip_R", {-0.2471, 1.1777, -0.7283}, {0, 0, 1}, 28}, {"hoof_L", {0.2471, 0.1972, -0.8822}, {0, 0, 1}, 39}, {"hoof_R", {-0.2471, 0.1972, -0.8822}, {0, 0, 1}, 43}, {"mouth", {0, 1.5063, 1.4482}, {0, 0, 1}, 8}, {"tail_root", {-0, 1.2074, -0.8728}, {0, 0, 1}, 31}, {"tail_tip", {0.0135, 1.1461, -1.0802}, {0, 0, 1}, 33}, {"udder", {0, 0.6731, -0.5783}, {0, 0, 1}, 2}},
		mesh = #load("../../assets/billy/mesh.bin", []Quad_Vertex),
		rest = #load("../../assets/billy/rest.bin", [][16]f32),
		frames = #load("../../assets/billy/frames.bin", [][12]f32),
	},
	.Packfox = {
		name = "packfox", // from Fox.blend
		bones = []string{"Body", "Back", "Torso", "Torso2", "Torso3", "Neck1", "Neck2", "Neck3", "Head", "Ear1.L", "Ear2.L", "Ear3.L", "Ear4.L", "Ear1.R", "Ear2.R", "Ear3.R", "Ear4.R", "FrontShoulder.L", "FrontUpperLeg.L", "FrontLowerLeg.L", "FrontShoulder.R", "FrontUpperLeg.R", "FrontLowerLeg.R", "BackShoulder.L", "BackLeg.L", "BackUpperLeg.L", "BackLowerLeg.L", "BackShoulder.R", "BackLeg.R", "BackUpperLeg.R", "BackLowerLeg.R", "Tail1", "Tail2", "Tail3", "Tail4", "Tail5", "Tail6", "Tail7", "Tail8", "PoleTargetBack.L", "PoleTarget.L", "PoleTargetBack.R", "PoleTarget.R", "IKBackLeg.L", "FFB.L", "IKFrontLeg.L", "FF.L", "IKBackLeg.R", "FFB.R", "IKFrontLeg.R", "FF.R"},
		parents = []int{-1, 0, 1, 2, 3, 4, 5, 6, 7, 7, 9, 10, 11, 7, 13, 14, 15, 3, 17, 18, 3, 20, 21, 1, 23, 24, 25, 1, 27, 28, 29, 1, 31, 32, 33, 34, 35, 36, 37, 0, 0, 0, 0, -1, 43, -1, 45, -1, 47, -1, 49},
		front = []bool{false, false, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, true, false, false, true, true, false, false, true, true},
		groups = []Quad_Group{{"Black", 0, 42}, {"Eyes", 42, 24}, {"Grey", 66, 1704}, {"Main", 1770, 2634}, {"Main_Light", 4404, 1140}},
		clips = []Quad_Clip{{"Idle", 0, 67, 20, true, 0}, {"Walk", 67, 21, 20, true, 1.2301}, {"Gallop", 88, 11, 20, true, 3.8472}, {"Eating", 99, 51, 20, true, 0}, {"Idle_HitReact_Left", 150, 14, 20, false, 0}, {"Death", 164, 22, 20, false, 0}, {"Attack", 186, 28, 20, false, 0}, {"Gallop_Jump", 214, 20, 20, false, 0}},
		sockets = []Quad_Socket{{"eye_L", {0.2413, 1.0576, 1.3407}, {0.889, 0.1345, 0.411}, 8}, {"eye_R", {-0.1585, 1.0384, 1.3689}, {-0.8321, 0.0535, 0.5316}, 8}, {"hip_L", {0.2237, 0.7846, -0.1493}, {0, 0, 1}, 24}, {"hip_R", {-0.2237, 0.7846, -0.1493}, {0, 0, 1}, 28}, {"hoof_L", {0.2237, 0.1078, -0.148}, {0, 0, 1}, 44}, {"hoof_R", {-0.2237, 0.1078, -0.148}, {0, 0, 1}, 48}, {"mouth", {0, 0.8629, 1.7656}, {0, 0, 1}, 8}, {"tail_root", {-0, 0.9088, -0.2981}, {0, 0, 1}, 31}, {"tail_tip", {-0, 0.4916, -1.3637}, {0, 0, 1}, 38}, {"udder", {0, 0.5635, 0.0007}, {0, 0, 1}, 2}},
		mesh = QUAD_PACKFOX_MESH,
		rest = QUAD_PACKFOX_REST,
		frames = QUAD_PACKFOX_FRAMES,
	},
}
