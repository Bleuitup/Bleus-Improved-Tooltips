-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_AdvancedHUDBars.lua
--
-- Post-hook on lua/GUIAdvancedHUDBars.lua, the Centralized and NS1 HUD bars. Everything here applies
-- to the CENTRALIZED mode only (hudbars 1); NS1 (2) is left as vanilla draws it. Three jobs:
--
--   1. OPACITY, both teams (1.06). The bars are redrawn as stacked copies of their own art at the
--      Mods panel opacity; see ImprovedTooltips_BarLayers.lua. Default fully opaque, floor = vanilla.
--   2. ALIEN SHIELD BAR (1.06). Mucous, vampirism and babbler shields as one segmented bar outboard
--      of the health bar, with their sum in green underneath; see ImprovedTooltips_AlienShields.lua.
--      Vanilla hides its shield ring in this mode and leaves only a corner number.
--   3. EXO WEAPON BAR HIDING (1.05). While the mod's exo weapon bars show, vanilla's right-hand weapon
--      bar and its number are hidden, so a pilot does not get two readouts beside the crosshair.
--
-- HOW THE OPACITY LAYERS FOLLOW VANILLA. Vanilla's Update sets size, texture region, color and
-- visibility on its items every frame (GUIAdvancedHUDBars.lua:246-400). After it runs, each item is
-- read back and copied onto its layers, and the vanilla item itself is hidden - the layers draw it,
-- in vanilla's order, so the tracks stay underneath the fills. Pulsing red, damage, energy and death
-- all carry over with no knowledge of why vanilla set them. In this mode every bar item uses
-- ui/centerhudbar.dds and a Middle/Center anchor (:63-110), so the copies need no more than that.
--
-- Any error in the mod's part disables that part for the rest of the session and leaves vanilla's
-- own bars showing, rather than a missing HUD.
--
-- Mode is cached at Initialize: changing HUD bars restarts GUIMarineHUD / GUIAlienHUD, which recreate
-- this script (AdvancedOptions.lua:328, GUIMarineHUD.lua:583-591, GUIAlienHUD.lua:245-252). Changing
-- the mod's own bar settings calls Reset, which re-runs Initialize. Neither CBM nor B2TP replaces this
-- file.

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_ExoBarsState.lua")
Script.Load("lua/ImprovedTooltips/ImprovedTooltips_AlienShields.lua")
Script.Load("lua/ImprovedTooltips/ImprovedTooltips_BarLayers.lua")

local IT = ImprovedTooltips

if type(GUIAdvancedHUDBars) ~= "table" or type(GUIAdvancedHUDBars.Update) ~= "function" then
	return
end

local kCentralized = 1
local kBarTexture = "ui/centerhudbar.dds"

-- Vanilla's creation order, which is also the draw order the copies must keep.
local kBarItems = { "leftBarBg", "healthBar", "armorBar", "rightBarBg", "rightBar" }
local kRightSideItems = { rightBarBg = true, rightBar = true }

-- The shield bar's track and fill regions of centerhudbar.dds in Centralized mode (:66-67).
local kTrackTexCoords = { 0, 255, 63, 127 }

local kWhite = Color(1, 1, 1, 1)

local function Report(what, err)
	Shared.Message(string.format("[Improved Tooltips] Centralized bars: %s disabled after an error: %s", what, tostring(err)))
end

------------------------------------------------------------------------------------------------------
-- Opacity layers
------------------------------------------------------------------------------------------------------

local function BuildLayers(self)

	local count, factor = IT.GetBarLayering((IT.kCentralizedBarOpacity or 1))
	if IT.GetBarLayeringIsVanilla(count, factor) then
		return
	end

	self.itLayerCount = count
	self.itLayerFactor = factor
	self.itLayers = { }

	for _, field in ipairs(kBarItems) do
		if self[field] then
			self.itLayers[field] = IT.CreateBarCopies(self, count, kBarTexture)
		end
	end

end

local function SyncLayers(self, hideRightSide)

	for _, field in ipairs(kBarItems) do

		local item = self[field]
		local copies = self.itLayers[field]

		if item and copies then
			IT.MirrorBarItem(item, copies, self.itLayerFactor, hideRightSide and kRightSideItems[field])
			item:SetIsVisible(false)
		end

	end

end

local function DropLayers(self)

	for _, copies in pairs(self.itLayers or { }) do
		IT.HideBarCopies(copies)
	end

	self.itLayers = nil

