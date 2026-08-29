-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_SelectionPanel.lua
--
-- Post-hook on lua/GUISelectionPanel.lua. Tints the health and armour icons on vanilla's selection
-- panel - the one you get when you click an existing structure - to match their own figures.
--
-- Vanilla already colours the two NUMBERS differently (kHealthBarColors / kArmorBarColors) but
-- draws both ICONS in one flat team colour, so the cross and the shield look identical while the
-- numbers beside them do not. This makes the icon agree with its number, in the same way and with
-- the same maths the mod's own tooltips use.
--
-- Kept in step with ImprovedTooltips_TooltipGUI.lua: same measured art base, same divide-and-clamp.
-- If the tint changes in one place, change it in the other.

if not Client then
	return
end

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Values.lua")

local IT = ImprovedTooltips

-- Brightest pixels of the health/armour cells in ui/{marine,alien}_commander_textures.dds.
local kIconArtBase = {
	[kMarineTeamType] = Color(152 / 255, 186 / 255, 195 / 255, 1),
	[kAlienTeamType]  = Color(244 / 255, 185 / 255, 55 / 255, 1),
}

local function GetTint(targetColor, teamType)

	local base = kIconArtBase[teamType]
	if not base or not targetColor then
		return nil
	end

	local function channel(t, b)
		if b <= 0 then
			return 1
		end
		return math.min(1, t / b)
	end

	return Color(channel(targetColor.r, base.r), channel(targetColor.g, base.g), channel(targetColor.b, base.b), 1)

end

local originalInitializeSingleSelectionItems = GUISelectionPanel.InitializeSingleSelectionItems

function GUISelectionPanel:InitializeSingleSelectionItems()

	originalInitializeSingleSelectionItems(self)

	if not IT.kTintSelectionPanelIcons then
		return
	end

	-- Vanilla derives teamType the same way a few lines above where it colours the text.
	local teamType = PlayerUI_GetTeamType()

	if self.healthIcon and GUISelectionPanel.kHealthBarColors then
		local tint = GetTint(GUISelectionPanel.kHealthBarColors[teamType], teamType)
		if tint then
			self.healthIcon:SetColor(tint)
		end
	end

	if self.armorIcon and GUISelectionPanel.kArmorBarColors then
		local tint = GetTint(GUISelectionPanel.kArmorBarColors[teamType], teamType)
		if tint then
			self.armorIcon:SetColor(tint)
		end
	end

end
