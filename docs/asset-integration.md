# Asset workshop and game integration

How models and textures made in the workshop reach the game, who owns which file, and how an asset is accepted. Who is working on what, and the handoff history of all work (assets included), are on the board: [work.md](work.md). Write your row there before you edit.

## Ownership and interchange

Coordinate changes to joint names, socket meaning, units and axes on both sides of the export. The independent Blender workshop owns editable components, rigs, palettes, authored clips and export. A person and an agent can address the same part by a stable name such as `ear.L`. Start from a recipe to create a new asset. Open the existing Blender source for a local revision so a hand-sculpted muzzle survives an ear edit.

| File | Owner and use |
|---|---|
| Recipe JSON and editable `.blend` | Workshop. Recipe defines the starting geometry and pivots. The Blender file retains individually editable objects and later hand edits. |
| `.glb` in `assets/<name>/` (trees in `assets/trees/`) | Workshop exports it; it is the only hand-over. In the workbench (`tools/workbench.sh`) a GLB saved over the one in `assets/` is packed and on the screen in the running game about 1.3 s later. +Y up, metres, named bones and parts, named materials, baked animations, vertex colours, shape keys, and sockets as empty nodes named `socket_<name>` parented to bones. An edit to one source component produces a complete new GLB. |
| Packed `.bin`, `info.json`, `src/game/quadruped_assets.odin`, `fox_asset.odin`, `tree_assets.odin` | `tools/pack_assets` (Odin, `vendor:cgltf`) writes them from the GLBs on every build and check run, deriving normals, weights, rest frames, sampled clips, strides, sockets, material groups and colours. The game `#load`s only these; never edit them by hand. |
| Blender sources and scripts | The workshop folder outside the repository, `/Users/gio/Projects/prosio_asset_gen/` (its README says how each GLB was made). No Python or `.blend` file lives in the game repository; a rule fails if a `.py` file appears. |
| Versioned `.asset.json` | Workshop exports it alongside the GLB. The pilot specifies metres, +Y up, +Z forward and a semantic socket-to-joint map. Record the workshop revision alongside an adopted export. |

Odin owns AI, body composition, collisions, reach, grip targets, throws, inventories, building and simulation timing. Drive the visible pose from that state. Keep raylib calls in `src/game/platform.odin`. Resolve names when loading and share immutable asset data. Each actor needs independent pose state. Measure multiple visible animals before choosing CPU skinning, GPU skinning or rigid transforms. Preserve allocation-free gameplay updates. Include the shader, outline and projected-shadow passes in performance measurements.

## Asset and model choices

These are suggested starting efforts for authoring. They have not been compared in a controlled model benchmark.

| Asset family | Suggested GPT-6.2 model and effort | What the author needs to get right |
|---|---|---|
| Prosio | Astra High for body and action rig | Belly growth, limb proportions, clear hooves during motion, aiming and holding objects with two hands. Inspect at gameplay distance and in the outfit close-up. |
| Wardrobe | Astra High for fitting, Sol Medium for pieces | Ten slots and eight presets. Test inner and outer layers, front and back, across body sizes and arm positions. |
| Fox, goat and billy | Astra High for shared rig and grip behavior, Sol High for each first silhouette, Sol Medium for variants | Fox tail tip and mouth socket. Goat's two hind hooves must reach two distinct grips. Keep head, eyes, ears, horns, muzzle, legs and tail individually editable where applicable. |
| Turkey | Sol High for first rig, Astra High for difficult transitions | Leg grips, wings and tail fan in walking, held, swimming and floating poses. |
| Rabbit, crow, bee and fish | Sol Medium | Recognizable hop, wingbeat, swarm or swim at game-camera scale. |
| Trees, bushes, crops and pond plants | Sol High for the first family, Sol Medium for variants | Tree silhouettes, growth stages, wind, canopy fading and visibility around harvestable objects. |
| Oven, fire and block, churn, mill, bench, hives and larder | Sol Medium for geometry, Sol High for moving parts | Distinct moving parts, hinges, working positions and visible finished goods. |
| Fence, gate, scarecrow, rod, spear, rocks and pebbles | Sol Medium for shapes, Sol High for pivots and contacts | Fence-grid alignment, gate swing, hand grip, rod-line origin and projectile orientation. |
| Ingredients, dishes and sack icons | Sol Medium | Readability of the 33 inventory item kinds, including food seen in the world, in a fox's mouth and in the sack. |
| Terrain, water, lighting, shadows, particles and HUD | Sol High for visual iteration, Astra High for renderer or performance issues | Consistency under the game's camera, pixel scaling, lighting, outlines and shadow pass. |

## Migration and acceptance

1. **Fox.** Keep the procedural path available for comparison during the pilot. Load the GLB and manifest in the game and confirm socket names, axes, scale and clip playback. Compare trot, theft with food in mouth, held-by-tail, release, landing and shadow. Put two foxes in different poses to catch accidental sharing of mutable state. Build desktop and web, then exercise the asset on each target. Record screenshots and frame timings at the same camera and animal count.
2. **Goat and billy.** Reuse the quadruped vocabulary. Exercise two separate hoof contacts, struggle, milking, release and swimming. Verify the existing gameplay outcomes with the agent controls.
3. **Prosio and clothing.** Check hand clearance at lean, default and large belly sizes during a full stride, charge, aim and two-handed hold. Check garment coverage in the rotating outfit view. Keep progression, grip physics and saves compatible as the visual implementation changes.

Run `tools/check.sh` after game changes. Headless checks establish gameplay outcomes. Inspect rendered sequences for clipping, sliding sockets and inconsistent shadows. Record separately which builds ran, which scenes were seen, and which measurements are still missing.

