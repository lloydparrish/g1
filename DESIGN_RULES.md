# Project Arcanist design rules

The full authoritative contract is in [`docs/PROJECT_ARCANIST_DESIGN_CONTRACT.md`](docs/PROJECT_ARCANIST_DESIGN_CONTRACT.md). Preserve these rules whenever content or systems are expanded.

## Authority and simulation

- The simulation owns all game state. The renderer displays it; input becomes explicit game commands.
- The simulation must run headlessly and reproduce the same result from the same seed, saved state and player commands.
- Waiting for player input never advances game time. Resolve scheduled actors after each committed player action, then stop at the player's next decision.
- Save enough state to resume the current encounter, including the random generator state. Version serialized data and test round trips.
- Combat presentation is a renderer-only playback of events emitted by committed simulation commands. Normal, Fast and Instant playback must produce identical authoritative state; playback never schedules actors or advances time on its own.
- Keep combat event records bounded and visibility-filtered. Fog of war applies to the event feed and animation patches as well as the battlefield; never reveal hidden actors, targets or damage details.
- Keep the compact Recent Events panel on the battle HUD and put the longer, paged encounter history in a contextual overlay. Store only meaningful visible structured events, with a sensible cap; never parse presentation text back into game state.
- Award full kill experience only for player or player-owned summon kills, partial assist experience for meaningful player participation, and no experience for unrelated kills. Keep level growth data-driven per character.
- Keep exactly eight configurable stable-ID quickbar slots for active abilities and usable items. Reassignment and save/resume preserve identity; do not key an item slot to a transient inventory index.

## Content and rules

- Add game content as definitions composed from reusable costs, targeting, effects, conditions, triggers and modifiers. Avoid a script per spell, creature or item.
- Resources and damage types are registries. Do not assume Mana or a closed set of damage types is the whole system.
- Status and environmental interactions belong to reusable rules. Spells may cause them but must not own the only implementation of a world interaction.
- Factions and creature footprints determine hostility and occupancy. Large bosses use ordinary movement, targeting and damage rules where possible.
- Natural ability progression follows explicit prerequisites. Rare knowledge comes from discoveries such as spellbooks and shrines, never from unrelated automatic progression.
- Summons occupy real battlefield cells when appropriate and consume their defined Command. Do not add a global summon-count cap.
- Living player-owned summons carry across every Stage and Map transition with their stable identity, ownership, Health, statuses, remaining durations and timeline state. Place them on legal, unoccupied cells near the player; save any summons that must wait for a free cell. Never resurrect dead/expired summons or heal summons on transition.
- Core companion behavior uses ordinary scheduled actions, targeting, line of sight, movement and pathfinding. Owner-following companions stay within one or two tiles when idle, favor nearby hostiles around their owner, and do not attack beyond their authored range.
- Artifacts are persistent run modifiers and do not consume a fixed artifact-slot allowance.
- Equipment supports the defined nine slots; two-handed weapons reserve both hand slots. Keep ordinary inventory at 30 items.
- Keep ordinary inventory as a compact 6×5 item grid with selected-item details and contextual actions; equipment belongs in the same inventory view. Do not reserve battlefield space for a closed pack.
- The ability model is an extensible prerequisite graph. A viewport, screen size or current content count must never impose a logical node limit; the web UI must pan/scroll to reach every revealed branch.
- Keep natural progression distinct from discovery. Schoolbooks and other authored sources record discovery flags and show their contents before study; unrelated knowledge remains hidden until found.
- Keep progression data-driven and extensible: prerequisites are graph relationships and hidden branches stay hidden until discovered. The interface must pan and zoom through the graph instead of limiting its size.
- Treat martial disciplines as complete build paths with active techniques and meaningful passives. A viable build must not require magic.
- New profiles start with The Mundane, The Archer, The Apprentice and The Defender as intentionally weak, mostly empty builds. The Mundane has zero character-driven reward weighting; other starter affinities are hidden probability preferences, never class restrictions.
- Arcane is school-less direct use of magical energy, not a branch that evolves into other schools.
- Use stable IDs for definitions, profiles and save references. Moving official package content into Core preserves its IDs; package definitions use the same shape as Core. Read [`docs/CONTENT_FOUNDATION.md`](docs/CONTENT_FOUNDATION.md) before modifying package loading, prerequisites, weighting, exploration loot, unlocks or related saves.
- Runs continue without a final Map: each Map contains six Stages, Stage 6 has an eligible content-defined boss, and successful map completion reveals the next deterministic Map. Only hero death ends a run. Map number is separate from Stage number and has no gameplay cap. Read [`docs/ENDLESS_MAP_PROGRESSION.md`](docs/ENDLESS_MAP_PROGRESSION.md) before changing maps, stages, bosses, run persistence, rewards or the World Map.
- The World Map records all visited maps, highlights the current Map, and shows only one unknown `?` destination until the current map is completed. Long trails page/scroll while keeping nodes readable. Future theme, boss and encounter details remain hidden until map reveal.
- Stage transitions preserve the same active run and carry hero health/resources, inventory/equipment, build, artifacts/relics, weighting and statistics. After each completed Stage, entering the next Stage restores `max(1, floor(MaxHealth × 0.05))` Health, capped at maximum, including Stage 6 to the next Map's Stage 1. Run creation and save/resume do not trigger this recovery; Map entry does not refill Mana or Stamina. Active runs autosave/resume; hero death clears resumability and preserves a permanent run summary/unlocks.
- Every future implementation prompt must begin by reviewing [`PLANNED_IMPLEMENTATIONS.md`](PLANNED_IMPLEMENTATIONS.md). Recheck every `BLOCKED` dependency; if satisfied, mark `READY`, then implement only if in scope, test it, and mark `IMPLEMENTED` with references. Leave still-blocked ideas unchanged and do not implement unrelated entries.
- Rewards, prerequisites and evolutions are data-driven simulation rules. Tags allow multi-theme hybrid content. Character/build tags adjust probabilities without eliminating off-build choices. Skill-book learning is run-specific; enemy drops are occasional and marked with a star.
- Advanced classes keep stable IDs aldren, mara, brakka, orin and sylvi while displaying The Spellblade, The Bloodletter, The Warrior, The Necromancer and The Ranger. Their current unlocks require, respectively: a completed stage with owned Sword + Arcane tags; owned Blood + Dagger tags; a completed stage with Greatsword equipped and Might at least 14; five individual living player-controlled Undead summons simultaneously; a completed stage with owned Bow + Nature tags. An authored unlock may await future content; never substitute an unrelated temporary condition. Locked cards show a large ?, Unknown Character and the actual requirement, hiding name and portrait; unlocked characters show a concise reveal.
- Use static Treatment A portraits across all nine current classes: crude/charming clean stick figures with readable equipment and restrained accents. Treatment B is not the production direction.
- Do not invent major classes, characters, spell schools, signature abilities, currencies, core combat systems, expansion themes, lore or large progression families to fill gaps. Ask the user when a substantial game-design decision is not already documented; choose minor implementation and balance details autonomously.

