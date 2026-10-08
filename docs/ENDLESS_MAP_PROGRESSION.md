# Endless Map Progression

This document is the canonical implementation contract for the endless run loop. Read it with [`PROJECT_ARCANIST_DESIGN_CONTRACT.md`](PROJECT_ARCANIST_DESIGN_CONTRACT.md), [`CONTENT_FOUNDATION.md`](CONTENT_FOUNDATION.md) and the [`Codex reference bundle`](README_FOR_CODEX.md) before changing maps, stages, bosses, run persistence, rewards or the world map.

## Run, Map and Stage

- A run begins with Map 1, Stage 1. A Map is one coherent six-stage region; a Stage is one encounter within that Map.
- Stages 1–5 use the generated map's stored stage-template and encounter plans. Stage 6 always has a boss selected from the enabled, eligible boss definitions.
- Completing Stage 6 completes the current Map, presents its completion/reward state, generates and reveals exactly one next Map, and lets the player enter it. A map transition stays in the same run and never invokes new-run initialization.
- Map numbers and long counters are nonnegative decimal strings where machine-sized integers would impose an artificial progression cap. Stage index is a separate 0–5 value. There is no final Map or reach-a-depth victory condition. Hero death ends the run.
- A normal Core boss is selected through the same Stage-6 definition pool as package bosses. No universal boss is substituted when a definition pool is empty; map generation must use eligible boss content.

## Deterministic map generation and content packages

The active run owns its RNG seed/state. Generation persists the selected theme, map number, five non-boss stage templates, planned objective/enemy/loot choices, boss ID and generation state before the player can enter the generated result. Stage layouts, entities, chest outcomes after opening, inventory, abilities and the current encounter are part of the saved run. Resuming restores RNG state and established plans rather than rerolling them.

`data/content.json` uses `maps`, `stages` and `bosses` definitions that share the package registry with Core and official packages. A map definition provides an eligible theme, weight, tags, depth bounds/prerequisites and stage templates. Stage templates provide objectives, enemy pools, composition curves, terrain and exploration-loot rules. Bosses provide their enemy definition, Stage-6 eligibility, theme/depth/prerequisites and selection weight. A package can add these definitions through the registry; central generation consumes them without a package-specific branch. Package enablement, dependencies, deterministic load order and validation remain governed by `CONTENT_FOUNDATION.md`.

Map 1 is deliberately constrained: Ruined Village is selected; only Eliminate and Reach Exit objectives are used; only tier-zero enemies are planned. It remains a normal generated encounter flow, not a scripted tutorial. Later maps exclude the immediately previous theme when another eligible theme exists, to make the journey varied while keeping each Map internally coherent.

The lower World Map stores every visited/revealed map, highlights the current map, and appends one circular `?` while the next map is still unknown. It does not reveal future themes, bosses, stages or encounters early. Stage-6 completion replaces that unknown node with the generated destination. The panel displays five nodes at a time, follows the newest map by default, and provides paging through the complete visited history; node size stays readable instead of fitting an unbounded history on one screen.

## Difficulty and rewards by depth

For map depth `d`, `L = ln(d)` and initial enemy scaling is:

- Health multiplier: `1 + 0.12L + 0.02L²`
- Damage multiplier: `1 + 0.085L + 0.012L²`
- Armor bonus: `floor(0.035L)`
- Additional planned enemies: `floor(1.15L)`, bounded by usable encounter cells
- Maximum eligible enemy tier: `floor(L / ln(2))`

Each value belongs to `scripts/game_sim.gd` and is a tuning constant, not a victory/maximum-depth rule. Stat application uses the largest exactly represented integer supported by the combat model (`10^15`) as a technical serialization/precision safety boundary; map depth and scaling formulas themselves have no gameplay depth cap. UI counters switch to compact scientific notation when their decimal representation becomes too long.

Reward definitions continue through global eligibility, prerequisites and package availability. Character affinities and selected build tags only change probability; they never hard-lock off-build content. For Common content, depth adds no rarity multiplier. For Uncommon/Rare/Epic/Legendary, the rank is 1/2/3/4 and the ordinary candidate weight is multiplied by `1 + 0.04 × ln(d) × rank`. This raises access to rarer rewards gradually without guaranteeing upgrades or removing ordinary options.

Boss definitions are filtered by enemy reference, Stage-6-only eligibility, min/max depth, map themes and prerequisites. Base weight comes from content. A rare boss's current default weight multiplier is `1 + ln(d) × 0.08`; a non-rare boss's default multiplier is divided by `1 + ln(d) × 0.015`. Both coefficients are content-overridable. This keeps rare bosses possible at shallow depth and increasingly likely at depth without guaranteeing them at an arbitrary map number.

## Run continuity, saving and death

Between maps, retain the current hero's Health, Mana, Stamina, inventory, equipment, consumables, learned run abilities, ability state, relics, artifacts, tag counts/dynamic reward weighting and run statistics. Map entry does not apply an additional heal or resource refill. Ordinary within-map stage rules remain their own existing behavior. Stage-scoped statuses and battlefield summons continue to follow the existing encounter reset model.

The existing `user://run_save.json` remains the one active-run save. It now stores map depth/history, current and pending map data, stage index and plans, run stats, full encounter state and RNG state alongside existing inventory/build/profile references. Writes use a temporary file and backup/rename recovery; the save format is versioned, and existing version-1 run state is migrated into the six-stage map model. Application pause, focus loss and close save the active run. The title screen offers Resume Run while an active save exists. Beginning a replacement run requires an explicit discard-and-begin action.

Hero death captures a profile-level last-run summary, removes active-run resumability and keeps permanent profile unlocks. Run-specific abilities, items and artifacts are not carried into a new run. The summary reports character, maps/stages, deepest map/stage, enemy/boss counts, level/XP and final ability/equipment/relic/artifact lists; a paged build view keeps long builds usable on mobile and desktop. Only accurately tracked simulation statistics belong in the summary.

## Deferred content ledger

[`PLANNED_IMPLEMENTATIONS.md`](../PLANNED_IMPLEMENTATIONS.md) is the persistent queue for approved but unavailable content. Every future implementation prompt begins by reviewing it. For each `BLOCKED` entry, verify dependencies. If satisfied, mark `READY`, check scope, implement only when it belongs to the current prompt, test it, then record `IMPLEMENTED` with a code/document reference. Otherwise leave it blocked. Scope discipline applies: the presence of a ledger entry is not permission to implement it.

The approved Swordplay package, its characters, techniques, enemies, weapons/relics/artifacts and rare Sword Lord Stage-6 boss remain blocked until the later user-led Swordplay work. This endless-progression update only supplies package-driven map/stage/boss injection and rare-boss depth weighting.
