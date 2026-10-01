# Refactor and optimization review — 2026-09-17

## Recommendation

Continue from Claude's completed cleanup. The next work should prioritize two confirmed state-delivery problems, retained behavioral tests, and measured reductions in per-frame work. A broad rewrite is not justified by this review.

This is a plan and audit, not an implementation. Production Lua, textures, saved settings, source/output packages, branches, and releases were not changed.

## Reviewed baseline

- Repository: Bleu's Improved Tooltips.
- Branch: `refactor/cleanup`.
- Commit: `16f078808555d84f7d9f13cfe2db9ef2bc089361`.
- Starting working tree: clean.
- Published version: 1.06. The branch contains the 1.07 hive research candidate plus cleanup and a biomass initialization fix.
- Read `CLAUDE.md`, `docs/refactor-plan.md`, the updated hive research notes and related feature documentation; traced state/network/hook behavior and the update paths of the major HUD features.
- Existing checker: `check_mod: OK, 34 files`.
- Recursive source/output inventory and SHA-256 comparison: zero missing, different, or extra output files.
- The existing plan says six phases are complete but two in-game sessions remain. Do not treat those sessions as completed without a later test record.
- Supplemental probes execute actual source functions with engine/GUI stand-ins under Lua 5.4. They do not establish in-game behavior or Lua 5.1 compatibility.

See [verification and upstream status](review-evidence.md) and [the probe script](audit-probes.lua).

## Keep Claude's completed work

The shared helpers, single team-join hook, table-driven settings menu, isolated Hive research slots, separated map diagnostics, and filtered cooldown list cache are already present. Repeating those changes would add churn.

Preserve the public resolver API, every saved `BIT_*` key, approved visual geometry and glyphs, load priority and compatibility behavior. Keep the diagnostic commands as the user requested. Retain comments that explain verified engine constraints. Parked shield-bar work and the marine notification fix remain separate from this refactor.

## Findings that change the order of work

### P1 — Hive snapshots are sent to the wrong teams

Evidence: `ImprovedTooltips_TeamJoin.lua:38` invokes `ResyncPlayerHiveState` for every successful join. `ImprovedTooltips_HiveState.lua:154` clears the recipient's cache and then replays every entry from `publishedHiveState`, without checking the recipient's team. The probe reproduced a marine recipient receiving the location, biomass and both research slots of an alien Hive.

The normal marine HUD does not show these records, but the client still receives team-specific research information. This is a mod defect, not a vanilla issue to report upstream.

Plan: clear stale client state on any team transition, but send nonempty Hive snapshots only to the intended alien team. Keep live broadcasts and join snapshots under the same recipient rule. Make the cache explicitly team-scoped, or explicitly enforce the supported team mapping. Do not accidentally add a new spectator entitlement.

Acceptance: alien late join receives the correct snapshot; marine, ready-room and spectator transitions clear previous state without receiving alien snapshots. Reconnection and round reset do not restore old records.

### P2 — Joining during an empty commander seat misses active cooldowns

Evidence: `ImprovedTooltips_CooldownState.lua:145` reconstructs a snapshot using the seated commander. Lines 151–154 return after sending only a clear when there is no commander. The probe contrasted clear + active cooldown with an occupied seat against clear alone with an empty seat.

Trigger: X casts, leaves the chair, Y joins the team during the remaining cooldown, then takes command. Y missed the original broadcast, receives no active snapshot, and the client-side replay has nothing to restore. This is a gap in the mod's synchronization, not a new vanilla report separate from #235.

Plan: retain authoritative cooldown records per team on the server when `SetTechCooldown` runs, including the actual start time and duration. Replay active records independently of a seated commander, prune expired entries, and clear them at the correct round/map lifecycle boundary. If actual duration is transmitted, treat that as an explicit network-schema change and test both endpoints. Avoid reading a private vanilla upvalue unless a stronger reason emerges.

