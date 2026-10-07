# Content Foundation

This document defines the content architecture and progression rules introduced for the content-development phase. Read it and the [design contract](PROJECT_ARCANIST_DESIGN_CONTRACT.md) before changing content, saves, rewards, character selection or progression. The design contract remains authoritative; this document records its content-system details.

## Content packages and stable identity

Core and packaged definitions use the same definition shape and stable content IDs. `data/core_manifest.json` identifies Core. A package manifest declares its stable package ID, display name, semantic version, kind, dependencies, content file and asset paths. Definitions are data-driven and currently resolve against existing game mechanics. The registry loads Core first, then enabled packages in deterministic dependency-first order with stable ID tie-breaking. A disabled package contributes no definitions. Its shared content catalog already accepts definition sections for characters, abilities, passives, equipment/items, relics/artifacts, enemies/bosses, maps, stages, events, evolutions, unlocks, visual-asset metadata and tags; records for future gameplay families remain inert until a runtime feature consumes them. Missing dependencies, cycles, malformed manifests, duplicate content IDs, unknown tags and missing assets are validation errors intended for development diagnostics.

Package identity records provenance and version; it does not become part of an item's stable content ID. Save references use content IDs, so moving a definition from an official package into Core preserves its identity. To promote a package: copy its definitions/assets into their Core locations, retain every stable content ID, update the Core manifest and references, verify dependency and save migration behavior, then remove the promoted package from the selectable package list. Do not leave two enabled copies of the same definition. Keep a compatibility alias/migration only when an old ID truly must change; physical source movement alone never justifies an ID change.

Official development packages and community mods are separate package kinds and are independently enableable. The player-facing Content / Mods view shows package names and enabled state without exposing versions, raw IDs or development diagnostics. Community packages currently have a data-only boundary: existing effects and mechanics can be composed in definitions. Do not load arbitrary executable content. If novel mechanics later require scripting, add a controlled, versioned game API at the simulation/content-action boundary, validate all script requests as ordinary simulation commands, and keep scripts away from UI-owned state, filesystem access and unrestricted engine APIs. No scripting runtime or community SDK exists yet.

## Tags, eligibility and weights

Content definitions may carry multiple canonical tags. Tags describe concepts and relationships; a definition can be both Bow and Blood, for example. A character's affinity map and a run's selected-tag counts adjust the weights of otherwise eligible definitions. Selecting content can modestly increase the chance of related future choices. These values remain hidden in ordinary play, use conservative adjustments, and never remove an eligible off-build choice. The Mundane's character affinity map is empty: wielding a sword does not create Sword or Physical reward bias. All characters retain the global content pool.

Prerequisites are data conditions evaluated by shared simulation rules, not widgets. Supported condition families include build tags (one or several), currently owned tags, ability, item/equipment, weapon, stat thresholds, completed stage, simultaneously controlled summon counts, relic/artifact, character, package, progression level, school/discipline, discoveries and resources. all, any and not composition allows future packages to express combined requirements without assigning one exclusive category to an ability. Build-tag counts drive future reward weights; owned-tag checks inspect current abilities, carried/equipped content, weapons and artifacts. Package availability and other normal content eligibility checks still apply.

Standalone conditional content and true evolutions are separate supported models. Standalone content becomes eligible when its prerequisites are fulfilled. An evolution names the base ability, required ability level/state and additional conditions; performing it replaces/transforms run ability state while retaining the evolution's stable identity. Run abilities and evolution state serialize with the run. Do not add a speculative evolution tree in the foundation phase.

## Characters and profile progression

Fresh profiles unlock exactly The Mundane (`jim`, retained for save compatibility), The Archer (`archer`), The Apprentice (`apprentice`) and The Defender (`defender`). The simple starters carry only their defining weapon/ability. The Mundane receives no inherent content weighting. The Archer favors Bow/Ranged/Projectile, the Apprentice favors Magic/Arcane, and the Defender favors Shield/Armor/Defense/Health/Survivability tags. These are probability preferences, not class restrictions.

Existing advanced characters remain in content and are profile unlocks. A locked selection card displays a large ?, “Unknown Character” and the authored requirement, but never the character’s name or normal portrait/silhouette. Unlocks persist in the profile. On unlock, present the character’s static portrait, class title and concise identity. Stable IDs remain aldren, mara, brakka, orin and sylvi; their player-facing titles are The Spellblade, The Bloodletter, The Warrior, The Necromancer and The Ranger, respectively. The current nine portraits use Treatment A: intentionally crude/charming, clean stick figures, with simple equipment silhouettes and restrained accents. Their assets are in assets/portraits/.

