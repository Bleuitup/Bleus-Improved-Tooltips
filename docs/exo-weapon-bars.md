# Exo weapon bars

For 1.06, on `feature/exo-weapon-bars` (cut from the unpublished 1.05 branch). Built; awaiting the
user's in-game test. Replaces `feature/exosuit-no-viewmodel-ui`, which predated the Mods panel, showed
numbers only, and never ran.

NS2 line numbers refer to `D:\SteamLibrary\steamapps\common\Natural Selection 2\ns2\lua`.

## Settled with the user, 2026-09-14

| | |
| --- | --- |
| When | Exo viewmodel hidden (`Client.kHideViewModel`), **whatever the marine HUD bars style** (revised 2026-09-14, see below) |
| Setting | EXO WEAPON BARS in the Mods panel, `BIT_ExoWeaponBars`, default **on** |
| Per arm | One bar each side, never averaged |
| Look | ydy center bar stroke at 2x thickness, further out than ydy, number below |
| CBM | Target is CBM's **dev** branch |
| Mockups | Approved on the user's own exo screenshot |

## Why it is needed

Vanilla paints minigun heat and railgun charge onto the viewmodel's texture through GUIViews
(`Minigun.lua:390-400`, `Railgun.lua:364-375`); CBM's plasma launcher renders its dial into the same
railgun surface. Hiding the viewmodel removes the surface and the readout with it. Vanilla already
patches the armor text for this exact case (`GUIMarineHUD.lua:979-990`) but not weapon state.

## The condition

- `Client.kHideViewModel` is set by `ViewModelOption_Update` (`NS2Utility.lua:1781`): true for
  "Hide all", or "Custom" with `drawviewmodel_exo` off. It is recomputed whenever the local player
  changes (`Client.lua:1812`), so switching from marine to exo is covered.

**Marine HUD bars used to be a second condition and no longer are.** The first build required
`hudbars_m == 0` (`AdvancedOptions.lua:306`: 0 Default, 1 Centralized, 2 NS1), on the reasoning that
Centralized and NS1 already show an exo readout (`GetWeaponAmmoFraction`, `NS2Utility.lua:84-99`).
After testing, the user dropped it: that readout squeezes both arms into one averaged bar, minigun
inverted, so a player can like those styles for marines and still want these bars in an exo. Nothing
collides - Centralized is 32-64 px from center, NS1 sits in the bottom corners, these start at 74.

## Arms, detected by what they expose

| Exposes | Arm | Bar |
| --- | --- | --- |
| `heatAmount` | Minigun | Heat: base color to `kExoBarHeatWarnFrom`, blend to warn by `kExoBarHeatWarnAt`, to hot at 100%; overheated pulses red with vanilla's formula (`GUIAdvancedHUDBars.lua:256`) |
| `GetChargeAmount` and `energyCost` | CBM PlasmaLauncher | Energy pool: fill is stored energy, tick at the shot cost read live, dim base below it, CBM's dial color once affordable (magenta Bomb, cyan MultiShot) |
| `GetChargeAmount` only | Railgun | Charge: `railgunAttacking` gates it, so 0 when idle and fills while held; white at 100% |
| none | Claw | Hidden |

`overheated` is a private network var; the fallback is `heatAmount >= 1`.

## CBM dev branch, as read 2026-09-14

CBM's GitHub repository is not public; read from the local dev build at
`G:\My Drive\[01] Martin\[03] Gaming\NS2 Server\Workshop Mods\Community Balance Mod (dev)` (newest
file 2026-09-05; the dev Workshop item 2992773495 was updated 2026-09-07 and is not on disk).

- Buyable weapon arms: Claw, Minigun, Railgun, PlasmaLauncher. **ExoFlamer and ExoShield are
  commented out of `ModularExo_Data.lua`** - discontinued, not built for.
- PlasmaLauncher: `energyWAmount` 0-1, starts 0.5, refills at `kPlasmaLauncherEnergyUpRate` 0.25/s,
  fires only with `energyWAmount >= energyCost`. The mode switch is commented out, so it is always
  `"Bomb"` at `kPlasmaBombEnergyCost` 0.80. Dev no longer loads the T1/T2 balls. The bomb
  electrifies aliens hit for `kElectrifiedDuration` 5 s - a target effect, nothing for this HUD.
- Railgun: dev changed only targeting and hit traces; charge is unchanged.
- Minigun and ExoWeaponHolder: identical to live CBM.
- CBM's own `GetWeaponAmmoFraction` still averages arms and carries a TODO that mixed minigun and
  railgun "will break".

## Geometry

1080p pixels, scaled by `GUIScale` and by `crosshairscale` above 1, as `GUIAdvancedHUDBars.lua:51-61`
does. Vanilla Centralized bars are a 32x64 quad 32 px from center; the ydy texture puts its stroke on
the quad's outer edge, so ydy draws at 59-64 px, 5 px thick, 4 px fill. These bars: inner edge 74 px,
10 px track (1 px strong edge, 1 px faint edge each side), 8 px fill, 64 tall, centered vertically,
percentage 4 px below. A crosshair scale change rebuilds on the next option poll (0.5 s).

## Test checklist

Vanilla or B2TP, then CBM dev for the plasma launcher.

```
cheats 1
```

Then `dualminigun` or `dualrailgun` (`NS2ConsoleCommands_Server.lua:2048-2050`; `exo` is also dual
minigun). Claw and minigun has no console command - buy it at a prototype lab. Advanced > Misc >
Draw viewmodel must hide the exo.

- Dual minigun: both bars fill while firing, blend blue to orange to red, pulse red when overheated,
  and each arm reads on its own.
- Dual railgun: 0% idle, fills while held, white at 100%, back to 0 after the shot.
- Claw and minigun: the claw side shows nothing.
- Viewmodel shown: no bars.
- HUD bars Centralized and NS1: bars still show, alongside vanilla's own, without overlapping.
- Setting off in the Mods panel: no bars, applied immediately.
- Crosshair scale above 1: bars move out and grow with it.
- CBM dev plasma launcher: fill refills over time, tick at 80%, dim below it, magenta at or above,
  drops by 80% per shot.
