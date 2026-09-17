-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_TeamJoin.lua
--
-- Post-hook on lua/NS2Gamerules.lua. Hands a player who joins a team everything the server has
-- already told that team, so someone arriving mid-round sees it at once rather than when it next
-- changes:
--
--   - the team's commander ability cooldowns, for the In Cooldown panel and the button dial
--     (ImprovedTooltips_CooldownState.lua);
--   - per-hive biomass and research, for the alien hive status panel
--     (ImprovedTooltips_HiveState.lua).
--
-- Each resync starts with a clear, so the joiner also drops anything stale from a previous team or
-- round. Both helpers live in state files that depend on no class, so this hook can load them
-- whatever order the game loads NS2Gamerules.lua, Commander.lua and AlienTeamInfo.lua in.

if not Server then
	return
end

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Values.lua")
Script.Load("lua/ImprovedTooltips/ImprovedTooltips_CooldownState.lua")
Script.Load("lua/ImprovedTooltips/ImprovedTooltips_HiveState.lua")

local IT = ImprovedTooltips

-- JoinTeam returns (success, player) and replaces the player entity on the way through, so resync
-- the entity it hands back rather than the one passed in.
local originalJoinTeam = NS2Gamerules.JoinTeam

function NS2Gamerules:JoinTeam(player, newTeamNumber, force)

	local success, newPlayer = originalJoinTeam(self, player, newTeamNumber, force)

	if success then
		local joined = newPlayer or player
		IT.ResyncPlayerCooldowns(joined, newTeamNumber)
		IT.ResyncPlayerHiveState(joined)
	end

	return success, newPlayer

end
