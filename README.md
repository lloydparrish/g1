# Project Arcanist

A deterministic, touch first tactical roguelike vertical slice built with Godot 4.7.2. The game runs from character selection through branching encounters and rewards to the Grave Tyrant, victory, or death. The authoritative design brief and supplied UI reference are preserved in [`docs/`](docs/).

## Run it

The Windows machine copy of Godot is project local under `.tools/godot-4.7.2` and was obtained from the official Godot 4.7.2 stable archive. `.tools`, generated editor state and builds are ignored by Git.

From PowerShell at the project root:

```powershell
scripts\arcanist.ps1 Editor  # Open the Godot editor
scripts\arcanist.ps1 Run     # Launch the game
scripts\arcanist.ps1 Test    # Run the headless deterministic suite
scripts\arcanist.ps1 Build   # Export a Windows x86-64 development build
```

For a fresh checkout, run `scripts\arcanist.ps1 Setup`. It downloads the official editor, console runner and, when needed, the Godot 4.7.2 Windows and Android export templates. The full template archive is about 1.2 GB; the setup script installs only the platform files used here. Godot user settings and saves are redirected to the local `.godot-profile` folder when these scripts run.

The game also accepts arrow keys or WASD, Escape to pause/cancel, I for inventory, K for abilities, M for the route map, E/Space to wait and 1–6 for known abilities. Mouse and touch use the same tap/target actions.

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

`scripts\arcanist.ps1 Build` writes `build/windows/ProjectArcanist.exe` as a self contained debug export. Run it after setup; the command checks both the matching Godot templates and the resulting file. `export_presets.cfg` also has a release template configuration for a release export from Godot's export dialog.

## Android setup and export

The project is landscape first and uses the OpenGL compatibility renderer. Its Android preset targets arm64 and an APK. To export on Windows:

1. Install OpenJDK 17 or newer and the Android SDK.
2. Install Android SDK Platform Tools 35 or newer, Build Tools 35.0.1, Android Platform 35, CMake 3.10.2.4988404 and NDK 28.1.13356709 (r28b).
3. Set `JAVA_HOME` and `ANDROID_HOME` (or `ANDROID_SDK_ROOT`), then in Godot Editor Settings set the matching Java SDK and Android SDK paths.
4. Run `scripts\export_android.ps1` to create `build/android/ProjectArcanist.apk`.

Godot 4.7's Windows Android export requirements and package versions are recorded in the [official Android export guide](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html). This machine currently has Java 11 and no Android SDK tools, so Android export and device acceptance remain pending; the APK command reports the missing prerequisites instead of producing an unverified build. Windows export is available and verified.

## Content editing

`data/content.json` is the starter content source. IDs referenced by another definition must exist in the same content registry; the validator checks references before the rest of the suite runs. Ability effects are arrays of reusable operations, costs are resource maps, targets declare their range/shape, and event rules use named triggers plus conditions/modifiers. Add mechanics to the generic resolver before adding a one-off ability implementation. Run saves are JSON at Godot's `user://run_save.json` with format version 1; the seeded RNG state is stored alongside the route, current encounter, entities, resources, inventory and progression.

## Design boundaries

This is Prompt 1's playable vertical slice. The starter roster, spell and item library are intentionally smaller than the design contract's later 60–80 ability baseline. Art, audio, production balance, broader enemy/boss roster and native Android device testing are follow up production scope; the combat and content model needed to expand them is already exercised by this slice.

On ultra wide 20:9 displays, the interface keeps its 16:9 composition and square battlefield tiles centered with dark side margins. A full width safe area layout and native Android device review remain production polish work.
