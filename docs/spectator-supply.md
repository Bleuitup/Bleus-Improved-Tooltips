# Spectator top bar supply

Shipped in 1.02, from `feature/spectator-supply`. Section 4 of `docs/spectator-plan.md` on
`feature/spectator` is where this started; the placement there did not survive contact with the
game, and this file is what was actually built.

NS2 line numbers refer to `D:\SteamLibrary\steamapps\common\Natural Selection 2\ns2\lua`.

## What it adds

A supply counter per team on the spectator top bar, reading `used / max`, beside the resources,
resource towers and biomass the bar already carries. Supply is the one number on that bar that
vanilla never shows a spectator at all.

## No new networking

`TeamInfo.supplyUsed` is an ordinary network var with `TeamInfo:GetSupplyUsed()` (`TeamInfo.lua:42`,
`:348`), and the ceiling comes from `GetMaxSupplyForTeam` (`NS2Utility.lua:257`). The bar already
reads both teams' `TeamInfo` for resources and biomass, so nothing new crosses the wire and nothing
is needed from the server side of this mod.

## Why the items are made here rather than fetched

`GUIInsight_TopBar` keeps every item in a file-local and stores nothing on `self`, so a post-hook
has no handle to hang anything off. Same problem, same solution as
`ImprovedTooltips_InsightTopBar.lua`: wrap `GUIManager.CreateGraphicItem` for the duration of
`Initialize`, collect what vanilla makes, then identify the pieces by texture.

- background — `ui/topbar.dds`
- biomass icon — `ui/buildmenu.dds`, which appears exactly once on this bar

The wrapper is restored before anything else, including before re-raising an error out of
`pcall`, so a failure inside vanilla's `Initialize` cannot leave `CreateGraphicItem` wrapped.

## Geometry, and the mistake worth recording

Measured from vanilla (`GUIInsight_TopBar.lua:139`, `:219-224`). The bar is 512 wide and centred, so
its own middle is at 256. Marine items anchor `GUIItem.Left` and are positioned from the bar's left
edge; everything else anchors `GUIItem.Right` and is positioned leftward from its right edge, which
is why the two sides' offsets look mirrored.

| | position |
| --- | --- |
| marine extractors | 50 |
| marine resources | 130 |
| *centre* | *256* |
| alien resources | 317 |
| alien harvesters | 397 |
| alien biomass | 507 |

**The first attempt squeezed both counters inside those 512 pixels and they collided with what was
already there.** The bar is 512 wide on a screen that is not; the space either side of it is empty
and unused. That is where these went:

- marine supply — outside the bar's left edge entirely
- alien supply — the slot biomass used to occupy, hard against the right edge
- alien biomass — pushed one place further out, past the right edge

Final values are `kSpectatorSupplyMarineX = -95`, `kSpectatorSupplyAlienX = -5` and
`kSpectatorBiomassShiftX = 110`, tuned in game. The marine side started at `-140` and read
asymmetric against the alien side's tighter gap.

## Moving vanilla's biomass counter

The one thing here that touches an existing item. Its icon and its text are both children of a
holder that vanilla's `CreateIconTextItem` creates, so **shifting the holder moves the pair together**
and leaves their relative layout alone — shifting the icon would strand the number. The holder is
reached with `icon:GetParent()`, the icon having been found by its texture, and is checked against
the background so a layout change in a future patch cannot make us move the whole bar.

## The icon

`GUIHudSupply.kThemeData`, read at creation with the literal atlas coordinates only as a fallback,
so a mod that re-themes the HUD top bar re-themes this too. Same source the commander tooltip's
supply icon uses (`ImprovedTooltips_TooltipGUI.lua:212`), which is what keeps supply looking
identical everywhere the mod draws it.

## Config

`kShowSpectatorSupply`, plus the three positions above. Turning it off skips the wrapper entirely
and leaves vanilla's biomass counter where it was.

## Test checklist

- Spectate a live round: both counters present, neither overlapping anything
- Supply changes as units are built and lost, on both sides
- Alien biomass sits clear of alien supply and still reads `N / 12`
- Resolution change, which re-runs `Initialize`
- `kShowSpectatorSupply = false` restores vanilla's bar exactly
