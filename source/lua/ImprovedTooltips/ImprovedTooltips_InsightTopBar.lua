-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_InsightTopBar.lua
--
-- Post-hook on lua/GUIInsight_TopBar.lua, the bar across the top of spectator view. Colours its
-- biomass counter to match the biomass icons everywhere else, which vanilla leaves as the bare
-- greyscale atlas cell.
--
-- This one costs more machinery than it looks like it should, because nothing in GUIInsight_TopBar
-- is reachable from outside it. Every item is a file-local - `background`, `alienBiomass` and the
-- rest - and not one field is stored on self, so there is nothing to walk down from. The icon is
-- built inside a local CreateIconTextItem which returns only the text item, so even the value the
-- file keeps is the wrong half of the pair.
--
-- So the items are caught as they are made: GUIManager.CreateGraphicItem is wrapped for exactly the
-- duration of Initialize, the items created during it are collected, and the wrapper is put back.
-- Lua is single threaded and Initialize is synchronous, so nothing else can be creating items in
-- that window, and the original method is restored on the error path too.
--
-- Identifying the right item is exact rather than positional: "ui/buildmenu.dds" is used precisely
-- once in that file, for the biomass icon. Everything else on the bar comes from the marine or
-- alien insight sheets. So the one created item drawing from the build menu atlas is the one.

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Values.lua")

local IT = ImprovedTooltips

local kBuildMenuTexture = "ui/buildmenu.dds"

local originalInitialize = GUIInsight_TopBar.Initialize

function GUIInsight_TopBar:Initialize()

	if not IT.kColorSpectatorBiomass or not IT.kBiomassIconColor then
		return originalInitialize(self)
	end

	local manager = GUIManager
	local originalCreateGraphicItem = manager and manager.CreateGraphicItem

	if type(originalCreateGraphicItem) ~= "function" then
		return originalInitialize(self)
	end

	local created = { }

	manager.CreateGraphicItem = function(...)
		local item = originalCreateGraphicItem(...)
		created[#created + 1] = item
		return item
	end

	local ok, err = pcall(originalInitialize, self)

	-- Restored before anything else, including before re-raising.
	manager.CreateGraphicItem = originalCreateGraphicItem

	if not ok then
		error(err)
	end

	for i = 1, #created do

		local item = created[i]
		local ready = item and type(item.GetTexture) == "function" and type(item.SetColor) == "function"

		if ready and item:GetTexture() == kBuildMenuTexture then
			item:SetColor(IT.kBiomassIconColor)
		end

	end

end
