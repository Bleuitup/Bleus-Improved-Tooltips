-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_MistBadge.lua
--
-- Post-hook on lua/GUIUnitStatus.lua, the units' status plates. In the alien commander's view, a
-- badge above every alien entity the nutrient mist is helping right now: embryos, anything still
-- growing, and disconnected cysts (the rule is IT.GetIsMistHelping, ImprovedTooltips_Common.lua).
-- The mist cloud is hard to see under alien vision and is gone once it dissipates, and a commander
-- who takes the chair mid-mist cannot tell who is misted; this answers both at a glance. Always on.
--
-- THE BADGE is the tech-tree mist icon (buildmenu.dds, through GetTextureCoordinatesForIcon) tinted
-- green, with the HUD status row's own green up arrow (player_status_icons.dds, the arrow vanilla
-- puts on alien buffs like Umbra and Energize) in its bottom-right corner. Option C, 48 px, chosen
-- from mockups on 2026-10-30.
--
-- IT FOLLOWS THE PLATE. It is a child of the unit's status plate (statusBg), centered just above it,
-- so it moves with the unit and goes when the unit leaves the commander's view or range (50 m,
-- Player_Client.lua:376). Unlike the welder icon it does not wait for a name: a commander's plates
-- show names only on hover, and the badge is meant to be seen without hovering.
--
-- The second post-hook on this file; ImprovedTooltips_WelderIcon.lua wraps the same method first.
-- Both call what they wrapped before doing their own part, so the order does not matter.

if not Client then
	return
end

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Config.lua")
Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Common.lua")

local IT = ImprovedTooltips

if type(GUIUnitStatus) ~= "table" or type(GUIUnitStatus.UpdateUnitStatusBlip) ~= "function" then
	return
end

local kStatusIconsTexture = "ui/player_status_icons.dds"
-- GUIPlayerStatus.kArrowUpCoords, read at use when that script has loaded; this is its value.
local kArrowUpCoords = { 96, 352, 128, 384 }

local function GetArrowCoords()
	local coords = GUIPlayerStatus and GUIPlayerStatus.kArrowUpCoords
	if type(coords) == "table" and #coords == 4 then
		return coords
	end
	return kArrowUpCoords
end

-- Only the alien commander. Asked once a frame, not once per plate.
local viewerFrame = -1
local viewerSees = false

local function GetViewerSeesBadges()

	local now = Shared.GetTime()

	if now ~= viewerFrame then
		viewerFrame = now
		local player = Client.GetLocalPlayer()
		viewerSees = player ~= nil and player:isa("AlienCommander")
	end

	return viewerSees

end

local function CreateBadge(blip)

	local size = GUIScale(IT.kMistBadgeSize)
	local gap = GUIScale(IT.kMistBadgeGap)

	local badge = GUIManager:CreateGraphicItem()
	badge:SetAnchor(GUIItem.Middle, GUIItem.Top)
	badge:SetSize(Vector(size, size, 0))
	badge:SetPosition(Vector(-size / 2, -size - gap, 0))
	badge:SetTexture(IT.kBuildMenuTexture)
	local cell = GetTextureCoordinatesForIcon(kTechId.NutrientMist)
	badge:SetTexturePixelCoordinates(cell[1], cell[2], cell[3], cell[4])
	badge:SetColor(IT.kMistBadgeColor)
	badge:SetIsVisible(false)

	local arrowSize = size * IT.kMistBadgeArrowFraction
	local arrow = GUIManager:CreateGraphicItem()
	arrow:SetAnchor(GUIItem.Right, GUIItem.Bottom)
	arrow:SetSize(Vector(arrowSize, arrowSize, 0))
	arrow:SetPosition(Vector(-arrowSize, -arrowSize, 0))
	arrow:SetTexture(kStatusIconsTexture)
	local coords = GetArrowCoords()
	arrow:SetTexturePixelCoordinates(coords[1], coords[2], coords[3], coords[4])
	badge:AddChild(arrow)

	-- A child of the plate, so it moves, hides and is destroyed with it.
	blip.statusBg:AddChild(badge)
	blip.bitMistBadge = badge

	return badge

end

local function UpdateMistBadge(script, blipIndex)

	local blip = script.activeBlipList and script.activeBlipList[blipIndex]
	local blipData = script.activeStatusInfo and script.activeStatusInfo[blipIndex]

	if not blip or not blipData or not blip.statusBg then
		return
	end

	local show = IT.kShowNutrientMistIndicators and script.visible ~= false and GetViewerSeesBadges()
		and IT.GetIsMistHelping(Shared.GetEntity(blipData.UnitId))

	local badge = blip.bitMistBadge

	if not show then
		if badge then
			badge:SetIsVisible(false)
		end
		return
	end

	badge = badge or CreateBadge(blip)
	badge:SetIsVisible(true)

end

-- A fault here must never take the plates down with it: run protected, and after the first error
-- say so once in the console and stop.
local failed = false

local originalUpdateUnitStatusBlip = GUIUnitStatus.UpdateUnitStatusBlip

function GUIUnitStatus:UpdateUnitStatusBlip(blipIndex, localPlayerIsCommander, baseResearchRot, showHints, playerTeamType)

	originalUpdateUnitStatusBlip(self, blipIndex, localPlayerIsCommander, baseResearchRot, showHints, playerTeamType)

	if failed then
		return
	end

	local ok, err = pcall(UpdateMistBadge, self, blipIndex)

	if not ok then
		failed = true
		Print("[Bleu's Improved Tooltips] nutrient mist badges disabled after an error: %s", tostring(err))
	end

end
