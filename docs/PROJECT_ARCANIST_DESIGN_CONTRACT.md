# Project Arcanist — v0.1 Design Contract

## Product definition

- Genre: turn-based tactical horde roguelike / buildcraft RPG.
- Primary platform: Android landscape.
- Secondary platform: Windows development/testing.
- Engine: Godot 4.x.
- Target successful-run length: approximately 45–90 minutes, with reliable suspend/resume.
- Initial presentation: polished symbolic/tile graphics with rendering separated from game state.
- Core inspiration: deliberate tactical combat and build planning combined with escalating synergistic builds.

Core fantasy: start as a relatively understandable adventurer and end a run as a mechanical engine assembled from weapons, magic, summons, artifacts, environmental effects, passives and hybrid disciplines. Pure martial, pure magical and hybrid builds must all be legitimate.

## Non-negotiable architecture

### Game logic is independent of rendering
A creature is a game entity, not an ASCII character. The initial renderer may display symbols, but rendering must be replaceable later by a Dwarf Fortress-like graphical tileset or sprites without rewriting combat.

### Content is data-driven
Avoid one bespoke script per spell, creature or item when reusable components can express the behavior. Abilities should primarily compose Costs -> Targeting -> Effects -> Conditions -> Triggers -> Modifiers.

### Generic effect vocabulary
Support reusable operations such as damage, healing, movement, teleport, knockback, pull, status application/removal, terrain creation/transformation, summoning, resource/stat modification, projectiles, areas, chaining, delays, repeats, execution, battlefield-object creation/destruction and Command modification.

### Generic triggers
The architecture should be able to support triggers including OnCast, OnHit, OnKill, OnMove, OnDamaged, OnBlock, OnDodge, OnCrit, OnDeath, OnTurn, OnSummon, OnStatusApplied, OnTerrainEntered, OnResourceSpent, OnHeal, OnEncounterStart and OnEncounterComplete.

The eventual game is intended to support 500+ abilities, so ability #501 must not require architectural reinvention.

## Turn system

Combat is fully turn-based. There is never a real-time decision timer for the player. Nothing advances while the game is waiting for player input.

Actions consume simulation time. Example conceptual costs: Quickstep 40, dagger attack 65, bow shot 90, move 100, sword attack 100, Fireball 115, Phantom Blade cast 130, greatsword attack 140, Raise Skeleton 150, major ritual 200+.

After the player chooses an action, resolve scheduled actors/events until the player's next decision point, then stop. Show a readable upcoming-turn timeline. This system must support speed, haste, slow, weapon speed, casting speed and future time magic.

Combat presentation is a sequential rendering of events produced by the committed deterministic command. Normal, Fast and Instant are presentation speeds only: all modes share the same simulation outcome, and waiting for an animation never advances time or resolves another actor. Provide a visible skip control and prevent overlapping gameplay commands while the event sequence is playing. Keep bounded recent combat history and use concise floating feedback for important damage, healing, status, death, XP and level-up events.

Presentation data must obey the same fog-of-war rules as the battlefield. Hidden actors and targets, their positions and damage details must not leak through event text, feed history, animation patches or floating labels. An unseen attack on the player may use generic impact feedback.

Show roughly five to eight meaningful recent visible outcomes in the battle HUD and expose the larger encounter history only in a contextual, paged view. Store a bounded history of structured event records; omit routine scheduler/resource bookkeeping and do not reconstruct the feed from prose logs.

Kill progression awards full experience for a player kill or a player-owned summon kill, partial assist experience for meaningful player participation in another actor's kill, and no experience for unrelated deaths. Level rewards remain deterministic and data-driven; character growth profiles define any automatic attribute milestones.

Keep exactly eight configurable quickbar slots for learned active abilities and usable items. Persist stable ability/item IDs rather than inventory indices; an empty consumable slot remains associated with its item so replenished stock restores it. Passive abilities do not occupy action slots. Quickbar assignment is presentation/input convenience and must not create a second ability or item rule path.

