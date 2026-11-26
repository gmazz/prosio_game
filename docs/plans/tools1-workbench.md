# [Tools 1] The workbench: change the game while it runs

**Status:** built (all six steps, 2026-11-25) and extended since with panes (2026-11-26, see `docs/workbench-panes.md`); the README's "The workbench" says how it works now. What follows is the proposal as written before building. Build times below were measured on Gio's Mac; everything about Windows and Linux is unverified.

## What Gio asked for (2026-11-25)

> Instead of a test meadow I wanna a testing system that allows me to edit directly to select any entities open the odin scripts controlling those entities with a click, modify the code and automatically recompile it at file save [...] I want also a menu allowing to perform any action, teleport to and region, etc. Basically I wanna a fully interactve IDE for the game.

> I wanna the editing system to be portable across platforms so that I can edit and make changes directly without relying on external tools on other machines.

Decided since: the editor is built into the workbench, on Odin's own `core:text/edit` and `core:odin/tokenizer`; no C library. The workbench replaces the Test Meadow.

## 1. What makes this possible

- **Everything is compiled in.** Code, tuning numbers, texts, shaders and packed models all become part of the program when it is built. So one mechanism, rebuild and reload, covers every kind of change.
- **A rebuild is fast.** Unoptimised: 0.56 s. Checking for errors only: 0.07 s. (The optimised build the players get takes about 7 s; the workbench does not use it.)
- **The game's state is one record of plain numbers** (`Game` in `src/game/game.odin`) and the game allocates no memory. It can be handed from the old code to the new in one copy.
- **Only `platform.odin` talks to raylib**, so the window can stay open while the rest is swapped.

## 2. How it works

```
tools/workbench.sh
      │
      ▼
 the host (small program, never reloaded)
   · opens the window
   · watches src/, data/ and assets/ for saved files
   · rebuilds the game as a loadable library
   · swaps it in and hands the state across
      │ loads
      ▼
 the game library (rebuilt on every save)
   · the whole game, unchanged
   · the workbench's own panels: menu, inspector, editor, overlays
```

**On every save:**

1. The host sees a newer file (it compares file times a few times a second; no system-specific watching, so it is the same on every platform).
2. If a tuning or text file changed, `gen_data` runs. If a GLB changed, the asset packer runs.
3. The game is rebuilt as a library, under a new file name each time.
4. **If the build fails:** nothing is swapped. The old game keeps running and the compiler's errors show in a panel; clicking one opens the file at that line.
5. **If it succeeds:** the new library is loaded, the graphics it needs (meshes, shader, font) are loaded again, the state is copied in, and the game carries on from the same frame.

**What survives a reload:** the whole `Game` record (Prosio, every animal, the world, the camera), plus the few things kept outside it that matter (which screen is showing, his outfit, the language, the key bindings). These are gathered into one second record so they can be handed across together.

**What does not:** menu cursors and similar, which start again. They are cheap to lose.

**When the state's shape changes** (a field added to an animal, a list made longer), the old state no longer fits the new code. The workbench then starts a fresh game and replays the current set-up (section 4), so the scene comes back by itself.

**Old libraries stay loaded** until the workbench closes. The state holds pointers to texts that live inside the library that made them; unloading it would leave them dangling.

## 3. What changes in the game itself

As little as possible, and none of it in the game the players get:

| Change | Why |
|---|---|
| `platform_init` splits into "open the window" and "load the graphics" | The window is opened once by the host; the graphics are loaded again after each swap. |
| Two hooks, called after the game's update and after its drawing, compiled in only for the workbench | So the workbench's panels can run without the game knowing about them. |
| The game can be drawn into part of the window | So the editor has room beside it. First version: the editor is a panel over the right half and the camera shifts left; a true split comes later if wanted. |
| The loose variables that should survive a reload move into one record | See section 2. |
| The Test Meadow (`lab.odin`, its fields in `Game` and `Options`, its `--lab` builds, its texts and tuning) is deleted | Replaced by section 4, once that does everything it did. |

