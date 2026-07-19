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
- [x] Expanded Level 1 into a real first level (not just a short vertical slice): scattered lettuce tokens, two Cheese "little enemy" encounters (resolved as a regular enemy, not a boss), an Air Fryer power-up (spin dash), ending in the Hot Sauce fight — renamed `Main.tscn` to `Level1.tscn` to establish the naming convention ahead of Level 2+
- [x] 3-life system with an icon-only HUD; at 0 lives the level restarts from the beginning with lives reset to 3 (see `game-brief.txt` Design Philosophy for how this reconciles with the no-fail-state pillar)
- [ ] Playtest with the target audience (or an age-appropriate proxy)

### Phase 2 — Full 7-Level Progression (post vertical-slice validation)
- [ ] Ability-gated upgrade system unlocked between levels
- [ ] Remaining 6 levels, each with its own ingredient, obstacle puns, and boss battle (see `feature.md` F5) — Avocado and Salsa Bowl bosses still need their own instances (`boss.gd` is written to be reused, art is ready for Avocado; Salsa Bowl too)
- [ ] Design remaining boss roster beyond Hot Sauce and Avocado (Salsa Bowl's role as boss vs. regular enemy still undecided; Cheese is resolved as a regular enemy, already built)
- [ ] Wrap final-boss battle and end-game reconciliation scene
- [ ] On-screen lettuce token counter (see `feature.md` FB13)
- [ ] Cheese's proper "sleep for 10 seconds" effect, replacing its current generic stumble reaction (see `feature.md` FB14)
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
- Full boss roster/order across all 7 levels; Salsa Bowl's status as boss vs. regular enemy is still undecided (Cheese is resolved as a regular enemy).
- Whether the Wrap final battle plays as straight combat like other bosses, or shifts tone for the reconciliation moment.
- Do the 7 levels map to a specific real crunch-wrap ingredient list/order?
- Reference art/style direction still needed for the sprite-generation pipeline.