## Battlefield

- Square grid with eight-directional movement.
- Standard encounter target approximately 25x18 tiles, but stage definitions may vary.
- Walls/blocked tiles, line of sight, fog of war, visible/explored distinction, pathfinding, ranged/melee/area targeting, battlefield objects, corpses, terrain states and hazards.
- Multi-tile creatures must be supported: 2x2, 3x3 and extensible footprints.
- Hordes of roughly 50–150+ creatures must be architecturally possible without requiring expensive global reasoning for every actor each turn.

## Resources

Resources are generic data objects rather than a fixed Mana-only system.

Baseline resources:
- Health: survival.
- Mana: slowly regenerating magical resource.
- Stamina: faster-regenerating resource used by movement and martial actions.
- Command: summon capacity.

Future content may introduce Blood, Souls, Rage, Faith, Heat, Momentum, Corruption, Charges, Corpses and other resources. Abilities may consume multiple resources.

## Attributes

Baseline attributes:
- Might
- Dexterity
- Vitality
- Intelligence
- Willpower
- Perception

Players do not repeatedly allocate routine +1 attribute points. Attributes emerge primarily from character identity, equipment, discipline/magic investment, artifacts, statuses and special progression. Meaningful decisions should center on abilities, disciplines, equipment and build interactions.

## Damage

Initial damage types:
- Slashing
- Piercing
- Blunt
- Fire
- Cold
- Lightning
- Poison
- Arcane
- Holy
- Shadow

Damage types are registry/data-driven and expandable. Creatures may have resistance, vulnerability or immunity.

## Status system

Statuses may stack when their definitions permit it. Initial examples include Bleeding, Burning, Wet, Frozen, Chilled, Poisoned, Stunned, Slowed, Hasted, Cursed, Regenerating, Invisible, Rooted and Silenced. Multiple statuses may coexist where logical.

## Environmental system

Initial terrain/state vocabulary includes Water, Wet, Ice, Fire, Blood, Poison, Vegetation, Smoke and Oil.

Interactions should be owned by reusable environment/status rules rather than exclusively by individual spells. Examples:
- Water + Cold -> Ice.
- Wet + Lightning -> enhanced/conductive Lightning interaction.
- Vegetation + Fire -> burning terrain.
- Oil + Fire -> ignition/explosion.
- Blood + Cold -> Frozen Blood.
- Corpses may become resources/targets for Necromancy.

## Characters

Characters provide starting identity and hidden content affinities, not permanent class restrictions. New profiles start with four simple classes: The Mundane (stable ID jim), The Archer (archer), The Apprentice (apprentice) and The Defender (defender). They begin with their defining basic weapon/ability and otherwise small builds. Only the Archer, Apprentice and Defender have starting content affinities; The Mundane uses global reward weights with no character-derived weighting. Advanced classes remain profile unlocks and preserve the IDs aldren, mara, brakka, orin and sylvi. Their display titles are The Spellblade, The Bloodletter, The Warrior, The Necromancer and The Ranger, respectively. A locked card shows a large ?, Unknown Character and its actual player-facing requirement, while hiding the title, normal portrait and silhouette. Unlocks persist and show a concise portrait, title and identity reveal.

Advanced unlock conditions are: The Spellblade (aldren), complete a stage while owning Sword and Arcane tagged content; The Bloodletter (mara), own Blood and Dagger tagged content together; The Warrior (brakka), complete a stage with a Greatsword equipped and Might 14 or higher; The Necromancer (orin), control at least five individual living Undead summons at once; The Ranger (sylvi), complete a stage while owning Bow and Nature tagged content. The Necromancer counts actual living player-owned summon entities, never capacity or historical summons. Conditions may be impossible in the current content pool. Keep an advanced class locked until legitimate content makes its authored condition achievable; do not substitute a temporary unrelated unlock. See [Advanced Character Scaling Review](ADVANCED_CHARACTER_SCALING_REVIEW.md) for unchanged profiles and starter comparisons.

