# F41 — L4/L5 Window-Background Repositioning

**Status:** Not started. Small, fully scoped, no design questions — safe to build directly without
confirmation (matches `instructions-ai.txt` Operating Principle 1: shippable speed, no gold-plating, and
it's an explicit, already-approved user ask, not invented scope).

## Background
`feature.md` F29 fixed the L3/L4/L5 window-view art *content* (was rendering as a broken/unfilled mess —
root cause was a chroma-key prompt that didn't specify an opaque full-canvas wall). F29 explicitly did
**not** address the separate positioning complaints from the same feedback round
(`full-run-feedback.txt`):
- **Level 4:** "The background needs to change or be expanded and brought down to ground level" — the art
  content is already fixed; what's left is purely a camera/parallax Y-offset issue (background sitting too
  high / not reaching the ground line).
- **Level 5:** "This one could actually be fixed by just enlarging it and positioning down at ground
  level" — same class of fix, and the user explicitly said this alone would resolve it (no further art
  needed).

## Implementation
Both levels use the same `ParallaxBackground`/`ParallaxLayer` structure as every other level (see F11's
wiring notes and F26's rendering-bug fix for the proven-correct reference setup — Level 1's offsets are the
known-good baseline). The fix is purely numeric, in `Level4.tscn` / `Level5.tscn`:
1. Open each level's `WindowParallax` node and compare its `Window*` children's `position`/`scale` against
   Level 1's (`Level1.tscn`) proven values (`700px` displayed width target per F26's convention: scale =
   `700 / native_width`).
2. Adjust the Y offset so the art's bottom edge sits at/near the ground line, same visual target as L1/L2/
   L6/L7 already hit (per F26 §"Wiring notes" and F29's own fix for L3).
3. For Level 5 specifically, also increase `scale` slightly ("enlarging") per the user's own suggested fix
   — start from the current scale and increase until the art fills the vertical frame without visibly
   pixelating (check at actual gameplay resolution, not zoomed in).
4. Re-run the same screenshot check F26/F29 already used: real (non-headless) boot, screenshot, confirm no
   gray gap between sky and ground (`RGB(76,76,76)` is Godot's default clear color — its presence in a
   screenshot means something isn't covering that area, the exact bug F26 caught this way).

## Files touched
`scenes/Level4.tscn`, `scenes/Level5.tscn` — position/scale values only, no script changes needed.

## Verification
Real windowed screenshot of both levels (same technique as F26/F29), confirming the window art's bottom
edge meets the ground tile with no visible seam/gap, matching the already-shipped L1/L2/L6/L7 backgrounds.