Everything else lives in a folder of its own, `src/workbench/`, and its own build. A rule in `tools/check.sh` fails if the normal desktop or web build contains any of it. The workbench may allocate memory; the game still may not. The workbench never reads or writes the saved game.

## 4. The command menu

One key opens a searchable list. Type a few letters, press enter.

| Group | Commands |
|---|---|
| Go | Teleport to any region, to home, to the oven, the pond, a named animal, or where the mouse points |
| Put | Any animal, food, item or built thing at the mouse or in front of him; a pen with a turkey in it; a crowd |
| Him | Weight, fat, each muscle and skill, each need, bruises, stamina; fill the sack; choose an outfit |
| Make happen | Any reaction (wind, hiccup, tipsy), a fall, a faint, a knock-out; an animal's state (charge, flee, dead, swimming) |
| Time | Pause, one frame forward, slow motion (half, quarter, tenth), fast forward; time of day and season once the clock exists |
| Look | Free camera, zoom, portrait view, follow a chosen animal |
| Set-ups | Save the current scene under a name; load one; replay the current one |

A **set-up** is a short list of these commands saved as text ("120 kg, Goat Hills, one billy goat two metres in front"). It is what gets replayed when the state's shape changes, and it is how a bug is handed to someone else.

The same commands are offered to `tools/play.sh` under a separate word, usable only in the workbench build, so a playtesting agent can set up a scene. The rule that an agent playing the real game presses only a player's buttons stays as it is.

## 5. Select, inspect and open

**Selecting.** Click anything: Prosio, an animal, a tree or rock, a piece of food, a field, a fish, a pest, a hive, the oven, fire, churn, mill and bench, a fence, a larder. The workbench projects each thing's position to the screen and takes the nearest to the click; clicking again cycles through what is under the mouse.

**The inspector.** A panel with every number of the selected thing, updated live. Odin can list any record's fields by itself, so new fields appear without anyone adding them.

**What controls it.** The game has no script per entity; a goat's behaviour is spread over several procedures. So the workbench keeps an index, a small table that says for each kind of thing what moves, draws and tunes it:

| A goat | Opens |
|---|---|
| Deciding what to do | its cases in `update_enemies`, `enemies.odin` |
| Steering and turning | `quad_steer`, `quadruped.odin` |
| Feet on the ground | `quadruped_motion.odin` |
| Being bumped or thrown | `impact.odin` |
| Being held | `grab.odin` |
| Being drawn | `draw_enemy`, `quadruped.odin` |
| Its numbers | `data/tuning/animals.json` |
| Its model | `assets/goat/goat.glb` (revealed in the file browser) |

Each entry names a procedure, and Odin itself supplies that procedure's file and line when the workbench is built, so the index stays right as code moves. A rule fails if any kind of thing has no entry, so a new animal or food cannot be added without one.

## 6. The built-in editor

Built from what ships with Odin, with no outside library:

- **`core:text/edit`** for the text state: cursor, selection, movement by word and line, undo and redo, cut, copy and paste.
- **`core:odin/tokenizer`** for colouring Odin code. If it colours half-typed lines badly (it is made to report errors), a small forgiving tokenizer of our own replaces it. Tuning and text files get simple JSON colouring.
- **Our own drawing**, in **Iosevka Fixed** (Gio, 2026-11-25): a narrow monospace font, each character half the font size wide, so about 80 columns fit in half a 1280-wide window at size 16 (worked out, not measured). It has no ligatures, so raylib draws it directly and no shaping library is needed. The font file (open licence, SIL OFL) is added under `assets/fonts/` for the workbench only; the game's font is unchanged. Ligatures (Fira Code, through `vendor:kb_text_shape` and `vendor:stb/truetype`) were considered and set aside as an unproven extra.

What it does:

