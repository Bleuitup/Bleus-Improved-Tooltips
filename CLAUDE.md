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
- **Two tables, and both need feeding.** The mod's own table drives the mod's panel; vanilla's
  `gTechIdCooldowns` drives vanilla's rotating dial on the commander button. Filling only ours fixes
  the panel and leaves the button dial blank — that regression shipped once, in `20b8b80`, because
  the rewrite for team-wide visibility replaced the `AbilityResult` replay that had been feeding
  vanilla's table. `Commander:SetTechCooldown` is the public way into vanilla's, so
  `ImprovedTooltips_CooldownDial.lua` replays ours into it on `Commander:OnInitialized`
  (client-side, no server involvement — the client already has the data from the team broadcast).
  **If you touch the cooldown sync, check both views.**
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

## Icons: prefer vanilla, ship as little as possible

- **Health and armour come from `ui/{marine,alien}_commander_textures.dds`** at `(0,363)-(48,411)`
  and `(48,363)-(96,411)` — the cells `GUISelectionPanel.lua:54-55` draws when you click a
  structure. They are already coloured per team, so **do not tint them**, and they sit in the very
  atlas the tooltip background already loads. 0.86 and earlier drew custom ones after rejecting the
  softer copies in `ui/alien_buymenu.dds`; that was looking at the wrong atlas.
- **Those cells are baked at VANILLA's proportion, and the tooltip magnifies by sampling inward.**
  The glyph is 39px in a 64px cell (~61%, what vanilla uses); the selection panel draws the full
  cell, the tooltip samples a centred 48px window giving 39/48 = 81%, matching the other icons.
  Baking at 81% instead made the tooltips right and blew up vanilla's selection panel — same item
  size, bigger glyph inside it (issue #2). Sampling inward is safe; sampling outward to shrink
  would bleed into neighbouring cells.
- **The mod ships resampled copies of vanilla's cross and shield** (atlas cells 3 and 4), rather
  than drawing the vanilla atlas directly. Three reasons, all found in testing: the source glyphs
  occupy only ~29px of a 48px cell so they rendered smaller than the other icons; they top out at
  alpha 233 (149 on the marine atlas) so they looked translucent beside the opaque drawn glyphs; and
  being amber they could not be tinted onto a target colour at all, because `SetColor` multiplies
  and can only darken. The baked copies are white and fully opaque, so the tint lands exactly.
  `ImprovedTooltips_SelectionPanel.lua` repoints vanilla's own panel at the same cells - **keep the
  two in step.**
- **Match the figure colours too**, from `GUISelectionPanel.kHealthBarColors` / `kArmorBarColors`
  (`GUISelectionPanel.lua:21-27`): marine health `(0.725, 1, 1)`, marine armour `(0.078, 0.9, 1)`,
  alien health `(1, 197/255, 71/255)`, alien armour `(1, 143/255, 34/255)`. Read at runtime with
  those literals as fallback, so the mod follows anything that changes them.
- **Alien speed uses the Celerity icon**, `kTechIdToMaterialOffset[kTechId.Celerity] = 64` → cell
  (4,5) of `ui/buildmenu.dds`. Greyscale, already points right, and CBM assigns the same index to
  `SpurPassive`.
- **Icon indices in `buildmenu.dds` are `y*12 + x`, 80px cells**, sheet is 960 wide.
- The mod's own sheet is now **192x64, three cells**: hourglass, stopwatch, marine speed chevron.
- **The marine chevron is lifted, not drawn**: `marine_buildmenu_insight.dds` row 2 col 4
  (x 240-320, y 80-160), mirrored to point right. Its button plate is **opaque**, so unlike the
  buy-menu glyphs the alpha channel is useless — luminance becomes the mask instead. Luminance alone
  still cannot remove the plate's *border*, which is as bright as the glyph, so the extract is
  cropped to `(14,10)-(74,70)`; the measured glyph extent is x 20-70, y 12-66.
- **Before adding an icon, look for a vanilla one.** The atlases worth checking are
  `{marine,alien}_commander_textures.dds` (selection panel furniture), `buildmenu.dds` (all tech
  icons), and `marine_buildmenu_insight.dds` (arrows, symbols).

## Movement speed and ARC stances

- **Speed has no TechData key**, and vanilla stores it inconsistently. Verified values:

  | Class | Real source | Speed |
  |---|---|---|
  | ARC | `ARC.kMoveSpeed`, no accessor (`ARC_Server.lua:29`) | 2.0 |
  | Drifter | `Drifter.kMoveSpeed`, no accessor | 11 |
  | MAC | `MAC.kMoveSpeed` via `GetMoveSpeed` | 6 |
  | Whip | `Whip.kMoveSpeed` via `GetMoveSpeed` | 3.5 |
  | Shift | `Shift.kMoveSpeed` via `GetMaxSpeed` | 2.9 |
  | **Crag** | **`Crag.kMaxSpeed`** via `GetMaxSpeed` — different constant name | 2.9 |
  | **Shade** | **global `kAlienStructureMoveSpeed`** via `GetMaxSpeed` | **1.73** |

  **`Shade.kMoveSpeed = 2.5` is vestigial — nothing reads it.** Reading `kMoveSpeed` alone therefore
  shows nothing for Crag and a wrong 2.5 for Shade; both shipped that way once. The accessor is the
  authority and is called **statically** (no instance) inside `pcall`: these are one-line constant
  returns, and MAC's — which needs `self` — throws and falls back to the constant, its correct base.
- The class is found via `kTechId[techId]` (bidirectional enum) → `_G[name]`. Guarded because names
  collide (`kTechId.Move` vs the `Move` hotkey table).
- **The techId on a button is not always the thing it produces.** The alien drifter button is
  `kTechId.DrifterEgg` (`AlienCommander.lua:565`), and `DrifterEgg` is its own class with no speed,
  so name-derivation found nothing and the button showed none. Vanilla already points that button's
  TechData at `kDrifterHealth`/`kDrifterArmor`, so a resolver aliases speed to `kTechId.Drifter` too.
  **If a value is missing for one button, check whether its techId names the produced unit.**
- **Having a speed is not being able to use it.** A class defining `GetStructureMoveable` has
  conditional movement, and the condition differs by mod, so it cannot be hardcoded: B2TP's Spur
  requires `GetHasTech(self, kTechId.ShiftHive)`, CBM's Spur only `not self.electrified` (no tech
  gate at all), vanilla's Whip only `GetIsUnblocked()`. All need a real entity — `GetHasTech(self,…)`
  cannot even determine the team without one. So the mod **asks live entities on the player's team**
  and lets whichever mod is loaded answer for itself. Any instance reporting moveable counts, so one
  blocked Whip does not blink the figure off. **Do not hardcode a ShiftHive check — it would be
  wrong under CBM.**
