# Planned Implementations Ledger

This ledger preserves approved design work whose dependencies or implementation window are not available yet. It is a scoped queue, not permission to implement every listed idea in any future update.

## Workflow for future Codex work

Every implementation prompt must begin by reviewing this file. For each `BLOCKED` entry, check whether the named dependency now exists. If it does, change the entry to `READY`, decide whether the current prompt includes it, and implement only when it is in scope and safe. Test the implementation and then record `IMPLEMENTED` with the code/document reference. Leave unmet dependencies `BLOCKED`. Do not activate unrelated entries merely because they are listed here. Preserve the user's approved intent and ask before making a substantial design choice that is not specified in the entry or current prompt.

Statuses:

- `BLOCKED` — an explicit dependency or scope gate is not satisfied.
- `READY` — dependencies are satisfied and a future in-scope prompt may implement it.
- `IMPLEMENTED` — shipped in the referenced implementation and verified.

## Swordplay Content Package

### SWP-001 — Swordplay package scope

- **Status:** BLOCKED
- **Origin:** User-approved Swordplay planning in the Endless Map Progression update; implementation intentionally deferred to a later user-led Swordplay design prompt.
- **Intended behavior:** Develop Swordplay first as a modular official content package, test and balance it independently, and consider physically promoting successful content into Core later while retaining stable IDs.
- **Dependencies:** A user-led design pass that finalizes package scope and any open content design questions; the existing modular package, tag, prerequisite, reward, evolution and package-injection foundation.
- **Reason deferred:** This update establishes endless-map infrastructure and explicitly does not begin Swordplay.
- **Implementation notes:** Swordplay covers sword-based martial combat, including Sword, Rapier, Greatsword and useful variants. Aim for about 15–20 distinct base techniques and about 25–40 concepts after advanced forms/combinations. Avoid abilities that differ only by small damage percentages or duplicate gameplay roles. Package scope may include generic and unique weapons, abilities, passives, relics, artifacts, enemies, bosses and three characters. Do not turn this into a crafting ladder.

### SWP-002 — Approved Swordplay base techniques

- **Status:** BLOCKED
- **Origin:** User-approved concepts in the Endless Map Progression update.
- **Intended behavior:** Design these as distinct tactical techniques using existing combat rules and new reusable simulation mechanics only where needed:
  1. **Lunge** — move toward a target and attack.
  2. **Cleave** — attack multiple adjacent enemies in an arc.
  3. **Pommel Strike** — a low-damage disruptive or stunning strike.
  4. **Whirlwind** — a costly Stamina technique that attacks surrounding adjacent enemies.
  5. **Execute** — a powerful attack against a sufficiently weakened enemy.
  6. **Impale** — thrust through the first target and damage a target behind it.
  7. **Advance** — attack and move into the target's tile when appropriate.
  8. **Reposition** — attack, then make controlled movement.
  9. **Driving Blow** — attack plus knockback.
  10. **Blade Rush** — travel multiple tiles in a line and strike the first valid target.
  11. **Parry** — negate or reduce an incoming melee attack; base Parry does not automatically counterattack.
  12. **Thrust** — extended straight-line melee reach.
  13. **Feint** — set up greater vulnerability to a subsequent sword attack.
  14. **Disengage** — strike while retreating or repositioning.
  15. **Overhead Strike** — a heavy, armor-breaking purpose, not a generic damage button.
  16. **Sweeping Blow** — broad frontal attack emphasizing displacement or knockback.
  17. **Reckless Swing** — a powerful attack or area effect with a meaningful defensive tradeoff.
- **Dependencies:** SWP-001 and the user-led Swordplay design pass.
- **Reason deferred:** No Swordplay techniques or mechanics are to be implemented in the Endless Map update.
- **Implementation notes:** Deflect was explicitly considered and rejected; do not add it. Use cooldowns and Stamina costs where suitable. Spatial mechanics may include knockback, swaps, advancing into vacated tiles, retreating and repositioning. Not every technique needs an evolution. Rare abilities may combine mechanics from two distinct techniques. Evolution remains run-specific. Do not inflate the list with near-duplicates.

### SWP-003 — The Duelist

- **Status:** BLOCKED
- **Origin:** User-approved Swordplay character concept in the Endless Map Progression update.
- **Intended behavior:** One-handed Sword precision/dueling archetype, likely leaning Dexterity and Perception, without a required unique character power. Intended unlock: successfully Parry an authored number of attacks within a stage or run.
- **Dependencies:** SWP-001, Swordplay's Parry mechanic and a user-approved/finalized unlock count during Swordplay design.
- **Reason deferred:** The Swordplay package and its Parry mechanic do not exist; the exact count is intentionally open.
- **Implementation notes:** Keep the existing generic character unlock/prerequisite system. Do not invent the count before the Swordplay implementation pass.

### SWP-004 — The Fencer

- **Status:** BLOCKED
- **Origin:** User-approved Swordplay character concept in the Endless Map Progression update.
- **Intended behavior:** Rapier mobility and extended-melee-range archetype emphasizing thrusts, lunges, retreats and repositioning, without a required unique character power. Intended unlock: perform an authored number of Swordplay reposition/movement actions during a stage or run.
- **Dependencies:** SWP-001 and finalized technique definitions/action tracking; unlock count to be decided during Swordplay implementation.
- **Reason deferred:** Swordplay movement techniques do not exist yet, and the exact count is intentionally open.
- **Implementation notes:** Use generic character/unlock data and production movement-action state, not a UI-only counter.

