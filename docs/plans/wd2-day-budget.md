# [WD 2] The day's budget: what he burns, what the meadow gives, how fast he changes

**Status:** proposal for Gio to review (2026-11-24). Worked out on paper from the numbers in `data/tuning/`; nothing is built, nothing has been measured in the game, and nothing has been sent to the dev session.

## The targets (Gio, 2026-11-24)

- A day is 60 minutes of play.
- Four or five meals a day, about 2,000 kcal in all, keep an 80 kg Prosio at 80 kg.
- A third of the day (20 minutes) spent gathering and cooking brings in about 2,000 kcal.
- Cooking takes little real time: the dial shows cooking minutes, a bread waits about 10 seconds.

## 1. What he burns today, over a 60-minute day

At 80 kg with ordinary muscle (13 kg), counting 200 kcal to the kilogram as the game does:

| What | Today's number | Over a day |
|---|---|---|
| His muscles, all the time | 0.00023 kg a second for each kg of muscle | 2,150 kcal |
| Walking, half the day (30 minutes) | 0.02 kg a second | 7,200 kcal |
| Sprinting, 2 minutes | 0.06 kg a second | 1,440 kcal |
| Picking 150 things | 0.03 kg each | 900 kcal |
| 30 jumps | 0.06 kg each | 360 kcal |
| 30 bumps, grabs, bashes or throws | 0.2 kg each | 1,200 kcal |
| **An active day** | | **13,250 kcal** |

So today he burns between six and seven times the target, and standing still all day already burns more than 2,000.

## 2. What he should burn

An active day of 2,000 kcal, split as bodies split it: 1,200 for being alive, 800 for what he does.

| What | Proposed | Over the same day |
|---|---|---|
| His muscles, all the time | 92 kcal a day for each kg of muscle (0.56 of today) | 1,200 kcal |
| Walking | 17 kcal a minute, times his weight / 80 | 520 kcal |
| Sprinting | 52 kcal a minute, times his weight / 80 | 104 kcal |
| Picking something up | 0.43 kcal | 65 kcal |
| A jump | 0.87 kcal | 26 kcal |
| A bump, grab, bash or throw | 2.9 kcal | 86 kcal |
| **An active day** | | **2,000 kcal** |

Everything he does costs 0.072 of what it costs today (a fourteenth); they keep their proportions to one another.

What that gives for other pigs and other days:

| | A day of rest | An active day |
|---|---|---|
| Wasted (8 kg of muscle) | 740 kcal | 1,540 |
| Ordinary (13 kg) | 1,200 | 2,000 |
| Muscular (25 kg) | 2,300 | 3,100 |
| Most muscle (30 kg) | 2,770 | 3,570 |

A strong pig still needs proportionally more, as decided.

## 3. What it takes to gain or lose weight

Energy is what is kept in the books: what he eats and does not burn goes onto him, and what he burns and does not eat comes off. How many kilograms that is depends on one number, the calories in a kilogram of fat. Today it is 200, the same as for carbs and protein.

| Eating, on an active day | Each day, at 200 kcal a kg (today) | Each day, at 450 kcal a kg (proposed) |
|---|---|---|
| Nothing | loses 10 kg | loses 4.4 kg |
| 1,000 kcal | loses 5 kg | loses 2.2 kg |
| 2,000 kcal | stays | stays |
| 2,500 kcal | gains 2.5 kg | gains 1.1 kg |
| 3,000 kcal | gains 5 kg | gains 2.2 kg |
| 4,000 kcal (double) | gains 10 kg | gains 4.4 kg |

| How long it takes | At 200 | At 450 |
|---|---|---|
| From the start (45 kg of fat) to huge (70), eating double | 2.5 days | 5.6 days |
| From the start to lean (30), on half rations | 3 days | 6.8 days |
| From the start to no fat at all, eating nothing | 4.5 days | 10 days |

**Decided by Gio, 2026-11-24: it stays at 200 for fat, as for carbs and protein.** A change of shape is a matter of two or three days of play. (I had proposed 450, about a week.)

## 4. What the meadow gives

What grows back today, if all of it were picked the moment it was ripe, over a 60-minute day:

| Kind | A day |
|---|---|
| Berries | 62,600 kcal |
| Nuts | 31,300 |
| Cabbages | 24,800 |
| Apples | 22,800 |
| Wheat | 22,600 |
| Pumpkins | 20,900 |
| Honey | 18,000 |
| Mushrooms | 16,300 |
| Milk | 15,000 |
| Fish | 12,000 |
| Eggs (wild) | 11,400 |
| **All of it** | **about 258,000 kcal** |