- With **no instance** of a gated class the figure is DIMMED, not hidden and not asserted
  (`kUnconfirmedSpeedAlpha`). Hiding was tried first in `d95b41e` and threw the number away exactly
  where it is most wanted, on the build button. Classes with no `GetStructureMoveable` — ARC, MAC,
  Drifter — are unconditional, skip the gate, and never dim.
- **A zero speed means two different things.** The default 0 ("does not move") is hidden, or every
  structure would carry a pointless `0`; a 0 from a *registered resolver* is deliberate and is
  shown. `IT.HasResolver(field, techId)` distinguishes them. This is what puts `0` on ARC Deploy.
- **ARC stance changes armour AND speed**: `kARCArmor = 400` / `kARCDeployedArmor = 0`
  (`BalanceHealth.lua:100-101`), kept as `undeployedArmor`/`deployedArmor` at `ARC.lua:212-213`.
  `kTechId.ARCDeploy` and `kTechId.ARCUndeploy` have **no TechData entries at all**, so the mod
  registers resolvers making each button describe the state it puts the ARC into.
- Those resolvers read the constants **inside** the closure, not at registration: this file loads
  from a post-hook with no guarantee `ARC.lua` or `BalanceHealth.lua` have run yet.

## ARC targeting (researched 2026-08-29, nothing built yet)

Explored improving the feedback between an ARC's range circle and what it can actually hit. Facts,
so they are not re-derived:

- **The range test is point-to-point, against `target:GetOrigin()`** — not model extents, not the
  tech point's square. `ARC.lua:462`. So the hive's visual bulk is irrelevant; only its entity origin
  is measured. `kARCRange = 26`, `kARCMinRange = 7` (`Balance.lua:350-351`).
