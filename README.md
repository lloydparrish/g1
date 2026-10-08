# Project Arcanist

A deterministic, touch-first tactical roguelike built with Godot 4.7.2. A run continues through procedurally generated six-stage maps until the hero dies, then presents a run summary. The authoritative design brief and supplied UI reference are preserved in [`docs/`](docs/).

## Run it

The Windows machine copy of Godot is project local under `.tools/godot-4.7.2` and was obtained from the official Godot 4.7.2 stable archive. `.tools`, generated editor state and builds are ignored by Git.

From PowerShell at the project root:

```powershell
scripts\arcanist.ps1 Editor  # Open the Godot editor
scripts\arcanist.ps1 Run     # Launch the game
scripts\arcanist.ps1 Test         # Run simulation, production-flow, mobile, progression/inventory, balance and presentation suites
scripts\arcanist.ps1 Build        # Export a Windows x86-64 development build
scripts\arcanist.ps1 SetupAndroid # Install project-local Android export requirements
scripts\arcanist.ps1 Android      # Export and inspect the installable Android APK
scripts\arcanist.ps1 BuildAll     # Tests, Windows export and Android APK export
```

For a fresh checkout, run `scripts\arcanist.ps1 Setup`. It downloads the official editor, console runner and, when needed, the Godot 4.7.2 Windows and Android export templates. The full template archive is about 1.2 GB; the setup script installs only the platform files used here. Godot user settings and saves are redirected to the local `.godot-profile` folder when these scripts run.

The game accepts mouse or touchscreen taps for selection, movement, abilities, targeting and menus. Long press inspects battlefield creatures; the on-screen Cancel control and Android Back cancel targeting. Mouse right-click and keyboard shortcuts (WASD/arrows, Escape, I/K/M, E/Space and 1–6) remain optional desktop conveniences. Waiting for the player never advances simulation time.

## What is implemented

- Seeded, serializable simulation with a deterministic initiative timeline and no real time player decision clock.
- Data-defined actors, factions, weapons, abilities, resources, status effects, map themes, stage definitions, objectives, bosses, rewards, artifacts and spellbooks in `data/content.json`.
- Square battlefield generation, eight direction movement, walk/path checks, line of sight, visible/explored fog and multi tile occupancy.
- Four weak starting classes (The Mundane, The Archer, The Apprentice and The Defender) plus five advanced classes discovered through profile unlocks; eleven enemies, stage-aware threat bands, an extensible damage/status registry and reusable terrain rules.
- Six stages per procedural map; Stage 6 selects an eligible content-defined boss. Map themes, stage templates and bosses can be added by enabled content packages. The 2×2 Grave Tyrant is the current Core boss.
- 32 currently playable abilities and passives (29 active, 3 passive) span martial, magical, hybrid and discovery paths. The prerequisite graph is data-driven and larger than the visible UI; its interface pans, filters and zooms, with no viewport-based node cap.
- A compact 6×5 inventory grid, contextual item inspection, all nine equipment slots, two-handed hand reservation, 30 item capacity, rewards, consumables, exploration loot, codex discoveries, autosave/resume, map transitions that preserve the active hero/build, and death/run-summary screens.
- Sequential combat-event playback with Normal, Fast and Instant presentation speeds, visibility-safe floating feedback, a six-entry Recent Events panel and a paged 100-record encounter history, full/assist/no-participation XP credit, and character-profile growth.
- Eight configurable quickbar slots store stable ability/item IDs, preserve empty consumable assignments and save across resume; gameplay input is blocked until event playback finishes or is skipped.
- Custom symbolic battlefield and touch-sized contextual screens guided by the supplied dark tactical reference.

## Project structure

- `scripts/game_sim.gd` owns all authoritative game rules and serialization; it does not render.
- `data/content.json` defines the starter content and effect/trigger rules.
- `scripts/main.gd` renders the simulation and maps touch, mouse and keyboard input to game commands.
- `scenes/main.tscn` is the normal game entry point.
- `tests/content_foundation_runner.gd` and `tests/endless_progression_runner.gd` cover packages, progression, saves, deterministic map generation and a 60-map stress run; production-flow and mobile suites exercise mouse and touch through the production scene.
- `docs/PROJECT_ARCANIST_DESIGN_CONTRACT.md` and `docs/Project_Arcanist_UI_Reference.png` retain the source design materials.
- [`docs/ENDLESS_MAP_PROGRESSION.md`](docs/ENDLESS_MAP_PROGRESSION.md) defines endless-map generation, Stage-6 bosses, difficulty/reward scaling, autosave and run summaries.
- [`PLANNED_IMPLEMENTATIONS.md`](PLANNED_IMPLEMENTATIONS.md) tracks approved deferred work; Swordplay remains blocked for a future user-led design pass.
- [`DESIGN_RULES.md`](DESIGN_RULES.md) keeps the non negotiable architecture and product rules visible for later work.

## Windows build

