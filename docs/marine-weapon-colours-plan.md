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
- **Jetpackers keep the jetpack glyph and take the weapon colour** (settled 2026-08-31). The
  distinction is carried by the sprite, the colour by the weapon — the two are independent, so a
  jetpacker with a shotgun reads as "jetpack" and "shotgun" at once.
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

## Jetpackers already have their own sprite

No new art is needed for the distinction itself. Blip sprites are chosen by class name through
`BuildClassToGrid` (`NS2Utility.lua:2709`), and the jetpacker has its own cell:

    ClassToGrid["Marine"]        = { 1, 2 }
    ClassToGrid["Exo"]           = { 2, 2 }
    ClassToGrid["JetpackMarine"] = { 3, 2 }

in `ui/minimap_blip.dds`. `MapBlipMixin.lua:228` resolves the type with
`kMinimapBlipType[self:GetClassName()]`, so a jetpacker is already drawn with the jetpack glyph
today. Sprite and colour are independent, which is exactly why this decision costs nothing: tint the
glyph the marine already has.

### The sheet this branch ships (done 2026-08-31)

Vanilla's marine and jetpacker glyphs are nearly the same silhouette, so the sprite half of this
feature barely reads at map scale. B2TP darkens the jetpack backpack, and CBM ships the same edit.

`source/ui/minimap_blip.dds` here is **vanilla's sheet with only cell (3,2) replaced** by B2TP's
jetpacker. Verified: exactly one cell differs from vanilla in mip 0 (341 of 1024 pixels), every
other cell is byte-identical, and the file matches vanilla's format — 256x256, uncompressed RGBA,
9 mipmaps, 349,652 bytes.

Built rather than copied, deliberately:

- **B2TP's file could not be shipped as-is.** It is a DXT1 re-encode with a single mip level
  (32,896 bytes). Adopting it would have replaced every blip in the game with a block-compressed
  version and thrown away the mipmaps the minimap needs when it draws blips small.
- **CBM's file could not be shipped as-is either.** It is full quality, but it edits **18 cells**,
  not one. Taking it wholesale would have imported all of CBM's other blip art.

Method, if it ever needs redoing: `utils/nvdecompress.exe` on both sheets to TGA, composite cell
(3,2) with System.Drawing, then
`utils/nvcompress.exe -rgb -alpha -highqual merged.png minimap_blip.dds`.

### Two things to settle before this merges to main

1. **Shipping this file overrides CBM's whole sheet**, including the 17 other cells CBM edits, for
   anyone running both mods. Given how much this mod values CBM compatibility, that is a real cost
   for one glyph. Options: ship it anyway, drop the sheet and rely on colour alone, or ask the CBM
   team.
2. **Provenance.** The cell came from B2TP, the user's own mod, on their instruction. CBM ships a
   visually identical and technically cleaner version of the same edit. If the design originated
   with CBM, whether it belongs in this mod — and whether anything should be said in the credits —
   is the user's call, not one to make silently.

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
