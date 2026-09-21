# CLAUDE.md — Bleu's Improved Tooltips

Working notes for this repo. `README.md` covers what the mod does, its public API, every file and
hook, and the config; this file covers things that are easy to get wrong.

**Feature by feature research lives in [docs/development-notes.md](docs/development-notes.md)**, moved
there on 2026-09-17 to keep this file short: commander cooldowns, icons, movement speed and ARC
stances, ARC targeting, the biomass tech map, the hive status HUD, CBM compatibility, upgrade stat
deltas, glyph sizing and detail, Shine integration, the spectator top bar, and the 1.06 glyph
refresh. Read the matching section before changing any of those. The rules from it that must not be
broken are repeated under "Rules carried from the development notes" below.

## What this is

A standalone ModLoader NS2 mod (not a Shine extension) that started as research time, cooldown,
health and armor on the commander tooltips and now also improves the In Cooldown panel, the alien
hive status panel and research notifications, the biomass bar, the spectator top bar, the marine HUD,
maps and the scoreboard. Most values are read on the client; team cooldowns and per-hive biomass and
research are sent by the server in the mod's own network messages.

**But it is not a "works on any server" client mod, and must not be described as one.** NS2's
default consistency config restricts `lua/entry/*.entry`
(`core/lua/ConsistencyConfig.lua:29` → `Server.AddRestrictedFileHashes`), and `ServerConfig.lua:49-50`
defaults `consistency_enabled = true` / `use_own_consistency_config = false`. A client carrying an
entry file the server lacks is expected to be rejected, so the server needs the mod as well. 0.8
shipped with the description claiming the opposite and `tag_support = "Passes Default Consistency"`;
both were corrected in 0.81 to `Must be run on Server`. The user flagged this before I checked —
they were right.

## Code organization (refactor, 2026-09-17)

- **`ImprovedTooltips_Common.lua` holds anything more than one feature needs**: texture paths and the
  mod's icon sheet cells (`IT.GetOwnIconCoords`), the top bar supply icon, catching items a script
  creates (`IT.CaptureCreatedGraphicItems`), the positional biomass level tech ids,
  `IT.GetTechIdByName`, and on the server `IT.SendToPlayer` / `IT.SendToTeam`. Before adding a helper
  to a feature file, check whether it belongs there.
- **The Mods panel is one table.** `kOptions` in `ImprovedTooltips_ModsMenu.lua` holds each option's
  saved key, default, config field and widget; the panel and `ApplyStoredOptions` are built from it.
  Never rename a `BIT_*` key: it is what keeps a player's saved setting.
- **Run `lua tools/check_mod.lua` from the repo root before every commit.** It parses every file,
  checks load and hook targets, `IT.` names read but never assigned, globals read before their local
  declaration, unknown globals (baseline `tools/check_mod_globals.txt`), every file's top level
  against a stub game, and Mods panel defaults against the config. It caught its own bugs while being
  written; it cannot see inside functions or prove Lua 5.1 compatibility. The refactor plan and its
  phases are in `docs/refactor-plan.md`.

## Code review handoff (2026-09-17)

Read [mod-code-findings.md](docs/review-2026-09-17/mod-code-findings.md) before further refactoring.
It records two source-probe-confirmed mod defects (Hive snapshot recipients and empty-seat
cooldown joins), conditional reliability concerns, and unmeasured optimization candidates.
Findings apply to commit `16f0788`; recheck before implementing. The full plan and evidence are
linked there. This was a review of the mod and related vanilla/CBM paths, not all of NS2 Lua.

The broader follow-up is [broader-vanilla-review.md](docs/review-2026-09-17/broader-vanilla-review.md):
three additional upstream drafts (Power Surge/beacon, weapon-ammo pickup, timed mute expiry),
source probes, branch comparisons, and explicit scope limits. Cooldown handover is already
upstream #235; keep the mod regression test and do not create a duplicate report.

