# Welder icon on nameplates

**Published in 1.10 (2026-10-19).** Built on `feature/welder-nameplate-icon`. Tested in game by the user on
2026-10-18: commander view and first person, small and large nameplates. The first test found the
icon staying over a marine whose plate had gone (see "Placement"); fixed, then resized to 0.8 and set
to 80% opacity from other players' feedback, and re-tested clean, with no errors in the log. The
stub-game harness has 32 checks.

NS2 line numbers refer to `D:\SteamLibrary\steamapps\common\Natural Selection 2\ns2\lua`.

## Settled with the user, 2026-10-18

| | |
| --- | --- |
| Why | So nobody has to ask who has a welder, or hold the scoreboard open to find out |
| Who sees it | The marine commander and marines in the field, Exo pilots included. Not spectators (the user dropped the spectator view), not aliens |
| Where | Right of the name. Devnull Shine Extras puts its request icons on the left |
| Art | The commander build menu welder (`ui/buildmenu.dds`, the cell `GetTextureCoordinatesForIcon(kTechId.Welder)` gives, cropped 13/14/10/14 px), tinted (205, 245, 255), the color of the kill feed and buy menu welders. 80% opaque, from other players' feedback after the first test (it was fully opaque) |
| Size | First 2x the name's capitals plus a pixel (26 px at 1080p with small nameplates), chosen from 1x, 1.5x and 2x mockups on the user's own screenshots. Then scaled by 0.8 from other players' feedback after the first test: about 21 px |
| Setting | WELDER ICON ON NAMEPLATES under MARINES, `BIT_WelderNameplateIcon`, default **on** |

The art was picked from five existing welder icons: kill feed (`ui/inventory_icons.dds`), build
menu, buy menu (`ui/buymenu_marine/weaponButtons.dds`, the same drawing as the help screen and
Devnull's scoreboard), pickup marker (`ui/drop_icons.dds`) and the weld prompt
(`ui/marine_welder.dds`).

## Nothing did this already

Checked 2026-10-18: neither vanilla nor any installed mod draws a welder on nameplates. Devnull
ESB shows welders in the scoreboard only; Devnull AdvancedHud only recolors the welder on your own
HUD; Devnull Shine Extras' improvedComHUD adds ammo and medpack request icons, left of the plate,
for the commander only.

## Where "has a welder" comes from

The nameplate data has a `HasWelder` field (`Player_Client.lua:528-531`), but it is only filled
within 10 m, because `UnitStatusMixin:GetHasWelder` asks the marine's own weapons, which a client
only has while the marine is close. From the commander chair that is almost never.

`PlayerInfoEntity.currentTech` is computed on the server for every player and already sent to every
client for the scoreboard. Its `displayWeapons` list includes the welder
(`PlayerInfoEntity.lua:188`), and the game's own `GetTechIdsFromBitMask` (`:224`) decodes it. CBM's
copy of the file keeps the same list. The mod rebuilds a player id to welder table every 0.25 s,
the same pattern as the weapon colored map blips, and still accepts the close-range `HasWelder` so a
welder bought beside you shows at once.

## Placement

The icon is a child of the plate's `statusBg`, anchored Middle/Top like `NameText`, and is shown
only while `NameText` is visible **and holds text**, so it follows the game's own ranges (13 m in the
field, 50 m from the chair, `Player_Client.lua:375-376`) and its rules for when names show.

**Visible is not enough.** In first person a teammate's plate stays in the list the whole time they
are within 13 m, but `PlayerUI_GetStatusInfoForUnit` fills in the name only while
`PlayerUI_ShowsUnitStatusInfo` (`Player_Client.lua:418`) holds: you aim at them, they are selected by
you as commander, or marked. The rest of the time the name is `""` (`:509-513`, held for the 0.2 s
state cache, `UnitStatusMixin.lua:107`) and the bars are hidden, so nothing shows. The first build
only tested `GetIsVisible()` and left the icon floating over the marine. So in first person the icon
shows while you aim at a welder carrier, and the user accepted that on 2026-10-18 as the scope: it
improves what the nameplate already tells you.

**Every nameplate style behaves the same** (Advanced > NAMEPLATE STYLE: DEFAULT, NUMBERS, BARS ONLY,
NUMBERS + BARS). NUMBERS swaps the name for a health percentage, but `percentageString` is only ever
built for non-players (`Player_Client.lua:461-464`), so a teammate's plate keeps the name; BARS ONLY
hides names on non-players only (`GUIUnitStatus.lua:764`).

Size and offsets are in units of the name's line height (`GetTextHeight("!") * scale`), so the same
numbers fit small and normal nameplates at any resolution:

- height 0.96 lines (1.2 before the 0.8 resize), width from the crop's aspect (57:52)
- left edge 0.23 lines right of the text's right edge (half `GetTextWidth * scale` right of center)
- centered 0.43 lines below the text's top, on the capitals

Those ratios were measured on the small-nameplate font (Agency tiny at 1.08, a 21.6 px line) at
1080p, assuming `GetTextHeight("!")` returns the line height, as `GUIChat.lua:418` treats it. The
first in-game test bore that out: the user found the size and position right with small and large
nameplates, in the commander view and in first person.

## Other mods

- CBM ships its own `GUIUnitStatus.lua` and Devnull AdvancedHud replaces it; all keep `statusBg`,
  `NameText` and `UpdateUnitStatusBlip(blipIndex, ...)` as vanilla has them. The post-hook wraps
  whichever loaded. If one is missing the icon is never made.
- The wrapper calls the original first and runs the icon under `pcall`; after an error it prints
  once and stops, so a fault cannot take the nameplates down.

### The map colors' palette read had to follow wrappers

`ImprovedTooltips_MapBlipColor.lua` reads the commander's ammo bar colors (`kAmmoBarColors`) out of
`GUIUnitStatus.UpdateUnitStatusBlip`'s upvalues. Wrapping that method, as this feature does, would
have hidden them and dropped the map to its fallback colors. The search now follows function
upvalues down up to four levels. That also fixes a case that was already there: Devnull Shine
Extras wraps the same method at runtime.

## Test checklist

1. Field marine, a teammate with a welder: icon right of the name, the size of the mockup. (Passed 2026-10-18.)
1a. First person, look away from that teammate: the icon goes when the plate does, and comes back on
    aiming at them again. (The fix after the first test.)
2. Teammate drops or buys a welder: icon follows within a moment.
3. Commander chair: icon on teammates' plates wherever their names show.
4. Exo pilot: sees it. Dead marine, spectator, alien: never.
5. Normal (not small) nameplates, under Advanced: icon scales with the name. (Passed 2026-10-18.)
6. Setting off in the Mods panel: icons go at once.
7. Weapon colored map blips still use the commander palette (`it_blipcolors` says "read from GUIUnitStatus at runtime").
8. With CBM, and with Devnull Shine Extras' request icons on screen.
