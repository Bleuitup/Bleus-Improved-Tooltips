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
--                   NOTIFICATIONS: vanilla's rotating "working" ring with the DNA glyph inside it, on
--                   any hive researching anything - the pair a player sees on a busy hive.
--                   HIVE PANEL: up to two research slots, the hive's own research and the
--                   evolution chamber's, each the research notification's vertical bar
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

local kBuildMenuTexture = IT.kBuildMenuTexture

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

-- The research slots are the left part of vanilla's own research notification (GUINotificationItem.lua,
-- alien style) - the ringed circle, the vertical progress bar, the icon inside the circle and the
-- countdown under it - without the name plate, drawn at IT.kHiveResearchSlotScale. Every position
-- and size below is the notification's own, in its art pixels, relative to the notification's
-- top-left, so the slot is the notification in miniature:
--
--   frame   kAlienFrameCoordinates {6, 6, 213, 94}, cropped at x 72 where the circle's rim ends and
--           the name plate would begin
--   socket  ProgressBarBackgroundCoords {240, 6, 268, 52} at (-4, 11), tinted ProgressBarBackgroundColor
--   bar     kAlienBarCoordinates {240, 1, 273, 56} at (-4, 6), with a 5px glow top and bottom
--   icon    kAlienIconSize 40 at IconPos (18, 19), corrected per tech as below
--   timer   BottomTextPos (20, -15) from the bottom, centered vertically. Here it is centered in the
--           dark backing instead: x 38.5 is the backing's own middle (art x 22-67), and y 70 sits
--           above the backing's geometric middle because a centered line of digits draws low (the
--           line's height includes room below the baseline that digits never use) and the backing
--           fades towards its bottom. Placed there after the 2026-09-17 test showed it sitting low.
local kNotificationsTexture = "ui/research_notifications.dds"
-- The frame is drawn in two pieces so the dark backing under the countdown can be shortened to
-- suit the smaller countdown: the circle down to y 72 (frame y 66), where the circle ends, and the
-- backing's lower 22 pixels squashed to kTimerBoxHeight. Its width is left as it is: its top 8
-- pixels sit inside the circle piece, behind the rim, so a narrower lower part would step.
local kFrameCoords = { 6, 6, 72, 72 }
local kFrameArtSize = Vector(66, 66, 0)
local kTimerBoxCoords = { 6, 72, 72, 94 }
local kTimerBoxArtPos = Vector(0, 66, 0)
local kTimerBoxArtWidth = 66
local kTimerBoxHeight = 14
local kSocketCoords = { 240, 6, 268, 52 }
local kSocketArtSize = Vector(28, 46, 0)
local kSocketArtPos = Vector(-4, 11, 0)
local kSocketColor = Color(47 / 255, 26 / 255, 11 / 255, 1)
local kBarCoords = { 240, 1, 273, 56 }
local kBarArtSize = Vector(33, 55, 0)
local kBarArtPos = Vector(-4, 6, 0)
local kBarGlow = 5
local kIconArtSize = 40
local kIconArtPos = Vector(18, 19, 0)
local kTimerArtPos = Vector(38.5, 70, 0)

-- GUINotificationItem's per-tech icon corrections, which make each icon fill its circle evenly:
-- { size offset, position offset x, position offset y }, in 80px icon cell pixels, applied at half
-- (the icon is 40 of those 80) exactly as GUINotificationItem:Initialize does. Copied because both
-- tables are file-local there (GetCustomSizeOffsetForTechId / GetCustomPosOffsetForTechId); only the
-- alien entries, keyed by name so a missing tech is skipped. A tech not listed - biomass, or a mod's
-- ability - is drawn plain, which is also what the notification does.
local kVanillaIconCorrections =
{
	Leap = { 33, -4, -3 },
	Xenocide = { 25, 5, 3 },
	BileBomb = { 29, -3, -2 },
	Umbra = { 31, 7, 8 },
	Spores = { 25, 1, 1 },
	MetabolizeEnergy = { 14, 0, -1 },
	MetabolizeHealth = { 14, 0, -2 },
	Stab = { 18, -5, 0 },
	Charge = { 13, -1, 6 },
	BoneShield = { 18, -6, -3 },
	Stomp = { 24, 2, 2 },
	UpgradeToCragHive = { 19, -6, -1 },
	UpgradeToShadeHive = { 23, -8, -1 },
	UpgradeToShiftHive = { 20, -4, -1 },
}
-- The mod's own additions. Biomass One's art, three small spheres, fills less of its cell than any
-- other icon here, and at the slot's 0.85 scale it read smaller than the notification's. +16 makes its
-- icon 48 instead of 40, so on screen it is drawn at the notification's own size.
local kSlotIconCorrections =
{
	ResearchBioMassOne = { 16, 0, 0 },
}
local kIconCorrections = nil

