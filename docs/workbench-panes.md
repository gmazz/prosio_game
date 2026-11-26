# Adding a pane to the workbench

The workbench (`tools/workbench.sh`, README "The workbench") is the game in a window that rebuilds and swaps in new code whenever a file is saved. A **pane** is a panel on its right for one mechanic: things to try it with, live numbers, and the numbers of its formulas on sliders. There are two so far, **Attacks** (`draw_attacks` in `src/workbench/panes.odin`) and **Mixing and cooking** (`src/workbench/pane_mixing.odin`). This is how to add another, for example to show and judge new models or textures.

Write your row on the board ([work.md](work.md)) before you start.

## What to make: a file and one line

1. **A file of your own**, `src/workbench/pane_NAME.odin`, in `package workbench`, with a procedure that draws the pane's rows:

   ```odin
   package workbench

   import game "../game"
   import "core:fmt"

   draw_textures :: proc() {
   	pane_heading("Prosio's skin")
   	pane_text(fmt.tprintf("he weighs %.0f kg", game.g.prosio.kg), DIM)
   	if pane_buttons({"a lean pig", "a heavy pig"}) == 1 {game.set_weight(120)}
   	draw_formulas("textures") // its numbers, if it has any (below)
   }
   ```

2. **One line** in the table `PANES` in `src/workbench/panes.odin`:

   ```odin
   {name = "textures", title = "Textures", draw = draw_textures},
   ```

That is all. The pane then has a button under every pane's head, `pane textures` opens it from the command menu (Shift+1) or from outside, and Shift+6 opens whichever pane was open last. Each save of your file rebuilds and swaps it in about a second later.

Optional fields of the same line:

| Field | What it is |
|---|---|
| `command` | `proc(words: []string, line: string) -> string`: a command of the pane's own, run as `NAME ...` from the menu or from outside (`words` lower-cased, `line` as typed); what it returns is the answer. It is listed in the command menu with `help`. See `mixing_command`. |
| `help` | What that command takes, for the menu. |
| `save`, `load` | `proc() -> string` and `proc(text: string)`: the pane's own state as one line, kept across a swap (the game's state is kept by the workbench itself). See `mixing_text` and `take_mixing_text`. |

## The rows you can draw

All in `panes.odin`; each draws one row and moves down. Rows scrolled out of sight are only counted, not drawn.

| Procedure | Draws |
|---|---|
| `pane_heading(text)` | a section's title, with a rule above |
| `pane_text(text, color)` | a line of text (`INK`, `DIM`, `TYPE`, `AMBER`, `CHANGED`) |
| `pane_buttons(labels, lit, about) -> int` | a row of buttons; the one clicked this frame, or -1; `lit` marks those that are on |
| `pane_number(id, label, ^value, lo, hi, changed, about, unit) -> bool` | a number with a slider and a box to type into; true when it was changed |
| `pane_bar(label, value, lo, hi, good_lo, good_hi, best, text, about)` | a bar: where a value is, a span shown as right, and the best |
| `draw_formulas(name)` | every number marked for this pane (below), by file |

An `about` text shows at the pane's foot while the mouse points at the row (a click on a number's name keeps it there).

## Numbers of the formulas on sliders

A number in `data/tuning/*.json` goes on a pane when it is marked with the pane's name:

```json
"STOMP_SINK": {"f32": 0.15, "tune": "attacks", "about": "metres..."}
"STONE_MOMENTUM_SHARE": {"f32": 0, "tune": "attacks", "range": [0, 1], "about": "..."}
```

It must be an `f32`, or a table of them keyed by an enum (`"[Enemy_Kind]f32": {...}`) that is not `"const": true`; `"range"` is its slider's span (otherwise 0 to three times its value); `"tune"` may list several panes. `tools/gen_data` then makes it a variable in the workbench's build only and lists it in `src/game/gen_tune.odin`; `draw_formulas("NAME")` puts every number marked so on the pane. In the game the players get it stays a constant, as before. (`data/tuning` and `tools/gen_data` belong to the dev session: mark numbers through a row on the board.)

Every pane shares, without any code of its own: a slider and a box for each number, acting in the running game at once; changed numbers marked and counted in the head, and kept across swaps; **Save** (writes each changed number into its JSON file, nothing else in it, after backing up all of `data/tuning` into `tuning_backups/tuning_DDMMYY_HHMMSS/`), **Reset** (back to the files), and **Load parameters** (a backed-up set into the running game, to try). The commands `tune`, `tune-save`, `tune-reset`, `tune-list`, `tune-sets` and `tune-load` do the same from outside.

## Trying it from a shell

```bash
WORKBENCH_OUT=build/workbench_me WORKBENCH_UNFOCUSED=1 tools/workbench.sh
```

Then write a command into `build/workbench_me/command.txt` (`pane textures`, `shot build/me/pane.png`, `quit`) and read the answer in `build/workbench_me/answer.txt`. Use a folder of your own: the default one may be Gio's, and two workbenches on one folder would take each other's commands (a second one says so and stops). `WORKBENCH_UNFOCUSED=1` makes the window take no keys or clicks, so what Gio types elsewhere does not go into it.

## What must not happen

- **Nothing of a pane reaches the game the players get.** The workbench is built with `-define:WORKBENCH=true`; the game (`src/game`) reaches workbench code only inside `when WORKBENCH` blocks, and a rule in `tools/check.sh` fails otherwise. A pane reads and sets the game's state through `game.` (`game.g`, `game.set_weight` and the like). If it needs the game to do something it cannot do yet (a test rig, a hook), that goes in `src/game/workbench_hooks.odin` inside `when WORKBENCH`, which is the dev session's: ask through the board.
- The game allocates no memory and only `src/game/platform.odin` calls raylib; the workbench may do both (use `context.temp_allocator` for what lasts a frame).
- What a pane says is the workbench's own English; anything the player sees goes through `data/text` (README, "Text").
- No `.py` file in the repository (a rule fails); Blender and Python stay in the workshop folder.
- `tools/check.sh` passes before you hand over.
