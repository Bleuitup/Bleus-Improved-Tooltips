# Bleu's Improved Tooltips

An NS2 mod of small additions that help commanders, players and spectators read the game: a welder
icon on nameplates, commander hotkey labels, nutrient mist indicators, an alien shield bar for the
Centralized HUD bars, tech maps for spectators, and ready labels on the scoreboard under Shine's
tournament mode.

It started as research time, cooldowns, health and armor on the commander tooltips, and grew from
there. **Build 345 made most of that part of NS2 itself** (see [Gone vanilla](#gone-vanilla)), and
1.2 removed everything the game now does on its own. The name stayed.

Almost all of it runs on the client. The one server part is the spectator tech maps, which need a
team's tech tree sent to the spectators who ask for it. The mod has to be installed server-side
regardless; see [Servers](#servers).

Version 1.21, for build 345. Published to the Steam Workshop as
[item 3790290682](https://steamcommunity.com/sharedfiles/filedetails/?id=3790290682).

## What it adds

| Feature | Who sees it | Setting | Design notes |
|---|---|---|---|
| Welder icon right of a marine teammate's name | Marine commander; marines while that nameplate shows | WELDER ICON ON NAMEPLATES, on | `docs/welder-nameplate-icon.md` |
| Each commander button's hotkey in its corner, from your own bindings | Both commanders | HOTKEY LABELS ON COMMANDER BUTTONS, off | `docs/commander-hotkey-labels.md` |
| Nutrient mist badge over every alien entity the mist is helping (lifeform eggs, anything still growing, disconnected cysts) | Alien commander | none, always on | `docs/nutrient-mist-indicators.md` |
| Nutrient mist entry in the HUD status row while evolving in a misted egg | The player in the egg | none, always on | `docs/nutrient-mist-indicators.md` |
| Mucous, vampirism and babbler shields as one segmented bar beside the Centralized health bar, with their total underneath; full = the lifeform's most shield at biomass 1 | Aliens with Centralized HUD bars | SHIELD BAR, on | `docs/alien-shield-bar.md` |
| Tech maps for neutral spectators: hold the tech map key, 1 or 2 for marines or aliens | Spectators | none; stands down under NSL Mod | `docs/spectator-tech-maps.md` |
| Ready / Not Ready on each team's scoreboard header under Shine's tournament mode | Everyone | none; inert without the plugin | `docs/tournament-ready-label.md` |

Settings live under Options > Mods > Bleu's Improved Tooltips.

## Gone vanilla

Ported into the base game in build 345 and removed from the mod in 1.2. Most are switches under
Options > Advanced. The design notes under `docs/` are kept as the record of how each was worked out.

| Was in the mod | In build 345 |
|---|---|
| Research time, cooldown, health, armor and speed on commander tooltips, Bone Wall's live health, ARC deployed stats | `GUICommanderTooltip`, with its own `ui/commander_stat_icons.dds`; RESEARCH TIME TOOLTIP |
| Selection panel health and armor icons tinted to their figures | `GUISelectionPanel` |
| Supply on tooltips marked with the top bar's icon | `GUICommanderTooltip` |
| "In Cooldown" panel for the whole team, minimum duration setting | TEAM COOLDOWNS (`GUITeamCooldowns`, fixed 5 s minimum) |
| Cooldown sync, the commander's button dial fix, cooldowns handed to joining players and spectators | `Commander:SetTechCooldown`, `SendTeamTechCooldowns` |
| Biomass icons and research in each hive's row, HIVE RESEARCH DISPLAY | `GUIHiveStatus`, HIVE RESEARCH PROGRESS |
| The busy-hive ring in NOTIFICATIONS mode | Not ported; dropped with the rest |
| Every biomass level in progress lit on the tech map | `AlienTeam:UpdateBioMassLevel` |
| Bead fills and ability progress meters on the biomass bar | `GUIBioMassDisplay` |
| Hive research kept off the notification stack, and its completion sound | `GUIEvent` |
| Spectator top bar supply, and its colored biomass counter | `GUIInsight_TopBar` |
| Lost arms lab upgrades kept on the marine HUD in red | `GUIMarineHUD` |
| Marine blips colored by weapon, custom weapon colors | COLOR MARINE BLIPS BY WEAPON, CUSTOM WEAPON COLORS |
| Phase gate arrows on the commander and spectator corner minimap | `GUIMinimapConnection`, PHASE GATE LINES |
| Exo weapon bars beside the crosshair | EXO WEAPON BARS (`GUIExoWeaponBars`) |
| CBM compatibility (biomass 5 tint, SMG map color) | Moot: build 345 replaces CBM |

Tag `v1.12` is the last published code that holds all of these.

## How it hooks in

Every hook is a post-hook, so the mod stacks with anything that ships its own copy of a file.
Entry `Priority` is deliberately low (5); ModLoader sorts entries by *descending* priority and
appends post-hooks in that order, so a low number means these hooks run last and wrap whatever else
loaded. `ImprovedTooltips_FileHooks.lua` lists them grouped by feature.

| Hook target | Our file | What it does |
|---|---|---|
| `lua/GUICommanderButtons.lua` | `ImprovedTooltips_HotkeyLabels.lua` | **Client.** Wraps `SharedInitializeButtons` and `Update` to write each commander button's hotkey in its corner, when switched on |
| `lua/ClientUI.lua` | `ImprovedTooltips_ClientUI.lua` | **Client.** Registers the spectator tech map for the spectator team |
| `lua/GUIInsight_Overhead.lua` | `ImprovedTooltips_SpectatorTechMapHint.lua` | **Client.** Adds the spectator tech maps to the overhead view's key hints |
| `lua/GUIUnitStatus.lua` | `ImprovedTooltips_WelderIcon.lua` | **Client.** Wraps `UpdateUnitStatusBlip` to put a welder icon right of a marine teammate's name |
| `lua/GUIUnitStatus.lua` | `ImprovedTooltips_MistBadge.lua` | **Client.** Wraps `UpdateUnitStatusBlip` to badge, for the alien commander, every alien entity the nutrient mist is helping |
| `lua/Hud/GUIPlayerStatus.lua` | `ImprovedTooltips_MistStatus.lua` | **Client.** Adds a nutrient mist entry to the alien HUD's status row, through the upvalues of `Initialize` |
| `lua/GUIAdvancedHUDBars.lua` | `ImprovedTooltips_ShieldBar.lua` | **Client.** Wraps `Initialize`, `Uninitialize` and `Update` to add the alien shield bar and its number beside the Centralized bars |
| `lua/GUIAlienHUD.lua` | `ImprovedTooltips_AlienHUD.lua` | **Client.** Wraps `Update` to hide vanilla's corner shield number while the shield bar stands in for it |
| `lua/GUIScoreboard.lua` | `ImprovedTooltips_TournamentReady.lua` | **Client.** Ready labels on the team headers under Shine's tournament mode |
| `lua/menu2/NavBar/Screens/Options/Mods/ModsMenuData.lua` | `ImprovedTooltips_ModsMenu.lua` | **Client and main menu.** The settings panel under Options > Mods |
| `lua/NetworkMessages.lua` | `ImprovedTooltips_NetworkMessages.lua` | Registers the spectator tech tree request in every VM |
| `lua/TechTree_Server.lua` | `ImprovedTooltips_SpectatorTechTree.lua` | **Server.** Wraps `SendTechTreeUpdates` to send a team's tech tree to the neutral spectators who asked for it |

## Layout

`source/` is the tree Launch Pad builds from; `output/` is generated and git-ignored.

```
source/lua/entry/ImprovedTooltips.entry          mod entry, points at the FileHooks file
source/lua/ImprovedTooltips/
    ImprovedTooltips_FileHooks.lua               registers every hook, grouped by feature
    ImprovedTooltips_Config.lua                  display options and the version
    ImprovedTooltips_Common.lua                  shared helpers: textures and icon cells, tech lookup,
                                                 whether the mist is helping an entity
    ImprovedTooltips_ModsMenu.lua                the settings panel, built from one table of options

  commander buttons
    ImprovedTooltips_HotkeyLabels.lua            hook on GUICommanderButtons.lua

  spectator tech maps
    ImprovedTooltips_ClientUI.lua                hook on ClientUI.lua
    GUIImprovedTooltipsSpectatorTechMap.lua      the spectator tech map
    ImprovedTooltips_SpectatorTechMapHint.lua    hook on GUIInsight_Overhead.lua
    ImprovedTooltips_SpectatorTechTree.lua       hook on TechTree_Server.lua     (server)

  nameplates and HUD
    ImprovedTooltips_WelderIcon.lua              hook on GUIUnitStatus.lua, welder icon on nameplates
    ImprovedTooltips_MistBadge.lua               hook on GUIUnitStatus.lua, nutrient mist badges
    ImprovedTooltips_MistStatus.lua              hook on Hud/GUIPlayerStatus.lua, mist status icon

  Centralized HUD bars
    ImprovedTooltips_ShieldBar.lua               hook on GUIAdvancedHUDBars.lua, alien shield bar
    ImprovedTooltips_AlienHUD.lua                hook on GUIAlienHUD.lua, hides the corner shield number

  scoreboard
    ImprovedTooltips_TournamentReady.lua         hook on GUIScoreboard.lua

  every VM
    ImprovedTooltips_NetworkMessages.lua         hook on NetworkMessages.lua

source/ui/bleu_tooltip_icons.dds                 448x64 icon sheet, 7 cells of 64x64; since 1.2 only
                                                 the ready and not-ready cells are used
tools/build_icons.ps1                            regenerates the icon sheet
tools/check_mod.lua                              static check of source/, run before committing
preview.jpg                                      Workshop preview, 512x512
mod.settings                                     Launch Pad project settings
```

## Checking the code

NS2 Lua only really runs in game, so `tools/check_mod.lua` catches what can be caught without it.
Run it from the repository root with Lua 5.4, `luac` beside `lua`:

```
lua tools/check_mod.lua
```

It checks that every file parses; every `Script.Load` and file hook target exists; every
`ImprovedTooltips` field read is assigned somewhere; no function reads a global its own file declares
as a local later; no unknown global names appear (known NS2 names are listed in
`tools/check_mod_globals.txt`, rewritten with `--write-baseline` after checking a new one); every
file's top level runs against a stub game; and every settings panel default matches the config. A
pass is not proof: NS2 runs Lua 5.1, and nothing inside a function runs.

## Config

`ImprovedTooltips_Config.lua`:

- `kVersion` — the mod version, `"1.2"`
- `kShowTournamentReadyLabels` — the glyph and green/red label at the front of each team's
  scoreboard header under Shine's tournament mode. Inert when that plugin is not running
- `kReadyLabelText` / `kNotReadyLabelText` — the label strings, brackets included
- `kReadyLabelColor` / `kNotReadyLabelColor` — full green and full red. The tick and cross beside
  them are what carry the meaning for a red/green dichromat
- `kReadyGlyphHeightScale` — glyph height as a fraction of the label's measured text height
- `kReadyGlyphGap` / `kReadyLabelGap` — gaps as fractions of the label's text height, glyph to
  label and label to team name, so they stay in proportion under a scoreboard mod's own font
- `kShowWelderNameplateIcon` — a welder icon right of the name of every marine teammate carrying one,
  for the marine commander and marines in the field. On by default, and exposed in the settings panel
- `kWelderIconCellInset`, `kWelderIconColor` — the build menu welder, cropped from its cell, tinted
  light blue and 80% opaque
- `kWelderIconHeight` / `kWelderIconGap` / `kWelderIconCenter` — icon size, gap after the name and
  vertical center, in units of the name's line height so they fit small and normal nameplates
- `kWelderIconRefreshInterval` — seconds between rebuilds of who carries a welder
- `kShowCommanderHotkeyLabels` — each commander tab and grid button's hotkey in its bottom-right
  corner, from the player's own bindings. Off by default, and exposed in the settings panel
- `kHotkeyLabelScale` / `kHotkeyLabelInset` / `kHotkeyLabelColor` — label size and corner inset, both
  relative to the commander GUI's own scale, and its color (always bright)
- `kShowNutrientMistIndicators` — the nutrient mist badges (alien commander) and status icon (alien
  HUD). Always on; no settings panel option
- `kMistBadgeSize` / `kMistBadgeColor` / `kMistBadgeArrowFraction` / `kMistBadgeGap` — the commander
  badge: 48 px, green, arrow at 46%, 4 px above the plate
- `kMistStatusColor` — the status row icon's tint, the alien icon color
- `kShowAlienShieldBar` — the alien shield bar beside the Centralized HUD bars, and the corner shield
  number hidden while it shows. On by default, and exposed in the settings panel
- `kShieldBarInward` — how far the bar sits inward of one bar width outboard of the health bar, as a
  fraction of the bar width: 23/64, half the gap vanilla's art leaves between two bars
- `kShieldBarBabblerColor` / `kShieldBarVampirismColor` / `kShieldBarMucousColor` — the segments,
  tan, green and lavender, bottom to top
- `kShieldNumberColor` — the total's color, vanilla's shield number green
- `kShieldNumberGap` — 1080p pixels between the total and the widest health text for the lifeform

The settings removed in 1.2 leave their saved `BIT_*` values in players' options files, unread.

## Building the assets

```powershell
.\tools\build_icons.ps1
```

Regenerates `source/ui/bleu_tooltip_icons.dds` from vector drawing code and compresses it with
`nvcompress.exe` from the game's `utils/` folder. Pass `-NS2 <path>` if the game is not at the
default install path. Output is uncompressed RGBA rather than DXT — the sheet is tiny and DXT
block artifacts are very visible on hard-edged white glyphs.

## Servers

The mod changes no gameplay. Its one server part sends a playing team's tech tree to the neutral
spectators who ask for it, which no client can read for itself. It has to be installed on the server
regardless, because of NS2's consistency check rather than anything this mod does:

- `ns2/lua/ServerConfig.lua` defaults `consistency_enabled = true` and
  `use_own_consistency_config = false`, so a stock server uses the built-in config.
- That config (`core/lua/ConsistencyConfig.lua`) sets `restrict = { "lua/entry/*.entry" }`, fed to
  `Server.AddRestrictedFileHashes`. Entry files are how a mod declares itself, so this is the hook
  UWE uses to control which mods a client may load — note the `ignore` list carves out specific
  cosmetic files (`ui/crosshairs.dds`, hitsound banks) precisely so *those* client mods work.

A client carrying `lua/entry/ImprovedTooltips.entry` that the server does not have is therefore
expected to fail the check. Admins should add the mod to the server's mod list, or whitelist it.

The Workshop item is tagged `Must be run on Server` for this reason.

> The exact engine behavior of `Server.AddRestrictedFileHashes` is not readable from Lua, so this
> is read off the config and NS2's server defaults rather than measured. If it turns out a stock
> server does accept it, the tag and this section should be revisited.

## Credits

- **NSL Mod (Dragon).** The spectator tech maps use the same controls and approach as NSL Mod's
  (MIT licensed); the code is this mod's own.

## Changelog

**1.21 (Workshop, 2026-11-15)**
- **Alien shield bar.** With Centralized HUD bars, an alien's mucous, vampirism and babbler shields
  show as one bar beside the health bar: babblers tan at the bottom, vampirism green, mucous lavender
  on top, in the order damage reaches them. A full bar is the most shield the lifeform can carry at
  biomass 1, vampirism included, so the same fill always means the same amount of shield (vanilla's
  ring is relative to whichever shields are active, so a full ring could mean very different
  amounts). More than that is cut off at the top. The total is underneath in green, always shown
  while there is any shield, and vanilla's corner number is hidden meanwhile. The bar uses the
  installed bar texture, so ydy-style bars restyle it too. Setting SHIELD BAR, on by default. See
  `docs/alien-shield-bar.md`. It replaces the 1.06-era attempt on `feature/centralized-bars-shields`,
  whose scale and style options and bar opacity slider were dropped.

**1.2 (Workshop, 2026-11-14; for build 345)**
- **Build 345 made most of the mod part of NS2**, so 1.2 removes everything the game now does on
  its own: the tooltip values and selection panel tint, the supply icons, the "In Cooldown" panel and
  cooldown sync, the hive status additions and HIVE RESEARCH DISPLAY (the busy-hive ring with them),
  the research notification fixes, biomass progress on the tech map and the bead bar, the spectator
  top bar supply and biomass color, the lost arms lab alert, weapon colored map blips and custom
  weapon colors, corner minimap phase gate arrows, the exo weapon bars, and CBM compatibility. See
  [Gone vanilla](#gone-vanilla). 27 files, both server messages for cooldowns and hive state, and
  nine settings panel rows went with them.
- **Nutrient mist indicators** (built as 1.13, never published on its own). The alien commander sees
  a badge (the tech-tree mist icon in green, with the HUD's green up arrow) over every alien entity
  the mist is helping right now: embryos, anything still growing, and disconnected cysts. A player
  evolving in a misted egg gets a mist entry in the alien HUD's status row. Grown structures get
  neither, even inside the mist, because the game's own code does nothing for them (it does not stop
  off-infestation damage, and mist heals nothing; checked again on build 345). Always on. See
  `docs/nutrient-mist-indicators.md`.
- The settings panel keeps HOTKEY LABELS ON COMMANDER BUTTONS and WELDER ICON ON NAMEPLATES.
- Workshop description rewritten around what the mod still adds, with a "Gone vanilla" section.
- Tested 2026-11-14 on build 345.4583 beta from Launch Pad: no doubled HUD elements, the two remaining
  settings, and the remaining features all working, with no script errors in the log.

**1.12 (Workshop, 2026-10-30)**
- **Tech maps for spectators.** A neutral spectator holds their tech map key (J by default) and
  presses 1 or 2 for the marine or alien tech map, the same controls as NSL Mod's, with the hint
  added to the overhead view's key hints. The server sends the chosen team's tech tree to that
  spectator only; dead players watching their own team keep their own side's map. Stands down when
  NSL Mod is loaded. See `docs/spectator-tech-maps.md`.

**1.11 (Workshop, 2026-10-22)**
- **Hotkey labels on the commander buttons.** New setting HOTKEY LABELS ON COMMANDER BUTTONS, off
  by default: each tab and grid button shows its hotkey small in its bottom-right corner, as Age of
  Mythology does, following the player's own key bindings. Empty slots get none, Space reads SPC, and
  a grid bound to a key the game ignores (a number, a mouse button) gets none. Both teams. See
  `docs/commander-hotkey-labels.md`.
- Workshop description: the 1.10 welder icon and the hotkey labels are described, and the CBM
  paragraph no longer claims CBM is named in one place only (the SMG map color made that untrue).

**1.10 (Workshop, 2026-10-19)**
- **Welder icon on nameplates.** A marine teammate carrying a welder gets a welder icon right of
  their name, so nobody has to ask who has one or hold the scoreboard open. The marine commander
  sees it on every plate whose name shows; marines in the field see it while their teammate's
  nameplate shows, which in first person is while aiming at them. The art is the commander build
  menu's welder, tinted light blue. New setting WELDER ICON ON NAMEPLATES under MARINES, on by
  default. See `docs/welder-nameplate-icon.md`.
- The weapon colored map reads the commander's palette even when another mod wraps the nameplate
  code, as this release and Devnull Shine Extras both do. It used to fall back to its own copy of
  the colors.

**1.09a (Workshop, 2026-10-01)**
- Settings panel: the MARINES and ALIENS headings are a tier smaller, so they read as parts of the
  panel instead of matching its title bar.

**1.09 (Workshop, 2026-10-01)**
- **Custom weapon colors for the map and minimap.** New setting CUSTOM WEAPON COLORS: OFF or ON,
  with a color picker per weapon folding out beneath it. One palette, used on every map that has
  weapon colors switched on; the setting folds away when neither map does. The pickers start
  at the colors the map already uses, so nothing changes until one is picked. See
  `docs/custom-weapon-blip-colors.md`.
- **Settings panel grouped by team.** Settings common to both teams come first, then MARINES and
  ALIENS headings. The SMG color row only appears in a game running CBM.
- **In Cooldown icons in the team color.** They were drawn in the build menu's raw gray, which read
  as disabled; they now take the same tint as the commander's own buttons.
- **Hive panel additions for spectators.** Following an alien in first person shows the alien hive
  panel, but the mod's biomass icons, research ring and HIVE PANEL slots stayed empty because their
  data only went to the alien team. Spectators now receive it too.

**1.08** (Workshop, 2026-09-26)
- **The In Cooldown panel wraps three to a row.** Past three abilities it used to run off the right
  of the screen, and aliens reach four at the default cut-off. A short last row is centered, and the
  alien smoke is refitted so it covers the whole panel rather than fading out under the bottom row.
- **Marines get a backdrop behind the In Cooldown panel**: the commander selection panel's own
  scanline plate and frame.
- **Smaller phase gate arrows on the corner minimap.** They were drawn at the big map's size, about
  three times too big for the small map; they are now drawn at 0.6 of that size.
- **The spectator supply counter follows a re-themed top bar**, as the commander tooltip already did.
  It read the top bar's icon settings under the wrong names and always used its built-in copy.
- **Code cleanup, no visible change.** Duplicated helpers merged into `ImprovedTooltips_Common.lua`,
  the settings panel built from one table, the two team join hooks merged into one, the hive research
  slots moved to their own file, and a static check added in `tools/check_mod.lua`. See
  `docs/refactor-plan.md`.

**1.07** (Workshop, 2026-09-22)
- **Hive research in the hive panel.** New setting HIVE RESEARCH DISPLAY. NOTIFICATIONS (default)
  keeps research on the left with the busy ring on the hive, as before. HIVE PANEL moves research
  done in hives into that hive's row instead: the hive's own research (biomass or a hive type upgrade)
  on the left, the evolution chamber's on the right, each drawn like a small research notification
  with its progress bar and time left. Advanced structure upgrades and other research stay on the
  left. See `docs/hive-research-slots.md`.
- **Research notifications for aliens no longer go missing.** With more than three researches
  running, vanilla dropped the ones pushed below the three shown for good, and only played the
  "trait available" sound for research on screen. Every research now returns to the list when a
  place frees up, and every completion plays the sound.
- **Biomass is right on the tech map from the start of a round.** A vanilla typo meant a change in
  alien biomass never refreshed the tech tree, so a round could start showing biomass 0 until a
  structure was dropped or a research started. Already fixed on the game's beta branch.
- **Tournament mode ready labels are right after a round is reset.** Both teams could still read
  `[Ready]` in the new pre-game once a round had started and been reset, since Shine clears its
  ready states silently when a game begins and the labels only noticed while the scoreboard was
  open. They now notice either way.

**1.06**
- **Refreshed glyphs.** The hourglass and stopwatch get a soft vanilla-style glow and are slightly
  smaller - the hourglass by 12%, the stopwatch by 7%, scaled evenly so neither is stretched - so they
  sit better beside vanilla's health and armor. The hourglass also has far less sand in its lower
  bulb, since the glow made the old mound read as a full bottom. The marine speed icon becomes flat, thinner double
  chevrons with the same glow. Health, armor, alien speed and the ready icons are unchanged, and the
  build now checks that pixel for pixel. See `docs/glyph-refresh.md`.
- **The stat row fits the tooltip.** The panel is a fixed width, and the row used a fixed gap, so the
  ARC - the one tooltip with all four figures and a four-digit one (2600 / 400 / 2 / 10) - ran its
  last glyph and number out past the frame. The row now ends where the top row does, at the right
  edge of the team res icon: the gaps close up evenly to fit, and only a row that still does not fit
  brings each number closer to its icon.

**1.05**
- **Phase gate arrows on the commander's and spectator's corner minimap.** Vanilla draws them on the
  big map and on the marine HUD's minimap but never on the overhead corner map, because a single
  `not modeIsMini` term (`GUIMinimapConnection.lua:32`) switches off both the static and the
  animated arrows there. New setting PHASE GATE ARROWS ON CORNER MINIMAP, on by default.
- It follows the player's own phase gate line setting (Advanced > Map) and vanilla's own rules:
  marine gates only, and only with more than two of them. Solid lines, alien tunnels and two-gate
  setups are left exactly as vanilla draws them.
- Lines that carry arrows there are drawn 10 thick, the same as the marine HUD's minimap, instead of
  the corner map's usual 6: at 6 the arrow art is squashed past reading.
- **CBM's SMG blips are blue instead of orange.** The commander palette's SMG orange (`#FF6600`) sat
  right next to the default alien blip color (`#FF8A00`), and CBM players read SMG marines as
  aliens. Blue follows the "rifle plus" idea, a rifle-tier weapon in the rifle's color family, which
  a CBM player also suggested. It can match the plain marine color; with weapon colors on, the only
  marines left in that color are exos, and their blips are far larger. A new override table,
  `kMapBlipColorOverrides`, wins over the palette read; per-weapon custom colors will use it later.
- **Exo weapon bars beside the crosshair.** Hiding the exo viewmodel also hides minigun heat and
  railgun charge, because vanilla paints both onto the weapon model's own texture. A bar and a
  percentage now sit either side of the crosshair, one per arm, never averaged. New setting EXO
  WEAPON BARS, on by default.
- Shown only when the exo viewmodel is hidden ("Hide all", or "Custom" with the exo hidden),
  whatever the marine HUD bars style. Centralized and NS1 do carry an exo readout, but they squeeze
  both arms into one averaged bar, so a player can like those for marines and still want these.
- **With Centralized HUD bars, vanilla's right-hand weapon bar and its number are hidden** while the
  exo bars show, so there is one readout beside the crosshair rather than two. The exo armor bar on
  the left stays. NS1 is left alone: its bars are in the bottom corners and do not crowd these.
- Arms are recognized by what they expose, not by name: heat (minigun) blends from blue through
  orange to red and pulses when overheated; charge (railgun) turns white when full; an energy pool
  (CBM's plasma launcher) marks the shot cost with a tick and turns CBM's own color once a shot is
  affordable. A claw shows nothing.
- The look is the ydy center HUD bar stroke at twice the thickness, drawn from plain GUI items so it
  is the same whichever bar texture a player has installed.
- The Workshop description's Settings paragraph now covers every switch, not just the cooldown
  panel.

**1.04a**
- **Weapon colors on the big map are now on by default.** It is a screen you open deliberately, to
  read, so the extra color earns its place there. The minimap stays off by default: it is in the
  corner of the screen all round whether you are reading it or not.
- Nobody's choice is overwritten. `Client.GetOptionBoolean` returns whatever a player stored, so the
  new default only reaches players who never touched the setting.

**1.04**
- **The big map and the minimap have a weapon color switch each.** COLOR MAP BLIPS BY WEAPON now
  covers only the big map, the one on the map key, and keeps its 1.03 setting, so a player who had
  it on still does. The new COLOR MINIMAP BLIPS BY WEAPON covers the minimap in the corner of the
  marine HUD, and the commander's and spectator's corner map. Off by default.
- Each map is a `GUIMinimapFrame` whose `comMode` says which one it is: `kModeBig` for the map key,
  `kModeZoom` for the marine HUD's minimap, `kModeMini` for the overhead corner map. The big map
  switch applies to `kModeBig`; everything else is a minimap.
- **American spelling throughout.** The settings labels now read COLOR, not COLOUR, and the
  Workshop description, this README, the docs and the code comments follow suit (armor, gray,
  center). `docs/marine-map-weapon-colours.md` is now `docs/marine-map-weapon-colors.md`.

**1.03**
- **Marine blips on the map can be colored by primary weapon.** Optional, off by default, in the
  settings panel. The colors are the commander's own — `GUIUnitStatus`'s `kAmmoBarColors`, the
  palette already under each marine's ammo bar in the top-down view — so the map agrees with what a
  commander is reading on the same screen. A rifleman is teal, a shotgunner green, and so on.
- **It follows the primary weapon, not the one in hand.** A shotgunner who switches to a welder or a
  pistol stays green: `Marine:GetPlayerStatusDesc` reads the primary HUD slot, so the map says what
  a marine can bring rather than what is momentarily raised.
- **The palette is read out of the running game, not hardcoded.** `GUIUnitStatus` keeps that table
  as a file-local, so it comes out of `GUIUnitStatus:UpdateUnitStatusBlip`'s upvalues via
  `debug.getupvalue` — the same technique Shine and NSL use — and the bridge from a blip to it is by
  name, since `kPlayerStatus` and `kTechId` agree on every weapon name that matters. **A weapon any
  mod adds is picked up with nothing written here**, CBM's SMG included. A written-down copy in
  config takes over only if that read cannot happen.
- **Only marines and spectators ever see it.** Gating on the blip type would have leaked loadouts:
  `MapBlip.lua:326` deliberately shows Steam friends across teams, so an alien can see a marine
  blip. The gate is on the viewer's team instead.
- **Steam friend highlighting still works on top of it.** Vanilla's friend treatment is a
  desaturation applied after the color is chosen, not a color of its own, so the mod feeds the
  base color and lets that compose — a friend with an HMG is half-saturated red. Returning a final
  color from the hook would have wiped it.
- Exosuits keep the plain marine color. Vanilla does color them elsewhere — the spectator ammo
  bars give minigun red and railgun orange — but under CBM an exo is modular and can carry any
  combination, so there is no single weapon to color one by.
- NS2 has **three** per-weapon palettes, not one: the outline glow on the model (everyone,
  commander included), the ammo bar under a marine in the commander's view, and the ammo bar in the
  spectator's. All three agree exactly on shotgun, grenade launcher and flamethrower; HMG differs by
  a shade; rifle has three different values, and the map takes the commander's teal. Recorded in
  `docs/marine-map-weapon-colors.md`.
- **The hourglass and stopwatch glyphs were redrawn with more detail**, to match the artwork in
  the Workshop preview. The hourglass is part full at the top and part full at the bottom, so it
  reads as time running rather than not started, and keeps its old width. The stopwatch gains a
  crown and a start button at 45 degrees, clear of the ring, so it no longer reads as a wall clock;
  its hands stay at 12 and 3. Health, armor and the marine speed chevron are unchanged.
- The Workshop description lost two sentences to make room under Steam's 8000-byte cap: the quoted
  Lua stub in the "In Cooldown" paragraph, and a clause about display versus enforcement. Both were
  implementation detail on a page meant for players.

**1.02b**
- **The tournament mode ready state moved from the skill badge to the front of the header row.**
  1.02 drew a pip in the badge's corner; it worked, but it was small and took two rounds of
  resizing to be legible at all. Each team's header now reads `[tick] [Ready] Frontiersmen
  (6 Players)`, green for ready and red for not, with the glyph squared off to the height of the
  label beside it. No art change — cells 5 and 6 were already a colored square with a white mark.
- Two things in vanilla made that harder than it looks, both recorded in
  `docs/tournament-ready-label.md`. The skill badge's x is derived from the team name's width but
  only recomputed when the team's summed skill changes, so shifting the name strands the badge on
  top of it unless the mod drives that position itself. And there is little room before the player
  column headers — 400 unscaled pixels on a wide screen, 275 below 1280 — and a full team's
  `Frontiersmen (12 Players)` plus glyph plus label plus badge is close to the first and past the
  second. The row is therefore measured every update, and the label drops to glyph-only rather than
  overlapping the Score column.
- **Compatible with scoreboard mods that replace `GUIScoreboard.lua` wholesale**, Devnull's
  Enhanced Scoreboard in particular. The first cut of this hardcoded vanilla's header order and so
  moved that mod's skill badge from the front of the row to the back, and set the label in a font
  the mod does not use. Nothing about the row is assumed now: the host's own item positions are
  read back and only ever shifted, so whichever order it chose survives, and the label's font is
  copied off the team name rather than taken from a constant the host may have left unused.

**1.02**
- **Supply on the spectator top bar.** That bar carries resources, resource towers and alien
  biomass but never supply, on a screen far wider than the 512 pixel bar vanilla lays out inside.
  Both teams' supply now sits in the space either side, used against maximum, with vanilla's biomass
  pair shifted right to free the slot. No new networking: `TeamInfo` already carries the numbers.
- **A ready tick or a not-ready cross on the scoreboard's team skill badges** while Shine's
  tournament mode waits for both teams, so the scoreboard says who is being waited on. Inert on a
  server not running that plugin, and off entirely once the round starts. Shine does not send one
  canonical ready message — `ReadyTeam` picks between `TeamReadyChange` and `TeamReadyWaiting`
  depending on what the other team is doing, and a player backing out of a ready team produces only
  `TeamPlayerNotReady` — so all three are tracked. Listening to `TeamReadyChange` alone misses the
  first team to ready up, which is the most common event there is.
- The `Config` section of this README now lists every constant. Ten added in 1.01 were never
  documented there.

**1.01**
- **Lost arms lab upgrades stay on screen, in red.** When a team loses every arms lab, or they all
  lose power, the marine HUD's weapon and armor icons simply vanished — indistinguishable from
  never having researched them. Vanilla already contains the alert red for this state but can never
  show it: `GUIMarineHUD:Update` hides the icons fifteen lines before it colors them, and both
  tests come from the same arms lab. The icons now stay, using vanilla's own color, driven by the
  `researched` flag `PlayerUI_GetArmorLevel` accepts and the HUD never passes.
- **The biomass bar shows research as it happens.** The twelve bead bar knew only whole beads —
  empty until a research finished, then full — because it reads a single integer. Each bead being
  researched now fills as the work goes in, several at once when several hives are working, drawn
  from the per-level progress the 0.92 fix has been publishing all along. Bead positions are
  measured from the texture rather than assumed even; they are not.
- **Ability icons on that bar light up while being researched** and carry a progress bar, matching
  the tech map, which promotes any node with partial progress to its "available" color. They used
  to stay grayed out until the instant the research completed.
- **A settings panel under Options, Mods**, alongside CBM's and anyone else's: the In Cooldown panel
  can be switched off, and a slider sets the shortest cooldown it will list. Both apply immediately.
- **CBM's biomass 5 tint now uses CBM's own advanced alien color.** It previously used the purple
  from CBM's tech map connector lines, which is in fact nearer their advanced *marine* shade — an
  alien research marked in almost the marine color.
- The Workshop description no longer claims movement speed "picks up whatever the loaded mods set it
  to". It does not: the figure is read off the unit's own class, so mods that compute speed live
  from game state read low or blank. Known, and stated plainly rather than overclaimed.

**1.0**
- **Speed is stated plainly and never dimmed.** Structures whose movement is conditional used to be
  faded when no live one could confirm it — which caught far more than intended: a Whip can always
  move, and on its build button, before you own one, there was nothing to ask, so it faded. The
  class's own speed is shown instead. B2TP's Spur shows a speed before its Shift Hive is in, which is
  the one thing given up for everything else being right.
- **The hourglass and stopwatch now match the vanilla glyphs in size.** Both were drawn 57px tall in
  a 64px cell and sampled whole, so they rendered at 89% of the icon against the health and armor
  glyphs' 81% and visibly overhung them. They are now measured after drawing and fitted to the same
  81%, which also keeps them in step if the drawing code changes.
- Fixed an error seen on a plain install: `Element 'DualMinigun' doesn't exist in the enum`. `kTechId` is
  an engine enum that **raises** on a name it does not hold rather than answering nil. Every lookup
  by name now goes through `ImprovedTooltips.GetTechIdByName`, which reads the underlying table and
  answers nil for a name that is not there.
- **Biomass icons are colored everywhere the mod can reach them** — the hive HUD row, the biomass
  icon on the commander tooltip, and the spectator top bar counter — in the tech map's own color for
  researched alien tech. Vanilla leaves all three as the bare grayscale atlas cell, but nothing else
  in a tooltip or in the tech tree stays uncolored, so untinted read as unfinished rather than as
  deliberate. CBM's biomass 5 keeps CBM purple.
- **A CBM compatibility module**, the one mod-specific file in the mod and a deliberate exception:
  CBM color-codes its own tech in a way nothing can be read from. It detects CBM by the tech CBM
  adds rather than by a name, and registers nothing at all when CBM is absent.
- **CBM's biomass 5 icon is tinted purple** on the hive HUD, matching how CBM marks that hive out.
  The research itself needed no code — the HUD already listed it and reads its art from the atlas, so
  CBM's own icon appeared unaided. The tint goes through a new public `RegisterIconColor` registry
  rather than a branch in the drawing code.
- Fixed `RegisterResolver` raising an error rather than declining when handed a techId that does not
  exist.
- **Supply on the commander tooltip now uses the HUD top bar's icon** instead of a MAC or a Drifter.
  Both meant supply and looked nothing alike; the split is a leftover from the top bar replacing
  `GUIResourceDisplay`, whose create and destroy calls are now commented out, leaving the tooltip as
  the last place the worker icon stood for supply. The MAC and Drifter icons are untouched wherever
  they stand for the units themselves.
- **Biomass on the hive status HUD.** Each hive in the top-left panel now shows one icon per +1
  biomass research it has completed, beside its location name. A fresh hive shows none, matching how
  it shows no hive type icon until it is upgraded, and each research adds its own button's art -
  which get denser as they go, so the row reads as a progression.
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
- Fixed the health and armor glyphs being oversized on vanilla's selection panel. They are now
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
  Deploy shows armor dropping to 0 and speed to 0 — the cost of deploying, visible while choosing.
- **Health and armor icons replaced with vanilla's own** cross and shield, resampled into the mod's
  sheet so they match the other icons in size and are fully opaque. The mod's earlier hand-drawn
  pair is gone.
- **Color.** Figures and icons both take vanilla's selection-panel colors — marine health pale
  cyan, marine armor deep teal, alien health yellow, alien armor darker orange — so a number means
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
  under the title, alongside health and armor. In 0.8 each extra icon in the top row pushed it
  further left, and with a long title it collided with the title text.
- Dropped 0.8's repacking of vanilla's own cost / supply / biomass icons — no longer needed, and it
  means tooltips with no extra data now render exactly as vanilla does.
- Redrew the hourglass. The 0.8 version was a flat bowtie of two bars and two triangles; it now has
  rounded caps, concave glass, and sand falling from a full upper bulb into a mound below.

**0.8** — first published build.
