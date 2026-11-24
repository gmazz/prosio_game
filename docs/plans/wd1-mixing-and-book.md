# [WD 1] Mixing, its editor, and the book

**Status:** agreed with Gio on 2026-11-24 (section 10 has his answers). Step 1 (the rules alone) is built: `src/game/mixing.odin`, tried with `tools/check.sh mix`.

## What this slice is for

It tests the core idea of the game in the smallest way: results come from properties and rules, the player finds out what works, and what works goes into his own book. It replaces the fixed recipe list of the oven and the fire. The workbench, building and the clock are later slices.

## What Gio decided (this slice must keep to it)

- Results come from properties and rules, not from a designed tree; but controlled: few properties, things change only when Prosio does something to them, the same inputs always give the same result, and every result is one of a known set of kinds.
- Hierarchical: a mix is a thing in itself (flour + water is a dough) and goes on into other things (bread, pizza).
- A failed experiment can be eaten, with unwanted and funny consequences.
- What works is written in his book with a proposed name he can change; names have a maximum length.
- Recipes made for the player in advance are made by exactly this mechanism, are hidden until he makes them, and cannot be read out of the game's files.
- There is an editor, so making a recipe is easy.

## 1. Properties

Every food keeps what it has today: its calories and its six shares (carbs, fat, protein, fibre, vitamins, electrolytes). Each also gets a few points of eight properties, per piece:

| Property | What it means in a mix |
|---|---|
| Wet | lets things come together; too much and it never sets |
| Starchy | the body of a dough or a batter |
| Binding | holds a shape when heated |
| Fatty | soft and rich |
| Sweet, Salty, Sour | taste |
| Raw | has to be heated out, or it bites back |

One more mark, **filling**, says a thing stays in pieces in a mix (fruit, nuts, cheese, meat).

Proposed points for what the game has now (blank is none):

| Thing | Wet | Starchy | Binding | Fatty | Sweet | Salty | Sour | Raw | Filling |
|---|---|---|---|---|---|---|---|---|---|
| Water (new) | 3 | | | | | | | | |
| Milk | 3 | | | 1 | | | | | |
| Flour | | 3 | | | | | | 1 | |
| Egg | 1 | | 3 | 1 | | | | 1 | |
| Honey | 1 | | 1 | | 3 | | | | |
| Butter | | | | 3 | | | | | |
| Salt | | | | | | 3 | | | |
| Cheese | | | 1 | 2 | | 1 | | | yes |
| Berries | 1 | | | | 2 | | 1 | | yes |
| Apple | | | | | 2 | | 1 | | yes |
| Pumpkin | | | | | 1 | | | | yes |
| Nuts | | | | 2 | | | | | yes |
| Cabbage, Mushroom | | | | | | | | | yes |
| Fish | | | | | | | | 1 | yes |
| Meat | | | | 1 | | | | 1 | yes |

These go in `data/tuning/food.json` beside `COMPOSITION`.

## 2. What he can do to things

| Doing | Where | In this slice |
|---|---|---|
| Mix | a mixing bowl (new, at home by the oven) | yes |
| Bake | the oven | yes |
| Grill | the cooking fire, his campfire | yes |
| Churn | the churn | stays as it is |
| Grind | the mill | stays as it is |
| Boil (needs a pot), leave to stand (needs the clock) | | later |

## 3. The rules

**Mixing** adds up the points of everything in the bowl and names the mix by them. With `r` = wet divided by starchy:

| The totals | It is a |
|---|---|
| Starchy 2 or more, `r` under 0.4 | **Crumbs** (too dry to hold) |
| Starchy 2 or more, `r` 0.4 to 2.2, binding under half the starchy | **Dough** |
| Starchy 2 or more, `r` 0.4 to 2.2, binding at least half the starchy | **Batter** |
| Starchy 2 or more, `r` over 2.2 | **Slop** (too wet to set) |
| Little starch, binding 3 or more | **Egg mix** |
| Little starch, wet 3 or more and at least twice the filling | **Drink** |
| Little starch, some filling | **Salad** |
| Little starch, none of the above, no filling (salt, butter, honey) | **Mush** |

