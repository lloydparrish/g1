# Swordplay Content Package

Swordplay is the first substantial official package built on the shared content registry. It is enabled through Content / Mods and uses ordinary definitions for abilities, evolutions, characters, equipment, relics, artifacts, enemies, maps, stages, bosses and unlocks. The package ID is `swordplay`; permanent content IDs are explicit and do not contain package paths. Definitions can later move into Core without changing save identities.

When enabled, Swordplay definitions enter the same eligibility, reward, encounter and Stage-6 boss pools as Core. Prerequisites still filter each definition: combination techniques require both parent techniques currently owned, characters stay locked until their authored condition is met, and Sword Lord requires the package plus Stage 6. Disabling Swordplay stops it from entering new runs. A saved active run that uses the package prevents it from being disabled until the run is finished or discarded, so its definitions remain available to resume.

## Tags and progression rules

Swordplay uses the shared `sword`, `martial`, `melee`, `technique`, `mobility`, `defense`, `precision`, `heavy`, `area`, `forced_movement`, `piercing`, `rapier`, and `greatsword` tags where they describe reusable relationships. Tags drive ordinary reward affinity and prerequisites; they are not a player-facing taxonomy dump. The Mundane keeps an empty character-affinity map: its starting sword alone does not add Swordplay weighting.

Sword techniques spend Stamina and use the normal action-time and cooldown systems. Resource profiles intentionally differ. Most are usable without cooldown; expensive/strong techniques such as Whirlwind, Execute, Blade Rush, Overhead Strike, Reckless Swing and advanced forms have additional recovery time. Exact authored costs and cooldowns live in the package definitions below.

## Techniques

### Base techniques

| Technique | Initial cost / cooldown | Player-facing behavior |
| --- | --- | --- |
| Lunge (`lunge`, refined Core definition) | 8 Stamina / 85 time | Short, controlled gap closer followed by an attack; reserved for nearby targets. |
| Cleave (`cleave`, refined Core definition) | 13 Stamina / 125 time | Hits multiple adjacent enemies in a forward arc. |
| Pommel Strike | 5 / 75 | Modest close blunt damage and a brief stun. |
| Whirlwind | 20 / 135 / 2-turn cooldown | Hits every hostile adjacent to the user. |
| Execute | 14 / 125 / 2-turn cooldown | Close attack gains major bonus damage below 35% target Health; killing a foe restores Stamina. |
| Impale | 10 / 100 | Clear straight line up to 3 tiles, hitting the target and one foe behind. |
| Advance | 8 / 105 | Attacks, then steps into the target's vacated tile after a kill or displacement when legal. |
| Reposition | 8 / 95 | Attacks and then takes one controlled legal step. |
| Driving Blow | 11 / 115 | Blunt hit, up to 2-tile knockback; wall/actor collision causes additional damage and stun. |
| Blade Rush | 18 / 135 / 2-turn cooldown | Commits to a clear line up to 4 tiles and hits the first hostile; obstacles stop the charge. |
| Parry | 6 / 65 / 1-turn cooldown | Arms against the next melee hit, sharply reducing damage. It never counters automatically. |
| Thrust | 7 / 85 | Precise clear-line attack at up to 2 tiles. |
| Feint | 5 / 70 | Small hit that makes the target Exposed to the next sword attack. |
| Disengage | 10 / 105 / 1-turn cooldown | Attacks, then retreats up to 2 legal steps. |
| Overhead Strike | 17 / 145 / 2-turn cooldown | Committed heavy hit with armor penetration and extra force against armor. |
| Sweeping Blow | 14 / 125 / 1-turn cooldown | Hits a three-tile frontal arc and knocks foes back; collisions can stun and damage. |
| Reckless Swing | 16 / 130 / 2-turn cooldown | Wide heavy arc, followed by Off Balance, which increases damage taken through the next enemy action. |

Lunge and Cleave refine the existing Core records rather than duplicate them. Other base techniques are package definitions. Charge, dance-route, line, shove and retreat effects use legal path/movement checks; they respect bounds, walls, obstacles and occupied cells. Collision reactions are deterministic damage/disruption consequences, not a physics simulation.

### Selective evolutions

Evolutions replace the matching owned technique for the current run. There is no requirement that every technique have an evolution.

| Evolution | Replaces | Behavior |
| --- | --- | --- |
| Blade Dance | Whirlwind | Move up to 3 legal tiles and strike nearby foes along the route. |
| Executioner's Stroke | Execute | Finishes targets below 40% Health; a kill restores 16 Stamina and shortens its cooldown. |
| Skewer | Impale | Clear line up to 4 tiles, piercing up to 3 enemies. |
| Perfect Parry | Parry | Negates the next melee hit and strongly disrupts the attacker; no automatic counter. |
| Unstoppable Charge | Blade Rush | Commits up to 6 tiles and continues through foes killed along the route. |
| Battering Blow | Driving Blow | Drives one foe up to 3 tiles; collisions deal enhanced damage and stun. |
| Berserker's Arc | Reckless Swing | Larger, harder-hitting arc with the same significant Off Balance drawback. |

