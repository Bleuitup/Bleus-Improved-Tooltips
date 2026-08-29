-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_CooldownJoin.lua
--
-- Post-hook on lua/NS2Gamerules.lua. Gives a player the team's current cooldowns when they join a
-- team, so someone arriving mid-round sees an ability that is already ticking rather than nothing
-- until the next cast.
--
-- Separate from ImprovedTooltips_CooldownSync.lua purely for load order: that one wraps a Commander
-- method and so must hook Commander.lua, this one wraps a gamerules method and must hook
-- NS2Gamerules.lua. Neither file can assume the other's class exists yet, which is why the shared
-- helpers sit in ImprovedTooltips_CooldownState.lua.

if not Server then
	return
end

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Values.lua")
Script.Load("lua/ImprovedTooltips/ImprovedTooltips_CooldownState.lua")

local IT = ImprovedTooltips

-- JoinTeam returns (success, player) and replaces the player entity on the way through, so resync
-- the entity it hands back rather than the one passed in.
local originalJoinTeam = NS2Gamerules.JoinTeam

function NS2Gamerules:JoinTeam(player, newTeamNumber, force)

	local success, newPlayer = originalJoinTeam(self, player, newTeamNumber, force)

	if success then
		IT.ResyncPlayerCooldowns(newPlayer or player, newTeamNumber)
	end

	return success, newPlayer

end