## Player-facing design

- Windows and Android are supported platforms; landscape Android is the primary mobile presentation.
- Touch and mouse are first-class. Both resolve through the same UI actions and explicit simulation commands.
- No required action or information may depend only on hover, right-click, middle-click, wheel input or keyboard. Make inspection available by touch (for example, long press or an Inspect control).
- Keep required touch targets comfortably tappable and separated enough to avoid accidental input. A visible cancel action must accompany an active targeting state.
- Respect Android safe areas and modern landscape aspect ratios without wasting battlefield space. Preserve safe-area behavior in future UI changes.
- Store data in Godot user-data paths such as `user://`; do not use writable project directories, drive letters or machine-specific paths for saves.
- Test every future production feature with Windows mouse and Android-style touch, including representative desktop, wide-phone and small effective resolutions.
- Give the battlefield the greatest practical space. Keep health/resources, available actions, turn order and important statuses visible; put extended inspection and build screens in contextual overlays.
- Keep text, targets and controls readable and comfortably tappable. Do not expose internal IDs, calculations, test controls, raw data, temporary copy or engine defaults in normal play.
- Completing an objective does not force a transition. Let the player explore and collect rewards, then choose the next location.
- Use [`docs/Project_Arcanist_UI_Reference.png`](docs/Project_Arcanist_UI_Reference.png) as the production visual direction: resource/status information, a large battlefield, turn order, contextual inspection, action costs, and compact inventory/build panels.
- Make inventory and build screens contextual. Opening them may reorganize available space; closing them should return the battlefield to its largest practical layout.
- Keep the production battle composition in three bands: compact character/resources at left, the largest practical battlefield in the center, and turn order plus contextual inspection at right. Tapping a visible enemy selects it and shows its details in the right panel.
- Put routine management in one lower dock with four sections: World Map, Character / Abilities, Inventory / Equipment, and Spellbook / Discovery. Expand at most one section at a time; keep the other sections available as compact headers/summaries and collapse the dock to restore battlefield height.
- Keep the ability web available as a dedicated large subview from Character / Abilities. Do not restore duplicate full-screen map or inventory interfaces beside the lower dock.
- The battle action strip has fixed Move, Weapon, Wait, and End Turn actions plus exactly eight configurable slots between Weapon and Wait. Slots accept only learned active abilities and usable carried items. Show each action's resource and time cost; keep passive, unknown, and unassigned actions out of the configured slots.
- Keep Normal/Fast/Instant playback options out of the ordinary battle HUD. Keep the movement D-pad Android-only; desktop movement uses the battlefield and standard desktop input.
- For major UI work, inspect the canonical reference beside the production screen at 1920×1080 or larger in three logged visual passes. Record concrete layout defects and their fixes in `docs/PROMPT6_VISUAL_QA.md`.

