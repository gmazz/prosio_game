package pack_assets

// Turns the models the game draws from GLB files into what it loads.
//
//   Blender (outside this repository) --export--> assets/<name>/<name>.glb
//   tools/pack_assets --> assets/<name>/*.bin and info.json,
//                         src/game/*_assets.odin  --#load--> the game
//
// The GLB is the only thing handed over from Blender: +Y up, named bones and
// parts, named materials, baked animations, vertex colours and shape keys.
// Everything derived from it is worked out here, never stored in it: flat
// and smooth normals, the four strongest weights, inverse rest frames,
// animations sampled, strides, sockets. The game reads only the packed files
// (through #load), never a GLB. This tool may allocate; the game does not.
//
//   tools/pack_assets.sh     (the build scripts and tools/check.sh run it)
//
// A file is written only when what it would hold changes, so a build after
// no change to any GLB leaves everything as it was.

import "core:fmt"
import "core:os"
import "core:strings"

QUADS := []Quad_Spec {
	{
		name = "goat", length = 2.6,
		clips = {"Idle", "Walk", "Gallop", "Eating", "Idle_HitReact_Left", "Death", "Attack_Headbutt", "Gallop_Jump"},
		sockets = {"eye_L", "eye_R", "hip_L", "hip_R", "hoof_L", "hoof_R", "mouth", "tail_root", "tail_tip", "udder"},
	},
	{
		name = "billy", length = 2.6,
		clips = {"Idle", "Walk", "Gallop", "Eating", "Idle_HitReact_Left", "Death", "Attack_Headbutt", "Gallop_Jump"},
		sockets = {"eye_L", "eye_R", "hip_L", "hip_R", "hoof_L", "hoof_R", "mouth", "tail_root", "tail_tip", "udder"},
	},
	{
		name = "packfox", length = 3.2, flag = "PACK_FOX",
		clips = {"Idle", "Walk", "Gallop", "Eating", "Idle_HitReact_Left", "Death", "Attack", "Gallop_Jump"},
		sockets = {"eye_L", "eye_R", "hip_L", "hip_R", "hoof_L", "hoof_R", "mouth", "tail_root", "tail_tip", "udder"},
	},
}

fail :: proc(asset: string, format: string, args: ..any) -> ! {
	fmt.eprintf("pack_assets: %s: ", asset)
	fmt.eprintfln(format, ..args)
	os.exit(1)
}

main :: proc() {
	root := len(os.args) > 1 ? os.args[1] : "."
	quads := make([]Quad_Packed, len(QUADS))
	for spec, i in QUADS {
		dir := join(root, "assets", spec.name)
		quads[i] = pack_quadruped(spec, join(dir, strings.concatenate({spec.name, ".glb"})))
		q := &quads[i]
		write(join(dir, "points.bin"), bytes_of(q.points[:]))
		write(join(dir, "corners.bin"), bytes_of(q.corners[:]))
		write(join(dir, "flats.bin"), bytes_of(q.flats[:]))
		write(join(dir, "rest.bin"), bytes_of(q.rest))
		write(join(dir, "frames.bin"), bytes_of(q.frames[:]))
		write(join(dir, "info.json"), transmute([]byte)quad_info(q^))
	}
	write(join(root, "src", "game", "quadruped_assets.odin"), transmute([]byte)quad_tables(quads))

	skin_dir := join(root, "assets", "prosio_base")
	skin := pack_skin("prosio_base", join(skin_dir, "prosio_base.glb"), join(skin_dir, SKIN_BIND))
	write(join(skin_dir, "vertices.bin"), bytes_of(skin.vertices[:]))
	write(join(skin_dir, "indices.bin"), bytes_of(skin.indices[:]))
	write(join(skin_dir, "paint.bin"), bytes_of(skin.paint[:]))
	write(join(skin_dir, "face_fat.bin"), bytes_of(skin.face[:]))
	write(join(skin_dir, "rest.bin"), bytes_of(skin.rest[:]))

	fox_dir := join(root, "assets", "fox")
	fox := pack_fox("fox", fox_dir)
	write(join(fox_dir, "vertices.bin"), bytes_of(fox.vertices[:]))
	write(join(fox_dir, "indices.bin"), bytes_of(fox.indices[:]))
	write(join(root, "src", "game", "fox_asset.odin"), transmute([]byte)fox.table)

	trees := make([]Tree_Packed, len(TREES))
	for name, i in TREES {
		dir := join(root, "assets", "trees")
		trees[i] = pack_tree(name, join(dir, strings.concatenate({name, ".glb"})))
		write(join(dir, strings.concatenate({name, ".bin"})), bytes_of(trees[i].rows[:]))
		write(join(dir, strings.concatenate({name, ".json"})), transmute([]byte)tree_info(trees[i]))
	}
	write(join(root, "src", "game", "tree_assets.odin"), transmute([]byte)tree_tables(trees))
}

join :: proc(parts: ..string) -> string {
	return strings.join(parts, "/")
}

bytes_of :: proc(s: []$T) -> []byte {
	return ([^]byte)(raw_data(s))[:len(s) * size_of(T)]
}

// Writes a file only if it would change.
write :: proc(path: string, data: []byte) {
	old, err := os.read_entire_file(path, context.allocator)
	if err == nil && string(old) == string(data) {
		return
	}
	if e := os.write_entire_file(path, data); e != nil {
		fail(path, "cannot write it (%v)", e)
	}
	fmt.println("pack_assets: wrote", path)
}
