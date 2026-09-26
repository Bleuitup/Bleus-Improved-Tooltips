# Phase gate arrows on the corner minimap

For 1.05. Built; awaiting the user's in-game test.

NS2 line numbers refer to `D:\SteamLibrary\steamapps\common\Natural Selection 2\ns2\lua`.

## The problem

The user noticed phase gate arrows, static or animated, show on the big map and on the marine HUD's
minimap, but not on the commander's corner minimap, and asked for a toggle, default on, that turns
them on there whenever the vanilla phase gate line setting asks for arrows.

## Why vanilla leaves them out

One condition in `GUIMinimapConnection:UpdateAnimation` (`GUIMinimapConnection.lua:32`):

```lua
local animatedArrows = not modeIsMini and teamNumber == kTeam1Index
                       and #GetEntitiesForTeam("MapConnector", kTeam1Index) > 2
```

`GUIMinimap.lua:1259` passes `self.comMode == GUIMinimapFrame.kModeMini` as `modeIsMini`:

| Map | Mode | Arrows in vanilla |
| --- | --- | --- |
| Big map (map key), any player | `kModeBig` | Yes |
| Marine HUD corner minimap | `kModeZoom` (`GUIMarineHUD.lua:372`) | Yes |
| Commander's and spectator's corner minimap | `kModeMini` (`Commander_Client.lua:767`) | **No** |

That one flag gates the static arrows (texture row 16 when `kLineMode > 0`, `:40`) and the animation
(`kLineMode > 1`, `:33`), and also thins the line from 10 to 6 (`:44`).

The setting is `AdvancedOptions["pglines"]` (`AdvancedOptions.lua:1001`, option path
`CHUD_MapConnectorLines`): 0 solid, 1 static arrows, 2 animated lines (dashed texture), 3 animated
arrows, default 3. It is mirrored onto `GUIMinimapConnection.kLineMode`.

## What the hook does

Post-hook on `lua/GUIMinimapConnection.lua`, wrapping `UpdateAnimation`. On the corner map, when the
line would have had arrows anywhere else - marine team, `kLineMode > 0`, more than two gates - it
calls vanilla with `modeIsMini = false`. Everything else goes to vanilla untouched.

- **The player's own setting still decides.** Solid mode draws no arrows here either.
- **Thickness 10, settled with the user (2026-09-13).** The marine HUD's minimap is about the same
  size and already carries arrows at 10. At vanilla's 6 the 16 pixel arrow art is squashed past
  reading. Lines without arrows keep 6, so the corner map looks unchanged wherever there is nothing
  to add.
- **Spectators included, settled with the user.** Their corner map is the same `kModeMini`; no
  viewer check.

Setting: PHASE GATE ARROWS ON CORNER MINIMAP in the Mods panel, option key
`BIT_MinimapPhaseGateArrows`, config `IT.kCommanderMinimapPhaseGateArrows`, default on. Read on
every call, so toggling applies immediately.

## Test checklist

Three or more phase gates on the marine team are needed; with two, vanilla draws no arrows anywhere.

```
cheats 1
autobuild 1
```

- Commander, toggle on, phase gate lines = animated arrows: arrows animate on the corner minimap.
- Same, static arrows: arrows, no animation.
- Same, animated lines: dashed lines animate.
- Same, solid: plain thin lines, exactly vanilla.
- Toggle off: plain thin lines, exactly vanilla, and switching applies without a restart.
- Two phase gates only: no arrows on any map, as vanilla.
- Big map and marine HUD minimap: unchanged.
- Spectator overhead view: the corner map matches the commander's.
- Changing the phase gate lines setting mid-round updates the corner map.

## Arrow size (1.08)

The user found the arrows too big on the corner map (2026-09-25). Vanilla draws them the same size on
every map: `UpdateAnimation` maps 1 texel of the 64x16 arrow art to 1 pixel along the line
(`x2Coord = x1Coord + self.length`, `:36`) and sets the height to `GUIScale(10)` (`:44`), whatever
the map's scale. The maps are not the same scale:

| Map | Map scale (`GUIMinimap:SetScale`) | Arrow size against the rooms |
| --- | --- | --- |
| Corner minimap, `kModeMini` | 1 (300 px at 1080p) | 1 |
| Marine HUD minimap, `kModeZoom` | 3 x zoom; default zoom 0.79 (`GUIMarineHUD.lua:1097-1106`), so about 2.4 | about 0.42 |
| Big map, `kModeBig` | 3 | 0.33 |

So the marine HUD minimap's arrows are exactly vanilla's size too; they only look smaller because
that map is zoomed in. Matching its look means scaling the arrows with the map.

The user chose 0.42, the marine HUD minimap's proportion at default zoom, from rendered options
(1.0, 0.6, 0.42, 0.33). After vanilla sets the line up, the hook stretches the texture span to
`length / scale` and sets the height to `GUIScale(10) * scale`: about 4 px tall, an arrow every
27 px. The animation phase is vanilla's, so the arrows still advance one arrow a second.
`IT.kCommanderMinimapPhaseGateArrowScale`, config only; 1 (or anything outside 0-1) gives vanilla's
size.

Known from the render: at 0.42 the thin line between the arrowheads is under a pixel, so the line
reads mostly as a row of small arrowheads. The user saw this in the render and chose it.

Not adjusted: `Setup` moves both end points up 4 px (`:58-59`) to center a 10 px line. A 4 px line
may sit a pixel or two off the gate blips. Check in game; nudge only if it shows.

### Test checklist (1.08)

- Three or more gates, animated arrows: small arrows on the corner map, moving.
- Static arrows and animated lines: same size, lines dashed in the second case.
- The line sits on the gate blips (see the note above).
- Solid lines, two gates, alien tunnels, toggle off: exactly vanilla.
- Big map and marine HUD minimap: unchanged.
