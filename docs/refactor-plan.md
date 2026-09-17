# Refactor plan

Written 2026-09-17 after reading all 32 Lua files (6,526 lines, about a third of them comments) on
`feature/hive-research-slots` at `ce1ae75`. **Status: all six phases done on `refactor/cleanup`
(2026-09-17); both in-game test sessions still owed.** Decisions recorded at the end.

## Done

| Phase | Commit | Notes |
| --- | --- | --- |
| 0 | `cfc8fa5` | `tools/check_mod.lua` and its globals baseline. Proven against six deliberate mistakes. |
| 1 | `d524c72` | A1, A2, A4. |
| 2 | `49d8990` | `ImprovedTooltips_Common.lua`, `ImprovedTooltips_TeamJoin.lua`. |
| - | `8ad50d5` | Not refactor: the HIVE RESEARCH DISPLAY default was still 1 (now HIVE PANEL) after BOTH was dropped, because a text substitution missed a CRLF file. Fixed on the hive branch and merged in. |
| 3 | `e4749fb` | Mods panel from one table, verified identical to the old panel in both VMs; the check also compares panel defaults with the config. File hooks grouped. |
| 4 | `3110fcd` | Hive state without `researching`, slots in `ImprovedTooltips_HiveResearchSlots.lua`, `kShowHiveResearch`. Verified by a simulation of the sync over fake hives (15 cases). |
| 5 | `295461c` | C4, C5, C7; diagnostics in `ImprovedTooltips_MapBlipDiagnostics.lua`. |
| 6 | this commit | README hooks, layout, config, check section; `CLAUDE.md` status rewritten and feature history moved to `docs/development-notes.md`. |

Decision 3 was not acted on: the unused duration formats and the panel backing opacity remain.

## Ground rules

- **No change a player can see**, except the bug fixes listed under A, each called out as such.
- **The public API stays exactly as documented in the README:** `RegisterResolver`, `SuppressField`,
  `GetTechCategory`, `RegisterIconColor`, `GetValue`, `GetValues`, `HasResolver`.
- **Saved settings survive:** every `BIT_*` option key keeps its name.
- **Comments survive.** They carry verified facts about vanilla that took testing to learn. Only stale
  or wrong ones change.
- **One commit per step, on its own branch**, so any step can be reverted alone.
- **Every step is checked before it is committed:** `luac -p` on every file, a rebuilt `output/`
  diffed against `source/`, and a new static check (Phase 0). In-game testing is grouped into two
  sessions rather than one per step.

## Findings

### A. Bugs and wrong information, none visible in game today

1. **The spectator supply counter reads the top bar's icon theme with the wrong field names**
   (`entry.texture` / `entry.coords` instead of `icon` / `pxCoords`), so it always uses the hardcoded
   fallback. The same art today, but a mod that re-themes the top bar would be ignored there while the
   commander tooltip follows it.
2. **Three guards in `ImprovedTooltips_Values.lua` cannot work.** `if kTechId.DrifterEgg then` and the
   two ARC stance equivalents index the engine enum directly, which raises on a missing name instead of
   returning nil. Under a mod that removed one of those techs, the file would stop loading part way,
   taking the Bone Wall resolver and the CBM module with it. The same direct indexing builds both
   biomass tech lists. Vanilla, CBM and B2TP all have these techs, so it has never fired.
3. **The README's hook table lists 13 of the mod's 23 hooks.**
4. **Stale comments**, for example: the icon sheet described as "320x64" (it is 448x64, seven cells),
   the file hooks header saying "the two post-hooks that make up the whole mod", a hive state comment
   about "old callers", and a missing section divider in the config.

### B. The same thing written more than once

1. **Two `NS2Gamerules:JoinTeam` wrappers**, `CooldownJoin.lua` and `HiveJoin.lua`, doing the same
   job for two features. One file can resync both.
2. **Two copies of "send a message to a player, skipping bots" and "send it to the whole team"**, in
   the cooldown and hive state files.
3. **Two copies of the top bar supply icon lookup** (TooltipGUI, InsightSupply), which is how A1
   happened.
4. **Two copies of "catch the items GUIInsight_TopBar creates"**, a delicate trick (swap
   `GUIManager.CreateGraphicItem` for the duration of `Initialize`, restore it even on error), in
   InsightTopBar and InsightSupply.
5. **Two copies of the twelve biomass tech ids** (BiomassProgress, BiomassOverlay).
6. **Two copies of the progress-to-percent rounding** for the hive message.
7. **The mod's icon sheet coordinates in three files** (TooltipGUI, SelectionPanel, TournamentReady),
   and the build menu texture path in five.
