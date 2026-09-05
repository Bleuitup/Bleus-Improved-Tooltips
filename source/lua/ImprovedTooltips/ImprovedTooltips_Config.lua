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
--
-- What is shown is the structure's own speed constant, with no attempt to say whether it can use it
-- right now. Some mods gate movement behind an upgrade - B2TP's Spur needs a Shift Hive - and an
-- earlier version dimmed the figure whenever that could not be confirmed from a live entity. It
-- dimmed far more than it should have, including vanilla's Whip, which can always move and only
-- reports otherwise mid-root. Stating the plain speed is the simpler and more often correct answer.
IT.kShowSpeed = true

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

-- One icon per +1 biomass research a hive has completed, beside its location name. A fresh hive
-- shows none, matching how it shows no hive type icon until it is upgraded; each research then adds
-- its own button's art, in order, so the icons grow denser as the hive climbs.
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
--
-- The ring is positioned by its top-left but is read as a disc, so it is easier to think in centres:
-- this puts its centre at (168, 38), which is directly under the middle of the SECOND biomass icon
-- (140 + 19 + 18/2 = 168) and low enough to clear the name plate. Change the size and the ring grows
-- down and right from the same corner, so move the position by half the difference to keep it
-- centred where it was.
IT.kHiveResearchIconPosition = Vector(134, 4, 0)
IT.kHiveResearchIconSize = 68

-- The DNA glyph as a fraction of the ring it sits inside.
IT.kHiveResearchDnaScale = 0.55
-- The colour of every biomass icon the mod draws or reaches: the hive HUD row, the biomass icon on
-- the commander tooltip, and the spectator top bar counter.
--
-- Vanilla leaves all three untinted, which is the same greyscale cell in each case - kTechId.Biomass
-- and kTechId.BioMassOne are both atlas index 112. But nothing else in the tech tree or in a tooltip
-- stays uncoloured, so untinted reads as unfinished rather than as deliberate. This is the tech
-- map's own colour for alien tech that is researched and available -
-- kTechMapIconColors[kAlienTeamType][kTechStatus.Available] in GUITechMap.lua - so a biomass icon
-- means the same thing wherever it is seen.
--
-- A compatibility module can claim a different colour for one specific research; CBM's biomass 5
-- takes CBM's advanced alien colour this way. See IT.RegisterIconColor.
IT.kBiomassIconColor = Color(1, 0.9, 0.4, 1)

-- Colour the spectator top bar's biomass counter too. Separate because reaching it takes more work
-- than the others: see ImprovedTooltips_InsightTopBar.lua.
IT.kColorSpectatorBiomass = true

-- The ring art is already amber, so it is drawn untinted. The DNA glyph is pale and takes the
-- alien tooltip tint.
IT.kHiveResearchRingColor = Color(1, 1, 1, 1)
IT.kHiveResearchDnaColor = Color(1, 0.79, 0.3, 1)

-- Seconds per full turn. Matches GUIUnitStatus.kResearchRotationDuration, so the HUD ring and the
-- one on the hive itself spin together.
IT.kHiveResearchRotationDuration = 2

-- Use the HUD top bar's supply icons on the commander tooltip, in place of vanilla's MAC and
-- Drifter.
--
-- Vanilla marks the supply figure on a tooltip with the team's worker, while the supply readout on
-- the top bar uses a dedicated pair of icons. Both mean supply and they look nothing alike.
--
-- That split is a leftover, not a decision: the top bar (lua/Hud2) replaced GUIResourceDisplay,
-- which used exactly the same worker coordinates for its own supply counter, and Commander_Client
-- now has both its create and destroy calls commented out. The tooltip is simply the last place the
-- worker icon survives standing for supply.
--
-- The MAC and Drifter icons are untouched wherever they stand for the units themselves.
IT.kUseTopBarSupplyIcon = true

------------------------------------------------------------------------------------------------
-- CBM compatibility
------------------------------------------------------------------------------------------------
--
-- See ImprovedTooltips_CBM.lua. Everything in that file is inert unless CBM is actually loaded,
-- detected by the tech it adds rather than by a name.

-- Turn the whole CBM module off, restoring what the mod does with no knowledge of CBM at all.
IT.kEnableCBMCompat = true

