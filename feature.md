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

### F11 — Level 1/2 Environment Art Pass (Obstacles, Hazard Fills, Ground Tiles, Parallax Depth)
User-requested: levels should have jump-over obstacles (not just gaps to jump across) themed per level, gap-hazards should look like something thematic instead of a plain void (e.g. Level 1's gaps full of hot salsa), and a fuller environment art pass beyond just character sprites. Scoped to Levels 1-2 only for this pass (already built); Levels 3-7 get their own art when they're actually built. Status: **all 16 assets generated, cropped, and wired into `Level1.tscn`/`Level2.tscn`, including a working parallax background. Not yet playtested. Open item: some duplicate/nested nodes in Level1 (see `plan.md`) worth reviewing next session.**

**Wiring notes (current, post-fixes -- see `plan.md` for the multi-round history of getting here):** obstacles are `StaticBody2D` + `CollisionShape2D` + `Sprite2D`, sized (collision height 32/46/58px for small/medium/large) to stay comfortably under the player's ~73px jump apex (`JUMP_VELOCITY`/`GRAVITY` in `player.gd`). Ground-tile and hazard-fill `TextureRect`s need `expand_mode = 1` (`IGNORE_SIZE`) + `stretch_mode = 6` (`KEEP_ASPECT_COVERED`) explicitly set -- `TextureRect` defaults to `expand_mode = KEEP_SIZE`, which ignores anchors/offsets entirely and renders at native pixel size, and the default stretch mode warps a wide-aspect source into a short box. Cactus/string-lights (L1) and chip/cheese-drip (L2) scenery replaced the old procedural `Polygon2D` decorations, though `Sprite2D` centers on its own origin so the Y position needs adjusting from the old polygon's position to actually touch the ground line, not copied verbatim. The window-view background lives in Godot's native `ParallaxBackground`/`ParallaxLayer` (not a custom script -- see plan.md for why that detour happened), tiled edge-to-edge as the whole backdrop (the flat `SkyTop`/`SkyMid`/`SkyHorizon` bands were removed), with `motion_scale = Vector2(0.4, 1.0)` -- X gets the parallax depth reduction, Y stays at full 1:1 camera tracking so the background never detaches from the ground during a jump. A dedicated backdrop fill (also inside the `ParallaxBackground`, never as a plain scene-tree node -- that draws in front of it, not behind) covers any gray showing past the tiled art's edges/seams. The Hot Sauce arena floor was deliberately left as its distinct dark-red `ColorRect` rather than covered with the ground tile, to preserve the boss-arena visual distinction built in F9.

**Bug found while wiring:** `l1`/`l2_ground_tile.png` and `l1`/`l2_hazard_fill.png` were actually JPEG-encoded bytes saved with a `.png` extension -- Godot's texture importer rejected them ("Failed loading resource"), caught via a headless `--import` run. Re-encoded as real PNGs, cleared the stale `.import` metadata Godot had cached from the failed first attempt, and hardened `generate-sprites.ps1` to detect and auto-fix this (JPEG magic bytes) on any future generation.

**Generation outcome:** the first pass (default `gemini-3.1-flash-image` model) had real defects on 7 assets: readable text baked onto jar/label art despite the "no text" instruction, character faces (Hot Sauce/Cornchip) bleeding into pure textures and scenery because reference images were being sent even for non-character prompts, and `l1_string_lights` not matching its prompt at all (came back as one plain ball instead of 3 colored bulbs on a wire). Fixed by: (1) adding a `NoRefs` flag to `generate-sprites.ps1` so texture/scenery prompts skip the character reference images, and (2) regenerating the 7 affected assets (`l1_obstacle_small/medium/large`, `l1_ground_tile`, `l1_string_lights`, `l1_window_view`, `l2_ground_tile`) with `gemini-3-pro-image` instead, per user's choice. All 7 confirmed clean on re-inspection.

**Pipeline bug found and fixed while verifying the regen batch:** `crop-sprites.ps1`'s chroma-key removal is a border flood-fill, which misses magenta pockets fully enclosed by outline pixels (e.g. the gap where 3 stacked jars meet on `l1_obstacle_medium`) — left a stray magenta sliver in the crop. A blanket "remove small enclosed background-colored pockets" fix was tried and reverted: it also ate legitimate anti-aliased gradient art (`l1_window_view`'s sunset-purple hills fractured into speckled noise, since dithering creates many small same-hued islands that look identical to a real leftover sliver by size alone). The one confirmed leftover-sliver case was fixed manually per-asset instead; `crop-sprites.ps1` itself keeps the original safe border-flood-fill behavior, plus a new `-Only <filenames>` param so a partial regeneration can be re-cropped without touching already-finalized assets (re-running the crop on an already-cropped file is unsafe — its corner pixel is transparent, not magenta, breaking the color reference sample).

