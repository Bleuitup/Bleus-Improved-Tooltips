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
-- Only changes are sent. The state is two small numbers per location that move a handful of times
-- a round, so diffing against what was last published keeps this to a few messages per game rather
-- than a stream.

if not Server then
	return
end

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Values.lua")
Script.Load("lua/ImprovedTooltips/ImprovedTooltips_HiveState.lua")

local IT = ImprovedTooltips

-- A hive counts as busy for any research: biomass, a lifeform ability off the DNA menu, or a hive
-- type upgrade. ResearchMixin only advances while GetIsUnitActive is true, so a hive that is still
-- building or is dying reports its researchingId but is not actually progressing - GetIsResearching
-- is the accessor that accounts for that, when it exists.
local function GetIsHiveResearching(hive)

	if hive.GetIsResearching then
		local ok, researching = pcall(hive.GetIsResearching, hive)
		if ok then
			return researching == true
		end
	end

	if hive.GetResearchingId then
		local ok, researchingId = pcall(hive.GetResearchingId, hive)
		if ok then
			return researchingId ~= nil and researchingId ~= kTechId.None
		end
	end

	return false

end

local originalUpdateAllLocationsSlotData = AlienTeamInfo.UpdateAllLocationsSlotData

function AlienTeamInfo:UpdateAllLocationsSlotData()

	originalUpdateAllLocationsSlotData(self)

	if not IT.kShowHiveBiomassIcons and not IT.kShowHiveResearchIcon then
		return
	end

	local teamNumber = self:GetTeamNumber()
	local current = { }

	for _, hive in ipairs(GetEntitiesForTeam("Hive", teamNumber)) do

		local locationId = hive.locationId

		if hive:GetIsAlive() and locationId and locationId > 0 then

			local biomass = hive.bioMassLevel or 0
			local researching = GetIsHiveResearching(hive)

			-- Two hives sharing a location is not a thing vanilla builds for - AlienTeamInfo keeps
			-- one slot per location and the last hive walked wins - but take the higher biomass and
			-- the busier flag rather than letting iteration order decide.
			local existing = current[locationId]

			if existing then
				existing.biomass = math.max(existing.biomass, biomass)
				existing.researching = existing.researching or researching
			else
				current[locationId] = { biomass = biomass, researching = researching }
			end

		end

	end

	-- Locations that had a hive and no longer do are published as empty once, so the HUD drops
	-- their icons rather than keeping the last thing they showed.
	for locationId, published in pairs(IT.publishedHiveState) do
		if not current[locationId] and (published.biomass > 0 or published.researching) then
			current[locationId] = { biomass = 0, researching = false }
		end
	end

	for locationId, state in pairs(current) do

		local published = IT.publishedHiveState[locationId]
		local isEmpty = state.biomass <= 0 and not state.researching

		-- An empty state with nothing published is a hive that has nothing to say yet - one still
		-- being built, which is biomass 0 until construction finishes. Publishing it would send the
		-- same "nothing" every tick for the whole build, because an empty state is not cached.
		if isEmpty and not published then
			-- nothing to announce, and nothing outstanding to retract
		elseif not published or published.biomass ~= state.biomass or published.researching ~= state.researching then

			IT.BroadcastHiveState(teamNumber, locationId, state.biomass, state.researching)
			IT.publishedHiveState[locationId] = not isEmpty and state or nil

		end

	end

end
