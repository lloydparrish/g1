# Prompt 6 Visual QA

## Reference and baseline

Canonical reference: [`Project_Arcanist_UI_Reference.png`](Project_Arcanist_UI_Reference.png).

The baseline was regenerated from the pulled `main` checkout with the production Godot scene before UI edits. Captures are in the ignored `build/visual-qa/` directory at 1920×1080, 2560×1440, and 2400×1080. The 1920×1080 baseline and canonical image were inspected side by side at `build/visual-qa/prompt6-baseline-comparison.png`.

### Baseline comparison — before reconstruction

The HUD already has a recognizable left / center / right arrangement and a large battlefield. Its measured 1920×1080 outer regions are approximately:

| Region | Current HUD | Reference art | Difference |
|---|---:|---:|---|
| Character column width | 14.8% | 15.5% | Similar |
| Battlefield width | 61.1% | 64.6% | Current field is narrower |
| Right information column | 19.3% | 17.4% | Current column is wider |
| Combat dock height | 18.1% | 11.9% | Current dock reserves more height |
| Lower four-panel relationship | Not present | 4 adjacent panels | Current utilities open unrelated full-screen overlays |

### Major discrepancies found before editing

1. The production HUD has no four-column lower interface. Map, ability web, inventory, and Codex are separate full-screen overlays rather than related sections of a contextual lower dock.
2. The combat dock is a wide row of application-like controls. It mixes fixed actions, eight configured slots, utility buttons, and Normal/Fast/Instant presentation controls. The reference has an icon-led action row and a distinct, restrained End Turn button.
3. Normal/Fast/Instant controls are exposed on the normal combat HUD, and the movement D-pad is visible in the Windows capture.
4. The left panel presents every resource and a two-column stat dashboard. The reference is a compact character readout with build-relevant resources and compact effects.
5. The right column has a turn list and field-intelligence panel, but it does not include the selected-enemy card in the default composition. The timeline has no strong current-turn treatment beyond a small label.
6. Inventory and ability views use detached modal layouts. The inventory has a 6×5 pack and nine equipment positions already, but not the four-section visual relationship or compact icon-first equipment treatment shown in the reference.
7. The toolbar's fixed actions, utility controls, and quick slots use uniform rectangular button styling and small labels; selected/affordability states and category accents need a more coherent RPG action-slot vocabulary.

These are the structural corrections used to scope the reconstruction. The baseline capture set and the reference were inspected before any production UI changes.

## Visual comparison passes

### Pass 1 — initial reconstruction

The first 1920×1080 production comparison established the left / battlefield / right frame, action strip, and four lower sections. It also exposed four concrete defects: the right context region was too tall, the action strip was too wide, the Known tab competed with the web shortcut, and the last ability card overlapped the panel footer. These findings drove the next pass rather than being accepted as final.

### Pass 2 — composition and panel correction

The second comparison used the canonical reference beside the updated 1920×1080 screen. The right panel was capped, the action strip narrowed, and the battlefield kept its dominant central area. Inspection of the expanded Character / Abilities section still showed the web shortcut crowding the four-tab row and the last card/footer spacing was not yet clean. Those remained open for the final pass.

### Pass 3 — final structural correction

The final whole-screen comparison confirmed the Known tab is fully visible, ability cards clear the footer, and the map fits between both side rails. The web opens from the Character tab as a dedicated larger subview. The final 1920×1080 screen measures approximately 14.8% left character column, 62.8% battlefield, and 18.9% right rail; the action strip is 68.9% of screen width and 10.8% of screen height. The canonical reference measures approximately 15.5%, 64.6%, and 17.4% for those three columns, with an action strip about 68.6% wide and 11.7% high. The remaining small difference is the slightly wider right rail and narrower battlefield; both fit without overlap.

With a dock section expanded, the four section widths are each about 23.9% of the 1920-pixel screen. The battlefield still occupies about 51% of screen height in that state; the collapsed default gives it more room. The reference shows all lower panels open at once, while production expands one section at a time to preserve battlefield space.

## Final assessment

The final composition follows the reference's dark tactical language and left / center / right information hierarchy. It preserves the eight configurable action slots and makes routine map, build, equipment, and discovery flows available in one contextual dock. Enemy inspection is shown in its own capture after selecting an enemy. The old full-screen map and inventory drawing paths were removed; the ability web remains intentionally available as the only large progression subview.

Final screenshots were captured at 1920×1080, 2560×1440, 2400×1080, 2340×1080, and 1280×720, plus focused captures for selected-enemy inspection, each dock section, ability assignment, and item assignment. Files are in the ignored `build/visual-qa/` directory so they do not add generated images to the source tree. The three passes were reviewed at 1920×1080 or larger against the canonical image at the top of this document.

## Final acceptance evidence

The refreshed whole-screen 1920×1080 capture was reviewed after the last item-action correction. All five target sizes and the focused captures were regenerated with `scripts/capture_visual_qa.ps1`. The final production screenshots are `build/visual-qa/1920x1080.png`, `build/visual-qa/p6-selected-enemy/1920x1080.png`, `build/visual-qa/p6-world-map/1920x1080.png`, `build/visual-qa/p6-character-abilities/1920x1080.png`, `build/visual-qa/p6-inventory-equipment/1920x1080.png`, `build/visual-qa/p6-spellbook-discovery/1920x1080.png`, `build/visual-qa/p6-ability-assignment/1920x1080.png`, and `build/visual-qa/p6-item-assignment/1920x1080.png`.

The full automated suite passed: 55 core, 27 production flow, 30 mobile acceptance, 49 progression and inventory, 40 playtest regression, 6 balance, and 37 combat presentation checks. The Windows debug export completed and the latest executable launched. The Android debug APK exported at 27.4 MiB, its package metadata and debug signature were verified, and it installed and launched on emulator `emulator-5554`.

Android touch acceptance was exercised on the installed build: all four lower sections opened; tapping a skeleton displayed its enemy inspection panel; D-pad movement updated the player turn; an ability was assigned to a vacant quick slot; and the Healing Draught changed from REMOVE BAR to ADD TO BAR when removed, then was assigned to another vacant slot. Ending a turn displayed exactly one SKIP control during enemy playback. The Android HUD shows the D-pad, while the desktop capture does not; neither capture exposes playback-speed controls. Touch captures are in `build/visual-qa/android-emulator/`, including `android-resumed-final.png`, `android-item-postfix.png`, `android-item-removed-postfix.png`, `android-item-assigned-postfix.png`, and `android-playback-postfix.png`.

Godot emitted a Windows root-certificate-store warning during its runs, and Android export reported that it selected build tools 35.0.1 for the configured target. Both builds completed successfully; the APK passed metadata and signature verification.
