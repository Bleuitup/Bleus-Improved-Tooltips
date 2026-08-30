-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_BiomassProgress.lua
--
-- Post-hook on lua/AlienTeam.lua. Server only - AlienTeam.lua is loaded by Server.lua and by
-- nothing else, so the class does not exist in the client VM at all.
--
-- Fixes the tech map showing only ONE biomass level in progress when several hives are researching
-- biomass at the same time. With two hives at biomass 1 each (team biomass 2) both researching,
-- vanilla lights up BioMassThree alone; BioMassFour stays dark even though it is just as much on
-- its way.
--
-- The cause is in AlienTeam:UpdateBioMassLevel. It walks the hives building a single scalar:
--
--     if bioMassAdd > progress then
--         progress = bioMassAdd
--     end
--
-- taking the MAX across every hive, and then writes that one number to exactly one node:
--
--     local techNodeProgress = i == self.bioMassLevel + 1 and progress or 0
--
-- Everything above the next level is explicitly zeroed. So the information is not missing from the
-- server, it is discarded one step before it would have been sent: each hive knows its own
-- fraction, and the team throws all but the largest away.
--
-- This is display only. Node research progress is not what gates anything - availability runs off
-- GetHasTech / GetAvailable / GetResearched, and the per-hive research itself is driven by
-- ResearchMixin against the ResearchBioMassN nodes, none of which this file touches. Fixing it
-- server-side rather than in the GUI means it flows out through vanilla's own TechNodeUpdate
-- message to every client, so the tech map, spectators and anything else reading the nodes all
-- agree, with no GUI code at all.

if not Server then
	return
end

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Values.lua")

local IT = ImprovedTooltips

-- Mirrors the file-local kBioMassTechIds in AlienTeam.lua, which we cannot reach. The index IS the
-- team biomass level the node stands for, so this list must stay positional: a missing entry is
-- skipped in place rather than closing the gap.
local kBioMassTechIds =
{
	kTechId.BioMassOne,
	kTechId.BioMassTwo,
	kTechId.BioMassThree,
	kTechId.BioMassFour,
	kTechId.BioMassFive,
	kTechId.BioMassSix,
	kTechId.BioMassSeven,
	kTechId.BioMassEight,
	kTechId.BioMassNine,
	kTechId.BioMassTen,
	kTechId.BioMassEleven,
	kTechId.BioMassTwelve,
}

-- One entry per hive that is on its way to adding a biomass level, holding both the fraction to
-- display and an estimate of how long it has left.
--
-- `fraction` mirrors vanilla's own bioMassAdd exactly, so the number drawn on a bar is the number
-- vanilla would have drawn. `remaining` exists only to order the entries, and is never displayed.
--
-- Vanilla resets biomassResearchFraction to 0 on research complete and on cancel, and only writes
-- it while the researching id is a biomass research, so a non-zero value means "this hive is part
-- way through a biomass research" and GetResearchingId names which one. A hive still under
-- construction cannot research at all (GetIsUnitActive gates ResearchMixin), so the two branches
-- are mutually exclusive in practice; both are kept because vanilla adds them.
local function GetPendingBiomass(team)

	local pending = { }

	for _, hive in ipairs(GetEntitiesForTeam("Hive", team:GetTeamNumber())) do

		if hive:GetIsAlive() then

			local fraction = hive.biomassResearchFraction or 0
			local remaining = nil

			if fraction > 0 then

				local researchId = hive.GetResearchingId and hive:GetResearchingId()
				local researchTime = researchId and LookupTechData(researchId, kTechDataResearchTimeKey, 0) or 0

				if researchTime > 0 then
					remaining = (1 - fraction) * researchTime
				end

			end

			if not hive:GetIsBuilt() then

				local builtFraction = hive:GetBuiltFraction() or 0
				fraction = fraction + builtFraction

				local buildTime = hive.GetTotalConstructionTime and hive:GetTotalConstructionTime() or 0

				if buildTime > 0 then
					remaining = (1 - builtFraction) * buildTime
				end

			end

			if fraction > 0 then
				-- No estimate means "assume furthest out", which sorts it last without inventing a
				-- number. A hive being welded has no fixed finish time anyway; it depends entirely
				-- on how many gorges are on it.
				table.insert(pending, { fraction = math.min(fraction, 1), remaining = remaining or math.huge })
			end

		end

	end

	return pending

end

local function SortBySoonest(a, b)
	return a.remaining < b.remaining
end

local originalUpdateBioMassLevel = AlienTeam.UpdateBioMassLevel

function AlienTeam:UpdateBioMassLevel()

	originalUpdateBioMassLevel(self)

	if not IT.kSpreadBiomassProgress then
		return
	end

	local techTree = self.techTree

	if not techTree then
		return
	end

	local pending = GetPendingBiomass(self)

	-- With nothing or a single thing in flight, vanilla's max IS that one fraction and it already
	-- landed on the right node. Leaving early keeps the common case byte-for-byte vanilla.
	if #pending < 2 then
		return
	end

	-- Sorted by time left, not by fraction. Biomass researches are not the same length - 25, 40, 60
	-- and 80 seconds for levels one through four - so the hive that is furthest along is not
	-- necessarily the one that finishes first. A hive 20% into a 25 second research beats one 50%
	-- into a 60 second research, and it is the first to finish that takes the team to the next
	-- level, which is the node the bar belongs on. Ordering by time is also stable: every remaining
	-- time counts down at one second per second, so entries can never swap places and start
	-- trading bars.
	table.sort(pending, SortBySoonest)

	local level = self.bioMassLevel or 0

	for i = 1, #pending do

		local index = level + i

		if index > #kBioMassTechIds then
			break
		end

		local techId = kBioMassTechIds[index]
		local techNode = techId and techTree:GetTechNode(techId)
		local progress = pending[i].fraction

		if techNode and techNode:GetResearchProgress() ~= progress then
			techNode:SetResearchProgress(progress)
			techTree:SetTechNodeChanged(techNode, string.format("researchProgress = %.2f", progress))
		end

	end

end