end

------------------------------------------------------------------------------------------------------
-- Alien shield bar
------------------------------------------------------------------------------------------------------

-- Geometry is read off vanilla's own left bar background, so resolution and crosshair scale come out
-- exactly as vanilla's bars do. That item is a 32x64 quad (times the scale) with a negative height,
-- growing upward from its position.
local function BuildShieldBar(self)

	local bg = self.leftBarBg.guiItem
	local position = bg:GetPosition()
	local size = bg:GetSize()

	local width = math.abs(size.x)
	local height = math.abs(size.y)
	local unit = width / 32

	local shield = { }
	shield.style = IT.kShieldBarStyle or 0
	shield.bottom = position.y
	shield.height = height
	shield.reading = IT.NewAlienShieldReading()
	shield.segments = { }
	shield.fills = { }

	local count = self.itLayerCount or 1
	local factor = self.itLayerFactor or 1
	shield.count, shield.factor = count, factor

	if shield.style == IT.kShieldStyleYdy then

		-- The ydy stroke, one stroke outboard of the ydy health bar: the ydy art sits on the outer
		-- 5 of its 32 units (texels 0-9 of 64), so this is 5 units wide, 5 units further out.
		shield.x = position.x - (IT.kShieldYdyGap + IT.kShieldYdyWidth) * unit
		shield.width = IT.kShieldYdyWidth * unit
		shield.centerX = shield.x + shield.width / 2

		local edge = math.max(1, math.floor(unit + 0.5))
		local edgeAlpha = IT.GetLayeredAlpha(IT.kShieldYdyEdgeAlpha, count, factor)
		shield.inset = edge / 2

		shield.edges = { }
		for i, x in ipairs({ shield.x, shield.x + shield.width - edge }) do
			local item = self:CreateAnimatedGraphicItem()
			item:SetAnchor(GUIItem.Middle, GUIItem.Center)
			item:SetLayer(kGUILayerPlayerHUD)
			item:SetIsScaling(false)
			item:SetColor(Color(1, 1, 1, edgeAlpha))
			item:SetSize(Vector(edge, -height, 0))
			item:SetPosition(Vector(x, shield.bottom, 0))
			item:SetIsVisible(false)
			shield.edges[i] = item
		end

		for _, source in ipairs(IT.kAlienShieldOrder) do
			shield.fills[source] = IT.CreateBarCopies(self, 1, nil)
		end

	else

		-- A third centerhudbar quad, one quad-width outboard of the health bar, in whatever bar art
		-- is installed - vanilla's, or a bar texture mod's.
		shield.x = position.x - width
		shield.width = width
		shield.centerX = shield.x + width / 2

		shield.track = IT.CreateBarCopies(self, count, kBarTexture)
		for _, source in ipairs(IT.kAlienShieldOrder) do
			shield.fills[source] = IT.CreateBarCopies(self, count, kBarTexture)
		end

	end

	-- The total. Same font as vanilla's Centralized health/armor text (GUIAdvancedHUDBars.lua:29, :112-134),
	-- in the green vanilla uses for its shield number (GUIAlienHUD.lua:114). Right-aligned just past the
	-- bar's center so it grows outward, away from vanilla's health text, as the number gets longer.
	local text = self:CreateAnimatedTextItem()
	text:SetAnchor(GUIItem.Middle, GUIItem.Center)
	text:SetFontName(Fonts.kAgencyFB_Tiny)
	text:SetTextAlignmentX(GUIItem.Align_Max)
	text:SetLayer(kGUILayerPlayerHUD)
	text:SetIsScaling(false)
	text:SetColor(IT.kShieldNumberColor)
	text:SetPosition(Vector(shield.centerX + IT.kShieldNumberOffsetX * unit, shield.bottom + IT.kShieldNumberGap * unit, 0))
	text:SetScale(GetScaledVector())
	GUIMakeFontScale(text)
	text:SetIsVisible(false)
	shield.text = text
	shield.lastTotal = -1

	self.itShield = shield

end

local function HideShieldBar(shield)

	if shield.track then IT.HideBarCopies(shield.track) end
	if shield.edges then
		for _, item in ipairs(shield.edges) do item:SetIsVisible(false) end
	end
	for _, copies in pairs(shield.fills) do IT.HideBarCopies(copies) end
	shield.text:SetIsVisible(false)

end

