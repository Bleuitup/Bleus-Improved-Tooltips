# CLAUDE.md — Bleu's Improved Tooltips

Working notes for this repo. `README.md` covers what the mod does and its public API; this file
covers things that are easy to get wrong.

## What this is

A standalone ModLoader NS2 mod (not a Shine extension) that adds research time, cooldown, health
and armour to the commander tooltips. All the logic is client-side — every value is readable on the
client and nothing is networked.

**But it is not a "works on any server" client mod, and must not be described as one.** NS2's
default consistency config restricts `lua/entry/*.entry`
(`core/lua/ConsistencyConfig.lua:29` → `Server.AddRestrictedFileHashes`), and `ServerConfig.lua:49-50`
defaults `consistency_enabled = true` / `use_own_consistency_config = false`. A client carrying an
entry file the server lacks is expected to be rejected, so the server needs the mod as well. 0.8
shipped with the description claiming the opposite and `tag_support = "Passes Default Consistency"`;
both were corrected in 0.81 to `Must be run on Server`. The user flagged this before I checked —
they were right.

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

## Commander ability cooldowns (verified 2026-08-26)

- **Cooldowns are team-global, not per-commander.** `Commander.lua:22` holds
  `local gTechIdCooldowns = {}` keyed by **team number**; `Commander_Server.lua:504` blocks a cast
  by checking it. Three Shades cannot alternate Ink. Durations: Shade Ink 15, Nano Shield 10,
  Heal Wave 6, Power Surge 4, Rupture 4, Hallucination Cloud 3, Nutrient Mist 2.
- **That table is file-local and never networked.** It exists separately in the server VM and every
  client VM. A client's copy is only written by `Commander:OnAbilityResultMessage`, driven by the
  `AbilityResult` message, which vanilla sends **only to the casting commander**. Vanilla marks the
  gap itself — `Commander:SetTechCooldown` ends with an empty
  `if Server then -- send message to commander to sync the cd end`.
- **The mod keeps its OWN client-side table** (`ImprovedTooltips_CooldownState.lua`) rather than
  reading `Commander:GetCooldownFraction`. That method exists only on a Commander, and on a client
  is only ever populated for the player who cast — so a field player, or a commander who just left
  the chair, has no data at all. The mod's table lives on the shared `ImprovedTooltips` table, not
  on the player entity, so it survives entity replacement on spawn/death/logout.
- **`AbilityResult` cannot be reused to reach field players.** `OnCommandAbilityResult` bails unless
  `Client.GetLocalPlayer():GetIsCommander()`, and `Client.HookNetworkMessage` is handed the function
  **by value** at load, so redefining the global later does not change what is registered. Hence the
  mod's own `ImprovedTooltipsCooldown` message.
- **`ClientUI` matches with `forPlayer:isa(class)`** (`ClientUI.lua:307`, `:386`), so registering a
  script for `"Player"` covers every class. It is not exact-name matching. Ready room is excluded
  separately via `kShowOnTeam[kTeamReadyRoom]`.
- **A GUI script registered for `Player` survives class AND team changes**, so anything cached at
  Initialize from the team (dial texture, tint, smoke) goes stale on a team switch. The panel
  re-initialises when `PlayerUI_GetTeamType()` no longer matches what it cached.
- **A team has at most ONE commander at a time**, however many command structures it owns — the
  user corrected me on this and the code agrees: `CommandStructure:GetIsPlayerValidForCommander`
  requires `not team:GetHasCommander()` (true if any Commander entity exists on the team), and
  `NS2Gamerules:OnCommanderLogin` gates on the same. `PlayingTeam:GetCommander()` just returns
  `commanders[1]`. **Do not write code that forwards state between simultaneous commanders** — a
  `SetTechCooldown` broadcast doing exactly that was written and removed as dead code. Every path
  that starts a cooldown already messages the single commander: the normal cast, and
  `Drifter.lua:525`.