The four baseline classes are:
- **The Mundane:** ordinary sword, simple ordinary combat and an otherwise open build.
- **The Archer:** basic bow and ranged projectile identity.
- **The Apprentice:** one basic Magic Missile and beginner Arcane identity.
- **The Defender:** shield equipment and Shield Bash, with shield/armor/defense/survivability affinities.

Affinity and build choices adjust hidden probability weights. They never restrict the global eligible pool. Repeatedly selected content tags can modestly influence later rewards. See [`CONTENT_FOUNDATION.md`](CONTENT_FOUNDATION.md) for the package, eligibility, weighting, exploration and save contracts.

The five advanced records retain their existing abilities, auras, resources, attributes, equipment and growth profiles. Their archetypal titles and authored unlock conditions are finalized above; do not rebalance these profiles without a separate user-led design pass.

Characters use a consistent static Treatment A portrait family: intentionally crude/charming, clean stick figures distinguished by readable weapons, equipment, pose and restrained thematic accents. The approved portraits are stored in assets/portraits; do not replace this direction with the comparison Treatment B.

## Martial disciplines

Initial framework:
1. Swordsmanship
2. Axes
3. Heavy Weapons
4. Polearms
5. Daggers
6. Archery
7. Crossbows
8. Unarmed
9. Defense
10. Mobility

Martial disciplines are first-class build systems. A completely nonmagical build must be capable of defeating eligible Stage-6 bosses and surviving a meaningful portion of an endless run.

## Magic schools

Common/naturally learnable schools:
1. Fire
2. Frost
3. Storm
4. Earth
5. Nature
6. Holy
7. Shadow

Specialized/discoverable schools:
9. Necromancy
10. Summoning
11. Spirit
12. Blood
13. Demonology

Future expansion can add Chronomancy, Void, Dream, Chaos, Flesh, Gravity and other schools.

Arcane is school-less magic: direct manipulation of magical energy, not a school that later branches into Fire, Blood, Time or another discipline. Magic Missile, Arcane Blast and Arcane Shield are examples of Arcane concepts. The `Arcane` damage/theme label may be used by abilities, but it does not designate a registered magical school or progression branch.

## Knowledge acquisition

Two broad forms of progression exist.

### Natural development
Known abilities reveal logical successors. Fireball may contribute toward Meteor. Swordsmanship reveals advanced sword techniques.

### Discovery
Unrelated, rare or forbidden knowledge must be found through spellbooks, shrines, events, bosses, NPCs, artifacts or secret conditions. Fireball must not spontaneously teach Demonology.

## Spellbooks

Spellbooks are identifiable loot with explicit immediate learning rules. Example:

The Lesser Key of Ash — Demonology — Rare
- Summon Imp
- Hellfire Pact
- Demonic Gateway

Books may unlock a school, teach abilities, provide choices or use other definition-driven rules. Pre-study previews show only the immediate grants or current choice options defined for that book. A learning result reports what was actually granted; it must not reveal downstream abilities that are only future possibilities.

## Ability webs

Progression is a graph rather than necessarily a tree. Abilities may require other abilities, school/discipline ranks, multiple prerequisites, character conditions, discovery flags, artifacts, resource thresholds or other extensible requirements.

Examples:
- Firebolt -> Fireball -> Greater Fireball -> Meteor, with Flame Wave branching from Fireball.
- Swordsmanship + Fire -> Flaming Blade.
- Necromancy + Frost -> Frozen Dead.
- Necromancy + Fire -> Corpse Explosion.
- Swordsmanship + Spirit/Arcane -> Phantom Blade-related development.

## v0.1 ability target

Target approximately 60–80 meaningful abilities/passives, roughly 72, emphasizing interconnected mechanics rather than filler.

Suggested allocation:
- ~24 martial abilities.
- ~6 Fire.
- ~6 Frost.
- ~6 Storm.
- ~5 Nature.
- ~5 Arcane.
- ~6 Holy/Shadow combined initially.
- ~8 Necromancy/Blood/Demonology rare/discovered abilities.
- ~6 hybrids.

