# Marine map blips colored by weapon

Shipped in 1.03 and confirmed working in game. 1.04 split the one toggle into two: the big map and
the minimaps are switched separately (see [Big map and minimap](#big-map-and-minimap-switched-apart-104)).

Marine player blips on the map take a color per weapon, so the map says where the shotguns are
rather than only where bodies are. Optional and off by default.

NS2 line numbers refer to `D:\SteamLibrary\steamapps\common\Natural Selection 2\ns2\lua`.

## Settled with the user, 2026-09-07

| | |
| --- | --- |
| Which blips | Marine and JetpackMarine only. **Exos keep the plain marine color** — under CBM an exo is modular and can carry any combination, so there is no single weapon to color one by. Vanilla DOES color exos in `GUIInsight_PlayerHealthbars` (minigun red, railgun orange); the CBM reason is the one that decides it |
| Which weapons | Every PRIMARY weapon the commander's palette distinguishes, read at runtime — rifle included, plus anything a mod adds such as CBM's SMG. Pistols, axes and welders never appear: `kPlayerStatus` has no value for them |
| Who sees it | Marines and spectators only |
| Friend tinting | Composes on top: a friend with an HMG is half-saturated red |
| Own blip | Untouched. Not a `MapBlip` at all |
| Setting | In the Mods panel, default **off**. Two since 1.04: big map, and minimap |
| Colorblind | Nothing to do |
| Art | **None.** This branch ships no `.dds` |

## Read at runtime, not hardcoded

The colors come out of the running game. `GUIUnitStatus.lua:57-64` holds `kAmmoBarColors`, keyed by
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
rather than given up on, and results are only memoized once the question is settled — caching early
would pin every weapon to the fallback for the session. If the read genuinely cannot happen (no
debug library, a mod that replaces `GUIUnitStatus` with something shaped differently, a rename), the
written-down table in config takes over, holding copies of the same values.

**It is the PRIMARY weapon, not the one in hand**, and that falls out of the data source rather than
needing any work. `Marine:GetPlayerStatusDesc` reads `GetWeaponInHUDSlot(1)` — the primary slot — so
a shotgunner who switches to a welder or a pistol still reports `Shotgun`. The map says what a
marine can bring, not what is momentarily raised.

**Nothing is excluded by weapon.** An earlier version held rifles back, on the theory that they
should stay the plain team color; the user corrected it, and rightly. A rifle *is* a primary
weapon and takes the commander palette's teal like any other, so a plain rifleman reads as teal
rather than as an absence of information. Pistols, axes and welders never come up at all —
`kPlayerStatus` has no value for them, since they only ever sit in slots 2 and 3.

Exos remain the one exclusion, and that is by blip type rather than by weapon.

## Three palettes, not two

There are **three** per-weapon color tables in NS2, and they are shown to different people. I found
the first two and reasoned from them; the user pointed out the third, which is the one a commander
actually reads.

| | file | seen by | readable at runtime |
| --- | --- | --- | --- |
| Outline glow on the model | `ui/marine_outline_lookup.dds`, indexed by `EquipmentOutline.lua:20` | everyone, **including the commander** (`CommanderGlowMixin.lua:32`) | **no** — file-local list, colors in a texture |
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
and this takes the commander bar's teal, since that is the palette a commander is reading beside it.

**CBM colors the SMG in two of the three.** The commander bar gets `#FF6600` and the outline gets
`#D37300`; only the spectator bar is missing an entry, where it falls through to `kEnergyColor`
yellow — the flamethrower's color. So the gap is spectator-only, and a commander sees the SMG
correctly as orange.

**This mod uses the commander bar's `#FF6600`**, because the map is read from the same seat and at
the same moment as that bar, and the brighter orange carries further at blip size.

Only the spectator table is reachable from Lua, which is why every value here is written down rather
than read: the two authoritative palettes keep their lists in file-locals and their colors in a
texture.

## Why the first build colored nothing

Two facts have to line up, and missing either makes the whole file silently inert. The first build
missed both, and the symptom was simply no color at all.

**Players are not `MapBlip` entities.** `MapBlipMixin.lua:59-64`:

```lua
if self:isa("Player") then
    mapName = PlayerMapBlip.kMapName
```

`PlayerMapBlip` is declared at `MapBlip.lua:461` and does **not** override `GetMapBlipColor`.

**And NS2's class system copies methods into derived classes rather than delegating.** That is
exactly why `Class_ReplaceMethod` exists (`core/lua/Class.lua:18`) — it swaps a method and then
walks `Script.GetDerivedClasses` replacing it in every subclass that still holds the original. So
`PlayerMapBlip` holds its **own copy** of `GetMapBlipColor`, taken when the class was declared at
line 461, and a plain `MapBlip.GetMapBlipColor = wrapper` leaves that copy untouched. Every marine
on the map kept calling vanilla's version.

The fix is one line, and it is the idiomatic one:

```lua
originalGetMapBlipColor = Class_ReplaceMethod("MapBlip", "GetMapBlipColor", ColorMapBlipByWeapon)
```

`ScanMapBlip` picks up the wrapper too and is unaffected by it: a scan's blip type is never Marine
or JetpackMarine, so it falls straight through to the original.

**This is worth remembering beyond this feature.** Everywhere else this mod hooks a plain function
on a table — `GUIScoreboard:UpdateTeam`, `GUIInsight_TopBar:Initialize` — reassignment is correct,
because nothing derives from those. The moment a hook targets a class that has subclasses, plain
assignment is wrong and silently so.

The rest of the chain was right all along: `MinimapMappableMixin:UpdateMinimapItem:130` calls
`GetMapBlipColor` every update rather than caching, and `PlayerInfoEntity.playerId` really is the
entity id `SetOwner` was given.

## Feed the base color, do not return the result

`GetMapBlipColor` (`MapBlip.lua:272`) picks a color by blip type and **then** transforms it:

```lua
if MapBlip.kFriendsHighlightingEnabled and friendTeams[blipTeam] then
    local hue, sat, val = RGBToHSV(color)
    sat = sat * .5
```

Steam friends are not a separate color, they are half the saturation of whatever was chosen. **A
wrapper that returned a weapon color would land after that block and wipe it.** So the mod sets
`MapBlip.kCustomMarineColor` for the duration of the original call and restores it after, inside a
`pcall` so a fault cannot leave every marine stuck on one weapon's color. The friend tint, the
hallucination check and the commander's same-building highlight all keep working untouched.

## Gate on the viewer, not on the blip

An alien **can** see a marine blip. `MapBlip.lua:326`:

```lua
-- Allow enemies to see friends on the other team.  Used to be a bug, now it's a feature. :)
```

Coloring by blip type alone would tell the alien team what their Steam friend is carrying. Vanilla
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

## Colorblind mode needs nothing

NS2 has **no Lua-side colorblind handling anywhere**. It is a render setting —
`Client.SetRenderSetting("colorblind_mode", n)`, `Render.lua:78`, three modes offered in
`menu2/MenuData.lua:3176` — applied to the whole frame downstream of everything. Any color set
here gets the same filter as every other color in the game. An earlier version of this document
listed "must react to the colorblind setting" as a requirement, as though there were something to
read. There is not.

## The local player's own marker

Not a `MapBlip`, and unreachable from this hook. It is a separate player icon with its own setting,
`AdvancedOptions["minimaparrowcolor"]` (`AdvancedOptions.lua:1066`, default `0xFFFF00`), applied
through `minimapScript:SetPlayerIconColor`. No exclusion needed.

## Big map and minimap, switched apart (1.04)

The user asked for the 1.03 toggle to cover the big map only, with a second one for the minimap in
the corner of the marine HUD.

Every map on screen is a `GUIMinimapFrame`, and the `minimap` argument `GetMapBlipColor` receives is
that frame (`MinimapMappableMixin.lua:130`). Its `comMode` says which map it is
(`GUIMinimapFrame.lua:30-32`):

| Mode | Map | Where it is set |
| --- | --- | --- |
| `kModeBig` | The map on the map key, field players and commanders alike | `GUIMinimapFrame.lua:230`, `Player_Client.lua:2707` |
| `kModeZoom` | The marine HUD's corner minimap, a second instance that never leaves this mode | `GUIMarineHUD.lua:372`; see the note at `GUIMinimapFrame.lua:228` |
| `kModeMini` | The commander's and the spectator's corner minimap | `Commander_Client.lua:767` |

So the test is `comMode == kModeBig`, and everything else counts as a minimap. That puts the
commander's and spectator's corner map under the minimap switch, which is what a player would call
it. The mode is read on every call, not cached per frame, because an overhead view flips a single
instance between mini and big.

The big map keeps the 1.03 option key, `BIT_WeaponBlips`, so a player who had it on still does. The
minimap is `BIT_WeaponBlipsMinimap`, default off, which means a 1.03 player who had colors
everywhere now has them on the big map only until they tick the second box.

## No art in this branch

An earlier cut shipped `source/ui/minimap_blip.dds` — vanilla's sheet with the jetpacker cell
swapped for Drey's darker edit. **Removed.** Sprite and color are separate paths
(`BuildClassToGrid` versus `GetMapBlipColor`); this feature changes only the second, so whatever
sheet is loaded is irrelevant to it. Shipping art here imported an attribution question and a "we
now override CBM's whole sheet" problem for no gain to the feature.

For the record, since it was measured: the jetpack cell edit is the same in B2TP and CBM — mean
per-channel difference against vanilla 13.96 and 13.95, against each other 2.36, which is noise.
It is Drey's art and both the user and the CBM developers have his permission. Not a blocker, and
not this branch's business.

## Testing it

### Without bots, and without a round

`it_blipcolors` in the client console dumps what the palette resolved to. This is the test that
matters most, because the runtime read either works or silently falls back to the config copy and
the two look nearly identical in game:

```
[Improved Tooltips] setting: big map off, minimap off
[Improved Tooltips] palette: read from GUIUnitStatus at runtime
[Improved Tooltips]   Rifle              #00FFFF
[Improved Tooltips]   Shotgun            #00FF00
[Improved Tooltips]   GrenadeLauncher    #FF00FF
[Improved Tooltips]   Flamethrower       #FFFF00
[Improved Tooltips]   HeavyMachineGun    #E60000
[Improved Tooltips]   Submachinegun      #FF6600      <- only with CBM loaded
[Improved Tooltips] 6 weapon colors resolved.
```

`palette: CONFIG FALLBACK` means the `debug.getupvalue` read failed. Everything still works, but a
weapon a mod added would be uncolored.

### With bots

`give` cannot equip a bot — it only ever targets `client:GetControllingPlayer()`
(`NS2ConsoleCommands_Server.lua:2032`), so there is no console command that hands a specific gun to
a specific bot. Two ways round it:

```
cheats 1
addbot 3 1          -- three bots on marines (team 1)
allfree             -- everything costs nothing
```

- **Let them buy.** Marine bots have a `BuyWeapons` objective and `HasGoodWeapon` checks their
  primary slot against shotgun, HMG, flamethrower and grenade launcher
  (`bots/MarineBrain_Data.lua:808-816`). With an armory and `allfree` they will equip themselves
  within a minute or so. You get a spread of weapons, not the one you asked for.
- **Drop weapons at them.** `spawn shotgun` puts one on the ground where you are looking
  (`:2033`), and bots have a `PickupDroppedWeapons` action (`:3406-3445`), so they will collect
  them. Still not deterministic about which bot takes which.

`addpassivebot` gives bots that do not act — useful for a stationary target, but they will not pick
anything up either.

**You cannot see your own color.** The local player's marker is the minimap arrow, not a `MapBlip`,
so at least one OTHER marine has to exist for this feature to show anything at all.

### The cases bots cannot cover

- **The friend leak.** Needs a real Steam friend on the opposing team. Bots have no Steam identity,
  so `Client.GetIsSteamFriend` is never true for them and neither the friend desaturation nor the
  cross-team leak can be reproduced with bots at all.
- **Friend desaturation** on your own team: same problem, needs a real friend.

Both need a second human. Worth doing once, since the leak is the only failure mode that is
invisible from the marine side.

## Test checklist

Confirmed in game for 1.03: colors appear on the map with bots carrying dropped weapons. The
friend and CBM cases below are still unverified.

- Both settings off, the default: every map looks exactly like vanilla.
- Setting on, as a marine: rifle teal, shotgun green, GL fuchsia, flamethrower yellow, HMG red. A
  marine holding a pistol, axe or welder keeps their primary weapon's color.
- **1.04: big map on, minimap off.** Colored on the map key; the HUD's corner minimap stays plain.
- **1.04: minimap on, big map off.** The reverse, and the same for a commander's corner map.
- **1.04: a 1.03 player who had it on** still has the big map colored after updating.
- A jetpacker with a shotgun: green, and still the jetpack glyph.
- An exo: plain marine color, both flavors, and under CBM with a mixed loadout.
- A Steam friend on your own team carrying an HMG: red at half saturation, not full red.
- **As an alien, with a Steam friend on the marine team**: that friend's blip must NOT be weapon
  colored. This is the leak the viewer gate exists for.
- As a spectator: both teams look right, marines colored, aliens untouched.
- Your own arrow: unchanged, still `minimaparrowcolor`.
- Weapon swap mid-round: the color follows within the refresh interval.
- Toggling the setting in the panel: applies immediately, no restart.
- With CBM loaded, and with Devnull's ESB loaded, since both are on the server.
