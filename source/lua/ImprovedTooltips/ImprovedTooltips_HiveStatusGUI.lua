-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_HiveStatusGUI.lua
--
-- Post-hook on lua/GUIHiveStatus.lua, the alien hive panel in the top-left corner (Advanced
-- Options -> UI -> hive status, option "CHUD_HiveStatus"). Adds two things to each hive's row:
--
--   Biomass       - one icon per biomass level that hive has, beside the location name. A fresh
--                   hive is biomass 1 and shows one; each +1 research adds another. The fourth and
--                   last uses the denser icon off the research button that grants it, so a maxed
--                   hive reads differently at a glance from one still climbing.
--
--   Researching   - vanilla's rotating "working" ring with the DNA glyph inside it, on any hive
--                   that is researching anything: biomass, a lifeform ability, or a hive type.
--                   The same pair a player sees in the world when they look at a busy hive.
--
-- Every image here is vanilla's own, addressed through GetTextureCoordinatesForIcon rather than by
-- pixel, so a mod that moves an icon in the atlas moves ours with it. Nothing new was drawn.
--
-- The data comes from the mod's own network message, not from the hives - see
-- ImprovedTooltips_HiveState.lua for why it has to.

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Values.lua")
Script.Load("lua/ImprovedTooltips/ImprovedTooltips_HiveState.lua")

local IT = ImprovedTooltips

local kBuildMenuTexture = "ui/buildmenu.dds"

-- The spinning ring, lifted from where the player already sees it: GUIUnitStatus draws this exact
-- region of the alien status sheet over a unit that is researching, rotating once every
-- kResearchRotationDuration seconds.
local kUnitStatusTexture = "ui/unitstatus_alien.dds"
local kProgressRingCoords = { 256, 68, 256 + 128, 68 + 128 }

-- Icon identities, resolved once on first use because kTechId and the offset table are both
-- populated by files that may load after this one.
--
-- The naming is vanilla's and it is confusing, so: a hive at biomass 3 clicks the button called
-- ResearchBioMassThree to reach biomass 4. That button carries the denser cluster art. The plain
-- ball is what every BioMassN node uses, and ResearchBioMassFour shares it, which is why the fourth
-- icon is keyed off the button rather than off the level.
local kIconCoords = nil

local function GetIconCoords()

	if kIconCoords then
		return kIconCoords
	end

	if not GetTextureCoordinatesForIcon then
		return nil
	end

	kIconCoords =
	{
		ball = GetTextureCoordinatesForIcon(kTechId.BioMassOne),
		dense = GetTextureCoordinatesForIcon(kTechId.ResearchBioMassThree),
		dna = GetTextureCoordinatesForIcon(kTechId.LifeFormMenu),
	}

	return kIconCoords

end

local kMaxBiomassIcons = 4

------------------------------------------------------------------------------------------------
-- Building the extra items
------------------------------------------------------------------------------------------------

local function CreateBiomassIcons(slot)

	local coords = GetIconCoords()
	if not coords then
		return
	end

	local size = GUIScale(Vector(IT.kHiveBiomassIconSize, IT.kHiveBiomassIconSize, 0))
	local origin = GUIScale(IT.kHiveBiomassIconOrigin)
	local spacing = GUIScale(IT.kHiveBiomassIconSpacing)

	slot.itBiomassIcons = { }

	for i = 1, kMaxBiomassIcons do

		local icon = GUIManager:CreateGraphicItem()
		icon:SetSize(size)
		icon:SetAnchor(GUIItem.Left, GUIItem.Top)
		icon:SetPosition(Vector(origin.x + spacing * (i - 1), origin.y, 0))
		icon:SetTexture(kBuildMenuTexture)
		-- The last slot is the denser cluster; the first three are the plain ball.
		icon:SetTexturePixelCoordinates(GUIUnpackCoords(i < kMaxBiomassIcons and coords.ball or coords.dense))
		icon:SetColor(IT.kHiveBiomassIconColor)
		icon:SetLayer(kGUILayerPlayerHUDForeground4)
		icon:SetIsVisible(false)
		slot.background:AddChild(icon)

		slot.itBiomassIcons[i] = icon

	end

end