The [Arms Lab selection investigation](docs/review-2026-09-17/arms-lab-selection-investigation.md)
records a player-reported deselection near research completion. The isolated source probe did
not reproduce it, including stationary world-click release before/after completion. A small drag
can clear selection independently of research. The user confirmed a world-building click; exact
release timing and an in-game reproduction remain outstanding. Do not label this confirmed.

## Verified facts about vanilla (checked against the install, do not re-derive)

NS2 source for cross-checking: `D:\SteamLibrary\steamapps\common\Natural Selection 2\ns2\lua`.

- **All four commander-tooltip consumers go through one function.**
  `PlayerUI_GetTooltipDataFromTechId` (`Player_Client.lua:1177`) is called by `GUICommanderButtons`,
  `GUITechMap`, `GUIBioMassDisplay` and `GUICommanderHelpWidget`. They all register with the single
  `GUICommanderTooltip` instance, which renders via `UpdateData`. Hooking that pair covers
  everything — there is no second tooltip path to find.
- **`GUICommanderTooltip:UpdateData` takes positional arguments**, so extra fields added to the
  data table cannot reach the renderer. Hence the `IT.lastValues` stash in
  `ImprovedTooltips_TooltipData.lua`. It is safe because `GUICommanderTooltip:Update` takes the
  *first* non-nil `GetTooltipData()` result, stops querying the rest, and calls `UpdateData` in the
  same frame — and our `Update` hook clears the stash at the top of every frame.
- **`kTechType`** (`TechTreeConstants.lua:291`) is
  `Invalid, Order, Research, Upgrade, Action, Buy, Build, EnergyBuild, Manufacture, Activation, Menu, EnergyManufacture, PlasmaManufacture, Special, Passive`.
  `IT.GetTechCategory` maps these onto tech/structure/cast; it is *not* used to decide which
  numbers to show (TechData key presence decides that).
- **Bone Wall is the only vanilla dynamic-health commander tech.**
  `BoneWall:OnInitialized` (`CommAbilities/Alien/BoneWall.lua:104`) does
  `kBoneWallHealth + max(0, biomass-1) * kBoneWallHealthPerBioMass`. `BiomassHealthMixin` exists but
  its only users are `Clog`, `Hydra` and `Alien` — all gorge/player, never commander tooltips.
- **Mature alien structure health is NOT in TechData.** `AlienStructure:OnCreate(matureMaxHealth,
  matureMaxArmor, ...)` takes it as constructor arguments. Deliberately not shown — see README's
  known limitations. The user chose base-only for 0.8.
- **Client-side biomass** is `GetTeamInfoEntity(kTeam2Index):GetBioMassLevel()`, same as
  `GUIBioMassDisplay.lua:271`.
- **Vanilla's icon row uses hardcoded slots**, not a flow layout: cost at slot 1, supply at 3,
  biomass at 5, where slot *n* sits at `-kResourceIconSize * (2n-1) + kResourceIconXOffset` from the
  right edge. **We no longer touch that row at all** (0.81). 0.8 added research/cooldown to it and
  repacked it; because the row grows leftward, each added icon moved it ~2 icon-widths further left
  and it collided with long titles. Do not put anything back in that row.
- **`self.text` (the title) is not clipped or wrapped** — unlike requires/enables/info, it has no
  `SetTextClipped`, so it runs as long as it needs to and will happily overlap anything on the
  right-hand side of the same line. This is why the top row is off limits.
- **No vanilla tech has both a research time and a cooldown** — verified by scanning every TechData
  block for both keys, zero hits (77 have research time, 19 have cooldown). So the stat row is at
  most three entries wide. The code does not *depend* on this; a modded tech with both renders both.
- **The only place vanilla prints a research duration** is `GUIProduction.lua:335`, the production
  queue's hover text, as `M:SS` — but that is a live countdown. We default to raw seconds; see
  `kTimeFormat` in the config if that is revisited.
- **Entry `Priority` sorts descending** (`ModLoader.lua`, `SortByModPriority`). Lower number =
  registered later = post-hook runs last. Ours is 5 on purpose. For reference: CBM 100,
  Shimizu 99, CompMod 50, B2TP 28.
