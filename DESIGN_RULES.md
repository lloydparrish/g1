# Project Arcanist design rules

The full authoritative contract is in [`docs/PROJECT_ARCANIST_DESIGN_CONTRACT.md`](docs/PROJECT_ARCANIST_DESIGN_CONTRACT.md). Preserve these rules whenever content or systems are expanded.

## Authority and simulation

- The simulation owns all game state. The renderer displays it; input becomes explicit game commands.
- The simulation must run headlessly and reproduce the same result from the same seed, saved state and player commands.
- Waiting for player input never advances game time. Resolve scheduled actors after each committed player action, then stop at the player's next decision.
- Save enough state to resume the current encounter, including the random generator state. Version serialized data and test round trips.

## Content and rules

- Add game content as definitions composed from reusable costs, targeting, effects, conditions, triggers and modifiers. Avoid a script per spell, creature or item.
- Resources and damage types are registries. Do not assume Mana or a closed set of damage types is the whole system.
- Status and environmental interactions belong to reusable rules. Spells may cause them but must not own the only implementation of a world interaction.
- Factions and creature footprints determine hostility and occupancy. Large bosses use ordinary movement, targeting and damage rules where possible.
- Natural ability progression follows explicit prerequisites. Rare knowledge comes from discoveries such as spellbooks and shrines, never from unrelated automatic progression.
- Summons occupy real battlefield cells when appropriate and consume their defined Command. Do not add a global summon-count cap.
- Artifacts are persistent run modifiers and do not consume a fixed artifact-slot allowance.
- Equipment supports the defined nine slots; two-handed weapons reserve both hand slots. Keep ordinary inventory at 30 items.

## Player-facing design

- Design for landscape Android displays first. Touch and mouse share clear tap-to-move, tap-ability-then-target and cancel behavior.
- Give the battlefield the greatest practical space. Keep health/resources, available actions, turn order and important statuses visible; put extended inspection and build screens in contextual overlays.
- Keep text, targets and controls readable and comfortably tappable. Do not expose internal IDs, calculations, test controls, raw data, temporary copy or engine defaults in normal play.
- Completing an objective does not force a transition. Let the player explore and collect rewards, then choose the next location.

## Verification bar

- A vertical slice is complete only when the production entry point connects selection, multiple stages, combat, rewards, route choice, the large boss, victory and death.
- Cover deterministic rules, save/resume, content references, AI/factions, objectives, rewards, equipment and summon behavior with headless checks; exercise a representative production-path playthrough and death.
- Launch the real game, inspect screenshots at desktop and phone landscape sizes, and fix visible layout or readability defects.
- Mark environment/device or platform checks as pending when they have not been performed. A simulator or headless test does not count as native Android acceptance.