local function CreateResearchIcon(slot)

	local coords = GetIconCoords()
	if not coords then
		return
	end

	local size = GUIScale(Vector(IT.kHiveResearchIconSize, IT.kHiveResearchIconSize, 0))
	local position = GUIScale(IT.kHiveResearchIconPosition)

	slot.itResearchRing = GUIManager:CreateGraphicItem()
	slot.itResearchRing:SetSize(size)
	slot.itResearchRing:SetAnchor(GUIItem.Left, GUIItem.Top)
	slot.itResearchRing:SetPosition(position)
	slot.itResearchRing:SetTexture(kUnitStatusTexture)
	slot.itResearchRing:SetTexturePixelCoordinates(GUIUnpackCoords(kProgressRingCoords))
	slot.itResearchRing:SetColor(IT.kHiveResearchRingColor)
	slot.itResearchRing:SetLayer(kGUILayerPlayerHUDForeground4)
	slot.itResearchRing:SetIsVisible(false)
	-- Spin about the middle rather than a corner. GUIUnitStatus gets away without saying so, but
	-- saying it outright costs nothing and does not depend on what the engine defaults to.
	if slot.itResearchRing.SetRotationOffsetNormalized then
		slot.itResearchRing:SetRotationOffsetNormalized(Vector(0.5, 0.5, 0))
	end
	slot.background:AddChild(slot.itResearchRing)

	-- The DNA sits inside the ring and must not spin with it, so it is a sibling positioned to the
	-- same centre rather than a child.
	local dnaSize = size * IT.kHiveResearchDnaScale
	local inset = (size - dnaSize) * 0.5

	slot.itResearchDna = GUIManager:CreateGraphicItem()
	slot.itResearchDna:SetSize(dnaSize)
	slot.itResearchDna:SetAnchor(GUIItem.Left, GUIItem.Top)
	slot.itResearchDna:SetPosition(position + inset)
	slot.itResearchDna:SetTexture(kBuildMenuTexture)
	slot.itResearchDna:SetTexturePixelCoordinates(GUIUnpackCoords(coords.dna))
	slot.itResearchDna:SetColor(IT.kHiveResearchDnaColor)
	slot.itResearchDna:SetLayer(kGUILayerPlayerHUDForeground4)
	slot.itResearchDna:SetIsVisible(false)
	slot.background:AddChild(slot.itResearchDna)

end

------------------------------------------------------------------------------------------------
-- Hooks
------------------------------------------------------------------------------------------------

local originalCreateStatusContainer = GUIHiveStatus.CreateStatusContainer

function GUIHiveStatus:CreateStatusContainer(slotIdx, locationId)

	originalCreateStatusContainer(self, slotIdx, locationId)

	local slot = self.statusSlots[slotIdx]
	if not slot or not slot.background then
		return
	end

	if IT.kShowHiveBiomassIcons then
		CreateBiomassIcons(slot)
	end

	if IT.kShowHiveResearchIcon then
		CreateResearchIcon(slot)
	end

end

local originalUninitializeStatusSlot = GUIHiveStatus.UninitializeStatusSlot

function GUIHiveStatus:UninitializeStatusSlot(slotIdx)

	-- Ours go first: the original destroys slot.background, which is their parent.
	local slot = self.statusSlots[slotIdx]

	if slot then

		if slot.itBiomassIcons then
			for i = 1, #slot.itBiomassIcons do
				GUI.DestroyItem(slot.itBiomassIcons[i])
			end
			slot.itBiomassIcons = nil
		end

		if slot.itResearchRing then
			GUI.DestroyItem(slot.itResearchRing)
			slot.itResearchRing = nil
		end

		if slot.itResearchDna then
			GUI.DestroyItem(slot.itResearchDna)
			slot.itResearchDna = nil
		end

	end

	originalUninitializeStatusSlot(self, slotIdx)

end

local originalUpdateStatusSlot = GUIHiveStatus.UpdateStatusSlot

function GUIHiveStatus:UpdateStatusSlot(slotIdx, slotData)

	originalUpdateStatusSlot(self, slotIdx, slotData)

	local slot = self.statusSlots[slotIdx]
	if not slot then
		return
	end

	local locationId = (slotData and slotData.locationId) or slot._locationId
	local state = IT.GetHiveState(locationId)
	local visible = self.visible == true

	if slot.itBiomassIcons then
		for i = 1, #slot.itBiomassIcons do
			slot.itBiomassIcons[i]:SetIsVisible(visible and i <= state.biomass)
		end
	end

	if slot.itResearchRing then

		local researching = visible and state.researching

		slot.itResearchRing:SetIsVisible(researching)
		slot.itResearchDna:SetIsVisible(researching)

		if researching then
			-- Same rate and direction as the ring the player sees on the hive itself, so the two
			-- read as the same indicator rather than two different ones.
			local turn = (Shared.GetTime() % IT.kHiveResearchRotationDuration) / IT.kHiveResearchRotationDuration
			slot.itResearchRing:SetRotation(Vector(0, 0, -2 * math.pi * turn))
		end

	end

end