- **`modEntry.Client` is not usable here.** ModLoader turns it into a post-hook on `lua/Class.lua`
  (`modEntryFile`), which loads far too early to wrap GUI functions. Use explicit
  `ModLoader.SetupFileHook` calls via `FileHooks`, which is what this mod does.
- **Workshop tag vocabulary** (extracted from `x64/LaunchPad.exe`, UTF-16BE): modtype is one of
  `Crosshairs`, `Hitsound`, `Alien Vision`, `Gameplay Tweak`, `Look and Feel`, `Custom Game Mode`,
  `Localization`; support is `Passes Default Consistency` or `Must be run on Server`. "Interface"
  and "Client Side Only" are **not** valid values. This mod uses `Look and Feel` /
  `Must be run on Server` (see the consistency note at the top).


## Environment constraints

- **`python` on PATH is the Microsoft Store stub**, not a real interpreter — it fails with "Python
  was not found". Do not reach for it for scripted text edits; use the Edit tool or `perl`.
- **Syntax-check before shipping:** `C:\Users\maost\AppData\Local\Programs\Lua\bin\luac.exe -p <file>`.
  It is **Lua 5.4** and NS2 runs **5.1**, so a pass proves the file parses but not 5.1 compatibility —
  and it says nothing about GUI layout or NS2 API use. Never report a `luac -p` pass as "verified";
  behavior is in-game-only.
- **`gh` CLI is installed** at `C:\Program Files\GitHub CLI\gh.exe`, authenticated as `Bleuitup`.
  It is *not* on the Bash tool's PATH — call it by full path or from PowerShell.
- **No ImageMagick and no Python.** `convert` on PATH is Windows' FAT-to-NTFS converter — never
  invoke it. Image work goes through PowerShell + `System.Drawing`, and DDS conversion through the
  game's own `utils\nvcompress.exe` / `utils\nvdecompress.exe`.
- **PowerShell wildcard trap:** this repo's path contains `[01]` and `[07]`, which PowerShell
  parses as wildcard character classes. `Test-Path`, `New-Item`, `Get-Content` etc. silently do the
  wrong thing — always pass `-LiteralPath`. `.NET` calls like `[System.IO.File]::ReadAllBytes` are
  unaffected.
- **PowerShell alias trap:** `R` is an alias for `Invoke-History`, so a helper function named `R`
  is silently swallowed. The asset scripts use `Rct`/`Pt`.
- **CRLF:** if repo files end up CRLF, use `perl -i -pe` rather than `sed -i`, which rewrites the
  whole file to LF and produces a huge diff for a one-line change.

## NS2 Lua gotcha carried over from B2TP

Never put a multi-line `[[ ... ]]` long string in a Lua file if its content might contain `--`
anywhere. NS2's script preprocessor scans for `--` comment markers without tracking whether it is
inside an open long string, and truncates the file — reported as `unfinished long string near
'<eof>'` at the line with the first `--`, not at the real end. Build multi-line text as a table of
quoted strings joined with `table.concat`. Ordinary `"..."` strings are unaffected.

(`mod.settings` is read by Launch Pad, not NS2's loader, so its `[=[ ]=]` description block is
fine — but keep it pure ASCII and avoid `]=]` inside.)

## Launch Pad gotcha carried over from B2TP

Launch Pad **rewrites `mod.settings` on publish** from the copy it loaded when the project was
opened. Editing it on disk while Launch Pad has the project open gets silently clobbered. Change
`mod.settings` → fully close Launch Pad → reopen → publish. Workshop descriptions are BBCode, not
Markdown.

**It bit this repo on the 0.8 publish (2026-08-26).** Launch Pad wrote back a `mod.settings` with
the description emptied to `[=[]=]`, both tags emptied, the apostrophe stripped from the name, and
`publish_id = 3790290682` added. It was restored by hand in 0.81. Two lessons:

1. **Keep `publish_id`** — it is the only thing tying the project to the existing Workshop item.
2. **Never `git add -A` blind after the user has published.** Diff the staged changes first; the
   0.81 commit swept the wiped `mod.settings` in unnoticed. `git status` + `git diff --cached` on
   `mod.settings` before committing.

