-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_TooltipGUI.lua
--
-- Post-hook on lua/GUICommanderTooltip.lua. Inserts one stat row directly under the tooltip's
-- title, above the description, showing health, armour and research time or cooldown:
--
--     Armor #3 ( C )                    40 [res]
--     [hourglass] 120
--     Gives Marines 60 extra armor
--
-- 0.8 put research time and cooldown in vanilla's top-right icon row instead. That row is
-- positioned right-to-left from the panel edge, so every icon added to it pushes the row a further
-- ~2 icon-widths left - and with a long title the row ran into the title text. Moving our values
-- out of that row entirely fixes the collision at its source, and means a tooltip with no extra
-- data to show is now pixel-identical to vanilla (0.8 also repacked vanilla's own icons, which is
-- no longer needed and has been dropped).
--
-- The panel grows to fit automatically: vanilla's CalculateTotalTextHeight -> UpdateSizeAndPosition
-- sizes the background from its content every frame, so the row only has to declare its height.

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Values.lua")

local IT = ImprovedTooltips

-- Icons come from three places, because the mod ships only what the game does not already have.
--
--   health, armor  - ui/{marine,alien}_commander_textures.dds, the same atlas the tooltip
--                    background uses, at the cells GUISelectionPanel draws when you click an
--                    existing structure (GUISelectionPanel.lua:54-55). Already coloured per team,
--                    so these are NOT tinted at runtime.
--   speed (alien)  - the Celerity icon in ui/buildmenu.dds, index 64 -> cell (4,5). Points right
--                    already; CBM uses the same index for SpurPassive.
--   the rest       - ui/bleu_tooltip_icons.dds, our own 192x64 sheet, white and tinted per team.
--                    See tools/build_icons.ps1; keep the cell order in step with it.
local kOwnIconTexture = "ui/bleu_tooltip_icons.dds"

local kOwnIconCoords = {
	research     = { 0,   0, 64,  64 },
	cooldown     = { 64,  0, 128, 64 },
	speedMarine  = { 128, 0, 192, 64 },
}

local kVanillaIconCoords = {
	health = { 0,  363, 48, 411 },
	armor  = { 48, 363, 96, 411 },
}

-- Celerity, index 64 in a 12-column sheet of 80px cells.
local kCelerityCoords = { 4 * 80, 5 * 80, 5 * 80, 6 * 80 }
local kBuildMenuTexture = "ui/buildmenu.dds"

-- Left-to-right order of the stat row.
local kRowOrder = { "health", "armor", "speed", "research", "cooldown" }

-- Health and armour figures are coloured the way vanilla colours them in the selection panel, so a
-- number means the same thing wherever you read it: marine health pale cyan, marine armour deep
-- teal, alien health yellow, alien armour darker orange.
--
-- Read from GUISelectionPanel at runtime rather than copied, so the mod follows anything that
-- changes them. The literals below are only a fallback for the case where that file has not loaded
-- - they are vanilla's own values (GUISelectionPanel.lua:21-27).
local kFallbackHealthColors = {
	[kMarineTeamType] = Color(0.725, 1, 1, 1),
	[kAlienTeamType]  = Color(1, 197 / 255, 71 / 255, 1),
}

local kFallbackArmorColors = {
	[kMarineTeamType] = Color(0.078, 0.9, 1, 1),
	[kAlienTeamType]  = Color(1, 143 / 255, 34 / 255, 1),
}

local function GetTextColor(field, teamType)

	local vanilla, fallback

	if field == "health" then
		vanilla = GUISelectionPanel and GUISelectionPanel.kHealthBarColors
		fallback = kFallbackHealthColors
	elseif field == "armor" then
		vanilla = GUISelectionPanel and GUISelectionPanel.kArmorBarColors
		fallback = kFallbackArmorColors
	else
		-- Durations and speed have no vanilla precedent to match; plain white.
		return Color(1, 1, 1, 1)
	end

	return (vanilla and vanilla[teamType]) or fallback[teamType] or Color(1, 1, 1, 1)

end

