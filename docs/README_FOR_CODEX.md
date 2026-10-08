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
   - The current HUD keeps exactly three persistent lower sections: World Map, Character / Abilities, and Inventory / Equipment. Spellbooks remain reachable through Inventory tabs. The World Map records visited maps, highlights the current map and shows only one unknown `?` next destination until the six-stage map is complete. Later maps are revealed one at a time.
   - Android landscape keeps a contextual three-section dock with touch-sized controls and safe-area handling. The ability web remains a dedicated larger subview.

3. `CONTENT_FOUNDATION.md`
   - Canonical package identity/loading, stable-ID promotion, tags, prerequisites, weighting, unlocks, rewards, exploration loot, scripting boundary and artifact policy for the content foundation.
   - Consult it together with the design contract before changing content definitions, profile progression, save references or content UI.

4. `ADVANCED_CHARACTER_SCALING_REVIEW.md`
   - Source-record comparison for the five advanced class profiles against the four simple starters. Final titles and unlock requirements are established; profile scaling remains unchanged.

5. `CONTENT_FOUNDATION_VISUAL_QA.md`
   - Retained desktop/mobile captures and manual visual QA notes for the content foundation, including screenshots of the installed nine-portrait Treatment A set.

6. `ENDLESS_MAP_PROGRESSION.md`
   - Canonical Map-versus-Stage loop, endless generation, map themes and package injection, Stage-6 boss eligibility, depth scaling, rewards, visited-map presentation, autosave/resume and death summaries.

7. `ENDLESS_MAP_VISUAL_QA.md`
   - Reviewed desktop/mobile captures for the endless map, Stage-6 boss, map reveal, long history, resume flow, deep counters and run summary.

8. `../PLANNED_IMPLEMENTATIONS.md`
   - Persistent queue for approved ideas deferred until their dependencies exist, currently including the explicitly blocked Swordplay package scope.

## Priority when resolving ambiguity

1. The user's current Codex prompt.
2. This design contract for game identity and architectural rules.
3. The UI reference for presentation intent.

Do not silently contradict an established design rule. If implementation constraints require a deviation, document the deviation and choose the narrowest solution that preserves future extensibility.

## Required opening review for implementation work

Begin every future implementation prompt by reviewing `PLANNED_IMPLEMENTATIONS.md`. For each `BLOCKED` entry, verify whether its dependency now exists. If satisfied, mark it `READY`, determine whether the current update includes it, and implement only when in scope and safe. Test it and then record `IMPLEMENTED` with the relevant code/document reference. Leave unresolved dependencies `BLOCKED`; do not implement unrelated entries.

For work touching maps, stages, bosses, active-run saves, rewards or the World Map, also read `ENDLESS_MAP_PROGRESSION.md`. For packages, prerequisites, tags, unlocks or stable save identities, also read `CONTENT_FOUNDATION.md`.

## BUILD ARTIFACT POLICY

- Git stores historical source states; generated executables are not long-term version history.
- Keep the latest verified Windows build at `build/windows/current/ProjectArcanist.exe` and Android APK at `build/android/current/ProjectArcanist.apk`.
- Keep at most two immediately preceding verified build sets when they help comparison or regression testing. Delete older redundant executables, APKs, duplicate export folders, and temporary QA outputs after verification.
- Old versions are reproduced by checking out their Git commit and rebuilding.
- `releases/ProjectArcanist.apk` is the explicitly designated, tracked release artifact and is exempt from generated-build cleanup.
- Preserve screenshots cited by permanent QA documents. Keep uncited captures and temporary logs only while they are needed for active verification.
- Do not create permanent timestamped executable copies for each update. Before removing a generated build, check whether it is running and confirm it is neither a documented release nor a QA artifact still needed for current review. Never apply this cleanup rule to authored source assets, canonical fixtures, saves or design documents.