- **There are TWO different distance metrics**, and they disagree when there is height difference:
  - `GetCanFireAtTargetActual:462` uses `GetLengthXZ()` — horizontal only, auto-acquisition.
  - `ValidateTargetPosition:603` uses `GetLength()` — full 3D.
  - `OnValidateOrder:630` applies **both** for a manual attack order. So a flat ground circle is
    exactly right for auto-acquire but slightly optimistic for a manual order near the edge.
- **No line of sight is required — ARCs fire through walls.** The only `Shared.TraceRay` in the ARC
  code is `ARC_Server.lua:92`, tracing straight down as a ground check. Confirmed by the user.
- **But two non-wall gates still block firing:** `GetIsSighted() or GetIsTargetDetected()`
  (`ARC.lua:459`, team sighting rather than ARC vision), and **Shade Ink** —
  `ValidateTargetPosition:598` refuses outright if enemy Ink clouds are within
  `kShadeInkDisorientRadius` of the target. That is the mechanical basis for Ink deterring ARCs.
- **The 7m minimum range is never drawn.** `kVisualRange` **accepts a table** and every entry gets
  its own circle, for both placement ghosts (`Commander_Client.lua:477-495`) and selected units
  (`536-556`, "draw them all") — the Shift already uses it for echo + energize. So
  `[kVisualRange] = { ARC.kFireRange, ARC.kMinFireRange }` is a one-entry TechData change.
- **The range circles are render decals** using `models/misc/circle/circle.material` and
  `circle_alien.material`, shader `shaders/circle_emissive.surface_shader`. That shader tints by
  `input.color` and declares a settable `hiddenAmount` float (opacity). `material:SetParameter` works
  on decal materials (precedent at `Client.lua:1680`), but **nothing in NS2 calls `SetColor` on a
  decal**, so recolouring likely needs a second `.material` + `.dds` rather than a tint call.

Plan agreed with the user, not implemented: draw the min-range circle, plus a marker at each nearby
target's origin whose prominence encodes the real answer (both distance rules), computed the same way
`OnValidateOrder` does. Rejected: recolouring the big circle (says something is in range, not what)
and highlighting the hive itself (requires overriding a material on an entity we do not own and
undoing it on deselect/death — a leaked highlight would read as a mod bug).

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

> Tag namespaces: `v*` = published and tested; `pending-test/*` = compiles but never run. If a
> `pending-test/*` tag exists, `main` is ahead of the published build — put the test checklist in the
> tag message, and delete the tag once that work ships. None is outstanding right now.

- Version 0.9, tested in game (client and dedicated server) and published. (There is no published
  0.81 — that was the working version number while the stat row was moved and the hourglass redrawn;
  it shipped as 0.85.)
- Published: Steam Workshop item `3790290682`. GitHub: https://github.com/Bleuitup/Bleus-Improved-Tooltips
- `preview.jpg` is the user's own artwork (added 2026-08-26), replacing the generated placeholder.
  `tools/build_preview.ps1`, which produced that placeholder, has been deleted — do not recreate a
  script that writes `preview.jpg`, it would silently clobber real artwork.
  **It must stay 512x512 and stay a JPEG**: Steam rejects other sizes for this item, and
  `mod.settings` names the file by extension, so a `.png` beside it does nothing.
- **Durations are raw seconds, settled with the user after in-game review (2026-08-26).** Do not
  re-propose `M:SS`. `kTimeFormat` keeps the other modes, but `"seconds"` is the decision.
- **The Workshop description was brought current with 0.91** (2026-08-30, `83ec3fa`) — it now covers
  the "In Cooldown" panel, speed and its dimming, health/armour colour matching and ARC stances, and
  no longer claims the mod "sends nothing", which stopped being true in 0.86. When editing it,
  remember Launch Pad must be fully closed and reopened first or it writes its stale copy back, and
  keep `mod.settings` CRLF — it is the one CRLF file in the repo.
- Discussed but not built: ARC range feedback, settled on drawing the 7m minimum-range circle
  (`[kVisualRange] = { ARC.kFireRange, ARC.kMinFireRange }`, since `kVisualRange` accepts a table)
  plus an origin marker on nearby targets whose state encodes both distance rules. See the ARC notes
  below.

## Biomass tech map (0.92)

