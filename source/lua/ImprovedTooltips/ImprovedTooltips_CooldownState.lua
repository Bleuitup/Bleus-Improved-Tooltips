-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_CooldownState.lua
--
-- The mod's own client-side record of which team abilities are on cooldown.
--
-- Why not just use vanilla's? Because vanilla's only exists for the seated commander.
-- Commander:GetCooldownFraction reads gTechIdCooldowns, a file-local table in lua/Commander.lua
-- that on a client is only ever written by the "AbilityResult" message - which the server sends to
-- the commander alone. A field player, or a commander who has just left the chair, has no cooldown
-- data at all, and GetCooldownFraction is a Commander method they do not even have.
--
-- So the mod keeps its own table, fed by its own network message (see
-- ImprovedTooltips_NetworkMessages.lua) which the server broadcasts to the whole team. That makes
-- the panel work for anyone, and it survives the player entity being replaced on spawn, death or
-- leaving the chair, because the state lives here rather than on the entity.

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Values.lua")

ImprovedTooltips = ImprovedTooltips or { }
local IT = ImprovedTooltips

-- [techId] = startTime. Duration is looked up from TechData, the same assumption vanilla's own
-- client handler makes. Parked on the shared table so a Script.Load with reload does not drop
-- live cooldowns.
IT.teamCooldowns = IT.teamCooldowns or { }

function IT.ClearTeamCooldowns()
	IT.teamCooldowns = { }
end

function IT.SetTeamCooldown(techId, startTime)

	if not techId or techId == kTechId.None then
		return
	end

	IT.teamCooldowns[techId] = startTime

end

-- Mirrors Commander:GetCooldownFraction exactly: counts DOWN from 1 to 0 as the cooldown expires,
-- and returns 0 when there is none. The panel and the vanilla dial both expect that direction.
function IT.GetTeamCooldownFraction(techId)

	local startTime = IT.teamCooldowns[techId]
	if not startTime then
		return 0
	end

	local duration = LookupTechData(techId, kTechDataCooldown, 0)
	if type(duration) ~= "number" or duration <= 0 then
		IT.teamCooldowns[techId] = nil
		return 0
	end

	local fraction = 1 - math.min(1, (Shared.GetTime() - startTime) / duration)

	if fraction <= 0 then
		-- Expired entries are dropped as they are noticed rather than swept, so nothing has to run
		-- on a timer.
		IT.teamCooldowns[techId] = nil
		return 0
	end

	return fraction

end

------------------------------------------------------------------------------------------------
-- Bridging back into vanilla's own cooldown table
------------------------------------------------------------------------------------------------
--
-- The mod's table drives the mod's panel. It does NOT drive vanilla's rotating dial on the
-- commander button, which reads gTechIdCooldowns through Commander:GetCooldownFraction. So a
-- commander who takes the chair mid-cooldown still sees a blank button dial even though our panel
-- is correct.
--
-- Commander:SetTechCooldown is the public way into that table - it writes gTechIdCooldowns keyed by
-- team - so pushing our synced state through it fixes the vanilla dial with no server involvement
-- at all. The client already has everything needed.
--
-- Writing an entry vanilla already holds is harmless: SetTechCooldown searches by techId and
-- updates in place rather than appending. Expired entries are harmless too, since
-- GetCooldownFraction returns 0 once the time has passed - but they are skipped anyway.

function IT.ApplyCooldownToVanillaDial(commander, techId, startTime)

	if not commander or not commander.SetTechCooldown or not techId or techId == kTechId.None then
		return
	end

	local duration = LookupTechData(techId, kTechDataCooldown, 0)
	if type(duration) ~= "number" or duration <= 0 then
		return
	end

	if startTime + duration <= Shared.GetTime() then
		return
	end

	commander:SetTechCooldown(techId, duration, startTime)

end

-- Replays everything currently known into vanilla's table. Called when the local player becomes a
-- commander, which is the moment vanilla's table is empty but ours is not.
function IT.PushAllCooldownsToVanillaDial(commander)

	for techId, startTime in pairs(IT.teamCooldowns) do
		IT.ApplyCooldownToVanillaDial(commander, techId, startTime)
	end

end

------------------------------------------------------------------------------------------------
-- Server: publishing cooldowns to the team
------------------------------------------------------------------------------------------------
--
-- These live here rather than in a hook file because two different hooks need them
-- (ImprovedTooltips_CooldownSync.lua on Commander.lua, ImprovedTooltips_CooldownJoin.lua on
-- NS2Gamerules.lua) and this file depends on no class, so it is safe to load from either whatever
-- order the game happens to load Commander.lua and NS2Gamerules.lua in.

if not Server then
	return
end

function IT.SendCooldownTo(player, techId, startTime, clear)

	-- Bots go through the same cast and join paths but have no client to message.
	if not player or (player.GetIsVirtual and player:GetIsVirtual()) then
		return
	end

	Server.SendNetworkMessage(player, "ImprovedTooltipsCooldown",
		BuildImprovedTooltipsCooldownMessage(techId, startTime, clear), true)

end

function IT.BroadcastCooldown(teamNumber, techId, startTime)

	for _, player in ipairs(GetEntitiesForTeam("Player", teamNumber)) do
		IT.SendCooldownTo(player, techId, startTime, false)
	end

end

-- The full current picture, for a player who just joined a team mid-round. Reconstructed through
-- the public GetCooldownFraction because gTechIdCooldowns is file-local and unreachable:
--
--     fraction  = 1 - timePassed / duration        (Commander:GetCooldownFraction)
--     startTime = now - (1 - fraction) * duration
--
-- It needs a commander to ask, GetCooldownFraction being a Commander method. With nobody in the
-- chair there is nothing to report, but the clear is still sent so the joiner drops anything stale
-- from a previous team or round.
function IT.ResyncPlayerCooldowns(player, teamNumber)

	IT.SendCooldownTo(player, kTechId.None, 0, true)

	local gamerules = GetGamerules()
	local team = gamerules and gamerules.GetTeam and gamerules:GetTeam(teamNumber)
	local commander = team and team.GetCommander and team:GetCommander()

	if not commander then
		return
	end

	local techIds = IT.GetTechIdsWithCooldown()
	local now = Shared.GetTime()

	for i = 1, #techIds do

		local techId = techIds[i]
		local fraction = commander:GetCooldownFraction(techId)

		if fraction and fraction > 0 then
			local duration = LookupTechData(techId, kTechDataCooldown, 0)
			if duration > 0 then
				IT.SendCooldownTo(player, techId, now - (1 - fraction) * duration, false)
			end
		end

	end

end
