-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_FileHooks.lua
--
-- Registers every file hook the mod uses, grouped by feature. Each is a post-hook: our file runs
-- straight after the game's, and wraps whatever version of it actually loaded. That is what keeps
-- the mod compatible with mods that ship their own copy of a file - CBM, for instance, replaces
-- Player_Client.lua wholesale.
--
-- Each hook is registered only in the VM that loads its target, so neither VM hooks a file it never
-- loads. Two hooks on the same file run in the order they are registered here, each wrapping what
-- the one before left.

if Client then

	-- COMMANDER TOOLTIPS. Vanilla funnels every commander tooltip - GUICommanderButtons, GUITechMap,
	-- GUIBioMassDisplay and GUICommanderHelpWidget - through one pair of functions:
	-- PlayerUI_GetTooltipDataFromTechId builds the data, and the single GUICommanderTooltip renders
	-- it. The selection panel you get clicking a structure takes the same health and armor icons.
	ModLoader.SetupFileHook("lua/Player_Client.lua", "lua/ImprovedTooltips/ImprovedTooltips_TooltipData.lua", "post")
	ModLoader.SetupFileHook("lua/GUICommanderTooltip.lua", "lua/ImprovedTooltips/ImprovedTooltips_TooltipGUI.lua", "post")
	ModLoader.SetupFileHook("lua/GUISelectionPanel.lua", "lua/ImprovedTooltips/ImprovedTooltips_SelectionPanel.lua", "post")

	-- IN COOLDOWN PANEL, and the exo weapon bars: both GUI scripts are registered with ClientUI.
	-- Commander.lua, client side, replays synced cooldowns into vanilla's own table when the local
	-- player takes the chair, so vanilla's button dial works too.
	ModLoader.SetupFileHook("lua/ClientUI.lua", "lua/ImprovedTooltips/ImprovedTooltips_ClientUI.lua", "post")
	ModLoader.SetupFileHook("lua/Commander.lua", "lua/ImprovedTooltips/ImprovedTooltips_CooldownDial.lua", "post")

	-- ALIEN HIVE STATUS PANEL, top left: biomass icons, and each hive's research as a busy ring or
	-- as research slots, per HIVE RESEARCH DISPLAY. The notification queue and stack, so HIVE PANEL
	-- can keep research done in hives off the left, and so every research completion sounds and
	-- every research in progress stays in the stack.
	ModLoader.SetupFileHook("lua/GUIHiveStatus.lua", "lua/ImprovedTooltips/ImprovedTooltips_HiveStatusGUI.lua", "post")
	ModLoader.SetupFileHook("lua/Hud/GUINotificationMixin.lua", "lua/ImprovedTooltips/ImprovedTooltips_ResearchNotifications.lua", "post")
	ModLoader.SetupFileHook("lua/Hud/GUIEvent.lua", "lua/ImprovedTooltips/ImprovedTooltips_ResearchStack.lua", "post")

	-- BIOMASS BAR, the twelve beads shown with the map, buy menu or tech map open: a partial fill on
	-- each bead being researched, and progress meters under the ability icons.
	ModLoader.SetupFileHook("lua/GUIBioMassDisplay.lua", "lua/ImprovedTooltips/ImprovedTooltips_BiomassOverlay.lua", "post")

	-- SPECTATOR TOP BAR: the biomass counter's color, then a supply counter per team. Separate
	-- files so each can be switched off alone and neither breaks if the other is wrong.
	ModLoader.SetupFileHook("lua/GUIInsight_TopBar.lua", "lua/ImprovedTooltips/ImprovedTooltips_InsightTopBar.lua", "post")
	ModLoader.SetupFileHook("lua/GUIInsight_TopBar.lua", "lua/ImprovedTooltips/ImprovedTooltips_InsightSupply.lua", "post")

	-- MARINE HUD: researched-but-inactive weapon and armor icons stay on screen in alert red when the
	-- arms lab is destroyed or unpowered. With Centralized HUD bars, vanilla's right-hand weapon bar
	-- is hidden while the exo weapon bars show, so a pilot does not get two readouts.
	ModLoader.SetupFileHook("lua/Hud/Marine/GUIMarineHUD.lua", "lua/ImprovedTooltips/ImprovedTooltips_ArmsLabAlert.lua", "post")
	ModLoader.SetupFileHook("lua/GUIAdvancedHUDBars.lua", "lua/ImprovedTooltips/ImprovedTooltips_AdvancedHUDBars.lua", "post")

	-- MAPS: marine blips colored by weapon, and phase gate arrows on the commander's and spectator's
	-- corner minimap.
	ModLoader.SetupFileHook("lua/MapBlip.lua", "lua/ImprovedTooltips/ImprovedTooltips_MapBlipColor.lua", "post")
	ModLoader.SetupFileHook("lua/GUIMinimapConnection.lua", "lua/ImprovedTooltips/ImprovedTooltips_MinimapConnection.lua", "post")

	-- SCOREBOARD: a glyph and a green or red label at the front of each team header while Shine's
	-- tournament mode is waiting for both teams. Inert when that plugin is not running.
	ModLoader.SetupFileHook("lua/GUIScoreboard.lua", "lua/ImprovedTooltips/ImprovedTooltips_TournamentReady.lua", "post")

	-- SETTINGS PANEL under Options > Mods. Hooked on the file that declares gModsCategories, so by the
	-- time we append, the table exists and manageMods is already first in it, which
	-- GUIMenuOptions.lua:425 asserts.
	ModLoader.SetupFileHook("lua/menu2/NavBar/Screens/Options/Mods/ModsMenuData.lua", "lua/ImprovedTooltips/ImprovedTooltips_ModsMenu.lua", "post")

end

-- NETWORK MESSAGES, in every VM: a message has to be registered identically on client and server,
-- and NetworkMessages.lua loads in all of them.
ModLoader.SetupFileHook("lua/NetworkMessages.lua", "lua/ImprovedTooltips/ImprovedTooltips_NetworkMessages.lua", "post")

if Server then

	-- One hook per class, because no file can assume another's class has loaded yet. The helpers
	-- they share live in ImprovedTooltips_CooldownState.lua and ImprovedTooltips_HiveState.lua,
	-- neither of which depends on a class.
	--
	--   Commander.lua     SetTechCooldown, to broadcast a new cooldown to the team. Hooked here and
	--                     not on Commander_Server.lua, which Commander.lua loads at its line 69, long
	--                     before the method is defined further down.
	--   NS2Gamerules.lua  JoinTeam, to hand a joining player the team's cooldowns and hive state.
	--   AlienTeam.lua     UpdateBioMassLevel, to show every biomass level in progress on the tech map.
	--                     Loaded by Server.lua alone, so the class only exists in this VM.
	--   AlienTeamInfo.lua UpdateAllLocationsSlotData, to publish per-hive biomass and research for the
	--                     hive status panel, which vanilla gathers for nobody.
	ModLoader.SetupFileHook("lua/Commander.lua", "lua/ImprovedTooltips/ImprovedTooltips_CooldownSync.lua", "post")
	ModLoader.SetupFileHook("lua/NS2Gamerules.lua", "lua/ImprovedTooltips/ImprovedTooltips_TeamJoin.lua", "post")
	ModLoader.SetupFileHook("lua/AlienTeam.lua", "lua/ImprovedTooltips/ImprovedTooltips_BiomassProgress.lua", "post")
	ModLoader.SetupFileHook("lua/AlienTeamInfo.lua", "lua/ImprovedTooltips/ImprovedTooltips_HiveSync.lua", "post")

end