-- Resolves which texture and cell each entry draws from, for the given team. Returns texture,
-- coords, tint - tint nil meaning "leave it alone, the art is already the right colour".
local function GetIconSource(field, teamType, tint)

	if field == "health" or field == "armor" then
		local atlas = (teamType == kAlienTeamType)
			and "ui/alien_commander_textures.dds"
			or  "ui/marine_commander_textures.dds"
		return atlas, kVanillaIconCoords[field], nil
	end

	if field == "speed" then
		if teamType == kAlienTeamType then
			return kBuildMenuTexture, kCelerityCoords, tint
		end
		return kOwnIconTexture, kOwnIconCoords.speedMarine, tint
	end

	return kOwnIconTexture, kOwnIconCoords[field], tint

end

-- Recomputed on every Initialize, which is also what OnResolutionChanged triggers.
local kStatRowYOffset
local kStatRowHeight
local kStatIconTextGap
local kStatEntryGap

local function UpdateScale()
	kStatRowYOffset  = GUIScale(8)
	kStatRowHeight   = GUICommanderTooltip.kResourceIconSize
	kStatIconTextGap = GUIScale(4)
	kStatEntryGap    = GUIScale(20)
end

local function GetIconColor()
	if CommanderUI_IsAlienCommander() then
		return IT.kAlienIconColor
	end
	return IT.kMarineIconColor
end

local function FormatDuration(seconds)

	if IT.kTimeFormat == "clock" then
		local minutes = math.floor(seconds / 60)
		return string.format("%d:%02d", minutes, math.floor(seconds - minutes * 60))
	end

	local rounded = math.floor(seconds + 0.5)

	if IT.kTimeFormat == "suffix" then
		return ToString(rounded) .. "s"
	end

	return ToString(rounded)

end

------------------------------------------------------------------------------------------------
-- Item creation
------------------------------------------------------------------------------------------------

-- One entry: an icon with its number to the right of it, as "[health] 1500".
local function CreateEntry(field, teamType, tint)

	local texture, coords, iconTint = GetIconSource(field, teamType, tint)

	local icon = GUIManager:CreateGraphicItem()
	icon:SetAnchor(GUIItem.Left, GUIItem.Top)
	icon:SetSize(Vector(GUICommanderTooltip.kResourceIconSize, GUICommanderTooltip.kResourceIconSize, 0))
	icon:SetTexture(texture)
	icon:SetTexturePixelCoordinates(GUIUnpackCoords(coords))
	-- Vanilla's health and armour art is already the team's colour, so it is left untinted;
	-- multiplying it again would darken it.
	icon:SetColor(iconTint or Color(1, 1, 1, 1))
	icon:SetIsVisible(false)

	local text = GUIManager:CreateTextItem()
	text:SetFontSize(GUICommanderTooltip.kCostFontSize)
	text:SetScale(GetScaledVector())
	text:SetAnchor(GUIItem.Right, GUIItem.Top)
	text:SetTextAlignmentX(GUIItem.Align_Min)
	text:SetTextAlignmentY(GUIItem.Align_Center)
	text:SetPosition(Vector(kStatIconTextGap, GUICommanderTooltip.kResourceIconSize / 2, 0))
	text:SetColor(GetTextColor(field, teamType))
	text:SetFontIsBold(true)
	text:SetFontName(Fonts.kAgencyFB_Small)
	GUIMakeFontScale(text)
	icon:AddChild(text)

	return { icon = icon, text = text }

end

local originalInitialize = GUICommanderTooltip.Initialize

function GUICommanderTooltip:Initialize()

	originalInitialize(self)

	UpdateScale()

	-- Parented to self.background, so vanilla's Uninitialize destroys these along with everything
	-- else - no cleanup hook needed.
	local teamType = CommanderUI_IsAlienCommander() and kAlienTeamType or kMarineTeamType
	local tint = GetIconColor()

	self.itEntries = { }
	for i = 1, #kRowOrder do
		local field = kRowOrder[i]
		local entry = CreateEntry(field, teamType, tint)
		self.background:AddChild(entry.icon)
		self.itEntries[field] = entry
	end

end

------------------------------------------------------------------------------------------------
-- Layout
------------------------------------------------------------------------------------------------

-- Where vanilla's nextYPosition chain starts, i.e. the bottom of the title line.
local function GetTitleBottom(self)
	return self.text:GetPosition().y + self.text:GetTextHeight(self.text:GetText()) * self.text:GetScale().y
end