### Rare combinations

Each combination is a separate rare technique; both listed parent techniques must currently be owned. Parents are not consumed. Eligibility is checked from current run ownership, while normal rarity and reward weighting still apply. A prior combination does not permanently unlock the result.

| Combination | Prerequisites | Behavior |
| --- | --- | --- |
| Transfixing Charge | Lunge + Impale | Clear charge line through up to 3 targets. |
| Sundering Sweep | Cleave + Driving Blow | Broad arc with strong displacement and collision damage/stun. |
| Relentless Advance | Advance + Execute | Execute-style finish and move into the defeated target's tile; a kill returns 6 Stamina. It never grants an extra attack. |
| Masterstroke | Parry + Feint | Exposes the target while arming a melee defense; no counterattack. |
| Dancing Steel | Whirlwind + Reposition | Controlled movement up to 3 tiles, striking nearby foes along the route. |
| Armor Splitter | Overhead Strike + Impale | Concentrated piercing hit with high armor penetration and additional damage against armor. |
| Parting Thrust | Disengage + Thrust | Clear-line thrust followed by a legal retreat. |
| Great Cleaver | Sweeping Blow + Reckless Swing | Large frontal displacement with collision effects and Off Balance recovery. |

Great Cleaver is Epic; the other combination definitions are Rare. None creates recursive or repeated free attacks.

## Characters and unlocks

| Character | Starting weapon and kit | Attributes and starting resources | Permanent unlock |
| --- | --- | --- | --- |
| The Duelist (`duelist`) | Sword; Lunge only | Might 9, Dexterity 14, Vitality 10, Intelligence 8, Willpower 9, Perception 14; 38 Health, 52 Stamina | 5 successful melee Parries in one run. Activating a defense that blocks nothing does not count. |
| The Fencer (`fencer`) | Rapier; Thrust only | Might 8, Dexterity 15, Vitality 9, Intelligence 8, Willpower 10, Perception 14; 36 Health, 55 Stamina | 8 successful sword-technique movements in one run. Only movement actually completed by the technique counts. |
| The Berserker (`berserker`) | Greatsword; Cleave only | Might 14, Dexterity 8, Vitality 13, Intelligence 8, Willpower 11, Perception 9; 54 Health, 62 Stamina | Defeat Sword Lord of the Goblin Horde. Ordinary stat progression does not unlock this character. |

Affinities are respectively Sword/Martial/Precision; Sword/Rapier/Mobility/Precision; and Sword/Greatsword/Heavy/Martial. None starts with a large advanced kit or a character-exclusive ordinary active ability. Treatment A package portraits are stored beside the package content.

## Berserker's Blade Pair

Once per map, the Berserker can select two currently valid offensive actions: basic attacks and/or offensive abilities. The player chooses both actions and both targets before committing. The same ability cannot be selected twice; basic attack can be chosen twice. A defensive or utility-only ability is not a valid choice.

Resolution is deterministic and sequential internally, but the pair is one exceptional action: the first selected attack resolves first; the second resolves only if its exact selected target remains alive in its originally selected tile and the action still passes current range/line validation. If the first action kills or moves that target, or changes the state so the second cannot reach, the second is skipped. It is never redirected to another foe. The pair consumes one turn using the larger of the two action-time costs and does not grant free movement or a second full turn. Its used state is saved, survives stages, and resets only when the next Map is entered.

## Weapons

Core Sword and Greatsword definitions are reused. Swordplay adds the generic Rapier and an Offhand Sword. The Rapier is a light one-handed weapon with two-tile reach. The Offhand Sword supports the existing equipment slots: dual wield adds a lighter attack but costs more Stamina and time; two-handed weapons occupy both hands. There is no stance system or crafting ladder.

| Named weapon | Implemented identity |
| --- | --- |
| Goblinbane | Bonus damage to Goblinoids; a Goblinoid kill shortens technique cooldowns. |
| Needle | Rapier; grants Thrust while equipped and adds a target to its line penetration. Unequipping removes the temporary grant. |
| Headsman's Mercy | Slow Greatsword; raises Execute's threshold by 10 percentage points, with weaker ordinary attacks. |
| Wayfarer's Blade | Reduces Stamina cost of movement techniques by 2. |
| Stonebreaker | Adds armor penetration and collision damage. |
| The Second Hand | After a sword technique, the next basic attack gains 6 damage. No Time dependency. |
| Coward's End | Deals 5 bonus damage to foes left Unbalanced by displacement or collision. |
| Bloodless Edge | Builds up to 4 temporary Precision stacks across unhurt actions; each adds 2 sword damage, and taking damage clears the stacks. No Blood dependency. |
| Oathkeeper | Improves Parry damage reduction by 20 percentage points, at the cost of 2 ordinary attack damage. |
| Sword of the Goblin Horde | Your first sword technique each encounter costs 8 less Stamina. Technique kills briefly stack a martial damage bonus. |

