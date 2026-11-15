-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_ClientUI.lua
--
-- Post-hook on lua/ClientUI.lua, which is where AddClientUIScriptForTeam is defined. Registers the
-- spectator tech map so ClientUI creates it for neutral spectators and destroys it when they leave.
--
-- Until 1.2 this also registered the In Cooldown panel and the exo weapon bars. Build 345 has both
-- (GUITeamCooldowns and GUIExoWeaponBars), so they were removed.

if not Client then
	return
end

-- The tech map for neutral spectators (1.12): hold the tech map key, 1 or 2 for marines or aliens.
-- Registered for the spectator team, so a dead player watching their own team (a TeamSpectator on
-- team 1 or 2) keeps vanilla's tech map of their own side and never gets this one.
AddClientUIScriptForTeam(kSpectatorIndex, "ImprovedTooltips/GUIImprovedTooltipsSpectatorTechMap")
