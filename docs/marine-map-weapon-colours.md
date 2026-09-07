# Marine map blips coloured by weapon

Branch `feature/marine-weapon-colours`, for 1.03. **Built and parsing; never run in game.**

Marine player blips on the map take a colour per weapon, so the map says where the shotguns are
rather than only where bodies are. Optional and off by default.

NS2 line numbers refer to `D:\SteamLibrary\steamapps\common\Natural Selection 2\ns2\lua`.

## Settled with the user, 2026-09-07

| | |
| --- | --- |
| Which blips | Marine and JetpackMarine only. **Exos keep the plain marine colour** — under CBM an exo is modular and can carry any combination, so there is no single weapon to colour one by. Vanilla DOES colour exos in `GUIInsight_PlayerHealthbars` (minigun red, railgun orange); the CBM reason is the one that decides it |
| Which weapons | The four vanilla already distinguishes. Rifle, pistol, welder and axe keep the player's own `playercolor_m` |
| Who sees it | Marines and spectators only |
| Friend tinting | Composes on top: a friend with an HMG is half-saturated red |
| Own blip | Untouched. Not a `MapBlip` at all |
| Setting | In the Mods panel, default **off** |
| Colourblind | Nothing to do |
| Art | **None.** This branch ships no `.dds` |

## The colours are vanilla's own

`EquipmentOutline.lua:17-27` already maps weapon class to a colour, for the outline on a dropped
weapon in the world:

```lua
kEquipmentOutlineColor = enum { [0]='TSFBlue', 'Green', 'Fuchsia', 'Yellow', 'Red' }
local lookup = { "Shotgun", "GrenadeLauncher", "Flamethrower", "HeavyMachineGun" }
```

The index is a material parameter sampled out of `ui/marine_outline_lookup.dds`, so the RGB is in a
texture rather than in Lua. Decompressed and read directly:

| weapon | colour |
| --- | --- |
| default — rifle, pistol, welder, axe | `#00EFFF` |
| Shotgun | `#00FF00` |
| Grenade Launcher | `#FF00FF` |
| Flamethrower | `#FFFF00` |
| Heavy Machine Gun | `#FF0000` |

Reusing them means one mapping to learn, holding in the world and on the map. The default is not
applied here: leaving rifles on `playercolor_m` respects a setting the player already chose, and
that colour (`#00D8FF`) is near enough to `#00EFFF` that the two read as the same family anyway.

**Corroborated against the spectator ammo bars, and they agree.**
`GUIInsight_PlayerHealthbars.kAmmoColors` (`:42-54`) is a second, independent per-weapon palette,
used for the ammo bar under a marine in the SPECTATOR overhead view. On the four weapons this
feature colours, the two systems are identical:

| weapon | outline lookup | ammo bar | |
| --- | --- | --- | --- |
| Shotgun | `#00FF00` | `Color(0,1,0,1)` | same |
| Grenade Launcher | `#FF00FF` | `Color(1,0,1,1)` | same |
| Flamethrower | `#FFFF00` | `Color(1,1,0,1)` | same |
| Heavy Machine Gun | `#FF0000` | `Color(1,0,0,1)` | same |

So there is no side to pick: green shotgun, fuchsia GL, yellow flamethrower and red HMG are
vanilla's answer in both places, and now on the map too.

Where the two do differ is everything else, and it is worth knowing:

- **Rifle.** The outline palette defaults it to `#00EFFF` cyan; the ammo bars give it `#0000FF`
  blue. Vanilla is not self-consistent here. It costs us nothing, because rifles are deliberately
  left on the player's own `playercolor_m` rather than taking either.
- **Sidearms.** The ammo bars colour a pistol teal and axe, welder, builder and mines white. The
  outline palette has none of them. Again untouched here.
- **Exos.** The ammo bars DO distinguish them: minigun red `#FF0000`, railgun orange `#FF8000`.
  Only the outline palette lacks exo colours.

That last point corrects a claim made elsewhere in this document and in the commit for this branch:
"vanilla has no exo colour" is true of the outline palette and **false in general**. The reason exos
keep the plain marine colour is the CBM one on its own — an exo there is modular and can carry any
combination, so there is no single weapon to colour it by, and a minigun/railgun split would be
wrong the moment CBM changed a loadout. That reasoning stands without the false premise.


