-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_HiveSync.lua
--
-- Post-hook on lua/AlienTeamInfo.lua. Server only - AlienTeamInfo's server half is inside an
-- `if Server then` block and this is where the per-location hive data for the HUD is gathered.
--
-- Wraps UpdateAllLocationsSlotData, which vanilla already calls every update to walk the alien
-- team's hives and eggs and push their state into AlienTeamInfo's network vars. Walking the same
-- hives immediately afterwards means the mod's extra fields are gathered from the same entities in
-- the same tick as vanilla's, so the HUD can never show a biomass count from one moment and a
-- health bar from another.
--
-- Only changes are sent. Biomass and which research is running move a handful of times a round and
-- go out at once; research progress moves constantly, so it goes out at most once every
-- IT.kHiveResearchProgressSendInterval seconds per location, and only while something is running.

if not Server then
	return
end

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Values.lua")
Script.Load("lua/ImprovedTooltips/ImprovedTooltips_HiveState.lua")

local IT = ImprovedTooltips

-- A hive counts as busy for any research, but "the hive" is two entities, not one.
--
-- Biomass and hive type upgrades run on the Hive itself. Lifeform abilities - Leap, Metabolize,
-- Umbra, Bone Shield and the rest off the DNA menu - do not: Hive:OnInitialized creates a separate
-- "evolutionchamber" entity and hands it ownership (Hive.lua:159), and EvolutionChamber carries its
-- own ResearchMixin. Its own comment says it "handles the life-form researches for the Hive". So
-- asking only the Hive misses every ability research, which is exactly what 0.93 did.
--
-- The chamber is reached through the hive's public accessor, and Shared.GetEntity returns nil for
-- the -1 the id is initialized to, so an unbuilt hive simply has none.
--
-- What one of the two entities is researching: its tech id and progress, or None and 0. Only while
-- GetIsResearching says so, which is ResearchMixin's own test: it treats a finished research that
-- the tech tree has not yet processed as no longer researching. All three accessors are plain field
-- reads on ResearchMixin (ResearchMixin.lua:124-130, :191).
local function GetResearch(entity)

	if not entity or not entity.GetIsResearching or not entity:GetIsResearching() then
		return kTechId.None, 0
	end

	local researchId = entity:GetResearchingId()
	if not researchId or researchId == kTechId.None then
		return kTechId.None, 0
	end

	return researchId, entity:GetResearchProgress() or 0

end

-- Whether a new reading is worth sending, given what was last published for the location.
local function GetShouldPublish(published, state, now)

	if not published then
		return true
	end

	if published.biomass ~= state.biomass
		or published.hiveResearchId ~= state.hiveResearchId or published.evoResearchId ~= state.evoResearchId then
		return true
	end

	local ToSteps = IT.ToHiveProgressSteps
	local progressMoved = ToSteps(published.hiveProgress) ~= ToSteps(state.hiveProgress)
		or ToSteps(published.evoProgress) ~= ToSteps(state.evoProgress)

	return progressMoved and now - (published.sentAt or 0) >= IT.kHiveResearchProgressSendInterval

end

local originalUpdateAllLocationsSlotData = AlienTeamInfo.UpdateAllLocationsSlotData

function AlienTeamInfo:UpdateAllLocationsSlotData()

	originalUpdateAllLocationsSlotData(self)

	if not IT.kShowHiveBiomassIcons and not IT.kShowHiveResearch then
		return
	end

	local teamNumber = self:GetTeamNumber()
	local current = { }

	for _, hive in ipairs(GetEntitiesForTeam("Hive", teamNumber)) do

		local locationId = hive.locationId

		if hive:GetIsAlive() and locationId and locationId > 0 then

			local hiveResearchId, hiveProgress = GetResearch(hive)
			local evoResearchId, evoProgress = GetResearch(hive.GetEvolutionChamber and hive:GetEvolutionChamber())
			local state = IT.MakeHiveState(hive.bioMassLevel or 0,
				hiveResearchId, hiveProgress, evoResearchId, evoProgress)

			-- Two hives sharing a location is not a thing vanilla builds for - AlienTeamInfo keeps
			-- one slot per location and the last hive walked wins - but keep the higher biomass
			-- rather than letting iteration order decide.
			local existing = current[locationId]
			if not existing or state.biomass > existing.biomass then
				current[locationId] = state
			end

		end

	end

	-- Locations that had a hive and no longer do are published as empty once, so the HUD drops
	-- their icons rather than keeping the last thing they showed.
	for locationId, published in pairs(IT.publishedHiveState) do
		if not current[locationId] and not IT.GetHiveStateIsEmpty(published) then
			current[locationId] = IT.MakeHiveState()
		end
	end

	local now = Shared.GetTime()

	for locationId, state in pairs(current) do

		local published = IT.publishedHiveState[locationId]
		local isEmpty = IT.GetHiveStateIsEmpty(state)

		-- An empty state with nothing published is a hive that has nothing to say yet - one still
		-- being built, which is biomass 0 until construction finishes. Publishing it would send the
		-- same "nothing" every tick for the whole build, because an empty state is not cached.
		if isEmpty and not published then
			-- nothing to announce, and nothing outstanding to retract
		elseif GetShouldPublish(published, state, now) then

			IT.BroadcastHiveState(teamNumber, locationId, state)
			state.sentAt = now
			IT.publishedHiveState[locationId] = not isEmpty and state or nil

		end

	end

end
