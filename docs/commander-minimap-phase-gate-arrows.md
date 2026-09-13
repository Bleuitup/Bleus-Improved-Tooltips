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
