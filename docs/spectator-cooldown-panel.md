# In Cooldown panel for spectators: known gap, not fixed

Written 2026-09-28. **Not fixed in the mod, by the user's decision:** most of this mod is being merged
into the base game by Ghoul and UWE, so this note is for whoever takes it on there. The hive panel had
the same gap and was fixed in 1.08; see "Correction, 2026-09-28" in `docs/hive-research-slots.md`.

NS2 line numbers refer to build 344.

## What a spectator sees today

- **First person on a marine or an alien:** the In Cooldown panel exists but **stays empty**, even
  while that team has abilities on cooldown.
- **Free look, overhead, following in third person:** also empty. That part is by design, since
  the panel only lists cooldowns for a player on team 1 or 2, but it means spectators never see
  cooldowns in any mode.

Players on a team and commanders are unaffected.

## Why

1. **The panel exists for spectators.** It is registered for every `Player`
   (`ImprovedTooltips_ClientUI.lua`, `AddClientUIScriptForClass("Player", ...)`). In first person the
   followed player is the client's local player (`Client.GetLocalPlayer()`; `Client.lua` calls
   `ClientUI.EvaluateUIVisibility` with it). So the panel is built, and `GetActiveCooldowns` sees a
   team 1 or 2 player and goes on to read the cooldown table.
2. **The table is never filled for a spectator.** Cooldowns reach clients only through the mod's
   `ImprovedTooltipsCooldown` message, which the server sends to the caster's team
   (`IT.BroadcastCooldown` -> `IT.SendToTeam(teamNumber, ...)` in
   `ImprovedTooltips_CooldownState.lua`). Spectators are on `kSpectatorIndex` and receive none of it.
3. **Joining the spectator team only clears.** `IT.ResyncPlayerCooldowns` runs on every
   `NS2Gamerules:JoinTeam`, but it asks that team's commander for the current picture, and the
   spectator team has none. So a spectator gets the clear and nothing else.

## Why the hive fix doesn't simply carry over

The hive panel fix was one line: send the hive message to the spectator team as well. Alien hives
only ever come from one team, so nothing could mix.

Cooldowns come from **both** teams, and the client keeps **one** table
(`IT.teamCooldowns`, keyed by tech id only, in `ImprovedTooltips_CooldownState.lua`). The message
carries no team either (`techId`, `startTime`, `clear`). Sent to spectators as it is, marine and
alien cooldowns would land in the same table. The panel would draw them all in the team style of
whoever is being followed. And the `clear` that opens each join resync would wipe the whole table,
so resyncing a spectator with one team and then the other would lose the first.

## How to fix it, if wanted

### In the mod

1. **Put the team in the message.** Add `teamNumber = "integer (0 to 4)"` to `kCooldownMessage`
   in `ImprovedTooltips_NetworkMessages.lua`, and a parameter to
   `BuildImprovedTooltipsCooldownMessage`.
2. **Key the client table by team.** `IT.teamCooldowns[teamNumber][techId] = startTime`, with
   `IT.SetTeamCooldown`, `IT.GetTeamCooldownFraction` and `IT.ClearTeamCooldowns` all taking the team.
   A clear for one team empties only that team.
3. **Send to spectators as well.** In `IT.BroadcastCooldown`, also send to `kSpectatorIndex`, the
   same way `IT.BroadcastHiveState` does now.
4. **Resync spectators with both teams.** When a player joins the spectator team, run the existing
   resync once for team 1 and once for team 2 instead of for their own team.
5. **The panel reads the viewed team.** `GetActiveCooldowns` already takes the team from
   `player:GetTeamNumber()`. In first person that is the followed player's team, so passing it
   through to `IT.GetTeamCooldownFraction` picks the right half, and the existing rebuild-on-team-
   change gives the right team styling. Free look and overhead can stay empty, or show a team if a
   spectator mod (Better Spectator's team perspective, for example) exposes one.
6. **The vanilla button dial.** `IT.ApplyCooldownToVanillaDial` then reads the commander's own team's
   entries, which is what it does today in effect.

Cost is a handful of bytes per cast, sent to a few more clients.

### In the base game

It gets simpler, because the base game can reach what the mod cannot:

- **`gTechIdCooldowns` in `Commander.lua` is already keyed by team**, and a client VM has its own copy
  of it. What is missing is filling it: today only the casting commander is messaged
  (`AbilityResult`, `Commander_Server.lua`), and `Commander:SetTechCooldown` still carries an empty
  `if Server then -- send message to commander to sync the cd end` block for exactly that job.
- So a base game version would **send the cooldown to the team and to spectators with its team
  number, and write it into that client's `gTechIdCooldowns[team]`**. The panel (and the command
  button dial) read it through a team-taking accessor instead of `Commander:GetCooldownFraction`,
  which only exists on a Commander.
- **Resync from the table itself.** The server's `gTechIdCooldowns` holds each team's current
  cooldowns, so a joiner (player or spectator) can be sent them directly. The mod has to reconstruct
  them through a seated commander's `GetCooldownFraction`, which is why someone joining a team with
  an empty chair gets nothing. The 2026-09-17 code review lists that as a mod defect.

## How to check a fix

Spectate a game. Cast Shade Ink and Nano Shield in quick succession (cheats, or two commanders).

- Follow an alien in first person: Shade Ink listed, in the alien style. Switch to a marine: Nano
  Shield, marine style. Switch back: Shade Ink still there with the right time left.
- Start spectating after both were cast: both show when you follow each team.
- After a round reset, nothing stale from the previous round is listed.
- Players on each team still see only their own team's cooldowns.