Representative martial abilities: Lunge, Cleave, Parry, Riposte, Blade Dance, Crushing Blow, Wide Swing, Brace, Earthshaker, Quick Stab, Flurry, Backstab, Aimed Shot, Piercing Arrow, Volley, Guard, Shield Bash, Hold Ground, Quickstep, Dash, Evasive Footwork.

Representative magic: Firebolt, Fireball, Flame Wave, Combustion, Flame Ward, Meteor; Frostbolt, Ice Lance, Freeze, Frozen Ground, Ice Wall, Blizzard; Spark, Lightning Bolt, Chain Lightning, Static Field, Thunderstep, Stormcall; Entangling Roots, Thorn Burst, Regrowth, Overgrowth, Call Wolf; Arcane Bolt, Blink, Arcane Shield, Phantom Blade, Arcane Barrage; Raise Skeleton, Corpse Explosion, Life Drain, Blood Lance, Blood Covenant, Blood Pool, Summon Imp, Hellfire Pact.

Representative hybrids: Flaming Blade, Frozen Dead, Storm Arrow, Bloodletting Strike, Arcane Riposte, Thorn Armor.

## Phantom Blade architecture benchmark

Phantom Blade is an architecture test. It summons an ethereal sword associated with its owner. It follows to within one or two tiles when idle and attacks valid nearby enemies through its own scheduled timeline turns. Targeting respects its authored attack range and line of sight, favors enemies near the owner, and uses shared movement/pathfinding to return when separated. Its follow, target and attack behavior belongs in reusable Core companion mechanics rather than a monolithic summon exception.

## Summoning and Command

Summons occupy real battlefield locations unless explicitly defined otherwise. Each summon has a Command cost; examples: Skeleton 1, Imp 1, Wolf 2, Wraith 3, Knight 4, Greater Demon 8. Living player-owned summons persist across Stage and Map transitions with identity, ownership, health, statuses, remaining durations and timeline state. They are placed on legal unoccupied tiles near the owner; deterministic saveable deferred placement handles temporary lack of space. Dead, expired or dismissed summons never transfer, and transition placement does not heal them.

Command is itself modifiable by spells, artifacts, equipment and character traits. Example: Blood Covenant: -20 Maximum Health, +1 Command. There is no universal hard-coded summon-count maximum.

## Equipment

Slots:
- Weapon
- Offhand
- Head
- Body
- Hands
- Feet
- Ring 1
- Ring 2
- Amulet

Two-handed weapons may occupy Weapon + Offhand capacity. General inventory capacity is 30 items.

Weapon types must have mechanical identity, not merely different numbers. Examples: dagger fast/cheap; sword flexible; greatsword slow/cleaving; spear reach; axe chopping/high impact; bow ranged; crossbow slow/high damage; staff magical specialization; wand faster magical attacks.

## Consumables

Support potions, scrolls, bombs, throwing items and temporary enchantments. Scrolls can allow a character to cast a specific spell without permanently knowing its school.

## Artifacts

Artifacts are persistent run modifiers and do not consume a limited artifact-slot pool. Rarity limits accumulation. They range from modest to transformative.

Examples:
- Copper Hare: +5% movement speed.
- Iron Candle: improved sight while below half Health.
- Heart of Command: -20 maximum Health, +1 Command.
- Mirror of Embers: every third Fire spell repeats at reduced power.
- Ossuary Bell: every tenth eligible living kill creates a temporary Skeleton.
- Crimson Crown: substantially modifies Blood/healing rules.

Lucky runs may accumulate several compatible artifacts and become unusually powerful.

## Loot weighting

Rewards use global eligibility and tag-driven character/build weight adjustments, but weighting is never exclusivity. The Mundane has no character adjustment. A character can discover off-archetype content and redirect the run.

## Encounter generation

