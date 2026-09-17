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
--   Researching   - per HIVE RESEARCH DISPLAY (IT.kHiveResearchDisplay):
--                   RING ONLY: vanilla's rotating "working" ring with the DNA glyph inside it, on
--                   any hive researching anything - the pair a player sees on a busy hive.
--                   BOTH / HIVE PANEL ONLY: up to two research slots, the evolution chamber's
--                   research and the hive's own, each the research notification's vertical bar
--                   beside the research icon. See docs/hive-research-slots.md.
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

-- The research slots borrow the research notification's own art, from GUINotificationItem.lua, so a
-- hive row and the notification stack show progress the same way. Alien entries:
--
--   socket  ProgressBarBackgroundCoords {240, 6, 268, 52}, tinted ProgressBarBackgroundColor
--   bar     kAlienBarCoordinates {240, 1, 273, 56}, which includes a 5px glow top and bottom
--
-- In the notification the bar sits 5px above the socket (ProgressBarPos y 6 vs
-- ProgressBarBackgroundPos y 11). That art-pixel offset is kept here and scaled with the socket.
-- The visible crescent ends about 14 art pixels in, which is where the icon's box starts.
local kNotificationsTexture = "ui/research_notifications.dds"
local kSocketCoords = { 240, 6, 268, 52 }
local kSocketArtSize = Vector(28, 46, 0)
local kSocketColor = Color(47 / 255, 26 / 255, 11 / 255, 1)
local kBarCoords = { 240, 1, 273, 56 }
local kBarArtSize = Vector(33, 55, 0)
local kBarGlow = 5
local kBarArtOffsetY = -5
local kCrescentArtWidth = 14

-- Where each research icon's drawn shape sits inside its 80x80 buildmenu.dds cell, as
-- { width, height, centerX, centerY }, keyed by atlas index (row * 12 + column). Measured
-- from the texture's alpha (> 60 of 255) on 2026-09-17. The cells are far from uniform - Biomass
-- One's shape is 44px, Leap's is 56x30 and Biomass Three's 62x66, some off center - which is why
-- drawing whole cells at one size made small, uneven, off-center icons. The notification copes
-- with a private per-tech table in GUINotificationItem.lua that a hook cannot reach. An index not
-- listed here, such as a modded ability, is drawn as a typical 56px shape centered in its cell.
local kIconShapes =
{
	[67]  = { 56, 30, 41.5, 42.5 },   -- Leap
	[95]  = { 55, 47, 37, 38 },       -- Xenocide
	[68]  = { 50, 40, 40.5, 40.5 },   -- Bile Bomb
	[102] = { 66, 49, 38.5, 40 },     -- Webs
	[75]  = { 46, 49, 35.5, 35 },     -- Umbra
	[69]  = { 54, 45, 38.5, 39 },     -- Spores
	[169] = { 66, 45, 39.5, 37 },     -- Metabolize
	[170] = { 66, 45, 39.5, 38 },     -- Advanced Metabolize
	[105] = { 57, 62, 42, 39.5 },     -- Stab
	[111] = { 68, 48, 37.5, 36.5 },   -- Charge
	[156] = { 62, 57, 42.5, 41 },     -- Bone Shield
	[72]  = { 54, 56, 39.5, 38.5 },   -- Stomp
	[157] = { 61, 57, 46, 40 },       -- Crag Hive
	[158] = { 56, 57, 43.5, 40 },     -- Shade Hive
	[159] = { 60, 57, 45.5, 40 },     -- Shift Hive
	[150] = { 44, 46, 39.5, 39.5 },   -- Biomass One
	[112] = { 55, 58, 37, 37.5 },     -- Biomass Two and Four
	[175] = { 62, 66, 39.5, 40.5 },   -- Biomass Three
}
local kDefaultIconShape = { 56, 56, 40, 40 }

-- Each entry is { coords = ..., techId = ... }. The techId is kept so a compatibility module can
-- claim a color for it - CBM marks its biomass 5 research out in purple.
local kBiomassIcons = nil
local kDnaIconCoords = nil

