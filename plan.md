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
- [ ] Playtest with the target audience (or an age-appropriate proxy)

### Phase 2 — Full 7-Level Progression (post vertical-slice validation)
- [ ] Ability-gated upgrade system unlocked between levels
- [ ] Stomp-to-defeat enemy mechanic (Cornchip's baseline combat ability, see `feature.md` FB8)
- [ ] Remaining 6 levels, each with its own ingredient, obstacle puns, and boss battle (see `feature.md` FB9)
- [ ] Design remaining boss roster beyond Hot Sauce, Avocado, and Salsa Bowl (Cheese's and Salsa Bowl's role as boss vs. hazard enemy still undecided)
- [ ] Wrap final-boss battle and end-game reconciliation scene

### Phase 3 — Polish & Post-MVP Stretch
- [ ] Full AI-art pass across all levels/characters for visual consistency
- [ ] Audio/music/SFX pass (ambient sound is fine — still no reading required)
- [ ] 2-player local co-op investigation (Cheeto)

## Definition of Done — Vertical Slice
- Playable, single level, start to finish, keyboard only
- Zero possible "game over" states
- No text required to understand any mechanic
- Ingredient-collection loop functions with clear visual feedback

## Decision Log
Canonical list of confirmed product decisions lives in `instructions-ai.txt` under "Confirmed Product Decisions." Update both files together when a decision changes.

## Open Questions / Risks
- Whether lettuce is an in-level scattered token replacing the "one ingredient per level" model, or an additional collectible layer alongside it.
- Full boss roster/order across all 7 levels; Cheese's and Salsa Bowl's status as boss vs. hazard enemy is still undecided.
- How boss battles and the jump-to-defeat mechanic square with the no-fail-state pillar (working assumption: losing just means an immediate retry, no penalty).
- Whether the Wrap final battle plays as straight combat like other bosses, or shifts tone for the reconciliation moment.
- Do the 7 levels map to a specific real crunch-wrap ingredient list/order?
- Reference art/style direction still needed for the sprite-generation pipeline.
