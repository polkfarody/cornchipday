# F42 — Full Art Consistency Pass (Backlog FB4)

**Status:** Deliberately not scheduled. This file is a pointer, not an execution plan — there is no
confirmed scope to build against yet.

## Why this isn't a normal feature file
Every other planning file in this folder has a concrete implementation sketch. This one doesn't, on
purpose. `feature.md`'s own Backlog entry for FB4 (written 2026-07-21) already assessed this and declined
to build it blind:

> "Every generation prompt in `generate-sprites.ps1`, across the entire project history, reuses the same
> `$styleSuffix`... plus character reference images for anything with an established design — visual
> consistency has been a structural property of the pipeline by construction, not left to chance. Blindly
> regenerating dozens of already-shipped, already-good assets on a vague 'consistency' goal (with no way
> to verify the result is actually more consistent than what exists) isn't a good use of generation spend."

That reasoning still holds. Don't reopen this as a full pass without a concrete trigger.

## What to actually do if this comes up again
1. **Ask the user to name specific assets** that read as visually inconsistent — a character, a texture, a
   scene. Do not proceed on "make everything more consistent" as stated; it isn't actionable and every
   prior "full pass" style request in this project turned out to really mean 1-2 specific defects once
   pinned down (see F26/F29's root-caused, per-asset fixes vs. a blind regen).
2. Once a specific asset is named, treat it exactly like every other art defect fix already done this
   project (F26, F29, F34): identify the concrete problem (wrong style, bleed-through, wrong pose), fix
   just that prompt in `generate-sprites.ps1`, regenerate only that asset, visually verify before/after via
   screenshot, and note the fix in `feature.md`.
3. If the user does want a genuine full-project regeneration despite the above (e.g. changing the whole
   house style, not fixing an inconsistency), that's a different, much bigger ask — confirm the actual
   motivation before scoping it, since it would mean discarding a large amount of already-approved,
   already-shipped art.

## Do not
- Do not run a "regenerate everything" batch speculatively.
- Do not invent a list of "inconsistent" assets to justify starting — if nothing concrete has been named,
  there's nothing to build yet.