local function GetEntryWidth(entry)
	return GUICommanderTooltip.kResourceIconSize + kStatIconTextGap
		+ entry.text:GetTextWidth(entry.text:GetText()) * entry.text:GetScale().x
end

-- Vanilla positions requires/enables/info straight after the title. With a row inserted between,
-- they all move down by the same amount, which preserves the spacing vanilla chose between them.
local function ShiftBlock(item, dy)

	if item:GetIsVisible() then
		local pos = item:GetPosition()
		item:SetPosition(Vector(pos.x, pos.y + dy, 0))
	end

end

local function GetDisplayValue(field, values)

	if field == "health" then
		return values.health > 0 and ToString(math.floor(values.health + 0.5)) or nil
	elseif field == "armor" then
		-- An explicit 0 tells a commander "no armour" rather than "not measured", but only
		-- alongside a health figure - a lone "0" would be meaningless.
		if values.armor > 0 then
			return ToString(math.floor(values.armor + 0.5))
		elseif values.health > 0 and IT.kShowZeroArmor then
			return "0"
		end
		return nil
	elseif field == "speed" then
		if not IT.kShowSpeed or values.speed <= 0 then
			return nil
		end
		-- Speeds are small and fractional (ARC 2.0, Shade 2.5, Shift 2.9, Whip 3.5), so a whole
		-- number would collapse Shade and Shift onto the same figure. One decimal, trimmed when it
		-- is a round number so MAC reads "6" rather than "6.0".
		local speed = values.speed
		if math.abs(speed - math.floor(speed + 0.5)) < 0.05 then
			return ToString(math.floor(speed + 0.5))
		end
		return string.format("%.1f", speed)
	elseif field == "research" then
		return values.researchTime > 0 and FormatDuration(values.researchTime) or nil
	elseif field == "cooldown" then
		return values.cooldown > 0 and FormatDuration(values.cooldown) or nil
	end

	return nil

end

local function LayoutStatRow(self, values)

	local shown = false
	local x = GUICommanderTooltip.kTextXOffset
	local y = GetTitleBottom(self) + kStatRowYOffset

	for i = 1, #kRowOrder do

		local field = kRowOrder[i]
		local entry = self.itEntries[field]
		local display = values and GetDisplayValue(field, values) or nil

		entry.icon:SetIsVisible(display ~= nil)

		if display then
			entry.text:SetText(display)
			entry.icon:SetPosition(Vector(x, y, 0))
			x = x + GetEntryWidth(entry) + kStatEntryGap
			shown = true
		end

	end

	if shown then
		local dy = kStatRowHeight + kStatRowYOffset
		ShiftBlock(self.requires, dy)
		ShiftBlock(self.enables, dy)
		ShiftBlock(self.info, dy)
	end

end

------------------------------------------------------------------------------------------------
-- Hooks
------------------------------------------------------------------------------------------------

-- Vanilla calls this at the top of UpdateData to size the background before anything is
-- positioned, so the stat row has to be accounted for here or it renders outside the panel.
local originalCalculateTotalTextHeight = GUICommanderTooltip.CalculateTotalTextHeight

function GUICommanderTooltip:CalculateTotalTextHeight(text, requires, enables, info)

	local totalHeight = originalCalculateTotalTextHeight(self, text, requires, enables, info)

	-- kStatRowHeight is nil until the first Initialize. In practice Initialize always runs first,
	-- but this is reached from vanilla code we do not control, so do not assume it.
	if kStatRowHeight and IT.lastValues then
		totalHeight = totalHeight + kStatRowHeight + kStatRowYOffset
	end

	return totalHeight

end

local originalUpdateData = GUICommanderTooltip.UpdateData

function GUICommanderTooltip:UpdateData(text, hotkey, costNumber, requires, enables, info, typeNumber, supplyRequired, biomass)

	originalUpdateData(self, text, hotkey, costNumber, requires, enables, info, typeNumber, supplyRequired, biomass)

	LayoutStatRow(self, IT.lastValues)

end

-- Clearing here bounds the stash to a single frame: Update clears it, GetTooltipData fills it,
-- UpdateData consumes it. Nothing can leak into the next frame's tooltip.
local originalUpdate = GUICommanderTooltip.Update

function GUICommanderTooltip:Update(deltaTime)

	IT.lastValues = nil
	originalUpdate(self, deltaTime)

end
