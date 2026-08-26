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

-- The tooltip hooks are client-only; the cooldown sync is server-only. Guard each so neither VM
-- registers a hook on a file it never loads.
if Client then
	ModLoader.SetupFileHook("lua/Player_Client.lua", "lua/ImprovedTooltips/ImprovedTooltips_TooltipData.lua", "post")
	ModLoader.SetupFileHook("lua/GUICommanderTooltip.lua", "lua/ImprovedTooltips/ImprovedTooltips_TooltipGUI.lua", "post")
	ModLoader.SetupFileHook("lua/ClientUI.lua", "lua/ImprovedTooltips/ImprovedTooltips_ClientUI.lua", "post")
end

-- Hooked onto Commander.lua rather than Commander_Server.lua: Commander.lua loads the server file
-- at its line 69, long before Commander:OnProcessMove is defined further down, so wrapping the
-- method from Commander_Server.lua would run too early and wrap nothing. The hook file guards on
-- Server itself.
if Server then
	ModLoader.SetupFileHook("lua/Commander.lua", "lua/ImprovedTooltips/ImprovedTooltips_CooldownSync.lua", "post")
end
