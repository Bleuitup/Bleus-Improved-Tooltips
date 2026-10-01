-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_InsightTopBar.lua
--
-- Post-hook on lua/GUIInsight_TopBar.lua, the bar across the top of spectator view. Colors its
-- biomass counter to match the biomass icons everywhere else, which vanilla leaves as the bare
-- grayscale atlas cell.
--
-- This one costs more machinery than it looks like it should, because nothing in GUIInsight_TopBar
-- is reachable from outside it. Every item is a file-local - `background`, `alienBiomass` and the
-- rest - and not one field is stored on self, so there is nothing to walk down from. The icon is
-- built inside a local CreateIconTextItem which returns only the text item, so even the value the
-- file keeps is the wrong half of the pair.
--
-- So the items are caught as they are made, with IT.CaptureCreatedGraphicItems (see
-- ImprovedTooltips_Common.lua for how that stays safe).
--
-- Identifying the right item is exact rather than positional: "ui/buildmenu.dds" is used precisely
-- once in that file, for the biomass icon. Everything else on the bar comes from the marine or
-- alien insight sheets. So the one created item drawing from the build menu atlas is the one.

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Values.lua")

local IT = ImprovedTooltips

local originalInitialize = GUIInsight_TopBar.Initialize

function GUIInsight_TopBar:Initialize()

	if not IT.kColorSpectatorBiomass or not IT.kBiomassIconColor then
		return originalInitialize(self)
	end

	local created = IT.CaptureCreatedGraphicItems(originalInitialize, self)

	for i = 1, #created do
		if IT.GetItemTexture(created[i]) == IT.kBuildMenuTexture then
			created[i]:SetColor(IT.kBiomassIconColor)
		end
	end

end