Stage definitions control visual theme, terrain, enemy factions, encounter size, hazards, objective pool, rewards, special objects and possible events.

Objective framework includes Eliminate, Boss, Survive, Defend, Reach Exit, Destroy Targets, Interrupt Ritual and Rescue. Objectives are selected only when contextually appropriate for the generated stage.

## Initial region: The Fractured March

Potential locations:
- Ruined Village — undead/raiders/burning structures.
- Old Graveyard — undead/corpses/necromantic events.
- Goblin Warrens — hordes/traps.
- Flooded Ruins — Water/Wet/Lightning interactions.
- Thornwood — vegetation/beasts/Nature.
- Abandoned Keep — armor/chokepoints.
- Ash Shrine — possible Demonology discovery.
- Forgotten Crypt — Necromancy/rare rewards.

## Factions and enemies

Initial factions include Undead, Goblinoids, Bandits, Wild Beasts and Demons. Relationships are data-defined; hostile factions can fight each other.

Initial enemy target approximately 18:
- Skeleton
- Skeleton Archer
- Zombie
- Ghoul
- Necromancer
- Goblin
- Goblin Archer
- Goblin Shaman
- Hobgoblin
- Bandit
- Bandit Archer
- Bandit Brute
- Wolf
- Dire Wolf
- Spider
- Imp
- Hellhound
- Lesser Demon

Enemies should differ mechanically rather than being stat reskins.

## Bosses

Initial bosses:

### Grave Tyrant
Large undead boss that raises corpses and manipulates death terrain.

### Thornmother
Large Nature creature that creates vegetation, roots targets and summons beasts/plants.

### Ashbound Herald
Large demon using Fire, summoned imps and battlefield transformation.

Bosses obey normal mechanics wherever logical. Immunities are specific, not a global boss exemption from interesting systems.

## Run structure

A run is an endless sequence of Maps. Each Map is one coherent region with exactly six Stages. Map number/depth and Stage within the current Map are separate state. Stage 6 is a boss encounter selected from enabled content definitions; completing it completes the current Map, resolves its rewards, generates/reveals one next Map, and lets the same hero continue. There is no final Map and reaching a particular Map/Stage does not produce victory. Hero death ends the run and produces a summary.

Map themes, stage templates, enemy pools, encounter composition, exploration loot and bosses are data-driven and may be contributed by eligible enabled packages. Map 1 remains approachable with constrained enemy/objective generation, while later Maps increase both enemy numbers/stats and the eligibility of more dangerous compositions. Depth also increases access to higher-rarity rewards and makes rare bosses more likely without guaranteeing an upgrade or a rare encounter. See [`ENDLESS_MAP_PROGRESSION.md`](ENDLESS_MAP_PROGRESSION.md) for the initial formulas, data fields and generation boundaries.

## Post-encounter behavior

Completing a Stage objective does not immediately transition. The player may continue exploring, looting, consuming corpses, interacting with shrines or manipulating terrain before choosing to continue. Stages 1–5 continue within the current Map. After Stage 6, the map-completion/reward flow reveals the next Map; entering it is a map transition inside the active run, not new-run initialization. Entering any next Stage after completion restores `max(1, floor(MaxHealth × 0.05))` Health, capped at maximum; this includes the new Map's Stage 1. Initial run creation and save/resume do not trigger the heal. Map entry does not refill Mana or Stamina.

## Death and persistent progression

Death ends the run and carried equipment, artifacts and run power are lost. Do not use permanent percentage-stat grinding. Persistent progression primarily records Codex discoveries, characters, knowledge/information, possible starting options and achievements/challenges. Discovering a secret school records it but does not automatically grant it next run.

## Android UX contract

Landscape first. The supplied UI mockup is a visual target, adapted intelligently for phone space.

Windows and Android are both supported. Android landscape is the primary mobile presentation; Windows remains a first-class desktop build.

