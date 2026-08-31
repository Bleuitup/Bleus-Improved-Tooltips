# Spectator work — plan

Branch `feature/spectator`. Tracking issue: #6. Nothing here is implemented yet; this file is the
spec so the research does not have to be redone.

All line numbers refer to `D:\SteamLibrary\steamapps\common\Natural Selection 2\ns2\lua`.

## 1. Tech tree while spectating

**Not a vanilla feature.** The overhead spectator legend (`GUIInsight_Overhead.lua:60-85`) lists
thirteen entries — free camera, overview, first person, switch mode, stats, toggle health, toggle
outlines, zoom, reset zoom, draw, clear, toggle help, toggle HUD — and none of them is a tech tree.
The legend text is hardcoded English, not localised; an added entry should match that style.

The binding already exists for players: `ShowTechMap`, default **J** (`BindingsDialog.lua:57`,
`:110`), plus a button on the minimap strip (`GUIMinimapButtons.lua:80-84`). While spectating it is
inert rather than blocked, because `ClientUI.GetScript("GUITechMap")` returns nil — so wiring it up
is the natural entry point rather than inventing a key.

### Why it needs new networking

Three independent blockers:

1. `GUITechMap` is in `kBothAlienAndMarine` and copied only into `kShowOnTeam[kTeam1Index]` and
   `[kTeam2Index]` (`ClientUI.lua:81-86`). `kShowOnTeam[kSpectatorIndex]` holds only `GUISpectator`
   (`:59-66`).
2. `PlayingTeam:UpdateTechTree` (`PlayingTeam.lua:870-896`) sends `SendTechTreeBase` and
   `SendTechTreeUpdates` to `self:GetPlayers()` — its own team. `SpectatingTeam.lua` has no tech
   tree code at all.
3. The client holds exactly one tree: `Client.lua:167` declares a single `local gTechTree`, and the
   client's `GetTechTree()` takes **no team argument**, unlike the server's `GetTechTree(teamNumber)`
   (`Server.lua:408`). `GUITechMap` reads that global directly (`:293`) and picks its layout from
   `PlayerUI_GetTeamType()` (`:170`, `:247`).

A dead player spectating their own team is a `TeamSpectator`, still on team 1 or 2, and keeps their
own side's tech map. Only the true spectator (team 3) and the both-teams case fail.

### Intended behaviour (settled 2026-08-31)

| Situation | Show |
|---|---|
| Neutral spectator, both teams' information visible | **Both trees, side by side** |
| Restricted to one team | That team's tree only |
| First person on a specific player | That player's team's tree |

The test is the spectator's own team number: `kSpectatorIndex` means unrestricted and gets both
trees; anything else is a `TeamSpectator` and gets one. `TeamSpectator:GetIsValidTarget`
(`TeamSpectator.lua:43`) already refuses targets on the other team, so the restriction is a property
of how you are spectating, not a setting.

**There is no legend entry that hides one team's information.** The overhead legend has the thirteen
entries listed above and no more — `Weapon4` toggles the whole Insight HUD, not one team's half. What
separates the two cases is joining as a neutral spectator versus spectating from a team slot (which
is also what happens when you die). If a manual per-team toggle is wanted, it would be new work.

Side by side means two `GUITechMap` instances at reduced scale. Check legibility of the icons early —
if half-width turns out to be too small, the fallback is one instance with the `ShowTechMap` key
cycling marine / alien / off.

### Shape of the work

- New messages carrying both teams' node states to spectators. The mod already owns two network
  messages, so the plumbing is familiar.
- A parallel client-side store, since `gTechTree` cannot hold two trees.
- Either two `GUITechMap` instances, or a fork taking tree + team type as arguments instead of
  reading globals. That is a rewrite of its data path, not a hook.
- Roughly one message per node at spectator join (100+ nodes), then deltas.

Precedent: Insight already ships spectator-only messages — Health, TechPoints, Recycle, Consume,
Reset (`InsightNetworkMessages.lua`). None carries a tech tree, but that is the established route.

## 2. Gorge death alert

Vanilla never wrote it. The comment at `GUIInsight_PlayerFrames.lua:426` reads
`-- Alerts for Lerk, Fade, Onos, Exo deaths` and the if/elseif chain covers exactly those. Nothing
is gated or commented out. Skulk is absent for the same reason.

Adding gorge is a copy of an existing branch: match `STATUS_GORGE` and `GORGE_EGG`, use
`ui/Gorge.dds` (it ships), and the shared text format needs no change —
`string.format("%s %s Has Died", oldStatus, playerName)`.

**Gorge only — skulk is deliberately not added** (settled 2026-08-31). `ui/Skulk.dds` ships too and
it would be the same one-branch change, but skulks die constantly and the alerts would bury the
lerk / fade / onos / exo ones the queue exists to surface.

## 3. Jetpack death alert

`kPlayerStatus` (`Globals.lua:182`) has **no Jetpack value**, so the status-driven path above cannot
see it. But NS2 models the jetpack as a separate player class, `JetpackMarine`, and blip types come
from the class name — `kMinimapBlipType[self:GetClassName()]` (`MapBlipMixin.lua:228`).

It already reaches spectators: `MapBlip:UpdateRelevancy` (`MapBlip.lua:82-96`) sets an infinite
relevancy distance and excludes only by team 1 / team 2.

Implementation, no new networking:

- Cache "is this client currently a JetpackMarine" per player each update, from the blip type or
  `Shared.GetEntity(...):isa("JetpackMarine")` where the entity is relevant.
- Read the cache on the transition to Dead — the marine entity is gone by then, so it must be
  last-known rather than live.
- Empty cache means no jetpack alert, rather than a guess.

**Exo containing a jetpacker is already correct for free:** their status is `Exo`, so the exo branch
fires first and the jetpack is never consulted.

Still to find: the jetpack icon's coordinates in `ui/marine_buy_bigIcons.dds`, the sheet the exo
alert already uses.

## 4. Supply on the spectator top bar

No new networking: `TeamInfo.supplyUsed` is a networkVar with `TeamInfo:GetSupplyUsed()`
(`TeamInfo.lua:42`, `:348`), and a global event `OnTeam%dSupplyUsedChanged` (`:236`) exists to drive
updates. The top bar already reads the alien `TeamInfo` for biomass.

The icon is already solved inside this mod: `GetTopBarSupplyIcon(teamType)` in
`ImprovedTooltips_TooltipGUI.lua:212` reads `GUIHudSupply.kThemeData` with a fallback to
`ui/hud2/team_info_atlas.dds`. Reusing it keeps supply identical everywhere the mod draws it.

**Placement, settled:** from the centre outwards, resources then supply then biomass. Marine supply
on the marine side, alien supply on the alien side. Nothing else on the top bar moves.

Layout notes for `GUIInsight_TopBar.lua`: items come from `CreateIconTextItem` (`:58`), and the
anchor differs per team — `kTeam1Index` anchors `GUIItem.Left`, everything else anchors
`GUIItem.Right` (`:59-63`), so the sign of the x offset is mirrored between sides. Existing values:
`marineResources` `+130` (`:219`), `alienResources` `-195` (`:222`), `alienBiomass` `-5` (`:224`).
Exact offsets have to be tuned in game — the two sides are not symmetric today.