Acceptance: original caster, existing teammate, occupied-seat join, empty-seat join, leave/reenter command, expiration, bot commander and round reset all agree on remaining time in both the panel and vanilla button dial.

## Proposed sequence

| Phase | Work | Completion criteria |
| --- | --- | --- |
| 0. Preserve and characterize | Record this baseline; retain the state tests; improve VM-specific checks; complete the existing in-game checklist before stacking major structural changes. | Baseline failures are explicit; unrelated behavior is recorded. |
| 1. State correctness | Fix recipient scoping and empty-seat cooldown snapshots in separate commits. | Focused tests pass; both endpoints and handover scenarios work in game. |
| 2. Research tracking | Reduce duplicate scans and allocations in `ResearchStack`, keeping sound detection before vanilla's cleanup. | Same queue contents and completion events; fewer enumerations and temporary tables. |
| 3. HUD updates | Update mod-owned text/layout only when inputs change; preserve smooth fills/rotation. | Matching screenshots and transitions; fewer redundant setters. |
| 4. Server publishing and caches | Reduce temporary Hive state allocations, make cache lifetimes explicit, harden cache initialization. | Same immediate state changes and progress rate; no stale snapshots. |
| 5. Integration and delivery | Test vanilla, CBM and relevant companion mods; verify package contents and document results. | Existing regressions pass; any performance claims have measured evidence. |

Each implementation phase should be a small reviewable commit. Keep bug fixes distinguishable from changes intended to preserve behavior. Choose the final release number when the tested scope is settled.

## Optimization targets, in priority order

### 1. Research notification tracking

`ImprovedTooltips_ResearchStack.lua:64–99,146–175,208–240` enumerates in-progress research before vanilla's update and again while recovering dropped notifications. It creates lists, keyed tables, per-research records and string keys each frame. HIVE PANEL also repeatedly considers filtered research that will not be queued.

Use a single per-update research snapshot where ordering permits, reusable current/previous buffers, and a retained membership set for notification/queue keys. Keep identities as tech ID plus entity ID, and test cancel/restart of the same tech.

Separate the research transition logic from the GUI adapter so tests can exercise completion, cancellation and overflow without recreating every graphical item. Keep this feature-local; there is no need for a general event framework.

Preserve `pcall` restoration around the temporary class-method override. That override is compatibility-sensitive. Replacing it with a permanent global hook or replacing all of GUIEvent would be a larger risk than the measured allocation issue.

### 2. Redundant HUD text and layout writes

- `GUIImprovedTooltipsCooldowns.lua:233–335`: cached eligible tech IDs already exist, but the active list and entries are rebuilt each frame. Reuse storage; cache layout by visible count/team/scale/options. Update seconds text when its displayed integer changes and texture coordinates when its tech ID changes. Keep the dial animated.
- `ImprovedTooltips_HiveResearchSlots.lua:266–336`: remove the short-lived research list/records, skip hidden slots early, cache countdown text by displayed second, and update progress geometry when its quantized input changes.
- `ImprovedTooltips_InsightSupply.lua:150–169`: only rewrite text when used/max supply changes.
- `ImprovedTooltips_TooltipGUI.lua:365–456`: reuse temporary row storage and cache formatted text/widths for unchanged inputs. Do not skip the post-vanilla layout adjustments blindly: vanilla repositions its own items each update.
- `ImprovedTooltips_BiomassOverlay.lua:119–269`: texture, size and placement can be cached until scale/theme changes; progress crop can remain live. Existing comments claiming no allocations overlook the Vector construction.
- Exo bars already cache percentage text. Preserve their smooth charge/heat updates; do not make them visibly step to save a few calls.

### 3. Server Hive state publishing

`ImprovedTooltips_HiveSync.lua:78–141` already limits progress messages to once per second and immediately sends ID/biomass changes. It still creates a fresh current-state map and records on each update.

Profile this before changing it. If worthwhile, reuse per-team/per-location storage and compare scalar fields before materializing a message. Preserve immediate completion/cancellation/death changes. Moving the entire reader to a one-second timer would delay those transitions and change behavior.

