-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_HiveJoin.lua
--
-- Post-hook on lua/NS2Gamerules.lua. Hands a joining player the current per-hive biomass and
-- research state, so someone arriving mid-round sees the HUD filled in rather than blank until the
-- next hive finishes a research.
--
-- A second hook on NS2Gamerules.lua rather than an addition to ImprovedTooltips_CooldownJoin.lua:
-- ModLoader appends post-hooks in order and each wraps whatever the previous one left, so the two
-- chain cleanly, and keeping one file per feature means the cooldown sync and the hive HUD can be
-- changed or turned off without touching each other.

if not Server then
	return
end

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Values.lua")
Script.Load("lua/ImprovedTooltips/ImprovedTooltips_HiveState.lua")

local IT = ImprovedTooltips

-- JoinTeam returns (success, player) and replaces the player entity on the way through, so resync
-- the entity it hands back rather than the one passed in.
local originalJoinTeam = NS2Gamerules.JoinTeam

function NS2Gamerules:JoinTeam(player, newTeamNumber, force)

	local success, newPlayer = originalJoinTeam(self, player, newTeamNumber, force)

	if success then
		IT.ResyncPlayerHiveState(newPlayer or player)
	end

	return success, newPlayer

end
