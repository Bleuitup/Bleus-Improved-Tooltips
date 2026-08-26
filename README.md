# Bleu's Improved Tooltips

An NS2 mod that puts the numbers a commander actually needs into the commander tooltips: research
times, ability cooldowns, and structure health and armour.

All the work happens client-side — every value is already on the client and nothing is sent
anywhere — but that does **not** mean it runs on any server; see [Servers](#servers).

Version 0.85. Published to the Steam Workshop as
[item 3790290682](https://steamcommunity.com/sharedfiles/filedetails/?id=3790290682).

## What it shows

| Value | Icon | Appears on |
|---|---|---|
| Research time | hourglass | Researches and upgrades — Armour 3, Stomp, Biomass, weapon upgrades |
| Cooldown | stopwatch | Commander abilities — Bone Wall, Power Surge, Nutrient Mist, Rupture, Heal Wave, Cyst |
| Health / Armour | cross / shield | Anything dropped, built or manufactured, both teams |

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

Vanilla only surfaces that on the ability's own button, so a panel on the right of the commander's
screen lists whatever is currently on cooldown, using vanilla's own `GUIDial` and per-team cooldown
textures so it spins exactly like the button does, plus the seconds remaining.

Abilities qualify at `kCooldownPanelMinDuration` seconds or more (default 5): Shade Ink 15s,
Nano Shield 10s, Heal Wave 6s. Shorter ones — Rupture 4s, Hallucination Cloud 3s, Nutrient Mist 2s —
are excluded because they would flicker in and out constantly. As everywhere else in this mod the
candidates come from `kTechDataCooldown`, so modded abilities qualify automatically.

### The vanilla bug it depends on

A commander who takes the chair while a team ability is on cooldown never saw the rotating dial.
Enforcement was always correct — only the display was blind.

`gTechIdCooldowns` exists separately in the server VM and in every client VM, and nothing syncs
them. A client's copy is only ever written by the `AbilityResult` message, which the server sends
to the casting commander alone. Vanilla marks the gap itself — `Commander:SetTechCooldown` ends:

```lua
if Server then
    -- send message to commander to sync the cd
end
```

an empty block. `ImprovedTooltips_CooldownSync.lua` fills it in, replaying the team's live cooldowns
to a commander on their first move tick after taking the chair. It reuses vanilla's own
`AbilityResult` message rather than adding one, and recovers the original start time through the
public `GetCooldownFraction` as `castTime = now - (1 - fraction) * duration`, since
`gTechIdCooldowns` itself is file-local. Fixing this also makes the vanilla button dial work.

Only the login case needs handling: a team can have at most one commander at a time no matter how
many command structures it owns (`CommandStructure:GetIsPlayerValidForCommander` requires
`not team:GetHasCommander()`), so there is never a second seated commander to forward a cooldown to.
Every path that starts a cooldown already messages the one commander there is — the normal cast, and
`Drifter.lua:525` for drifter-delivered clouds.

This is the mod's only server-side code. It needs the server anyway (see [Servers](#servers)).

## Design

**Nothing is registered per tech.** The values already live in `TechData.lua` under keys a tech
cannot function without, so reading the key *is* the detection:

| Value | TechData key | Vanilla entries |
|---|---|---|
| Research time | `kTechDataResearchTimeKey` | 77 |
| Health | `kTechDataMaxHealth` | 81 |
| Armour | `kTechDataMaxArmor` | — |
| Cooldown | `kTechDataCooldown` | 19 |

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
| `lua/ClientUI.lua` | `ImprovedTooltips_ClientUI.lua` | Registers the "In Cooldown" panel for both commander classes |
| `lua/Commander.lua` | `ImprovedTooltips_CooldownSync.lua` | **Server only.** Wraps `OnProcessMove` to replay the team's live cooldowns to a commander on taking the chair |

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
    ImprovedTooltips_CooldownSync.lua       post-hook on Commander.lua           (server)
    GUIImprovedTooltipsCooldowns.lua        the "In Cooldown" panel
source/ui/bleu_tooltip_icons.dds            256x64 icon sheet, 4 cells of 64x64
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
- `kMarineIconColor` / `kAlienIconColor` — per-team tint applied to the white icon sheet
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
- Added the "In Cooldown" panel — a titled panel on the right of the commander's screen listing
  team abilities currently on cooldown, with vanilla's rotating dial and the seconds left. Both
  teams; abilities qualify at 5s or more by default.
- Fixed the vanilla bug where a commander who took the chair while a team ability was on cooldown
  never saw its dial. Server enforcement was always correct; only the display was blind. This also
  repairs the vanilla button dial, not just the new panel.
- The mod gains its first server-side file as a result. It already had to be installed server-side.

**0.85**
- Moved research time and cooldown out of vanilla's top-right icon row and into a single stat row
  under the title, alongside health and armour. In 0.8 each extra icon in the top row pushed it
  further left, and with a long title it collided with the title text.
- Dropped 0.8's repacking of vanilla's own cost / supply / biomass icons — no longer needed, and it
  means tooltips with no extra data now render exactly as vanilla does.
- Redrew the hourglass. The 0.8 version was a flat bowtie of two bars and two triangles; it now has
  rounded caps, concave glass, and sand falling from a full upper bulb into a mound below.

**0.8** — first published build.
