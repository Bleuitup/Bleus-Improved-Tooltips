# Nutrient mist indicators

Built as 1.13 on `feature/nutrient-mist-indicators` (2026-10-30), never published on its own; it went
out in 1.2 (2026-11-14). Tested in game by the user from Launch Pad on 2026-10-30 (build 344, as a lifeform
and as commander) and again on 2026-11-14 (build 345.4583 beta). The rules below were re-checked
against build 345 on 2026-11-14; line numbers are from build 344 unless marked.

NS2 line numbers refer to `D:\SteamLibrary\steamapps\common\Natural Selection 2\ns2\lua`.

## Settled with the user, 2026-10-30

| | |
| --- | --- |
| Why | Under alien vision, or after the cloud fades, it is hard to tell what is misted; a commander taking the chair cannot tell which player is misted in an egg |
| Commander | A badge above every alien entity the mist is helping. Option C from a mosaic of six: the tech-tree mist icon tinted green with the HUD status row's own green up arrow, **48 px**. Always shown, no hover needed |
| Player in an egg | An entry in the alien HUD's status row, styled like Umbra and Energize (option F): green tile, up arrow, the mist icon in the alien icon color |
| Grown things | No badge. The user: not for fully mature entities unless the effect plays for them; the code says it does not (below) |
| Setting | None; always on (`IT.kShowNutrientMistIndicators` in the config) |

Precedent for the green up arrow on aliens: the alien status row draws six buffs with it, from
`kArrowUpCoords` on the green tile: Enzyme, Mucous, Cloaked, Umbra, Energize, Crag range
(`Hud/GUIPlayerStatus.lua:473-484`).

## What mist does, from the code

Mist is a `NutrientMist` entity that, every 1.5 s for its 15 s life (`kNutrientMistDuration`,
`Balance.lua:777`), calls `TriggerCatalyst(2, ...)` on the alien team's `Catalyst` entities within
10 m (`CommAbilities/Alien/NutrientMist.lua`). That sets the networked `isCatalysted` flag for 2 s,
so the flag ends at most 2 s after the cloud does. Every client already has the flag: nothing new is
sent.

`CatalystMixin:GetCanCatalyst` (`CatalystMixin.lua:80-90`) only flags an entity that is still growing,
an embryo, a damaged cyst (`Cyst:GetCanCatalyzeHeal` is true), a structure that needs infestation and
is off it, or `maturityStarvation` (set by nothing in vanilla). What the flag then does:

| Flagged because | Effect in game | Badge |
| --- | --- | --- |
| Embryo | Evolves faster (`GetAlienCatalystTimeAmount`, `Embryo.lua:136`) | Yes |
| Still growing | Matures faster (`MaturityMixin:GetMaturityMistBonus`) | Yes |
| Disconnected cyst, grown or not | No starvation damage (`Cyst_Server.lua:347`) | Yes |
| Damaged, connected, grown cyst | None: the heal constants in `CatalystMixin` are never used | No |
| Off infestation, grown (e.g. a harvester) | None: `AlienTeam`'s off-infestation damage (`AlienTeam.lua:765-783`, 2% of max health a second, at least 20) never checks the flag. CBM's copy is the same | No |

So `IT.GetIsMistHelping(entity)` (`ImprovedTooltips_Common.lua`) is: flagged, and an embryo, or still
growing, or a disconnected cyst. Spawn eggs are never helped (no maturity; only flagged off
infestation). A full-health disconnected cyst is only flagged once it has taken a tick of starvation
damage, so its badge can lag the mist by up to one pulse.

The game's own tooltip agrees: "Speeds structure maturation, speeds player evolution, and prevents
damage to disconnected cysts".

## Commander badge: `ImprovedTooltips_MistBadge.lua`

Second post-hook on `lua/GUIUnitStatus.lua`, after the welder icon; wraps `UpdateUnitStatusBlip`. For
the local `AlienCommander` only, it looks up each plate's entity (`blipData.UnitId`) and shows a badge
when `IT.GetIsMistHelping` holds: a child of the plate's `statusBg`, anchored Middle/Top, centered
`kMistBadgeGap` above it. It does not wait for the plate's name, which a commander only sees on
hover. Runs under `pcall`, prints once and stops on error.

## Status row: `ImprovedTooltips_MistStatus.lua`

Post-hook on `lua/Hud/GUIPlayerStatus.lua`. Its entries are a file-local `statusSettings` table built by
a file-local `CreateStatusIndicator`; both are read from `GUIPlayerStatus.Initialize`'s upvalues with
`debug.getupvalue`, the technique Shine and NSL use for file-locals. (CBM, while it
existed, shipped its own `Hud/GUIPlayerStatus.lua` with the same names and shape.)

- A `NutrientMist` entry goes into `statusSettings` before any `Initialize`, so `GetFreeStatus` finds
  it and it gets a `lastStatusState`.
- `Initialize`, alien team only, appends one indicator from the game's own `CreateStatusIndicator`,
  then points its effect arrow back at `ui/player_status_icons.dds` (it is created from the entry's
  own texture, the build menu).
- `Update` sets `parameters.NutrientMist` on the table the alien HUD builds each frame
  (`GUIAlienHUD.lua:930`) before the original runs; `SimpleStatusLogic` handles visibility, the pop-in
  and ordering. Like Umbra it shows only with the full HUD (`fullMode`).

## Test checklist

1. Alien commander, mist over growing structures and an embryo: a badge above each, gone within
   about 2 s of the cloud fading.
2. Mist over grown structures, a grown harvester off infestation, spawn eggs: no badge.
3. A disconnected cyst under mist: badged (possibly after one pulse).
4. As a player evolving in an egg, get misted: the mist icon appears in the status row, bottom left.
5. Marine commander and field aliens: no badges.
6. Badge size and position against the mockup, at more than one zoom level.
