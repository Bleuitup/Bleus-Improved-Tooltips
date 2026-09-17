-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_HiveState.lua
--
-- Per-hive biomass level and research, keyed by location, for the alien hive status HUD in the
-- top-left corner.
--
-- Why this has to be networked by the mod at all:
--
-- Both are already on the Hive entity, and both are already network vars - Hive.lua's bioMassLevel,
-- and ResearchMixin's researchingId and researchProgress. But a Hive is only relevant to players
-- within kMaxRelevancyDistance (40m, ns2/lua/Globals.lua:348) plus the team's own commander, per
-- Hive:SetIncludeRelevancyMask. GUIHiveStatus is shown to field aliens (kShowAsClass["Alien"] in
-- ClientUI.lua) and its whole point is reporting on hives across the map, which is exactly the
-- case where the client does not have the entity. That is why vanilla feeds that HUD from
-- AlienTeamInfo, a team-wide always-relevant entity, rather than from the hives themselves.
--
-- AlienTeamInfo carries eggs, health, built fraction and hive type per location, but not biomass
-- and not research. Its networkVars are file-local and the class is already linked by the time a
-- post-hook could run, so extending them would mean re-linking the whole class - brittle, and it
-- would fight any other mod doing the same. Sending our own message instead is the same approach
-- the cooldown panel already uses.
--
-- The tech tree does not fill the gap either. Research is only tracked per entity for the techs in
-- GetTechIdIsInstanced (TechTree.lua:386) - of the alien ones, just the three hive type upgrades.
-- Biomass and lifeform abilities keep one progress value per tech, and biomass can be researched by
-- two hives at once, so "which hive, how far" has to come from the server.
--
-- A hive runs up to two researches at once, because "the hive" is two entities: the Hive itself
-- (biomass or a hive type upgrade) and the EvolutionChamber it owns (lifeform abilities off the DNA
-- menu). Each gets its own slot here.
--
-- Nothing here is sent per frame. ImprovedTooltips_HiveSync.lua diffs against the last published
-- value and sends a research id change at once, but a progress change at most every
-- kHiveResearchProgressSendInterval seconds.

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Values.lua")

ImprovedTooltips = ImprovedTooltips or { }
local IT = ImprovedTooltips

-- Progress travels as a whole percentage.
IT.kHiveResearchProgressSteps = 100

-- A 0..1 progress as the whole steps the message carries. The server also compares published
-- progress in steps, so a change too small to send is not treated as a change.
function IT.ToHiveProgressSteps(progress)
	return math.floor(Clamp(progress or 0, 0, 1) * IT.kHiveResearchProgressSteps + 0.5)
end

-- [locationId] = state, where state is
--   { biomass = 0..6, researching = boolean,
--     hiveResearchId = kTechId, hiveProgress = 0..1, evoResearchId = kTechId, evoProgress = 0..1 }
-- Parked on the shared table so a Script.Load with reload does not drop live state.
IT.hiveState = IT.hiveState or { }

function IT.ClearHiveState()
	IT.hiveState = { }
end

local function GetNone()
	return kTechId and kTechId.None or 1
end

-- Builds a normalized state table. Every argument is optional; a missing one reads as nothing
-- researching and no biomass, so MakeHiveState() is the empty state.
function IT.MakeHiveState(biomass, researching, hiveResearchId, hiveProgress, evoResearchId, evoProgress)

	local none = GetNone()

	return {
		biomass = biomass or 0,
		researching = researching == true,
		hiveResearchId = hiveResearchId or none,
		hiveProgress = Clamp(hiveProgress or 0, 0, 1),
		evoResearchId = evoResearchId or none,
		evoProgress = Clamp(evoProgress or 0, 0, 1),
	}

end

function IT.GetHiveStateIsEmpty(state)
	local none = GetNone()
	return state.biomass <= 0 and not state.researching
		and state.hiveResearchId == none and state.evoResearchId == none
end

function IT.SetHiveState(locationId, state)

	if not locationId or locationId <= 0 then
		return
	end

	-- Biomass 0 with nothing researching means the location has no hive worth drawing for - a dead
	-- hive, or one that has not finished building. Drop the entry rather than keeping a row of
	-- zeroes around.
	if not state or IT.GetHiveStateIsEmpty(state) then
		IT.hiveState[locationId] = nil
		return
	end

	IT.hiveState[locationId] = state

end

-- Always returns a table, so callers do not have to nil-check before reading any field.
local kEmptyHiveState = nil

function IT.GetHiveState(locationId)
	if not kEmptyHiveState then
		kEmptyHiveState = IT.MakeHiveState()
	end
	return IT.hiveState[locationId] or kEmptyHiveState
end

-- True while any hive or evolution chamber on the team is researching techId, per the last state
-- the server sent. Used to keep those researches out of the notification stack in hive panel mode.
function IT.GetIsResearchedInHive(techId)
	for _, state in pairs(IT.hiveState) do
		if state.hiveResearchId == techId or state.evoResearchId == techId then
			return true
		end
	end
	return false
end

------------------------------------------------------------------------------------------------
-- Server: publishing hive state to the team
------------------------------------------------------------------------------------------------
--
-- Split out here rather than living in the hook file for the same reason the cooldown helpers are:
-- two different hooks need them (ImprovedTooltips_HiveSync.lua on AlienTeamInfo.lua and
-- ImprovedTooltips_TeamJoin.lua on NS2Gamerules.lua), and this file depends on no class, so either
-- can load it whatever order the game loads those two files in.

if not Server then
	return
end

-- Seconds between progress updates for one location. A research id change is sent at once.
IT.kHiveResearchProgressSendInterval = 1

function IT.SendHiveStateTo(player, locationId, state, clear)
	IT.SendToPlayer(player, "ImprovedTooltipsHiveState",
		BuildImprovedTooltipsHiveStateMessage(locationId, state or IT.MakeHiveState(), clear))
end

function IT.BroadcastHiveState(teamNumber, locationId, state)
	IT.SendToTeam(teamNumber, "ImprovedTooltipsHiveState",
		BuildImprovedTooltipsHiveStateMessage(locationId, state, false))
end

-- What the server last told the team about each location, so the sync only sends real changes.
IT.publishedHiveState = IT.publishedHiveState or { }

-- The full current picture, for a player who just joined a team mid-round. Replayed from what the
-- server has already published rather than re-read from the hives, so a joiner sees exactly what
-- everyone else is seeing.
function IT.ResyncPlayerHiveState(player)

	IT.SendHiveStateTo(player, 0, nil, true)

	for locationId, state in pairs(IT.publishedHiveState) do
		IT.SendHiveStateTo(player, locationId, state, false)
	end

end