local function GetIconCorrection(techId)

	if not kIconCorrections then
		local corrections = { }
		for _, source in ipairs({ kVanillaIconCorrections, kSlotIconCorrections }) do
			for name, correction in pairs(source) do
				local id = IT.GetTechIdByName(name)
				if id then
					corrections[id] = correction
				end
			end
		end
		kIconCorrections = corrections
	end

	return kIconCorrections[techId]

end

-- The notification's countdown: GUINotificationItem.kDefaultFontName (Fonts.kAgencyFB_Small, read
-- when a slot is made) and the alien TextColor.
local kTimerColor = Color(221 / 255, 188 / 255, 7 / 255, 1)
-- Progress arrives in whole percent, up to a second late, so an estimate can honestly be off by
-- about 1% of the research time plus a second. Only a bigger gap moves the countdown.
local kTimerResyncSeconds = 2

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

-- Two slots per row, for the HIVE PANEL mode: the hive's own research and the
-- evolution chamber's. Which is drawn in which slot is decided every update, so a lone research always
-- takes the first.
local function CreateResearchSlots(slot)

	if not ResolveIcons() then
		return
	end

	-- One art pixel of the notification, on screen.
	local scale = GUIScale(IT.kHiveResearchSlotScale)

	local function NewGraphic(texture)
		local item = GUIManager:CreateGraphicItem()
		item:SetAnchor(GUIItem.Left, GUIItem.Top)
		item:SetTexture(texture)
		item:SetLayer(kGUILayerPlayerHUDForeground4)
		item:SetIsVisible(false)
		slot.background:AddChild(item)
		return item
	end

	slot.itResearchSlots = { }

	for i = 1, #IT.kHiveResearchSlotPositions do

		local origin = GUIScale(IT.kHiveResearchSlotPositions[i])
		local entry = { origin = origin, scale = scale, techId = nil }

		-- Created in the notification's draw order: frame, socket, icon, bar.
		entry.frame = NewGraphic(kNotificationsTexture)
		entry.frame:SetPosition(origin)
		entry.frame:SetSize(kFrameArtSize * scale)
		entry.frame:SetTexturePixelCoordinates(GUIUnpackCoords(kFrameCoords))

		entry.timerBox = NewGraphic(kNotificationsTexture)
		entry.timerBox:SetPosition(origin + kTimerBoxArtPos * scale)
		entry.timerBox:SetSize(Vector(kTimerBoxArtWidth, kTimerBoxHeight, 0) * scale)
		entry.timerBox:SetTexturePixelCoordinates(GUIUnpackCoords(kTimerBoxCoords))

		entry.socket = NewGraphic(kNotificationsTexture)
		entry.socket:SetPosition(origin + kSocketArtPos * scale)
		entry.socket:SetSize(kSocketArtSize * scale)
		entry.socket:SetTexturePixelCoordinates(GUIUnpackCoords(kSocketCoords))
		entry.socket:SetColor(kSocketColor)

		entry.icon = NewGraphic(kBuildMenuTexture)
		entry.icon:SetColor(kIconColors and kIconColors[kAlienTeamType] or Color(1, 1, 1, 1))

		entry.bar = NewGraphic(kNotificationsTexture)

		entry.timer = GUIManager:CreateTextItem()
		entry.timer:SetAnchor(GUIItem.Left, GUIItem.Top)
		entry.timer:SetFontName(Fonts.kAgencyFB_Small)
		entry.timer:SetScale(GUIScale(Vector(1, 1, 0)) * IT.kHiveResearchSlotTimerScale)
		if GUIMakeFontScale then
			GUIMakeFontScale(entry.timer)
		end
		entry.timer:SetTextAlignmentX(GUIItem.Align_Center)
		entry.timer:SetTextAlignmentY(GUIItem.Align_Center)
		entry.timer:SetColor(kTimerColor)
		entry.timer:SetPosition(origin + kTimerArtPos * scale)
		entry.timer:SetLayer(kGUILayerPlayerHUDForeground4)
		entry.timer:SetIsVisible(false)
		slot.background:AddChild(entry.timer)

		slot.itResearchSlots[i] = entry

	end

