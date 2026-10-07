# Content Foundation Visual QA

Final captures rendered on 2026-10-07 with Godot 4.7.2. Desktop (1920×1080), reduced desktop (1280×720), large desktop (2560×1440), and both established landscape-mobile sizes (2400×1080 and 2340×1080) were inspected for character selection. The capture script removes each previous PNG before regenerating it, and the capture viewport waits for settled rendered frames. The screenshots are retained as current review artifacts.

## Character selection and portraits

| View | Screenshot |
| --- | --- |
| Locked roster, desktop | [1920×1080](../build/visual-qa/content-foundation/character-select/1920x1080.png) |
| Locked roster, reduced desktop | [1280×720](../build/visual-qa/content-foundation/character-select-small/1280x720.png) |
| Locked roster, large desktop | [2560×1440](../build/visual-qa/content-foundation/character-select-large/2560x1440.png) |
| Locked roster, landscape mobile | [2400×1080](../build/visual-qa/content-foundation/character-select-mobile/2400x1080.png) |
| Locked roster, second landscape mobile size | [2340×1080](../build/visual-qa/content-foundation/character-select-mobile-2340/2340x1080.png) |
| All nine portraits and titles, desktop | [1920×1080](../build/visual-qa/content-foundation/character-select-all-unlocked/1920x1080.png) |
| All nine portraits and titles, reduced desktop | [1280×720](../build/visual-qa/content-foundation/character-select-all-unlocked-small/1280x720.png) |
| All nine portraits and titles, landscape mobile | [2400×1080](../build/visual-qa/content-foundation/character-select-all-unlocked-mobile/2400x1080.png) |
| All nine portraits and titles, second landscape mobile size | [2340×1080](../build/visual-qa/content-foundation/character-select-all-unlocked-mobile-2340/2340x1080.png) |
| Portrait contact sheet | [Treatment A: all nine](../build/visual-qa/content-foundation/portraits/treatment-a-nine-portrait-sheet.png) |

## Character reveals

Each advanced-class reveal was inspected with its final portrait, title and short description. The mobile screenshot shows the Spellblade reveal.

| Reveal | Screenshot |
| --- | --- |
| The Spellblade | [1920×1080](../build/visual-qa/content-foundation/character-reveal/1920x1080.png) |
| The Bloodletter | [1920×1080](../build/visual-qa/content-foundation/portrait-reveal-bloodletter/1920x1080.png) |
| The Warrior | [1920×1080](../build/visual-qa/content-foundation/portrait-reveal-warrior/1920x1080.png) |
| The Necromancer | [1920×1080](../build/visual-qa/content-foundation/portrait-reveal-necromancer/1920x1080.png) |
| The Ranger | [1920×1080](../build/visual-qa/content-foundation/portrait-reveal-ranger/1920x1080.png) |
| The Spellblade, landscape mobile | [2400×1080](../build/visual-qa/content-foundation/character-reveal-mobile/2400x1080.png) |
| The Spellblade, second landscape mobile size | [2340×1080](../build/visual-qa/content-foundation/character-reveal-mobile-2340/2340x1080.png) |

The locked cards show a large `?`, “Unknown Character” and the authored player-facing requirement. They hide the actual title, portrait and silhouette. The requirement text wraps within the card at the inspected desktop and mobile sizes. Unlocked cards and reveal views use the actual portrait and concise class identity.

## Other affected screens

| Screen | Desktop / reduced | Large desktop | Landscape mobile |
| --- | --- | --- | --- |
| Content / Mods | [1920×1080](../build/visual-qa/content-foundation/content-mods/1920x1080.png) | [2560×1440](../build/visual-qa/content-foundation/content-mods-large/2560x1440.png) | [2400×1080](../build/visual-qa/content-foundation/content-mods-mobile/2400x1080.png) |
| Three stage rewards | [1920×1080](../build/visual-qa/content-foundation/stage-rewards/1920x1080.png), [1280×720](../build/visual-qa/content-foundation/stage-rewards-small/1280x720.png) | [2560×1440](../build/visual-qa/content-foundation/stage-rewards-large/2560x1440.png) | [2400×1080](../build/visual-qa/content-foundation/stage-rewards-mobile/2400x1080.png) |
| Chest | [1920×1080](../build/visual-qa/content-foundation/exploration-chest/1920x1080.png) | — | [2400×1080](../build/visual-qa/content-foundation/exploration-loot-mobile/2400x1080.png) |
| Skill book | [1920×1080](../build/visual-qa/content-foundation/exploration-book/1920x1080.png) | — | — |
| Star-marked drop | [1920×1080](../build/visual-qa/content-foundation/exploration-star/1920x1080.png) | — | — |
| Inventory / equipment | [1920×1080](../build/visual-qa/content-foundation/inventory-equipment/1920x1080.png) | — | — |
| Ability window | — | — | [2400×1080](../build/visual-qa/content-foundation/ability-window-mobile/2400x1080.png) |

The Official Content and Mods columns remain distinct; Core is labeled “Always On” without showing IDs or package versions. Reward options, chest and skill-book actions, and the dropped-loot star marker remain visible. The inspected layouts have no text overlap, portrait/name collisions, clipping, broken wrapping or internal IDs. The established lower-toolbar layout remains intact.

## Portrait direction

Treatment A was selected and is installed as the static portrait family in `assets/portraits/`. It uses deliberately crude/charming clean stick figures with readable equipment and restrained accents. Treatment B is not used in production. No Swordplay or other new content package was created for this QA pass.
