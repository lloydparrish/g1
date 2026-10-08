# Core Companion and Stage Continuity

This document records the shared Core rules for owner-following companions, summon persistence and stage-entry recovery. These behaviors are independent of official content-package enablement.

## Owner-following companions

Summons may opt into the generic `follow_owner` behavior. Their ordinary AI turn is still scheduled by the simulation. A companion chooses hostiles near its living owner, tests line of sight, attacks only within its authored `range`, and uses the shared pathfinder and movement event path to engage or return. It stays one to two tiles away when idle; a summon that initially shares its owner's tile moves to an adjacent legal tile on its own turn. Its configured return distance takes priority over chasing. The behavior does not create free actions, teleportation or attacks through terrain.

Phantom Blade remains a Core summon with `range: 5`. Its current companion settings use a 1-tile minimum and 2-tile preferred maximum, a 4-tile owner-centered engagement distance and a 4-tile return-priority distance. The flags and AI logic are reusable by other companion definitions.

## Summon persistence

Every real Stage transition and Map transition uses `_new_stage`'s shared transfer path. It carries each living player-owned summon and preserves the entity dictionary, stable entity ID, current Health, ownership, Command cost, statuses and remaining status durations, timeline time, and other authored combat fields. A transition does not heal or tick a summon. Dead, zero-Health, dismissed and explicitly expired summons are filtered out.

After terrain generation, each summon is placed on the nearest deterministic valid tile that has no actor, blocks no object, and supports its footprint. Placement treats ethereal entities as occupants for this operation. When no legal cell exists, the complete entity state stays in the serialized `pending_summon_transfers` queue. Normal movement and deaths retry placement. Command occupancy includes both placed and queued summons. Enemy and summon ID allocation checks active entities and queued summon IDs to prevent overwrites.

Run-save version 4 stores the pending queue and the last applied stage-heal transition key. Versions 1 through 3 migrate with safe defaults; loading or resuming does not run either transition path.

## Stage-entry recovery

After completing a Stage, the production continue action applies one Core recovery on entry to the next Stage:

`max(1, floor(MaxHealth * STAGE_ENTRY_HEAL_PERCENT))`

`STAGE_ENTRY_HEAL_PERCENT` is `0.05` in `scripts/game_sim.gd`. Recovery is capped at maximum Health. The rule includes Stage 6 to the next Map's Stage 1. New-run initialization and save/load/resume do not apply it. Existing Stage Mana and Stamina recovery remains as authored by the prior stage flow; Map entry still does not refill those resources.

## Verification references

- Production and persistence regressions: `tests/summon_stage_fix_runner.gd`.
- Suite integration: `scripts/arcanist.ps1` (`Test` and `BuildAll`).
- Current rendered companion and transition captures: `docs/SUMMON_STAGE_VISUAL_QA.md`.
- Endless run continuity: [`ENDLESS_MAP_PROGRESSION.md`](ENDLESS_MAP_PROGRESSION.md).
