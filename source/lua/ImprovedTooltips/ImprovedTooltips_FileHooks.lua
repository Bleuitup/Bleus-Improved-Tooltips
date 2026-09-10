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
	-- The alien hive status panel in the top-left corner: biomass icons and a researching ring.
	ModLoader.SetupFileHook("lua/GUIHiveStatus.lua", "lua/ImprovedTooltips/ImprovedTooltips_HiveStatusGUI.lua", "post")
	-- The spectator top bar, for its biomass counter's colour.
	ModLoader.SetupFileHook("lua/GUIInsight_TopBar.lua", "lua/ImprovedTooltips/ImprovedTooltips_InsightTopBar.lua", "post")
	-- The same bar again, for a supply counter per team. A separate file so the biomass tint and the
	-- supply counter can be switched off independently, and so neither breaks if the other is wrong.
	ModLoader.SetupFileHook("lua/GUIInsight_TopBar.lua", "lua/ImprovedTooltips/ImprovedTooltips_InsightSupply.lua", "post")
	-- Marine HUD: keep researched-but-inactive weapon and armour icons on screen in alert red
	-- when the arms lab is destroyed or unpowered, instead of hiding them.
	ModLoader.SetupFileHook("lua/Hud/Marine/GUIMarineHUD.lua", "lua/ImprovedTooltips/ImprovedTooltips_ArmsLabAlert.lua", "post")
	-- The twelve-bead biomass bar shown with the map, buy menu or tech map open: a partial fill on
	-- each bead being researched, and progress meters under the ability icons.
	ModLoader.SetupFileHook("lua/GUIBioMassDisplay.lua", "lua/ImprovedTooltips/ImprovedTooltips_BiomassOverlay.lua", "post")
	-- The mod's own settings panel under Options, Mods. Hooked on the file that declares
	-- gModsCategories, so by the time we append, the table exists and manageMods is already first
	-- in it - which GUIMenuOptions.lua:425 asserts.
	ModLoader.SetupFileHook("lua/menu2/NavBar/Screens/Options/Mods/ModsMenuData.lua", "lua/ImprovedTooltips/ImprovedTooltips_ModsMenu.lua", "post")
	-- Scoreboard: a glyph and a green or red label at the front of each team header while Shine's
	-- tournament mode is waiting for both teams. Inert when that plugin is not running.
	ModLoader.SetupFileHook("lua/GUIScoreboard.lua", "lua/ImprovedTooltips/ImprovedTooltips_TournamentReady.lua", "post")
	-- The map, both the minimap and the big one: marine blips coloured by the weapon each player
	-- carries. Off by default, and only ever shown to the marine side or to a spectator.
	ModLoader.SetupFileHook("lua/MapBlip.lua", "lua/ImprovedTooltips/ImprovedTooltips_MapBlipColor.lua", "post")
	-- TEMPORARY, remove before 1.03 ships. Pairs with the banner the hooked file prints: this line
	-- says the hook was REGISTERED in this VM, that one says it FIRED. Seeing the first without the
	-- second means ModLoader never ran the hook, which is a different fault from the file erroring.
	Shared.Message("[Improved Tooltips] registered the lua/MapBlip.lua hook")
end

-- Shared: the cooldown network message has to be registered identically in every VM, and
-- NetworkMessages.lua loads in all of them.
ModLoader.SetupFileHook("lua/NetworkMessages.lua", "lua/ImprovedTooltips/ImprovedTooltips_NetworkMessages.lua", "post")

-- Five server hooks rather than one, because each wraps a method on a different class and no
-- file can assume another's class has loaded yet:
--
--   Commander.lua    - Commander:SetTechCooldown, to broadcast a new cooldown to the team.
--                      Hooked here and not on Commander_Server.lua, which Commander.lua loads at
--                      its line 69, long before the method is defined further down.
--   NS2Gamerules.lua - NS2Gamerules:JoinTeam, twice: cooldowns and hive state for a joiner.
--   AlienTeam.lua    - AlienTeam:UpdateBioMassLevel, to show every biomass level in progress.
--   AlienTeamInfo.lua- AlienTeamInfo:UpdateAllLocationsSlotData, to publish per-hive biomass and
--                      research for the top-left hive panel.
--
-- Two post-hooks on NS2Gamerules.lua chain cleanly: ModLoader appends them in order and each wraps
-- whatever the previous left, so one file per feature costs nothing. Shared helpers live in
-- ImprovedTooltips_CooldownState.lua and ImprovedTooltips_HiveState.lua, neither of which depends
-- on a class. Each hook file guards on Server itself.
if Server then
	ModLoader.SetupFileHook("lua/Commander.lua", "lua/ImprovedTooltips/ImprovedTooltips_CooldownSync.lua", "post")
	ModLoader.SetupFileHook("lua/NS2Gamerules.lua", "lua/ImprovedTooltips/ImprovedTooltips_CooldownJoin.lua", "post")
	-- AlienTeam.lua is loaded by Server.lua alone, so the class only exists in this VM. Spreads
	-- in-progress biomass across every level being worked on instead of only the next one.
	ModLoader.SetupFileHook("lua/AlienTeam.lua", "lua/ImprovedTooltips/ImprovedTooltips_BiomassProgress.lua", "post")
	-- AlienTeamInfo.lua feeds the top-left hive panel. Adds per-hive biomass and a researching
	-- flag, which vanilla gathers for nobody. NS2Gamerules.lua again, to hand that state to a
	-- player joining mid-round.
	ModLoader.SetupFileHook("lua/AlienTeamInfo.lua", "lua/ImprovedTooltips/ImprovedTooltips_HiveSync.lua", "post")
	ModLoader.SetupFileHook("lua/NS2Gamerules.lua", "lua/ImprovedTooltips/ImprovedTooltips_HiveJoin.lua", "post")
end
