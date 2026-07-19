# Cornchip Day — Feature Specification

## MVP Vertical Slice Features

### F1 — Player Movement
- Run left/right via keyboard (arrow keys and/or A/D)
- Single jump (Space)
- No double-jump or other upgrades in the MVP — those arrive later as unlockable, level-gating abilities (see Phase 2 in `plan.md`)

### F2 — Obstacle Interaction & Lives
- One obstacle type for the MVP: thrown "mild" salsa (per `game-brief.txt`)
- On contact: a comedic visual reaction (e.g. Cornchip wilts or slips), then a brief respawn at the last safe point -- this per-hit feel is unchanged
- Every hit also costs one of 3 lives, shown as icon-only HUD (no numbers/text) in the top-left. At 0 lives, the whole level restarts from the beginning with lives reset to 3 -- no game-over screen. `level1.gd` owns the life count; `player.gd` just emits `player_hit` on every hit regardless of source, so any future hazard gets lives-tracking for free.

### F3 — Ingredient Collection & Level Completion
- The level's ingredient is no longer just sitting out in the open — it spawns at the boss's position once the boss is defeated (see F5)
- Picking it up triggers a clear, purely visual celebration — no text
- Defines the vertical slice's "complete" state

### F5 — Stomp-to-Defeat Combat & Boss Battles
- Cornchip's baseline way to interact with enemies: jumping on them from above defeats them (detected via the player's fall velocity and position relative to the enemy at contact, not precise collision-normal math)
- Touching an enemy any other way (from the side, while not falling onto it) triggers the same stun-and-respawn as any obstacle, via the existing `hit_by_obstacle()`
- Implemented as a reusable `boss.gd` (patrol between two points, periodic projectile attack, N-hit health, defeat animation) rather than one script per boss, since more bosses are already planned
- The vertical slice's level now ends with a real boss fight: Hot Sauce patrols, fires a horizontal projectile at intervals, and takes 3 stomps to defeat; defeating him spawns the level's ingredient
- Promoted out of the backlog (was FB8/FB9) once actually built — see `plan.md` for status

### F6 — Little Enemies
- Cheese now appears as a regular in-level enemy (resolved from the boss-vs-enemy open question in `characters.txt`): same `boss.gd` script as bosses, but configured with 1 hit point, no projectile, and a tighter patrol range
- Defeated the same way as any boss (stomp from above); a side touch costs a life like any obstacle
- Known simplification: the brief's "puts Cornchip to sleep for 10 seconds" effect isn't built yet -- Cheese currently uses the generic hit reaction

### F7 — Scattered Lettuce Tokens
- Multiple lettuce pickups placed throughout the level (reusing `Ingredient.tscn`/`ingredient.gd`, tagged with the `lettuce_token` group instead of ending the level)
- Separate from the boss-dropped level ingredient, which is unchanged
- Counted in `level1.gd` (`lettuce_tokens_collected`); no on-screen counter yet -- flagged as a follow-up, not built this pass

### F8 — Air Fryer Power-Up (Spin Dash)
- A pickup (placeholder art) that grants Cornchip a spin-dash: pressing Up (`ui_up`, already bound by default -- avoided hand-editing the InputMap) triggers ~1 second where touching any enemy defeats it instead of hurting him, same code path as a stomp
- Visual feedback is a color tint on the sprite for now, not a real spin animation -- flagged as future art/polish, not a functional gap

### F4 — First-Pass Art
- AI-generated Cornchip sprite: idle, run, jump, and "hit" reaction states
- AI-generated sprite for the one obstacle type
- Simple background/tileset for the single level
- **Pipeline note:** sprites are generated on a solid magenta (`#FF00FF`) background rather than requested as "transparent" — diffusion image models can't natively output real alpha, so a transparency request just yields a checkerboard baked into opaque pixels; shadows are explicitly forbidden in the prompt too, since a soft shadow blends with the magenta rather than matching it and survives chroma-keying as a smudge. Each character is generated as a single 8-pose grid image (idle, idle variant, 2-frame move cycle, 2-frame signature action, hit reaction, celebrate/defeated) rather than separate stills, covering Cornchip plus the four confirmed bosses (Hot Sauce, Avocado, Cheese, Salsa Bowl) ahead of their Phase 2 implementation. `tools/generate-sprites.ps1` produces the raw grid images; `tools/crop-sprites.ps1` keys out the magenta, isolates each of the 8 poses as its own blob, and normalizes them onto a shared per-character canvas (bottom-anchored) so frame-switching doesn't jitter. The salsa obstacle and lettuce ingredient stay single still images since "8 poses" doesn't apply to a static prop.

## Backlog (Post-MVP, Not Yet Scheduled)
- **FB1** — Ability-gated upgrade system spanning all 7 levels
- **FB2** — Remaining 6 levels, each with its own ingredient and obstacle puns
- **FB3** — Wrap final-boss battle and end-game reconciliation scene (depends on FB9's boss-battle structure)
- **FB4** — Full art pass across all characters/levels for visual consistency
- **FB5** — Audio/music/SFX pass
- **FB6** — 2-player local co-op with Cheeto
- **FB7** — "Spin dash" upgrade: Cornchip spins rapidly, letting him plow through enemies unharmed while they comically fly off-screen (front- or back-flipping). Unlocked via the Air Fryer collectible (see below). Candidate for the ability-gated upgrade system (FB1).
- ~~FB8 — Stomp-to-defeat~~ and ~~FB9 — Per-level boss battles~~ — built, see F5. Remaining boss-battle work: Avocado, Cheese, Salsa Bowl still need their own boss instances (art is ready), and further stomp-triggered upgrades (beyond the baseline stomp) are still backlog.
- ~~FB10 — Air Fryer collectible~~ — built, see F8.
- **FB11** — Tomato collectible: temporary power-up letting Cornchip fire seeds at enemies from range for a short duration. Still not built.
- ~~FB12 — Lettuce as the main collectible token~~ — built, see F7. Resolved as an additional collectible layer alongside the per-level boss-guarded ingredient, not a replacement for it (see game-brief.txt Resolved Questions).
- **FB13** — On-screen lettuce token counter (icon + count, no reading-heavy number if avoidable). `level1.gd` already tracks the count; only the display is missing.
- **FB14** — Cheese's "sleep for 10 seconds" effect, replacing the generic stumble reaction it currently uses.

## Explicitly Out of Scope (MVP)
- Touch/mobile input
- Text-based instructions or dialogue
- Multiplayer
