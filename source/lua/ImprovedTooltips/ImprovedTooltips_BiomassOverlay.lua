-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_BiomassOverlay.lua
--
-- Post-hook on lua/GUIBioMassDisplay.lua, the twelve-bead biomass bar that appears in the top left
-- with the map, the buy menu or the tech map open, and for the commander always.
--
-- Two additions, both showing research that is already in flight and that vanilla simply does not
-- draw here:
--
--   1. A partial fill on each bead being researched. Several at once, because two hives researching
--      biomass really are two levels in flight - the same case ImprovedTooltips_BiomassProgress.lua
--      fixed for the tech map in 0.92.
--   2. A progress meter under each ability icon that is currently being researched, drawn the same
--      way the tech map draws its own.
--
-- WHERE THE DATA COMES FROM. Nothing new is networked. Vanilla's own bar reads a single integer,
-- teamInfo:GetBioMassLevel() (GUIBioMassDisplay.lua:272), so it can only ever jump a whole bead at
-- a time - there is no fraction anywhere in that file. But the per-level tech nodes DO carry a
-- fraction: ImprovedTooltips_BiomassProgress.lua writes SetResearchProgress onto BioMassOne..Twelve
-- for every research in flight, and vanilla ships that to clients through its own TechNodeUpdate
-- message. So the client already holds exactly what this file draws, and has since 0.92. Ability
-- nodes carry their own researchProgress the same way, which is what GUITechMap:305-309 reads.
--
-- WHY IT CAN BE A POST-HOOK. GUIBioMassDisplay keeps its pieces on self - self.background,
-- self.foreground, and self.abilityIcons[i][j] holding both .Graphic and .TechId
-- (GUIBioMassDisplay.lua:79-143). So the ability icons can be decorated in place rather than
-- reimplemented, which matters because UpdateAbilityList itself is a file-local and unreachable.
--
-- Everything drawn here is parented under self.background, which vanilla destroys in its own
-- Uninitialize (:242-254) - that is also why vanilla can destroy the ability icons without
-- touching them individually. Destroying a parent takes its children with it.

if not Client then
	return
end

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Config.lua")

local IT = ImprovedTooltips

-- Vanilla file-locals we cannot reach, mirrored. kForegroundCoords is the filled-bar region of
-- ui/biomass_bar.dds (GUIBioMassDisplay.lua:26) and the bar is twelve beads wide, so one bead is a
-- twelfth of it. The bar's on-screen size is read from the item rather than mirrored, so a mod that
-- resizes it stays correct.
local kForegroundCoords = { 0, 0, 1200, 160 }
local kBeadCount = 12

-- Same list, and the same ordering, as ImprovedTooltips_BiomassProgress.lua writes to. The index IS
-- the team biomass level the node stands for, so this must stay positional - never close a gap.
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

local function GetResearchFraction(techTree, techId)

	if not techTree or not techId then
		return 0
	end

	local techNode = techTree:GetTechNode(techId)
	if not techNode or techNode:GetResearched() then
		return 0
	end

	local progress = techNode:GetResearchProgress() or 0

	return math.max(0, math.min(1, progress))

end

------------------------------------------------------------------------------------------------
-- Partial fill on the beads being researched
------------------------------------------------------------------------------------------------

local function GetBeadItem(self, index)

	self.itBeads = self.itBeads or { }

	if not self.itBeads[index] then

		local item = GetGUIManager():CreateGraphicItem()
		item:SetAnchor(GUIItem.Left, GUIItem.Top)
		item:SetInheritsParentAlpha(true)
		item:SetIsVisible(false)
		self.background:AddChild(item)
		self.itBeads[index] = item

	end

	return self.itBeads[index]

end

local function UpdateBeadProgress(self)

	if not self.background or not self.foreground then
		return
	end

	local techTree = GetTechTree()
	local player = Client.GetLocalPlayer()
	local teamInfo = player and GetTeamInfoEntity(player:GetTeamNumber())
	local bioMass = (teamInfo and teamInfo.GetBioMassLevel) and teamInfo:GetBioMassLevel() or 0

	local barSize = self.background:GetSize()
	local beadWidth = barSize.x / kBeadCount
	local texWidth = (kForegroundCoords[3] - kForegroundCoords[1]) / kBeadCount

	local shown = 0

	-- Only levels ABOVE the current one can be in flight, and vanilla's own filled bar already
	-- covers everything at or below it, so there is nothing to overlap.
	for index = bioMass + 1, kBeadCount do

		local fraction = GetResearchFraction(techTree, kBioMassTechIds[index])

		if fraction > 0 then

			shown = shown + 1
			local item = GetBeadItem(self, shown)

			-- Same texture and the same slice of it vanilla uses, just cropped to one bead and then
			-- to the fraction within it. Read from the live item so a re-themed bar follows.
			item:SetTexture(self.foreground:GetTexture())
			item:SetSize(Vector(beadWidth * fraction, barSize.y, 0))
			item:SetPosition(Vector((index - 1) * beadWidth, 0, 0))

			local x1 = kForegroundCoords[1] + (index - 1) * texWidth
			item:SetTexturePixelCoordinates(x1, kForegroundCoords[2], x1 + texWidth * fraction, kForegroundCoords[4])

			item:SetColor(IT.kBiomassBeadProgressColor)
			item:SetIsVisible(true)

		end

	end

	if self.itBeads then
		for i = shown + 1, #self.itBeads do
			self.itBeads[i]:SetIsVisible(false)
		end
	end

