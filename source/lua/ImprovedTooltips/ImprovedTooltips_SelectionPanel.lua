-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_SelectionPanel.lua
--
-- Post-hook on lua/GUISelectionPanel.lua. Brings vanilla's selection panel - the one you get when
-- you click an existing structure - in line with the mod's tooltips.
--
-- Vanilla already colours the two NUMBERS differently (kHealthBarColors / kArmorBarColors) but draws
-- both ICONS in one flat team colour, so the cross and the shield look identical while the numbers
-- beside them do not.
--
-- The icons are repointed at the mod's own resampled copies of those same glyphs. They are the same
-- art, so the panel looks unchanged in shape, but they are white and fully opaque - which means the
-- colour can be set exactly (SetColor multiplies, so the original amber could only ever be darkened,
-- never moved onto the cyan of marine armour) and they no longer render at the source's alpha 233,
-- or 149 on the marine atlas.
--
-- Size is deliberately left alone: the panel sets it, and it should keep its own proportions.

if not Client then
	return
end

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Values.lua")

local IT = ImprovedTooltips

local kIconTexture = "ui/bleu_tooltip_icons.dds"
local kIconCoords = {
	health = { 192, 0, 256, 64 },
	armor  = { 256, 0, 320, 64 },
}

local function ApplyIcon(item, coords, color)

	if not item or not color then
		return
	end

	item:SetTexture(kIconTexture)
	item:SetTexturePixelCoordinates(GUIUnpackCoords(coords))
	item:SetColor(color)

end

local originalInitializeSingleSelectionItems = GUISelectionPanel.InitializeSingleSelectionItems

function GUISelectionPanel:InitializeSingleSelectionItems()

	originalInitializeSingleSelectionItems(self)

	if not IT.kTintSelectionPanelIcons then
		return
	end

	-- Same accessor vanilla uses a few lines above, where it colours the text.
	local teamType = PlayerUI_GetTeamType()

	if GUISelectionPanel.kHealthBarColors then
		ApplyIcon(self.healthIcon, kIconCoords.health, GUISelectionPanel.kHealthBarColors[teamType])
	end

	if GUISelectionPanel.kArmorBarColors then
		ApplyIcon(self.armorIcon, kIconCoords.armor, GUISelectionPanel.kArmorBarColors[teamType])
	end

end
