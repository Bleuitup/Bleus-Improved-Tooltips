-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_Config.lua
--
-- Client-side display options. Nothing here affects gameplay, so these are plain constants rather
-- than a config file - flip one and rebuild.

ImprovedTooltips = ImprovedTooltips or { }
local IT = ImprovedTooltips

-- How durations (research time, cooldown) are printed.
--   "seconds"  ->  "90"    "10"
--   "suffix"   ->  "90s"   "10s"
--   "clock"    ->  "1:30"  "0:10"
--
-- "seconds" is settled, confirmed against the published build - a 90 second research reads "90".
-- The other two modes are kept for anyone who prefers them, but do not change the default.
--
-- For the record, since it looks inconsistent at first glance: the only place vanilla prints a
-- research duration is the production queue's hover text (ns2/lua/GUIProduction.lua:335), and that
-- uses "1:23". But that is a live countdown, where a clock reads naturally. These are static
-- properties of the tech, and the same row also carries cooldowns of 3 to 20 seconds, where "0:03"
-- reads worse than "3".
IT.kTimeFormat = "seconds"

-- Show the armor figure next to health. Armor is 0 on a fair number of structures (Bone Wall,
-- Cyst, Infest Node); when this is true those show an explicit "0" rather than hiding the icon,
-- so a commander can tell "no armor" apart from "not measured".
IT.kShowZeroArmor = true

-- Show movement speed for things that move: ARC 2.0, Shade 1.73, Crag 2.9, Shift 2.9, Whip 3.5,
-- MAC 6, Drifter 11. Read from the class rather than TechData, which has no key for it.
IT.kShowSpeed = true

-- Opacity of the speed figure when the mod cannot confirm the structure can actually move right
-- now. Some structures have a speed but only move under a condition their own mod defines - B2TP's
-- Spur needs a Shift Hive, CBM's only needs to not be electrified - and that condition can only be
-- answered by a live entity. With none on the field, the figure is dimmed rather than hidden: it
-- states the speed without claiming it is usable yet. Set to 1 to stop dimming entirely.
IT.kUnconfirmedSpeedAlpha = 0.45

-- Icon tint. Applies to the mod's own icons only. Vanilla's health and armour art is already
-- coloured per team and is left untinted.
IT.kMarineIconColor = Color(0.7, 0.9, 1, 1)
IT.kAlienIconColor = Color(1, 0.79, 0.3, 1)

------------------------------------------------------------------------------------------------
-- "In Cooldown" panel
------------------------------------------------------------------------------------------------

-- Commander ability cooldowns are team-global (see ImprovedTooltips_CooldownSync.lua), so a Shade
-- Ink on cooldown blocks every Shade, not just the one that cast it. This panel surfaces that.
IT.kShowCooldownPanel = true

-- Only abilities with at least this much cooldown get a panel entry. Vanilla durations are
-- Shade Ink 15, Nano Shield 10, Heal Wave 6, Power Surge 4, Rupture 4, Hallucination Cloud 3,
-- Nutrient Mist 2. At 5 the panel shows the ones worth tracking and does not flicker constantly
-- from the two- and three-second abilities.
IT.kCooldownPanelMinDuration = 5

-- Position of the panel, as an offset from the right edge of the screen. x is negative (leftward
-- from that edge); y is measured down from the vertical middle. Both are pre-GUIScale.
IT.kCooldownPanelOffset = Vector(-210, -120, 0)

-- Show the remaining time in seconds under each icon, the way the tooltips show durations.
IT.kCooldownPanelShowSeconds = true

-- Backing plate opacity behind the whole panel, per team. Both are 0.
--
-- Each entry now sits on the game's own build-menu button plate, the same one the research display
-- uses, so the row has a shape of its own and needs nothing behind it. Any flat colour here draws a
-- hard-edged rectangle: obvious on the alien side, where the smoke mask fades to nothing at its
-- edges and the box shows through underneath, and just as wrong on the marine side where there is
-- no smoke to distract from it. Raise one only if text turns out unreadable over a bright map.
IT.kCooldownPanelAlienBackgroundAlpha = 0
IT.kCooldownPanelMarineBackgroundAlpha = 0

-- Also tint the health and armour icons on VANILLA's selection panel - the one you get clicking an
-- existing structure - to match their own figures. Vanilla colours the two numbers differently but
-- draws both icons in one flat team colour.
IT.kTintSelectionPanelIcons = true

------------------------------------------------------------------------------------------------
-- Tech map
------------------------------------------------------------------------------------------------

-- Show EVERY biomass level currently on its way, rather than only the next one.
--
-- Vanilla collapses all hives into a single number and writes it to one tech node, so two hives
-- researching biomass at once light up one icon between them. See
-- ImprovedTooltips_BiomassProgress.lua for the detail.
--
-- This is the mod's only server-side display option: AlienTeam lives in the server VM, and the
-- corrected progress reaches clients through vanilla's own tech node update. Setting it false
-- restores vanilla's behaviour exactly.
IT.kSpreadBiomassProgress = true

------------------------------------------------------------------------------------------------
-- Alien hive status HUD (top-left corner)
------------------------------------------------------------------------------------------------
--
-- Requires the vanilla panel to be on: Advanced Options -> UI -> hive status. Both of these need
-- the server, because a Hive is only relevant to players within 40m and the whole point of that
-- panel is hives across the map. See ImprovedTooltips_HiveState.lua.

-- One icon per biomass level, beside the hive's location name. Biomass 1 shows one, 4 shows four,
-- and the fourth uses the denser cluster art off the research button that grants it.
IT.kShowHiveBiomassIcons = true

-- Vanilla's rotating "working" ring plus the DNA glyph on any hive that is researching anything -
-- biomass, a lifeform ability, or a hive type upgrade.
IT.kShowHiveResearchIcon = true

-- Placement, all pre-GUIScale and all relative to the top-left of a hive's row in the panel. The
-- row is 228x50 with the location name plate running from x -6 to 135, so these sit in the space
-- to its right. Nudge them if a resolution or another mod moves things.
IT.kHiveBiomassIconOrigin = Vector(140, -13, 0)
IT.kHiveBiomassIconSize = 18
IT.kHiveBiomassIconSpacing = 19
IT.kHiveResearchIconPosition = Vector(182, 12, 0)
IT.kHiveResearchIconSize = 34

-- The DNA glyph as a fraction of the ring it sits inside.
IT.kHiveResearchDnaScale = 0.55

-- Biomass icons take the tech map's own "researched" colour for aliens - GUITechMap's
-- kTechMapIconColors[kAlienTeamType][kTechStatus.Available] - so a biomass ball means the same
-- thing here as it does there.
IT.kHiveBiomassIconColor = Color(1, 0.9, 0.4, 1)

-- The ring art is already amber, so it is drawn untinted. The DNA glyph is pale and takes the
-- alien tooltip tint.
IT.kHiveResearchRingColor = Color(1, 1, 1, 1)
IT.kHiveResearchDnaColor = Color(1, 0.79, 0.3, 1)

-- Seconds per full turn. Matches GUIUnitStatus.kResearchRotationDuration, so the HUD ring and the
-- one on the hive itself spin together.
IT.kHiveResearchRotationDuration = 2