**Mechanics (need no new code):**
- Jump-over obstacles are a plain solid wall -- same collision pattern as the ground segments, just a raised block placed mid-ground. The player's existing movement/collision handles walking into or jumping over it with zero new script logic.
- Pit-hazard fill is purely visual -- a themed texture (e.g. bubbling salsa) drawn over/in the existing gaps. The fall consequence (`FALL_RESPAWN_Y` -> `hit_by_obstacle()`, see F9) is completely unchanged.
- The window/parallax background element is the one piece needing new code: implemented as a Godot `ParallaxLayer` (inside a `ParallaxBackground`) so it scrolls slower than the foreground gameplay layer, producing real depth rather than just an illustrated trick.

**Obstacle variants:** 2-3 height/size variants per level (user request), reusing the same themed design at different stack heights so a level doesn't just repeat one exact silhouette everywhere.

**Asset list (16 total), Level 1 -- Salsa Cantina:**
| File | Prompt |
|---|---|
| `l1_obstacle_small.png` | A cartoon obstacle for a platformer: a single stack of two red salsa jars with cartoon labels, glossy glass, a small comedic wobble to the stack. |
| `l1_obstacle_medium.png` | Same, but a small pyramid of three stacked salsa jars. |
| `l1_obstacle_large.png` | Same, but a tall pyramid of five stacked salsa jars, slightly leaning for a comedic wobble. |
| `l1_hazard_fill.png` | Seamless tileable texture: bubbling hot molten salsa, glossy red-orange, bubble highlights, subtle simmering texture, no visible seam. |
| `l1_ground_tile.png` | Seamless tileable texture: warm terracotta patio floor tiles with grout lines, warm reddish-brown tones, no visible seam. |
| `l1_cactus.png` | A simple cartoon saguaro cactus silhouette, two side arms, bright green with highlight lines. |
| `l1_string_lights.png` | A short strand of 3 festive string lights (red, yellow, green bulbs) on a thin wire. |
| `l1_window_view.png` | A wooden cantina-style window frame set into a warm adobe wall, with a hazy, softer-detailed distant desert scene visible through the glass: silhouettes of far-off cacti and low hills under a warm sunset sky, suggesting depth beyond the window. |

**Asset list, Level 2 -- Nacho Kitchen:**
| File | Prompt |
|---|---|
| `l2_obstacle_small.png` | A single nacho serving tray standing on its edge, red plastic basket-style tray with a few tortilla chips visible. |
| `l2_obstacle_medium.png` | Two stacked nacho serving trays, same style. |
| `l2_obstacle_large.png` | Three stacked nacho trays topped with a block of yellow cheese. |
| `l2_hazard_fill.png` | Seamless tileable texture: bubbling molten nacho cheese, glossy orange-yellow, bubble highlights, melty texture, no visible seam. |
| `l2_ground_tile.png` | Seamless tileable checkered nacho-bar floor, alternating warm yellow and tan tiles, no visible seam. |
| `l2_chip.png` | A single cartoon tortilla chip, triangular, golden-tan with brown speckles. |
| `l2_cheese_drip.png` | A single cartoon cheese-drip/dollop hanging shape, glossy orange-yellow. |
| `l2_window_view.png` | A window frame set into a tiled cheese-yellow kitchen wall, with a hazy, softer-detailed distant scene visible through the glass: a softly-lit dining area or second kitchen counter, suggesting depth beyond the window. |

**Generation notes:** obstacles and background-scenery items (cactus, string lights, chip, cheese drip, window views) are icon-style assets on solid magenta, same treatment as character art. Hazard-fill and ground-tile textures are NOT magenta/chroma-key assets -- they're requested directly as seamless tileable patterns, since the whole image is the visible texture rather than an icon to key out. Same reference images (`cornchip_frame1.png`, `hot_sauce_boss_frame1.png`) used for all, for style consistency.

