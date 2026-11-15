-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_FileHooks.lua
--
-- Registers every file hook the mod uses, grouped by feature. Each is a post-hook: our file runs
-- straight after the game's, and wraps whatever version of it actually loaded.
--
-- Each hook is registered only in the VM that loads its target, so neither VM hooks a file it never
-- loads. Two hooks on the same file run in the order they are registered here, each wrapping what
-- the one before left.
--
-- 1.2 (build 345): the commander tooltip values, the In Cooldown panel and its sync, the hive status
-- additions, the research notification fixes, the biomass bar, the spectator top bar, the arms lab
-- alert, weapon blip colors, minimap phase gate arrows and the exo weapon bars are part of the game
-- now, and their hooks are gone.

if Client then

	-- COMMANDER BUTTONS: each tab and grid button's hotkey in its bottom-right corner, when switched
	-- on. Both teams; the marine and alien button scripts are subclasses of this one.
	ModLoader.SetupFileHook("lua/GUICommanderButtons.lua", "lua/ImprovedTooltips/ImprovedTooltips_HotkeyLabels.lua", "post")

	-- SPECTATOR TECH MAPS: the map is a ClientUI script, registered in ImprovedTooltips_ClientUI.lua
	-- and fed by the server half below; the key hint goes along the bottom of the overhead view.
	ModLoader.SetupFileHook("lua/ClientUI.lua", "lua/ImprovedTooltips/ImprovedTooltips_ClientUI.lua", "post")
	ModLoader.SetupFileHook("lua/GUIInsight_Overhead.lua", "lua/ImprovedTooltips/ImprovedTooltips_SpectatorTechMapHint.lua", "post")

	-- NAMEPLATES: a welder icon right of a marine teammate's name, for the marine commander and
	-- marines in the field. Wraps whichever GUIUnitStatus loaded; Devnull's AdvancedHud ships its own.
	ModLoader.SetupFileHook("lua/GUIUnitStatus.lua", "lua/ImprovedTooltips/ImprovedTooltips_WelderIcon.lua", "post")

	-- NUTRIENT MIST: a badge above every alien entity the mist is helping, for the alien commander,
	-- and an entry in the alien HUD's status row while the mist is helping you (in an egg).
	ModLoader.SetupFileHook("lua/GUIUnitStatus.lua", "lua/ImprovedTooltips/ImprovedTooltips_MistBadge.lua", "post")
	ModLoader.SetupFileHook("lua/Hud/GUIPlayerStatus.lua", "lua/ImprovedTooltips/ImprovedTooltips_MistStatus.lua", "post")

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

	-- TechTree_Server.lua, loaded by TechTree.lua in this VM only: SendTechTreeUpdates, to add the
	-- neutral spectators who asked for that team's tech tree.
	ModLoader.SetupFileHook("lua/TechTree_Server.lua", "lua/ImprovedTooltips/ImprovedTooltips_SpectatorTechTree.lua", "post")

end
