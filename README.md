# Bleu's Improved Tooltips

An NS2 mod that puts the numbers a commander actually needs into the commander tooltips: research
times, ability cooldowns, and structure health and armour.

The tooltip work is entirely client-side. Two things additionally need the server: the "In Cooldown"
panel, which broadcasts team cooldowns that vanilla never sends to anyone but the commander who
cast, and the biomass tech map fix, which corrects state that only exists in the server VM. Note
this mod has to be installed server-side regardless; see [Servers](#servers).

Version 0.93. Published to the Steam Workshop as
[item 3790290682](https://steamcommunity.com/sharedfiles/filedetails/?id=3790290682).

## What it shows

| Value | Icon | Appears on |
|---|---|---|
| Research time | hourglass | Researches and upgrades — Armour 3, Stomp, Biomass, weapon upgrades |
| Cooldown | stopwatch | Commander abilities — Bone Wall, Power Surge, Nutrient Mist, Rupture, Heal Wave, Cyst |
| Health / Armour | cross / shield | Anything dropped, built or manufactured, both teams |
| Speed | chevrons / celerity | Things that move — ARC, MAC, Drifter, Whip, Shade, Shift |

All of it appears as a single row directly under the tooltip's title, above the description:

```
Armor #3 ( C )                    40 [res]
[hourglass] 120
Gives Marines 60 extra armor
```

The card grows to fit — vanilla already sizes the panel from its content every frame, so the row
only has to declare its height. Vanilla's own top-right icon row (cost / supply / biomass) is left
exactly as it is, so a tooltip with nothing extra to show is pixel-identical to vanilla.

No vanilla tech carries both a research time and a cooldown, so the row is at most three entries
wide. Modded tech that somehow has both will simply show both.

## "In Cooldown" panel

Commander ability cooldowns in NS2 are **team-global**, not per-commander — `Commander.lua:22`
keeps them in `local gTechIdCooldowns = {}` keyed by *team number*, and the server blocks a cast by
checking that team table. Three Shades cannot alternate Ink to keep ARCs suppressed.

Vanilla only surfaces that on the ability's own button, and only for the commander. This panel sits
on the right of the screen for **every player on the team**, listing whatever is currently on
cooldown, using vanilla's own `GUIDial` and per-team cooldown textures so it spins exactly like the
button does, plus the seconds remaining. Shade Ink being down is as useful to a field alien deciding
whether to push as it is to the commander.

Abilities qualify at `kCooldownPanelMinDuration` seconds or more (default 5): Shade Ink 15s,
Nano Shield 10s, Heal Wave 6s. Shorter ones — Rupture 4s, Hallucination Cloud 3s, Nutrient Mist 2s —
are excluded because they would flicker in and out constantly. As everywhere else in this mod the
candidates come from `kTechDataCooldown`, so modded abilities qualify automatically.

### The vanilla bug it depends on

Nobody but the commander who personally cast an ability ever saw its rotating dial - not a commander
who took the chair mid-cooldown, not one who had just left it, and no field player at all.
Enforcement was always correct; only the display was blind.

`gTechIdCooldowns` exists separately in the server VM and in every client VM, and nothing syncs
them. A client's copy is only ever written by the `AbilityResult` message, which the server sends
to the casting commander alone. Vanilla marks the gap itself — `Commander:SetTechCooldown` ends:

```lua
if Server then
    -- send message to commander to sync the cd
end
```

an empty block.

The mod fills it in by keeping **its own** cooldown table client-side, fed by its own message
broadcast to the whole team — on each new cooldown (`SetTechCooldown`) and as a full resync when a
player joins a team (`JoinTeam`). Because that state lives in the mod rather than on the player
entity, it survives the entity being replaced on spawn, death, or leaving the chair, and works for
every class.

Vanilla's `AbilityResult` can't be reused for this: its client handler bails unless
`Client.GetLocalPlayer():GetIsCommander()`, so it can never reach a field player — and it can't be
hooked away either, since `Client.HookNetworkMessage` is handed the function by value at load, so
redefining the global afterwards changes nothing.

The resync recovers start times through the public `GetCooldownFraction` as
`startTime = now - (1 - fraction) * duration`, since `gTechIdCooldowns` itself is file-local and
unreachable. Duration is never sent — the client looks it up from TechData, as vanilla's own handler
does.

A team has at most one commander at a time no matter how many command structures it owns
(`CommandStructure:GetIsPlayerValidForCommander` requires `not team:GetHasCommander()`), so there is
no second-commander case to handle — only the rest of the team.

### Vanilla's own button dial

The mod's table drives the mod's panel. It does not drive vanilla's rotating dial on the commander
button, which reads `gTechIdCooldowns` through `Commander:GetCooldownFraction` — so that dial stayed
blank for a commander who took the chair mid-cooldown even once the panel was correct.

No server involvement is needed to fix it. By the time you sit down, your client has already been
receiving the team broadcast as a field player; the data just isn't anywhere vanilla looks. Becoming
a commander is exactly the moment vanilla's table is empty and the mod's is not, so
`Commander:OnInitialized` replays ours into vanilla's through the public `SetTechCooldown`. The
network handler does the same for live updates while commanding, so the two views cannot drift.

The broadcast and the join resync are server-side; everything else in the cooldown work, including
this dial bridge, is client-side. It needs the server anyway (see [Servers](#servers)).

## Biomass in the tech map

Open the tech map with two hives both researching biomass and only one biomass level lights up. With
two hives at biomass 1 each — team biomass 2, both researching — vanilla shows BioMassThree in
progress and leaves BioMassFour dark, even though it is just as much on its way.

The data is not missing, it is discarded one step before it would have been sent. Every hive tracks
its own `biomassResearchFraction`; `AlienTeam:UpdateBioMassLevel` then collapses all of them into
one scalar and writes it to exactly one node:

```lua
if bioMassAdd > progress then
    progress = bioMassAdd            -- max across every hive
end
...
local techNodeProgress = i == self.bioMassLevel + 1 and progress or 0   -- one node, rest zeroed
```

The mod post-hooks that function and re-spreads the fractions across consecutive nodes, so two hives
researching light two icons and three light three.

This is display only. Nothing gates on node research progress — availability runs off `GetHasTech` /
`GetAvailable` / `GetResearched`, and the per-hive research is driven by `ResearchMixin` against the
`ResearchBioMassN` nodes, which are untouched. Fixing it on the server rather than in the GUI means
it travels out through vanilla's own `TechNodeUpdate` message, so the tech map, spectators and
anything else reading the nodes all agree, with no GUI code involved.

### Which level gets which bar

Entries are sorted by **time remaining, not by fraction**. Biomass researches are not the same
length — 25, 40, 60 and 80 seconds for levels one through four — so the hive that is furthest along
is not necessarily the one that finishes first, and it is the first to finish that takes the team to
the next level. A hive 20% into a 25 second research (20s left) reaches its level before one 50%
into a 60 second research (30s left), so it takes the nearer icon.

Ordering by time is also stable. Every remaining time counts down at one second per second, so two
entries can never swap places; ordering by fraction, a short research overtakes a long one part way
through and the bars trade icons underneath the cursor.

The cost is that bars are no longer monotonic left to right: the nearer level can show a lower bar
than the one past it. That is honest rather than tidy — it is what the underlying researches
actually look like.

A hive still under construction is ordered the same way, off its build time. A hive with no usable
estimate sorts last, rather than having a number invented for it.

With zero or one thing in flight the hook returns immediately, so the common case stays byte-for-byte
vanilla.

## Hive status HUD

The alien hive panel in the top-left corner (Advanced Options → UI → hive status) already shows each
hive's health, egg count and type. Two things are added to each row.

**Biomass** — one icon per biomass level that hive has, beside its location name. A hive is biomass 1
the moment it finishes building and gains one more per research, so the row is a count you can read
without doing arithmetic. The fourth and last uses a denser cluster icon, so a maxed hive is
distinguishable at a glance from one still climbing.

**Researching** — vanilla's rotating "working" ring with the DNA glyph inside it, on any hive that is
researching anything: biomass, a lifeform ability off the DNA menu, or a hive type upgrade. It is the
same pair a player already sees in the world when they look at a busy hive, at the same rotation
speed, so the two read as one indicator rather than two.

Every image is vanilla's own, addressed through `GetTextureCoordinatesForIcon` rather than by pixel,
so a mod that moves an icon in the atlas moves ours with it. Nothing new was drawn.

The vanilla naming is consistent once the scheme is clear: a research is named for how much it has
added over the hive's base, not for the level it lands on. A hive contributes 1 biomass the moment it
is built, and `ResearchBioMassOne` / `Two` / `Three` are the +1, +2 and +3 on top of that — so
`ResearchBioMassThree` is the one that takes a hive to 4, and it carries the denser art. That is also
where the team cap of 12 comes from: three hives, each fully upgraded. `ResearchBioMassFour` shares
the plain ball with every `BioMassN` node, so the fourth icon is keyed off the research that grants
the level rather than off the level itself.

### Why this needs the server

Both numbers are already on the Hive and both are already network vars — `bioMassLevel` in
`Hive.lua`, `researchingId` from `ResearchMixin`. They still cannot simply be read on the client.

A Hive is only relevant to players within `kMaxRelevancyDistance`, 40 metres, plus the team's own
commander (`Hive:SetIncludeRelevancyMask`, `Globals.lua:348`). This panel is shown to field aliens
and its entire purpose is reporting on hives across the map — exactly the case where the client does
not have the entity. That is why vanilla feeds it from `AlienTeamInfo`, a team-wide always-relevant
entity, rather than from the hives.

`AlienTeamInfo` carries eggs, health, built fraction and hive type per location, but not biomass and
not research. Its `networkVars` are file-local and the class is linked by the time a post-hook could
run, so extending them would mean re-linking the whole class — brittle, and it would fight any other
mod doing the same. The mod sends its own message instead, the same approach the cooldown panel
already uses.

Nothing is sent per frame. `AlienTeamInfo:UpdateAllLocationsSlotData` already walks the team's hives
every update; the hook walks the same hives in the same tick, diffs against what was last published,
and sends only what moved. Biomass changes a handful of times a round and research starts and stops,
so this is a few small messages per game. A hive still under construction is biomass 0 with nothing
researching, which is deliberately never published — otherwise it would send the same "nothing" every
tick for the whole build.

Location ids are `Shared.GetStringIndex(locationName)` (`ScriptActor_Server.lua:180`), not entity ids.
`AlienTeamInfo` declares its own as `"entityid"` and gets away with it; the mod's message calls it an
integer, which is what it is.


## Design

**Nothing is registered per tech.** The values already live in `TechData.lua` under keys a tech
cannot function without, so reading the key *is* the detection:

| Value | TechData key | Vanilla entries |
|---|---|---|
| Research time | `kTechDataResearchTimeKey` | 77 |
| Health | `kTechDataMaxHealth` | 81 |
| Armour | `kTechDataMaxArmor` | — |
| Cooldown | `kTechDataCooldown` | 19 |

**Speed is the exception** - it has no TechData key at all. The class is derived the same way:
`kTechId` is bidirectional, so `kTechId[techId]` yields the enum's own name (`"ARC"`, `"MAC"`,
`"Crag"`), and NS2 classes are globals under exactly those names. A modded mover whose techId is
named after its class is picked up with no registration.

Getting the speed off that class is the awkward part, because vanilla is inconsistent: ARC and
Drifter keep it in `kMoveSpeed` with no accessor; MAC and Whip expose `GetMoveSpeed`; Shift uses
`GetMaxSpeed`; **Crag** keeps it under a different name entirely (`Crag.kMaxSpeed`); and **Shade**'s
real speed is the global `kAlienStructureMoveSpeed` (1.73), with `Shade.kMoveSpeed = 2.5` sitting
there vestigially, read by nothing. So the accessor is asked first, statically - they are one-line
constant returns, and the one that needs a real instance (MAC) throws and falls back to the constant,
which is its correct base value anyway.

**Having a speed is not the same as being able to use it.** A class defining `GetStructureMoveable`
has conditional movement, and the condition is not the same between mods — B2TP's Spur requires a
Shift Hive, CBM's Spur only requires not being electrified, vanilla's Whip only requires not being
blocked. All three need a real entity to answer. So rather than encode any mod's rule, the mod asks
the entities actually on your team and lets whichever mod is loaded answer for itself. Any instance
reporting moveable counts, so one blocked Whip does not blink the figure off. With no instance at
all there is nothing to ask, so the figure is drawn dimmed - stating the speed without claiming it
is usable yet. Unconditional movers (ARC, MAC, Drifter) skip the check entirely and never dim.

### Icons

Only the hourglass and stopwatch are drawn from scratch. Everything else is vanilla art:

| Icon | Source |
|---|---|
| Speed (alien) | Celerity, index 64 in `ui/buildmenu.dds`, used straight from vanilla — CBM assigns the same index to `SpurPassive` |
| Health, armour | Vanilla's selection-panel cross and shield, **resampled** into `ui/bleu_tooltip_icons.dds` |
| Marine speed | `marine_buildmenu_insight.dds` row 2 col 4, mirrored to point right and lifted off its button plate |
| Hourglass, stopwatch | Drawn in `tools/build_icons.ps1` |

Health and armour are resampled rather than drawn from the vanilla atlas at runtime for three
reasons: the source glyphs fill only ~29px of a 48px cell, so at icon size they came out smaller
than everything beside them; they top out at alpha 233, so they looked translucent next to the
opaque ones; and being amber they could not be tinted onto a target colour at all, since `SetColor`
multiplies and can only darken. The baked copies are white and fully opaque, so the tint lands
exactly. Vanilla's own selection panel is repointed at the same glyphs, keeping its own size.

The figures are coloured from `GUISelectionPanel.kHealthBarColors` / `kArmorBarColors`, read at
runtime — marine health pale cyan, marine armour deep teal, alien health yellow, alien armour darker
orange — and the icons take the same colour, so a number means the same thing wherever you read it.

### ARC stances

An ARC is a different unit depending on its stance — `kARCArmor = 400` undeployed against
`kARCDeployedArmor = 0`, and it cannot move once deployed. `kTechId.ARC` already carries the
undeployed values, but the two stance buttons carry no TechData at all, which leaves them free to
describe the state they put the ARC *into*. So the Deploy button reads `0` armour and no speed,
making the cost of deploying visible while you are choosing it.

A mod that adds tech has to populate these for the tech to work at all, so CBM's Advanced Shade,
CompMod's Charge and B2TP's MedTech get improved tooltips without this mod knowing they exist.

**Live values where they differ from the stored ones.** Bone Wall's real health is computed at
spawn from the team's biomass level (`BoneWall:OnInitialized`), not stored in TechData — at
Biomass 9 the stored value of 100 is off by 800. The tooltip mirrors that calculation and tracks
biomass as the round goes on.

### Extending it from another mod

Register a resolver for anything your mod computes at runtime rather than storing in TechData:

```lua
-- health, armor, researchTime, cooldown
ImprovedTooltips.RegisterResolver("health", kTechId.MyAbility, function(techId)
    return kMyBaseHealth + GetSomeLiveMultiplier()
end)

-- Or hide a field whose stored value would mislead a commander:
ImprovedTooltips.SuppressField("cooldown", kTechId.MyPassiveThing)
```

Resolvers are called every frame the tooltip is visible, so keep them cheap. Return `0` or `nil`
to hide the field. `ImprovedTooltips.GetTechCategory(techId)` returns `"tech"`, `"structure"`,
`"cast"` or `"none"`, derived from the tech tree's own `techType` — useful for writing suppression
rules without a hand-maintained list.

Guard your registration so it does not run before this mod loads:

```lua
if ImprovedTooltips then
    ImprovedTooltips.RegisterResolver(...)
end
```

## How it hooks in

Two post-hooks cover every commander tooltip in the game, because vanilla funnels all four
consumers — `GUICommanderButtons`, `GUITechMap`, `GUIBioMassDisplay`, `GUICommanderHelpWidget` —
through one pair of functions:

| Hook target | Our file | What it does |
|---|---|---|
| `lua/Player_Client.lua` | `ImprovedTooltips_TooltipData.lua` | Wraps `PlayerUI_GetTooltipDataFromTechId`, attaching the extra values |
| `lua/GUICommanderTooltip.lua` | `ImprovedTooltips_TooltipGUI.lua` | Wraps `Initialize` / `UpdateData` / `CalculateTotalTextHeight` / `Update` to create the row, place it under the title, and shift the description blocks down to make room |
| `lua/GUIHiveStatus.lua` | `ImprovedTooltips_HiveStatusGUI.lua` | **Client only.** Wraps `CreateStatusContainer` / `UpdateStatusSlot` / `UninitializeStatusSlot` to add biomass icons and a researching ring to each hive row |
| `lua/ClientUI.lua` | `ImprovedTooltips_ClientUI.lua` | Registers the "In Cooldown" panel for `Player`, so the whole team sees it |
| `lua/GUISelectionPanel.lua` | `ImprovedTooltips_SelectionPanel.lua` | Tints vanilla's own health/armour icons to match their figures |
| `lua/Commander.lua` | `ImprovedTooltips_CooldownDial.lua` | **Client only.** Wraps `OnInitialized` to replay synced cooldowns into vanilla's own table, fixing vanilla's button dial |
| `lua/NetworkMessages.lua` | `ImprovedTooltips_NetworkMessages.lua` | Registers the mod's cooldown and hive-state messages in every VM |
| `lua/Commander.lua` | `ImprovedTooltips_CooldownSync.lua` | **Server only.** Wraps `SetTechCooldown` to broadcast a new cooldown to the team |
| `lua/NS2Gamerules.lua` | `ImprovedTooltips_CooldownJoin.lua` | **Server only.** Wraps `JoinTeam` to hand a joining player the current cooldowns |
| `lua/AlienTeam.lua` | `ImprovedTooltips_BiomassProgress.lua` | **Server only.** Wraps `UpdateBioMassLevel` to spread in-progress biomass across every level being worked on |
| `lua/AlienTeamInfo.lua` | `ImprovedTooltips_HiveSync.lua` | **Server only.** Wraps `UpdateAllLocationsSlotData` to publish per-hive biomass and research to the team |
| `lua/NS2Gamerules.lua` | `ImprovedTooltips_HiveJoin.lua` | **Server only.** Wraps `JoinTeam` to hand a joining player the current hive state |

Post-hooks rather than file replacements, so the mod stacks with anything that ships its own copy
of either file — CBM, for instance, replaces `Player_Client.lua` wholesale. Entry `Priority` is
deliberately low (5); ModLoader sorts entries by *descending* priority and appends post-hooks in
that order, so a low number means these hooks run last and wrap whatever else loaded.

## Layout

`source/` is the tree Launch Pad builds from; `output/` is generated and git-ignored.

```
source/lua/entry/ImprovedTooltips.entry     mod entry, points at the FileHooks file
source/lua/ImprovedTooltips/
    ImprovedTooltips_FileHooks.lua          registers the post-hooks
    ImprovedTooltips_Config.lua             display options (time format, tints, panel, tech map)
    ImprovedTooltips_Values.lua             value resolution + the resolver registry
    ImprovedTooltips_TooltipData.lua        post-hook on Player_Client.lua       (client)
    ImprovedTooltips_TooltipGUI.lua         post-hook on GUICommanderTooltip.lua (client)
    ImprovedTooltips_ClientUI.lua           post-hook on ClientUI.lua            (client)
    ImprovedTooltips_SelectionPanel.lua     post-hook on GUISelectionPanel.lua   (client)
    ImprovedTooltips_CooldownDial.lua       post-hook on Commander.lua           (client)
    ImprovedTooltips_HiveStatusGUI.lua      post-hook on GUIHiveStatus.lua       (client)
    ImprovedTooltips_NetworkMessages.lua    post-hook on NetworkMessages.lua     (shared)
    ImprovedTooltips_CooldownState.lua      team cooldown table + server publish
    ImprovedTooltips_CooldownSync.lua       post-hook on Commander.lua           (server)
    ImprovedTooltips_CooldownJoin.lua       post-hook on NS2Gamerules.lua        (server)
    ImprovedTooltips_BiomassProgress.lua    post-hook on AlienTeam.lua           (server)
    ImprovedTooltips_HiveState.lua          per-hive biomass + research + server publish
    ImprovedTooltips_HiveSync.lua           post-hook on AlienTeamInfo.lua       (server)
    ImprovedTooltips_HiveJoin.lua           post-hook on NS2Gamerules.lua        (server)
    GUIImprovedTooltipsCooldowns.lua        the "In Cooldown" panel
source/ui/bleu_tooltip_icons.dds            320x64 icon sheet, 5 cells of 64x64
tools/build_icons.ps1                       regenerates the icon sheet
preview.jpg                                 Workshop preview, 512x512
mod.settings                                Launch Pad project settings
```

The repo root doubles as the NS2 Launch Pad project — `mod.settings`, `preview.jpg` and `output/`
are all Launch Pad needs, so it can be opened and published directly from here.

`preview.jpg` **must stay 512x512 and must stay a JPEG**; Steam rejects other sizes for this item,
and `mod.settings` names the file by extension.

## Config

`ImprovedTooltips_Config.lua`:

- `kTimeFormat` — `"seconds"` (default, `90`), `"suffix"` (`90s`) or `"clock"` (`1:30`)
- `kShowZeroArmor` — show an explicit `0` for armourless structures rather than hiding the icon
- `kShowSpeed` — show movement speed for things that move
- `kUnconfirmedSpeedAlpha` — opacity of a speed figure whose mobility cannot be confirmed (default 0.45; set to 1 to disable dimming)
- `kTintSelectionPanelIcons` — also tint the icons on vanilla's selection panel to match
- `kMarineIconColor` / `kAlienIconColor` — per-team tint, applied to the mod's own icons only
  (vanilla's health and armour art is already team-coloured and is left alone)
- `kShowCooldownPanel` — turn the "In Cooldown" panel off entirely
- `kCooldownPanelMinDuration` — minimum cooldown, in seconds, to earn a panel entry (default 5)
- `kCooldownPanelOffset` — panel position, offset from the right edge / vertical middle
- `kCooldownPanelShowSeconds` — show the remaining seconds under each icon
- `kSpreadBiomassProgress` — show every biomass level in progress on the tech map, not just the next
  one. Server-side, like the two hive HUD toggles below; false restores vanilla exactly
- `kShowHiveBiomassIcons` — biomass icons beside each hive name on the hive status HUD
- `kShowHiveResearchIcon` — the rotating ring and DNA glyph on a hive that is researching
- `kHiveBiomassIconOrigin` / `kHiveBiomassIconSize` / `kHiveBiomassIconSpacing` — placement of that row
- `kHiveResearchIconPosition` / `kHiveResearchIconSize` / `kHiveResearchDnaScale` — placement of the ring
- `kHiveBiomassIconColor` / `kHiveResearchRingColor` / `kHiveResearchDnaColor` — their tints
- `kHiveResearchRotationDuration` — seconds per turn, matching the ring on the hive itself

## Building the assets

```powershell
.\tools\build_icons.ps1
```

Regenerates `source/ui/bleu_tooltip_icons.dds` from vector drawing code and compresses it with
`nvcompress.exe` from the game's `utils/` folder. Pass `-NS2 <path>` if the game is not at the
default install path. Output is uncompressed RGBA rather than DXT — the sheet is tiny and DXT
block artefacts are very visible on hard-edged white glyphs.

## Servers

The mod reads only client-side state and sends nothing, so it needs no server logic. It still has
to be installed on the server, because of NS2's consistency check rather than anything this mod
does:

- `ns2/lua/ServerConfig.lua` defaults `consistency_enabled = true` and
  `use_own_consistency_config = false`, so a stock server uses the built-in config.
- That config (`core/lua/ConsistencyConfig.lua`) sets `restrict = { "lua/entry/*.entry" }`, fed to
  `Server.AddRestrictedFileHashes`. Entry files are how a mod declares itself, so this is the hook
  UWE uses to control which mods a client may load — note the `ignore` list carves out specific
  cosmetic files (`ui/crosshairs.dds`, hitsound banks) precisely so *those* client mods work.

A client carrying `lua/entry/ImprovedTooltips.entry` that the server does not have is therefore
expected to fail the check. Admins should add the mod to the server's mod list, or whitelist it.

The Workshop item is tagged `Must be run on Server` for this reason.

> The exact engine behaviour of `Server.AddRestrictedFileHashes` is not readable from Lua, so this
> is read off the config and NS2's server defaults rather than measured. If it turns out a stock
> server does accept it, the tag and this section should be revisited.

## Known limitations

- **Alien structure maturity is not shown.** A Whip goes 560 → 720 health as it matures, but the
  mature values are constructor arguments in `AlienStructure.lua` subclasses rather than TechData,
  so there is no generic way to read them. Only the drop-time value is shown.

## Changelog

**Unreleased**
- **Biomass on the hive status HUD.** Each hive in the top-left panel now shows one icon per biomass
  level it has, beside its location name. The fourth uses the denser cluster art off the research
  button that grants it, so a maxed hive reads differently from one still climbing.
- **A researching indicator on the same panel.** Vanilla's rotating ring plus the DNA glyph appear on
  any hive researching anything - biomass, a lifeform ability, or a hive type upgrade - at the same
  rotation speed as the ring the player sees on the hive itself.
- Both are drawn entirely from vanilla art, addressed by techId rather than by pixel. Neither number
  is readable on the client, because a Hive is only relevant within 40m and this panel is about hives
  across the map, so the mod publishes them the same way it publishes cooldowns.

**0.92**
- **Every biomass level in progress now shows on the tech map.** With two hives researching biomass
  at once, vanilla lit up one icon between them: `AlienTeam:UpdateBioMassLevel` takes the maximum
  fraction across all hives and writes it to a single node, zeroing the rest. Two hives now light two
  icons, three light three.
- Entries are ordered by time remaining rather than by fraction, because biomass researches run 25,
  40, 60 and 80 seconds and the hive furthest along is not necessarily the one that finishes first.

**0.91**
- Fixed the health and armour glyphs being oversized on vanilla's selection panel. They are now
  baked at vanilla's own proportion, with the tooltips magnifying by sampling a smaller window.
- Speed is now **dimmed**, rather than stated as fact, for structures whose movement is conditional
  and cannot currently be confirmed. B2TP's Spur needs a Shift Hive, CBM's Spur does not — the mod
  asks the entities on your team and lets whichever mod is loaded answer, rather than encoding
  either rule. Dimming rather than hiding keeps the number on the build button, where you are
  deciding whether to build the thing in the first place.

**0.9**
- **Movement speed** added for things that move: ARC 2.0, Shade 1.73, Crag 2.9, Shift 2.9, Whip 3.5,
  MAC 6, Drifter 11.
- **ARC stances.** The Deploy and Undeploy buttons now describe the state they put the ARC into, so
  Deploy shows armour dropping to 0 and speed to 0 — the cost of deploying, visible while choosing.
- **Health and armour icons replaced with vanilla's own** cross and shield, resampled into the mod's
  sheet so they match the other icons in size and are fully opaque. The mod's earlier hand-drawn
  pair is gone.
- **Colour.** Figures and icons both take vanilla's selection-panel colours — marine health pale
  cyan, marine armour deep teal, alien health yellow, alien armour darker orange — so a number means
  the same thing wherever it is read. Vanilla's own selection panel is brought in line too.
- **Cooldown panel** entries now sit on the game's build-menu button plate rather than one flat
  rectangle behind the whole panel, removing the hard-edged box on both teams.
- Fixed Crag showing no speed and Shade showing a wrong one: Crag stores its speed under a different
  constant name, and Shade's real speed is a global, `Shade.kMoveSpeed` being vestigial.
- Fixed the Drifter button showing no speed: it is `kTechId.DrifterEgg`, a class with no speed of its
  own, so speed is aliased to the Drifter it hatches — as vanilla already does for its health.

**0.86**
- Added the "In Cooldown" panel — a titled panel on the right of the screen listing team abilities
  currently on cooldown, with vanilla's rotating dial and the seconds left. Both teams; abilities
  qualify at 5s or more by default.
- Visible to **every player on the team**, not just the commander, and it persists when a commander
  leaves the chair. This needed the mod to keep its own synced cooldown table: vanilla's lives only
  on the casting commander's client, so field players had no data at all.
- Fixed the underlying vanilla bug — nobody but the commander who personally cast an ability ever
  saw its dial. Enforcement was always correct; only the display was blind.
- Vanilla's own rotating dial on the commander button is fixed too, not just the new panel: taking
  the chair mid-cooldown now shows the ability as blocked on its own button.
- Removed a hard-edged backing rectangle that showed through the alien panel's smoke.
- The mod gains its first server-side code as a result. It already had to be installed server-side.

**0.85**
- Moved research time and cooldown out of vanilla's top-right icon row and into a single stat row
  under the title, alongside health and armour. In 0.8 each extra icon in the top row pushed it
  further left, and with a long title it collided with the title text.
- Dropped 0.8's repacking of vanilla's own cost / supply / biomass icons — no longer needed, and it
  means tooltips with no extra data now render exactly as vanilla does.
- Redrew the hourglass. The 0.8 version was a flat bowtie of two bars and two triangles; it now has
  rounded caps, concave glass, and sand falling from a full upper bulb into a mound below.

**0.8** — first published build.
