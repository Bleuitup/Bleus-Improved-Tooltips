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
[cross] [Not Ready]  Kharaa       (6 Players)  [skill badge]
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

**The name is never custom, which I got wrong at first.** The header always uses vanilla's
`NAME_TEAM_n` locale string (`:780`) — "Frontiersmen" and "Kharaa". Tournament mode's
`sh_setteamnames` does not touch it: those names go to the **Insight spectator bar** through
`Insight.lua`'s `teams` console command (`client.lua:28`, `Insight.lua:143-160`), which is a
different surface entirely. So the 25-character limit in the plugin's data table is irrelevant here.

What does vary is the player-count suffix and the locale. `Frontiersmen (12 Players)` is
meaningfully wider than `Kharaa (1 Player)`, and a wordier language would be wider still — enough
that the fallback is a live case on a full team, not a theoretical one.

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

## Scoreboard mods replace this file wholesale

**Devnull's Enhanced Scoreboard** (Workshop `2597529958`, v2.8, `lua/Devnull_ESB/`) hooks
`lua/GUIScoreboard.lua` with `"replace"`, not `"post"` — so vanilla's copy never loads and ours
post-hooks *theirs*. Its entry `Priority` is 99 against our 5, and ModLoader sorts descending, so
our hooks register last and wrap whatever it left. That part works by design.

What did not work was assuming vanilla's arrangement. The first version hardcoded name-at-10,
badge-after-name and wrote both positions from those constants. ESB flows the header the other way:

| | vanilla | Devnull ESB |
| --- | --- | --- |
| skill badge | after the name, at `GetTextWidth(header) + 20` (`:1153`) | pinned at x=10 (`:360`) |
| team name | x=10 (`:165`) | x = 10 + badge width, for playing teams (`:350-352`) |
| repositions the badge later? | yes, but only when summed skill changes (`:1142`) | never |
| team name font | `kTeamNameFontName`, which is the font it actually uses | `SetFont` with Arial 13; `kTeamNameFontName` is left as `Fonts.kInsight` and unused |

So on a server running ESB our code **moved somebody else's badge from the front of the row to the
back of it**, and set our label in `Fonts.kInsight` while the name beside it was Arial 13.

Both fixes generalise rather than special-casing ESB:

- **Read the host's positions back and only shift them.** `TrackBase` keeps, per item, the last x
  we wrote; anything different from that on the next update is the host's own write and becomes the
  new base. The prefix goes at `min(nameBase, badgeBase)` and both items move right by its width,
  so whichever order the host chose survives. Zero shift puts everything back exactly.
- **Copy the font off the team name item.** `SetFont` resolves to `SetFontName` plus a fitted scale
  (`GUIItemExtras.lua:413-431`), so `GetFontName()` and `GetScale()` describe whatever the host
  settled on however it was set. Gaps became fractions of the measured text height for the same
  reason.

Nothing here reads a constant that a scoreboard mod could redefine, except `GetColumnStartX`, which
ESB reproduces identically (`:370`).

**Other scoreboard replacements on this machine**, all worth a look if a report comes in:
CompMod (`1876217244`), Shimizu Scoreboard (`3776560923`), Shimizu Better Spectator
(`3789671641`), ExperienceManager (`3774306230`), NoMoreSkillTierIcons.

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
- Round starts: the prefix goes and the name and badge return to exactly where the host had them —
  no gap left where the label used to be, and no change of order.
- Round ends into a new pre-game: both not ready again, not whatever they were last round.
- A team with no players: no prefix. Vanilla hides the skill badge in that case and this follows it.
- **A full team.** `Frontiersmen (12 Players)` is the widest the header gets in English; confirm the
  label drops to glyph-only rather than running into the Score column.
- **Devnull's Enhanced Scoreboard loaded**: the badge must stay at the FRONT of the row where
  that mod puts it, with the prefix before it, and the label must be in the same typeface as the
  team name. This is the case that caught the first version out.
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
