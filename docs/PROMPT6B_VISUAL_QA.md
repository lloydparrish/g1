# Prompt 6B — Final HUD, Combat and Platform QA

Prompt 6B supersedes the four-panel and map-travel decisions recorded in Prompt 6A. The authoritative desktop lower HUD now contains three persistent panels: World Map, Character / Abilities, and Inventory / Equipment. Android retains a touch-first contextual dock with those same three sections.

## Final implementation contract

- World Map reads the active run's visited route, current encounter, and real connected choices. It supports inspection and shows connection lines; it does not expose route or boss travel actions. The post-objective destination picker is the normal progression flow and consumes the same `route_choices` state through the run's existing route APIs.
- Distant movement uses deterministic Dijkstra search over legal cells and chooses the lowest accumulated movement-time path. The current game charges the same per-step time for every legal terrain type, so the path cost is the step count multiplied by `_movement_step_time_cost`; the same helper drives the actual movement action. Player route planning respects explored terrain, walls, other occupants, diagonal directions and full creature footprints.
- Character categories come from the global content registry and appear only when current character/run progression makes that category relevant. Acquiring an ability or unlocking a school makes the category visible without removing any global categories.
- Spellbooks remain in Inventory / Spellbooks and the Codex. Previews and study results show immediate grants or current choice options. Storm Ledger grants Lightning Bolt; it no longer lists Storm Arrow as a direct grant. Cinder Primer likewise lists only Firebolt.
- Equipment filters its carried-item grid with the simulation's `can_equip_item` query. The selected Head slot shows a compact empty state when no compatible item exists; selecting Weapon shows compatible weapons and actual authored damage, type, time, range and stamina. Armor inspection uses the item's authored armor, resistances and modifiers.
- Targeted actions get range and valid-target cells from `get_targeting_preview`, which calls the same range and target predicates used by `is_valid_target_cell` during combat. Range is a light tile outline; visible valid targets receive a stronger mark. The query excludes unseen cells, and targeting clears on cancel, replacement action, resolution and turn transitions.
- Prompt 6A's physical-pixel text rendering and divider treatment remain active.

## Visual inspection

The final default combat captures were inspected at 1920×1080, 2560×1440, 1600×900 and 1280×720. Each keeps the battlefield and action strip dominant and fits the three lower panels without a fourth-column gap. The 1280×720 view retains the full layout. The expanded equipment and targeting states were separately checked at 1920×1080.

Focused captures:

- `build/visual-qa/p6b-character-abilities/1920x1080.png` — character-relevant ability categories.
- `build/visual-qa/p6b-equipment-head/1920x1080.png` — Head filter and “No compatible gear for this slot” state.
- `build/visual-qa/p6b-equipment-weapon/1920x1080.png` — Weapon filter, actual weapon stats, Equip and Unequip actions.
- `build/visual-qa/p6b-world-map/1920x1080.png` — visited route, current node, actual connected choices, no map travel action.
- `build/visual-qa/p6b-targeting-range/1920x1080.png` — visible range outlines and a stronger legal target marker.
- `build/visual-qa/p6b-destination-picker/1920x1080.png` — dedicated picker populated from this run's two connected choices.
- `build/visual-qa/windows-export/1920x1080.png` — screenshot produced by launching the exported Windows executable.

The first capture exposed overlapping current-location text and equipment footer controls. The map now places the current-location label above its route connectors; the equipment panel moves its clear-filter control to the list header and separates stats from its Equip / Unequip row. The regenerated captures show no overlapping labels in those areas.

## Android touch acceptance

The exported `build/android/ProjectArcanist.apk` installed and launched on emulator `emulator-5554` (2400×1080 landscape). A real touch opened Inventory, opened its Spellbooks tab and displayed the empty-book state. A D-pad touch moved Jim, spent one Stamina, and recorded “Jim the Mundane moves” in Recent Events. The final installed-build touch screenshot is `build/visual-qa/android-installed-touch-move.png`; earlier installed-build captures show the title, battle default and Spellbooks tab.

This verifies the emulator-installed build; physical-handset acceptance remains separate.

## Automated verification

The final test command is `scripts/arcanist.ps1 Test`. It runs all eight project suites:

| Suite | Checks | Failures |
|---|---:|---:|
| Core simulation and movement | 62 | 0 |
| Production flow | 30 | 0 |
| Mobile acceptance | 32 | 0 |
| Prompt 6A / 6B UI | 43 | 0 |
| Progression and inventory | 52 | 0 |
| Playtest regressions | 43 | 0 |
| Balance | 6 | 0 |
| Combat presentation | 37 | 0 |
| **Total** | **305** | **0** |

The suite includes long horizontal and vertical paths, an obstacle detour, an independently enumerated longer legal alternative, deterministic route selection, cost parity, fog constraints, category visibility, immediate spellbook grants, equipment slot filtering/stats, shared target legality, hidden-target exclusion, and overlay lifecycle checks.

## Build and release

The Windows debug executable was exported and launched from `build/windows-prompt6b/ProjectArcanist.exe`; its run produced the screenshot listed above. The default `build/windows-p5` output was occupied by a prior running executable, so the final build uses a separate folder and leaves the running process intact.

The Android APK was signed with the local debug key and verified with Godot's export checks plus `apksigner`. `releases/ProjectArcanist.apk` is the release copy to publish with this Prompt 6B change.

## Intentional differences from the reference artwork

- Desktop uses three lower panels instead of the reference's four, as requested in Prompt 6B. Spellbooks remain available in Inventory.
- The persistent World Map is a compact route overview; route selection happens in the post-objective destination picker.
- The battlefield uses the project's current grid and symbolic terrain/entity marks instead of the reference's illustrated tiles and decorative creature sprites.
- Android uses a contextual dock and D-pad rather than a desktop-like row of always-expanded panels.
