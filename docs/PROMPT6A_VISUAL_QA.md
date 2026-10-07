# Prompt 6A — Historical Desktop HUD and Mobile Regression QA

> Superseded by Prompt 6B. Prompt 6A's four-panel desktop and map travel-control contracts below describe the earlier state. The current three-panel layout and destination-picker travel flow are recorded in [`PROMPT6B_VISUAL_QA.md`](PROMPT6B_VISUAL_QA.md).

## Typography finding and correction

The project uses a 1440×810 logical canvas with `window/stretch/mode="canvas_items"` and `window/stretch/aspect="expand"`. The small fallback-font sizes passed to `draw_string` were being rasterized in the logical canvas and then resampled at fractional window scales. This made compact labels look soft and uneven, especially at 1280×720 and 1600×900.

The HUD now draws text in physical-pixel space: `_draw_label` selects an integer physical font size, rounds the rendered position, temporarily removes the canvas scale, and restores the scene transform after each label. `_fit_text` measures with that same physical font size so measured widths agree with the rendered text. No bitmap font or other font asset was introduced.

## Layout and interaction contract

- Windows keeps World Map, Character / Abilities, Inventory / Equipment, and Spellbook / Discovery visible together. Changing a tab or panel selection does not advance the simulation.
- Android keeps the four section selectors in its contextual dock and gives the selected section the full lower width. The D-pad appears only on the Android layout.
- Inventory opens on the Inventory tab. Its tabs are Inventory, Equipment, Artifacts, and Spellbooks. Selecting an item or equipment slot only inspects it; explicit Equip and Unequip controls perform those actions.
- Ability categories come from content metadata, and the selected category filters abilities and the Known progression list. Desktop hover details use the selected ability, item, map node, artifact, or book's content data.
- The map uses the current run's recorded route and connected `route_choices`. Selecting a destination only selects it. A separate Travel action is visible after the encounter is complete; no travel action is exposed before completion.
- Field Intelligence is the default right-side context. Selecting an enemy replaces its contents with that enemy's details; the clear control restores Field Intelligence.
- Panel and timeline separators were inspected at all four required desktop sizes. Header labels stay above their dividers, and the page, category, and inventory controls do not cross their panel boundaries.

## Visual comparison passes

### Pass 1 — first four-panel draft

The 1920×1080 draft established the four always-visible Windows panels and the independent Android path. Review found the map left its destination area empty before an encounter completed, and some compact labels still looked soft after canvas scaling. The map now shows only the run's actual connected choices in a locked state, while the text path renders at physical-pixel size.

### Pass 2 — resolution and information-flow review

The first full-size capture set was reviewed at 1920×1080, 2560×1440, 1600×900, and 1280×720. The four-panel layout fit at each size and retained the central battlefield. Inspection found the current map label too close to the left panel edge, a redundant desktop Next Stage button beside the map's Travel action, and ability-cost text crossing the page controls. The route track was inset, desktop Next Stage was removed while keeping its Android navigation role, and the ability details moved above the page-control row. Mobile review also showed the active panel needed the full dock width for equipment and carried items; its contextual body now spans that width.

### Pass 3 — final four-size and focused-state review

The regenerated full-screen set was inspected after those fixes. The map route label stays inside its panel, the completed-map state has one clear Travel action, and ability details clear the pagination controls. The four desktop panels remain independently usable at all target sizes. Focused captures verify locked and ready routes, Pyromancy and Arcane filtering, the equipment slots beside carried gear, and a data-backed ability hover tooltip. Android-layout automation exercises item selection, explicit Equip and Unequip, destination selection, explicit travel, ability assignment, enemy inspection, and turn flow. Emulator review found the mobile Character dock needed extra height to keep its detail/action footer below the ability cards; the dock now reserves the same 260 logical pixels as Inventory, and the installed 2400×1080 emulator capture confirms the footer clears the final card.

## Capture set

The automated capture script now includes the requested Windows sizes plus the existing wide-phone profiles. Whole-screen images and focused states are written to the ignored `build/visual-qa/` directory:

- `1920x1080.png`, `2560x1440.png`, `1600x900.png`, and `1280x720.png`
- `6a-map-locked/1920x1080.png` and `6a-map-ready/1920x1080.png`
- `6a-abilities-pyromancy/1920x1080.png` and `6a-abilities-arcane/1920x1080.png`
- `6a-equipment/1920x1080.png` and `6a-ability-tooltip/1920x1080.png`
- `android-prompt6a/abilities_final.png` (installed emulator, 2400×1080)

The earlier Prompt 6 screenshots and conclusions remain historical; this record documents the Prompt 6A desktop composition and its Android touch regression pass.