`AlienTeam:UpdateBioMassLevel` (`ns2/lua/AlienTeam.lua:227`) is the whole bug. It reduces every
hive to one scalar with `if bioMassAdd > progress then progress = bioMassAdd end` — a max — and
then writes it to exactly one node with `local techNodeProgress = i == self.bioMassLevel + 1 and
progress or 0`. Every other biomass node is explicitly zeroed, so two hives researching light one
icon.

Facts established while fixing it, so they do not need re-deriving:

- **`AlienTeam.lua` is server-only.** `Server.lua:22` is its sole loader; the class does not exist
  in the client VM. The fix is therefore a server hook, and reaches clients through vanilla's own
  `TechNodeUpdate` message with no GUI code.
- **Each hive has its own `bioMassLevel`** (1..4 in vanilla, via `ResearchBioMassOne/Two/Three` on
  button slot 2). Team biomass is the sum. `kHiveBiomass = 1` (`Balance.lua:861`).
- **`hive.biomassResearchFraction`** is a plain server field, written only in `Hive:UpdateResearch`
  and only while the researching id is a biomass research, zeroed on complete and on cancel. So
  non-zero means "part way through a biomass research" and `GetResearchingId()` names which.
- **`kBioMassTechIds` in AlienTeam.lua is file-local**, so the mod mirrors it. The index IS the team
  biomass level, so the mirror must stay positional — never close a gap.
- **Node research progress is display-only.** Gating runs off `GetHasTech` / `GetAvailable` /
  `GetResearched`; `researching` is a separate flag that `SetResearchProgress` does not touch.
  `GUIProduction` builds its list from `TeamInfo:GetRelevantTech()` bitmasks, not node progress, so
  filling extra nodes adds no production-queue rows.
- **`TechNode.instances` exists** for per-entity progress, but `GetTechIdIsInstanced`
  (`TechTree.lua:386`) lists only AdvancedArmoryUpgrade, UpgradeRoboticsFactory and the three hive
  type upgrades. Biomass is not instanced, so its node is last-writer-wins.
- **Biomass research times differ**: 25 / 40 / 60 / 80 seconds (`Balance.lua:160-166`), all under
  `kTechDataResearchTimeKey`. Hence ordering by time remaining rather than by fraction — the hive
  furthest along is not necessarily the one that finishes first. Remaining times all count down at
  one second per second, so that ordering is stable and entries never swap icons.
- `SendTechTreeUpdates` builds each message from the node's **current** state and `techNodesChanged`
  is a `unique_set`, so vanilla zeroing a node and the mod re-filling it in the same tick sends one
  message with the final value. No flicker.

Verified against a standalone Lua harness covering the user's case, single-hive, idle, the
divergent-ordering case, three hives, a hive under construction, a dead hive, and overflow past
BioMassTwelve. Nothing has been run in game.

## Hive status HUD (0.93)

`GUIHiveStatus` is the alien panel in the top-left corner, gated on Advanced Options ->
`CHUD_HiveStatus` and registered in `ClientUI.lua`'s `kShowAsClass["Alien"]` -- **field aliens only**,
not the commander and not spectators. Its `TODO` header says using it for the Khamm was never done.

Facts established while building on it:

- **A Hive is NOT relevant to a client across the map.** `ScriptActor` sets
  `SetRelevancyDistance(kMaxRelevancyDistance)` = 40m (`Globals.lua:348`), and `Hive` only adds
  `kRelevantToTeam2Commander`. So `bioMassLevel` and `researchingId`, both real network vars, are
  unreadable on a field alien's client for the hives this panel is about. That is why vanilla feeds
  the panel from `AlienTeamInfo` instead. **Do not "simplify" the mod's network message away.**
- **`AlienTeamInfo` per-location fields are** eggCount, eggInCombat, hiveHealthScalar, hiveMaxHealth,
  hiveBuiltFraction, hiveFlag, hiveInCombat, locationId. No biomass, no research. Its `networkVars`
  are file-local and `Shared.LinkClassToMap` runs at the end of the file, so a post-hook cannot
  extend them without re-linking the class.
- **`locationId` is `Shared.GetStringIndex(locationName)`** (`ScriptActor_Server.lua:180`), an
  integer, NOT an entity id -- `AlienTeamInfo` declaring `location1Id = "entityid"` is vanilla being
  loose. `ScriptActor` initialises it to 0, so 0 is the safe "none" sentinel.
