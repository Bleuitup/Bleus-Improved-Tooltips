-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_HiveState.lua
--
-- Per-hive biomass level and "is this hive researching anything", keyed by location, for the alien
-- hive status HUD in the top-left corner.
--
-- Why this has to be networked by the mod at all:
--
-- Both numbers are already on the Hive entity, and both are already network vars - Hive.lua's
-- bioMassLevel, and ResearchMixin's researchingId. But a Hive is only relevant to players within
-- kMaxRelevancyDistance (40m, ns2/lua/Globals.lua:348) plus the team's own commander, per
-- Hive:SetIncludeRelevancyMask. GUIHiveStatus is shown to field aliens (kShowAsClass["Alien"] in
-- ClientUI.lua) and its whole point is reporting on hives across the map, which is exactly the
-- case where the client does not have the entity. That is why vanilla feeds that HUD from
-- AlienTeamInfo, a team-wide always-relevant entity, rather than from the hives themselves.
--
-- AlienTeamInfo carries eggs, health, built fraction and hive type per location, but not biomass
-- and not research. Its networkVars are file-local and the class is already linked by the time a
-- post-hook could run, so extending them would mean re-linking the whole class - brittle, and it
-- would fight any other mod doing the same. Sending our own message instead is the same approach
-- the cooldown panel already uses, and it costs one small message per hive per change.
--
-- Nothing here is sent per frame. Biomass changes a handful of times a round and research starts
-- and stops; ImprovedTooltips_HiveSync.lua diffs against the last published value and only sends
-- when something actually moved.

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Values.lua")

ImprovedTooltips = ImprovedTooltips or { }
local IT = ImprovedTooltips

-- [locationId] = { biomass = 0..6, researching = boolean }
-- Parked on the shared table so a Script.Load with reload does not drop live state.
IT.hiveState = IT.hiveState or { }

function IT.ClearHiveState()
	IT.hiveState = { }
end

function IT.SetHiveState(locationId, biomass, researching)

	if not locationId or locationId <= 0 then
		return
	end

	-- Biomass 0 with nothing researching means the location has no hive worth drawing for - a dead
	-- hive, or one that has not finished building. Drop the entry rather than keeping a row of
	-- zeroes around.
	if (biomass or 0) <= 0 and not researching then
		IT.hiveState[locationId] = nil
		return
	end

	IT.hiveState[locationId] = { biomass = biomass or 0, researching = researching == true }

end

-- Always returns a table, so callers do not have to nil-check before reading either field.
local kEmptyHiveState = { biomass = 0, researching = false }

function IT.GetHiveState(locationId)
	return IT.hiveState[locationId] or kEmptyHiveState
end

------------------------------------------------------------------------------------------------
-- Server: publishing hive state to the team
------------------------------------------------------------------------------------------------
--
-- Split out here rather than living in the hook file for the same reason the cooldown helpers are:
-- two different hooks need them (ImprovedTooltips_HiveSync.lua on AlienTeamInfo.lua and
-- ImprovedTooltips_HiveJoin.lua on NS2Gamerules.lua), and this file depends on no class, so either
-- can load it whatever order the game loads those two files in.

if not Server then
	return
end

function IT.SendHiveStateTo(player, locationId, biomass, researching, clear)

	-- Bots go through the same join path but have no client to message.
	if not player or (player.GetIsVirtual and player:GetIsVirtual()) then
		return
	end

	Server.SendNetworkMessage(player, "ImprovedTooltipsHiveState",
		BuildImprovedTooltipsHiveStateMessage(locationId, biomass, researching, clear), true)

end

function IT.BroadcastHiveState(teamNumber, locationId, biomass, researching)

	for _, player in ipairs(GetEntitiesForTeam("Player", teamNumber)) do
		IT.SendHiveStateTo(player, locationId, biomass, researching, false)
	end

end

-- What the server last told the team about each location, so the sync only sends real changes.
IT.publishedHiveState = IT.publishedHiveState or { }

-- The full current picture, for a player who just joined a team mid-round. Replayed from what the
-- server has already published rather than re-read from the hives, so a joiner sees exactly what
-- everyone else is seeing.
function IT.ResyncPlayerHiveState(player)

	IT.SendHiveStateTo(player, 0, 0, false, true)

	for locationId, state in pairs(IT.publishedHiveState) do
		IT.SendHiveStateTo(player, locationId, state.biomass, state.researching, false)
	end

end
