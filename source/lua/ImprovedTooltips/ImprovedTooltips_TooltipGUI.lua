-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_TooltipGUI.lua
--
-- Post-hook on lua/GUICommanderTooltip.lua. Adds two things to the commander tooltip:
--
--   * the top-right icon row gains a research-time and a cooldown entry, alongside vanilla's
--     cost / supply / biomass icons;
--   * a stat row appears under the description text showing health and armor.
--
-- Vanilla's icon row uses hardcoded slots (cost at slot 1, supply at 3, biomass at 5, measured
-- leftward from the right edge in icon-widths), which leaves holes whenever a tech has some but
-- not all of them. Rather than fight that, we let vanilla position everything and then repack the
-- whole row right-to-left over the icons that actually ended up visible.

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Values.lua")

local IT = ImprovedTooltips

local kIconTexture = "ui/bleu_tooltip_icons.dds"

-- Four 64x64 icons laid out in one row. tools/build_icons.ps1 generates the sheet and documents
-- the cell order - keep the two in step.
local kIconCoords = {
	health   = { 0,   0, 64,  64 },
	armor    = { 64,  0, 128, 64 },
	research = { 128, 0, 192, 64 },
	cooldown = { 192, 0, 256, 64 },
}

-- Recomputed on every Initialize, which is also what OnResolutionChanged triggers.
local kStatRowYOffset
local kStatRowHeight
local kStatIconTextGap
local kStatEntryGap

local function UpdateScale()
	kStatRowYOffset  = GUIScale(10)
	kStatRowHeight   = GUICommanderTooltip.kResourceIconSize
	kStatIconTextGap = GUIScale(4)
	kStatEntryGap    = GUIScale(18)
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

-- Builds an icon with a number attached, matching how vanilla builds its cost/supply/biomass
-- entries so the new ones sit correctly beside them.
--
-- textSide "left"  -> number is right-aligned just left of the icon  ("90 [hourglass]")
--                     icon anchors to the panel's RIGHT edge, since the top-right row is
--                     positioned with negative offsets from there.
-- textSide "right" -> number is left-aligned just right of the icon  ("[health] 650")
--                     icon anchors to the panel's LEFT edge, like vanilla's text blocks.
local function CreateIconWithText(coords, textSide)

	local icon = GUIManager:CreateGraphicItem()
	if textSide == "right" then
		icon:SetAnchor(GUIItem.Left, GUIItem.Top)
	else
		icon:SetAnchor(GUIItem.Right, GUIItem.Top)
	end
	icon:SetSize(Vector(GUICommanderTooltip.kResourceIconSize, GUICommanderTooltip.kResourceIconSize, 0))
	icon:SetTexture(kIconTexture)
	icon:SetTexturePixelCoordinates(GUIUnpackCoords(coords))
	icon:SetColor(GetIconColor())
	icon:SetIsVisible(false)

	local text = GUIManager:CreateTextItem()
	text:SetFontSize(GUICommanderTooltip.kCostFontSize)
	text:SetScale(GetScaledVector())
	text:SetColor(Color(1, 1, 1, 1))
	text:SetFontIsBold(true)
	text:SetFontName(Fonts.kAgencyFB_Small)
	text:SetTextAlignmentY(GUIItem.Align_Center)

	if textSide == "right" then
		text:SetAnchor(GUIItem.Right, GUIItem.Top)
		text:SetTextAlignmentX(GUIItem.Align_Min)
		text:SetPosition(Vector(kStatIconTextGap, GUICommanderTooltip.kResourceIconSize / 2, 0))
	else
		text:SetAnchor(GUIItem.Left, GUIItem.Top)
		text:SetTextAlignmentX(GUIItem.Align_Max)
		text:SetPosition(Vector(GUICommanderTooltip.kCostXOffset, GUICommanderTooltip.kResourceIconSize / 2, 0))
	end

	GUIMakeFontScale(text)
	icon:AddChild(text)

	return icon, text

end

local originalInitialize = GUICommanderTooltip.Initialize

function GUICommanderTooltip:Initialize()

	originalInitialize(self)

	UpdateScale()

	-- Parented to self.background, so vanilla's Uninitialize destroys these along with everything
	-- else - no cleanup hook needed.
	self.itResearchIcon, self.itResearchText = CreateIconWithText(kIconCoords.research, "left")
	self.background:AddChild(self.itResearchIcon)

	self.itCooldownIcon, self.itCooldownText = CreateIconWithText(kIconCoords.cooldown, "left")
	self.background:AddChild(self.itCooldownIcon)

	self.itHealthIcon, self.itHealthText = CreateIconWithText(kIconCoords.health, "right")
	self.background:AddChild(self.itHealthIcon)

	self.itArmorIcon, self.itArmorText = CreateIconWithText(kIconCoords.armor, "right")
	self.background:AddChild(self.itArmorIcon)