## CBM's SMG, and how much of this can be dynamic

**CBM adds a sixth weapon and colours it itself.** Its `Globals.lua:185` appends `"Submachinegun"`
to `kPlayerStatus` (appended last, so every vanilla index is preserved), its `Marine.lua:841` returns
that status, and its `EquipmentOutline.lua:17-27` extends `kEquipmentOutlineColor` with `'Orange'`
and maps `"Submachinegun"` to it. Its own `ui/marine_outline_lookup.dds` carries six entries:

| index | colour | |
| --- | --- | --- |
| 0-4 | `#00EFFF` `#00FF00` `#FF00FF` `#FFFF00` `#FF0000` | byte-identical to vanilla |
| 5 | `#D37300` | Submachinegun, CBM's own |

So CBM extended the palette rather than changing it, and the SMG has a defined colour: orange.

**Almost none of that is readable at runtime, and it is worth being precise about why.**

| source | reachable from Lua? | |
| --- | --- | --- |
| `kEquipmentOutlineColor` | yes | just an enum of names, no RGB |
| `EquipmentOutline`'s weapon list | **no** | `local lookup` (`:20`), a file-local |
| the outline RGBs | **no** | in `ui/marine_outline_lookup.dds`, sampled by a material parameter |
| `GUIInsight_PlayerHealthbars.kAmmoColors` | **yes** | public table on a public script, keyed by `kMapName` |
| `kPlayerStatus` | yes | public enum, and mods do extend it |

The authoritative palette is therefore unreadable, which is why its values are read out of the
texture and written into config. `kAmmoColors` is the one per-weapon palette a mod can both read and
add to at runtime, so this file consults it for anything not named in config:

1. config table, by `kPlayerStatus` value
2. `kAmmoColors`, bridged from the status NAME to a `kMapName`
3. nothing — the blip keeps the plain marine colour

That is the dynamic half. A mod that adds a weapon, gives it a `kPlayerStatus` value and lists it in
`kAmmoColors` gets a map colour here with no patch to this mod.

**The bridge is lowercase**, which is correct for `rifle`, `shotgun`, `grenadelauncher` and
`flamethrower`. Two do not follow it and are aliased: `HeavyMachineGun` to `hmg` and `Submachinegun`
to `smg`.

**Why the SMG is in config rather than left to the fallback:** CBM does **not** list `smg` in
`kAmmoColors` (`:42-56`; it adds `exoflamer` and `PlasmaLauncher` but not the SMG). Its own commander
ammo bar therefore falls through to `kEnergyColor`, which is yellow — the flamethrower's colour. Left
to the fallback we would inherit that collision. Naming it in config keeps the map agreeing with
CBM's world outline instead, which is the colour a player actually associates with the weapon.

Worth telling the CBM developers about, since it is a small inconsistency on their side: a spectator's
SMG ammo bar reads flamethrower yellow while the same weapon's outline glow is correctly orange.

Everything here costs nothing without CBM: `rawget(kPlayerStatus, "Submachinegun")` is nil in
vanilla, so the entry never resolves to a status and is never used.


## Who sees which palette

The two palettes are not shown to the same people, which matters when reasoning about what a
mismatch would actually look like:

| | palette | seen by |
| --- | --- | --- |
| Weapon outline glow in the world | outline lookup (`.dds`) | everyone, **including the commander** — `CommanderGlowMixin.lua:32` adds the model to `EquipmentOutline` so equipment can be picked out of the darkness from above |
| Ammo bar under a marine | `kAmmoColors` | **spectators only**. Both health bar scripts are created and destroyed by `GUIInsight_Overhead.lua:224,227`, the spectator overhead view, and nowhere else |
| Map blip | this mod | marines and spectators |

So CBM's SMG gap shows up for **spectators**, not commanders: a spectator's SMG ammo bar falls
through to `kEnergyColor` yellow, the flamethrower's colour, while the commander's outline glow for
the same weapon is correctly orange.

## Feed the base colour, do not return the result

`GetMapBlipColor` (`MapBlip.lua:272`) picks a colour by blip type and **then** transforms it:

```lua
if MapBlip.kFriendsHighlightingEnabled and friendTeams[blipTeam] then
    local hue, sat, val = RGBToHSV(color)
    sat = sat * .5
```