During combat the battlefield receives maximum area. Persist essentials such as Health, Mana, Stamina, relevant special resource, Command when relevant, action bar, timeline and important statuses. Full character stats, enemy details, extended effects and logs should be contextual/collapsible. Windows desktop keeps exactly three persistent lower panels: World Map, Character / Abilities, and Inventory / Equipment. There is no persistent Spellbook / Discovery panel; spellbooks remain available through Inventory tabs and dedicated knowledge interfaces. The World Map is the player's actual journey: retain completed/visited Maps, highlight the current Map, and represent the one unrevealed next Map with a circular `?`. Do not show a future theme, boss, stage layout or encounter before the current Map is complete. On completion, replace `?` with the revealed Map; do not show several future Maps. Render the trail as a winding chain of circular nodes and page/scroll through long histories without shrinking nodes into unreadability. Android landscape uses a contextual lower dock with the same three sections, where one section expands at a time and the other sections remain available as compact headers. Collapse the Android dock to restore battlefield space. On both platforms the ability web may open as a dedicated large subview. Codex, settings, map reveal, resume confirmation and run-summary flows may use focused overlays.

Hover descriptions use a shared measured wrapping layout with a bounded maximum width and content-driven height. Place the complete tooltip inside the viewport. Combat action names may wrap to two centered lines before ellipsis; keep icons, resource/time costs and item counts visible in aligned, equal-height slots. Panel headings, separators, wrapped copy and following content participate in measured vertical flow: give rules clear padding from glyphs and move later content down when earlier text wraps.

The Character / Abilities category list is data-driven but character-relevant: show a category when the current character has a learned, unlocked, invested or otherwise meaningfully available ability in it. Keep the full global category registry for future acquisition; newly relevant categories appear from run state.

Equipment selection filters the carried gear grid by the selected equipment slot using the same compatibility rules used by equip actions. Inspection exposes actual authored combat values such as weapon damage/type/time/range/stamina, armor, resistances and modifiers. Never fabricate missing stats.

Touch model:
- Tap: select/move/target.
- Long press: inspect.
- Tap ability then target: cast/use.
- Drag/scroll: pan where appropriate.

Controls must be comfortably phone-usable.

Mouse and touchscreen are first-class input methods. Platform input must resolve into the same explicit game commands. No required action or information may depend only on hover, a secondary mouse button, wheel input or a keyboard shortcut. Touch must provide a way to inspect, cancel targeting and reach every required screen. Keep touch targets comfortably sized and avoid overlapping hit regions.

Use Godot user-data paths for saves on both platforms. Respect Android safe areas and landscape aspect ratios while keeping the battlefield prominent. Future gameplay and UI changes must be checked on Windows and Android at desktop, wide-phone and smaller effective resolutions.

## Visual direction

Follow the supplied reference image's overall language: dark tactical presentation, crisp panels, strong hierarchy, high contrast, readable symbolic battlefield, restrained neon magical effects, clear targeting, lightweight particles and useful combat feedback.

The production battle layout keeps character resources at left, the battlefield dominant in the center, and turn order plus selected-entity inspection at right. Its action strip contains fixed Move, Weapon, Wait and End Turn actions around exactly eight configurable slots for learned active abilities and usable carried items. Display resource and time costs on actions. Keep playback speed controls off the ordinary HUD and show the movement D-pad only on Android. Use three whole-screen visual comparison passes at 1920×1080 or larger for major UI reconstruction; log findings and fixes in `docs/PROMPT6_VISUAL_QA.md` and any follow-up reconstruction record.

Avoid debug-looking UI, programmer labels, raw IDs, exposed calculations, giant text walls, inconsistent spacing and temporary default Godot controls presented as final UI.

## Save behavior

Application interruption is expected on desktop and Android. Save enough state to resume the active run exactly, including run seed and RNG state, current/pending map data, visited maps, within-map Stage, encounter plans, battlefield, entities, resources, statuses, inventory, equipment, artifacts/relics, abilities/state, summons, timeline, weighting and statistics. Safe/versioned writes should recover from interrupted replacement where practical. The title screen must offer an explicit Resume Run if an active run exists and require a deliberate confirmation before replacing it with a new run. Hero death clears active-run resumability, preserves permanent profile progression and stores a useful run summary.

