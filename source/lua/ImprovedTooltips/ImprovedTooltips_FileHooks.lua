-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_FileHooks.lua
--
-- Registers the two post-hooks that make up the whole mod. Both target files that only exist in
-- the Client VM, so everything is guarded on Client.
--
-- Only two hooks are needed because vanilla funnels every commander tooltip through a single
-- pair of functions:
--
--   PlayerUI_GetTooltipDataFromTechId  (lua/Player_Client.lua)  - builds the data table. Called by
--       GUICommanderButtons, GUITechMap, GUIBioMassDisplay and GUICommanderHelpWidget.
--   GUICommanderTooltip:UpdateData     (lua/GUICommanderTooltip.lua)  - renders it. The single
--       tooltip instance every one of those scripts registers itself with.
--
-- Post-hooking rather than replacing keeps us compatible with mods that ship their own copy of
-- either file - CBM, for instance, replaces Player_Client.lua wholesale. Our hook wraps whatever
-- version actually loaded.

if not Client then
	return
end

ModLoader.SetupFileHook("lua/Player_Client.lua", "lua/ImprovedTooltips/ImprovedTooltips_TooltipData.lua", "post")
ModLoader.SetupFileHook("lua/GUICommanderTooltip.lua", "lua/ImprovedTooltips/ImprovedTooltips_TooltipGUI.lua", "post")
