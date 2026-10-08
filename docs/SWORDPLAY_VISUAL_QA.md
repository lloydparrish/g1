# Swordplay Visual QA

The retained captures were generated from isolated QA profiles with the current Godot build. Desktop-layout captures use a 1920×1080 window; mobile-layout captures use the project's 2400×1080 capture profile with mobile sizing and touch layout enabled. These are rendered UI captures, not Android-device runtime screenshots.

## Captures reviewed

| Capture | Layout | Review focus |
| --- | --- | --- |
| `content-mods/1920x1080.png` | Desktop | Swordplay package name, summary, enable state and spacing. |
| `content-mods-mobile/2400x1080.png` | Mobile | Package row and enable control at mobile scale. |
| `characters-locked/1920x1080.png` | Desktop | Locked character cards and authored conditions. |
| `characters-unlocked/1920x1080.png` | Desktop | Duelist/Fencer cards, portrait, stats and concise identity. |
| `berserker-locked/2400x1080.png` | Mobile | Hidden identity, portrait concealment and Sword Lord condition. |
| `berserker-unlocked/1920x1080.png` | Desktop | Berserker portrait, weapon, attributes and unlocked state. |
| `portrait-duelist/1920x1080.png` | Desktop | Revealed Duelist portrait. |
| `portrait-fencer/1920x1080.png` | Desktop | Revealed Fencer portrait. |
| `portrait-berserker/2400x1080.png` | Mobile | Revealed Berserker portrait at mobile scale. |
| `technique-lunge/1920x1080.png` | Desktop | Gap-closer targeting and cost/range tooltip. |
| `technique-cleave/1920x1080.png` | Desktop | Multi-target arc and selected ability presentation. |
| `technique-parry-mobile/2400x1080.png` | Mobile | Action palette and technique selection at mobile scale. |
| `technique-whirlwind/1920x1080.png` | Desktop | Radial area technique and resource/cooldown description. |
| `technique-blade-dance/1920x1080.png` | Desktop | Evolution selection, route movement and nearby strikes. |
| `technique-skewer/1920x1080.png` | Desktop | Piercing line geometry and prerequisite context. |
| `technique-forced-movement/1920x1080.png` | Desktop | Battering Blow displacement and collision result description. |
| `technique-combination/2400x1080.png` | Mobile | Great Cleaver selection and visible parent techniques. |
| `parry-state/1920x1080.png` | Desktop | Active Parrying state and character panel. |
| `enemy-family/1920x1080.png` | Desktop | Goblin, Kobold and Orc silhouettes, names and battle readability. |
| `unique-weapon/1920x1080.png` | Desktop | Goblinbane equipment identity and full tooltip. |
| `relic-detail/1920x1080.png` | Desktop | Mirror Guard trigger and reward/inventory presentation. |
| `artifact-detail/2400x1080.png` | Mobile | Perfect Timing effect and Stamina drawback. |
| `sword-lord-encounter/1920x1080.png` | Desktop | Stage-6 Sword Lord encounter identity and battlefield placement. |
| `sword-lord-reward/1920x1080.png` | Desktop | Signature weapon reward, relic and artifact card descriptions. |
| `later-endless-map/2400x1080.png` | Mobile | Swordplay map and foes at later endless depth. |

## Review and corrections

The selected package and character screens keep the three new portraits and unlock conditions readable. The portrait treatment remains intentionally rough and stick-figure-like, with equipment silhouettes separating sword, rapier and greatsword identities. The desktop ability captures show the selected technique's behavior, targeting and resource profile; the mobile captures were checked for card overlap, touch-control collision, cut-off labels and layout overflow. Equipment, relic and artifact detail panels expose their effects without raw IDs or tag dumps.

Visual review caught two content presentation issues. The Content/Mods summary and character descriptions were shortened to remove card ellipses, and the character ordering now places the new starters after the existing Core roster. The Sword of the Goblin Horde reward copy was shortened so the complete Stamina discount and kill-stacking effect fit in the reward card. The reward capture presents a completed deep run rather than zeroed progress counters. Captures were regenerated after these corrections and rechecked. No remaining clipping, overlap, placeholder art, internal IDs or unreadable geometry was observed in this capture set.

## Source captures

The 25 visual QA scenario images are retained under [`../build/visual-qa/swordplay/`](../build/visual-qa/swordplay/). Regenerate that set with `scripts/capture_swordplay_visual_qa.ps1`; each scenario receives a separate profile so unlocks and saves cannot contaminate another capture.

## Android package discovery regression

The installed Android build reproduced a package-discovery defect on `emulator-5554`: Content / Mods listed only Core, even though Swordplay's manifest and definitions were present in the APK. The scanner had checked a globalized absolute filesystem path before enumerating a `res://` package root; that path is not a physical directory in an Android APK. It now opens the resource root with `DirAccess.open()` and enumerates that directory directly.

After rebuilding and reinstalling the APK, the same screen showed Swordplay under Official Content with its Enable control. Enabling it changed the control to Disable and persisted `swordplay` in the profile's enabled package list. The Android runtime captures are `repro-content-mods.png` (before the fix), `fixed-content-mods.png` (package visible), and `enabled-content-mods.png` (package enabled), in the retained capture directory above.
