# Centralized HUD bars: alien shield bar and bar opacity

For 1.06, on `feature/centralized-bars-shields`. Built; awaiting the user's in-game test.

NS2 line numbers refer to `D:\SteamLibrary\steamapps\common\Natural Selection 2\ns2\lua`.

## Settled with the user, 2026-09-15

| | |
| --- | --- |
| Where | Centralized HUD bars only (`hudbars` 1). NS1 and the default HUD untouched |
| Shield bar | Aliens. One bar, segmented, outboard of the health bar. Setting SHIELD BAR, default on |
| Segments | Bottom to top: babblers tan, vampirism green, mucous lavender |
| Scale | Combobox SCALE: Relative (default) / Absolute |
| Style | Combobox STYLE: Vanilla (default) / ydy |
| Number | One number, the sum, green (`0, 1, 0.2`), `Fonts.kAgencyFB_Tiny`; corner number hidden |
| Expiry cue | None - players "feel for" shield time, and this is new information |
| Opacity | Slider CENTRALIZED BAR OPACITY, both teams, shield bar included. Default 1 (fully opaque), floor 0.30 (vanilla) |
| Bar texture mods | An installed bar texture (ydy) supersedes vanilla's art |

The user revived this themselves; it had been shelved on 2026-08-30 when the mod was tooltips-only.

## Vanilla

**Three shield sources**, all networked to the owning client:

| Source | Mixin | Current / max |
| --- | --- | --- |
| Mucous | `MucousableMixin` | `GetMuscousShieldAmount` (sic) / `GetMaxShieldAmount` - skulk 20% of base health, others the babbler percentage capped 85; lasts 5 s |
| Babblers | `BabblerClingMixin` | `GetBabblerShieldAmount` / `GetMaxBabblerShieldAmount` |
| Vampirism | `ShieldableMixin` ("overshield") | `GetOverShieldAmount` / `GetMaxOverShieldAmount` = 1.5 x max health x class vampirism scalar x 3. Leeched health is ADDED per hit (`DamageTypes.lua:158`, `ShieldableMixin.lua:166-178`) up to that three-shell cap, then decays |

`GetMaxOverShieldAmount` has no scalar for Embryo and does `nil * 3`; the mod reads it under `pcall`.

**Display.** `PlayerUI_GetMucousShieldHP` (`Alien_Client.lua:329`) sums each source rounded up, and
the maxima of only the sources above zero. The default HUD draws one ring at sum / sum-of-maxima
(relative) and one green number. Ring art: pale and veined if any mucous, green otherwise
(`ui/alien_hud_health.dds` at 0,320 and 160,320). With Centralized or NS1 the ring is hidden
(`GUIAlienHUD.lua:286`, `:734`) and the number stays in the corner. CBM dev: identical gating in its
own `GUIAlienHUD.lua`; it does not replace the mixins or `GUIAdvancedHUDBars.lua`.

**Damage order** (`DamageTypes.lua:303-318`): `ComputeDamageOverrideMixin` (mucous), then
`ShieldComputeDamageOverrideMixin` (overshield), then `ModifyDamageTaken` (babblers).

**Centralized bars** (`GUIAdvancedHUDBars.lua`): 32x64 quads (times GUIScale and crosshair scale above
1), 32-64 px from center, all `ui/centerhudbar.dds`, Middle/Center anchors; left = health + armor
stacked, right = energy (aliens) or ammo (marines). Vanilla's art peaks at alpha 76/255.

## Opacity

A color cannot make art more opaque than it is. "HL2 Center Hudbar Fix" (Workshop 1382367868) does it
by replacing `ui/centerhudbar.dds` (fill peak 76 -> 208) - the same file the ydy mod replaces, so they
cannot both apply. Shipping an opaque copy would override ydy the same way.

So the bars are redrawn as stacked copies of the installed art: n copies of alpha a composite to
`1 - (1 - a)^n`, the last copy's alpha scaled to land on the target (`ImprovedTooltips_BarLayers.lua`).
At the floor it is one copy at full alpha - vanilla - and nothing is created. Opaque art such as
ydy's fill is unchanged at any setting. After vanilla's `Update` each vanilla item is read back
(geometry, color, visibility, and `guiItem.texPixCoords`, which `GUIAnimatedItem` records) onto its
copies, and the vanilla item is hidden.

## Shield bar

- Geometry from `leftBarBg`: Vanilla style is a third quad one width outboard; ydy style is a 5-unit
  stroke 5 units outboard of the bar (the ydy art is the bar's outer 5 of 32 units).
- Calibrated against the user's screenshots (crosshair scale about 1.1; ydy strokes measured at
  66-70 px): the ydy style stroke clears the ydy health bar by about 6 px.
- Segment texture regions follow vanilla's armor-on-health stacking (`:372-380`).
- The number is right-aligned just past the bar's center so longer totals grow away from vanilla's
  health text.

## Test checklist

```
cheats 1
mucous
overshield 50
```

`mucousother` / `overshieldother` apply them to the player you aim at. Babblers need a gorge; a gorge
can attach its own babblers.

- Aliens, HUD bars Centralized: mucous alone fills the bar (relative); adding overshield and babblers
  stacks tan / green / lavender bottom to top; the total matches vanilla's number; the corner number
  is gone.
- SCALE Absolute: the same shields take a smaller share of the bar.
- STYLE ydy, with the ydy mod: a thin stroke beside the ydy health bar, no overlap.
- Opacity 1: bars clearly solid; 0.30: identical to vanilla; changes apply immediately.
- Marines, Centralized: opacity applies; exo weapon bars still hide the right-hand bar.
- NS1 and default HUD: unchanged. SHIELD BAR off: no bar, corner number back.
- Crosshair scale changes, resolution changes, death and respawn, evolving.
- CBM dev and B2TP.
