# [WD 3] Mixing in the game: the bowl, the oven and the fire on the real rules

**Status:** draft brief for Gio to review (2026-11-25). Not sent to the dev session. It is step 2 of [wd1](wd1-mixing-and-book.md) ("making it in the game"), on the rules of [wd1b](wd1b-quantities-times-effects.md) and [wd1c](wd1c-real-food-rules.md), which are built in `src/game/mixing.odin` and not yet called by the game. It should go after [wd2, the day's budget](wd2-day-budget.md) has landed, because it uses the stomach, the cooking times and the water in food from there.

Everything marked *proposed* is the planning session's and waits for Gio. The rest was decided by him on 2026-11-24.

## What this step is for

After it, Prosio cooks by the rules: he puts real amounts in a bowl, chooses how long to mix, how hot and how long to cook, and gets what the rules give, good or bad. The eleven fixed recipes of the oven and the fire are gone. The book, names and hidden recipes are the next step, not this one.

## In this step

### 1. The sack holds amounts

- Food in the sack is kept by weight as well as by piece, so a bowl can take 250 g of flour or 300 ml of milk. Eggs go by number, salt by the pinch.
- What the player sees stays simple: a box for each kind with how much of it.
- *Proposed:* the editor changes an amount in steps that suit the food (flour and the like 50 g, liquids 50 ml, an egg, a pinch), each step a number in the tuning files.

### 2. Made things in the sack

- A mix (a dough, a batter) and a dish (a bread, a cake) are things in the sack, carried, kept in a larder, stolen by the fox and gone off like any food.
- Each keeps what the rules worked out for it: its kind, weight, what it is made of, its microorganisms, how well it was mixed and cooked, and its effects.
- A mix can go back into a bowl with more things (a dough with cheese). That is the hierarchy.
- No memory is allocated: a fixed number of places for made things. *Proposed:* 16 different made things at once in the sack, and the same in each larder; when there is no place, he says so and the bowl is not made.
- *Proposed:* a dish goes into the sack cut into **portions** of about one meal (about 450 kcal, a number in the tuning files), so a loaf is several meals and the stomach of wd2 decides how many he eats at once.

### 3. Water and the bucket

- A **bucket**, made at the workbench from 2 logs. With it in the sack, `E` at the pond also fills it.
- *Proposed:* it holds 3 litres, used by the millilitre in a bowl. (wd1 said "three waters of a litre each", written before amounts were real.)

### 4. The mixing bowl

- A new place at home, by the oven. `E` opens the editor.
- It takes up to 4 kinds and 5 kg, as the rules do, and refuses what the rules refuse, saying why in his voice.
- He chooses the **mixing time**. The wait is 1 to 3 real seconds.
- What comes out is the mix the rules name, in the sack.

### 5. The oven and the fire

- The oven takes a mix or a single thing, a **temperature** and a **cooking time**. The fire (the one by the pond and his campfire) takes a **spit height** (low, middle, high) and a time.
- The timer stops by itself; the dish waits and does not go on cooking. The wait is a quarter of a real second for a dial minute.
- Wood is burnt by temperature and time, as the rules say (a small amount).
- One thing heated alone is the bowl of it alone: an egg on the fire is an omelette, a fish is grilled, meat is grilled.
- A drink in the oven boils away; on the fire it runs through the grill.
- The churn, the mill and the chopping block stay as they are.

### 6. The editor

One screen, the same at the bowl, the oven and the fire:

- **Left:** what in the sack can go in, with how much there is.
- **Middle:** what is in, and how much of each. Left and right change the amount.
- **Right:** what the bowl is like, as bars that move as things go in: how wet, how sweet, how salty, how fatty, how sour. Not what it will become.
- **Bottom:** the settings of this place (mixing time; or temperature and time; or spit height and time), each with an **interval** from the rules: wide for a beginner, narrowing with his baking or grilling skill, the best value never in the middle.
- It works with the keys and with the controller, in English and Polish, and everything fits (shown by the tour in both languages).
- *Proposed, until the book exists:* an **Again** line that refills the last bowl made at this place with the settings he used, if he has the things. Without it every loaf is entered by hand.

### 7. Eating a made thing

- He says what was wrong, by the worst of it ("Lumpy...", "Still gooey in the middle.", "Dry as dust.", "Burnt!", "Just right!"), in both languages.
- **Safety:** over the unsafe line, a tummy ache (the doubling-up he already has), longer the higher the count. Spoiled for good, he will not eat it.
- **Taste:** a short lift when it is good; half of it spat out when it is awful.
- **Energy:** the station's cooking bonus by how well it was mixed and cooked, growing with his skill as today.
- **Charcoal** cannot be eaten. A **Brick** cannot be eaten and is a rock: it can be thrown.
- Its sugar, salt, fat and fibre act on his body through what it is made of, as today.

### 8. Going off becomes microorganisms, for all food

- Decided on 2026-11-24: old food keeps its calories and becomes unsafe. So the sack's "loses half its calories in a set time" goes, for gathered food too, and every food carries its count.
- The count grows by the rules, by how warm the place is. *Proposed, until the seasons exist:* the sack and the open air are at 24 degrees; a larder is at 8 degrees. Both are numbers in the tuning files.
- The keeping times Gio set are the test: raw meat and fish must be cooked the same day; cooked, good for 2 days; eggs in the shell, 2 weeks.
- The sack shows when a thing is near unsafe and when it is unsafe, as it shows freshness today.

### 9. The old recipes and old saves

- The eleven fixed recipes of the oven and the fire go, with their menu.
- An old save's dishes are carried over as made things of the nearest kind with the same calories; nothing he had is lost. The save gets a new version.
- "He knows every recipe from the start" no longer applies to the oven and the fire; plans at the workbench are unchanged.

### 10. Pictures and words

- One picture and one name for each kind of mix and dish the rules can give from what is in this step, in both languages.
- A dish with a filling is named with it ("BERRY MUFFINS") by rule, as wd1 says, so the sack can tell two cakes apart. Renaming is for the book.

## Not in this step

| What | Why | Where it goes |
|---|---|---|
| The book, renaming, hidden recipes | Step 3 of mixing | next brief |
| Shaping (dumplings, noodles, layered bakes) | Worth little before the pot and the book | with the pot |
| The crock: pickles, wine, vinegar; what alcohol does to him | Needs days to pass visibly, and cucumbers and grapes | after the clock and the new foods |
| Washing and pressing | Nothing in the meadow today grows in the ground or is pressed | with the new foods |
| The new foods and chili | They need places to grow | the world slice |
| Seasons changing how food keeps | Needs the clock | the clock slice |

## Measuring and rules

- Rules: the game's bowl, oven and fire give exactly what `mixing.odin` gives for the same amounts and settings; the same bowl always gives the same thing; a made thing's weight and make-up are those of what went in, less the water driven off; the keeping times of section 8 hold in the sack and in a larder; no place for a made thing is ever overrun; an old save loads with what he had.
- The bot learns to cook by the new rules (at least bread, an omelette and grilled meat), so the long runs stay meaningful, and reports how often what it made was good, poor, unsafe or burnt.
- Screenshots of the editor at the bowl, the oven and the fire, in English and Polish.
- Every new number in `data/tuning/`, each with what it is, its unit and which way to turn it. README kept true; `tools/check.sh` passing.

## Open for Gio

1. **The pot.** By the rules raw milk gives him a tummy ache, and boiling is the cure, so without a pot milk is only good for the churn. *Recommended:* add the pot to this step (made at the workbench, used on the fire: boiled milk, boiled eggs, soup, porridge), and leave shaping and the crock out.
2. **Portions:** a dish cut into meals of about 450 kcal. Or should a loaf be one thing he eats bites from?
3. **Places for made things:** 16 different ones in the sack at once.
4. **Again** at each place until the book exists: wanted, or is entering the bowl each time part of the learning?
5. **Temperatures until the seasons exist:** 24 degrees outside, 8 in a larder.
6. **Amount steps** in the editor: 50 g and 50 ml.
7. **The bucket:** 3 litres.