-- Tint the biomass 5 research icon on the hive HUD, which CBM marks out in purple.
IT.kColorCBMBiomassFive = true

-- CBM's own colour for advanced ALIEN content: kAdvancedAlienColor in its GUIMinimap.lua, the
-- counterpart to kAdvancedMarineColor = Color(0.4, 0, 1, 1) for advanced marine content. Confirmed
-- by one of CBM's developers, 2026-09-05.
--
-- It used to be Color(0.7, 0.3, 1, 1) here, taken from CBM's tech map and minimap connector lines.
-- That was the closest thing to a deliberate CBM colour at the time, but it is a generic UI purple
-- and, as it turns out, nearer their advanced MARINE shade than their alien one - so an alien
-- research was being marked in almost the marine colour. This is the semantic one.
--
-- Mirrored rather than read at runtime. CBM declares both as file-locals in its own copy of
-- GUIMinimap.lua and keys them into self.blipColorTable through kBlipColorType, which it also
-- redeclares as a file-local with two entries appended. Nothing about that is reachable by name
-- from a post-hook, and indexing the table by a guessed enum position would break the moment CBM
-- reorders it. If these ever drift, that file is where to look.
IT.kCBMBiomassFiveColor = Color(0.93, 0, 0.65, 1)

------------------------------------------------------------------------------------------------
-- Lost arms lab upgrades
------------------------------------------------------------------------------------------------
--
-- See ImprovedTooltips_ArmsLabAlert.lua. Vanilla hides the weapon and armour upgrade icons when the
-- team has no working arms lab, which looks exactly like never having researched them. It also
-- contains the code to paint them red instead - unreachable, because the icons are hidden first.

-- Keep the icons on screen, in alert red, while the upgrades are researched but inactive.
IT.kShowLostArmsLabUpgrades = true

-- Vanilla's own alert red, from GUIMarineHUD:Update. Kept as a setting only so it can be toned
-- down; the default is deliberately the shade the game already chose for this state.
IT.kArmsLabLostColor = Color(1, 0, 0, 1)
-- The twelve-bead biomass overlay
------------------------------------------------------------------------------------------------
--
-- See ImprovedTooltips_BiomassOverlay.lua. The bar in the top left, shown with the map, the buy
-- menu or the tech map open. Vanilla reads a single integer for it, so a bead can only pop from
-- empty to full; these draw the research that is already in flight.

-- Partial fill on the beads being researched, and progress meters under the ability icons.
IT.kShowBiomassOverlayProgress = true

-- Tint for the partial bead. It draws the same slice of the same texture as the filled bar, so
-- this is what tells "being researched" apart from "done" - dimmer and slightly transparent, in
-- the manner of a ghost.
IT.kBiomassBeadProgressColor = Color(1, 1, 1, 0.5)

-- Height of an ability progress meter, as a fraction of the icon. GUITechMap uses 10px against its
-- own larger icons; these are a twelfth of the bar, so a fraction keeps the proportion rather than
-- the pixel count.
IT.kBiomassAbilityMeterFraction = 0.18

-- White, to match the tech map. Vanilla never calls SetColor on its own progress meter anywhere in
-- GUITechMap.lua, so it renders at the GUI default - plain white - and the same research reads the
-- same way in both places. Do not "correct" this to the alien palette: the meter is a mechanism,
-- not team furniture, and it was alien yellow here until 2026-09-05 when the inconsistency showed
-- up in game.
IT.kBiomassAbilityMeterColor = Color(1, 1, 1, 1)

-- Colour for an ability icon while its research is in flight. Vanilla's overlay only knows locked
-- and unlocked, so a research under way sits greyed out until the moment it finishes.
--
-- The tech map does not: GUITechMap promotes any node with partial progress straight to
-- kTechStatus.Available - "if researchProgress ~= 0 and researchProgress ~= 1 then status =
-- kTechStatus.Available" - so the icon lights up the moment work starts. This is that same colour,
-- kTechMapIconColors[kAlienTeamType][kTechStatus.Available], so a research in progress looks the
-- same in both places.
--
-- Deliberately its own constant rather than sharing IT.kBiomassIconColor, which happens to hold the
-- same value: that one means "a biomass icon", this one means "being researched". Changing one
-- should not silently change the other.
IT.kBiomassAbilityResearchingColor = Color(1, 0.9, 0.4, 1)
