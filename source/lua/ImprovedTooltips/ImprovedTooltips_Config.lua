-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_Config.lua
--
-- Client-side display options. Nothing here affects gameplay, so these are plain constants rather
-- than a config file - flip one and rebuild.
--
-- 1.2 (build 345): the tooltip values, In Cooldown panel, hive status additions, biomass bar,
-- spectator supply, arms lab alert, weapon blip colors, minimap phase gate arrows and exo weapon
-- bars are part of the game now, and their settings went with them.

ImprovedTooltips = ImprovedTooltips or { }
local IT = ImprovedTooltips

IT.kVersion = "1.21"

------------------------------------------------------------------------------------------------
-- Tournament mode ready labels
------------------------------------------------------------------------------------------------
--
-- See ImprovedTooltips_TournamentReady.lua. A glyph and a colored label at the front of each
-- team's scoreboard header while Shine's tournament mode waits for both teams to ready up, in
-- place of the corner pip 1.02 drew on the skill badge. Inert unless that plugin is running, and
-- removed entirely once the round starts.

IT.kShowTournamentReadyLabels = true

-- The labels themselves. Brackets included deliberately: they read as a status marker rather than
-- as part of the team's name, which is the thing immediately to their right.
IT.kReadyLabelText = "[Ready]"
IT.kNotReadyLabelText = "[Not Ready]"

-- Full green and full red. These are the one pair a red/green dichromat cannot separate, which is
-- why the tick and the cross are kept beside them: the shape carries the meaning and the color
-- only reinforces it.
IT.kReadyLabelColor = Color(0, 1, 0, 1)
IT.kNotReadyLabelColor = Color(1, 0, 0, 1)

-- Glyph height as a fraction of the label's own measured text height, so it squares off against
-- the text rather than against the row.
--
-- Two things pull in opposite directions here. A measured text height includes descender space the
-- bracketed label never uses, which argues for a value below 1; but cells 5 and 6 draw their plate
-- inset to pixels 6..52 of a 64 cell, so only 0.72 of whatever this sets is actually inked. At 0.8
-- the visible square came out at 0.58 of the text height and read a shade small beside it. 0.92
-- puts it at 0.66, which sits level with the label's cap height.
IT.kReadyGlyphHeightScale = 0.92

-- Gaps as fractions of the label's own text height: glyph to label, and label to the team name
-- after it. Fractions rather than pixels because a scoreboard mod can set the header in a font of
-- its own choosing, and a gap that stays in proportion to the text looks right in any of them.
-- These reproduce the 6 and 10 pixels they replaced at vanilla's font size.
IT.kReadyGlyphGap = 0.3
IT.kReadyLabelGap = 0.5

------------------------------------------------------------------------------------------------
-- Welder icon on nameplates
------------------------------------------------------------------------------------------------
--
-- See ImprovedTooltips_WelderIcon.lua. A welder icon to the right of a marine teammate's name, so
-- nobody has to ask who has one or hold the scoreboard open to find out. Seen by the marine
-- commander and by marines in the field. On by default, and exposed in the settings panel.

IT.kShowWelderNameplateIcon = true

-- The commander build menu's welder (IT.kBuildMenuTexture), cropped to the drawing inside its 80px
-- cell: left, top, right, bottom, in pixels. The user picked this art on 2026-10-18 from five
-- existing welder icons.
IT.kWelderIconCellInset = { 13, 14, 10, 14 }

-- The build menu art is gray. Multiplied by this it takes the light blue of the kill feed and buy
-- menu welders (205, 245, 255), which is what the user asked for. 80% opaque, from player feedback
-- after the first test (2026-10-18); it was fully opaque before.
IT.kWelderIconColor = Color(205 / 255, 245 / 255, 1, 0.8)

-- Size and place, in units of the name's line height, so the icon keeps its size against the name
-- with small or normal nameplates and at any resolution. The user first chose twice the capitals
-- plus a pixel (1.2 lines, 26 px), then had it scaled by 0.8 after player feedback (2026-10-18):
-- 0.96 lines, about 21 px at 1080p with small nameplates. The gap is 5 px and the center sits on the
-- capitals, both measured on the small-nameplate font at 1080p, where a line is 21.6 px; the center
-- stays put, so the smaller icon shrinks evenly above and below it.
IT.kWelderIconHeight = 0.96
IT.kWelderIconGap = 0.23
IT.kWelderIconCenter = 0.43

-- Seconds between rebuilds of who carries a welder, read from the scoreboard's data.
IT.kWelderIconRefreshInterval = 0.25