`scripts\arcanist.ps1 Build` writes the self-contained debug export to `build/windows/current/ProjectArcanist.exe`, replacing the current development build. It uses the Godot 4.7.2 template from project-local profile state. Start it with `scripts\arcanist.ps1 Run` to check the development project, or launch the exported EXE directly. Retain only named comparison/release builds and current QA artifacts; see the [build-output policy](docs/CONTENT_FOUNDATION.md#build-output-policy).

## Android setup and export

The Android export is a signed debug APK for ARM64, locked to landscape, named **Project Arcanist**, with package ID `com.projectarcanist.game`. Godot's compatibility renderer is shared with Windows. Touch enters the same game command path as mouse input; `user://` saves work in each platform's app data location.

For a fresh Windows checkout:

1. Run `scripts\arcanist.ps1 Setup` to install the project-local Godot 4.7.2 executable and export templates.
2. Run `scripts\arcanist.ps1 SetupAndroid`. This downloads Temurin JDK 17 and Google's command-line tools, installs the SDK packages required by Godot 4.7, accepts those SDK package licenses, creates the local debug key, and configures the ignored project-local Godot profile. It does not configure machine-global Java or Android settings.
3. Run `scripts\arcanist.ps1 Android` to export `build/android/current/ProjectArcanist.apk`, inspect the package name and app label, and verify its debug signature.

The toolchain uses OpenJDK 17, Android Platform Tools, Build Tools 35.0.1, Android Platform 35, command-line tools, CMake 3.10.2.4988404 and NDK 28.1.13356709. Godot's 4.7.2 Android template emits an APK with compile/target API 36; the local exporter reports its documented Build Tools fallback to 35.0.1. The resulting APK is signed, package-inspected and installed/launched in the Android emulator. Godot's export requirements are listed in its [Android export guide](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html). `BuildAll` runs all test suites, exports Windows, then exports and inspects the Android APK. Generated SDK, JDK, keystore, Godot profile and build files stay ignored by Git.

## Verification and visual QA

`scripts\arcanist.ps1 Test` runs ten suites: core 62, production flow 36, mobile acceptance 32, Prompt 6A UI 64, progression/inventory 52, playtest regressions 43, balance 6, combat presentation 37, content foundation 109 and endless progression 1,185 (1,626 checks total). The endless suite stress-tests 60 complete maps (360 stages) and covers deterministic generation/reload, package injection, Stage-6 bosses, long counters, carry-forward, unknown/revealed destinations and death cleanup. `BuildAll` runs the suites and exports current Windows and Android development builds. Balance samples 300 opening seeds, 400 stage samples and 60 deterministic tactical opening runs. Platform suites compare mouse/touch results, Android Back, lifecycle saves, safe-area/layout bounds and minimum touch regions. Content foundation coverage includes packages, tags, character unlocks, rewards, exploration loot, saves and the declined-transition regression.

`scripts\capture_visual_qa.ps1` retains the existing production screen captures. `scripts\capture_endless_visual_qa.ps1` captures Map 1 with its unknown destination, Stage-6 boss communication, next-map reveal, Map 2, long journey history (including older-page navigation), resume/new-run confirmation, run summaries and long summary builds on desktop and mobile. Captures are stored under `build/visual-qa/endless/`; the reviewed endless-map capture set is indexed in [`docs/ENDLESS_MAP_VISUAL_QA.md`](docs/ENDLESS_MAP_VISUAL_QA.md). The base design remains 1440×810 with canvas-item expansion; wide-phone layouts use available width for the inspection panel and action tray while keeping square battlefield tiles. Low-processor mode idles the static turn-based UI until input or a notice requires redraw.

The Prompt 2 build was physically tested by the user. The Prompt 5 APK was installed and launched in an accelerated Android 36 emulator at 2400×1080 landscape. Touch-style ADB input started a run, committed movement and a Lunge attack, changed presentation speed, opened the expanded ability palette, inventory and encounter history, and used Android Back to cancel targeting. Background/resume returned to the same turn state. The existing user-profile AVD could not create its snapshot lock under this workspace's permissions, so verification used a separate workspace-local emulator profile. Codex did not use a physical handset for Prompt 5; recheck touch feel, text size, performance/heat, suspend/resume and the device's cutout behavior on the intended phone.

## Content editing

`data/content.json` is the Core content source. IDs referenced by another definition must exist in the same content registry; the validator checks references before the rest of the suite runs. Ability effects are arrays of reusable operations, costs are resource maps, targets declare their range/shape, and event rules use named triggers plus conditions/modifiers. Add mechanics to the generic resolver before adding a one-off ability implementation. Run saves are JSON at Godot's `user://run_save.json` with format version 2 and version-1 migration. The saved RNG state, generated map/history and stage/boss plans are stored alongside the current encounter, entities, resources, inventory and progression.

## Design boundaries

The playable content remains intentionally smaller than the design contract's later 60–80 ability target. This milestone establishes the progression graph, early-run pacing, inventory and responsive presentation; broader content and final balance remain later production scope.

Windows and Android are supported from the same deterministic simulation. Android landscape is the primary mobile layout, with touch and mouse mapped to shared actions, safe-area-aware drawing and contextual inventory/build screens. Continue cross-platform QA for future UI and gameplay work; never cap progression to fit a viewport.
