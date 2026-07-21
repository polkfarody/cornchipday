# F41 — L4/L5 Window-Background Repositioning

**Status:** Done. Purely numeric fix in `Level4.tscn`/`Level5.tscn`, verified via real windowed screenshots.

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

## Result
Ground line (top of `GroundVisual`) sits at world y=360 across every level (`Ground* position.y=400` +
`offset_top=-40`) — confirmed against L1's already-correct `Window1` (native 1313x768, scale 0.99,
position y=-20 → bottom edge lands at y≈360.16). Used that as the target for both fixes:
- **L4:** scale left untouched at `0.5307` (already tuned to the 700px-width convention, native width
  1319). Displayed height = 768 × 0.5307 = 407.58, so `position.y` moved from `30` → `156.21` to put the
  bottom edge at y=360. Pure Y-offset, per the "no art issue" diagnosis above.
- **L5:** native art is 1302×670 (shorter than L1/L4's 768-tall crop), so the old scale (`0.5376`, tuned
  only for 700px width) left a visibly short wall with a gap above the ground. Increased scale to `0.65`
  (still well under 1.0 against the native resolution, so no upscale pixelation) and moved `position.y`
  from `0` → `142.25` so the taller result's bottom edge still lands at y=360.
- Real windowed screenshots (`--scene res://scenes/LevelN.tscn --write-movie ... --quit-after 5`,
  1280x720) of both levels confirm the art now reads edge-to-edge down to the ground tile with no gray
  gap and no visible seam.
