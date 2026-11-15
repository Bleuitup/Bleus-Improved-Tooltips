-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_MistStatus.lua
--
-- Post-hook on lua/Hud/GUIPlayerStatus.lua, the status icon row of the alien HUD (bottom left), which
-- shows Umbra, Enzyme, Mucous, Energize and the rest but had nothing for nutrient mist. Adds a
-- "NutrientMist" entry, shown while the mist is helping the local player, which in practice means
-- evolving in an egg: an embryo is the only player CatalystMixin:GetCanCatalyst lets mist mark. The
-- rule is IT.GetIsMistHelping (ImprovedTooltips_Common.lua). Always on.
--
-- IT LOOKS LIKE THE ROW'S OTHER BUFFS: the row's green tile (kBackgroundGreen) with its up arrow
-- (kArrowUpCoords), around the tech-tree mist icon in the alien icon color. Option F, chosen
-- 2026-10-30.
--
-- REACHING INTO THE ROW. Its entries are a file-local table, statusSettings, built by the file-local
-- CreateStatusIndicator, both used by GUIPlayerStatus:Initialize. They are read out of that method's
-- upvalues with debug.getupvalue, the technique Shine and NSL use for file-locals. If either is not
-- found, nothing is added.
--
--   - The entry is put in statusSettings BEFORE any Initialize, so GetFreeStatus finds it and
--     Initialize gives it a lastStatusState like the rest.
--   - Initialize, alien team only, appends one indicator built by the game's own CreateStatusIndicator.
--   - Update gets the parameters table the alien HUD builds fresh each frame (GUIAlienHUD.lua:930);
--     NutrientMist is set on it before the original runs, and SimpleStatusLogic does the rest:
--     visibility, the pop-in animation, ordering.
--   - CreateStatusIndicator draws the effect arrow from the entry's own texture, which here is the
--     build menu; the arrow is switched back to the status atlas after creation.

if not Client then
	return
end

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Config.lua")
Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Common.lua")

local IT = ImprovedTooltips

if type(GUIPlayerStatus) ~= "table" or type(GUIPlayerStatus.Initialize) ~= "function"
	or type(GUIPlayerStatus.Update) ~= "function" then
	return
end

local kStatusIconsTexture = "ui/player_status_icons.dds"
local kName = "NutrientMist"

-- The values vanilla's GUIPlayerStatus uses, for a build that does not expose them on the class.
local kArrowUpCoords = { 96, 352, 128, 384 }
local kBackgroundGreen = { 64, 576, 128, 640 }

local function FindUpvalue(fn, wanted)

	if type(debug) ~= "table" or type(debug.getupvalue) ~= "function" then
		return nil
	end

	local index = 1

	while true do
		local name, value = debug.getupvalue(fn, index)
		if name == nil then
			return nil
		end
		if name == wanted then
			return value
		end
		index = index + 1
	end

end

local statusSettings = FindUpvalue(GUIPlayerStatus.Initialize, "statusSettings")
local CreateStatusIndicator = FindUpvalue(GUIPlayerStatus.Initialize, "CreateStatusIndicator")

if type(statusSettings) ~= "table" or type(CreateStatusIndicator) ~= "function" then
	return
end

local mistSettings =
{
	Name = kName,
	Texture = IT.kBuildMenuTexture,
	TextureCoordinates = GetTextureCoordinatesForIcon(kTechId.NutrientMist),
	Color = IT.kMistStatusColor,
	Simple = true,
	EffectIconCoords = GUIPlayerStatus.kArrowUpCoords or kArrowUpCoords,
	StatusBackgroundCoords = GUIPlayerStatus.kBackgroundGreen or kBackgroundGreen,
}

statusSettings[kName] = mistSettings

local failed = false

local function Report(err)
	failed = true
	Print("[Bleu's Improved Tooltips] nutrient mist status icon disabled after an error: %s", tostring(err))
end

local function AddIndicator(self)

	if self.teamNum ~= kTeam2Index or type(self.statusIcons) ~= "table" then
		return
	end

	local indicator = CreateStatusIndicator(self, mistSettings)

	if indicator.EffectIcon then
		indicator.EffectIcon:SetTexture(kStatusIconsTexture)
		indicator.EffectIcon:SetTexturePixelCoordinates(GUIUnpackCoords(mistSettings.EffectIconCoords))
	end

	table.insert(self.statusIcons, indicator)

end

local originalInitialize = GUIPlayerStatus.Initialize

function GUIPlayerStatus:Initialize()

	originalInitialize(self)

	if failed then
		return
	end

	local ok, err = pcall(AddIndicator, self)

	if not ok then
		Report(err)
	end

end

local function GetLocalPlayerMisted()

	local player = Client.GetLocalPlayer()

	return IT.kShowNutrientMistIndicators and player ~= nil and player:isa("Alien") and IT.GetIsMistHelping(player)

end

local originalUpdate = GUIPlayerStatus.Update

function GUIPlayerStatus:Update(deltaTime, parameters, fullMode)

	if not failed and self.teamNum == kTeam2Index and type(parameters) == "table" then

		local ok, misted = pcall(GetLocalPlayerMisted)

		if ok then
			parameters[kName] = misted == true
		else
			Report(misted)
		end

	end

	return originalUpdate(self, deltaTime, parameters, fullMode)

end
