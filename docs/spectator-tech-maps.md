# Spectator tech maps

**Published in 1.12 (2026-10-30).** Built on `feature/spectator-tech-maps`. Before publishing, the
logic passed a stub-game harness (41 checks: server 18, client 20, key hint 3) and
`tools/check_mod.lua`, which prove nothing about layout, networking or the NS2 API.

This is section 1 of `docs/spectator-plan.md` on `feature/spectator` (tech tree while spectating),
built in a smaller form than that plan settled on 2026-08-31: one team at a time rather than both
side by side. NS2 line numbers refer to `D:\SteamLibrary\steamapps\common\Natural Selection 2\ns2\lua`.

## Settled with the user, 2026-10-30

| | |
| --- | --- |
| Seen in | NSL Mod (170777320) on a comp server, `lua/NSL/spectator_techtree/` and `lua/NSL/GUI/GUINSLSpectatorTechMap.lua`. Not vanilla, and not CompMod, which has no such code |
| Controls | NSL's: hold the tech map key, press 1 or 2 for marines or aliens. The key is the player's own `ShowTechMap` binding (J by default), in the controls and in the hint |
| One team at a time | The side-by-side layout from the spectator plan stays a possible later step: it needs a second client-side tech tree store and a forked GUITechMap |
| Who | Neutral spectators only. No settings panel option |
| Credit | NSL Mod (Dragon, MIT): same controls and approach, the mod's own code. In the README credits and the Workshop description |
| NSL loaded | This feature stands down, client and server, so there are never two maps or two trees |

## Why spectators have no tech map in vanilla

- `GUITechMap` is shown for teams 1 and 2 only (`ClientUI.lua:81-86`; the spectator team gets
  `GUISpectator`, `:59-66`).
- `PlayingTeam:UpdateTechTree` (`PlayingTeam.lua:871`) sends the tree to the team's own players only:
  `SendTechTreeBase` to those who just joined, `SendTechTreeUpdates(players)` once a second
  (`kTechTreeUpdateTime = 1`, `:22`).
- The client holds a single tree (`Client.lua`'s `gTechTree`), read through `GetTechTree()`.

A dead player watching their own team is a `TeamSpectator` on team 1 or 2 and keeps that team's map
and tree as vanilla gives them.

## Server: `ImprovedTooltips_SpectatorTechTree.lua`

Post-hook on `lua/TechTree_Server.lua`, which `TechTree.lua:14` loads in the server VM only.

- **Request.** New message `ImprovedTooltipsSpectatorTechTree { teamNumber = 0..2 }`, registered in
  `ImprovedTooltips_NetworkMessages.lua` (every VM) and handed to `IT.OnSpectatorTechTreeRequest`.
  Only a neutral spectator (`isa("Spectator")` on `kSpectatorIndex`) is listened to; a
  TeamSpectator asking for the other team would be ghosting. 1 or 2 subscribes; 0 unsubscribes and
  sends vanilla's `ClearTechTree`.
- **Subscriptions** are keyed by client id (the player entity changes on every class change) and
  remember which tree object their last baseline came from.
- **`TechTree:SendTechTreeUpdates(playerList)` is wrapped.** It finds which team the tree belongs to
  (`GetGamerules():GetTeam(n).techTree`), sends the full baseline with the game's own
  `SendTechTreeBase` (which starts with `ClearTechTree`) to anyone whose last baseline was a
  different tree - new, switched, or the round rebuilt the trees - then calls the original with a
  copy of the list plus those spectators. Nobody waits more than a second. A tree that is not yet
  complete sends no baseline, and the spectator gets no updates until it does.
- A subscription is dropped when its client is gone or its player is no longer a neutral spectator.
  Nothing is sent on joining a team: vanilla sends that team's baseline, which clears first.
- **Different from NSL:** NSL changes what `Team:GetPlayers` returns while the tree updates, which
  every caller in that window sees, and clears the client's tree when its GUI script is destroyed,
  which can race the new team's baseline on joining a team. Neither is done here.
- Runs under `pcall`; after an error it prints once, drops all subscriptions and stops, so the
  teams' own players always get their tree.

## Client: `GUIImprovedTooltipsSpectatorTechMap.lua`

A subclass of `GUITechMap` (CBM's own, under CBM), registered with
`AddClientUIScriptForTeam(kSpectatorIndex, ...)` in `ImprovedTooltips_ClientUI.lua`.

- `GUITechMap` takes its layout from `PlayerUI_GetTeamType()` in `Initialize` (`GUITechMap.lua:170`)
  and rebuilds whenever it changes in `Update` (`:247-253`). For those two calls only, the global
  answers the chosen team's type, and is restored even if the call fails. NSL swaps it the same way.
- Asks for the marine tree as soon as it starts, so the map is ready the first time the key is held,
  and remembers the chosen team across a rebuild (resolution change).
- `SendKeyEvent`: the tech map key sets `techMapButton` as vanilla does and is not consumed. While
  it is held, 1 and 2 (fixed `InputKey.Num1`/`Num2`, as on NSL servers) switch team and are
  consumed (returning true stops `GUIManager:SendKeyEvent`, `GUIManager.lua:272-288`), because on
  their own they switch the spectator camera mode (`Weapon1`/`Weapon2`).

## Key hint: `ImprovedTooltips_SpectatorTechMapHint.lua`

Post-hook on `lua/GUIInsight_Overhead.lua`: after `Initialize` builds the key hints
(`GUIInsight_Overhead.lua:55-80`), appends `[<tech map key>+(1/2)] Toggle TechMaps`, NSL's wording,
and re-wraps and repositions the line the way vanilla does.

## Test checklist

Needs a server (a local listen server is enough) and two players or bots on the teams.

1. As a neutral spectator, overhead: hold J. The marine tech map shows, with live research.
2. Hold J, press 2: the alien map. Press 1: marines again. The camera mode does not change.
3. Without J held, 1 and 2 still switch the camera mode as before.
4. The key hint at the bottom ends with `[J+(1/2)] Toggle TechMaps`. Rebind the tech map key: the
   hint and the controls follow (the hint after the overhead view is rebuilt).
5. Research something on each team: the map shows it in progress within a second.
6. New round (or `reset`): the map refills for the new round.
7. Join a team from spectate: that team's own tech map and buy menu are right (the old spectator
   tree must not linger).
8. Die and watch your own team as a dead player: your own team's map only; 1 and 2 do nothing to it.
9. With NSL Mod loaded: only NSL's map and hint, no doubled hint text.
10. With CBM: the CBM tech map layout.
