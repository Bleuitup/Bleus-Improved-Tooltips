-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_ShieldBar.lua
--
-- Post-hook on lua/GUIAdvancedHUDBars.lua, the Centralized and NS1 HUD bars. With Centralized bars on
-- the alien team, adds a shield bar outboard of the health bar: mucous, vampirism and babbler shields
-- as colored segments, with their total in green underneath. 1.21.
--
-- WHAT VANILLA SHOWS. PlayerUI_GetMucousShieldHP (Alien_Client.lua:330) adds up the three shields,
-- each rounded up, and the maxima of only the shields currently above zero. The default HUD draws one
-- ring at that ratio, so a full ring can mean anything from a full vampirism charge alone to all three
-- shields at their caps. With Centralized or NS1 bars even the ring is hidden (GUIAlienHUD.lua:563)
-- and only the green number in the corner is left.
--
-- THE SCALE (the user's design, 2026-11-15). A full bar is the most shield the lifeform can carry
-- at biomass 1: mucous + babblers + vampirism, each at its cap, vampirism counted even without the
-- upgrade. So a given fill always means the same amount of shield for a lifeform. About 52 for a
-- skulk, 61 gorge, 66 lerk, 118 fade and 198 onos on build 345. At biomass 1 max health is base
-- health (BiomassHealthMixin), and only the vampirism cap depends on max health, so it is scaled
-- back by base / max. Anything over a full bar - only possible at a higher biomass with all three
-- nearly full - is cut off at the top, which is mucous, the shield that empties first.
--
-- THE ART is whatever ui/centerhudbar.dds is installed, drawn the way vanilla draws its own bars, so
-- a bar texture mod (ydy and the like) restyles this bar too. Same size and height as the health
-- bar, one bar width outboard of it less IT.kShieldBarInward.
--
-- Everything here is plain GUI items owned by this file, created after vanilla's Initialize and
-- destroyed before its Uninitialize. Reset (resolution changes, team swaps) runs both, so the bar is
-- rebuilt along with vanilla's. Nothing of vanilla's is changed.

if not Client then
	return
end

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Config.lua")

local IT = ImprovedTooltips

if type(GUIAdvancedHUDBars) ~= "table" or type(GUIAdvancedHUDBars.Initialize) ~= "function"
	or type(GUIAdvancedHUDBars.Uninitialize) ~= "function" or type(GUIAdvancedHUDBars.Update) ~= "function" then
	return
end

local kCentralized = 1
local kTexture = PrecacheAsset("ui/centerhudbar.dds")

-- centerhudbar.dds regions in Centralized mode (GUIAdvancedHUDBars.lua:66-67): the empty track, and
-- the fill, whose rows 127 (bottom) to 0 (top) are cropped to the filled share.
local kTrackCoords = { 0, 255, 63, 127 }
local kFillBottom = 127

local kWhite = Color(1, 1, 1, 1)
local kBlack = Color(0, 0, 0, 1)

-- Bottom to top: the order damage reaches them, last to first.
local kSegments = { "babbler", "vampirism", "mucous" }

local kSegmentColorField =
{
	babbler = "kShieldBarBabblerColor",
	vampirism = "kShieldBarVampirismColor",
	mucous = "kShieldBarMucousColor",
}

-- Methods are called only if present, and under pcall: GetMaxOverShieldAmount indexes a table of
-- class scalars with no entry for Embryo and does nil * 3, and nothing here may throw into the HUD.
local function SafeNumber(object, methodName)

	local method = object[methodName]
	if type(method) ~= "function" then
		return 0
	end

	local ok, value = pcall(method, object)
	return (ok and type(value) == "number") and value or 0

end

-- Fills `reading` in place: each shield rounded up as vanilla rounds it, their total, and the
-- full bar (see THE SCALE above).
local function ReadShields(player, reading)

	reading.mucous = math.ceil(SafeNumber(player, "GetMuscousShieldAmount"))
	reading.babbler = math.ceil(SafeNumber(player, "GetBabblerShieldAmount"))
	reading.vampirism = HasMixin(player, "Shieldable") and math.ceil(SafeNumber(player, "GetOverShieldAmount")) or 0
	reading.total = reading.mucous + reading.babbler + reading.vampirism

	local vampirismCap = SafeNumber(player, "GetMaxOverShieldAmount")
	local baseHealth = SafeNumber(player, "GetBaseHealth")
	local maxHealth = SafeNumber(player, "GetMaxHealth")
	if baseHealth > 0 and maxHealth > 0 then
		vampirismCap = vampirismCap * baseHealth / maxHealth
	end

	reading.full = SafeNumber(player, "GetMaxShieldAmount") + SafeNumber(player, "GetMaxBabblerShieldAmount") + vampirismCap

	return reading

end

local function NewBarItem()

	local item = GUIManager:CreateGraphicItem()
	item:SetAnchor(GUIItem.Middle, GUIItem.Center)
	item:SetLayer(kGUILayerPlayerHUD)
	item:SetTexture(kTexture)
	item:SetIsVisible(false)
	return item

end

local function NewTextItem(color)

	local item = GUIManager:CreateTextItem()
	item:SetAnchor(GUIItem.Middle, GUIItem.Center)
	item:SetLayer(kGUILayerPlayerHUD)
	item:SetFontName(Fonts.kAgencyFB_Tiny)
	item:SetScale(GetScaledVector())
	GUIMakeFontScale(item)
	item:SetTextAlignmentX(GUIItem.Align_Max)
	item:SetColor(color)
	item:SetIsVisible(false)
	return item

end

-- Geometry, recomputed the way GUIAdvancedHUDBars:Initialize computes its own (:52-62). The bars
-- only scale with the crosshair when it is scaled up.
local function BuildShieldBar(self)

	local crosshairScale = GetAdvancedOption("crosshairscale")
	crosshairScale = (type(crosshairScale) == "number" and crosshairScale > 1) and crosshairScale or 1

	local width = GUIScale(32) * crosshairScale
	local height = GUIScale(64) * crosshairScale
	local healthBarX = -GUIScale(32) * crosshairScale - width

	-- Attached first, so a failure partway through still leaves DestroyShieldBar everything made so far.
	local bar = { fills = { } }
	self.itShieldBar = bar

	bar.x = healthBarX - width + IT.kShieldBarInward * width
	bar.bottom = height / 2
	bar.width = width
	bar.height = height

	-- Vanilla's health text is centered here, with its black copy GUIScale(2) down and right (:113-131).
	bar.healthTextCenterX = healthBarX / 2 - GUIScale(12)
	bar.textY = height / 2 + GUIScale(8)
	bar.shadowOffset = GUIScale(2)

	bar.track = NewBarItem()
	bar.track:SetTexturePixelCoordinates(kTrackCoords[1], kTrackCoords[2], kTrackCoords[3], kTrackCoords[4])
	bar.track:SetPosition(Vector(bar.x, bar.bottom, 0))
	bar.track:SetSize(Vector(width, -height, 0))
	bar.track:SetColor(kWhite)

	for i = 1, #kSegments do
		bar.fills[kSegments[i]] = NewBarItem()
	end

	bar.shadow = NewTextItem(kBlack)
	bar.text = NewTextItem(IT.kShieldNumberColor)

	bar.reading = { }
	bar.lastTotal = -1
	bar.lastTemplate = nil

end

local function DestroyShieldBar(self)

	local bar = self.itShieldBar
	if not bar then
		return
	end
	self.itShieldBar = nil

	local items = { bar.track, bar.shadow, bar.text }
	for _, item in pairs(bar.fills) do
		items[#items + 1] = item
	end
	for _, item in pairs(items) do
		GUI.DestroyItem(item)
	end

end

local function HideShieldBar(bar)

	bar.track:SetIsVisible(false)
	for _, item in pairs(bar.fills) do
		item:SetIsVisible(false)
	end
	bar.shadow:SetIsVisible(false)
	bar.text:SetIsVisible(false)

end

-- The number's right edge sits IT.kShieldNumberGap left of where vanilla's health text starts at its
-- widest for this lifeform: its max health and armor written with zeros (the widest digit in that
-- font is no narrower than any other), measured in the number's own font and scale.
local function PlaceNumber(bar, player)

	local template = string.format("%d / %d", math.floor(SafeNumber(player, "GetMaxHealth")),
		math.floor(SafeNumber(player, "GetMaxArmor"))):gsub("%d", "0")

	if template == bar.lastTemplate then
		return
	end
	bar.lastTemplate = template

	local width = bar.text:GetTextWidth(template) * bar.text:GetScale().x
	local right = bar.healthTextCenterX - width / 2 - GUIScale(IT.kShieldNumberGap)

	bar.text:SetPosition(Vector(right, bar.textY, 0))
	bar.shadow:SetPosition(Vector(right + bar.shadowOffset, bar.textY + bar.shadowOffset, 0))

end

local function UpdateShieldBar(self)

	local bar = self.itShieldBar
	if not bar then
		return
	end

	local player = Client.GetLocalPlayer()

	if not IT.kShowAlienShieldBar or not self.vis or not player or not player:GetIsAlive()
		or not player:isa("Alien") or player:isa("Embryo") then
		HideShieldBar(bar)
		return
	end

	local reading = ReadShields(player, bar.reading)

	-- Nothing at all: no bar and no number, like vanilla's ring and number.
	if reading.total <= 0 then
		HideShieldBar(bar)
		return
	end

	local full = reading.full > 0 and reading.full or reading.total

	bar.track:SetIsVisible(true)

	local from = 0
	for i = 1, #kSegments do

		local source = kSegments[i]
		local item = bar.fills[source]
		local to = math.min(from + reading[source] / full, 1)

		if to > from then
			-- As vanilla's armor bar sits on its health bar (GUIAdvancedHUDBars.lua:372-385): placed at
			-- the segment's bottom, drawn upward, with the art cropped to the same share of the bar.
			item:SetPosition(Vector(bar.x, bar.bottom - bar.height * from, 0))
			item:SetSize(Vector(bar.width, -bar.height * (to - from), 0))
			item:SetTexturePixelCoordinates(0, kFillBottom - kFillBottom * from, 63, kFillBottom - kFillBottom * to)
			item:SetColor(IT[kSegmentColorField[source]])
			item:SetIsVisible(true)
		else
			item:SetIsVisible(false)
		end

		from = to

	end

	PlaceNumber(bar, player)

	if reading.total ~= bar.lastTotal then
		bar.lastTotal = reading.total
		local text = tostring(reading.total)
		bar.text:SetText(text)
		bar.shadow:SetText(text)
	end
	bar.text:SetIsVisible(true)
	bar.shadow:SetIsVisible(true)

end

local originalInitialize = GUIAdvancedHUDBars.Initialize
function GUIAdvancedHUDBars:Initialize()

	originalInitialize(self)

	if self.team == kTeam2Index and GetAdvancedOption("hudbars_a") == kCentralized then
		local ok, err = pcall(BuildShieldBar, self)
		if not ok then
			Shared.Message("[Bleu's Improved Tooltips] shield bar not built: " .. tostring(err))
			DestroyShieldBar(self)
		end
	end

end

local originalUninitialize = GUIAdvancedHUDBars.Uninitialize
function GUIAdvancedHUDBars:Uninitialize()

	DestroyShieldBar(self)
	originalUninitialize(self)

end

local originalUpdate = GUIAdvancedHUDBars.Update
function GUIAdvancedHUDBars:Update(deltaTime)

	originalUpdate(self, deltaTime)

	-- One report, then the bar is dropped: a fault here must not spam the log or reach the HUD.
	local ok, err = pcall(UpdateShieldBar, self)
	if not ok then
		Shared.Message("[Bleu's Improved Tooltips] shield bar removed after an error: " .. tostring(err))
		DestroyShieldBar(self)
	end

end
