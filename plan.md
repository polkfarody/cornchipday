# Cornchip Day — Development Plan

## Current Phase: MVP Vertical Slice
Goal: prove the core loop is fun and age-appropriate before committing to all 7 levels.

## Roadmap

### Phase 0 — Documentation & Setup
- [x] Game brief, character bible, AI charter drafted
- [x] plan.md / readme.md / feature.md drafted (this phase)
- [x] Godot 4 installed, project scaffolded

### Phase 1 — Vertical Slice MVP
- [x] Player controller: run + jump, keyboard input
- [x] One obstacle (thrown "mild" salsa) with a visual-comedy reaction and a no-fail respawn
- [x] Level end: ingredient collectible with clear, wordless completion feedback
- [x] First-pass AI-generated art for Cornchip (idle/run/jump/hit), wired into the Player scene as an AnimatedSprite2D. Generated via Gemini/AI Studio using a magenta chroma-key pipeline (see `feature.md` F4); art for all four confirmed bosses is also generated and ready for Phase 2. Still needed: art for the salsa obstacle and lettuce ingredient.
- [x] Stomp-to-defeat enemy mechanic (Cornchip's baseline combat ability, see `feature.md` F5) — pulled forward from Phase 2 since it's needed for the boss fight below
- [x] First full boss battle (Hot Sauce): patrols, fires a projectile, takes 3 stomps to defeat, spawns the ingredient on death — also pulled forward from Phase 2 as a second vertical-slice milestone, replacing the old "ingredient just sitting in the open" ending
- [x] Expanded Level 1 into a real first level (not just a short vertical slice): scattered bean tokens, two Cheese "little enemy" encounters plus a Salsa Bowl enemy (resolved as regular enemies, not bosses), an Air Fryer power-up (spin dash), ending in the Hot Sauce fight — renamed `Main.tscn` to `Level1.tscn` to establish the naming convention ahead of Level 2+
- [x] 3-life system with an icon-only HUD; at 0 lives the level restarts from the beginning with lives reset to 3 (see `game-brief.txt` Design Philosophy for how this reconciles with the no-fail-state pillar)
- [x] Wrote up a 7-level bestiary (`characters.txt` Bestiary by Level) so the enemy roster evolves per level instead of repeating — **confirmed by the user**, including keeping Queso Grande/Jalapeño as-is. Full roster/order for Levels 2-7 is now the working plan, not just a proposal.
- [x] Cheese's proper "sleep" effect built (see `feature.md` F6/FB14), tuned down from 10s to 3s after testing
- [x] Level-to-level transition system built: `level_base.gd` (generalized from `level1.gd`) owns lives/HUD/bean-tracking for any level, plus `next_level_path` and `register_level_ingredient()` to progress between levels once a level's ingredient is collected
- [x] Real art generated for the salsa obstacle and lettuce ingredient, plus a new cheese ingredient icon — all wired into their scenes
- [x] Sprite pipeline improvements: generation requests now include reference images (existing character art) for style consistency; the grid-slicer detects the actual number of rows in a layout instead of assuming 2 (the model doesn't always honor the requested 4x2 layout); transparent pixels are fully zeroed (RGB and alpha) instead of leaving color baked in under alpha=0; the crop script can no longer reprocess and corrupt its own previously-finalized output (this happened once and was caught via checksum + git restore before committing)
- [x] Level 1 reworked to feel "grander/more epic" per direct user request: 4 real jump gaps (`FALL_RESPAWN_Y` in `player.gd`, same life-cost consequence as any hit), roughly doubled length, a layered sunset-patio background (procedural vector art, no new paid generation), and a distinct arena zone for the Hot Sauce fight — see `feature.md` F9
- [x] Fixed a real gap: `Obstacle.tscn`/`Ingredient.tscn` had been documented as using real generated art but were still on the old placeholder shapes -- now actually wired in, plus a new `CheeseIngredient.tscn` for Level 2
- [x] Level 2 (Nacho Kitchen) built in full: Queso Grande boss (new cheese-glob slow attack via `slow_projectile.gd`/`apply_slow()`), Jalapeño enemy, Cheese reused, bean tokens, 2 jump gaps, nacho-yellow background -- see `feature.md` F10
- [x] Lime and Onion art generated for Level 3 (not yet built into scenes). Two quality notes from this batch: Lime came back with an extra squirt-attack frame (9 poses instead of 8, all legitimate -- just pick 2 of the 3 when building the scene, no cleanup needed). Onion lost its "releasing fumes" decoration on 2 of 8 frames -- the fume-line shapes were visible in the raw generated image but didn't survive `crop-sprites.ps1`'s small-blob filtering, likely because they're thin/low-pixel-area compared to the character body. Flagged in Open Questions rather than silently reprocessed or paid to regenerate.
- [x] Level 1/2 environment art generated: all 16 F11 assets (jump-over obstacles, pit-hazard fills, tiled ground textures, background scenery, window/parallax depth layers). First pass used `gemini-3.1-flash-image` and came back with real defects (readable text on labels, character faces bleeding into pure textures/scenery, a string-lights asset that didn't match its prompt at all). Fixed by switching to `gemini-3-pro-image` for the 7 affected/judgment-call assets (`l1_obstacle_small/medium/large`, `l1_ground_tile`, `l1_string_lights`, `l1_window_view`, `l2_ground_tile`) and adding a `NoRefs` flag to `generate-sprites.ps1` so pure texture/scenery prompts stop receiving character reference images (the actual cause of the bleed-through). All 7 re-verified clean.
- [x] Fixed a real `crop-sprites.ps1` bug found while verifying the regen batch: its border-flood-fill chroma-key removal misses magenta pockets fully enclosed by outline pixels (e.g. the gap where 3 stacked jars meet on `l1_obstacle_medium`), leaving stray magenta slivers baked into the crop. Tried an automatic "small enclosed pocket" sweep as a general fix, but it also ate legitimate anti-aliased gradient art (`l1_window_view`'s sunset-purple hills fractured into speckled noise, since dithering creates many small same-hued islands indistinguishable from a real leftover sliver by size alone). Reverted the automatic sweep and repaired the corrupted file by inpainting the introduced holes from neighboring pixels (recoverable since the damage was self-inflicted and its exact locations were known). Net takeaway: leftover-magenta-sliver fixes need to stay a manual, visually-verified step per asset, not a blanket pipeline pass.
- [ ] **Next up:** wire all 16 environment assets into `Level1.tscn`/`Level2.tscn` -- obstacles as plain `StaticBody2D` walls, hazard-fill textures into the existing gaps (visual only), ground tiles replacing the flat `ColorRect` ground, background scenery placed in-scene, and the window-view assets as a real `ParallaxLayer`/`ParallaxBackground` for scroll depth. Not yet started.
- [ ] Playtest with the target audience (or an age-appropriate proxy)

### Phase 2 — Full 7-Level Progression (post vertical-slice validation)
- [ ] Ability-gated upgrade system unlocked between levels
- [ ] Levels 3–6 — **confirmed roster**, see `characters.txt` Bestiary by Level: Guac Stand, Market Tomatoes, Frosty Fridge, Sizzling Griddle, each with its own boss (Big Red, Sour Cream Sam, Iron Skillet still need art; Avocado already has art) and new enemies (Lime, Onion, Cherry Tomato, Ice Cube, Chive Bit, Grease Splatter still need art -- each generation batch confirmed with prompts before running)
- [ ] Level 7: no separate ingredient boss, built entirely around the Wrap confrontation, preceded by a remix gauntlet of one earlier enemy per level
- [ ] Wrap final-boss battle and end-game reconciliation scene
- [ ] On-screen bean token counter (see `feature.md` FB13)
- [ ] Tomato power-up (see `feature.md` FB11)

### Phase 3 — Polish & Post-MVP Stretch
- ~~Textures and style consistency pass~~ — scoped and detailed for Levels 1-2, see the Phase 1 item above and `feature.md` F11 (obstacles, hazard fills, ground tiles, scenery, parallax window depth). Levels 3-7 will need their own equivalent pass once built.
- [ ] Full AI-art pass across all levels/characters for visual consistency (FB4)
- [ ] Audio/music/SFX pass (ambient sound is fine — still no reading required)
- [ ] 2-player local co-op investigation (Cheeto)

## Definition of Done — Vertical Slice
- Playable, single level, start to finish, keyboard only
- No game-over screen; running out of lives restarts the level rather than ending the game
- No text required to understand any mechanic
- Ingredient-collection loop functions with clear visual feedback

## Decision Log
Canonical list of confirmed product decisions lives in `instructions-ai.txt` under "Confirmed Product Decisions." Update both files together when a decision changes.

## Open Questions / Risks
- **Onion's fume-line decoration is missing from 2 of its 8 frames** (see Phase 1 note above) -- ship as-is (the blur/wobble gameplay effect doesn't depend on the art showing fumes), try to recover it with a crop-script tweak (risk: might let real noise back in elsewhere), or pay to regenerate with a prompt tuned to draw thicker/larger fumes more likely to survive processing?
- Whether the Wrap final battle plays as straight combat like other bosses, or shifts tone for the reconciliation moment.
- Reference art/style direction still needed for the sprite-generation pipeline.
- Levels 3-6 need new art (Big Red, Cherry Tomato, Sour Cream Sam, Ice Cube, Chive Bit, Iron Skillet, Grease Splatter) -- each batch gets confirmed with prompts before generating, per standing practice.
