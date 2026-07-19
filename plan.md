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
- [x] Cheese's proper "sleep for 10 seconds" effect built (see `feature.md` F6/FB14 — no longer just planned, it's live)
- [x] Level-to-level transition system built: `level_base.gd` (generalized from `level1.gd`) owns lives/HUD/bean-tracking for any level, plus `next_level_path` and `register_level_ingredient()` to progress between levels once a level's ingredient is collected
- [x] Real art generated for the salsa obstacle and lettuce ingredient, plus a new cheese ingredient icon — all wired into their scenes
- [x] Sprite pipeline improvements: generation requests now include reference images (existing character art) for style consistency; the grid-slicer detects the actual number of rows in a layout instead of assuming 2 (the model doesn't always honor the requested 4x2 layout); transparent pixels are fully zeroed (RGB and alpha) instead of leaving color baked in under alpha=0; the crop script can no longer reprocess and corrupt its own previously-finalized output (this happened once and was caught via checksum + git restore before committing)
- [x] Queso Grande and Jalapeño confirmed by the user, art already generated -- clear to build into Level 2
- [x] Level 1 reworked to feel "grander/more epic" per direct user request: 4 real jump gaps (`FALL_RESPAWN_Y` in `player.gd`, same life-cost consequence as any hit), roughly doubled length, a layered sunset-patio background (procedural vector art, no new paid generation), and a distinct arena zone for the Hot Sauce fight — see `feature.md` F9
- [ ] Playtest with the target audience (or an age-appropriate proxy)

### Phase 2 — Full 7-Level Progression (post vertical-slice validation)
- [ ] Ability-gated upgrade system unlocked between levels
- [ ] Levels 2–6 — **confirmed roster**, see `characters.txt` Bestiary by Level: Nacho Kitchen, Guac Stand, Market Tomatoes, Frosty Fridge, Sizzling Griddle, each with its own boss (Queso Grande art ready; Big Red, Sour Cream Sam, Iron Skillet still need art; Avocado already has art) and new enemies (Jalapeño art ready; Lime, Onion, Cherry Tomato, Ice Cube, Chive Bit, Grease Splatter still need art -- each generation batch confirmed with prompts before running)
- [ ] Level 7: no separate ingredient boss, built entirely around the Wrap confrontation, preceded by a remix gauntlet of one earlier enemy per level
- [ ] Wrap final-boss battle and end-game reconciliation scene
- [ ] On-screen bean token counter (see `feature.md` FB13)
- [ ] Tomato power-up (see `feature.md` FB11)

### Phase 3 — Polish & Post-MVP Stretch
- [ ] Full AI-art pass across all levels/characters for visual consistency
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
- Whether the Wrap final battle plays as straight combat like other bosses, or shifts tone for the reconciliation moment.
- Reference art/style direction still needed for the sprite-generation pipeline.
- Levels 3-6 need new art (Lime, Onion, Big Red, Cherry Tomato, Sour Cream Sam, Ice Cube, Chive Bit, Iron Skillet, Grease Splatter) -- each batch gets confirmed with prompts before generating, per standing practice.
