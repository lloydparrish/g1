# Prompt 5 Visual QA

The production capture set was generated with `scripts/capture_visual_qa.ps1`.
It contains 44 PNG captures under `build/visual-qa/`, covering the baseline and
representative combat, quickbar, inventory, history, progression, reward, route,
pause, and mobile landscape states. These generated captures are local build
artifacts and are not committed.

## Layout review

The reviewed desktop and phone-like landscape captures include 1920×1080,
2560×1440, 2400×1080, 2340×1080, and 1280×720. The action tray fills the
available lower region more consistently with the reference, while keeping
separate tap regions for movement, attacks, quick slots, and utility actions.
The 54-pixel minimum hit regions are separated so adjacent actions do not
overlap. Targeting exposes a visible Cancel action.

The inventory captures cover the full 30-item pack, selected equipment,
selected consumables, and assigning an item to the quickbar. The combat-history
captures cover the compact recent-events view and the expanded paged history.
History closes from its in-panel close control. The level-up capture verifies
that the displayed XP is the post-threshold amount and that nearby floating
combat labels are placed without overlap.

## Captures to inspect

- `build/visual-qa/prompt5-baseline/1920x1080.png`
- `build/visual-qa/level-up/1920x1080.png`
- `build/visual-qa/full-inventory/1920x1080.png`
- `build/visual-qa/combat-history/1920x1080.png`
- `build/visual-qa/quickbar-empty/1920x1080.png`
- `build/visual-qa/2340x1080/normal-battle.png`

The screenshots are generated from the production game scenes and simulation.
They verify layout and presentation, but do not substitute for testing touch
feel, readability, heat, or system navigation on a physical Android device.

## Final recovery verification

The original 44 capture set was reviewed against
`docs/Project_Arcanist_UI_Reference.png` before publication. It shows the
reference's narrow character panel, dominant battlefield, right-side turn and
Field Intelligence panels, icon-led bottom action tray, and compact contextual
inventory/build interfaces. The P5 HUD reconstruction is structurally closer
to the reference than the previous stacked developer panels. The 6×5 inventory
grid, eight-slot quickbar, compact Recent Events feed and paged history are
visible in the reviewed production captures.

The final Android APK was installed and launched on 2026-10-06 in a workspace-
local Android 36 accelerated emulator profile. The app rendered in landscape at
2400×1080 with the host AMD Radeon GPU and OpenGL ES 3.1. ADB touch input
entered a run, committed movement, selected and canceled Lunge targeting with
Android Back, changed Normal/Fast/Instant controls, opened the ability palette,
inventory and encounter history, then cast Lunge at a highlighted Skeleton.
The Recent Events feed recorded the 14-point Piercing hit, the cast, and the
following Skeleton turns. Backgrounding to the Android launcher and reopening
the app returned to the same player decision with no duplicate turn.

The final emulator captures are kept as local build output under
`build/visual-qa/android-emulator/`; the main gameplay view with combat feedback
is `combat-feedback-final.png`. Additional captures show the touch targeting
cancel, quickbar, expanded ability palette, inventory, history, all three
speed selections, and background/resume state. They are excluded from Git along
with the other generated captures. The pre-existing user-profile AVD was not
modified because the emulator could not create its snapshot lock there; the
workspace-local profile provided the accelerated host-GPU path instead.

The Windows exported executable was also launched for production play. A map
tap visibly committed movement, showed sequential enemy turns and populated
the event feed; Lunge targeting appeared and the Cancel control returned to
the player state without spending a turn. These emulator and desktop checks do
not replace the physical-phone acceptance of readability, actual touch feel,
device-specific safe areas, heat, and real OS suspend/resume behavior.
