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
	ModLoader.SetupFileHook("lua/GUISelectionPanel.lua", "lua/ImprovedTooltips/ImprovedTooltips_SelectionPanel.lua", "post")
	-- Client side of Commander.lua: replays synced cooldowns into vanilla's own table when the
	-- local player takes the chair, so vanilla's button dial works too and not just our panel.
	ModLoader.SetupFileHook("lua/Commander.lua", "lua/ImprovedTooltips/ImprovedTooltips_CooldownDial.lua", "post")
end

-- Shared: the cooldown network message has to be registered identically in every VM, and
-- NetworkMessages.lua loads in all of them.
ModLoader.SetupFileHook("lua/NetworkMessages.lua", "lua/ImprovedTooltips/ImprovedTooltips_NetworkMessages.lua", "post")

-- Three server hooks rather than one, because each wraps a method on a different class and no
-- file can assume another's class has loaded yet:
--
--   Commander.lua    - Commander:SetTechCooldown, to broadcast a new cooldown to the team.
--                      Hooked here and not on Commander_Server.lua, which Commander.lua loads at
--                      its line 69, long before the method is defined further down.
--   NS2Gamerules.lua - NS2Gamerules:JoinTeam, to hand a joining player the current cooldowns.
--   AlienTeam.lua    - AlienTeam:UpdateBioMassLevel, to show every biomass level in progress.
--
-- The helpers the two cooldown hooks share live in ImprovedTooltips_CooldownState.lua, which
-- depends on no class. Each hook file guards on Server itself.
if Server then
	ModLoader.SetupFileHook("lua/Commander.lua", "lua/ImprovedTooltips/ImprovedTooltips_CooldownSync.lua", "post")
	ModLoader.SetupFileHook("lua/NS2Gamerules.lua", "lua/ImprovedTooltips/ImprovedTooltips_CooldownJoin.lua", "post")
	-- AlienTeam.lua is loaded by Server.lua alone, so the class only exists in this VM. Spreads
	-- in-progress biomass across every level being worked on instead of only the next one.
	ModLoader.SetupFileHook("lua/AlienTeam.lua", "lua/ImprovedTooltips/ImprovedTooltips_BiomassProgress.lua", "post")
end
