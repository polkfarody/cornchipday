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
- [ ] First-pass AI-generated art for Cornchip and the one obstacle type — currently placeholder vector shapes only; no image-generation tool available in this environment (see `feature.md` F4)
- [ ] Playtest with the target audience (or an age-appropriate proxy)

### Phase 2 — Full 7-Level Progression (post vertical-slice validation)
- [ ] Ability-gated upgrade system unlocked between levels
- [ ] Remaining 6 levels, each with its own ingredient and obstacle puns
- [ ] Wrap narrative beats / end-game reconciliation scene
- [ ] Resolve open question: literal boss encounter vs. narrative-only Wrap

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
- Is Wrap a literal end-of-game boss encounter, a narrative/dialogue-only figure, or both?
- Do the 7 levels map to a specific real crunch-wrap ingredient list/order?
- Reference art/style direction still needed for the AI sprite-generation pipeline.
