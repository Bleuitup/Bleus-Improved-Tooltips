# Tournament mode ready badge — plan

Branch `feature/tournament-ready-badge`, cut from `release/1.01`. Nothing implemented yet.

A tick when a team is ready under Shine's tournament mode, a cross when it is not.

All NS2 line numbers refer to `D:\SteamLibrary\steamapps\common\Natural Selection 2\ns2\lua`; Shine
paths are relative to the local `Shine` clone in the workspace.

## The ready state is already on the client

Shine's tournament mode broadcasts it. From
`Shine/lua/shine/extensions/tournamentmode/shared.lua:26-29`:

```
self:AddNetworkMessage( "TeamReadyChange", {
    Team = TeamField,
    IsReady = "boolean"
}, "Client" )
```

So no server work and no cooperation from Shine is needed — only listening.

**The registered name is `SH_tournamentmode_TeamReadyChange`.** Shine builds it as
`StringFormat( "SH_%s_%s", self.__Name, Name )` in
`core/shared/base_plugin/networking.lua:87`. Worth writing down because it is not guessable from
the plugin source alone.

**It only exists when the plugin is loaded**, and `Shared.RegisterNetworkMessage` for it runs inside
the plugin's `SetupDataTable`. So the hook has to be defensive about both the message being absent
and about load order — this mod is a standalone ModLoader mod and has no ordering relationship with
Shine at all. Check whether reading the client-side plugin's own state is more robust than hooking
the message; `tournamentmode/client.lua` is where to look.

## Where it goes — NEEDS CONFIRMING

The likely target is the scoreboard's team header skill badge: `teamSkillItem`,
`GUIScoreboard.lua:171-178`, drawn from `kPlayerSkillIconTexture` at texture coords
`(0, 0, 100, 31)`, sized `kPlayerSkillIconSize`, positioned `Vector(10, 5, 0)` scaled by
`GUIScoreboard.kScalingFactor`.

Confirm with the user before building:

- Is that the badge meant, or the per-player badges, or something on the HUD rather than the
  scoreboard?
- Overlay on the badge, or beside it? An overlay is more compact but risks obscuring the skill icon
  it sits on.
- Only in the pre-game, or whenever tournament mode is active?

Also check whether `teamSkillItem` is reachable — it is a local at creation and needs to be stored
on `self` or in a returned table for a post-hook to decorate it, the same problem
`GUIBioMassDisplay.abilityIcons` did not have.

## Art

No vanilla tick or cross has been located yet. Two routes:

- Find one in an existing atlas. The places worth checking first are the same ones the icon notes in
  `CLAUDE.md` list — `marine_buildmenu_insight.dds` carries arrows and symbols and is the most
  likely home for a tick.
- Draw them, the way the hourglass and stopwatch were drawn, with `tools/build_icons.ps1`. A tick
  and a cross are simple shapes and would sit in the mod's own sheet with no new dependency.

Prefer vanilla if something suitable exists, per the standing rule in `CLAUDE.md`.

## Open question: does this belong in this mod at all

This mod is tooltips and HUD. A tournament-mode readiness indicator is neither, and it depends on a
Shine plugin that most servers do not run. It is small and self-contained, so the cost is low — but
it is worth a moment's thought, given the mucous shield indicator was shelved on exactly this
argument.