local function UpdateShieldBar(self, barsVisible)

	local shield = self.itShield
	local player = Client.GetLocalPlayer()

	if not barsVisible or not IT.kShowCentralizedShields or not player or not player:isa("Alien") then
		HideShieldBar(shield)
		return
	end

	local reading = IT.ReadAlienShields(player, shield.reading)

	if reading.total <= 0 then
		HideShieldBar(shield)
		return
	end

	IT.GetAlienShieldSegments(player, reading, IT.kShieldBarScale or IT.kShieldScaleRelative, shield.segments)

	local bottom, height = shield.bottom, shield.height

	if shield.style == IT.kShieldStyleYdy then

		for _, item in ipairs(shield.edges) do item:SetIsVisible(true) end

		for _, source in ipairs(IT.kAlienShieldOrder) do
			local from, to = shield.segments[source][1], shield.segments[source][2]
			local length = (to - from) * height
			IT.SetBarCopies(shield.fills[source],
				Vector(shield.x + shield.inset, bottom - from * height, 0),
				Vector(shield.width - 2 * shield.inset, -math.max(1, length), 0),
				nil, IT.kShieldColors[source], length >= 0.5, 1)
		end

	else

		IT.SetBarCopies(shield.track, Vector(shield.x, bottom, 0), Vector(shield.width, -height, 0),
			kTrackTexCoords, kWhite, true, shield.factor)

		for _, source in ipairs(IT.kAlienShieldOrder) do
			local from, to = shield.segments[source][1], shield.segments[source][2]
			local length = (to - from) * height
			-- Vanilla stacks its armor on its health the same way (:372-380).
			IT.SetBarCopies(shield.fills[source],
				Vector(shield.x, bottom - from * height, 0),
				Vector(shield.width, -math.max(1, length), 0),
				{ 0, 127 - 127 * from, 63, 127 - 127 * to },
				IT.kShieldColors[source], length >= 0.5, shield.factor)
		end

	end

	if reading.total ~= shield.lastTotal then
		shield.text:SetText(tostring(reading.total))
		shield.lastTotal = reading.total
	end
	shield.text:SetIsVisible(true)

end

------------------------------------------------------------------------------------------------------
-- Hooks
------------------------------------------------------------------------------------------------------

local originalInitialize = GUIAdvancedHUDBars.Initialize

function GUIAdvancedHUDBars:Initialize(...)

	originalInitialize(self, ...)

	local player = Client.GetLocalPlayer()
	local team = player and player:GetTeamNumber()
	local isMarine = team == kTeam1Index
	local mode = GetAdvancedOption(isMarine and "hudbars_m" or "hudbars_a")

	self.itIsCentralized = mode == kCentralized
	self.itIsCentralizedMarine = self.itIsCentralized and isMarine
	self.itIsCentralizedAlien = self.itIsCentralized and team == kTeam2Index

	if not self.itIsCentralized then
		return
	end

	local ok, err = pcall(BuildLayers, self)
	if not ok then
		Report("opacity", err)
		DropLayers(self)
	end

	if self.itIsCentralizedAlien and IT.kShowCentralizedShields then
		ok, err = pcall(BuildShieldBar, self)
		if not ok then
			Report("shield bar", err)
			self.itShield = nil
		end
	end

end

local kExoRightSideText = { "ammoText", "ammoTextBg" }

local originalUpdate = GUIAdvancedHUDBars.Update

function GUIAdvancedHUDBars:Update(deltaTime)

	originalUpdate(self, deltaTime)

	if not self.itIsCentralized then
		return
	end

	-- Read before the layers hide vanilla's items.
	local barsVisible = self.leftBarBg and self.leftBarBg:GetIsVisible()
	local hideRightSide = self.itIsCentralizedMarine and IT.GetExoWeaponBarsActive()

	if self.itLayers then
		local ok, err = pcall(SyncLayers, self, hideRightSide)
		if not ok then
			Report("opacity", err)
			DropLayers(self)
		end
	end

	if hideRightSide then
		if not self.itLayers then
			for field in pairs(kRightSideItems) do
				if self[field] then self[field]:SetIsVisible(false) end
			end
		end
		for _, field in ipairs(kExoRightSideText) do
			if self[field] then self[field]:SetIsVisible(false) end
		end
	end

	if self.itShield then
		local ok, err = pcall(UpdateShieldBar, self, barsVisible)
		if not ok then
			Report("shield bar", err)
			pcall(HideShieldBar, self.itShield)
			self.itShield = nil
		end
	end

end