- **Icon indices** (`ui/buildmenu.dds`, 12 columns of 80x80, `index % 12`, `floor(index / 12)`):
  plain biomass ball = 112 (shared by every `BioMassN` **and** `ResearchBioMassTwo`/`Four`), the
  dense cluster = 175 = `ResearchBioMassThree`, the DNA helix = 136 = `LifeFormMenu`. Confirmed by
  extracting and looking at them, not by guessing. The fourth icon is keyed off
  `ResearchBioMassThree` and not `ResearchBioMassFour` -- see the biomass numbering note below.
- **Biomass numbering.** A research is named for how much it has added over the hive's base, not for
  the level it lands on. A hive contributes 1 the moment it is built (`kTechId.Hive` carries
  `kTechDataBioMass = kHiveBiomass`), and `ResearchBioMassOne` / `Two` / `Three` are the +1, +2 and
  +3 on top of that, each granting 1 (`OnResearchComplete` does `bioMassLevel + 1`). So
  `ResearchBioMassThree` takes a hive from 3 to **4**, and a hive maxes at 4. The team cap of 12 is
  three fully upgraded hives -- `AlienTeam` adds 4 to `maxBioMassLevel` per active hive
  (`AlienTeam.lua:301`) and clamps to 12 (`AlienTeam.lua:325`). The user gave this framing on
  2026-08-30; it is the scheme, not a vanilla inconsistency.
- **The world "researching" ring** is `ui/unitstatus_alien.dds` region `{256, 68, 384, 196}`, drawn
  by `GUIUnitStatus` with `SetRotation(Vector(0, 0, -2 * math.pi * t))` over
  `kResearchRotationDuration = 2` seconds. The mod reuses the same region and rate.
- **Alien tech map "researched" colour** is `Color(1, 0.9, 0.4, 1)` --
  `kTechMapIconColors[kAlienTeamType][kTechStatus.Available]` in `GUITechMap.lua:39`.
- **Row geometry** (unscaled, relative to a slot's `background`): row 228x50, location name plate
  141x24 at (-6, -13.2), hive icon 75x72 at (69, 6), hive type 39x36 at (52, 7), eggs 39x36 at
  (24, 30), commander icon 35x32 at (112, 4). The free space is to the right of the name plate and
  below it on the right-hand side, which is where the mod's items go.
- **Slot lifecycle**: `ClearStatusSlot` only hides `slot.background`, so children hide with it;
  `UninitializeStatusSlot` destroys each item explicitly. The mod's items are children of
  `slot.background` and are destroyed in its hook **before** calling the original, since the original
  destroys their parent.

Verified against a standalone Lua harness: appearance, no-change ticks staying silent, biomass
increments, research start, hive death publishing empty once then going quiet, an unbuilt hive
publishing nothing at all, and the join resync replaying published state. Nothing has been run in
game.

### Hive HUD corrections after the first in-game test (0.93)

- **`EvolutionChamber` is where lifeform abilities are researched, not the Hive.** `Hive:OnInitialized`
  creates an `evolutionchamber` entity and calls `SetOwner` on it (`Hive.lua:159`); it has its own
  `ResearchMixin` and its file comment says it "handles the life-form researches for the Hive".
  `Hive:GetIsResearching()` is therefore **false** during Leap, Metabolize, Umbra and everything else
  off the DNA menu, while being true for biomass and hive type upgrades. Reach it through
  `hive:GetEvolutionChamber()`; `evochamberid` starts at -1, so `Shared.GetEntity` gives nil when
  there is none.
- **A GUIItem already rotates about its own centre.** Do NOT set a rotation offset to "make sure".
  `SetRotationOffsetNormalized(Vector(0.5, 0.5, 0))` moves the pivot to the edge and the item visibly
  orbits a point outside itself. `GUIUnitStatus` spins the same ring with no offset at all, which is
  the thing to copy.
- **Verify GUI placement against a rendered mockup before shipping it.** The vanilla textures
  decompress with `utils/nvdecompress.exe` (it takes one argument, the dds, and writes a .tga beside
  it -- no `-format` flag), and the row can be reassembled in PowerShell + System.Drawing from the
  documented positions. Two PowerShell traps doing this: a bare negative literal like `-6` is parsed
  as a parameter name, so wrap it in parentheses; and `[System.Drawing.Image]::FromFile` locks the
  file, so read the bytes and use `FromStream`.
