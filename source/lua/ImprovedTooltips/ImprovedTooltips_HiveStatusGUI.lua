-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_HiveStatusGUI.lua
--
-- Post-hook on lua/GUIHiveStatus.lua, the alien hive panel in the top-left corner (Advanced
-- Options -> UI -> hive status, option "CHUD_HiveStatus"). Adds two things to each hive's row:
--
--   Biomass       - one icon per +1 biomass research that hive has completed, beside the location
--                   name. A fresh hive shows none, the same way it shows no hive type icon until it
--                   is upgraded; each research then adds its own button's art, in order.
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
-- The row shows the RESEARCHES a hive has completed, not the biomass it holds. A fresh hive already
-- contributes 1 biomass, but it shows nothing, the same way it shows no hive type icon until it is
-- upgraded to a Crag, Shade or Shift. Each +1 research then adds its own button's icon, in order.
-- That the hive is worth 1 on its own is already legible from the biomass bar, the map's upgrade
-- summary and the tech tree.
--
-- Vanilla's naming is consistent once the scheme is clear: a research is named for how much it has
-- added over the hive's base, not for the level it lands on. So ResearchBioMassOne / Two / Three are
-- the +1, +2 and +3, ResearchBioMassThree is the one that takes a hive to 4, and the team cap of 12
-- is three hives each fully upgraded.
--
-- Keying the icons off the researches rather than off the level means each is simply its own
-- button's art, with no special case for the last one - the denser cluster belongs to
-- ResearchBioMassThree and arrives with it.
--
-- ResearchBioMassFour has no button in vanilla (Hive:GetTechButtons stops at bioMassLevel <= 3) but
-- the node and its icon exist, and bioMassLevel networks up to 6, so it is listed and simply never
-- reached unless a mod adds the research.
local kBiomassResearchNames = { "ResearchBioMassOne", "ResearchBioMassTwo", "ResearchBioMassThree", "ResearchBioMassFour" }

-- Each entry is { coords = ..., techId = ... }. The techId is kept so a compatibility module can
-- claim a colour for it - CBM marks its biomass 5 research out in purple.
local kBiomassIcons = nil
local kDnaIconCoords = nil

local function ResolveIcons()

	if kBiomassIcons then
		return true
	end

	if not GetTextureCoordinatesForIcon then
		return false
	end

	-- Compatibility modules attach themselves on first use, and one of them may want to colour an
	-- icon built below.
	IT.ApplyCompatModules()

	kBiomassIcons = { }

	-- Stop at the first one a mod has removed rather than closing the gap: the position in this list
	-- IS which research the icon stands for.
	for i = 1, #kBiomassResearchNames do
		local techId = kTechId[kBiomassResearchNames[i]]
		if not techId then
			break
		end
		kBiomassIcons[i] = { coords = GetTextureCoordinatesForIcon(techId), techId = techId }
	end

	kDnaIconCoords = GetTextureCoordinatesForIcon(kTechId.LifeFormMenu)

	return true

end


------------------------------------------------------------------------------------------------
-- Building the extra items
------------------------------------------------------------------------------------------------

local function CreateBiomassIcons(slot)

	if not ResolveIcons() then
		return
	end

	local size = GUIScale(Vector(IT.kHiveBiomassIconSize, IT.kHiveBiomassIconSize, 0))
	local origin = GUIScale(IT.kHiveBiomassIconOrigin)
	local spacing = GUIScale(IT.kHiveBiomassIconSpacing)

	slot.itBiomassIcons = { }

	for i = 1, #kBiomassIcons do

		local entry = kBiomassIcons[i]

		local icon = GUIManager:CreateGraphicItem()
		icon:SetSize(size)
		icon:SetAnchor(GUIItem.Left, GUIItem.Top)
		icon:SetPosition(Vector(origin.x + spacing * (i - 1), origin.y, 0))
		icon:SetTexture(kBuildMenuTexture)
		-- Each slot is simply the art of the research it stands for.
		icon:SetTexturePixelCoordinates(GUIUnpackCoords(entry.coords))
		-- Untinted unless a compatibility module has claimed a colour for this research.
		icon:SetColor(IT.GetIconColor(entry.techId) or IT.kHiveBiomassIconColor)
		icon:SetLayer(kGUILayerPlayerHUDForeground4)
		icon:SetIsVisible(false)
		slot.background:AddChild(icon)

		slot.itBiomassIcons[i] = icon

	end

end

local function CreateResearchIcon(slot)

	if not ResolveIcons() then
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
	-- No rotation offset, deliberately. The engine already pivots about the item's own centre, which
	-- is why GUIUnitStatus spins this same art in place without setting one. 0.93 set it to a
	-- normalized (0.5, 0.5) on the theory that (0, 0) meant a corner; it does not, and that pushed
	-- the pivot out to the edge and made the ring orbit a point outside itself.
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
	slot.itResearchDna:SetTexturePixelCoordinates(GUIUnpackCoords(kDnaIconCoords))
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
		-- One icon per RESEARCH completed, so a fresh hive at biomass 1 shows none. Icon i stands
		-- for the i-th +1, which is why the count is one less than the level.
		local researches = state.biomass - 1
		for i = 1, #slot.itBiomassIcons do
			slot.itBiomassIcons[i]:SetIsVisible(visible and i <= researches)
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