------------------------------------------------------------------------------------------------
-- Hotkey labels on the commander buttons
------------------------------------------------------------------------------------------------
--
-- See ImprovedTooltips_HotkeyLabels.lua. The key for each commander tab and grid button, small in
-- its bottom-right corner, as Age of Mythology does. Both teams. OFF by default (the user's call,
-- 2026-10-22), and exposed in the settings panel.

IT.kShowCommanderHotkeyLabels = false

-- Text size relative to the commander GUI's own scale (GUIScale(kCommanderGUIsGlobalScale), what the
-- buttons are sized by), so the labels keep their size against the buttons at any resolution and UI
-- scale. 0.75 gives capitals about 11 px tall on the 81 px buttons of the user's 1080p screenshot,
-- the size approved in the mockup on 2026-10-22.
IT.kHotkeyLabelScale = 0.75

-- Distance of the text's bottom-right corner from the button's, in commander GUI units (scaled the
-- same way). 12 puts it about 5 px inside the corner of the button's bracket frame, as mocked up.
IT.kHotkeyLabelInset = 12

-- Always bright, whether or not the button can be used right now (user's call, 2026-10-22).
IT.kHotkeyLabelColor = Color(0.96, 0.96, 0.96, 1)

------------------------------------------------------------------------------------------------
-- Nutrient mist indicators
------------------------------------------------------------------------------------------------
--
-- See ImprovedTooltips_MistBadge.lua (alien commander) and ImprovedTooltips_MistStatus.lua (the
-- alien HUD's status row). Shown only where the mist is actually doing something; the rule is
-- IT.GetIsMistHelping in ImprovedTooltips_Common.lua. Always on: no settings panel option (the
-- user's call, 2026-10-30).

IT.kShowNutrientMistIndicators = true

-- The commander badge: the tech-tree mist icon tinted green, with the HUD status row's own green up
-- arrow in its bottom-right corner (option C, chosen 2026-10-30). 48 px at 1080p, scaled by GUIScale.
IT.kMistBadgeSize = 48
IT.kMistBadgeColor = Color(140 / 255, 1, 110 / 255, 1)
IT.kMistBadgeArrowFraction = 0.46
-- Gap between the badge's bottom edge and the top of the unit's status plate, in 1080p pixels.
IT.kMistBadgeGap = 4

-- The HUD status row entry: the same mist icon in the alien icon color (kIconColors' alien entry),
-- on the row's own green tile with its up arrow, like Umbra and Energize (option F).
IT.kMistStatusColor = Color(1, 0.9, 0.4, 1)

------------------------------------------------------------------------------------------------
-- Alien shield bar (1.21)
------------------------------------------------------------------------------------------------
--
-- See ImprovedTooltips_ShieldBar.lua. With Centralized HUD bars, an alien's mucous, vampirism and
-- babbler shields as one segmented bar outboard of the health bar, with their total in green
-- underneath; vanilla's corner shield number is hidden meanwhile (ImprovedTooltips_AlienHUD.lua).
-- Settled with the user 2026-11-15; mockups in "Improved Tooltips Images\Shield Bar 1.21".

-- On by default, and exposed in the settings panel.
IT.kShowAlienShieldBar = true

-- How far the shield bar sits inward of a full bar width outboard of the health bar, as a fraction
-- of the bar width. Vanilla's bar art leaves a gap of 46/64 of a bar width between two neighboring
-- bars; the user chose half of that (23/64). One value for every bar texture, since which one is
-- installed cannot be told from Lua: 13 px with vanilla's art, 16 px with ydy's, at 1080p and
-- crosshair scale 1.1.
IT.kShieldBarInward = 23 / 64

-- Segment colors, bottom to top in the order damage eats them last to first: babblers absorb last,
-- mucous first (DamageTypes.lua:303-318). Tinted onto the installed bar art like vanilla's own fills.
IT.kShieldBarBabblerColor = Color(222 / 255, 184 / 255, 120 / 255, 1)   -- tan
IT.kShieldBarVampirismColor = Color(70 / 255, 1, 90 / 255, 1)           -- green
IT.kShieldBarMucousColor = Color(190 / 255, 160 / 255, 1, 1)            -- lavender

-- The total underneath: vanilla's shield number green (GUIAlienHUD.lua kShieldTextColor), in the
-- Centralized bars' font with the same black copy their health text has. Shown whenever there is any
-- shield, and never fades.
IT.kShieldNumberColor = Color(0, 1, 0.2, 1)

-- Gap, in 1080p pixels, between the number's right edge and where vanilla's health text ("99 / 10")
-- starts at its widest for the current lifeform, so the two never overlap.
IT.kShieldNumberGap = 6
