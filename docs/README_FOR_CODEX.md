# Project Arcanist — Codex Reference Bundle

This bundle accompanies **Codex Prompt 1** supplied separately by the user.

## Authoritative files

1. `PROJECT_ARCANIST_DESIGN_CONTRACT.md`
   - The authoritative v0.1 game-design and architecture contract.
   - Treat requirements marked as architectural/non-negotiable as constraints across future implementation work.
   - Where Prompt 1 intentionally implements only a subset of final content, the prompt controls the immediate implementation scope while this document controls the intended architecture and game identity.

2. `Project_Arcanist_UI_Reference.png`
   - Visual design reference and acceptance target.
   - Preserve its overall design language rather than blindly reproducing every desktop-sized panel on a phone.
   - Android landscape gameplay should prioritize battlefield area and use contextual/collapsible panels or separate full-screen menus as needed.

## Priority when resolving ambiguity

1. The user's current Codex prompt.
2. This design contract for game identity and architectural rules.
3. The UI reference for presentation intent.

Do not silently contradict an established design rule. If implementation constraints require a deviation, document the deviation and choose the narrowest solution that preserves future extensibility.