- Opens a file at a line, from the index, from a compile error, or by name.
- Several files open at once, as tabs.
- Edit, save (which triggers the reload), undo, redo.
- Find in the file, find across the project, go to line.
- Line numbers, the current line marked, the lines with compile errors marked.
- While the editor has the keyboard, the game does not.

What it does not do: code completion, jump to a definition by clicking a name, or refactoring. Errors come from the compiler after a save, about a second later.

It is a text-box library underneath, holding each file as one piece. That suits this project: the longest file is about 3,600 lines.

Any outside editor still works beside it, since the host only watches for saved files.

## 7. Seeing inside

Switches in the menu, drawn over the world:

- Collision circles, reach and grab ranges, grip points and sockets.
- For each animal: what it is doing and for how long, where it is heading, its home.
- The fence grid, region borders, what has grown and when the rest will.
- The skeleton and the 36 body parts over a skinned model.
- Frame time, and how much of it went to updating, to skinning and to drawing.

## 8. Models

Depends on the GLB packer (sent to the dev session on 2026-11-25). Once every model reaches the game as a GLB, the host watches those too: export from Blender, the packer runs, the game reloads with the new model a second or two later.

## 9. Order of building

| Step | Done when |
|---|---|
| 1. The live loop | `tools/workbench.sh` opens the game. Changing a number in `data/tuning/prosio.json`, a line in `prosio.odin`, a text and the shader each shows in the running game within about a second, with Prosio where he was. A deliberate error shows the compiler's message and the game keeps running. Adding a field to `Enemy` restarts the scene cleanly. |
| 2. Commands and set-ups | Everything the Test Meadow did can be done from the menu; a saved set-up reloads with one key. The Test Meadow is deleted. |
| 3. The editor | A file can be opened by name, edited, saved and reloaded without leaving the window. Compile errors open at their line. |
| 4. Select, inspect, open | Clicking a goat shows its numbers and its index; each entry opens the editor at the right line. The rule for the index passes. |
| 5. Seeing inside | The overlays of section 7; numbers editable in the inspector. |
| 6. Models | A GLB saved from Blender shows in the running game. |

Step 1 is the one that proves the idea, and is useful by itself with any editor.

## 10. What could go wrong

| Risk | What to do |
|---|---|
| The gamepad code on the Mac (`pad_darwin.odin`) may not survive a swap | Test in step 1; if needed, set it up again after each load. |
| The unoptimised build may be slow with several skinned animals on screen | Measure in step 1 with a crowd. If so, build with light optimisation and accept a slower rebuild. |
| raylib must be shared between the host and the library | A shared raylib ships with Odin for macOS (seen). Windows and Linux: unverified. |
| The Odin compiler must be on any machine that edits | It is one folder that can be carried along, but it uses the system's linker (Apple's developer tools, Microsoft's build tools). How self-contained it is on Windows: unverified. |
| The web version cannot reload | The workbench is desktop only. The web build is untouched. |
| Text pointers into old code | Old libraries are kept loaded (section 2). |
| The editor grows without end | Its list in section 6 is the scope. Anything more is asked for separately. |

## 11. How it sits with the other work

- **The GLB packer** is with the dev session now. Step 6 here waits for it; steps 1 to 5 do not.
- **The character cleanup** (pose worked out apart from drawing, eyes and mouth into Blender, the fit check in the standard rules, the Anderson pig deleted) is not sent yet. Its "Test Meadow as a separate build" item is replaced by step 2 here.
- **Both touch `platform.odin` and `game.odin`**, as does step 1, so they are built one after another, not side by side.

## Open for Gio

1. Is the editor's list in section 6 the right size for a first version?
2. The editor as a panel over the right half of the window at first, a true split later: acceptable?
3. ~~Which comes first after the GLB packer?~~ **Decided by Gio, 2026-11-25: the character cleanup first**, then step 1 of the workbench. (I had proposed the other order.)
