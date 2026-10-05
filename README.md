# Project Arcanist

A deterministic, touch first tactical roguelike vertical slice built with Godot 4.7.2. The game runs from character selection through branching encounters and rewards to the Grave Tyrant, victory, or death. The authoritative design brief and supplied UI reference are preserved in [`docs/`](docs/).

## Run it

The Windows machine copy of Godot is project local under `.tools/godot-4.7.2` and was obtained from the official Godot 4.7.2 stable archive. `.tools`, generated editor state and builds are ignored by Git.

From PowerShell at the project root:

```powershell
scripts\arcanist.ps1 Editor  # Open the Godot editor
scripts\arcanist.ps1 Run     # Launch the game
scripts\arcanist.ps1 Test         # Run simulation, production-flow and mobile acceptance suites
scripts\arcanist.ps1 Build        # Export a Windows x86-64 development build
scripts\arcanist.ps1 SetupAndroid # Install project-local Android export requirements
scripts\arcanist.ps1 Android      # Export and inspect the installable Android APK
scripts\arcanist.ps1 BuildAll     # Tests, Windows export and Android APK export
```

For a fresh checkout, run `scripts\arcanist.ps1 Setup`. It downloads the official editor, console runner and, when needed, the Godot 4.7.2 Windows and Android export templates. The full template archive is about 1.2 GB; the setup script installs only the platform files used here. Godot user settings and saves are redirected to the local `.godot-profile` folder when these scripts run.

The game accepts mouse or touchscreen taps for selection, movement, abilities, targeting and menus. Long press inspects battlefield creatures; the on-screen Cancel control and Android Back cancel targeting. Mouse right-click and keyboard shortcuts (WASD/arrows, Escape, I/K/M, E/Space and 1–6) remain optional desktop conveniences. Waiting for the player never advances simulation time.

## What is implemented

- Seeded, serializable simulation with a deterministic initiative timeline and no real time player decision clock.
- Data defined actors, factions, weapons, abilities, resources, status effects, stage definitions, objectives, rewards, artifacts and spellbooks in `data/content.json`.
- Square battlefield generation, eight direction movement, walk/path checks, line of sight, visible/explored fog and multi tile occupancy.
- Six character definitions, ten enemy types, an extensible damage/status registry and reusable terrain rules.
- Weapons with different range, time and stamina behavior; target based spells; skeleton and owner bound phantom blade summons; the 2x2 Grave Tyrant encounter.
- Inventory and nine equipment slots, 30 item inventory limit, rewards, equipment, consumables, branching routes, codex discoveries, pause/resume save and death/victory screens.
- Custom symbolic battlefield and touch sized overlay screens styled for the supplied dark tactical reference.

## Project structure

- `scripts/game_sim.gd` owns all authoritative game rules and serialization; it does not render.
- `data/content.json` defines the starter content and effect/trigger rules.
- `scripts/main.gd` renders the simulation and maps touch, mouse and keyboard input to game commands.
- `scenes/main.tscn` is the normal game entry point.
- `tests/test_runner.gd` runs the simulation checks headlessly; `tests/production_path_runner.gd` feeds clicks through the actual main scene's input path from character selection through boss victory and player death.
- `docs/PROJECT_ARCANIST_DESIGN_CONTRACT.md` and `docs/Project_Arcanist_UI_Reference.png` retain the source design materials.
- [`DESIGN_RULES.md`](DESIGN_RULES.md) keeps the non negotiable architecture and product rules visible for later work.

## Windows build

`scripts\arcanist.ps1 Build` writes `build/windows/ProjectArcanist.exe` as a self-contained debug export. It uses the Godot 4.7.2 template from project-local profile state. Start it with `scripts\arcanist.ps1 Run` to check the development project, or launch the exported EXE directly.

## Android setup and export

The Android export is a signed debug APK for ARM64, locked to landscape, named **Project Arcanist**, with package ID `com.projectarcanist.game`. Godot's compatibility renderer is shared with Windows. Touch enters the same game command path as mouse input; `user://` saves work in each platform's app data location.

For a fresh Windows checkout:

1. Run `scripts\arcanist.ps1 Setup` to install the project-local Godot 4.7.2 executable and export templates.
2. Run `scripts\arcanist.ps1 SetupAndroid`. This downloads Temurin JDK 17 and Google's command-line tools, installs the SDK packages required by Godot 4.7, accepts those SDK package licenses, creates the local debug key, and configures the ignored project-local Godot profile. It does not configure machine-global Java or Android settings.
3. Run `scripts\arcanist.ps1 Android` to export `build/android/ProjectArcanist.apk`, inspect the package name and app label, and verify its debug signature.

The toolchain uses OpenJDK 17, Android Platform Tools, Build Tools 35.0.1, Android Platform 35, command-line tools, CMake 3.10.2.4988404 and NDK 28.1.13356709. Godot's current requirements are listed in its [Android export guide](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html). `BuildAll` runs all test suites, exports Windows, then exports and inspects the Android APK. Generated SDK, JDK, keystore, Godot profile and build files stay ignored by Git.

## Verification and visual QA

`scripts\arcanist.ps1 Test` runs 55 deterministic simulation checks, 17 production-flow checks, and 17 mobile acceptance checks. The last suite compares identical mouse/touch movement state, checks Android Back and lifecycle save/resume behavior, checks viewport/safe-area calculations and ensures interactive targets remain at least 54 logical pixels.

`scripts\capture_visual_qa.ps1` writes production screenshots under `build/visual-qa/` at 1920×1080, 2560×1440, 2400×1080, 2340×1080 and 1280×720, plus inventory, route, reward and pause overlays. The base design remains 1440×810 with canvas-item expansion; wide-phone layouts use available width for the inspection panel while keeping square battlefield tiles. Low-processor mode idles the static turn-based UI until input or a notice requires redraw.

Automated and desktop-render verification do not establish acceptance on a physical Android device. First install, touch feel, physical text size, heat/performance, system Back navigation, suspend/resume and the specific phone's cutout behavior still need phone testing.

## Content editing

`data/content.json` is the starter content source. IDs referenced by another definition must exist in the same content registry; the validator checks references before the rest of the suite runs. Ability effects are arrays of reusable operations, costs are resource maps, targets declare their range/shape, and event rules use named triggers plus conditions/modifiers. Add mechanics to the generic resolver before adding a one-off ability implementation. Run saves are JSON at Godot's `user://run_save.json` with format version 1; the seeded RNG state is stored alongside the route, current encounter, entities, resources, inventory and progression.

## Design boundaries

This is Prompt 1's playable vertical slice. The starter roster, spell and item library are intentionally smaller than the design contract's later 60–80 ability baseline. Art, audio, production balance, broader enemy/boss roster and native Android device testing are follow up production scope; the combat and content model needed to expand them is already exercised by this slice.

Windows and Android are supported from the same deterministic simulation. Android landscape is the primary mobile layout, with touch and mouse mapped to shared actions, safe-area-aware drawing and an expandable wide-phone side panel. Continue cross-platform QA for future UI and gameplay work.
