# Alien shield bar

Published in 1.21 (2026-11-15), built on `feature/1.21-shield-bar`. Tested in game by the user from
Launch Pad on 2026-11-15 (build 345.4620 beta), with no script errors from the mod; before that the
logic passed a stub-game harness (29 checks) and `tools/check_mod.lua`. The one script error in that
session was vanilla's: the `overshield` cheat on an egg reaches `GetMaxOverShieldAmount`
(`ShieldableMixin.lua:78`), which has no Embryo scalar. The mod reads it under `pcall`.

It replaces the 1.06-era attempt on `feature/centralized-bars-shields` (2026-09-15), whose first
in-game test showed the bar but failed elsewhere: the ydy style did not draw, the number was
misaligned, and the bar opacity layering threw about 23,000 errors. That branch is reference only.

NS2 line numbers are from build 345 (the `beta` branch of the ns2-game mirror, 2026-11-13).
`GUIAdvancedHUDBars.lua` is unchanged from 344 apart from line endings.

## Settled with the user, 2026-11-15

| | |
| --- | --- |
| Where | Aliens, Centralized HUD bars only (`hudbars_a` 1). NS1 bars and the default HUD untouched |
| Setting | SHIELD BAR, under ALIENS, on by default. The only option |
| Dropped | The SCALE and STYLE comboboxes and the CENTRALIZED BAR OPACITY slider of the first attempt. Players who want opaque bars have the HL2 Center Hudbar Fix |
| Segments | Bottom to top: babblers tan, vampirism green, mucous lavender |
| Full bar | Mucous cap + babbler cap + vampirism cap of the lifeform at biomass 1. Vampirism always counted, with or without the upgrade. Over 100% is cut off at the top |
| Art | Whatever `ui/centerhudbar.dds` is installed, drawn like vanilla's bars, so ydy-style textures restyle it |
| Spacing | One bar width outboard of the health bar, less half the gap vanilla's art leaves between bars (23/64 of a width). One value for every texture: which one is installed cannot be told from Lua |
| Number | The total, rounded up per shield like vanilla's. Green (`0, 1, 0.2`), `Fonts.kAgencyFB_Tiny`, with a black copy 2 px down-right like the bars' health text. Always shown while there is any shield; hidden at zero. Vanilla's corner number is hidden while the setting is on |
| Expiry cue | None |

Mockups: `Improved Tooltips Images\Shield Bar 1.21` (comparison, gap options; the user picked 50%).

## The scale

The user's reasoning: vanilla's ring is relative to whichever shields are active
(`PlayerUI_GetMucousShieldHP`, `Alien_Client.lua:330`, sums the maxima of only the shields above
zero), so a full ring can mean a full vampirism charge alone or all three shields at their caps. A
fixed scale per lifeform makes a given fill mean the same amount every time. Having all three full at
once is rare, so the reference is biomass 1 and anything above it is capped.

Caps on build 345, at base health:

| Lifeform | Mucous | Babblers | Vampirism | Full bar |
| --- | --- | --- | --- | --- |
| Skulk | 15 | 21 | 16 | ~52 |
| Gorge | 21 | 21 | 19 | ~61 |
| Lerk | 25 | 25 | 16 | ~66 |
| Fade | 40 | 40 | 38 | ~118 |
| Onos | 70 | 70 | 58 | ~198 |

- Mucous: `MucousableMixin:GetMaxShieldAmount` - skulk 20% of base health, others the babbler
  percentage, capped at 85.
- Babblers: `GetMaxBabblerShieldAmount`, set from base health in `BabblerClingMixin:__initmixin` on
  both client and server.
- Vampirism: `ShieldableMixin:GetMaxOverShieldAmount` = 1.5 x MAX health x class scalar x 3. Max
  health grows with biomass (`BiomassHealthMixin`: base + (biomass - 1) x health per biomass), so the
  mod scales it back by base / max to get the biomass 1 cap. That also follows any balance mod that
  changes the scalars. Embryo has no scalar and the method throws; read under `pcall`.

All current amounts are network fields (`shieldRemaining`, `babblerShieldRemaining`,
`overShieldRemaining`), so the owning client reads them directly.

Damage order (`DamageTypes.lua`): mucous first, then the overshield, then babblers - hence babblers at
the bottom and mucous on top, emptying first and cut first on overflow.

## How it is drawn

`ImprovedTooltips_ShieldBar.lua`, a post-hook on `GUIAdvancedHUDBars.lua`:

- After vanilla's `Initialize`, on the alien team with Centralized bars, it builds plain GUI items:
  the track, three fills, the number and its shadow. Geometry is recomputed the way vanilla computes
  its own (`:52-62`): bars 32 x 64 GUI units, times the crosshair scale when that is above 1.
- `Update` reads the shields each frame and places the segments the way vanilla stacks armor on
  health (`:372-385`): positioned at the segment's bottom, negative height, art rows cropped to the
  same share.
- Before vanilla's `Uninitialize` it destroys its items. `Reset` (resolution change, team swap) runs
  both, so the bar is rebuilt with vanilla's.
- Hidden when the setting is off, under the help screen (`self.vis`), when dead, in an egg, and when
  there is no shield.
- Any error is reported once to the console and the bar is removed for that HUD's lifetime.

The number's right edge sits 6 px left of where vanilla's health text (centered at
`leftBarXOffset / 2 - 12`, `:124`) starts at its widest for the current lifeform: its max health and
max armor written with zeros. It moves only when those maxima change.

`ImprovedTooltips_AlienHUD.lua` hides vanilla's corner number (`mucousText`) after each
`GUIAlienHUD:Update`, which sets it from `UpdateMucousBall` every frame (`:1056-1058`, `:1279`).

## Test checklist

```
cheats 1
mucous
overshield 50
```

`mucousother` / `overshieldother` apply them to the player you aim at. Babblers need a gorge; a gorge
can attach its own babblers. Switch HUD bars under Options > Advanced.

- Aliens, Centralized: no shield, no bar and no number. Mucous alone: a lavender segment of about
  15/52 of the bar on a skulk; the number matches what vanilla's corner number would show.
- All three: tan / green / lavender bottom to top; number = total. Mucous wears off first from the
  top.
- Higher biomass with all three near full: the bar stops at the top, the number keeps counting.
- Spacing: about 13 px between the bars with vanilla's art, 16 px with ydy's (at 1080p, crosshair
  scale 1.1). Try another crosshair scale and resolution.
- The number never touches vanilla's health text when that pops up after taking damage, on every
  lifeform, onos included.
- Corner number: gone with the setting on, back with it off; untouched on the default HUD and NS1.
- SHIELD BAR off: no bar, applies immediately.
- Marines with Centralized: nothing new. Spectating: nothing new.
- Death, respawn, evolving (no bar in the egg), team swap, resolution change.
- `log.txt`: no `[Bleu's Improved Tooltips]` lines and no script errors.
