-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_ClientUI.lua
--
-- Post-hook on lua/ClientUI.lua, which is where AddClientUIScriptForClass is defined. Registers the
-- "In Cooldown" panel so ClientUI creates it while the local player is a commander and destroys it
-- when they leave the chair.
--
-- Registered for "Player", not the two commander classes. ClientUI matches with forPlayer:isa(class)
-- (ClientUI.lua:307, :386), so one registration covers every player class on both teams - field
-- players, and a commander who has just left the chair. Cooldowns are team-wide, so the whole team
-- is the right audience; the panel itself checks the player is on a playing team, and ClientUI
-- already keeps scripts out of the ready room.
--
-- This only works because the panel reads the mod's own synced cooldown table rather than
-- Commander:GetCooldownFraction, which a field player does not have. See
-- ImprovedTooltips_CooldownState.lua.

if not Client then
	return
end

AddClientUIScriptForClass("Player", "ImprovedTooltips/GUIImprovedTooltipsCooldowns")

-- Exo weapon bars beside the crosshair. Registered for "Exo": ClientUI matches with isa, so this
-- covers every exo variant without naming them, and the script only exists while in a suit.
AddClientUIScriptForClass("Exo", "ImprovedTooltips/GUIImprovedTooltipsExoBars")

-- The tech map for neutral spectators (1.12): hold the tech map key, 1 or 2 for marines or aliens.
-- Registered for the spectator team, so a dead player watching their own team (a TeamSpectator on
-- team 1 or 2) keeps vanilla's tech map of their own side and never gets this one.
AddClientUIScriptForTeam(kSpectatorIndex, "ImprovedTooltips/GUIImprovedTooltipsSpectatorTechMap")
