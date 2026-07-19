# Cornchip Day — Feature Specification

## MVP Vertical Slice Features

### F1 — Player Movement
- Run left/right via keyboard (arrow keys and/or A/D)
- Single jump (Space)
- No double-jump or other upgrades in the MVP — those arrive later as unlockable, level-gating abilities (see Phase 2 in `plan.md`)

### F2 — Obstacle Interaction & Lives
- One obstacle type for the MVP: thrown "mild" salsa (per `game-brief.txt`)
- On contact: a comedic visual reaction (e.g. Cornchip wilts or slips), then a brief respawn at the last safe point -- this per-hit feel is unchanged
- Every hit also costs one of 3 lives, shown as icon-only HUD (no numbers/text) in the top-left. At 0 lives, the whole level restarts from the beginning with lives reset to 3 -- no game-over screen. `level_base.gd` owns the life count; `player.gd` just emits `player_hit` on every hit regardless of source, so any future hazard gets lives-tracking for free.

### F3 — Ingredient Collection, Level Completion & Level Transition
- The level's ingredient is no longer just sitting out in the open — it spawns at the boss's position once the boss is defeated (see F5)
- Picking it up triggers a clear, purely visual celebration — no text
- Collecting it now also transitions to the next level (`level_base.gd`'s `next_level_path`, set per-level as an exported property): a boss's `_die()` calls `register_level_ingredient()` on the level root when it spawns the ingredient (since the ingredient doesn't exist yet at boss-defeat time, and the boss itself may already be freed by the time the player actually walks over and collects it seconds later)
- `level1.gd` was generalized into `level_base.gd` so every level reuses one script (same pattern as `boss.gd`), configured per-level via exported properties rather than needing a new script each time

### F5 — Stomp-to-Defeat Combat & Boss Battles
- Cornchip's baseline way to interact with enemies: jumping on them from above defeats them (detected via the player's fall velocity and position relative to the enemy at contact, not precise collision-normal math)
- Touching an enemy any other way (from the side, while not falling onto it) triggers the same stun-and-respawn as any obstacle, via the existing `hit_by_obstacle()`
- Implemented as a reusable `boss.gd` (patrol between two points, periodic projectile attack, N-hit health, defeat animation) rather than one script per boss, since more bosses are already planned
- The vertical slice's level now ends with a real boss fight: Hot Sauce patrols, fires a horizontal projectile at intervals, and takes 3 stomps to defeat; defeating him spawns the level's ingredient
- Promoted out of the backlog (was FB8/FB9) once actually built — see `plan.md` for status

### F6 — Little Enemies
- Cheese and Salsa Bowl both appear as regular in-level enemies (resolved from the boss-vs-enemy open questions in `characters.txt`): same `boss.gd` script as bosses, but Cheese is configured with 1 hit point/no projectile/tighter patrol, and Salsa Bowl with 2 hit points and a projectile (reusing `BossProjectile.tscn`) for a slightly tougher, ranged encounter
- Defeated the same way as any boss (stomp from above); a side touch or getting hit by Salsa Bowl's projectile costs a life like any obstacle
- Cheese's "puts Cornchip to sleep" effect (per the original brief, tuned down from the original 10s to 3s after testing) is now built: `boss.gd`'s `sleep_duration` export, and `player.gd`'s `put_to_sleep()` (input disabled, no life lost -- distinct from the generic hit stun). Cheese is configured with `sleep_duration = 3.0`; every other enemy/boss leaves it at the default 0 (normal hit stun).

### F7 — Scattered Bean Tokens
- Multiple bean pickups placed throughout the level (`BeanToken.tscn`, reusing `ingredient.gd`'s generic pickup logic with new placeholder art, tagged with the `bean_token` group instead of ending the level)
- Corrected from an earlier "lettuce token" naming mixup (additions.txt) -- beans are the scattered collectible currency; lettuce stays an ingredient-only concept
- Separate from the boss-dropped level ingredient, which is unchanged
- Counted in `level_base.gd` (`bean_tokens_collected`); no on-screen counter yet -- flagged as a follow-up, not built this pass

### F8 — Air Fryer Power-Up (Spin Dash)
- A pickup (placeholder art) that grants Cornchip a spin-dash: pressing Up (`ui_up`, already bound by default -- avoided hand-editing the InputMap) triggers ~1 second where touching any enemy defeats it instead of hurting him, same code path as a stomp
- Visual feedback is a color tint on the sprite for now, not a real spin animation -- flagged as future art/polish, not a functional gap

### F9 — Level 1 Rework: Jump Gaps, Length, Visual Spectacle, Arena
Direct user request ("make Level 1 grander/more epic"), covering four things at once:
- **Jump gaps:** the single continuous ground slab is now 5 separate segments (`GroundA`-`GroundD` plus `GroundArena`) with 4 real gaps between them. Falling through one is handled by `player.gd`'s new `FALL_RESPAWN_Y` check in `_physics_process` -- crossing that Y threshold calls the existing `hit_by_obstacle()`, so a missed jump costs a life exactly like any other hit rather than needing a separate mechanic. Gaps are sized (~90-100px) to stay comfortably within the player's max jump distance (~154px at full run speed) for a 5-8 year old audience.
- **Longer level:** roughly doubled in length (now ~3900 units, was ~2000), with enemies and bean-token clusters spread across the extra space rather than just padding empty ground.
- **Visual spectacle:** a layered sunset-patio background (three-band gradient sky, repeating string-light clusters, cactus silhouettes) replacing the flat sky-blue `ColorRect`, all procedural vector art -- no new paid generation for this pass.
- **Arena:** a distinct zone for the Hot Sauce fight (its own ground color, festive bunting at the entrance) so reaching him reads as arriving somewhere, not just more of the same ground.

### F4 — First-Pass Art
- AI-generated Cornchip sprite: idle, run, jump, and "hit" reaction states
- AI-generated sprites for the salsa obstacle, lettuce ingredient, and a cheese ingredient icon (all previously placeholder, now real art)
- Simple background/tileset for the single level
- **Pipeline note:** sprites are generated on a solid magenta (`#FF00FF`) background rather than requested as "transparent" — diffusion image models can't natively output real alpha, so a transparency request just yields a checkerboard baked into opaque pixels; shadows are explicitly forbidden in the prompt too, since a soft shadow blends with the magenta rather than matching it and survives chroma-keying as a smudge. Each character is generated as a single 8-pose grid image (idle, idle variant, 2-frame move cycle, 2-frame signature action, hit reaction, celebrate/defeated) rather than separate stills, covering Cornchip plus the confirmed bosses ahead of their Phase 2 implementation. `tools/generate-sprites.ps1` produces the raw grid images; `tools/crop-sprites.ps1` keys out the magenta, isolates each of the 8 poses as its own blob, and normalizes them onto a shared per-character canvas (bottom-anchored) so frame-switching doesn't jitter. Non-character props stay single still images since "8 poses" doesn't apply to a static object.
- **Pipeline hardening (post-Level-1):** generation requests now attach existing character art (Cornchip, Hot Sauce) as reference images alongside the text prompt, for style consistency on new characters rather than relying on prompt wording alone. The grid-slicer clusters rows by detecting Y-gaps instead of assuming a fixed 2-row layout, since the model doesn't reliably honor the requested 4x2 arrangement (Queso Grande came back as 2x4). Transparent pixels are now zeroed on RGB as well as alpha -- previously alpha=0 was correct but the color channels still had magenta baked in underneath, harmless in Godot but sloppy. The crop script was also fixed after it briefly reprocessed and corrupted every already-finalized frame by running its "crop to largest blob" pass against files it had already produced; it now refuses to touch its own prior output.
- Queso Grande and Jalapeño (Level 2 boss/enemy) art generated and confirmed by the user -- clear to build into scenes.

### F10 — Level 2 (Nacho Kitchen)
- First level built from the confirmed Bestiary by Level plan. Boss: Queso Grande (3-hit, fires a cheese-glob that slows Cornchip instead of costing a life -- a new hazard type, see `scripts/slow_projectile.gd` and `player.gd`'s `apply_slow()`). Enemies: Jalapeño (new, 1-hit melee) and Cheese (returning, its sleep effect already live).
- Its own ingredient: `CheeseIngredient.tscn` (new, distinct sprite from Level 1's lettuce), dropped by Queso Grande on defeat, same as Hot Sauce's pattern.
- Ground has 2 real jump gaps, shorter overall than Level 1's "epic" length (that treatment was specific to Level 1 as the onboarding level).
- Nacho-yellow layered background (gradient sky, tortilla-chip and cheese-drip decorations), same procedural-art approach as Level 1.
- `next_level_path` points to `Level3.tscn`, which doesn't exist yet -- matches the same forward-declared pattern Level 1 used for Level 2 before it existed.

## Backlog (Post-MVP, Not Yet Scheduled)
- **FB1** — Ability-gated upgrade system spanning all 7 levels
- ~~FB2 — Remaining 6 levels~~ — Level 2 (Nacho Kitchen) built, see F10. Guac Stand, Market Tomatoes, Frosty Fridge, Sizzling Griddle, and the Wrap finale still to go — see `characters.txt` Bestiary by Level for the confirmed roster/order.
- **FB3** — Wrap final-boss battle and end-game reconciliation scene (depends on FB9's boss-battle structure)
- **FB4** — Full art pass across all characters/levels for visual consistency
- **FB5** — Audio/music/SFX pass
- **FB6** — 2-player local co-op with Cheeto
- **FB7** — "Spin dash" upgrade: Cornchip spins rapidly, letting him plow through enemies unharmed while they comically fly off-screen (front- or back-flipping). Unlocked via the Air Fryer collectible (see below). Candidate for the ability-gated upgrade system (FB1).
- ~~FB8 — Stomp-to-defeat~~ and ~~FB9 — Per-level boss battles~~ — built, see F5. Cheese and Salsa Bowl are built as regular enemies (see F6); Avocado still needs its own boss instance (art is ready), and further stomp-triggered upgrades (beyond the baseline stomp) are still backlog.
- ~~FB10 — Air Fryer collectible~~ — built, see F8.
- **FB11** — Tomato collectible: temporary power-up letting Cornchip fire seeds at enemies from range for a short duration. Still not built.
- ~~FB12 — Lettuce as the main collectible token~~ — superseded: the collectible is beans, not lettuce (additions.txt correction), built as F7. Lettuce stays an ingredient-only concept.
- **FB13** — On-screen bean token counter (icon + count, no reading-heavy number if avoidable). `level_base.gd` already tracks the count; only the display is missing.
- ~~FB14 — Cheese's "sleep for 10 seconds" effect~~ — built, see F6.
- ~~FB15 (partial) — Queso Grande and Jalapeño~~ — built, see F10. Remaining for Levels 3-6: Lime, Onion, Big Red, Cherry Tomato, Sour Cream Sam, Ice Cube, Chive Bit, Iron Skillet, Grease Splatter -- none have art or code yet; each generation batch gets confirmed with prompts first, per standing practice.

## Explicitly Out of Scope (MVP)
- Touch/mobile input
- Text-based instructions or dialogue
- Multiplayer
