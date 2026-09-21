# Mod code findings for Claude — 2026-09-17

## Purpose, scope, and baseline

Martin requested this handoff so the code findings remain available in a later Claude session. This records findings and proposed work; it does not authorize implementing the refactor or publishing anything.

Reviewed branch: `refactor/cleanup`.
Reviewed commit: `16f078808555d84f7d9f13cfe2db9ef2bc089361`.
Status of these findings: **open at the reviewed commit**. Recheck the current code before acting.

The review focused on Bleu's Improved Tooltips and the vanilla/CBM paths it touches. It was **not an audit of the entire NS2 Lua codebase**. One additional upstream report was supported: research notification overflow loses active entries and can suppress completion sounds. Those symptoms were already in Claude's notes; the audit added upstream comparison and source-level reproduction. That is not evidence that the rest of vanilla has no bugs.

Claude's existing six cleanup phases are already implemented. Preserve them and finish their outstanding in-game checks; do not repeat the refactor from scratch.

Companion documents:
- [Full refactor and optimization plan](refactor-and-optimization-plan.md)
- [Evidence, checked revisions, and reproduction instructions](review-evidence.md)
- [Source-level probes](audit-probes.lua)
- [Separate upstream notification report](upstream-notification-overflow-draft.md)
- [Existing cleanup plan](../refactor-plan.md)

All Lua filenames below refer to `source/lua/ImprovedTooltips/` unless another path is given. Line numbers are for the reviewed commit.

## Confirmed mod defects

These two behaviors were reproduced by executing the actual source functions with engine stand-ins under Lua 5.4. They still need in-game verification. They belong to this mod, not separate vanilla issue reports.

### MOD-01 — P1: Hive snapshots are sent to players joining other teams

**Evidence**
- `ImprovedTooltips_TeamJoin.lua:31–38` calls `IT.ResyncPlayerHiveState(joined)` after every successful team join.
- `ImprovedTooltips_HiveState.lua:154–159` sends a clear, then all entries in `IT.publishedHiveState`, without checking the recipient's team.
- The source probe reproduced a marine recipient receiving an alien Hive's location, biomass, and both research slots.

**Impact:** the normal marine HUD does not display these records, but the client receives team-specific alien information. Hiding a widget does not restrict delivery of its data.

**Potential correction:** continue clearing stale state on team changes, but restrict nonempty snapshots to the intended alien team. Apply a consistent recipient rule to live broadcasts and join snapshots. Make cache ownership explicit, either through team-scoped storage or a deliberate supported-team mapping. Do not add spectator access incidentally.

**Acceptance checks**
- An alien late join receives the current Hive snapshot.
- Marine, ready-room, and spectator joins/transitions receive the clear without alien snapshots.
- Switching away from aliens removes the old client data.
- Reconnect, Hive destruction, and round restart do not replay obsolete state.
- Verify messages sent, not only what the HUD displays.

### MOD-02 — P2: Regression coverage for existing upstream issue #235

