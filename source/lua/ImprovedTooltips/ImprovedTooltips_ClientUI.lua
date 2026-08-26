-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_ClientUI.lua
--
-- Post-hook on lua/ClientUI.lua, which is where AddClientUIScriptForClass is defined. Registers the
-- "In Cooldown" panel so ClientUI creates it while the local player is a commander and destroys it
-- when they leave the chair.
--
-- Both commander classes are registered: cooldowns are team-global on both sides, and marines have
-- Nano Shield (10s) and Power Surge (4s). The panel picks up its own team's styling at Initialize.

if not Client then
	return
end

AddClientUIScriptForClass("MarineCommander", "ImprovedTooltips/GUIImprovedTooltipsCooldowns")
AddClientUIScriptForClass("AlienCommander", "ImprovedTooltips/GUIImprovedTooltipsCooldowns")