**The Workshop description has a hard 8000-byte cap, and this one is close to it.** Steam's
`k_cchPublishedDocumentDescriptionMax` is 8000; over that, publish fails with a Launch Pad dialog
reading `steam result InvalidParam(8)` and nothing else. It gives no hint that length is the cause,
and nothing local is wrong. **It bit the first 1.02 publish attempt (2026-09-06):** 1.01 published
at 7209 bytes, the two new features took it to 8250, and Steam refused the call. Measure before
publishing, counting only what is between `[=[` and `]=]`:

```
awk '/description = \[=\[/{sub(/^description = \[=\[/,"");f=1} f{if(/\]=\]$/){sub(/\]=\]$/,"");print;exit} print}' mod.settings | wc -c
```

**From here every release spends from a fixed budget.** Adding a section means compressing an
existing one. When a publish fails with InvalidParam and nothing about the files has changed
structurally, check the byte count first — preview size, tags and `publish_id` were all fine here
and cost time to rule out.


## Status

> Tag namespaces: `v*` = published and tested; `pending-test/*` = compiles but never run. If a
> `pending-test/*` tag exists, `main` is ahead of the published build — put the test checklist in the
> tag message, and delete the tag once that work ships. None is outstanding right now.

- **Published: 1.06** (`v1.06`, 2026-09-16), the glyph refresh and the ARC stat row fit. Steam
  Workshop item `3790290682`. GitHub: https://github.com/Bleuitup/Bleus-Improved-Tooltips. Every
  earlier version is in the README changelog.
- **Next: 1.07 candidate.** `feature/hive-research-slots` holds HIVE RESEARCH DISPLAY (NOTIFICATIONS
  default, HIVE PANEL; BOTH was dropped on 2026-09-17) and the alien research notification fixes,
  tested over five in-game rounds; see `docs/hive-research-slots.md`. `refactor/cleanup` is built on
  it and holds the refactor, whose two in-game test sessions were still owed on 2026-09-17.
- **Parked branches.** `feature/centralized-bars-shields` (alien shield bar and Centralized bar
  opacity; its first test showed the ydy style not working, the shield number misaligned and many
  opacity-layer script errors) must be rebased onto the refactor when it resumes, with conflicts
  expected in Config, ModsMenu, FileHooks, AdvancedHUDBars and Values. `feature/tooltip-text-audit`
  is planning only. `feature/spectator` and `feature/hive-hud-research` are design docs only.
  `wip/hive-hud-research-plumbing` is the user's own work in progress and known not to run.
- **Parked by the user: the same notification bugs in the marine stack.** See the end of
  `docs/hive-research-slots.md`.
- `preview.jpg` was generated in an earlier conversation with Claude (the user corrected this on
  2026-09-08; an older note here called it their own artwork). It replaced a rougher placeholder.
  `tools/build_preview.ps1`, which produced that placeholder, has been deleted — do not recreate a
  script that writes `preview.jpg` - it would clobber the current one.
  **It must stay 512x512 and stay a JPEG**: Steam rejects other sizes for this item, and
  `mod.settings` names the file by extension, so a `.png` beside it does nothing.
- **Durations are raw seconds, settled with the user after in-game review (2026-08-26).** Do not
  re-propose `M:SS`. `kTimeFormat` keeps the other modes, but `"seconds"` is the decision.
- **The map blip diagnostic console commands stay**, in `ImprovedTooltips_MapBlipDiagnostics.lua`
  (user decision, 2026-09-17). They are inert unless typed and are how a "no colors" report gets
  diagnosed.
- **Line endings.** `core.autocrlf` is `true` in this clone, so git stores LF and a checkout writes
  CRLF, while files written by the tools are LF; the working tree holds both. Git normalizes either
  way, so do not convert files for their own sake. **But a multi-line `perl -0` substitution written
  with `\n` silently matches nothing in a CRLF file** - that left the HIVE RESEARCH DISPLAY default at
  1 when BOTH was dropped. Use the Edit tool, or `\r?\n` in patterns, and check the result.
  Launch Pad writes `mod.settings` back as CRLF on publish, which is why `git status` shows it
  modified afterwards while `git diff` shows nothing.
