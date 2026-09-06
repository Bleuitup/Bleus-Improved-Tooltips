# Tournament mode ready badge

Shipped in 1.02, from `feature/tournament-ready-badge`.

A tick when a team is ready under Shine's tournament mode, a cross when it is not.

All NS2 line numbers refer to `D:\SteamLibrary\steamapps\common\Natural Selection 2\ns2\lua`. Shine
paths are relative to `lua/shine` inside its Workshop copy, which on this machine is
`D:\SteamLibrary\steamapps\workshop\content\4920\117887554` — the readable source of truth for what
the server actually runs, since nothing under the server folder carries Shine's Lua.

## The ready state is already on the client

Shine's tournament mode broadcasts it — but not as one canonical message, which cost a round of
testing to find out. `ReadyTeam` (`extensions/tournamentmode/server.lua:338-357`) picks its message
based on what the *other* team is doing:

```
if OtherReady then
    self:SendNetworkMessage( nil, "TeamReadyChange", { Team = Team, IsReady = true }, true )
else
    self:SendNetworkMessage( nil, "TeamReadyWaiting", { ReadyTeam = Team, WaitingTeam = OtherTeam }, true )
end
```

So **listening to `TeamReadyChange` alone misses the first team to ready up** — the single most
common event there is. Three messages move a team between ready and not ready:

| Message | Fields | Sent when |
| --- | --- | --- |
| `TeamReadyChange` | `Team`, `IsReady` | A team readies while the other already is; a team unreadies by command; a ready team loses its commander (`server.lua:180,189`) |
| `TeamReadyWaiting` | `ReadyTeam`, `WaitingTeam` | The first team readies. Only sent when the other is *not* ready, so it settles both |
| `TeamPlayerNotReady` | `Team`, `PlayerName` | A player on a ready team backs out. `UnReadyTeam` is then called *without* its notify flag (`server.lua:424`), so no `TeamReadyChange` follows and this is the only word the client gets |

`GameStartAborted` needs no handling: whatever caused the abort already sent one of the three above.

No server work and no cooperation from Shine is needed — only listening to all three.

**Registered names are `SH_tournamentmode_<Name>`.** Shine builds them as
`StringFormat( "SH_%s_%s", self.__Name, Name )` in
`core/shared/base_plugin/networking.lua:87`. Worth writing down because it is not guessable from
the plugin source alone.

**They only exist when the plugin is loaded**, and `Shared.RegisterNetworkMessage` for them runs
inside the plugin's `SetupDataTable`. So the hook has to be defensive about both the messages being
absent and about load order — this mod is a standalone ModLoader mod and has no ordering
relationship with Shine at all.

**Wrapping the plugin's receivers is safe**, and is what the mod does rather than hooking the raw
messages. Shine's dispatcher does `self[ FuncName ]( ... )` — a lookup on the plugin table at call
time, not a captured reference (`networking.lua:97-102`) — so a wrapper installed long after
registration still runs. The client half keeps no state of its own; it only prints notifications
(`client.lua:76,84,113`), so the mod keeps its own table.
the message; `tournamentmode/client.lua` is where to look.

## Where it goes (settled)

The scoreboard team header skill badge: `teamSkillItem`, `GUIScoreboard.lua:171-178`. It is
reachable — the team background builder returns it as `TeamSkill` in the team's `GUIs` table
(`:302`), which vanilla itself reads back at `:778`.

The pip sits towards the badge's lower right at half its height, pulled in off the corner so it
overlaps the badge art and reads as a ribbon laid on it. `kReadyPipScale` is set against the item
rather than the visible plate, which cell 5 and 6 draw inset to 0.72 of the cell, so the scale runs
higher than the fraction of the badge you actually see.

**It inherits the badge's visibility**, being parented to it — and vanilla hides that badge for a
team with no players (`:1142-1156`) and starts it hidden (`:178`). An empty team cannot be ready, so
that is wanted here, but it is worth knowing: anything a future patch does to the skill badge
happens to the pip too.

**Shown only before the round starts.** Readiness stops meaning anything once play begins, so the
pips come off entirely on `GetGameStarted`, and the tracked states are cleared on the way back out
so last round's readiness cannot leak into the next pre-game.

## Art (done)

Drawn as cells 5 and 6 of the mod's own sheet, which grew from 320x64 to 448x64. See
`tools/build_icons.ps1`.

Emoji were ruled out. The code points are free — they are Unicode standards — but every set of
*glyphs* is somebody's artwork under its own licence: Apple's and the Segoe font's are proprietary,
Twemoji is CC-BY, OpenMoji is share-alike. A tick is two strokes, so there is nothing worth an
attribution line for.

**These are the only cells baked in colour.** Every other cell is white so `SetColor` can tint it
per team; green and red here are semantic and never team colours, so there is nothing to tint and a
two-item plate-plus-glyph construction would be wasted at pip size. The cost is that changing the
colours means re-running the build script rather than editing config.

Shape carries the meaning and colour only reinforces it — a tick against a cross survives red-green
colour blindness, a green square against a red one does not.

## Test checklist

**Status: written, never run.** `luac -p` passes, which proves the files parse and nothing more.

- Without Shine, or with tournament mode disabled: no pips, and no errors. This is the case most
  players will be in.
- Tournament mode on, pre-game: both teams show a cross by default.
- One team readies: its cross becomes a tick, the other stays a cross.
- Un-ready: back to a cross.
- Round starts: both pips disappear.
- Round ends into a new pre-game: both are crosses again, not whatever they were last round.
- A team with no players — the badge itself is hidden, so the pip should be too.
- Connecting mid-pregame while a team is already ready: expected to show a cross until the next
  toggle. This is the known gap below, not a bug in the drawing.
- Resolution change, which rebuilds the scoreboard's teams table.

## Known gap: no initial state

All three messages fire only on a **change**. Shine sends nothing carrying the current state, so a
client connecting mid-pregame does not learn that a team is already ready until the next toggle.

The default is "not ready", so the wrong answer is a cross on a team that is ready — which corrects
itself the moment anything changes. Fixing it properly needs a new message from the Shine side, or
an existing one that carries the state; worth asking if it turns out to matter in practice.

## Open question: does this belong in this mod at all

This mod is tooltips and HUD. A tournament-mode readiness indicator is neither, and it depends on a
Shine plugin that most servers do not run. It is small and self-contained, so the cost is low — but
it is worth a moment's thought, given the mucous shield indicator was shelved on exactly this
argument.