local function ResolveIcons()

	if kBiomassIcons then
		return true
	end

	if not GetTextureCoordinatesForIcon then
		return false
	end

	-- Compatibility modules attach themselves on first use, and one of them may want to color an
	-- icon built below.
	IT.ApplyCompatModules()

	kBiomassIcons = { }

	-- Stop at the first one a mod has removed rather than closing the gap: the position in this list
	-- IS which research the icon stands for.
	for i = 1, #kBiomassResearchNames do
		local techId = IT.GetTechIdByName(kBiomassResearchNames[i])
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
		-- Untinted unless a compatibility module has claimed a color for this research.
		icon:SetColor(IT.GetIconColor(entry.techId) or IT.kBiomassIconColor)
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
	-- No rotation offset, deliberately. The engine already pivots about the item's own center, which
	-- is why GUIUnitStatus spins this same art in place without setting one. 0.93 set it to a
	-- normalized (0.5, 0.5) on the theory that (0, 0) meant a corner; it does not, and that pushed
	-- the pivot out to the edge and made the ring orbit a point outside itself.
	slot.background:AddChild(slot.itResearchRing)

	-- The DNA sits inside the ring and must not spin with it, so it is a sibling positioned to the
	-- same center rather than a child.
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

-- Two slots per row, for the BOTH and HIVE PANEL ONLY modes: the evolution chamber's research and
-- the hive's own. Which is drawn in which slot is decided every update, so a lone research always
-- takes the first.
local function CreateResearchSlots(slot)

	if not ResolveIcons() then
		return
	end

	local barHeight = GUIScale(IT.kHiveResearchSlotBarHeight)
	local scale = barHeight / kSocketArtSize.y
	local iconMax = GUIScale(Vector(IT.kHiveResearchSlotIconMaxWidth, IT.kHiveResearchSlotIconMaxHeight, 0))
	local iconGap = GUIScale(IT.kHiveResearchSlotIconGap)

	slot.itResearchSlots = { }

	for i = 1, #IT.kHiveResearchSlotPositions do

		local origin = GUIScale(IT.kHiveResearchSlotPositions[i])
		local entry = { origin = origin, scale = scale, iconMax = iconMax, iconGap = iconGap, techId = nil }

		entry.socket = GUIManager:CreateGraphicItem()
		entry.socket:SetAnchor(GUIItem.Left, GUIItem.Top)
		entry.socket:SetPosition(origin)
		entry.socket:SetSize(kSocketArtSize * scale)
		entry.socket:SetTexture(kNotificationsTexture)
		entry.socket:SetTexturePixelCoordinates(GUIUnpackCoords(kSocketCoords))
		entry.socket:SetColor(kSocketColor)
		entry.socket:SetLayer(kGUILayerPlayerHUDForeground4)
		entry.socket:SetIsVisible(false)
		slot.background:AddChild(entry.socket)

		entry.bar = GUIManager:CreateGraphicItem()
		entry.bar:SetAnchor(GUIItem.Left, GUIItem.Top)
		entry.bar:SetTexture(kNotificationsTexture)
		entry.bar:SetLayer(kGUILayerPlayerHUDForeground4)
		entry.bar:SetIsVisible(false)
		slot.background:AddChild(entry.bar)

		entry.icon = GUIManager:CreateGraphicItem()
		entry.icon:SetAnchor(GUIItem.Left, GUIItem.Top)
		entry.icon:SetTexture(kBuildMenuTexture)
		entry.icon:SetColor(kIconColors and kIconColors[kAlienTeamType] or Color(1, 1, 1, 1))
		entry.icon:SetLayer(kGUILayerPlayerHUDForeground4)
		entry.icon:SetIsVisible(false)
		slot.background:AddChild(entry.icon)

		slot.itResearchSlots[i] = entry

	end

end