- Discussed but not built: ARC range feedback, settled on drawing the 7m minimum-range circle plus an
  origin marker on nearby targets. See "ARC targeting" in `docs/development-notes.md`.

## Rules carried from the development notes

The detail and the evidence are in `docs/development-notes.md`.

- **Cooldowns:** a team has at most ONE commander at a time; do not write code forwarding state
  between simultaneous commanders. Hook `lua/Commander.lua`, never `Commander_Server.lua`. Guard bot
  commanders with `GetIsVirtual()`. If you touch the cooldown sync, check both the panel and
  vanilla's button dial.
- **Icons:** do not tint the vanilla health and armor art; before adding an icon, look for a vanilla
  one. The icon sheet's cell order is part of the contract: append, never reorder.
- **Speed:** do not hardcode a ShiftHive check (wrong under CBM); a speed accessor is called
  statically inside the value code, and the class accessor is the authority over `kMoveSpeed`.
- **Hive status HUD:** a Hive is NOT relevant to a client across the map, so do not "simplify" the
  mod's network message away. Lifeform research runs on the hive's EvolutionChamber, not the Hive.
  Never set a rotation offset on a GUIItem "to make sure". Verify GUI placement against a rendered
  mockup before shipping it.
- **CBM:** do not add a purple tint on the belief that CBM has one. New mod-specific behavior goes in a
  compatibility module like `ImprovedTooltips_CBM.lua`, never in the core files.
- **Glyphs:** never widen the hourglass; check any change at tooltip size, not just magnified.
- **SHELVED for 1.0 - do not reintroduce without asking:** upgrade buttons showing stats, speed
  dimming, CBM speed corrections.
- **Shine:** read the server half of a plugin to see what is actually sent.

## Building output/ (read before rebuilding)

`output/` is what Launch Pad ships and what the game actually loads. It is git-ignored, so if it is
missing or stale **nothing in git will tell you** -- the repo looks perfectly clean while the mod
does nothing in game. That is exactly the failure seen on 2026-08-30: the user launched from Launch
Pad and saw none of the mod, because `output/` had been deleted.

Rebuild with:

```bash
mkdir -p output && cp -r source/. output/
```

**Do not use `rm -rf output && cp -r source output`.** This repo lives on `G:\My Drive`, a Google
Drive mount, and deleting a whole directory tree and recreating it at the same path in the same
instant is exactly the pattern Drive's sync can reconcile badly -- the delete propagates, the
recreate does not. The command above never removes the directory itself.

**If it has already been broken, the symptom is `Access is denied` on every read**, from bash and
PowerShell alike, while `Test-Path` returns false and `Get-Item` denies -- the directory is
simultaneously "there" and "not there". It happened again on 2026-09-07, from an `rm -rf output`
that this section already warns against. Recovery, in order:

1. Ask the user to quit and relaunch Google Drive. Necessary, but on its own it was not enough.
2. `cmd /c rmdir /s /q "<path>"` -- reports `Access is denied` and exit 5, but appears to queue the
   delete anyway.
3. `cmd /c move "<path>" "<path>_broken"` -- reports "cannot find the file specified", and the path
   is then clear. Between 2 and 3 the entry resolves.
4. `mkdir -p output && cp -r source/. output/`, then `diff -r source output`.

Nothing is at risk while this is going on: `output/` is a build artifact, regenerable from `source/`
in one command, and git holds the only copy that matters. Do not panic-commit around it.

If a file is renamed or deleted in `source/`, that copy leaves the old one behind in `output/`, so
after a rename check for strays:

```bash
diff -r source output
```

Verify after every rebuild, because a partial `output/` fails silently:

- `diff -r source output` reports no differences
- every `SetupFileHook` target in `ImprovedTooltips_FileHooks.lua` resolves to a file that exists
- every `Script.Load("lua/ImprovedTooltips/...")` target exists
- `lua/entry/ImprovedTooltips.entry` is present -- without it the mod is not a mod

