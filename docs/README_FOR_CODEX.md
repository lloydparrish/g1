# Project Arcanist — Codex Reference Bundle

This bundle accompanies the Project Arcanist prompts supplied separately by the user.

## Authoritative files

1. `PROJECT_ARCANIST_DESIGN_CONTRACT.md`
   - The authoritative v0.1 game-design and architecture contract.
   - Treat requirements marked as architectural/non-negotiable as constraints across future implementation work.
   - Where Prompt 1 intentionally implements only a subset of final content, the prompt controls the immediate implementation scope while this document controls the intended architecture and game identity.

2. `Project_Arcanist_UI_Reference.png`
   - Visual design reference and acceptance target.
   - Preserve its overall design language rather than reproducing the static screenshot literally at every size.
   - The Prompt 6 desktop battle HUD keeps exactly three persistent lower sections: World Map, Character / Abilities, and Inventory / Equipment. Spellbooks remain reachable through the Inventory tabs. The persistent map records only the chosen journey, with an unknown `?` node until the final encounter; the post-objective picker alone reveals future choices.
   - Android landscape keeps a contextual three-section dock with touch-sized controls and safe-area handling. The ability web remains a dedicated larger subview.

## Priority when resolving ambiguity

1. The user's current Codex prompt.
2. This design contract for game identity and architectural rules.
3. The UI reference for presentation intent.

Do not silently contradict an established design rule. If implementation constraints require a deviation, document the deviation and choose the narrowest solution that preserves future extensibility.

## BUILD ARTIFACT POLICY

- Git stores historical source states; generated executables are not long-term version history.
- Keep the latest verified Windows build at `build/windows/current/ProjectArcanist.exe` and Android APK at `build/android/current/ProjectArcanist.apk`.
- Keep at most two immediately preceding verified build sets when they help comparison or regression testing. Delete older redundant executables, APKs, duplicate export folders, and temporary QA outputs after verification.
- Old versions are reproduced by checking out their Git commit and rebuilding.
- `releases/ProjectArcanist.apk` is the explicitly designated, tracked release artifact and is exempt from generated-build cleanup.
- Preserve screenshots cited by permanent QA documents. Keep uncited captures and temporary logs only while they are needed for active verification.