### F12 — Level 3 (Guac Stand)
- Boss: Avocado (3-hit, jump-stomp -- confirmed by the user as the standard defeat condition, same as every other boss so far). Attack is a new hazard *type*, not a projectile: `boss.gd` gained a `hazard_scene` export (parallel to `projectile_scene`) that drops a static ground hazard at the boss's own feet on the attack beat instead of firing something at the player. `GuacPuddle.tscn`/`guac_puddle.gd` stuns on touch like any obstacle and self-frees after 4 seconds so puddles from a long fight don't keep piling up in the arena.
- Enemies: Lime (new, 2-hit ranged -- reuses the plain `BossProjectile.tscn`, same "standard hit" tier as Salsa Bowl) and Onion (new, 1-hit, stationary via `boss.gd`'s `move_speed = 0`). Onion introduces a genuinely new interaction: proximity, not touch, matters. `boss.gd` gained a `wobble_radius` export, checked every physics frame against the player's distance (not an Area2D touch event); in range, it calls a new `player.gd` method `apply_screen_wobble()`, which jitters `Camera2D.offset` with a sine wave -- the same technique already used for the run-cycle sprite bob, just applied to the camera instead. No life cost, matching the "a nuisance, not a hit" spec in `characters.txt`.
- Lime's sprite sheet came back with 9 poses instead of the standard 8 (an extra squirt-attack frame, same anomaly plan.md already noted for this batch) -- used frames 5 and 6 as the two attack phases and skipped 7, per the standing "pick 2 of the 3, no cleanup needed" call.
- Its own ingredient: `GuacIngredient.tscn` is a **procedural placeholder** (a `Polygon2D` blob, no generated art yet) -- Level 3's art pass (obstacles, ground tile, hazard fill, parallax background, ingredient icon, equivalent to F11 for Levels 1-2) hasn't happened yet and needs its own confirmed prompt batch before any paid generation runs, per standing practice. Jump-over obstacles are likewise plain procedural `Polygon2D` crates for the same reason -- both are placeholders, not a finished art pass.
- Ground has 2 real jump gaps, same overall scale as Level 2 (this level doesn't get Level 1's "epic" treatment either).
- `next_level_path` points to `Level4.tscn`, which doesn't exist yet -- same forward-declared pattern as every prior level.

### F13 — Level 4 (Market Tomatoes)
- Boss: Big Red, a genuinely new fight structure -- an "evolving-fight-pattern boss" per `characters.txt`, confirmed with the user before building since nothing else in the game changes mid-fight like this. `boss.gd` gained three exports for it: `split_into_scene`/`split_count`/`split_offset_x` (on the killing blow, spawn N copies of another scene at itself instead of the normal death) and `shared_defeat_group` (a piece only drops the ingredient on death if no other member of a named group is still alive). Both spawned Cherry Tomato pieces inherit Big Red's own `ingredient_scene`/`ingredient_spawn_position` and a group name unique to that split event (`"split_%d" % get_instance_id()`), generated at spawn time rather than hand-authored in a scene file.
- **Real bug caught by headless verification before shipping:** the first version of `shared_defeat_group`'s check (`get_nodes_in_group(...).size() > 1`) was racy -- `queue_free()` doesn't remove a node from its groups until the deferred free actually runs a moment later, so if both Cherry Tomato pieces are stomped in the same frame, each one's death-check still sees the other as "still alive" (neither had left the group yet) and *both* skip the ingredient drop, softlocking the level. Fixed by having each piece call `remove_from_group()` immediately/synchronously as the first step of its own death, before checking whether anyone else remains -- confirmed via a headless script that kills both pieces back-to-back and asserts exactly one ingredient spawns (was 0 before the fix, 1 after).
- Enemies: Cherry Tomato (new, 1-hit, fast, melee-only -- no attack animation wired, same pattern as Cheese/Jalapeno since it never fires anything) appears both standalone and as Big Red's split result. Salsa Bowl returns with a lower `fire_interval` (2.5 vs. the default 4.0) for a faster-firing "tougher" version, entirely via instance override -- no script changes needed.
- Cherry Tomato's art needed two generation passes: the default model baked visible text labels into every pose (violates the no-reading-required pillar outright), fixed by regenerating with `gemini-3-pro-image`, the same fix that worked for the L1/L2 text-defect batch in F11.
- Its own ingredient: `TomatoIngredient.tscn`, another procedural placeholder like Level 3's -- Level 4 environment art is deferred the same way, not yet scheduled.
- `next_level_path` points to `Level5.tscn`, not yet built.

### F14 — Level 5 (Frosty Fridge)
- Boss: Sour Cream Sam is the first boss with no attack of any kind (`projectile_scene`/`hazard_scene`/`split_into_scene` all unset) -- per `characters.txt`, the icy arena floor itself is the entire challenge, "changing how Cornchip's movement feels rather than adding another attack type." New `IceZone.tscn`/`ice_zone.gd`: a plain `Area2D` region trigger (not a hazard -- no life cost) that calls a new `player.gd` method `set_on_ice()` on entry/exit. While `is_on_ice` is true, horizontal movement switches from the normal instant velocity snap to `move_toward(velocity.x, target, ICE_ACCEL * delta)`, so input lags into a slide instead of stopping/turning immediately. Confirmed with the user before building since it's a new player-movement mechanic, not just an enemy config. Deliberately built as a generic reusable zone (not Sour-Cream-specific) for Level 6's heating floor to reuse the same pattern later.
- Enemies: Ice Cube (new, 1-hit, the fastest `move_speed` of any character yet, matching its "fast" spec) and Chive Bit (new, 1-hit, the smallest `Sprite2D` scale of any character yet, matching "tiny" -- placed as 3 instances clustered together for "small swarms," no new spawner code needed).
- Verification note: the `is_on_ice` zone-detection/toggle was confirmed correct via a headless script (teleporting the player in and out of the zone and checking the flag). The `move_toward` velocity-ramp itself couldn't be verified the same way -- simulated `Input.action_press()` didn't register through this particular headless harness, a test-tooling limitation rather than a sign of an engine or code issue (the toggle logic driving it is proven correct, and `move_toward` is a standard, well-understood built-in). Left for the user to feel-check directly during play, same as any other movement-feel question.
- Its own ingredient: `SourCreamIngredient.tscn`, another procedural placeholder -- Level 5 environment art deferred the same way as Levels 3 and 4.
- `next_level_path` points to `Level6.tscn`, not yet built.

### F15 — Level 6 (Sizzling Griddle)
- Boss: Iron Skillet is the second boss with no attack at all (`projectile_scene`/`hazard_scene`/`split_into_scene` unset), same as Sour Cream Sam -- the arena floor is the whole challenge. New `HeatZone.tscn`/`heat_zone.gd`, the sibling of Level 5's `IceZone`: a self-looping timer cycles safe (4s) -> warning flash (0.8s, a fairness cue for the target 5-8 year old audience) -> hot (2s) -> repeat. While hot, any body inside the zone that's grounded (`is_on_floor()`) and has a `hit_by_obstacle` method takes exactly one hit per hot phase (a per-cycle latch prevents repeat hits even if the player recovers and stays put). Confirmed with the user before building. **Verified via a headless script** driving a real `Player.tscn` instance settled on a floor inside a fast-cycling zone: hit fires exactly once at the hot-phase transition, latch blocks a second hit through the rest of the phase, resets correctly on the next cycle.
- Enemies: Jalapeño and Onion return tougher via plain instance overrides in `Level6.tscn` (Jalapeño: `max_health` 1->2, `move_speed` 55->65; Onion: `wobble_radius` 100->140) -- no script changes. Grease Splatter (new) is the first enemy that's genuinely immune to stomping: `boss.gd` gained a `cannot_be_stomped` export that forces `is_stomp` false regardless of fall angle, so any contact stuns the player like a side-touch instead of defeating it. The Air Fryer spin-dash still works on it (no stated exception to its "defeats anything you touch" rule in F8). **Verified via headless script**: a stomp-shaped contact leaves it undamaged and stuns the player; a spin-dash contact still defeats it.
- **Real fairness bug found via playtest, fixed in two rounds:** Grease Splatter originally patrolled, which the user reported as literally impossible to clear. Making it stationary (first fix) helped but wasn't enough -- reworking the jump-arc math showed the stationary hazard's own height still made it geometrically uncrossable by a single jump (the "high enough" window covers less horizontal distance than the hazard+player width requires). Real fix: **F16, double jump**, see below.

### F16 — Double Jump (Level 6+)
Added directly in response to the Grease Splatter fairness bug, per the user's own suggested fix. `player.gd` gained `has_double_jump`/`air_jumps_used`: one extra jump usable while airborne, reset whenever `is_on_floor()` becomes true (so it works whether the first ascent was a jump or just walking off a ledge). Deliberately gated to start at Level 6 rather than granted from the beginning -- Levels 1-5's jump gaps were tuned around the original single-jump ~154px range, and a global double jump would trivialize them. Granted via a new `level_base.gd` export, `grants_double_jump`, set per-level (`Level6.tscn` has it; `Level7.tscn` will need it too when built) rather than trying to persist ability state across the scene-reload boundary between levels -- the same lesson already learned from Air Fryer/spin-dash not surviving `change_scene_to_file()`. No new art needed; the existing "jump" animation already covers any airborne state.
Verified analytically rather than via a live headless playtest (simulated keyboard input doesn't register through this project's headless test harness -- same gap noted for Level 5's ice feel): a double jump timed near the first jump's apex reaches double the single-jump height and covers roughly 205px of "high enough" horizontal distance against Grease Splatter's 100px danger zone -- comfortable, over 2x margin.
- Its own ingredient: `CrunchyShellIngredient.tscn`, another procedural placeholder -- Level 6 environment art deferred the same way as Levels 3-5.
- `next_level_path` points to `Level7.tscn` (the Wrap finale), not yet built. This closes out Phase 2's Levels 2-6 -- only Level 7 remains before the full 7-level MVP is complete.

## Backlog (Post-MVP, Not Yet Scheduled)
- **FB1** — Ability-gated upgrade system spanning all 7 levels
- ~~FB2 — Remaining 6 levels~~ — Levels 2-6 built, see F10/F12/F13/F14/F15. Only the Wrap finale (Level 7) still to go — see `characters.txt` Bestiary by Level.
- **FB3** — Wrap final-boss battle and end-game reconciliation scene (depends on FB9's boss-battle structure)
- **FB4** — Full art pass across all characters/levels for visual consistency
- **FB5** — Audio/music/SFX pass
- **FB6** — 2-player local co-op with Cheeto
- **FB7** — "Spin dash" upgrade: Cornchip spins rapidly, letting him plow through enemies unharmed while they comically fly off-screen (front- or back-flipping). Unlocked via the Air Fryer collectible (see below). Candidate for the ability-gated upgrade system (FB1).
- ~~FB8 — Stomp-to-defeat~~ and ~~FB9 — Per-level boss battles~~ — built, see F5. Cheese and Salsa Bowl are built as regular enemies (see F6); Avocado is now built too (see F12). Further stomp-triggered upgrades (beyond the baseline stomp) are still backlog.
- ~~FB10 — Air Fryer collectible~~ — built, see F8.
- **FB11** — Tomato collectible: temporary power-up letting Cornchip fire seeds at enemies from range for a short duration. Still not built.
- ~~FB12 — Lettuce as the main collectible token~~ — superseded: the collectible is beans, not lettuce (additions.txt correction), built as F7. Lettuce stays an ingredient-only concept.
- **FB13** — On-screen bean token counter (icon + count, no reading-heavy number if avoidable). `level_base.gd` already tracks the count; only the display is missing.
- ~~FB14 — Cheese's "sleep for 10 seconds" effect~~ — built, see F6.
- ~~FB15 — Queso Grande and Jalapeño, Lime and Onion, Big Red and Cherry Tomato, Sour Cream Sam/Ice Cube/Chive Bit, Iron Skillet and Grease Splatter~~ — all built, see F10/F12/F13/F14/F15. Every boss/enemy through Level 6 now has art and code; only Wrap (Level 7's final boss) remains, and his art already exists from early Phase 1 work.

## Explicitly Out of Scope (MVP)
- Touch/mobile input
- Text-based instructions or dialogue
- Multiplayer
