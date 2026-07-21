# F40 — Roll 2-Player Co-op Into the Real 7 Levels

**Status:** Blocked on a human playtest that hasn't happened yet. Do not start building without it.

## Precondition (hard blocker, not a formality)
`feature.md` F38 shipped a co-op *prototype* (`scenes/CoOpTest.tscn`, Cheeto + `co_op_camera.gd` + shared
lives) verified only by headless script and one screenshot. Per F38's own stated limitation: **no actual
two-controller human playtest has happened.** An AI cannot press two input devices at once, so this can't
be verified by the AI at all — it needs the user to actually play `CoOpTest.tscn` with two controllers/
keyboard halves first. If that playtest surfaces feel problems (camera zoom pacing, Cheeto's move-set
parity, anything), fix those in the prototype *before* propagating co-op into all 7 shipped, already-solo-
playtested levels — fixing it once in 7 places is expensive.

## Goal (once the prototype is approved)
Make 2-player co-op actually playable across the real 7 levels, not just the standalone test level.

## Design questions to confirm before building
1. **Mode selection:** how does a player choose 1P vs 2P? Options: a toggle on the title screen, a prompt
   on the world map, or auto-detect (if a second controller is connected — more complex, not recommended
   for a keyboard-only MVP per `instructions-ai.txt`'s confirmed decisions). Needs a direct answer, not an
   invented default (Operating Principle 4).
2. **Cheeto's missing poses:** per F38's known limitations, Cheeto's `SpriteFrames` has no dedicated spin-
   dash/ice-slide art — currently reuses jump/run frames as a stand-in. Ship with that reuse (same
   precedent as the climbing-pose reuse in F33), or generate the missing poses first? Ask before spending
   generation budget either way.
3. **Nearest-player targeting gap:** `boss.gd`'s only `get_first_node_in_group("player")` call (Onion's
   screen-wobble effect) always targets whichever player is first in the group, effectively always
   Cornchip. Worth fixing to target the nearer player, or leave as a documented minor gap? Low risk either
   way (F38 already flagged it, no crash risk).

## Implementation sketch (once scope is confirmed)
1. Add mode selection per the answer to Q1 above; store the choice somewhere `level_base.gd` can read it
   (likely a new `GameProgress.co_op_mode` bool, consistent with how `GameProgress` already tracks
   cross-scene state).
2. `level_base.gd`: when `co_op_mode` is true, instantiate `Player2.tscn` at runtime next to the existing
   `Player` node (mirrors how the level already conditionally sets up `_setup_coop_camera()` — that
   function currently expects a `Player2` node to already exist as a static scene child in
   `CoOpTest.tscn`; confirm it also works with one added dynamically via `add_child()`, or adjust it to).
3. Do **not** hand-edit all 7 `.tscn` files to permanently add a `Player2` node — that would force co-op
   framing (camera zoom-out, second character) onto every existing solo playthrough with no way to opt
   out, the exact problem F38 deliberately avoided by keeping `CoOpTest.tscn` separate.
4. Spawn position: reuse `Player`'s existing spawn point with a small offset for `Player2`, same pattern as
   `CoOpTest.tscn`.

## Verification
Headless script per real level (all 7 + Level 7's finale) confirming: both players spawn in group
`"player"`, `co_op_camera.gd` activates with both targets wired and both players' own `Camera2D`s disabled,
boundary walls (F30) still generate correctly, lives stay shared. Mirrors F38's own `CoOpTest.tscn`
verification, just extended to the real levels. Feel (is it actually fun with two people) still needs the
human playtest from the precondition above — headless checks only prove it doesn't crash and frames
correctly, same caveat repeated throughout this project's other movement-feel items.
