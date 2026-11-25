package game

// Made by tools/pack_assets from assets/<name>/<name>.glb: do not edit.

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
		name = "goat", // from goat.glb
		bones = []string{"Body", "Back", "BackShoulder.L", "BackLeg.L", "BackUpperLeg.L", "BackLowerLeg.L", "BackShoulder.R", "BackLeg.R", "BackUpperLeg.R", "BackLowerLeg.R", "Tail1", "Tail2", "Tail3", "Torso", "Torso2", "FrontShoulder.L", "FrontUpperLeg.L", "FrontLowerLeg.L", "FrontShoulder.R", "FrontUpperLeg.R", "FrontLowerLeg.R", "Torso3", "Neck1", "Neck2", "Neck3", "Head", "Ear1.L", "Ear2.L", "Ear3.L", "Ear4.L", "Ear1.R", "Ear2.R", "Ear3.R", "Ear4.R", "PoleTarget.L", "PoleTarget.R", "PoleTargetBack.L", "PoleTargetBack.R", "IKBackLeg.L", "FFB.L", "IKBackLeg.R", "FFB.R", "IKFrontLeg.L", "FF.L", "IKFrontLeg.R", "FF.R"},
		parents = []int{-1, 0, 1, 2, 3, 4, 1, 6, 7, 8, 1, 10, 11, 1, 13, 14, 15, 16, 14, 18, 19, 14, 21, 22, 23, 24, 25, 26, 27, 28, 25, 30, 31, 32, 0, 0, 0, 0, -1, 38, -1, 40, -1, 42, -1, 44},
		front = []bool{false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, false, false, false, false, false, true, true, true, true},
		groups = []Quad_Group{{"Beard", 0, 138}, {"Eye_Black", 138, 132}, {"Eye_Lighter", 270, 240}, {"Eye_White", 510, 12}, {"Hooves", 522, 534}, {"Horn", 1056, 348}, {"Main", 1404, 3930}, {"Main_Dark", 5334, 228}, {"Main_Light", 5562, 1218}},
		clips = []Quad_Clip{{"Idle", 0, 67, 20, true, 0}, {"Walk", 67, 23, 20, true, 2.1095}, {"Gallop", 90, 11, 20, true, 3.4925}, {"Eating", 101, 120, 20, true, 0}, {"Idle_HitReact_Left", 221, 10, 20, false, 0}, {"Death", 231, 18, 20, false, 0}, {"Attack_Headbutt", 249, 17, 20, false, 0}, {"Gallop_Jump", 266, 29, 20, false, 0}},
		sockets = []Quad_Socket{{"eye_L", {0.1725, 1.7335, 0.8761}, {0.9831, 0.0089, 0.1827}, 25}, {"eye_R", {-0.2589, 1.6966, 0.8392}, {-0.987, -0.1603, 0.0136}, 25}, {"hip_L", {0.2286, 1.0896, -0.7353}, {0, 0, 1}, 3}, {"hip_R", {-0.2286, 1.0896, -0.7353}, {0, 0, 1}, 7}, {"hoof_L", {0.2286, 0.1758, -0.8731}, {0, 0, 1}, 39}, {"hoof_R", {-0.2286, 0.1758, -0.8731}, {0, 0, 1}, 41}, {"mouth", {0, 1.4195, 1.4533}, {0, 0, 1}, 25}, {"tail_root", {0, 1.1181, -0.8772}, {0, 0, 1}, 10}, {"tail_tip", {0.0133, 1.0579, -1.0806}, {0, 0, 1}, 12}, {"udder", {0, 0.638, -0.5853}, {0, 0, 1}, 13}},
		mesh = #load("../../assets/goat/mesh.bin", []Quad_Vertex),
		rest = #load("../../assets/goat/rest.bin", [][16]f32),
		frames = #load("../../assets/goat/frames.bin", [][12]f32),
	},
	.Billy = {
		name = "billy", // from billy.glb
		bones = []string{"Body", "Back", "BackShoulder.L", "BackLeg.L", "BackUpperLeg.L", "BackLowerLeg.L", "BackShoulder.R", "BackLeg.R", "BackUpperLeg.R", "BackLowerLeg.R", "Tail1", "Tail2", "Tail3", "Torso", "Torso2", "FrontShoulder.L", "FrontUpperLeg.L", "FrontLowerLeg.L", "FrontShoulder.R", "FrontUpperLeg.R", "FrontLowerLeg.R", "Torso3", "Neck1", "Neck2", "Neck3", "Head", "Ear1.L", "Ear2.L", "Ear3.L", "Ear4.L", "Ear1.R", "Ear2.R", "Ear3.R", "Ear4.R", "PoleTarget.L", "PoleTarget.R", "PoleTargetBack.L", "PoleTargetBack.R", "IKBackLeg.L", "FFB.L", "IKBackLeg.R", "FFB.R", "IKFrontLeg.L", "FF.L", "IKFrontLeg.R", "FF.R"},
		parents = []int{-1, 0, 1, 2, 3, 4, 1, 6, 7, 8, 1, 10, 11, 1, 13, 14, 15, 16, 14, 18, 19, 14, 21, 22, 23, 24, 25, 26, 27, 28, 25, 30, 31, 32, 0, 0, 0, 0, -1, 38, -1, 40, -1, 42, -1, 44},
		front = []bool{false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, false, false, false, false, false, true, true, true, true},
		groups = []Quad_Group{{"Beard", 0, 138}, {"Eye_Black", 138, 132}, {"Eye_Lighter", 270, 240}, {"Eye_White", 510, 12}, {"Hooves", 522, 534}, {"Horn", 1056, 708}, {"Main", 1764, 3930}, {"Main_Dark", 5694, 228}, {"Main_Light", 5922, 1218}},
		clips = []Quad_Clip{{"Idle", 0, 67, 20, true, 0}, {"Walk", 67, 23, 20, true, 2.16}, {"Gallop", 90, 11, 20, true, 3.5379}, {"Eating", 101, 120, 20, true, 0}, {"Idle_HitReact_Left", 221, 10, 20, false, 0}, {"Death", 231, 18, 20, false, 0}, {"Attack_Headbutt", 249, 17, 20, false, 0}, {"Gallop_Jump", 266, 29, 20, false, 0}},
		sockets = []Quad_Socket{{"eye_L", {0.1645, 1.8294, 0.906}, {0.981, 0.0088, 0.194}, 25}, {"eye_R", {-0.2505, 1.7939, 0.8706}, {-0.9868, -0.1603, 0.0251}, 25}, {"hip_L", {0.2471, 1.1777, -0.7283}, {0, 0, 1}, 3}, {"hip_R", {-0.2471, 1.1777, -0.7283}, {0, 0, 1}, 7}, {"hoof_L", {0.2471, 0.1972, -0.8822}, {0, 0, 1}, 39}, {"hoof_R", {-0.2471, 0.1972, -0.8822}, {0, 0, 1}, 41}, {"mouth", {0, 1.5063, 1.4482}, {0, 0, 1}, 25}, {"tail_root", {0, 1.2074, -0.8728}, {0, 0, 1}, 10}, {"tail_tip", {0.0135, 1.1461, -1.0802}, {0, 0, 1}, 12}, {"udder", {0, 0.6731, -0.5783}, {0, 0, 1}, 13}},
		mesh = #load("../../assets/billy/mesh.bin", []Quad_Vertex),
		rest = #load("../../assets/billy/rest.bin", [][16]f32),
		frames = #load("../../assets/billy/frames.bin", [][12]f32),
	},
	.Packfox = {
		name = "packfox", // from packfox.glb
		bones = []string{"Body", "Back", "BackShoulder.L", "BackLeg.L", "BackUpperLeg.L", "BackLowerLeg.L", "BackShoulder.R", "BackLeg.R", "BackUpperLeg.R", "BackLowerLeg.R", "Tail1", "Tail2", "Tail3", "Tail4", "Tail5", "Tail6", "Tail7", "Tail8", "Torso", "Torso2", "FrontShoulder.L", "FrontUpperLeg.L", "FrontLowerLeg.L", "FrontShoulder.R", "FrontUpperLeg.R", "FrontLowerLeg.R", "Torso3", "Neck1", "Neck2", "Neck3", "Ear1.L", "Ear2.L", "Ear3.L", "Ear4.L", "Ear1.R", "Ear2.R", "Ear3.R", "Ear4.R", "Head", "PoleTarget.L", "PoleTarget.R", "PoleTargetBack.L", "PoleTargetBack.R", "IKBackLeg.L", "FFB.L", "IKBackLeg.R", "FFB.R", "IKFrontLeg.L", "FF.L", "IKFrontLeg.R", "FF.R"},
		parents = []int{-1, 0, 1, 2, 3, 4, 1, 6, 7, 8, 1, 10, 11, 12, 13, 14, 15, 16, 1, 18, 19, 20, 21, 19, 23, 24, 19, 26, 27, 28, 29, 30, 31, 32, 29, 34, 35, 36, 29, 0, 0, 0, 0, -1, 43, -1, 45, -1, 47, -1, 49},
		front = []bool{false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, false, false, false, false, false, true, true, true, true},
		groups = []Quad_Group{{"Black", 0, 42}, {"Eyes", 42, 24}, {"Grey", 66, 1704}, {"Main", 1770, 2634}, {"Main_Light", 4404, 1140}},
		clips = []Quad_Clip{{"Idle", 0, 67, 20, true, 0}, {"Walk", 67, 21, 20, true, 1.2298}, {"Gallop", 88, 11, 20, true, 3.8371}, {"Eating", 99, 51, 20, true, 0}, {"Idle_HitReact_Left", 150, 14, 20, false, 0}, {"Death", 164, 22, 20, false, 0}, {"Attack", 186, 28, 20, false, 0}, {"Gallop_Jump", 214, 20, 20, false, 0}},
		sockets = []Quad_Socket{{"eye_L", {0.2413, 1.0576, 1.3407}, {0.8992, 0.136, 0.4158}, 38}, {"eye_R", {-0.1585, 1.0384, 1.3689}, {-0.8415, 0.0541, 0.5376}, 38}, {"hip_L", {0.2237, 0.7846, -0.1493}, {0, 0, 1}, 3}, {"hip_R", {-0.2237, 0.7846, -0.1493}, {0, 0, 1}, 7}, {"hoof_L", {0.2237, 0.1078, -0.148}, {0, 0, 1}, 44}, {"hoof_R", {-0.2237, 0.1078, -0.148}, {0, 0, 1}, 46}, {"mouth", {0, 0.8629, 1.7656}, {0, 0, 1}, 38}, {"tail_root", {0, 0.9088, -0.2981}, {0, 0, 1}, 10}, {"tail_tip", {0, 0.4916, -1.3637}, {0, 0, 1}, 17}, {"udder", {0, 0.5635, 0.0007}, {0, 0, 1}, 18}},
		mesh = QUAD_PACKFOX_MESH,
		rest = QUAD_PACKFOX_REST,
		frames = QUAD_PACKFOX_FRAMES,
	},
}