Equipment-granted abilities are temporary while their grant source is equipped. The run save records weapon, equipment, and weapon-state counters; a grant is not copied into permanent run knowledge merely by equipping it.

## Relics and artifacts

Relics are run augments with distinct triggers rather than weapon upgrades:

- **Stride Medallion** — first successful movement technique each turn restores 3 Stamina.
- **Mirror Guard** — successful Parry restores 3 Stamina and grants Guard against the next hit.
- **Mason's Tooth** — collisions caused by forced movement deal 6 additional damage.
- **Low Crescent** — Execute-family finish threshold increases by 8 percentage points.
- **Long Measure** — Thrust and Impale gain one tile of reach along a clear line.
- **Killing Rhythm** — a technique hitting multiple enemies restores 4 Stamina for each target beyond the first.
- **Martial Chart** — modestly increases Sword, Martial and Precision reward weights.
- **Alternating Seal** — alternating basic attacks and techniques grants the next action a small damage bonus.
- **Opening Buckle** — first sword technique after entering a stage costs 5 less Stamina.

Artifacts make more dramatic rule changes:

- **Arc of Blades** — basic sword attacks clip one additional adjacent hostile for reduced damage.
- **Perfect Timing** — Parry fully negates and stuns on a melee hit, while Swordplay techniques cost 25% more Stamina.
- **Collision Engine** — forced movement travels one tile farther and collisions deal 12 additional damage.
- **Endless Form** — first sword technique in each encounter costs no Stamina, once per stage.

## Enemy family and procedural content

The package contributes nine ordinary fantasy martial enemies and a rare boss: Goblin Swordsman, Goblin Fencer, Goblin Blade Dancer, Kobold Duelist, Kobold Skirmisher, Orc Cleaver, Orc Breaker, Orc Berserker and Goblin Bladeguard. Their tactical definitions exercise gap closing, straight lines, withdrawal, Parry/Feint, multi-target attacks, armor pressure, heavy swings and collisions. Generic ability-aware enemy evaluation checks geometry, current position, range, target condition, area target count, Parry opportunity and retreat safety before selecting a technique.

Blade Warrens and its Goblin, Kobold and Orc stages enter the generic map pool when eligible. Individual Swordplay foes can also enter appropriate procedural encounters through their eligible faction definitions. Package definitions enter the ordinary weighted global reward candidates, with each item's rarity and prerequisites preserved. This does not make every package item immediately available or guarantee a Swordplay result.

## Sword Lord of the Goblin Horde

Sword Lord is a rare, package-qualified boss available only in Stage 6. His base weight is 0.16 with 0.20 depth-weight growth, consumed by the existing rare-boss depth multiplier. He is never eligible on Stages 1–5, and no endless-map branch names this boss. His 285 Health, 23 damage, 3 armor and Goblinoid mastery kit make him more threatening through armor, mobility, lines, defensive timing and execution rather than an extreme Health multiplier alone. His defined kit is Lunge, Blade Rush, Perfect Parry, Impale, Cleave, Reposition and Execute; generic tactical selection uses range, geometry, target Health, clustering and recent attacks.

The first production boss-clear awards The Berserker permanently and guarantees the Sword of the Goblin Horde reward opportunity. Later wins keep the special reward opportunity without re-awarding the unlock. The established map boss ID and reward resolution are saved so reload does not reroll an already generated encounter.

## Saves, visuals and verification

Swordplay IDs and assets are package-local, while save references use stable content IDs. The run serializes package IDs, learned/evolved abilities, equipment grants/state, relics, artifacts, unlock counters, boss identity/reward resolution and `berserker_power_used`. Existing version-1 and version-2 runs migrate through the shared run migration to the current save version; profile unlocks stay profile-scoped.

See [`SWORDPLAY_VISUAL_QA.md`](SWORDPLAY_VISUAL_QA.md) for retained desktop/mobile capture review. The production-path Swordplay regression runner is `tests/swordplay_runner.gd`; it is included in both `Test` and `BuildAll` in `scripts/arcanist.ps1`.

## Deferred hybrids

This package adds no Sword + Arcane, Blood, Fire or Time hybrids. Arcane remains school-less/direct magic. In particular, neither The Second Hand nor Bloodless Edge depends on Time or Blood. Any future hybrid remains blocked until its external family and actual required mechanic exist; see `SWP-010` in [`PLANNED_IMPLEMENTATIONS.md`](../PLANNED_IMPLEMENTATIONS.md).