Note that `luac -p` passing proves nothing about `output/`; it only checks `source/`.


## kTechId is an ENGINE enum, not a table -- it RAISES on unknown names

Found in game on 2026-08-30, from `log.txt`:

```
Error: lua/ImprovedTooltips/ImprovedTooltips_Values.lua:387: Element 'DualMinigun' doesn't exist in the enum
```

`kTechId[name]` for a name the enum does not hold **raises a Lua error**; it does not return nil.
There is no Lua-side `enum` implementation to read -- it is engine code -- so this is only
discoverable by hitting it. Vanilla has `UpgradeToDualMinigun` and **no** `kTechId.DualMinigun`, so
deriving a product name from an upgrade name and looking it up throws on a plain vanilla install.

**Always use `IT.GetTechIdByName(name)`** for any name that might not exist: tech from a mod that may
not be loaded, or a name derived from another name. It uses `rawget`, which reads the underlying
table (where the entries actually live -- `pairs()` walks them) without going through the metamethod
that raises. Reverse lookups `kTechId[someNumber]` use `rawget` for the same reason.

Two things this cost, both from one error:

- The error aborted the `pairs` walk that builds the upgrade-target cache. The cache had already been
  assigned an empty table, so it was left **half built** and silently answered nil for everything not
  yet reached -- which is why CBM's Fortress upgrade buttons showed only a research time. Caches are
  now built into a local and published only once complete, so a throw leaves the cache nil and the
  next call retries.
- `GetIsCBMLoaded` tested `kTechId.FortressCrag ~= nil`, which would have raised on any non-CBM
  install. It did not fire in that log only because CBM (dev) was in fact mounted.

**Harness lesson:** the earlier harnesses used a plain Lua table for `kTechId`, which silently
returns nil and so could never have caught this. `scratchpad/test_enum.lua` models the real thing
with an `__index` that raises. Any future harness touching `kTechId` must do the same.


## Hooking a method on a class that has SUBCLASSES needs Class_ReplaceMethod (1.03)

**NS2's class system copies methods into derived classes at declaration time.** It does not delegate
through `__index`. So this, which is right everywhere else in this mod:

```lua
local original = SomeClass.SomeMethod
function SomeClass:SomeMethod(...) ... end
```

**silently fails to reach any subclass** that was declared after the method existed. The subclass is
holding its own copy.

`core/lua/Class.lua:18` provides the answer, and its existence is the proof of the rule:

```lua
originalMethod = Class_ReplaceMethod("MapBlip", "GetMapBlipColor", myWrapper)
```

It swaps the method, returns the original, and walks `Script.GetDerivedClasses` replacing it in
every subclass that still holds that original.

**It bit the marine map blip colors in 1.03, and the symptom was nothing at all happening.** Players
do not get a `MapBlip`: `MapBlipMixin.lua:59-64` gives a `Player` a **`PlayerMapBlip`**, declared at
`MapBlip.lua:461`, which does not override `GetMapBlipColor` and therefore holds a copy of it. Plain
assignment to `MapBlip.GetMapBlipColor` left every player blip calling vanilla.

Plain reassignment stays correct for the mod's other hooks - `GUIScoreboard:UpdateTeam`,
`GUIInsight_TopBar:Initialize`, `GUIMarineHUD:Update` - because nothing derives from those. The test
is whether the class has subclasses, not whether the hook looks like the others.

**Also worth knowing while debugging that one:** `Shared.GetEntitiesWithClassname("MapBlip")` will
not list player blips either; they are `"PlayerMapBlip"`.



## Entities are userdata, not tables (found 2026-09-17)

`rawget(player, ...)` raises `table expected, got userdata`. The first sound fix for hive research
did exactly that inside `GUIEvent:Update` and threw on every notification update (3445 errors in one
session), which also stopped the alien notification stack from updating. To override a method on
one entity temporarily, swap it on its class table (`_G[entity:GetClassName()]`, with
`rawget`/`rawset` on that table) and restore it with the call wrapped in `pcall`.
`ImprovedTooltips_ResearchStack.lua` is the example.