end

------------------------------------------------------------------------------------------------
-- Progress meters under the ability icons
------------------------------------------------------------------------------------------------

-- Geometry copied from GUITechMap:131-141: a black plate the width of the icon sitting inside its
-- bottom edge, with the meter inset one pixel. Anchoring Left/Bottom and positioning at -height is
-- what puts it inside rather than below, which also keeps it clear of the icon stacked underneath.
local function GetMeter(levelIcon, height)

	if not levelIcon.itMeterBg then

		local background = GetGUIManager():CreateGraphicItem()
		background:SetAnchor(GUIItem.Left, GUIItem.Bottom)
		background:SetColor(Color(0, 0, 0, 1))
		background:SetInheritsParentAlpha(true)
		levelIcon.Graphic:AddChild(background)

		local meter = GetGUIManager():CreateGraphicItem()
		meter:SetAnchor(GUIItem.Left, GUIItem.Top)
		meter:SetPosition(Vector(1, 1, 0))
		meter:SetInheritsParentAlpha(true)
		background:AddChild(meter)

		levelIcon.itMeterBg = background
		levelIcon.itMeter = meter

	end

	return levelIcon.itMeterBg, levelIcon.itMeter

end

local function UpdateAbilityProgress(self)

	if not self.abilityIcons then
		return
	end

	local techTree = GetTechTree()
	local barSize = self.background and self.background:GetSize()
	local iconSize = barSize and (barSize.x / kBeadCount) or 0

	if iconSize <= 0 then
		return
	end

	local meterHeight = math.max(3, math.floor(iconSize * IT.kBiomassAbilityMeterFraction))

	for i = 1, #self.abilityIcons do

		local levelIcons = self.abilityIcons[i]

		for j = 1, #levelIcons do

			local levelIcon = levelIcons[j]

			if levelIcon.Graphic then

				local fraction = GetResearchFraction(techTree, levelIcon.TechId)

				if fraction > 0 then

					local background, meter = GetMeter(levelIcon, meterHeight)

					background:SetSize(Vector(iconSize, meterHeight, 0))
					background:SetPosition(Vector(0, -meterHeight, 0))
					meter:SetSize(Vector(math.max(0, (iconSize - 2) * fraction), meterHeight - 2, 0))
					meter:SetColor(IT.kBiomassAbilityMeterColor)

					background:SetIsVisible(true)
					meter:SetIsVisible(true)

				elseif levelIcon.itMeterBg then

					levelIcon.itMeterBg:SetIsVisible(false)
					levelIcon.itMeter:SetIsVisible(false)

				end

			end

		end

	end

end

------------------------------------------------------------------------------------------------
-- Hooks
------------------------------------------------------------------------------------------------

local originalUpdate = GUIBioMassDisplay.Update

function GUIBioMassDisplay:Update(deltaTime)

	originalUpdate(self, deltaTime)

	if not IT.kShowBiomassOverlayProgress then
		return
	end

	-- Vanilla returns early from its own Update on most frames - it only refreshes twice a second
	-- unless something is animating (:285-289). These run every frame regardless, which is what a
	-- progress bar wants, and both are cheap: a dozen node lookups and no allocation once the items
	-- exist.
	UpdateBeadProgress(self)
	UpdateAbilityProgress(self)

end

local originalUninitialize = GUIBioMassDisplay.Uninitialize

function GUIBioMassDisplay:Uninitialize()

	-- Everything created here is a child of self.background or of an ability icon, and vanilla
	-- destroys self.background below, taking the whole tree with it. Only the references are
	-- dropped, so a re-initialised script does not reuse destroyed items.
	self.itBeads = nil

	if self.abilityIcons then
		for i = 1, #self.abilityIcons do
			for j = 1, #self.abilityIcons[i] do
				self.abilityIcons[i][j].itMeterBg = nil
				self.abilityIcons[i][j].itMeter = nil
			end
		end
	end

	originalUninitialize(self)

end
