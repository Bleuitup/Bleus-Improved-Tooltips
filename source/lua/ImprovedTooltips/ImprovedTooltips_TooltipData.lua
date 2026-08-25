-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_TooltipData.lua
--
-- Post-hook on lua/Player_Client.lua. Wraps PlayerUI_GetTooltipDataFromTechId, the one function
-- every commander tooltip in the game goes through, and attaches our extra values to the table it
-- returns.

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Values.lua")

local IT = ImprovedTooltips

-- GUICommanderTooltip:UpdateData is called with positional arguments, so extra fields added to the
-- data table cannot reach the renderer through the normal path. The values are stashed here as
-- well, and read back in ImprovedTooltips_TooltipGUI.lua.
--
-- This is safe because of how GUICommanderTooltip:Update is written: it walks its registered
-- scripts, takes the FIRST non-nil GetTooltipData result and stops calling the rest, then hands
-- that result straight to UpdateData in the same frame. So the last call to this function before
-- UpdateData is always the one being rendered. The GUI hook additionally clears the stash at the
-- top of every Update, so a stale value can never survive into a later frame.
IT.lastValues = nil

local originalGetTooltipDataFromTechId = PlayerUI_GetTooltipDataFromTechId

function PlayerUI_GetTooltipDataFromTechId(techId, hotkeyIndex)

	local tooltipData = originalGetTooltipDataFromTechId(techId, hotkeyIndex)

	if tooltipData then
		tooltipData.improvedTooltipsTechId = techId
		tooltipData.improvedTooltips = IT.GetValues(techId)
		IT.lastValues = tooltipData.improvedTooltips
	end

	return tooltipData

end