**Existing upstream report:** [#235 — Commander ability cooldowns are not displayed after changing commanders](https://github.com/GhoulofGSG9/ns2-game/issues/235). Martin confirmed this overlap on 2026-09-17. The empty-seat late-join case below documents incomplete coverage in our mod's repair; it is not a separate new vanilla report.

**Evidence**
- `ImprovedTooltips_CooldownState.lua:145–154` first clears the joining client's cooldown state, then returns if the team has no seated commander.
- The snapshot is otherwise reconstructed by querying that commander at lines 157–168.
- The source probe receives clear + an active cooldown with an occupied seat, but only clear with an empty seat.

**Trigger:** X casts an ability and leaves command. Y joins the team while the cooldown is still active and the chair is empty, then takes command. Y missed the original broadcast and has no active snapshot to replay. The authoritative cooldown can still prevent casting.

This does not imply that every commander handover is broken: a teammate who already received the cast broadcast is a different case.

**Potential correction:** retain authoritative active cooldown records per team on the server when `SetTechCooldown` runs, including the actual start time and duration. Replay them without requiring a seated commander. Expire/reset records at the correct lifecycle boundaries. If duration is added to the network message, treat that as a schema change and update both endpoints deliberately.

Review `ImprovedTooltips_CooldownSync.lua`, `ImprovedTooltips_CooldownState.lua`, `ImprovedTooltips_NetworkMessages.lua`, and the team-join hook together. Avoid relying on a private vanilla upvalue merely to bypass the seat requirement.

**Acceptance checks**
- Original caster and existing teammates keep correct remaining times.
- Both occupied-seat and empty-seat late joins recover the active cooldown.
- Entering/leaving command, expiration, bot commanders, and round reset work.
- Check the In Cooldown panel **and** vanilla button dial.
- Include vanilla and CBM abilities, especially any altered durations.

The general vanilla handover problem is already upstream issue #235; this is an uncovered case in our repair, not grounds for a duplicate upstream report.

## Reliability and test gaps

These are separate from the two reproduced gameplay-state defects.

### MOD-03 — Conditional failure: cooldown cache is published before construction succeeds

`ImprovedTooltips_Values.lua:339–357` assigns `cooldownTechIds = { }` before enumeration and TechData lookup finish. If a lookup raises after some entries are inserted, later calls can reuse the partial table instead of retrying.

The unsafe initialization pattern is present in source. This audit did **not** establish an actual current game/session failure caused by it.

Potential correction: populate and sort a local table, then assign the cache only after successful completion, as the project notes already recommend for other caches. A focused injected-failure test should show that a later call rebuilds the complete list.

### MOD-04 — Checker does not model separate game VMs

`tools/check_mod.lua:365–372` makes both `Client` and `Server` truthy in a permissive shared stub. Real server, game-client, and main-menu environments differ. Most function bodies also remain unexecuted by a top-level load check.

The checker passed all 34 files during this review, including the files containing MOD-01 and MOD-02. Preserve the checker, but do not treat that pass as a behavioral guarantee.

Potential improvements:
- Separate server, game-client, and main-menu load environments.
- An engine-like enum that raises on unknown names.
- Targeted strict API stubs and behavior checks for the state/queue functions.
- Lua 5.1/LuaJIT syntax checking when available; installed Lua 5.4 is not equivalent.
- Complete the two in-game sessions still owed by the existing cleanup plan.

## Optimization and maintainability candidates

These are **unmeasured opportunities**, not proven bottlenecks or promised FPS gains. The full plan provides details and sequencing.

| Area | Observed code pattern | Suggested investigation |
| --- | --- | --- |
| Research notifications | `ResearchStack.lua:64–99,146–175,208–240` repeatedly enumerates research and creates temporary lists/records/keys. | Share a per-update snapshot where ordering permits; reuse storage; preserve completion detection before vanilla cleanup and exact-once sound. |
| Cooldown panel | `GUIImprovedTooltipsCooldowns.lua:233–335` rebuilds active records and repeats text/layout updates. | Reuse records; change text only when displayed seconds change; cache layout inputs while retaining a smooth dial. |
| Hive research slots | `HiveResearchSlots.lua:266–336` creates short-lived lists/records. | Skip hidden slots early; cache countdown text and update quantized progress geometry when needed. |
| Supply and tooltip widgets | `InsightSupply.lua:150–169` repeats text; `TooltipGUI.lua:365–456` recreates row data/layout. | Cache unchanged values; account for vanilla resetting positions before the mod's hook. |
| Biomass overlay | `BiomassOverlay.lua:119–269` repeats geometry/setters and constructs Vectors. | Cache stable scale/theme geometry, preserve live progress. Correct comments claiming no allocation. |
| Server Hive publishing | `HiveSync.lua:78–141` creates maps/records each update despite already throttling progress messages. | Profile before changing; preserve immediate research-ID, biomass, cancellation, and destruction changes. |
| Movement-speed lookups | `Values.lua:237` creates small constant arrays and may repeatedly try instance-dependent accessors statically. | Hoist constant lists; consider caching lookup strategy only with safe invalidation. Do not freeze dynamic resolver results. |
| Dependencies and cache lifetime | Map color code uses Common helpers indirectly; interval/state caches deserve lifecycle checks. | Declare direct dependencies where appropriate. Verify reset behavior before adding reset hooks. No clock-reset bug was established. |

The shortened filenames in this table retain the `ImprovedTooltips_` prefix in the actual repository, except `GUIImprovedTooltipsCooldowns.lua`.

Also reconcile the stale spectator top-bar note about unconditional CBM purple with the current addon-mode check. This is documentation maintenance, not a new vanilla bug.

## Guardrails for any later implementation

- Make the two correctness fixes separate, reviewable changes before broad optimization.
- Keep all saved `BIT_*` keys, resolver API, approved glyphs/geometry, option defaults, and compatibility behavior.
- Keep the map diagnostic commands as Martin requested.
- Preserve friend tinting, viewer-team filtering, map/minimap separation, and copied-subclass handling.
- Preserve research sound-hook restoration when wrapped code throws; entities are userdata, not Lua tables.
- Preserve the server Hive synchronization: distant Hives are not necessarily relevant to the client.
- Keep the parked marine notification fix and shield-bar work out of this refactor unless Martin resumes them.
- Profile equivalent scenes before making performance claims.
- No production Lua or Launch Pad output was changed by this review/handoff. No issue was posted.