## Production interaction contracts

- A reward screen permits one choice. Persist the chosen reward and resolved state; disable every alternative after claiming it.
- Spellbooks declare their learning mode and effects in content data: teach all, choose an exact number, or unlock a school. Show the offered contents before study, consume books only as their definition specifies, and retain the studied record in the Codex.
- Re-selecting the active target action cancels targeting. Selecting a different action switches modes; the visible Cancel control, Escape and Android Back follow the same cancellation path.
- Command is occupied summon capacity, not a spendable cost. Report the specific insufficient resource or full capacity when an action cannot be used.
- Use one simulation-owned entity presentation source for symbols and names shown on the battlefield, timeline and inspection views.
- Show each committed player action and the scheduled responses in a readable sequential presentation. Normal, Fast and Instant are display speeds only; simulation resolution remains deterministic and immediate at command commit. Provide a visible skip control and block overlapping gameplay input during playback.
- Present concise floating combat feedback and a recent-event feed, with fuller event history available contextually where practical. Keep the active actor/target and target cancellation clear on touch.
- Use the eight-slot action bar as a stable, configurable quickbar for learned active abilities and usable inventory items. Empty stacks keep their item identity so replenishment restores the action; passive abilities do not occupy active slots.
- Grant full kill XP to the player or player-owned summons, assist XP for meaningful player contribution to another kill, and no XP for unrelated deaths. Level-up attribute growth follows a character data profile, alongside defined health and ability-point gains.
- Every playable ability needs an authored player-facing description in content data. Validate descriptions and spellbook references with the content registry.

## Opening difficulty and progression pacing

- Treat the first encounters as the run's on-ramp. Keep early enemy counts, enemy tiers and simultaneous complications inside stage-aware bands so players have room to learn combat and make an initial build choice.
- Escalate encounter count and composition with run stage. Preserve tactical enemy turns and dangerous decisions; do not flatten difficulty by disabling AI, removing costs or granting automatic invulnerability.
- Keep stage clear rewards and ordinary combat experience deterministic. Use seeded encounter batches to flag pathological openings, then inspect representative combat rather than balancing solely to an automated player.
- Keep progression metadata data-driven: ability links, AND/OR prerequisites, school and discipline ranks, character/resource/artifact conditions and discovery flags belong in definitions and shared progression rules, never per-node UI exceptions.

## Verification bar

- A playable loop connects selection, multiple Maps of six Stages, combat, rewards, exploration, a Stage-6 boss, map reveal/entry, save/resume, and death with a run summary. Reaching a Stage 6 or any map number is not victory.
- Cover deterministic rules, save/resume, content references, AI/factions, objectives, rewards, equipment and summon behavior with headless checks; exercise a representative production-path playthrough and death.
- Launch the real game, inspect screenshots at desktop and phone landscape sizes, and fix visible layout or readability defects.
- Mark environment/device or platform checks as pending when they have not been performed. A simulator or headless test does not count as native Android acceptance.
- Keep generated artifacts in predictable current-build paths, preserve named releases and needed QA evidence, and remove only stale generated outputs safe to regenerate. See [`docs/README_FOR_CODEX.md`](docs/README_FOR_CODEX.md).
