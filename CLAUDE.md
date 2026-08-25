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
  right edge. We let vanilla position them and then repack over the visible ones.
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

- **No standalone Lua interpreter** on this machine — nothing here can even be syntax-checked
  locally. Everything must be verified in-game.
- **No `gh` CLI** — a GitHub remote has to be created on github.com by hand, then `git remote add`
  + push (Git Credential Manager supplies auth).
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

- Version 0.8. **Never run in game.** Nothing here is verified beyond reading vanilla source.
- No GitHub remote yet.
- `preview.jpg` is a generated placeholder (`tools/build_preview.ps1`) — replace it with a real
  screenshot of an improved tooltip before publishing. Must stay 512x512.
