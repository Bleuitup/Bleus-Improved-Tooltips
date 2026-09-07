# Marine map blips coloured by weapon

Branch `feature/marine-weapon-colours`, for 1.03. **Built and parsing; never run in game.**

Marine player blips on the map take a colour per weapon, so the map says where the shotguns are
rather than only where bodies are. Optional and off by default.

NS2 line numbers refer to `D:\SteamLibrary\steamapps\common\Natural Selection 2\ns2\lua`.

## Settled with the user, 2026-09-07

| | |
| --- | --- |
| Which blips | Marine and JetpackMarine only. **Exos keep the plain marine colour** — under CBM an exo is modular and can carry any combination, so there is no single weapon to colour one by. Vanilla DOES colour exos in `GUIInsight_PlayerHealthbars` (minigun red, railgun orange); the CBM reason is the one that decides it |
| Which weapons | Whatever the commander's own palette distinguishes, read at runtime — the four vanilla weapons plus anything a mod adds, CBM's SMG included. Rifle, pistol, welder and axe keep the player's own `playercolor_m` |
| Who sees it | Marines and spectators only |
| Friend tinting | Composes on top: a friend with an HMG is half-saturated red |
| Own blip | Untouched. Not a `MapBlip` at all |
| Setting | In the Mods panel, default **off** |
| Colourblind | Nothing to do |
| Art | **None.** This branch ships no `.dds` |

## Read at runtime, not hardcoded

The colours come out of the running game. `GUIUnitStatus.lua:57-64` holds `kAmmoBarColors`, keyed by
`kTechId` — the palette a commander is already reading on the ammo bar under each marine, on the
same screen as this map.

It is a file-local, so it cannot be indexed. It **can** be pulled from the upvalues of a function
that closes over it — `GUIUnitStatus:UpdateUnitStatusBlip`, which uses it at `:678`:

```lua
local name, value = debug.getupvalue(GUIUnitStatus.UpdateUnitStatusBlip, index)
if name == "kAmmoBarColors" and type(value) == "table" then ...
```

That is normal practice in this ecosystem rather than a trick: Shine ships a wrapper for it
(`shine/lib/debug.lua:9`) and NSL uses it too (`NSL/eventhooks/server.lua:176`).

**The bridge is by name, so nothing is per-mod.** `kPlayerStatus` and `kTechId` use identical names
for every weapon that matters — `Shotgun`, `GrenadeLauncher`, `Flamethrower`, `HeavyMachineGun`, and
CBM's `Submachinegun` — so a blip's status resolves to a techId with no table of ours in between.
**CBM's SMG is therefore not hardcoded**: CBM adds `kTechId.Submachinegun` to its own
`kAmmoBarColors` and this picks it up, and so would any other mod that adds a weapon the same way.

`kTechId` is an **engine enum that raises on an unknown name**, so the lookup goes through
`IT.GetTechIdByName`, which rawgets.

**Failure is handled, not assumed away.** If `GUIUnitStatus` has not loaded yet the read is retried
rather than given up on, and results are only memoised once the question is settled — caching early
would pin every weapon to the fallback for the session. If the read genuinely cannot happen (no
debug library, a mod that replaces `GUIUnitStatus` with something shaped differently, a rename), the
written-down table in config takes over, holding copies of the same values.

**Rifles are excluded explicitly**, along with pistol, axe and welder. The commander palette *does*
colour a rifle — teal — but taking it would repaint every ordinary marine and discard the player's
own `playercolor_m`. Only the loud weapons deviate from it.

## Three palettes, not two

There are **three** per-weapon colour tables in NS2, and they are shown to different people. I found
the first two and reasoned from them; the user pointed out the third, which is the one a commander
actually reads.

| | file | seen by | readable at runtime |
| --- | --- | --- | --- |
| Outline glow on the model | `ui/marine_outline_lookup.dds`, indexed by `EquipmentOutline.lua:20` | everyone, **including the commander** (`CommanderGlowMixin.lua:32`) | **no** — file-local list, colours in a texture |
| Ammo bar under a marine, top-down | `GUIUnitStatus.lua:57-64`, keyed by `kTechId` | **the commander** | **no** — `local kAmmoBarColors` |
| Ammo bar under a marine, spectating | `GUIInsight_PlayerHealthbars.lua:42-56`, keyed by `kMapName` | **spectators** (`GUIInsight_Overhead.lua:224`) | **yes** — public table |

| weapon | outline | commander bar | spectator bar |
| --- | --- | --- | --- |
| Rifle | `#00EFFF` | `#00FFFF` teal | `#0000FF` blue |
| Shotgun | `#00FF00` | `#00FF00` | `#00FF00` |
| Grenade Launcher | `#FF00FF` | `#FF00FF` | `#FF00FF` |
| Flamethrower | `#FFFF00` | `#FFFF00` | `#FFFF00` |
| Heavy Machine Gun | `#FF0000` | `#E60000` | `#FF0000` |
| **Submachinegun (CBM)** | `#D37300` | `#FF6600` | **missing** |

**All three agree exactly on shotgun, grenade launcher and flamethrower.** HMG differs only in the
commander bar being a shade darker. Rifle has three different values, which costs nothing here
because rifles are never recoloured — they keep the player's `playercolor_m`.

**CBM colours the SMG in two of the three.** The commander bar gets `#FF6600` and the outline gets
`#D37300`; only the spectator bar is missing an entry, where it falls through to `kEnergyColor`
yellow — the flamethrower's colour. So the gap is spectator-only, and a commander sees the SMG
correctly as orange.

**This mod uses the commander bar's `#FF6600`**, because the map is read from the same seat and at
the same moment as that bar, and the brighter orange carries further at blip size.

Only the spectator table is reachable from Lua, which is why every value here is written down rather
than read: the two authoritative palettes keep their lists in file-locals and their colours in a
texture.

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