8. **Two copies of "queue every research in progress"** in `ResearchStack.lua`.
9. **Every Mods panel option is written in four places**: its key, its default, the line applying
   it, and its widget, plus its default a fifth time in the config. One table entry per option would
   replace all of them, and adding an option becomes one entry.

### C. Simpler ways to do the same thing

1. **The hive state's `researching` flag can be derived** from its two research ids, so it can leave
   the state table and the network message.
2. **Hive research reading on the server** goes through two nested helpers with a `pcall` on every
   method call; one reader does it.
3. **The hive research slot has six parts shown, hidden and destroyed line by line** in three
   places; a list of parts replaces that.
4. **`tooltipData.improvedTooltipsTechId` is written and never read.**
5. **`GetValues` names each field by hand** instead of walking `IT.kFields`, so a new field would
   need adding in two places.
6. **`kShowHiveResearchIcon` now switches the hive panel slots too**, not just the icon; rename to
   `kShowHiveResearch`.
7. **The In Cooldown panel builds a new filtered list of abilities every frame**; it can reuse one
   until the minimum duration setting changes.

### D. Organization

1. **`HiveStatusGUI.lua` (593 lines) holds three features**: the biomass icons, the busy ring, and the
   research slots drawn as a notification in miniature. The slots move to their own file.
2. **`MapBlipColor.lua` (530 lines) ends in about 130 lines of diagnostic console commands**,
   `it_blipcolors` and `it_blipstate`. See decision 2.
3. **`FileHooks.lua` becomes grouped by feature**, with a correct header.

### E. Documentation

1. README: the hook table and the config list brought current.
2. `CLAUDE.md`: its Status section still describes 1.06 as unreleased on `feature/glyph-refresh`.

## Out of scope

- No change to gameplay, visuals, option keys, network message names or the public API.
- `tools/build_icons.ps1` and the icon sheet are untouched.
- Other branches are untouched (see decision 1).

## Phases

| Phase | Contents | Risk |
| --- | --- | --- |
| 0 | New branch `refactor/cleanup`. A static check run before every commit: every `Script.Load` and file hook target exists, every `IT.` name read somewhere is defined somewhere, and every file loads under stub globals in `lua.exe` (catches mistakes in top-level code). Kept in `tools/`, not shipped. | None |
| 1 | A1, A2, A4. Bug fixes and stale comments. | Low |
| 2 | B1 to B8: a shared helpers file (sending, the icon sheet and texture paths, the supply icon, item capture, biomass tech ids) and the two join hooks merged. | Medium: server and spectator paths |
| 3 | B9 and D3: the Mods panel rebuilt from one table of options. | Medium: menu wiring |
| **Test session 1** | Tooltips, In Cooldown panel (including joining a team mid-cooldown), spectator top bar, all Mods panel options and their defaults. | |
| 4 | C1 to C3, D1: hive state, hive sync, and the slots moved to their own file. | Medium: server message changes |
| 5 | C4 to C7, D2 per decision 2. | Low |
| **Test session 2** | Both hive research modes, joining mid-round, the biomass bar, arms lab icons, map blip colors, minimap arrows, exo bars, tournament labels. | |
| 6 | E1, E2. Documentation. | None |

The code should shrink by a few hundred lines, most of it the menu and the duplicates.

## Decisions (2026-09-17)

Answered: 1 now, rebase the shield branch later; 2 keep, in a file of their own; 4 fix the status and
move the history into `docs/`. Decision 3 was unclear to the user and is explained again; the
settings stay unless they say otherwise.


1. **Timing and the shield branch.** Recommended: refactor now on top of the hive research work, and
   when the alien shield bar resumes, I rebase `feature/centralized-bars-shields` onto the result. It
   touches five of the same files (Config, ModsMenu, FileHooks, AdvancedHUDBars, Values), so
   conflicts are certain and are mine to resolve.
2. **The map blip diagnostic commands** (`it_blipcolors`, `it_blipstate`): keep them in a file of
   their own, or remove them. They cost nothing unless typed, and are how a "no colors" report was
   diagnosed.
3. **Settings no one can reach that do nothing different**: the two unused duration formats
   (`"suffix"`, `"clock"`) and the In Cooldown panel's backing plate opacity, zero for both teams.
   Keep or remove.
4. **`CLAUDE.md`**: only fix its Status section, or also move its long history into `docs/` so the
   working notes are shorter.
