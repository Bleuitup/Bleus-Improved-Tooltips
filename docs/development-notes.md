# Development notes — Bleu's Improved Tooltips

Feature by feature research and history, moved out of CLAUDE.md on 2026-09-17 so the working notes
stay short. Each section is as it was written at the time, so version labels and "now" refer to
that moment; file names inside may predate the refactor (for example CooldownJoin.lua and
HiveJoin.lua are now ImprovedTooltips_TeamJoin.lua). The rules that must not be broken are repeated
in CLAUDE.md.

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
  re-initializes when `PlayerUI_GetTeamType()` no longer matches what it cached.
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

- **Health and armor come from `ui/{marine,alien}_commander_textures.dds`** at `(0,363)-(48,411)`
  and `(48,363)-(96,411)` — the cells `GUISelectionPanel.lua:54-55` draws when you click a
  structure. They are already colored per team, so **do not tint them**, and they sit in the very
  atlas the tooltip background already loads. 0.86 and earlier drew custom ones after rejecting the
  softer copies in `ui/alien_buymenu.dds`; that was looking at the wrong atlas.
- **Those cells are baked at VANILLA's proportion, and the tooltip magnifies by sampling inward.**
  The glyph is 39px in a 64px cell (~61%, what vanilla uses); the selection panel draws the full
  cell, the tooltip samples a centered 48px window giving 39/48 = 81%, matching the other icons.
  Baking at 81% instead made the tooltips right and blew up vanilla's selection panel — same item
  size, bigger glyph inside it (issue #2). Sampling inward is safe; sampling outward to shrink
  would bleed into neighboring cells.
- **The mod ships resampled copies of vanilla's cross and shield** (atlas cells 3 and 4), rather
  than drawing the vanilla atlas directly. Three reasons, all found in testing: the source glyphs
  occupy only ~29px of a 48px cell so they rendered smaller than the other icons; they top out at
  alpha 233 (149 on the marine atlas) so they looked translucent beside the opaque drawn glyphs; and
  being amber they could not be tinted onto a target color at all, because `SetColor` multiplies
  and can only darken. The baked copies are white and fully opaque, so the tint lands exactly.
  `ImprovedTooltips_SelectionPanel.lua` repoints vanilla's own panel at the same cells - **keep the
  two in step.**
- **Match the figure colors too**, from `GUISelectionPanel.kHealthBarColors` / `kArmorBarColors`
  (`GUISelectionPanel.lua:21-27`): marine health `(0.725, 1, 1)`, marine armor `(0.078, 0.9, 1)`,
  alien health `(1, 197/255, 71/255)`, alien armor `(1, 143/255, 34/255)`. Read at runtime with
  those literals as fallback, so the mod follows anything that changes them.
- **Alien speed uses the Celerity icon**, `kTechIdToMaterialOffset[kTechId.Celerity] = 64` → cell
  (4,5) of `ui/buildmenu.dds`. Grayscale, already points right, and CBM assigns the same index to
  `SpurPassive`.
- **Icon indices in `buildmenu.dds` are `y*12 + x`, 80px cells**, sheet is 960 wide.
- The mod's own sheet is **448x64, seven cells**: hourglass, stopwatch, marine speed chevron,
  health cross, armor shield, ready tick, not-ready cross. `tools/build_icons.ps1` builds it, and
  the cell ORDER is what `kOwnIconCoords` indexes - append, never reorder.
- **The marine chevron is drawn from 1.06** as flat double chevrons with a soft glow (see "1.06
  glyph refresh" at the end of this file). Up to 1.05 it was lifted from
  `marine_buildmenu_insight.dds` row 2 col 4 (x 240-320, y 80-160), mirrored, with luminance as the
  mask because that button plate is opaque and cropped to `(14,10)-(74,70)` to clear the plate's
  bright border. That extraction is gone from the builder; the history is here if it is wanted back.
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
- **ARC stance changes armor AND speed**: `kARCArmor = 400` / `kARCDeployedArmor = 0`
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
  decal**, so recoloring likely needs a second `.material` + `.dds` rather than a tint call.

Plan agreed with the user, not implemented: draw the min-range circle, plus a marker at each nearby
target's origin whose prominence encodes the real answer (both distance rules), computed the same way
`OnValidateOrder` does. Rejected: recoloring the big circle (says something is in range, not what)
and highlighting the hive itself (requires overriding a material on an entity we do not own and
undoing it on deselect/death — a leaked highlight would read as a mod bug).


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
  loose. `ScriptActor` initializes it to 0, so 0 is the safe "none" sentinel.
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
- **Alien tech map "researched" color** is `Color(1, 0.9, 0.4, 1)` --
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
- **A GUIItem already rotates about its own center.** Do NOT set a rotation offset to "make sure".
  `SetRotationOffsetNormalized(Vector(0.5, 0.5, 0))` moves the pivot to the edge and the item visibly
  orbits a point outside itself. `GUIUnitStatus` spins the same ring with no offset at all, which is
  the thing to copy.
- **Verify GUI placement against a rendered mockup before shipping it.** The vanilla textures
  decompress with `utils/nvdecompress.exe` (it takes one argument, the dds, and writes a .tga beside
  it -- no `-format` flag), and the row can be reassembled in PowerShell + System.Drawing from the
  documented positions. Two PowerShell traps doing this: a bare negative literal like `-6` is parsed
  as a parameter name, so wrap it in parentheses; and `[System.Drawing.Image]::FromFile` locks the
  file, so read the bytes and use `FromStream`.


### Supply and biomass icon consistency (0.93)

- **`GUIResourceDisplay` is dead code.** `Commander_Client.lua:404` and `:731` have both its
  `DestroyGUIScriptSingle` and `CreateGUIScriptSingle` calls commented out. It was superseded by the
  `lua/Hud2` top bar. This matters because it used the same worker coords `{280, 363, 320, 411}` for
  supply that `GUICommanderTooltip` still uses -- so after the hud2 migration the tooltip was the
  only surviving place where a MAC or Drifter meant "supply". Do not "fix" GUIResourceDisplay; it
  never runs.
- **Top bar supply icons** live in `ui/hud2/team_info_atlas.dds` (100x250) and are declared in
  `GUIHudSupply.kThemeData`: marine `{50, 100, 100, 150}`, alien `{0, 100, 50, 150}`. Read them from
  that table rather than copying the numbers, so a mod re-theming the top bar re-themes the tooltip
  too. Marine is blue cogs, alien is amber organic nodes -- both already team-colored in the art,
  so they are drawn untinted, exactly like the worker icons they replace.
- **Vanilla draws biomass untinted.** `GUICommanderTooltip` builds its biomass icon from
  `GetTextureCoordinatesForIcon(kTechId.Biomass)` and never calls `SetColor`. `kTechId.Biomass` and
  `kTechId.BioMassOne` are both atlas index 112 (`TechTreeButtons.lua:341`, `:39`), i.e. the same
  grayscale cell. `GUITechMap` is the exception, not the rule: it colors every icon by tech status,
  so its warm yellow means "researched", not "biomass".

### Hive HUD biomass row: researches, not levels (0.93, revised)

The row shows the **researches a hive has completed**, not the biomass it holds, settled with the
user on 2026-08-30. A fresh hive is biomass 1 and shows **nothing** -- deliberately, to match how a
hive shows no type icon until it is upgraded to Crag/Shade/Shift. Icon count is `bioMassLevel - 1`.

Icon `i` is simply `GetTextureCoordinatesForIcon(kTechId.ResearchBioMass<N>)`, in order. That removes
the old "three plain balls plus a denser fourth" special case: the researches are strictly sequential
and their own button art already gets denser as they go (150 = three small spheres, 112 = the plain
ball, 175 = the dense cluster), so the progression is vanilla's, not the mod's.

`ResearchBioMassFour` is listed but never reached in vanilla -- `Hive:GetTechButtons` stops at
`bioMassLevel <= 3` -- and shares cell 112 with `Two`. It is kept so a mod adding the research works
with no change here. The list stops at the first name missing from `kTechId` rather than closing the
gap, because a position in that list IS which research the icon stands for.

## CBM compatibility (1.0 work, 2026-08-30)

Local copy at `G:\My Drive\[01] Martin\[07] Claude Code\CBM 3.5\CBM 3.5 Full`. Read it rather than
guessing; several assumptions about CBM turned out to be wrong.

- **`kCBMaddon = true`** (`Balance.lua:12`) is the switch for CBM's extra content: "AMAC, SPARC, SMG,
  Adv Obs, Adv Gate, Bio 5, and Advanced Structures". The Core Toggle edition is the other folder.
- **CBM's biomass 5 is `ResearchBioMassFour`**, enabled in `Hive:GetTechButtons` behind `kCBMaddon`,
  taking a hive 4 -> 5. It needed **no code**: the hive HUD already lists that research, and CBM
  gives it its own atlas cell (`kTechIdToMaterialOffset[kTechId.ResearchBioMassFour] = 206`, in a
  960x1440 buildmenu.dds -- 18 rows against vanilla's 16). Reading offsets from
  `GetTextureCoordinatesForIcon` rather than hardcoding is what made that free.
- **CBM's advanced upgrades are the "Fortress" structures**: `UpgradeToFortressCrag` / `Whip` /
  `Shade` / `Shift` -> `FortressCrag` etc. The upgrade tech carries only cost and research time; the
  product carries `kTechDataMaxHealth` / `kTechDataMaxArmor` (`kFortressCragHealth = 800`,
  `kFortressCragArmor = 300` in `BalanceHealth.lua`).
- **CBM does NOT color advanced upgrades purple or magenta.** Checked, because the user believed it
  did. Cells 192-195 (Fortress) and 206 (Bio 5) average RGB 103,103,103 and 126,126,126 -- neutral
  grayscale, same as vanilla's art. CBM's purple `Color(0.7, 0.3, 1)` is used only for tech map and
  minimap *connector lines* (`GUITechMap.lua:29`, used at `:194`), and its magenta
  `Color(1, 0.25, 1)` is the Plasma Launcher. `kTechMapIconColors` in CBM is identical to vanilla's.
  **Do not add a purple tint on the belief that CBM has one.**
- **CBM's `AlienTeam:UpdateBioMassLevel` has the identical single-node bug** and an identical
  12-entry `kBioMassTechIds`, so the 0.92 fix works unchanged when post-hooked onto CBM's version.
- **CBM makes structure speed instance-dependent.** `Crag:GetMaxSpeed` returns
  `kMoveSpeed * (0.5 + 0.5 * infestationSpeedCharge / kMaxInfestationCharge)` for a FortressCrag,
  `* 0.5` when electrified and `* 1.25` otherwise; Whip, Shade and Shift do the same. So there is no
  constant to print, and the mod's static class lookup returns the raw `kMoveSpeed` -- which is
  neither the normal speed nor the Fortress range. **Speed is therefore excluded from upgrade-button
  stat inheritance**, and the wider inaccuracy under CBM is a known open issue.

### The CBM compatibility module (1.0 work)

`ImprovedTooltips_CBM.lua` is the **only** mod-specific file, added on the user's explicit call that
CBM is prevalent enough to be worth the exception ("I believe having good CBM integration is
paramount to having the developers whitelist the mod"). Keep it that way: new mod-specific behavior
goes in a module like this, never in the core files.

- **Loaded from the BOTTOM of `ImprovedTooltips_Values.lua`**, not from the file hooks, because it
  needs the registry functions defined above it. It must NOT `Script.Load` Values.lua back -- that is
  a cycle, and it would run with `ImprovedTooltips` still empty.
- **Attaches lazily** through `IT.ApplyCompatModules()`, called from `IT.GetValue` (not `GetValues`,
  so every entry point including a direct API call gets it) and from the hive HUD's `ResolveIcons`.
  Load-time registration would decide "CBM absent" about a mod that had simply not loaded yet.
- **Detects CBM by `kTechId.FortressCrag`**, not by name or version, and gates the biomass 5 tint
  additionally on `kCBMaddon == true` since that flag is what enables the research.
- **Speed multipliers at full infestation charge**, derived from CBM's own `GetMaxSpeed`: 1.25 for a
  plain Crag/Shade/Shift/Whip, 1.0 for FortressCrag/Shade/Shift, 1.25 for FortressWhip (1.75 while
  frenzied, not quoted). The charge climbs +2/s on infestation and drains -1/s off it, so full charge
  IS "on infestation" -- the convention the user chose, mirroring quoting an ARC off infestation.
- **CBM's Whip base speed is a file-local** (`kWhipMoveSpeed = 2.9`) with no class field, which is
  why the mod showed no whip speed at all under CBM. `Whip:OverrideRepositioningSpeed()` returns it
  and touches no instance state, so it can be called statically -- that is how the base is read
  without hardcoding.
- **`IT.RegisterIconColor(techId, color)`** is the public registry the purple goes through. Any mod
  can claim a color for its own tech; the hive HUD asks `IT.GetIconColor(techId)` and falls back to
  its own default.
- The purple used is CBM's **UI** purple `Color(0.7, 0.3, 1, 1)` (its tech map and minimap connector
  lines), not the hive model's. The model's emissive averages a deeper magenta, roughly
  `Color(0.85, 0.25, 0.45)`; swapping `kCBMBiomassFiveColor` is the whole change if that reads
  better.

### Coloring the spectator top bar's biomass counter (1.0 work)

`GUIInsight_TopBar` (spectator view, created by `GUISpectator`) keeps **everything in file-locals**
and stores **not one field on self** -- `background`, `alienBiomass` and the rest are unreachable
from a post-hook, and its local `CreateIconTextItem` returns only the text item, not the icon. There
is no handle to walk down from, so the usual "wrap a method and touch self.x" does not apply.

`ImprovedTooltips_InsightTopBar.lua` catches the item as it is made instead: it wraps
`GUIManager.CreateGraphicItem` for exactly the duration of `Initialize`, collects what is created,
and restores the method -- on the error path too, re-raising afterwards. Lua is single threaded and
`Initialize` is synchronous, so nothing else can be creating items in that window.

Identification is exact, not positional: `"ui/buildmenu.dds"` appears **once** in that file, for the
biomass icon; every other icon on the bar comes from the marine or alien insight sheets. So the one
created item whose `GetTexture()` is the build menu atlas is the biomass icon.

Verified with a harness covering both the normal path and an `Initialize` that raises: the right icon
is tinted, the other four are untouched, and `GUIManager.CreateGraphicItem` is restored either way.

If this ever needs revisiting, check first whether the file has gained a `self.` field -- that would
make all of the above unnecessary.


### Upgrade buttons show differences, not absolutes (1.0 work)

Settled with the user on 2026-08-30 after seeing hive type upgrades report 4000 health -- which is
simply what a Hive already has, and reads as though the upgrade granted it. Buttons now show the
**change**: signed, and a zero difference is omitted entirely, so the hive type upgrades fall silent
again while CBM's Fortress upgrades read `+100` / `+200` / `-0.7`.

- **The source structure is the tech node's first prerequisite.** `AddUpgradeNode(upgrade, prereq1)`
  already carries it -- CBM registers `UpgradeToFortressCrag` with `kTechId.Crag`, vanilla registers
  `UpgradeToCragHive` with `kTechId.Hive` -- and it must be declared for the button to appear at all.
  Nothing is paired up by hand. `TechNode:GetPrereq1()` is the accessor.
- Values may now be **negative or zero**, so `GetValue` returns the delta straight rather than
  through the positive-only path, `GetValues` tests `~= 0` instead of `> 0`, and the renderer formats
  the magnitude and prefixes the sign so `-` and `+` occupy the same space.
- `IT.GetIsUpgradeDelta(techId)` is what tells the renderer to sign. It is per-techId rather than
  per-field because an upgrade carries no stats of its own at all -- every field it shows arrived the
  same way.
- **`GetIsMovementConfirmed` must follow the product.** Asking about the upgrade techId always failed
  (no `UpgradeToFortressShift` class exists), which dimmed every Fortress upgrade's speed as though
  its movement were unconfirmed. It reaches the lookup through `IT.GetUpgradeProductTechId` rather
  than the file-local, since the local is declared further down the file.

### Glyph sizing in build_icons.ps1

The hourglass and stopwatch are drawn from scratch and were 57px tall in the 64px cell. The tooltip
samples their **whole cell**, so they rendered at 57/64 = 89% of the icon, while the vanilla health
and armor glyphs -- baked at 39px and sampled through a centered 48px window -- render at 39/48 =
81%. That 8-point gap is what the user spotted by drawing lines across a screenshot.

`CommitFitted` measures the drawn glyph's alpha bounding box and scales it into a 52px box centered in
the cell (52/64 = 81.25%). Measuring rather than hand-tuning coordinates means the drawing code can
change without the sizes drifting apart again. From 1.06 the hourglass and stopwatch are further scaled
to 88% and 93% after glowing, and the chevron is drawn and glowed at the end of the build; see "1.06
glyph refresh" below.

**`CommitFitted` fits the LONGEST side, so a narrow glyph is narrower than a square one at the same
"52".** The hourglass is 40x52, aspect 0.77, against the cross's square. **Widening it was tried on
2026-09-08 and rejected on sight** - the user called it "entirely stretched horizontally, as if the
aspect ratio was botched". A narrow hourglass is what an hourglass looks like; making it square makes
it wrong, not bigger. An older version of this section recommended widening. It was wrong. Leave the
proportions alone.

**And the sizes already match in game**, which is worth checking before believing a size report.
`kOwnIconCoords` samples health and armor through a centered 48px window of their 64px cell, so their
39px glyph renders at 39/48 = 81%; research, cooldown and speed are sampled over the whole cell and
`CommitFitted` puts them at 52/64 = 81.25%. Comparing raw sheet cells makes the cross look small
because it has not been magnified yet - compare through the real sample windows instead.

### Glyph detail (1.03)

Redrawn to match the artwork in `preview.jpg`, which is more detailed than what shipped.

- **Hourglass.** 1.02 filled the upper bulb solid, which reads as "not started" rather than "time
  passing". The sand is now partial, and it rests **on the neck, not under the cap** -- in a
  half-run hourglass the top bulb is empty above the sand line and full below it, so the fill is the
  LOWER part of that bulb and comes out as a wedge narrowing into the neck. Filling the top band
  instead was tried first and reads as a thick cap. It is clipped as a `Region` intersected with the
  bulb path rather than drawn as a second path, so the sand's edges follow the glass exactly however
  the curve is retuned.
- **Not widened.** Squaring up the aspect was tried and rejected; see the sizing note above.
- **Stopwatch.** 1.02 was a bare ring with a rectangular stem and read as a wall clock. It now has a
  crown (stem plus a wider cap) and a start button on the shoulder at 45 degrees, which is what
  names it as a stopwatch and is the detail the user specifically asked for - it is what a real one
  is started with. The ring's edge at 45 degrees is `(32 + 21*cos45, 38 - 21*sin45)` = `(46.8,
  23.2)`, so the button bar runs outward from just inside that.
- **Hands stay at 12 and 3 o'clock.** Up and up-right was tried to match the preview art and the
  user preferred the original pairing.

**Check any change at tooltip size, not just magnified.** These render at roughly 32px in game, and
detail that reads at 5x can turn to mush. Decompress the built sheet with `utils/nvdecompress.exe`
and draw it at both scales -- note that `System.Drawing` cannot open NS2's TGAs (`FromFile` throws
"Out of memory"), so read the bytes and blit past the 18-byte header yourself.

## SHELVED for 1.0: upgrade stats, speed dimming, CBM speed corrections

Removed on 2026-08-30 at the user's direction. Do not reintroduce any of these without asking.

- **Upgrade buttons showing stats (absolute or incremental).** Both were built and both worked; the
  incremental version showed `+100` / `+200` / `-0.7` on CBM's Fortress upgrades and correctly fell
  silent on vanilla's hive type upgrades. It was shelved because **the tooltip is not wide enough**
  for some structures and the row overflowed. The upgrade tech's own description ("triples HP, moves
  slower") already conveys it. If it is ever revived, the machinery to rebuild is: product from the
  enum name (`UpgradeToX` -> `X`), source from `TechNode:GetPrereq1()`, and values allowed to be
  negative or zero throughout the plumbing and the renderer.
- **Speed dimming** (`kUnconfirmedSpeedAlpha`, `GetIsMovementConfirmed`, `GetIsClassMovementAllowed`).
  It asked the live structures on the team whether movement was possible and faded the figure when
  none could confirm. It caught far more than intended: vanilla's `Whip:GetStructureMoveable` returns
  `GetIsUnblocked()`, a transient rooting check rather than a capability gate, so a Whip faded on its
  own build button before you owned one. One rule genuinely cannot separate that from B2TP's Spur,
  which uses the same hook for a real `GetHasTech(self, kTechId.ShiftHive)` gate. The mod now states
  the plain class speed and never dims.
- **CBM speed corrections.** CBM's Crag, Shade, Shift and Whip compute speed from live infestation
  charge rather than storing a constant, so the plain class lookup is not their real figure — a CBM
  Crag reads 2.9 where it actually moves at 3.625, and a CBM Whip shows nothing at all, since CBM
  keeps its base in a file-local with no class field. **Known and accepted**, tracked as issue #7, per the user:
  "just show the speed attribute of the vanilla unupgraded entity and leave it at that".

What survives of the CBM module is the biomass 5 purple tint and nothing else. The user confirmed
that one in game and explicitly kept it when the rest was rolled back.

## Shine integration (1.02)

**Shine's Lua is not under the server folder.** `NS2 Server/Server/Server/shine` holds configs only.
The readable source of what the server actually runs is its Workshop copy, on this machine
`D:\SteamLibrary\steamapps\workshop\content\4920\117887554`. Read it before assuming anything about
a plugin's messages; searching the server folder finds nothing and looks like Shine is absent.

**Enabling a plugin for local testing** is `BaseConfig.json`, the plugin list around `:36-48`.
`tournamentmode` is now `true` there for the ready-pip work; `BaseConfig.json.bak` holds the
original. `pregameplus` is also true and both want the pre-round, so check the server console for a
conflict line if either stops loading.

**Wrapping a plugin's receiver is safe and late-bound.** Shine's dispatcher does
`self[ FuncName ]( ... )` — a lookup on the plugin table at call time, not a captured reference
(`core/shared/base_plugin/networking.lua:97-102`). So a wrapper installed long after the message was
registered still runs, which is what lets this mod hook Shine with no load-order relationship at
all. Find the plugin with `Shine:IsExtensionEnabled( name )`, which returns `enabled, plugin`.

**A plugin does not necessarily have one canonical message per state change.** Tournament mode
sends three different messages for "a team's readiness changed", picked by situation — see
`docs/tournament-ready-badge.md` for the table. Listening to the obvious one alone missed the most
common case in the game and cost a round of testing. Read the *server* half to see what is actually
sent; the shared half only tells you what exists.

## The spectator top bar is 512 wide on a screen that is not (1.02)

`GUIInsight_TopBar` lays every item out inside a 512-wide centered bar, and vanilla fills it: marine
extractors 50, marine resources 130, center 256, alien resources 317, harvesters 397, biomass 507.
There is no room left inside it. **The space either side of the bar is empty and unused**, and that
is where anything new has to go — the first spectator supply attempt put both counters inside those
512 pixels and they collided with what was already there.

Marine items anchor `GUIItem.Left` from the bar's left edge; everything else anchors `GUIItem.Right`
and is positioned leftward from its right edge, so the two sides' offsets look mirrored.

**To move one of vanilla's existing pairs, move the holder, not the icon.** `CreateIconTextItem`
parents both the icon and its number to a holder; shifting the icon strands the number. Reach the
holder with `icon:GetParent()`, having found the icon by its texture.


## 1.06 glyph refresh (approved 2026-09-15, integrated the same day)

Worked out by the user with ChatGPT Codex and approved ("Love it"); the handoff and its preview
builders live outside the repo in `G:\My Drive\[01] Martin\[07] Claude Code\Glyph Consistency Review\`,
and the decisions are copied into [docs/glyph-refresh.md](docs/glyph-refresh.md).

**Integrated into `tools/build_icons.ps1`** as a step at the end of the build, on
`feature/glyph-refresh`:

- Hourglass and stopwatch: glow at full size, then scaled uniformly to 88% and 93%. Never per axis.
- Marine speed: flat double chevrons, `(18,13)->(28,32)->(18,51)` and `(32,13)->(42,32)->(32,51)` in
  64px coordinates, 5.2px pen, flat caps, round joins, drawn at 4x, then glowed in the cell.
- Glow: `core = 0.4*mask + 0.6*blur(mask, 0.70)`, `halo = blur(mask, 2.5)`,
  `alpha = core + 0.85*halo*(1 - core)`, outer texel ring clear, color white for the runtime tint.
- **Cells 3-6 (health, armor, ready pips) are checked pixel-identical before and after; the build
  throws if not.** Health and armor are the benchmark.

**Verified 2026-09-15:** the unchanged builder reproduced the shipped atlas exactly (0 px), the
updated builder reproduced Codex's approved `candidate-resized-flat-speed.png` exactly (0 px), and the
decoded `source/ui/bleu_tooltip_icons.dds` matches it exactly (0 px).

**Trap in the builder:** `New-Item -LiteralPath` at the top is not a PowerShell 5.1 parameter. It only
runs when `source\ui` is missing, which never happens in the repo, but running a copy of the script
elsewhere fails there first and nvcompress then fails for want of the folder. Create the folder first.

Slides: the Workshop slide review set at `...\Improved Tooltips Images\Workshop Slides 1.05 Review`
shows the old glyphs and needs refreshing for 1.06.

