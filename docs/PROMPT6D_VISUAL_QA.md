# Prompt 6D UI and Build Verification

## Icon and label spacing

Desktop captures show the corrected Cleave entry at the normal, large, and reduced window sizes:

- `build/visual-qa/p6d-abilities-cleave/1920x1080.png`
- `build/visual-qa/p6d-abilities-cleave-2560/2560x1440.png`
- `build/visual-qa/p6d-abilities-cleave-reduced/1280x720.png`
- `build/visual-qa/p6d-passives/1920x1080.png`
- `build/visual-qa/p6d-known/1920x1080.png`

The same icon-slot layout was reviewed in mobile Cleave, Passives, and Known captures:

- `build/visual-qa/p6d-mobile-cleave/2400x1080.png`
- `build/visual-qa/p6d-mobile-passives/2400x1080.png`
- `build/visual-qa/p6d-mobile-known/2400x1080.png`

Both mobile character-card cases are retained:

- `build/visual-qa/p6d-mobile-character-no-effects/2400x1080.png`
- `build/visual-qa/p6d-mobile-character-effects/2400x1080.png`

The no-effects line has bottom padding, and the effects case shows all three entries. The card also moves attributes down when the resource bars need more vertical room. The movement pad relocates into the battlefield margin when an expanded dock would otherwise place it over the character card.

## Installed and exported builds

- Windows debug build: `build/windows/current/ProjectArcanist.exe`. It launched and produced `build/visual-qa/p6d-windows-current/1920x1080.png`.
- Android debug APK: `build/android/current/ProjectArcanist.apk`, 27.4 MiB, package `com.projectarcanist.game`; package metadata and debug signature verified. SHA-256: `D0A00AEB174EF91D103445EFF94B15C67A05277AB903C1A2430FF505E8317EF4`.
- The APK was copied to the explicitly tracked release path `releases/ProjectArcanist.apk`, installed over the existing app on `emulator-5554`, and launched in landscape. On the final installed build, opening Character / Abilities showed the touch-sized ability rows and fully visible “No active effects” line. A D-pad touch moved Jim, reduced Stamina from 59 to 58, and recorded the movement in Recent Events. The installed-build screenshots are `build/visual-qa/android-emulator/p6d-final-character.png` and `build/visual-qa/android-emulator/p6d-final-touch.png`.

## Automated verification

`scripts/arcanist.ps1 Test` passed all eight suites: core 62, production flow 30, mobile acceptance 32, Prompt 6A UI 64, progression/inventory 52, playtest regressions 43, balance 6, and combat presentation 37. The Prompt 6A UI suite now asserts icon-slot spacing at both card sizes, resource/attribute separation, no-effects bottom padding, and all active-effect rows.

Godot printed its Windows root-certificate-store warning during test, export, and capture runs. The test suite and both exports completed successfully.

## Artifact cleanup

The ignored build tree had no tracked build outputs; `releases/ProjectArcanist.apk` is the intentional tracked release. The 6C APK was moved to `build/android/previous-1/ProjectArcanist.apk`. The stable current Windows and Android output locations are now used by the project scripts. Inactive duplicate Windows exports for the generic, P4, Prompt 6A, and Prompt 6B builds were removed. Prompt 6C remains as the immediate prior Windows comparison; P5 remains because its executable is still running. Together with the new current build, these are the two older Windows builds retained for now. Temporary root logs, diagnostics, emulator images, and uncited visual captures were pruned where they were not in use. Existing screenshots cited by the QA records were preserved.

The pre-cleanup audit found four Prompt 5 screenshot paths already absent from the ignored build tree (`2340x1080/normal-battle.png`, `combat-history/1920x1080.png`, `full-inventory/1920x1080.png`, and `quickbar-empty/1920x1080.png`). They were not removed by this cleanup. Two active emulator host logs could not be deleted while the emulator held them open.