Check stable message counts and deletion handling over multiple rounds. Make round reset and team ownership explicit rather than relying on global tables persisting safely.

### 4. Cache reliability and narrow dependencies

- `ImprovedTooltips_Values.lua:339–363` assigns the cooldown cache before filling it. Build into a local and publish only after successful enumeration, matching the documented cache-safety rule. A failed lookup should not leave a partial permanent cache.
- `LookupClassMoveSpeed` at line 237 creates two literal arrays per lookup and can repeatedly make protected static calls that fail for instance-dependent accessors. Hoist the small lists. Cache a safe lookup strategy only with class/method identity and invalidation considered; do not freeze dynamic public resolver results.
- `MapBlipColor` already caches colors and refreshes player status on an interval. Preserve those improvements and its friend tint, viewer-team guard, map/minimap split and subclass handling.
- Declare its direct dependency on Common explicitly when it calls `IT.GetTechIdByName`; avoid relying on another feature to have loaded it first.
- Ensure interval caches recover if their time source goes backward; verify the game's actual reset behavior before introducing broad reset hooks.
- Feature files using only Common/Config need not load the full resolver/CBM module indirectly. Reduce dependencies only where the needed symbols and load order are clear.
- Correct the stale top-bar documentation about unconditional CBM purple; the current compatibility code checks addon mode.

## Verification improvements

The existing checker is useful and should stay. Its permissive shared stub sets both `Client` and `Server` truthy (`tools/check_mod.lua:365–372`), which is not a real game VM. It can hide wrong-side dependencies and does not execute most behavior.

Add separate server, game-client and main-menu load checks. Use a strict engine-like enum that raises on unknown names, targeted API stubs that reject incorrect argument types, and tests that actually call the state/queue helpers. Add a Lua 5.1/LuaJIT syntax check when a suitable runtime is available; do not describe the current Lua 5.4 check as equivalent.

Retain focused regressions for:
- Team-specific message recipients and empty-seat cooldown joins.
- Multiple researches, overflow, cancellation, same-tech restart, simultaneous completion and exact-once sound.
- Switching NOTIFICATIONS/HIVE PANEL, disabling the Hive status panel and changing local player class.
- Two research slots, late joins, Hive loss and round restart.
- Two/three/four pending biomass gains, including construction; cancel/loss and the upstream biomass dirty-flag fix.
- Hook restoration on thrown errors and the copied-subclass MapBlip case.
- Existing option keys/defaults and main-menu versus in-game behavior.

## Profiling and in-game matrix

Instrument feature scopes with the game's profiler, then compare the same scenes before/after: idle field player; busy alien team with six researches; repeated tech tooltip hover; spectator HUD; populated big map; exo charge/heat. Record scope time, enumeration counts, allocation behavior and message counts. Report relative changes under equivalent conditions; no FPS improvement has been measured in this audit.

Run the existing two test sessions plus the new edge cases in vanilla and CBM release/dev. Include B2TP exos and Devnull scoreboard/Shine tournament integration where relevant. Verify source/output content and stale-file removal after any renamed file. Preserve the 8000-byte Workshop description limit and Launch Pad reload requirements at release time.

## Upstream issue disposition

- Cooldown handover is already [#235](https://github.com/GhoulofGSG9/ns2-game/issues/235).
- Multiple biomass gains are already [#236](https://github.com/GhoulofGSG9/ns2-game/issues/236).
- The `self.techtree` biomass-change typo is fixed on the inspected upstream beta branch; no new report.
- Notification overflow and missed completion sound remain in the inspected upstream code. They were already documented by Claude, so they are not new discoveries; no matching issue was found in the inspected tracker. A [combined draft](upstream-notification-overflow-draft.md) is provided because queue loss and the missed sound share a mechanism.
- No further previously undocumented vanilla bug was established strongly enough to draft as fact. The two new state-delivery findings above belong to this mod.

Nothing was posted to GitHub.
