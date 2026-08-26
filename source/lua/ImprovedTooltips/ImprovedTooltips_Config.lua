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

-- Icon tint. One white icon set is tinted per team so it sits correctly on either commander HUD.
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
