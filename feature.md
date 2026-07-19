# Cornchip Day — Feature Specification

## MVP Vertical Slice Features

### F1 — Player Movement
- Run left/right via keyboard (arrow keys and/or A/D)
- Single jump (Space)
- No double-jump or other upgrades in the MVP — those arrive later as unlockable, level-gating abilities (see Phase 2 in `plan.md`)

### F2 — No-Fail Obstacle Interaction
- One obstacle type for the MVP: thrown "mild" salsa (per `game-brief.txt`)
- On contact: a comedic visual reaction (e.g. Cornchip wilts or slips), then a brief respawn at the last safe point
- No lives counter, no game-over screen, no score penalty of any kind

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
- **FB10** — Air Fryer collectible: grants Cornchip the spin-dash ability (FB7) once picked up.
- **FB11** — Tomato collectible: temporary power-up letting Cornchip fire seeds at enemies from range for a short duration.
- **FB12** — Lettuce as the main collectible token: scattered throughout each level (not just a single end-of-level pickup), functioning as the game's primary currency/collectible, alongside the per-level boss-guarded ingredient. **Open question:** does this replace the "one ingredient per level" model from the original brief, or sit alongside it as a separate collectible layer (see game-brief.txt Open Questions)?

## Explicitly Out of Scope (MVP)
- Touch/mobile input
- Any lives, game-over, or fail state
- Text-based instructions or dialogue
- Multiplayer