-- Points a slot at a research. The icon only changes when the research does. Its drawn shape, not
-- its cell, is scaled to fit the icon box and centered in it, and the box is centered on the bar.
local function SetSlotResearch(entry, techId)

	if entry.techId == techId then
		return
	end

	entry.techId = techId

	-- kTechIdToMaterialOffset is file-local in TechTreeButtons.lua; GetMaterialXYOffset is the
	-- public way to its index, as a column and row of the 12-wide atlas.
	local column, row = GetMaterialXYOffset(techId)
	local shape = column and kIconShapes[row * 12 + column] or kDefaultIconShape

	local pixelsPerArt = math.min(entry.iconMax.x / shape[1], entry.iconMax.y / shape[2])
	local center = entry.origin + Vector(
		kCrescentArtWidth * entry.scale + entry.iconGap + entry.iconMax.x * 0.5,
		kSocketArtSize.y * entry.scale * 0.5,
		0)

	entry.icon:SetSize(Vector(80, 80, 0) * pixelsPerArt)
	entry.icon:SetPosition(center - Vector(shape[3], shape[4], 0) * pixelsPerArt)
	entry.icon:SetTexturePixelCoordinates(GUIUnpackCoords(GetTextureCoordinatesForIcon(techId)))

end

-- Fills the bar the way GUIEvent fills the notification's (GUIEvent.lua, "Update the bar"): the
-- glow is part of the art, so it is only added once there is progress, and the last stretch snaps
-- to the full height so the top glow shows at completion.
local function SetSlotProgress(entry, progress, visible)

	local fullHeight = kBarArtSize.y
	local fullNoGlow = fullHeight - kBarGlow * 2
	local height = Clamp(math.floor(fullNoGlow * progress), 0, fullNoGlow)

	if height > 0 then
		height = height + kBarGlow
		if height >= fullHeight - kBarGlow then
			height = fullHeight
		end
	end

	entry.bar:SetIsVisible(visible and height > 0)

	if height > 0 then
		local s = entry.scale
		entry.bar:SetTexturePixelCoordinates(kBarCoords[1], kBarCoords[4] - height, kBarCoords[3], kBarCoords[4])
		entry.bar:SetSize(Vector(kBarArtSize.x * s, height * s, 0))
		entry.bar:SetPosition(entry.origin + Vector(0, (kBarArtOffsetY + fullHeight - height) * s, 0))
	end

end

local function HideSlot(entry)
	entry.socket:SetIsVisible(false)
	entry.bar:SetIsVisible(false)
	entry.icon:SetIsVisible(false)
end

local function UpdateResearchSlots(slot, state, visible)

	local none = kTechId.None
	local researches = { }

	if state.evoResearchId ~= none then
		researches[#researches + 1] = { techId = state.evoResearchId, progress = state.evoProgress }
	end
	if state.hiveResearchId ~= none then
		researches[#researches + 1] = { techId = state.hiveResearchId, progress = state.hiveProgress }
	end

	for i = 1, #slot.itResearchSlots do

		local entry = slot.itResearchSlots[i]
		local research = researches[i]

		if visible and research then
			SetSlotResearch(entry, research.techId)
			entry.socket:SetIsVisible(true)
			entry.icon:SetIsVisible(true)
			SetSlotProgress(entry, research.progress, true)
		else
			HideSlot(entry)
		end

	end

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
		CreateResearchSlots(slot)
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

		if slot.itResearchSlots then
			for i = 1, #slot.itResearchSlots do
				local entry = slot.itResearchSlots[i]
				GUI.DestroyItem(entry.socket)
				GUI.DestroyItem(entry.bar)
				GUI.DestroyItem(entry.icon)
			end
			slot.itResearchSlots = nil
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

	local ringMode = IT.kHiveResearchDisplay == IT.kHiveResearchDisplayRing

	if slot.itResearchSlots then
		UpdateResearchSlots(slot, state, visible and not ringMode)
	end

	if slot.itResearchRing then

		local researching = visible and ringMode and state.researching

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
