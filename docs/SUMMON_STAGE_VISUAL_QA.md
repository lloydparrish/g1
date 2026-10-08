# Summon and Stage Continuity Visual QA

Reviewed the actual Godot-rendered battle captures produced by `scripts/capture_summon_stage_qa.ps1`. The mobile cases use the game's Android landscape layout override at 2400×1080.

| Scenario | Desktop capture | Android-layout capture |
| --- | --- | --- |
| Phantom Blade follow | [Desktop capture](visual-qa/core-companion-stage/phantom-follow-desktop-1920x1080.png), 1920×1080 | [Android-layout capture](visual-qa/core-companion-stage/phantom-follow-android-layout-2400x1080.png), 2400×1080 |
| New Stage with carried summon | [Desktop capture](visual-qa/core-companion-stage/stage-entry-desktop-1920x1080.png), 1920×1080 | [Android-layout capture](visual-qa/core-companion-stage/stage-entry-android-layout-2400x1080.png), 2400×1080 |

The signed Android export was installed on the `emulator-5554` Android emulator, launched, and navigated by touch into its resumed Stage 1 battle. The actual emulator capture is [Android emulator battle](visual-qa/core-companion-stage/android-emulator-battle-2400x1080.png), 2400×1080.

## Inspection notes

- Phantom Blade is visible beside The Spellblade after its own scheduled movement turns. The timeline shows the summon and the recent-event panel records its movement.
- At the Stage 2 entry, the injured player displays 12/44 Health, consistent with entering at 10 HP and receiving the two-point 5% recovery. The injured Phantom Blade appears on a separate nearby cell and remains in the timeline.
- The 1920×1080 desktop captures keep the character panel, battlefield, timeline, action strip and lower dock readable. The 2400×1080 Android-layout captures keep the battlefield dominant, retain the movement controls and keep the action strip and compact lower sections separated.
- No clipping, icon/name collision, summon/player overlap or unreadable summon symbol was visible. No UI change was needed.

The automated captures exercise the shared render path and Android layout configuration. The emulator capture confirms the installed Android export launches into a readable battle layout; no combat action was taken on the emulator's pre-existing saved run.