Steam friends are not a separate colour, they are half the saturation of whatever was chosen. **A
wrapper that returned a weapon colour would land after that block and wipe it.** So the mod sets
`MapBlip.kCustomMarineColor` for the duration of the original call and restores it after, inside a
`pcall` so a fault cannot leave every marine stuck on one weapon's colour. The friend tint, the
hallucination check and the commander's same-building highlight all keep working untouched.

## Gate on the viewer, not on the blip

An alien **can** see a marine blip. `MapBlip.lua:326`:

```lua
-- Allow enemies to see friends on the other team.  Used to be a bug, now it's a feature. :)
```

Colouring by blip type alone would tell the alien team what their Steam friend is carrying. Vanilla
guards a comparable leak two lines below — `friendshipSecret`, commented *"Don't give the enemy
privileged information!"* So the gate is `minimap.spectating or localPlayer:GetTeamNumber() ==
kTeam1Index`.

## Joining a blip to a weapon

Nothing new is networked. A blip knows its owner entity id (`MapBlip.lua:110`), and
`PlayerInfoEntity` carries `playerId` plus `status` — and **status is the weapon**: `kPlayerStatus`
holds `Rifle`, `Shotgun`, `GrenadeLauncher`, `Flamethrower`, `HeavyMachineGun` as values
(`Globals.lua:182`). It is already on every client because the scoreboard is built from it.

`PlayerInfoEntity.currentTech` is the wrong field — it is a bitmask of welder, grenades, mines,
jetpack and parasite, and carries no primary weapon.

The owner-to-status table is rebuilt on an interval, not per call: `GetMapBlipColor` runs once for
every blip on every minimap update, and walking the entity list inside that would cost many times
the drawing it feeds.

## Colourblind mode needs nothing

NS2 has **no Lua-side colourblind handling anywhere**. It is a render setting —
`Client.SetRenderSetting("colorblind_mode", n)`, `Render.lua:78`, three modes offered in
`menu2/MenuData.lua:3176` — applied to the whole frame downstream of everything. Any colour set
here gets the same filter as every other colour in the game. An earlier version of this document
listed "must react to the colourblind setting" as a requirement, as though there were something to
read. There is not.

## The local player's own marker

Not a `MapBlip`, and unreachable from this hook. It is a separate player icon with its own setting,
`AdvancedOptions["minimaparrowcolor"]` (`AdvancedOptions.lua:1066`, default `0xFFFF00`), applied
through `minimapScript:SetPlayerIconColor`. No exclusion needed.

## No art in this branch

An earlier cut shipped `source/ui/minimap_blip.dds` — vanilla's sheet with the jetpacker cell
swapped for Drey's darker edit. **Removed.** Sprite and colour are separate paths
(`BuildClassToGrid` versus `GetMapBlipColor`); this feature changes only the second, so whatever
sheet is loaded is irrelevant to it. Shipping art here imported an attribution question and a "we
now override CBM's whole sheet" problem for no gain to the feature.

For the record, since it was measured: the jetpack cell edit is the same in B2TP and CBM — mean
per-channel difference against vanilla 13.96 and 13.95, against each other 2.36, which is noise.
It is Drey's art and both the user and the CBM developers have his permission. Not a blocker, and
not this branch's business.

## Test checklist

**Never run in game.** `luac -p` passes, which proves the files parse and nothing more.

- Setting off, the default: the map looks exactly like vanilla.
- Setting on, as a marine: shotgun green, GL fuchsia, flamethrower yellow, HMG red; rifles and
  sidearms unchanged from `playercolor_m`.
- A jetpacker with a shotgun: green, and still the jetpack glyph.
- An exo: plain marine colour, both flavours, and under CBM with a mixed loadout.
- A Steam friend on your own team carrying an HMG: red at half saturation, not full red.
- **As an alien, with a Steam friend on the marine team**: that friend's blip must NOT be weapon
  coloured. This is the leak the viewer gate exists for.
- As a spectator: both teams look right, marines coloured, aliens untouched.
- Your own arrow: unchanged, still `minimaparrowcolor`.
- Weapon swap mid-round: the colour follows within the refresh interval.
- Toggling the setting in the panel: applies immediately, no restart.
- With CBM loaded, and with Devnull's ESB loaded, since both are on the server.