That is 130 days of food growing every day. Scarcity today comes only from the short session.

**Proposed:**

- **Everything that grows or comes back takes 15 times as long.** Pumpkins come back in about three days, berries in about one, a penned turkey lays two to four eggs a day, a goat gives a jug or two a day, a hive a comb every hour or two. The meadow then gives about 17,000 kcal a day at the very most, eight days of food, much of it needing a fight, a pen or a walk.
- **Half as much standing at once:** at most 2,000 kcal of each kind (mushrooms 600), a day's food of each.
- No single kind then feeds him: each grows about 700 to 2,000 kcal a day (berries about 4,000), and he does not get all of any.

**Whether 20 minutes of gathering and cooking then brings 2,000 kcal cannot be worked out on paper.** It depends on how far apart things are and how much is ripe when he comes. He crosses the whole meadow in under a minute, so today it would take far less than 20 minutes; after the change it is what has grown that limits him. It has to be measured: a scripted forager, or the bot told to gather sensibly, over three days, reporting calories gathered for each minute of gathering. The number to turn is the 15.

## 5. What else is on the same clock

Three more things were set for short sessions and need to follow the day. Proposed starting points:

| What | Today | Proposed |
|---|---|---|
| Muscles and body skills fade by half | in 18 minutes | in 2 days |
| Training, wasting and recovering muscle | minutes | a seventh as fast |
| Protein, fibre, vitamins and salt in him run down by half | in 11 minutes | in a day |
| Water | a drink lasts 15 minutes or so | unchanged: three or four drinks a day |

## 6. Cooking time

The dial shows cooking minutes ("40 minutes at 200 degrees"). A dial minute is a quarter of a real second: a bread waits about 10 seconds, nothing more than about 20. Mixing takes 1 to 3 seconds. (Agreed 2026-11-24.)

## 7. Meals

Food keeps the calories it has now. A meal is 400 to 500 kcal: a pumpkin, a couple of cabbages, half a pie. A beginner's pumpkin pie (1,000 kcal) is two meals, and half a day.

## Open for Gio

1. ~~450 kcal to the kilogram of fat, or stay at 200?~~ **Decided: 200.**
2. **Decided 2026-11-24:** the active day of section 1 is the day to balance for.
3. **Decided 2026-11-24:** the meadow 15 times slower and half as full, as a first setting to be corrected by measuring.

Nothing is open. Not yet sent to the dev session: the mixing rework goes first.

## Added on 2026-11-24 (evening): the stomach, meat, and water from food

All of these are numbers for `data/tuning/`, each with its explanation, to be corrected by measuring.

**A stomach (Gio):** it limits how much he eats at once, by volume; the volume of a meal is its weight times `k`. *Proposed first setting:*

| Parameter | Value | Meaning |
|---|---|---|
| `k` | 1 litre to the kilogram | volume from a meal's weight |
| What it holds | 1 litre | about a kilogram of food at once |
| Empties in | 8 hours of the game's day (20 minutes of play) | about 3 kg of food a day |

So four or five meals of up to 600 g fit a day. On cabbage alone he tops out near 750 kcal a day; on mixed food 3,000 to 4,500; on bread about 8,000. Gaining weight means choosing dense food.

**What an animal gives (Gio: realistic, but balanced).** *Proposed:*

| Animal | Weighs | A real carcass | Proposed | Which is |
|---|---|---|---|---|
| Turkey | 16 kg | about 8 kg of meat | 3 kg | about 4,800 kcal |
| Goat | 55 kg | about 20 kg | 10 kg | about 14,000 kcal |
| Billy goat | 95 kg | about 35 kg | 16 kg | about 22,000 kcal |
| Fish | 400 g | about 200 g | 200 g | about 220 kcal |

What keeps that in balance: raw meat must be cooked the same day and cooked meat lasts two (see [wd1c](wd1c-real-food-rules.md), section 5); the stomach; meat alone is no diet; and **an animal that is killed comes back only after about a season** (today, minutes), so the meadow can be hunted out and a pen is the reliable way to have meat.

**The water in what he eats waters him (Gio)**, in proportion to the food's water content.

**How much he can gain in a day** (at 200 kcal to the kilogram): eating 3,000 kcal on an active day, 5 kg; 4,000, 10 kg; 6,000, 20 kg. The stomach and what the meadow holds are what limit it.
