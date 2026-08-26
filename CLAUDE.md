# CLAUDE.md — Bleu's Improved Tooltips

Working notes for this repo. `README.md` covers what the mod does and its public API; this file
covers things that are easy to get wrong.

## What this is

A **client-side-only** NS2 mod (standalone ModLoader mod, not a Shine extension) that adds
research time, cooldown, health and armour to the commander tooltips. Every value is readable on
the client, so the server does not need it.

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
  `Passes Default Consistency`.

## Environment constraints

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

## Status

- Version 0.81. **0.8 was tested in game by the user and published**; 0.81's changes (stat row moved
  under the title, hourglass redrawn) have themselves not been run yet.
- Published: Steam Workshop item `3790290682`. GitHub: https://github.com/Bleuitup/Bleus-Improved-Tooltips
- `preview.jpg` is a generated placeholder (`tools/build_preview.ps1`) — replace it with a real
  screenshot of an improved tooltip when there is one worth showing. Must stay 512x512.
- Open with the user: whether the Workshop item's tags should change (they raised server-side /
  whitelisting), and whether durations should switch from raw seconds to `M:SS`.