end

------------------------------------------------------------------------------------------------
-- Layout
------------------------------------------------------------------------------------------------

-- Vanilla's slot formula, from GUICommanderTooltip:Initialize: slot 1 sits at the right edge and
-- each further slot steps two icon-widths left.
local function SetIconSlot(icon, slot)

	local x = -GUICommanderTooltip.kResourceIconSize * (2 * slot - 1) + GUICommanderTooltip.kResourceIconXOffset
	icon:SetPosition(Vector(x, GUICommanderTooltip.kResourceIconYOffset, 0))

end

local function RepackIconRow(self)

	local row = { self.resourceIcon, self.supplyIcon, self.biomassIcon, self.itResearchIcon, self.itCooldownIcon }

	local slot = 1
	for i = 1, #row do
		local icon = row[i]
		if icon and icon:GetIsVisible() then
			SetIconSlot(icon, slot)
			slot = slot + 1
		end
	end

end

-- Mirrors the nextYPosition chain inside vanilla's UpdateData to find where the description text
-- actually ends. Runs after vanilla has positioned everything, so it reads final positions.
local function GetContentBottom(self)

	local y = self.text:GetPosition().y + self.text:GetTextHeight(self.text:GetText()) * self.text:GetScale().y

	if self.requires:GetIsVisible() then
		y = self.requires:GetPosition().y
			+ self.requires:GetTextHeight(self.requires:GetText()) * self.requires:GetScale().y
			+ self.requiresInfo:GetTextHeight(self.requiresInfo:GetText()) * self.requiresInfo:GetScale().y
	end

	if self.enables:GetIsVisible() and string.len(self.enablesInfo:GetText()) > 0 then
		y = self.enables:GetPosition().y
			+ self.enables:GetTextHeight(self.enables:GetText()) * self.enables:GetScale().y
			+ self.enablesInfo:GetTextHeight(self.enablesInfo:GetText()) * self.enablesInfo:GetScale().y
	end

	if self.info:GetIsVisible() then
		y = self.info:GetPosition().y + self.info:GetTextHeight(self.info:GetText()) * self.info:GetScale().y
	end

	return y

end

local function GetEntryWidth(text)
	return GUICommanderTooltip.kResourceIconSize + kStatIconTextGap
		+ text:GetTextWidth(text:GetText()) * text:GetScale().x
end

local function LayoutStatRow(self, values)

	local showHealth = values ~= nil and values.health > 0
	local showArmor = values ~= nil and (values.armor > 0 or (showHealth and IT.kShowZeroArmor))

	self.itHealthIcon:SetIsVisible(showHealth)
	self.itArmorIcon:SetIsVisible(showArmor)

	if not showHealth and not showArmor then
		return
	end

	local y = GetContentBottom(self) + kStatRowYOffset
	local x = GUICommanderTooltip.kTextXOffset

	if showHealth then
		self.itHealthText:SetText(ToString(math.floor(values.health + 0.5)))
		self.itHealthIcon:SetPosition(Vector(x, y, 0))
		x = x + GetEntryWidth(self.itHealthText) + kStatEntryGap
	end

	if showArmor then
		self.itArmorText:SetText(ToString(math.floor(values.armor + 0.5)))
		self.itArmorIcon:SetPosition(Vector(x, y, 0))
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
	local values = IT.lastValues
	if kStatRowHeight and values and (values.health > 0 or values.armor > 0) then
		totalHeight = totalHeight + kStatRowHeight + kStatRowYOffset
	end

	return totalHeight

end

local originalUpdateData = GUICommanderTooltip.UpdateData

function GUICommanderTooltip:UpdateData(text, hotkey, costNumber, requires, enables, info, typeNumber, supplyRequired, biomass)

	originalUpdateData(self, text, hotkey, costNumber, requires, enables, info, typeNumber, supplyRequired, biomass)

	local values = IT.lastValues

	local showResearch = values ~= nil and values.researchTime > 0
	local showCooldown = values ~= nil and values.cooldown > 0

	self.itResearchIcon:SetIsVisible(showResearch)
	if showResearch then
		self.itResearchText:SetText(FormatDuration(values.researchTime))
	end

	self.itCooldownIcon:SetIsVisible(showCooldown)
	if showCooldown then
		self.itCooldownText:SetText(FormatDuration(values.cooldown))
	end

	RepackIconRow(self)
	LayoutStatRow(self, values)

end

-- Clearing here bounds the stash to a single frame: Update clears it, GetTooltipData fills it,
-- UpdateData consumes it. Nothing can leak into the next frame's tooltip.
local originalUpdate = GUICommanderTooltip.Update

function GUICommanderTooltip:Update(deltaTime)

	IT.lastValues = nil
	originalUpdate(self, deltaTime)

end
