# For an agent working on Prosio

Prosio is a small game about a pig, for seven-year-olds, written in Odin with raylib. `README.md` describes everything the game is meant to do and how the code is laid out; read it before changing or judging anything.

## Coordinating asset work

For work on generated assets, rigs, outfit fitting, or their rendering and import, read the [asset integration plan and handoff](docs/asset-integration.md) first. Record your intended slice and affected files under **Current work** before editing. Refresh that entry if the scope changes. At handoff, record what landed, how you verified it, what remains unverified, and the next step. Check existing entries and the working tree for overlapping edits. Keep the Blender generator in its own repository.

## Building and running

- `./build_desktop.sh` builds `build/desktop/prosio`; `./build_web.sh` builds the browser version.
- You need Odin on the path. Nothing else is installed or downloaded.

## Testing it without a person

All of these run from a shell and answer in text (and pictures you can open):

| What | Command |
|---|---|
| The rules the game must keep (PASS or FAIL for each) | `tools/check.sh` |
| A bot plays for a long while and reports anything odd | `tools/check.sh autoplay --minutes 30 --seed 3` |
| Screenshots of every place, menu and outfit, with his state in numbers beside each | `tools/tour.sh` |
| One scripted run: a picture and his state at a chosen frame | `./build/desktop/prosio --pos 6 6 --shot out.png --frame 40` |

## Playing it yourself

The game is played in real time, which no program that thinks between moves can keep up with. So there is a way to play it a step at a time:

```
tools/play.sh start
tools/play.sh help
tools/play.sh look
tools/play.sh "walk 14 -30" "look" "tap g" "state"
tools/play.sh stop
```

The game stands still until you send a command, runs the frames you ask for with the buttons you name, and says what happened. `look` gives the screen in words, `shot FILE.png` gives it as a picture. You press the same buttons a person does; nothing reaches round the rules. The saved game is never read or written.

## If you were asked to playtest

Follow `.claude/agents/playtester.md`. It is written for one kind of agent but applies to any: what to run, how to judge what you find, and what the report must contain. In short: you do not change `src/`, `tools/` or `README.md`; whatever you make goes under `build/playtest/`; every finding says whether you reproduced it, measured it, read it in the source, or only suspect it.

## If you were asked to change the game

- Every number that shapes the game is in `data/tuning/*.json` (being moved there subject by subject; the rest are still named constants near the top of their files). The build turns those files into `src/game/gen_*.odin`: edit the JSON, never the `gen_` files. The README's "Tuning" table says where each number is.
- `src/game/platform.odin` is the only file that calls raylib. The game allocates no memory.
- When you fix or decide something, add a rule for it to `src/check/rules.odin`, and keep the README true.
- Run `tools/check.sh` before you say you are done.