## Determinism and automated simulation

Given seed + game state + player actions, the simulation should be reproducible. Build a headless simulation/testing path capable of validating large numbers of generated encounters, hordes, turns, terrain interactions, reward generations, content references, stage/objective validity, boss spawning and save/reload equivalence.

## Definition of playable

Compilation, passing unit tests or opening a scene are not sufficient. A human must be able to:

launch -> select character -> enter Map 1 Stage 1 -> navigate battlefield -> fight -> use abilities -> gain rewards -> equip loot -> explore -> complete Stages -> fight the Stage-6 boss -> reveal/enter another Map -> resume the same active run -> die -> review the run summary -> start another run.

## Three-prompt production rule

There are exactly three major implementation phases before judging the baseline product:

1. Prompt 1 — Playable Game: complete vertical skeleton, not merely foundations.
2. Prompt 2 — Platform Acceptance: Android landscape and touch compatibility, Windows preservation, lifecycle/save handling, build pipeline, APK creation and cross-platform verification.
3. Prompt 3 — Buildcraft & Content: expand the working game into the intended ability/school/discipline/artifact/environment ecosystem, then balance and polish it for both supported platforms.

Later prompts may expand content, but must preserve the shared deterministic simulation and continue checking both platforms.

## Playtest interaction regressions

- Each reward resolution accepts and saves exactly one selected reward. Other choices become unavailable after the claim.
- Spellbook learning is defined per book and supports teaching all listed abilities, selecting an exact number, or revealing a school. Inspectable book contents remain in the Codex after study or consumption.
- The same target action selected again cancels targeting; another action replaces the current target mode. Cancel, Escape and Android Back use the same target-cancellation route before closing broader UI.
- Clicking a distant battlefield tile uses a deterministic lowest-time-cost valid path that respects walls, occupancy, creature footprint, legal movement directions and fog/knowledge rules. Movement cost is sourced from the same per-step action cost as the movement action.
- Selecting a targeted attack shows a restrained battlefield range preview from the authoritative targeting query also used for action validation. It distinguishes range from visible legal targets and never exposes hidden tiles or enemies. The preview clears on cancel, action resolution, replacement action or turn/state transition.
- Hover descriptions and combat action labels use measured word wrapping; tooltip width stays bounded, tooltip height grows with wrapped content, and the full tooltip remains in the viewport.
- Panel separators follow their measured headers/content with visible padding. Wrapped descriptions push later content down rather than colliding with dividers, metadata or neighboring sections.
- Persistent World Map entries come from the saved visited-map history and current Map/Stage. While a Map is in progress, exactly one circular `?` represents the unknown next Map; no later theme, boss, Stage or encounter is visible. Completing Stage 6 reveals only the next Map and extends the trail. Paging through old visits never exposes future content.
- Declining a Stage transition dismisses its prompt. Ordinary movement must not reopen that same prompt after every move, and the explicit continue/reveal control must remain available.
- Every future implementation prompt begins by reviewing [`PLANNED_IMPLEMENTATIONS.md`](../PLANNED_IMPLEMENTATIONS.md). For each blocked idea, check dependencies; mark satisfied entries ready, implement/test only those within the current scope, then record implementation references. Leave unresolved and unrelated entries blocked.
- Content packages can inject Map themes, Stage templates, enemy pools and Stage-6 bosses through definitions. Do not add package-specific branches to central generation when existing eligibility, tags, prerequisites and weights can express the behavior.
- Command communicates occupied summon capacity. It is not spent like Mana; failure feedback identifies the resource that blocked the action or the full Command capacity.
- Battlefield, timeline and inspection use the same simulation-owned entity presentation, including canonical creature glyphs.
- Every playable ability must have a non-empty authored description in data. Content validation checks these descriptions and spellbook references.
