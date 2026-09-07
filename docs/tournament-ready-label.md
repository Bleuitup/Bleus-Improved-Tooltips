# Tournament mode ready label

The badge pip shipped in 1.02, from `feature/tournament-ready-badge`. This file now describes the
header label that replaces it, on `feature/tournament-ready-header`, for 1.02b. The Shine plumbing
below is unchanged and was tested in game; only the drawing half is new.

A tick and a green `[Ready]` at the front of a team's scoreboard header when that team has readied
up under Shine's tournament mode, a cross and a red `[Not Ready]` when it has not.

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

## Where it goes (revised for 1.02b)

**1.02 put a pip in the corner of the skill badge.** It worked, but it was small and easy to miss,
and it took two rounds of resizing to be legible at all. 1.02b moves the same state to the front of
the header row, where it reads at a glance:

```
[tick]  [Ready]      Frontiersmen (6 Players)  [skill badge]
[cross] [Not Ready]  The Kharaa   (6 Players)  [skill badge]
```

Label green for ready, red for not; glyph squared off to the height of the text beside it.

**The colour split forces a separate text item.** A GUI text item has one colour, so `[Ready]` in
green and the team name in the team's own colour cannot be one string. The label is our item,
measured and positioned by us; vanilla's `teamNameItem` (`:158-168`) is only moved.

**The skill badge position is derived from the name width AND cached.** `:1153` sets it to
`GetTextWidth(teamHeaderText) + 20`, inside a guard that only fires when the team's summed skill
changes (`:1142`) — so it moves when someone joins or leaves, and not otherwise. Shift the name and
the badge stays put, on top of it. This file therefore drives the badge x itself on every update,
in both states, reproducing vanilla's formula when there is no prefix.

**Room is the real constraint, and it is measured rather than assumed.** The player column headers
begin at `kPlayerItemWidth` (275) below 1280 wide, and at
`GetTeamItemWidth() - kTeamColumnSpacingX * 10` (400) above it (`:194`). Working back from there,
with the badge 62 wide (`kPlayerSkillIconSize`, `:79`) plus its 20 gap, the name has roughly 308
unscaled pixels on a wide screen and 183 on a narrow one. `Frontiersmen (1 Player)` plus a glyph
and `[Not Ready]` exceeds that.

Tournament mode makes it likelier, not less: admins set custom team names through the plugin, up to
25 characters (`string (25)`, `shared.lua:17-18`), pushed to clients as a `teams` console command
(`client.lua:28`).

So the row is measured every update. If glyph, label, name and badge all fit before the column
headers, the full prefix is drawn; if not, the label is dropped and the glyph alone is kept — still
at the front of the row, just quieter. Nothing is ever drawn over the columns.

`GetColumnStartX` reproduces vanilla's expression rather than reading it, because it is a local
there. **If that ever drifts, the symptom is a prefix overlapping the Score column instead of
shortening itself.**

**Shown only before the round starts.** Readiness stops meaning anything once play begins, so the
prefix comes off entirely on `GetGameStarted`, the name and badge return to vanilla's positions,
and the tracked states are cleared on the way back out so last round's readiness cannot leak into
the next pre-game. The plugin does the same on its side (`server.lua:213`) and resends nothing.

## Art (unchanged from 1.02)

Cells 5 and 6 of the mod's own sheet, 448x64. See `tools/build_icons.ps1`. The move from badge pip
to header prefix needed **no art change at all** — the cells were already a coloured rounded square
with a white tick or cross, which is exactly what the header wants.

Emoji were ruled out. The code points are free — they are Unicode standards — but every set of
*glyphs* is somebody's artwork under its own licence: Apple's and the Segoe font's are proprietary,
Twemoji is CC-BY, OpenMoji is share-alike. A tick is two strokes, so there is nothing worth an
attribution line for.

**These are the only cells baked in colour.** Every other cell is white so `SetColor` can tint it
per team; green and red here are semantic and never team colours, so there is nothing to tint and a
two-item plate-plus-glyph construction would buy nothing. The cost is that changing the
colours means re-running the build script rather than editing config.

Shape carries the meaning and colour only reinforces it — a tick against a cross survives red-green
colour blindness, a green square against a red one does not.

## Test checklist

**Status: written, never run.** `luac -p` passes, which proves the files parse and nothing more.
The 1.02 pip it replaces was tested in game and worked; none of that carries over to the drawing
half, only to the Shine plumbing above it.

- Without Shine, or with tournament mode disabled: nothing drawn, no errors, and the team name and
  skill badge sit exactly where vanilla puts them. This is the case most players will be in, and it
  is the one to check first because this version moves vanilla's own items.
- Tournament mode on, pre-game: both teams show the cross and a red `[Not Ready]`.
- One team readies: tick and a green `[Ready]`; the other stays as it was.
- Un-ready: back to the cross.
- Round starts: the prefix goes, the name returns to x=10 and the badge lands right beside it —
  no gap left where the label used to be.
- Round ends into a new pre-game: both not ready again, not whatever they were last round.
- A team with no players: no prefix. Vanilla hides the skill badge in that case and this follows it.
- **A long team name.** Set one with the plugin's `teams` command, 25 characters, and confirm the
  label drops to glyph-only rather than running into the Score column.
- **A narrow screen**, under 1280 wide, where the budget is 275 rather than 400. Likeliest place to
  see the glyph-only fallback.
- Someone joining or leaving mid-pregame, which is when vanilla would otherwise reposition the
  badge from its own formula.
- Resolution change, which rebuilds the scoreboard's teams table and so the prefix items with it.
- Connecting mid-pregame while a team is already ready: expected to show not-ready until the next
  toggle. This is the known gap below, not a bug in the drawing.

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