Advanced character requirements use the shared prerequisite evaluator and may depend on current owned content tags, stage completion, equipped weapons, attributes or live entity state. The Spellblade (aldren) requires a completed stage while owning Sword and Arcane tagged content. The Bloodletter (mara) requires Blood and Dagger tagged content together. The Warrior (brakka) requires a completed stage with a Greatsword equipped and Might 14 or higher. The Necromancer (orin) requires five individual living Undead summons owned by the player at the same time; Command capacity or historical summons do not count. The Ranger (sylvi) requires a completed stage while owning Bow and Nature tagged content. Player-facing requirement copy is authored separately from these internal expressions.

An authored advanced-character requirement may be impossible in the current content pool. Keep the character locked until legitimate content/mechanics make the existing condition achievable; do not replace it with a temporary or unrelated achievement. This lets a future package make an existing condition achievable without rewriting the character definition. In the current Core pool, Sword + Arcane, Greatsword + Might progression, and the Blood-tagged Crimson Crown artifact plus Dagger can satisfy their respective requirements. The Ranger's Nature requirement has no currently obtainable Nature-tagged reward or skill book. Starting-class Command capacity is 1; Heart of Command is the only current capacity increase (+1), so five simultaneous player-controlled Undead summons remain unavailable to starting-class runs. Keep the Ranger and Necromancer locked until their existing conditions can be met legitimately.

Arcane means school-less direct use of magical energy. It is not a magical school that evolves into Fire, Blood, Time or other disciplines. The existing Arcane damage/theme label may identify an effect; it does not establish a progression school.

Learning from a skill book modifies only the active run. It never teaches a permanent profile ability. A new run clears those temporary choices through the normal run reset.

## Rewards and exploration

Stage completion produces three choices drawn through global eligibility, prerequisites, enabled package availability, character affinities and selected build tags. A character may receive off-build options; three matching options are never guaranteed. Weights remain internal to normal player UI.

Stage definitions specify an exploration-loot range and types; a stage may explicitly specify zero rewards, while another may contain several. Chests roll their contents only when opened, using the central eligible weighted reward pool where applicable. Exploration objects can include chests, run-specific skill books and items. Enemy deaths have a conservative chance to drop meaningful loot; the drop is stored at its world location and visibly marked with a star so it is not missed.

The player may decline a stage transition and continue moving without the same completion choice being forced after every action. The transition can still be deliberately initiated later from the existing stage-exit/continue path.

## Validation and save stability

Before accepting definitions, validation reports duplicate stable IDs, malformed definitions and manifests, absent package dependencies, dependency cycles, unknown tags, invalid prerequisite references and broken asset references where the path can be checked. Diagnostics belong in development output, not gameplay UI.

Persist profile unlock IDs and run content IDs, not display names or file locations. Preserve the historical `jim` character ID while showing The Mundane. Package-to-Core movement keeps IDs. Add explicit migrations for any unavoidable data-shape/ID change, and cover old saves with automated tests.

## Art and UI boundary

Characters use static portrait resources referenced by data. Treatment A is the approved visual direction: crude/charming, clean stick figures with readable equipment, consistent across all nine current classes. Portraits are static. UI displays content package state, requirements and authored reveal copy; the simulation owns package loading, unlocks, prerequisites, weights and reward generation.

See [Content Foundation Visual QA](CONTENT_FOUNDATION_VISUAL_QA.md) for rendered screen captures and manual inspection notes. See [Advanced Character Scaling Review](ADVANCED_CHARACTER_SCALING_REVIEW.md) for the unchanged advanced build profiles compared with their starter archetypes.

## Build-output policy

Keep only the current useful development/test build at `build/windows/current/ProjectArcanist.exe` and `build/android/current/ProjectArcanist.apk`, explicitly designated release artifacts, and QA images still needed for current verification or cited by permanent QA documents. Prefer these predictable output locations; do not create permanent timestamped executable copies. Remove stale redundant generated builds only after checking that they are not running, are not documented/published releases, and can be regenerated. Never remove user-authored source assets, canonical fixtures, saves or design documents as build cleanup.

## Major design decisions

Do not invent major classes, characters, spell schools, signature abilities, currencies, combat systems, expansion themes, large content families, lore or progression systems to fill implementation gaps. Consult the user when a substantial design choice is genuinely needed and not already established by project documentation. Engineering details and modest initial balance constants can be chosen autonomously. Swordplay, Archery, Arcana and Defense packages are future content work; this foundation does not create their content.