A mix is a thing in the sack. It can go back into the bowl with more things (a dough with cheese), which is the hierarchy.

**Heating** turns a mix, or a single thing, into a dish:

| | In the oven | On the fire |
|---|---|---|
| Dough | Bread; with a filling, a Pie | Flatbread |
| Batter | Cake; with a filling, Muffins | Pancake |
| Egg mix | Custard | Omelette |
| Slop | a Brick | Porridge |
| Crumbs | Crackers | Charcoal |
| Salad | Baked ... | Grilled ... |
| Mush | Mush | Mush |
| Drink | boils away | runs through the grill |

**One thing heated alone** is heated as the bowl of it alone would be (decided 2026-11-24): an egg is a custard or an omelette, milk or water boils away or runs through, flour is crackers or charcoal, a fish, meat, an apple or a mushroom (a salad of itself) is baked or grilled.

That is 8 kinds of mix and 15 kinds of dish, 23 in all, plus the two ways a drink is lost. Each kind needs one picture and one name; nothing else is written per recipe.

**Tried on the game's foods** (worked through with the points above):

| In the bowl | It is | Oven | Fire |
|---|---|---|---|
| 1 flour, 1 water | Dough | Bread | Flatbread |
| 1 flour, 1 water, 1 cheese | Dough | Pie | Flatbread |
| 1 flour, 1 water, 3 apples | Dough | Pie | Flatbread |
| 1 flour, 2 eggs, 1 milk | Batter | Cake | Pancake |
| 2 flour, 2 eggs, 1 milk, 3 berries | Batter | Muffins | Pancake |
| 1 flour, 3 water | Slop | Brick | Porridge |
| 2 flour | Crumbs | Crackers | Charcoal |
| 2 eggs, 1 milk | Egg mix | Custard | Omelette |
| 3 berries, 1 water | Drink | boils away | runs through |
| 1 flour, 1 egg, 3 apples (today's apple pie) | Crumbs | Crackers | Charcoal |

Added after it was built (2026-11-24): 1 salt, 1 butter is **Mush** (Mush, Mush); 2 honey is **Mush**; 2 pumpkins is a **Salad** (Baked, Grilled). A dough with three lumps of salt stays plain **Bread**: the salt is in its shares, and that is the consequence.

The last row matters: **today's pies and muffins have no liquid in them, so under these rules they come out as crumbs.** Every one of them needs water or milk added. That is the rules doing their job, but it changes every recipe the game has.

**How good it is.** Each kind of mix has a best `r` (dough about 0.8, batter about 1.4). The nearer the mix, the more of the station's cooking bonus the dish gets; at the edge of the range it gets none. Egg mix, drink and salad always get all of it; crumbs, slop and mush none. So proportions are worth improving, and the book keeps the player's best.

**What it is worth.** Unchanged from today: a dish is what went into it, share for share, times the cooking bonus. Any combination, planned or not, has honest calories and nutrients. Two exceptions: **Charcoal** and a **Brick** cannot be eaten: no calories, but they keep the weight that went in (decided 2026-11-24).

## 4. Failures and consequences

Most consequences need nothing new, because what he eats already acts on his body:

- Too much salt in it: he is parched, and the goats come.
- Too much honey: a sugar rush, then the crash, then hiccups.
- A cabbage cake: gas.

Four things are new:

| What | Consequence |
|---|---|
| Anything eaten with **Raw** still in it (raw dough, batter, an unheated egg mix) | a tummy ache for a while (the doubling-up he already has) |
| Very **sour** | his face screws up and he shudders; nothing else |
| A **Brick** (baked slop) | cannot be eaten: "Ow! My tooth!". It is a small rock: he can throw it |
| **Charcoal** | cannot be eaten |

Crumbs, Slop and a Salad of odd things are simply poor food. Nothing is ever lost outright except a drink put on the fire.

## 5. Water

Mixing needs water, and today water is only a drink at the pond. Proposal: a **bucket** made at the workbench (2 logs). With a bucket in the sack, `E` at the pond also fills it: three waters, a kilogram and a litre each.

## 6. The editor

One screen, opened with `E` at the bowl, the oven or the fire:

- **Left:** what is in the sack that can go in.
- **Middle:** the bowl. Up to four kinds of thing and nine pieces. Left and right change how many.
- **Right:** a bar for each property, moving as things go in and out. He sees "very wet" before he makes it. He does not see what it will become.
- **Bottom:** what this place does (MIX, BAKE, GRILL) and how many batches.
- **From the book:** a line for each recipe he has found that can be made here; choosing one fills the bowl, if he has the things.

## 7. The book

A new page in the `M` menu.

- **An entry** is: what went in and how much, what was done to it, the kind it came out as, its name, and what one piece is worth. Its picture is the kind's.
- **Two things made the same way from the same kinds of thing are one entry.** Different amounts of the same things update the entry if they came out better, so the book does not fill with twelve breads.
- **Its name is proposed by rule:** the kind, with the main filling before it ("BERRY MUFFINS", "CHEESE PIE", plain "BREAD"). One press accepts it. Changing it opens a letter picker that works with keys and with the controller. At most 14 letters, to be tested in every menu in both languages.
- **Failures are entries too,** with what happened to him noted under them ("gave me a tummy ache").
- **Recipes made in advance** are entries like any other, hidden until he makes the same thing, and then shown with the name they were given. A dough with cheese, baked, would be found as "PIZZA".
- **He starts with an empty book.** Nothing is blocked by that: grilling an egg works without knowing it.

**Keeping the hidden ones hidden** (agreed): the game holds each hidden recipe only as a one-way fingerprint of what goes in and what is done, never the recipe itself; the saved book carries a checksum; names stay in the text files.

## 8. What changes under the hood (for the dev session)

- Today every dish is one of a fixed list (`Item` in `kitchen.odin`) and the sack keeps a count, calories and freshness for each. Made things cannot be a fixed list any more. Proposal: a fixed number of **book slots** (48 to start with), each a made thing, and the sack, the larder, going off and the fox extended to count them as they count items. No memory is allocated.
- The rules of sections 3 and 4 are small functions with no state, with their thresholds in `data/tuning/food.json`.
- The 11 fixed oven, fire and churn recipes go; the ones worth keeping come back as recipes made in advance, each written with water or milk so that it comes out as its kind.
- The save needs a new version that carries the book, and turns an old save's dishes into the matching entries.
- Text: names of the 23 kinds (and the two ways a drink is lost), and for each ingredient the word that goes before a kind, in English and in Polish (where it must agree with the kind's gender).
- Rules for the check suite: the same bowl always gives the same thing; every recipe made in advance comes out as its kind through the game's own mixing; a dish's weight and shares are those of what went in; no hidden recipe can be read from the game's data; a name longer than the limit cannot be saved.

## 9. Order of building, each testable by itself

1. **The rules alone.** Properties in the data, the mixing and heating rules, rules in the check suite, and a command that prints what any bowl gives (`tools/check.sh mix "Flour 1, Water 1" bake`). No screen yet. This is where the points and thresholds get tuned.
2. **Making it in the game.** Book slots in the sack, the bowl and its editor, the oven and the fire using the rules, the bucket and water, the consequences.
3. **The book.** Its page, names and renaming, the hidden recipes and their protection, Polish.

## 10. Open questions for Gio

1. ~~Today's recipes change. Every pie and muffin needs a liquid from now on.~~ **Decided 2026-11-24: yes, add liquid.**
2. **Decided 2026-11-24:** the mixing bowl is by the oven.
3. **Decided 2026-11-24:** all the kinds (23, once counted, with Mush), and they need testing.
4. **Decided 2026-11-24:** the Brick is a rock he can throw.
5. **Decided 2026-11-24:** the cooking bonus still grows with his skill, with the quality of the mix on top.

No questions are open.