- **No new network message was needed.** `AbilityResult` already carries `(techId, success,
  castTime)`. Since `gTechIdCooldowns` is unreachable, the start time is recovered through the
  public `GetCooldownFraction` as `castTime = now - (1 - fraction) * duration`.
- **`OnCommandAbilityResult` drops the message unless `Client.GetLocalPlayer():GetIsCommander()` is
  already true**, so syncing at login is racy — the client may not have swapped to the Commander
  entity yet. Sync on the commander's first server-side `OnProcessMove` instead, which only happens
  once the client is driving. `self.itCooldownsSynced` gates it; a fresh Commander entity is created
  by `player:Replace` on every login, so the flag resets naturally.
- **Hook `lua/Commander.lua`, never `lua/Commander_Server.lua`**, to wrap Commander methods:
  `Commander.lua:69` loads the server file long before `OnProcessMove` (~line 472) and
  `SetTechCooldown` (~408) are defined, so a hook there would wrap nothing.
- **Guard bot commanders.** `bots/CommanderBrain.lua:244` and `Drifter.lua:523` also call
  `SetTechCooldown`; virtual players have no client to message. Check `GetIsVirtual()`.
- The rotating timer is vanilla's `GUIDial` (`lua/GUIDial.lua`) with `ui/{marine,alien}_command_cooldown.dds`,
  configured as in `GUICommanderButtons.lua:75-118`. Anchoring it `Left`/`Bottom` with a zero offset
  over an equally sized parent makes it overlay exactly, because `GUIDial:Initialize` applies its own
  `-BackgroundHeight` offset.
- `kTechId` is **bidirectional** — `enum` rawsets both `[name]=value` and `[value]=name` (see
  CompMod's `EnumUtils.AppendToEnum`), so iterating it needs a
  `type(v) == "number" and type(k) == "string"` guard, and must skip `Max`.

## Environment constraints

- **`python` on PATH is the Microsoft Store stub**, not a real interpreter — it fails with "Python
  was not found". Do not reach for it for scripted text edits; use the Edit tool or `perl`.
- **Syntax-check before shipping:** `C:\Users\maost\AppData\Local\Programs\Lua\bin\luac.exe -p <file>`.
  It is **Lua 5.4** and NS2 runs **5.1**, so a pass proves the file parses but not 5.1 compatibility —
  and it says nothing about GUI layout or NS2 API use. Never report a `luac -p` pass as "verified";
  behaviour is in-game-only.
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

## Status

> ### ⚠ `main` is AHEAD of the published build and UNTESTED
>
> Everything after `v0.85` — the "In Cooldown" panel and the cooldown-sync fix — has **never been
> run in game**. It is marked by the annotated tag **`pending-test/cooldown-panel`**, whose message
> carries the full test checklist:
>
> ```bash
> git tag -l 'pending-test/*'
> git show pending-test/cooldown-panel
> ```
>
> Tag namespaces: `v*` = published, `pending-test/*` = compiles but unverified. **Delete the
> pending-test tag once the work is tested and released.** Do not publish to the Workshop while one
> is outstanding without saying so explicitly.

- Version 0.85, tested in game by the user and published. (There is no published 0.81 — that was the
  working version number while the stat row was moved and the hourglass redrawn; it shipped as 0.85.)
- Published: Steam Workshop item `3790290682`. GitHub: https://github.com/Bleuitup/Bleus-Improved-Tooltips
- `preview.jpg` is the user's own artwork (added 2026-08-26), replacing the generated placeholder.
  `tools/build_preview.ps1`, which produced that placeholder, has been deleted — do not recreate a
  script that writes `preview.jpg`, it would silently clobber real artwork.
  **It must stay 512x512 and stay a JPEG**: Steam rejects other sizes for this item, and
  `mod.settings` names the file by extension, so a `.png` beside it does nothing.
- **Durations are raw seconds, settled with the user after in-game review (2026-08-26).** Do not
  re-propose `M:SS`. `kTimeFormat` keeps the other modes, but `"seconds"` is the decision.
- Open: nothing, beyond testing the `pending-test/cooldown-panel` work above.
