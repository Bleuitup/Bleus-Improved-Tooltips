-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_HiveResearchSlots.lua
--
-- The research slots of the alien hive status panel's HIVE PANEL mode: up to two per hive row, the
-- hive's own research (biomass, hive type) and then its evolution chamber's (abilities). A lone
-- research always takes the first slot. Loaded by ImprovedTooltips_HiveStatusGUI.lua, which creates,
-- updates and destroys them with the rest of each row. See docs/hive-research-slots.md.
--
-- Each slot is the left part of vanilla's own research notification (GUINotificationItem.lua, alien
-- style) - the ringed circle, the vertical progress bar, the icon inside the circle and the countdown
-- under it - without the name plate, drawn at IT.kHiveResearchSlotScale. Every position and size
-- below is the notification's own, in its art pixels, relative to the notification's top-left, so the
-- slot is the notification in miniature:
--
--   frame   kAlienFrameCoordinates {6, 6, 213, 94}, cropped at x 72 where the circle's rim ends and
--           the name plate would begin
--   socket  ProgressBarBackgroundCoords {240, 6, 268, 52} at (-4, 11), tinted ProgressBarBackgroundColor
--   bar     kAlienBarCoordinates {240, 1, 273, 56} at (-4, 6), with a 5px glow top and bottom
--   icon    kAlienIconSize 40 at IconPos (18, 19), corrected per tech as below
--   timer   BottomTextPos (20, -15) from the bottom, centered vertically; here also centered under the
--           circle (x 37) and 1 higher, since the smaller text would otherwise sit left of center

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Values.lua")
Script.Load("lua/ImprovedTooltips/ImprovedTooltips_HiveState.lua")

local IT = ImprovedTooltips

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
local kTimerArtPos = Vector(37, 88 - 16, 0)

-- The notification's countdown: GUINotificationItem.kDefaultFontName (Fonts.kAgencyFB_Small, read
-- when a slot is made) and the alien TextColor.
local kTimerColor = Color(221 / 255, 188 / 255, 7 / 255, 1)
-- Progress arrives in whole percent, up to a second late, so an estimate can honestly be off by
-- about 1% of the research time plus a second. Only a bigger gap moves the countdown.
local kTimerResyncSeconds = 2

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

------------------------------------------------------------------------------------------------
-- Building and destroying
------------------------------------------------------------------------------------------------

-- Creates the slots for one hive row, as children of its background.
function IT.CreateHiveResearchSlots(slot)

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

		entry.icon = NewGraphic(IT.kBuildMenuTexture)
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

		-- The parts a slot shows whenever it holds a research. The bar and the timer are shown or not
		-- by their own rules.
		entry.frameParts = { entry.frame, entry.timerBox, entry.socket, entry.icon }
		entry.allParts = { entry.frame, entry.timerBox, entry.socket, entry.bar, entry.icon, entry.timer }

		slot.itResearchSlots[i] = entry

	end

end

-- Destroys one row's slots. Called before the row's background is destroyed, since it is their
-- parent.
function IT.DestroyHiveResearchSlots(slot)

	if not slot.itResearchSlots then
		return
	end

	for i = 1, #slot.itResearchSlots do
		local parts = slot.itResearchSlots[i].allParts
		for j = 1, #parts do
			GUI.DestroyItem(parts[j])
		end
	end

	slot.itResearchSlots = nil

end

------------------------------------------------------------------------------------------------
-- Updating
------------------------------------------------------------------------------------------------

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
local function SetSlotProgress(entry, progress)

	local fullHeight = kBarArtSize.y
	local fullNoGlow = fullHeight - kBarGlow * 2
	local height = Clamp(math.floor(fullNoGlow * progress), 0, fullNoGlow)

	if height > 0 then
		height = height + kBarGlow
		if height >= fullHeight - kBarGlow then
			height = fullHeight
		end
	end

	entry.bar:SetIsVisible(height > 0)

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
	if not IT.kShowHiveResearchSlotTimers or not researchTime or researchTime <= 0 then
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
	for i = 1, #entry.allParts do
		entry.allParts[i]:SetIsVisible(false)
	end
	entry.timerTechId = nil
	entry.timerEnd = nil
end

-- Shows one row's research from the hive state the server sent, or hides the slots.
function IT.UpdateHiveResearchSlots(slot, state, visible)

	if not slot.itResearchSlots then
		return
	end

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
			for j = 1, #entry.frameParts do
				entry.frameParts[j]:SetIsVisible(true)
			end
			SetSlotProgress(entry, research.progress)
			SetSlotTimer(entry, research.techId, research.progress)
		else
			HideSlot(entry)
		end

	end

end