end

-- Points a slot at a research. The icon only changes when the research does, sized and placed as
-- GUINotificationItem:Initialize places it.
local function SetSlotResearch(entry, techId)

	if entry.techId == techId then
		return
	end

	entry.techId = techId

	local correction = GetIconCorrection(techId)
	local cellToIcon = kIconArtSize / 80
	local sizeOffset = correction and correction[1] * cellToIcon or 0
	local posOffset = correction and Vector(correction[2], correction[3], 0) * cellToIcon or Vector(0, 0, 0)

	local size = kIconArtSize + sizeOffset
	local position = kIconArtPos - Vector(sizeOffset, sizeOffset, 0) * 0.5 + posOffset

	entry.icon:SetSize(Vector(size, size, 0) * entry.scale)
	entry.icon:SetPosition(entry.origin + position * entry.scale)
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
		entry.bar:SetSize(Vector(kBarArtSize.x, height, 0) * s)
		entry.bar:SetPosition(entry.origin + (kBarArtPos + Vector(0, fullHeight - height, 0)) * s)
	end

end

-- The countdown, "00:17" like the notification's. The server sends progress in whole percent at
-- most once a second, so the time left is not read straight off it - that would stall and jump.
-- Each update gives an estimated finish time; the slot keeps its own and counts down to it
-- smoothly, and only takes the new estimate when a research starts or the two drift apart by more
-- than that coarseness explains.
local function SetSlotTimer(entry, techId, progress)

	local researchTime = LookupTechData(techId, kTechDataResearchTimeKey, 0)
	if not researchTime or researchTime <= 0 then
		entry.timer:SetIsVisible(false)
		return
	end

	local now = Shared.GetTime()
	local estimatedEnd = now + researchTime * (1 - progress)

	if entry.timerTechId ~= techId or not entry.timerEnd
			or math.abs(estimatedEnd - entry.timerEnd) > kTimerResyncSeconds then
		entry.timerTechId = techId
		entry.timerEnd = estimatedEnd
	end

	local timeLeft = math.max(0, entry.timerEnd - now)
	local minutes = math.floor(timeLeft / 60)
	local seconds = math.floor(timeLeft - minutes * 60)

	entry.timer:SetText(string.format("%02d:%02d", minutes, seconds))
	entry.timer:SetIsVisible(true)

end

local function HideSlot(entry)
	entry.frame:SetIsVisible(false)
	entry.timerBox:SetIsVisible(false)
	entry.socket:SetIsVisible(false)
	entry.bar:SetIsVisible(false)
	entry.icon:SetIsVisible(false)
	entry.timer:SetIsVisible(false)
	entry.timerTechId = nil
	entry.timerEnd = nil
end

local function UpdateResearchSlots(slot, state, visible)

	local none = kTechId.None
	local researches = { }

	-- The hive's own research (biomass, hive type) first, then the evolution chamber's.
	if state.hiveResearchId ~= none then
		researches[#researches + 1] = { techId = state.hiveResearchId, progress = state.hiveProgress }
	end
	if state.evoResearchId ~= none then
		researches[#researches + 1] = { techId = state.evoResearchId, progress = state.evoProgress }
	end

	for i = 1, #slot.itResearchSlots do

		local entry = slot.itResearchSlots[i]
		local research = researches[i]

		if visible and research then
			SetSlotResearch(entry, research.techId)
			entry.frame:SetIsVisible(true)
			entry.timerBox:SetIsVisible(true)
			entry.socket:SetIsVisible(true)
			entry.icon:SetIsVisible(true)
			SetSlotProgress(entry, research.progress, true)
			if IT.kShowHiveResearchSlotTimers then
				SetSlotTimer(entry, research.techId, research.progress)
			else
				entry.timer:SetIsVisible(false)
			end
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
				GUI.DestroyItem(entry.frame)
				GUI.DestroyItem(entry.timerBox)
				GUI.DestroyItem(entry.socket)
				GUI.DestroyItem(entry.bar)
				GUI.DestroyItem(entry.icon)
				GUI.DestroyItem(entry.timer)
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
