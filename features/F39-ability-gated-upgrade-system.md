# F39 — Ability-Gated Upgrade System (Backlog FB1 / FB7)

**Status:** Not started. Scope unconfirmed — ask before building (Operating Principle 4, `instructions-ai.txt`).

## Goal
FB1 in `feature.md`'s Backlog: "Ability-gated upgrade system spanning all 7 levels." Currently abilities
exist but are ad hoc, not a system:
- Double jump: `player.gd` `has_double_jump`, granted per-level via `level_base.gd`'s `grants_double_jump`
  export (on from Level 6 onward). Permanent once granted, but re-derived from a scene export every level
  load, not stored centrally.
- Spin dash: `player.gd` `has_spin_dash`, granted by touching an `AirFryer` pickup. Does **not** persist
  across a scene change (`change_scene_to_file`) — each level needing it places its own Air Fryer pickup
  (e.g. Level 2 needed one before the Queso Grande arena, see F18).
- Tomato seed power: same pattern as spin dash — a timed pickup (`TomatoPowerup.tscn`), doesn't persist.
- Climbing: not gated at all — available in any `ClimbZone` regardless of prior progress.

FB7 ("spin dash upgrade, unlocked via Air Fryer") is effectively already built as the Air Fryer mechanic
above — don't rebuild it, but do decide whether this system should make it *persistent* instead of
per-pickup-per-level.

## Before building: confirm scope with the user
This item has no confirmed design, unlike everything already shipped. Concretely ask:
1. **Persistence:** should spin dash / tomato power become permanently unlocked once first picked up
   (stored in `GameProgress`, like `total_beans_collected`), instead of needing a fresh pickup every level?
   Or is the current per-level-pickup pattern intentional and this item is just about *gating content*
   behind abilities, not persistence?
2. **New gated content:** does this item include designing new optional areas/paths in existing levels
   that require a specific ability to reach (the actual "Metroidvania-lite" implication of "ability-gated")?
   If yes, that's new level-design scope requiring its own go-ahead per level — don't invent it unprompted.
3. **HUD:** does the existing ability-slot HUD icon (`level_base.gd`'s `get_ability_hud_slot()`, built for
   F32) need to become a persistent multi-ability inventory display, or stay as-is (one slot, current level
   only)?

## If confirmed as "make abilities persistent" (smallest viable scope)
1. `scripts/game_progress.gd`: add `unlocked_abilities: Dictionary` (or individual bools —
   `has_spin_dash`, `has_tomato_power`), persisted via the same `FileAccess.store_var()` pattern already
   used for `total_beans_collected`.
2. `player.gd`: in `_ready()`, read persisted flags from `GameProgress` and apply them, in addition to
   (not instead of) the existing pickup-triggered grants — so a fresh pickup still works but isn't strictly
   required after the first one.
3. Existing pickups (`air_fryer.gd`, `tomato_powerup.gd`) additionally call
   `GameProgress.unlock_ability("spin_dash")` etc. on first collection.
4. Double jump: fold `grants_double_jump` into the same persisted-flag system for consistency, OR leave it
   as the existing per-level export if the user wants Level 1-5 to stay single-jump regardless of later
   unlocks (re-confirm this against the existing tuning note in F16 — Levels 1-5's jump gaps were sized for
   single-jump on purpose).

## If confirmed to include new gated content
Do not scope this without the user naming specific levels/areas — each level's layout is already tuned
(F21/F22/F24) and adding a gated branch is real design work, not a mechanical change.

## Verification pattern (matches project convention)
Headless script instantiating a level twice: once with `GameProgress` fresh (no abilities), once after
setting the persisted flag, confirming the player's `has_spin_dash`/`has_double_jump` matches expectation
on `_ready()` without needing a pickup in the second case. See `feature.md` F25/F31 for the established
"boot through a real scene, not `--script`, when an autoload is involved" gotcha.