### SWP-005 — The Berserker and combined-turn power

- **Status:** BLOCKED
- **Origin:** User-approved Swordplay character concept in the Endless Map Progression update.
- **Intended behavior:** Greatsword, aggressive/heavy sword identity and a unique power usable once per map: choose two valid attack actions and execute them as one simultaneous/combined turn action. Actions may be two basic attacks, two abilities or one of each; they may target different enemies. This is not merely double damage.
- **Dependencies:** SWP-001; the Sword Lord of the Goblin Horde boss and unlock in SWP-006; a turn-resolution design that can combine attacks safely.
- **Reason deferred:** The Swordplay techniques, boss and character are intentionally absent in this update.
- **Implementation notes:** Resolve cases where the first selected action changes or invalidates the second action's target or state. Preserve ordinary action validation and deterministic simulation ownership. Do not resolve the second action against stale target assumptions.

### SWP-006 — Sword Lord of the Goblin Horde

- **Status:** BLOCKED
- **Origin:** User-approved rare boss and unlock concept in the Endless Map Progression update.
- **Intended behavior:** A rare Stage-6-only boss contributed by the Swordplay package. It is an extremely skilled fantasy goblin sword master, becomes more likely at deeper maps while remaining special, uses Swordplay techniques intelligently, and examines mastery of those mechanics instead of relying only on enormous HP. Defeating it unlocks The Berserker.
- **Dependencies:** SWP-001, Swordplay enemy family/techniques, the data-driven Stage-6 boss pool and generic permanent character unlock system.
- **Reason deferred:** Swordplay content is not in scope; the foundation's boss injection and depth weighting are now present for a later package.
- **Implementation notes:** Keep the stable content identity package-scoped and make theme/depth/package eligibility data-driven. Do not register an inert or broken canonical boss definition before its enemy, techniques and unlock target exist.

### SWP-007 — Generic and unique named weapons

- **Status:** BLOCKED
- **Origin:** User-approved Swordplay weapon rules in the Endless Map Progression update.
- **Intended behavior:** Use straightforward generic Sword, Rapier, Greatsword and other useful sword variants, contrasted with memorable rare named weapons that grant/alter abilities, change technique behavior, affect positioning, create unusual build rules or otherwise have a distinct mechanical identity.
- **Dependencies:** SWP-001 and weapon/ability interactions selected during the Swordplay design pass.
- **Reason deferred:** Swordplay equipment is intentionally not being authored here.
- **Implementation notes:** Avoid Iron Sword → Steel Sword → +1 → +2 stat ladders and intricate crafting. The future Swordplay implementation may design approximately 8–12 distinctive named weapons autonomously if they meet these rules.

### SWP-008 — Swordplay relics and artifacts

- **Status:** BLOCKED
- **Origin:** User-approved Swordplay scope in the Endless Map Progression update.
- **Intended behavior:** Consider about 8–12 sword-oriented relic/passive augments and 3–5 rarer artifacts. Relics should be buffs or meaningful run-changing augments rather than ordinary equipment slots/stat sticks; artifacts may be more dramatic/build-altering.
- **Dependencies:** SWP-001 and the Swordplay design pass.
- **Reason deferred:** No Swordplay content families are being created in this update.
- **Implementation notes:** Exact designs are left to the Swordplay implementation prompt. Use the existing run-scoped relic/artifact and package systems.

### SWP-009 — Swordplay fantasy enemy family

- **Status:** BLOCKED
- **Origin:** User-approved Swordplay scope and examples in the Endless Map Progression update.
- **Intended behavior:** Add approximately 8–10 fantasy-oriented enemies plus the Sword Lord. Approved racial/theme space includes Goblins, Kobolds and Orcs. They may form a coherent martial family and appear individually in appropriate encounter pools. Concepts include mobile goblin/fencer types, heavy orc greatsword fighters, precise kobold duelists, ordinary goblin swordsmen and elite bladeguards.
- **Dependencies:** SWP-001, Swordplay mechanics used by the enemies and eligible map/stage encounter pools.
- **Reason deferred:** No Swordplay enemies or mechanics are to be authored in this update.
- **Implementation notes:** The names are illustrative unless approved during Swordplay design. Enemy behavior should demonstrate mechanics where suitable; do not create a disconnected pile of theme-only stat variants.

### SWP-010 — Swordplay hybrid content blocked on absent families

- **Status:** BLOCKED
- **Origin:** Cross-build design rule established in the Content Foundation and reiterated in the Endless Map Progression update.
- **Intended behavior:** Swordplay may later define genuine hybrid abilities, including a Sword + Blood concept when its behavior actually depends on Blood mechanics.
- **Dependencies:** SWP-001 and the specific external content/mechanics required by each hybrid definition (for example, a Blood system for a Sword + Blood technique).
- **Reason deferred:** A missing content family cannot be replaced with a fake tag check, unrelated effect, broken partial definition or substitute mechanic.
- **Implementation notes:** Keep conditional standalone hybrids distinct from true ability evolutions. Record specific user-approved hybrids here when their intended behavior and dependencies are approved. Do not treat this general rule as approval to invent a new hybrid ability.
