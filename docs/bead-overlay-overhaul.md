# Bead Overlay Overhaul

Branch `feature/bead-overlay-overhaul`. Tracking issue: #1 ("Trait research appearing in the mapview
summarized biomass pannel").

**Status: written, never run.** `luac -p` passes on the changed files, which proves they parse and
nothing more. Layout in particular is unverified.

The overlay in question is `GUIBioMassDisplay` — the twelve-bead biomass bar in the top left, shown
whenever the map, the buy menu or the tech map is open, and permanently for the commander.

All line numbers refer to `D:\SteamLibrary\steamapps\common\Natural Selection 2\ns2\lua`.

## What vanilla does, and why neither feature exists there

**The beads are not twelve items.** They are one texture, `ui/biomass_bar.dds`, stretched to a
fraction of the bar's width (`GUIBioMassDisplay.lua:322-325`). The art merely looks like twelve
circles.

**That fraction comes from a single integer**, `teamInfo:GetBioMassLevel()` (`:272`). There is no
per-level number anywhere in the file, so a bead can only pop from empty to full. Vanilla could not
show a partial bead if it wanted to.

**The ability icons already know their own tech**, though. `UpdateAbilityList` stores
`self.abilityIcons[i][j]` holding both `.Graphic` and `.TechId` (`:79-143`), grouped by the biomass
level that unlocks them.

## The data was already there

Nothing new is networked. `ImprovedTooltips_BiomassProgress.lua` — the 0.92 tech map fix — already
writes `SetResearchProgress` onto `BioMassOne..Twelve` for **every** research in flight, and vanilla
ships that to clients through its own `TechNodeUpdate`. Ability nodes carry `researchProgress` the
same way, which is exactly what `GUITechMap:305-309` reads for its own meters.

So this branch is a client-side read of work that shipped in 0.92 and has been sitting unused by
this overlay ever since. The multi-research behaviour comes for free: the server fix already fills
several level nodes at once, so several beads fill at once.

## What this branch adds

**1. Partial fill on each bead being researched.** For every level above the current one, the node's
research fraction draws the same slice of the same texture vanilla uses, cropped to that one bead
and then to the fraction within it. Tinted (`kBiomassBeadProgressColor`, white at 50% alpha) so
"being researched" reads differently from "done". Beads at or below the current level are untouched
— vanilla's own filled bar already covers them, so there is no overlap.

**2. A progress meter under each ability icon being researched.** Geometry copied from
`GUITechMap:131-141`: a black plate the width of the icon, meter inset one pixel. Anchoring
Left/Bottom and positioning at `-height` puts it *inside* the icon's bottom edge rather than below
it, which is what vanilla does and what keeps it clear of the icon stacked underneath.

## Why a post-hook works

`GUIBioMassDisplay` keeps its pieces on `self` — `background`, `foreground`, and the `abilityIcons`
table — so the ability icons can be decorated in place. That matters, because `UpdateAbilityList` is
a **file-local** and cannot be hooked; reimplementing it would have meant duplicating the
prerequisite grouping and the hover handling.

Everything drawn is parented under `self.background`, which vanilla destroys in its own
`Uninitialize` (`:242-254`) — the same reason vanilla can drop every ability icon without touching
them individually. Our `Uninitialize` hook only clears the references.

## Things worth knowing

- **Vanilla throttles its own `Update`** to twice a second unless something is animating
  (`:285-289`). Ours runs every frame, which is what a progress bar wants and costs a dozen node
  lookups with no allocation once the items exist.
- **The bar is twelve beads but vanilla's ability list is ten.** `kBioMassTechIds` in
  `GUIBioMassDisplay.lua:44` stops at `BioMassTen`, while the bar and its label are `/ 12`. So beads
  eleven and twelve have no ability column in vanilla. The bead fill covers all twelve; the ability
  meters follow vanilla's ten.
- **The bar's on-screen size is read from the item**, not mirrored, so a mod that resizes the bar
  stays correct. Only the texture region (`{0, 0, 1200, 160}`) is mirrored, because there is no
  getter for it.

## Test checklist

- Two hives researching biomass at once: **two beads** should fill together, at their own rates.
  This is the headline case and the one vanilla gets wrong.
- One hive researching: one bead fills; the bar otherwise looks exactly as it did.
- A research completing: the partial fill should vanish as vanilla's solid bar grows into it, with
  no flicker or double-drawn bead at the boundary.
- A research cancelled: the partial fill disappears.
- Abilities — start Leap or Bile Bomb and watch the icon; the meter should fill and then disappear
  when it completes.
- Several abilities at once from different hives.
- Open and close the map repeatedly, and switch teams, to shake out stale or leaked items.
- Check it as commander, where the overlay is always visible, as well as from the map.

## Two things the first draft got wrong

Both were found before the branch was tested, and both are worth keeping written down because the
wrong version looks plausible.

- **Bead positions must be measured, not assumed.** The first draft divided the bar into twelfths.
  The beads are not evenly spaced — 78 to 80 pixels wide with gaps of 10 to 25 between them — so an
  even split put a fill up to a third of a bead out of place, starting inside the dark gap before
  it. The bounds in this file come from decompressing `ui/biomass_bar.dds` and taking the runs of
  columns carrying alpha in the foreground band; the method is written into the source comment so it
  can be redone if the art ever changes.
- **Crop rather than resize** to reveal progress. Resizing meant keeping the item's width and a
  matching texture sub-slice in step, and any disagreement between them stretched the art. With a
  crop the item never moves or changes size, so it cannot drift out of alignment with the bead
  beneath it.

**Considered and rejected:** raising the level text's layer, on the theory that a partial fill could
draw over "Biomass Level: N / 12". Testing showed the text sits clear of the bead art, and vanilla's
own full-width fill already passes under it at 12/12 without obscuring it. There is nothing to fix.

## Most likely to need adjusting in game

- **Bead alpha.** 50% white over the filled-bar art is a guess; it may read as too faint or as a
  glitch rather than as progress.
- **Meter height.** 18% of an icon that is a twelfth of the bar is roughly 7px at the default size.
  `GUITechMap` uses 10px against larger icons.
- **Render order.** Our bead items are added to `self.background` after vanilla's `foreground`, so
  they should draw on top. If a partial bead appears *behind* the bar art, that assumption is wrong.
