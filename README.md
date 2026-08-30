# Bleu's Improved Tooltips

An NS2 mod that puts the numbers a commander actually needs into the commander tooltips: research
times, ability cooldowns, and structure health and armour.

The tooltip work is entirely client-side. The "In Cooldown" panel additionally needs the server,
which broadcasts team cooldowns that vanilla never sends to anyone but the commander who cast. Note
this mod has to be installed server-side regardless; see [Servers](#servers).

Version 0.9. Published to the Steam Workshop as
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

The broadcast and the join resync are the mod's only server-side code; everything else, including
this dial bridge, is client-side. It needs the server anyway (see [Servers](#servers)).

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
all, speed is hidden rather than guessed; unconditional movers (ARC, MAC, Drifter) skip the check
entirely.

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
| `lua/ClientUI.lua` | `ImprovedTooltips_ClientUI.lua` | Registers the "In Cooldown" panel for `Player`, so the whole team sees it |
| `lua/GUISelectionPanel.lua` | `ImprovedTooltips_SelectionPanel.lua` | Tints vanilla's own health/armour icons to match their figures |
| `lua/Commander.lua` | `ImprovedTooltips_CooldownDial.lua` | **Client only.** Wraps `OnInitialized` to replay synced cooldowns into vanilla's own table, fixing vanilla's button dial |
| `lua/NetworkMessages.lua` | `ImprovedTooltips_NetworkMessages.lua` | Registers the mod's team-cooldown message in every VM |
| `lua/Commander.lua` | `ImprovedTooltips_CooldownSync.lua` | **Server only.** Wraps `SetTechCooldown` to broadcast a new cooldown to the team |
| `lua/NS2Gamerules.lua` | `ImprovedTooltips_CooldownJoin.lua` | **Server only.** Wraps `JoinTeam` to hand a joining player the current cooldowns |

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
    ImprovedTooltips_Config.lua             display options (time format, tints, panel)
    ImprovedTooltips_Values.lua             value resolution + the resolver registry
    ImprovedTooltips_TooltipData.lua        post-hook on Player_Client.lua       (client)
    ImprovedTooltips_TooltipGUI.lua         post-hook on GUICommanderTooltip.lua (client)
    ImprovedTooltips_ClientUI.lua           post-hook on ClientUI.lua            (client)
    ImprovedTooltips_SelectionPanel.lua     post-hook on GUISelectionPanel.lua   (client)
    ImprovedTooltips_CooldownDial.lua       post-hook on Commander.lua           (client)
    ImprovedTooltips_NetworkMessages.lua    post-hook on NetworkMessages.lua     (shared)
    ImprovedTooltips_CooldownState.lua      team cooldown table + server publish
    ImprovedTooltips_CooldownSync.lua       post-hook on Commander.lua           (server)
    ImprovedTooltips_CooldownJoin.lua       post-hook on NS2Gamerules.lua        (server)
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
- `kTintSelectionPanelIcons` — also tint the icons on vanilla's selection panel to match
- `kMarineIconColor` / `kAlienIconColor` — per-team tint, applied to the mod's own icons only
  (vanilla's health and armour art is already team-coloured and is left alone)
- `kShowCooldownPanel` — turn the "In Cooldown" panel off entirely
- `kCooldownPanelMinDuration` — minimum cooldown, in seconds, to earn a panel entry (default 5)
- `kCooldownPanelOffset` — panel position, offset from the right edge / vertical middle
- `kCooldownPanelShowSeconds` — show the remaining seconds under each icon

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
- Fixed the health and armour glyphs being oversized on vanilla's selection panel. They are now
  baked at vanilla's own proportion, with the tooltips magnifying by sampling a smaller window.
- Speed is now hidden for structures whose movement is conditional until an entity on your team
  actually reports it can move. B2TP's Spur needs a Shift Hive, CBM's Spur does not - the mod asks
  the loaded mod rather than encoding either rule.

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
