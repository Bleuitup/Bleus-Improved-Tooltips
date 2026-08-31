# Exosuit No Viewmodel UI

Branch `feature/exosuit-no-viewmodel-ui`. Tracking issue: #1 ("Exo hidden viewmodel fix").

Minigun and railgun charge as a percentage beside the crosshair, for exo pilots running with the
viewmodel hidden.

**Status: written, never run.** `luac -p` passes on every changed file, which proves they parse
under Lua 5.4 and nothing more — not NS2's 5.1, not the GUI layout, not the API use. Everything
below needs an in-game pass.

All line numbers refer to `D:\SteamLibrary\steamapps\common\Natural Selection 2\ns2\lua`.

## Why the readout disappears

Vanilla does show both figures, but it paints them onto the weapon model. The minigun renders
`lua/GUI<Slot>MinigunDisplay.lua` into the texture `*exo_minigun_<slot>`
(`Weapons/Marine/Minigun.lua:390-400`); the railgun does the same into `*exo_railgun_<slot>`
(`Weapons/Marine/Railgun.lua:364-375`). Hide the viewmodel and the surface those GUIViews are drawn
on goes with it.

Vanilla already treats this combination as a special case and patches part of it —
`GUIMarineHUD.lua:979-990` restores the armour text for a hidden-viewmodel exo — but does nothing
about weapon charge.

## The values are not stuck in the animation

Worth stating plainly, because the opposite is easy to assume. Both numbers are ordinary network
vars:

- `Minigun.heatAmount`, `"float (0 to 1 by 0.01)"` (`Minigun.lua:68`). A plain field, no accessor.
- `Railgun.timeChargeStarted`, `"time"` (`Railgun.lua:38`), behind the public
  `Railgun:GetChargeAmount()` (`:203`), which is
  `railgunAttacking and math.min(1, (Shared.GetTime() - timeChargeStarted) / kChargeTime) or 0`
  with `kChargeTime = 2` (`:22`).

Only the *rendering surface* was ever tied to the viewmodel. Nothing has to be recovered from
animation state.

## The reading matches vanilla's own

`GUIInsight_PlayerHealthbars.lua:300-315` already does this for its energy bar: reach the weapons
through `activeWeapon:isa("ExoWeaponHolder")` and `Shared.GetEntity(activeWeapon.leftWeaponId /
rightWeaponId)`, then `GetChargeAmount()` for a railgun or `heatAmount` for a minigun — **inverted**,
`1 - heat`, so the bar reads as remaining capacity.

**This script does not keep that inversion** (decided 2026-08-31). Each weapon prints what it is
actually doing:

| Weapon | Shows | Direction |
|---|---|---|
| Minigun | Heat | 0% cool, 100% overheated — up is bad |
| Railgun | Charge | 0% empty, 100% ready — up is good |

Heat counting up is what a pilot expects, and the figure is labelled by the thing it measures rather
than by its complement. The cost is that the two weapons read in opposite directions, so there is no
single warning threshold: `IT.kExoChargeWarnAbove` (75) colours a hot minigun, and
`IT.kExoChargeReadyAt` (100) colours a charged railgun, in separate colours.

**One deliberate difference: the slots are not averaged.** Vanilla averages dual weapons into one
bar, with its own source comment calling that a placeholder ("Maybe 2 bars eventually?"). An exo's
arms overheat independently and averaging hides the one that is about to fail, so each slot gets its
own figure on its own side — left arm to the left of the crosshair, right arm to the right.

## What is in this branch

| File | Change |
|---|---|
| `source/lua/ImprovedTooltips/GUIImprovedTooltipsExoCharge.lua` | New GUI script |
| `source/lua/ImprovedTooltips/ImprovedTooltips_ClientUI.lua` | Registers it for class `Exo` |
| `source/lua/ImprovedTooltips/ImprovedTooltips_Config.lua` | Config block at the end |

Registered for `"Exo"` rather than `"Player"`: ClientUI matches with `forPlayer:isa(class)`
(`ClientUI.lua:307`, `:386`), so one registration covers both exo variants and the script is never
created for anyone else.

Gating, in order, each frame: the master toggle, `player:isa("Exo")`, `Client.kHideViewModel` (the
same flag vanilla tests at `GUIMarineHUD.lua:980`, recomputed by `ViewModelOption_Update` at
`NS2Utility.lua:1781` whenever a drawviewmodel option changes), then an `ExoWeaponHolder` active
weapon.

## Config

`IT.kShowExoChargeNumbers` is the master switch, and the one the options panel will drive.
`IT.kExoChargeOnlyWhenViewModelHidden` defaults true — with the viewmodel visible, vanilla's gauges
are already on the weapon and a second readout is clutter. Offsets, font size, warning threshold and
both colours are constants alongside them.

## Test checklist

- Single minigun, single railgun, dual minigun, dual railgun, and one of each.
- The figure disappears when the viewmodel is switched back on, and returns when it is hidden again,
  without a map change — `ViewModelOption_Update` restarts `GUIMarineHUD` and `GUIExoEject` but not
  this script, so confirm the per-frame check is enough.
- Minigun held down to overheat: the number should climb to 100 and go orange, and fall back.
- Railgun: the number should reach 100 and change colour when fully charged.
- Ejecting from the exo, and dying in it, should leave nothing on screen.
- Resolution change, since `OnResolutionChanged` rebuilds both items.

## Not in this branch: the options panel

`IT.kShowExoChargeNumbers` is a constant here, not a live setting. The panel under Options > Mods is
shared infrastructure that the marine weapon colours branch needs too, so building it here would
mean writing it twice and merging it once. See `docs/mods-panel.md` for the registration recipe.
