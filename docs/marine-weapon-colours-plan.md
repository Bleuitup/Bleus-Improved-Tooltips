# Marine weapon colours on the large map — plan

Branch `feature/marine-weapon-colours`. Tracking issue: #1. Nothing here is implemented yet.

Opt-in setting that overrides the marine player colour on the large map, so a blip's colour says
what that marine is carrying.

All line numbers refer to `D:\SteamLibrary\steamapps\common\Natural Selection 2\ns2\lua`.

## Decisions

- **Large map only**, never the minimap. Gate on `minimap.comMode == GUIMinimapFrame.kModeBig`
  (`GUIMinimapFrame.lua:30-32` — Mini 0, Big 1, Zoom 2).
- **Marines only.** Colouring aliens the same way would hand the other team information it should
  not have.
- **Rifle has its own colour**, not inherited from the player's `playercolor_m`.
- Anything that is not a distinct primary — welder, pistol, mines — reads as rifle. This needs no
  code: `GetPlayerStatusDesc` inspects slot 1 only and already resolves them to
  `kPlayerStatus.Rifle`.
- Toggleable, so a busy palette is acceptable.
- Must react to the vanilla colourblind setting.

## Hook point

`MapBlip:GetMapBlipColor(minimap, item)` (`MapBlip.lua:272`) is the single function every blip
colour passes through. Today `marineBlipTypes` is `{ Marine, JetpackMarine, Exo }` (`:241`) and all
three take one flat `MapBlip.kCustomMarineColor`.

The vanilla colours it overrides come from `AdvancedOptions["playercolor_m"]` / `["playercolor_a"]`
(`AdvancedOptions.lua:1115-1153`), colour pickers writing `CHUD_PlayerColor_M` / `_A`, defaults
`0x00D8FF` and `0xFF8A00`, whose `immediateUpdate` sets `MapBlip.kCustomMarineColor` /
`kCustomAlienColor`.

## The weapon is already on every client — no new networking

`Marine:GetPlayerStatusDesc()` (`Marine.lua:773`, commented "Returns the name of the primary
weapon") resolves `GetWeaponInHUDSlot(1)` into `kPlayerStatus`: Rifle, Shotgun, GrenadeLauncher,
Flamethrower, HeavyMachineGun, with Exo as its own value. It rides the PlayerInfoEntity for the
scoreboard and lands in `playerRecord.StatusId` (`Scoreboard.lua:108`).

Join blip to player: `MapBlip:GetOwnerEntityId()` (`MapBlip.lua:110`, a networkVar) matched against
`playerRecord.EntityId` (`Scoreboard.lua:97`), read through `Scoreboard_GetPlayerRecord()` or
`ScoreboardUI_GetAllScores()`.

**Cache it.** The scoreboard is keyed by clientIndex, so matching on EntityId is a scan, and
`GetMapBlipColor` runs per blip. Build the map once per minimap update, not per blip per frame.

`GetPlayerStatusDesc` returns `Dead` before it looks at the weapon, so dead marines have no weapon
status to read.

## Colourblind

`kColorBlindOptionsKey = "graphics/display/colorblind_mode"` (`Globals.lua:388`), an int: 0 off,
1 Protanopia, 2 Deuteranopia, 3 Tritanopia (`menu2/MenuData.lua:3192-3198`).

It is applied as a **render setting** (`Render.lua:65-78`) — a post-process over the whole frame. It
transforms whatever we draw rather than reporting anything back, so it cannot keep a palette
separable on its own and may collapse two of our colours together. Read the option with
`Client.GetOptionFloat(kColorBlindOptionsKey, 0)` and swap to a second palette when it is non-zero.

## Settings

Goes in the mod's own panel under Options > Mods — see `docs/mods-panel.md` on the
`feature/exosuit-no-viewmodel-ui` branch for the registration recipe, since that branch needs the
same infrastructure. Six colour pickers plus one toggle.
