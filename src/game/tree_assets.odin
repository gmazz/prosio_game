package game

// Made by tools/pack_trees.sh from the tree models: do not edit.

Tree_Model_Kind :: enum {Round, Lumpy, Pine, Fir}
TREE_MAX_VERTS :: 2916

TREE_MODELS := [Tree_Model_Kind]Tree_Model {
	.Round = {
		name = "round", // from tree-low-poly_1a5a63c3-4ea4-471d-99b8-1cc4321bd9af.blend
		bark = 720,
		leaves = 1680,
		height = 9.6469,
		crown_low = 2.8811,
		crown_high = 9.6469,
		crown_r = 4.0906,
		spots = []Vec3{{-2.9347, 7.118, 3.0349}, {0.5167, 6.8374, -3.2055}, {2.8469, 4.6849, 1.7321}, {0.782, 7.8721, 1.887}, {-2.3656, 8.408, -0.4741}, {-0.4344, 4.9315, 3.8135}, {-1.9919, 4.9178, 1.6575}, {-1.5798, 7.0687, -2.4003}},
		mesh = #load("../../assets/trees/round.bin", [][9]f32),
	},
	.Lumpy = {
		name = "lumpy", // from low-poly-sheesham-tree_2f5ad2ca-4dc1-4863-b37b-a0f09fec1c00.blend
		bark = 1260,
		leaves = 1656,
		height = 11.6253,
		crown_low = 4.4722,
		crown_high = 11.6253,
		crown_r = 6.7553,
		spots = []Vec3{{-2.2775, 8.6896, -6.5752}, {-0.0866, 8.2671, 5.3608}, {5.112, 10.2432, -1.8403}, {-4.1258, 10.8423, 0.2578}, {3.2899, 9.2985, 2.2988}, {1.5764, 7.9489, -4.2158}, {-4.2613, 7.6096, 3.2102}, {1.3995, 11.3771, -2.8209}},
		mesh = #load("../../assets/trees/lumpy.bin", [][9]f32),
	},
	.Pine = {
		name = "pine", // from low-poly-pine-tree_cb631e57-dffc-4130-b403-92011cbcd245.blend
		bark = 468,
		leaves = 2250,
		height = 3.7516,
		crown_low = 0.4997,
		crown_high = 3.7516,
		crown_r = 0.9764,
		spots = []Vec3{{0.4434, 0.6751, 0.9482}, {-0.3424, 2.9943, -0.462}, {-0.1302, 0.7681, -0.8963}, {-0.6676, 1.8011, 0.532}, {0.7208, 1.9507, -0.1619}, {-0.9947, 0.6537, 0.0376}, {0.9759, 0.6539, -0.131}, {-0.5185, 1.7709, -0.6859}},
		mesh = #load("../../assets/trees/pine.bin", [][9]f32),
	},
	.Fir = {
		name = "fir", // from tree_3ef9ae8b-ee50-4346-be64-62acae0b221b.blend
		bark = 114,
		leaves = 168,
		height = 3.1,
		crown_low = 0.8281,
		crown_high = 3.1,
		crown_r = 1.0928,
		spots = []Vec3{{0.2913, 1.3594, -0.7111}, {-0.2436, 1.8236, 0.6107}, {-0.6786, 1.3791, -0.2534}, {0.6458, 1.3886, 0.2828}, {-0.2361, 1.8267, -0.5799}, {0.5738, 1.8374, -0.2442}, {-0.6946, 1.3665, 0.2975}, {0.2746, 1.3745, 0.6598}},
		mesh = #load("../../assets/trees/fir.bin", [][9]f32),
	},
}
