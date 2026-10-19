-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_WelderIcon.lua
--
-- Post-hook on lua/GUIUnitStatus.lua, the nameplates. Puts a welder icon to the right of a marine
-- teammate's name when that marine carries a welder, so nobody has to ask who has one or hold the
-- scoreboard open to find out. Seen by the marine commander and by marines in the field (Exo pilots
-- included); never by spectators or aliens. Switched by IT.kShowWelderNameplateIcon.
--
-- WHO CARRIES A WELDER COMES FROM THE SCOREBOARD'S DATA, NOT THE NAMEPLATE'S. The nameplate data
-- does have a HasWelder field, but Player_Client.lua only fills it within 10 m of the viewer, because
-- it asks the marine's own weapons and those are only on the client while the marine is close. From
-- the commander chair that is almost never. PlayerInfoEntity.currentTech is worked out on the server
-- for every player, welder included (PlayerInfoEntity.lua, displayWeapons), and is already sent to
-- every client for the scoreboard, so nothing new goes over the network. It is decoded with the
-- game's own GetTechIdsFromBitMask, so a mod that changes the bit layout cannot put it off by one.
-- The close-range HasWelder still counts, so a welder bought right beside you shows at once.
--
-- IT FOLLOWS THE NAME. The icon is a child of the nameplate and shows only while the name does, so
-- it keeps the game's own ranges (13 m in the field, 50 m from the chair) and the game's rules for
-- when names show at all: in first person, only while you aim at the teammate. It sits the same distance right of the text whatever the name's
-- length, and is sized from the name's line height, so small and normal nameplates both fit.
--
-- EVERY VERSION OF THE NAMEPLATES HAS THE SAME SHAPE. CBM ships its own GUIUnitStatus.lua and
-- Devnull's AdvancedHud replaces it, and both keep statusBg, NameText and UpdateUnitStatusBlip as
-- vanilla has them. A post-hook wraps whichever loaded. If a future one does not, the icon is simply
-- never made. Devnull Shine Extras puts its ammo and medpack request icons on the LEFT of the plate,
-- so the two never meet.
--
-- GUIUnitStatus has no subclasses, so plain reassignment of the method reaches every instance.

if not Client then
	return
end

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Config.lua")
Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Common.lua")

local IT = ImprovedTooltips

if type(GUIUnitStatus) ~= "table" or type(GUIUnitStatus.UpdateUnitStatusBlip) ~= "function" then
	return
end

------------------------------------------------------------------------------------------------
-- Who carries a welder
------------------------------------------------------------------------------------------------

-- Player entity id -> true. Rebuilt on an interval rather than per nameplate: the nameplates update
-- every frame, and walking the entity list for each of them would be many times the drawing's cost.
local weldersById = { }
local nextRefresh = 0

local function RefreshWelders()

	local now = Shared.GetTime()

	if now < nextRefresh then
		return
	end

	nextRefresh = now + IT.kWelderIconRefreshInterval

	local fresh = { }
	local welderTechId = kTechId.Welder

	for _, info in ientitylist(Shared.GetEntitiesWithClassname("PlayerInfoEntity")) do

		local id = info.playerId
		local tech = info.currentTech

		if id and id ~= Entity.invalidId and tech and tech > 0 then

			local techIds = GetTechIdsFromBitMask(tech)

			for i = 1, #techIds do
				if techIds[i] == welderTechId then
					fresh[id] = true
					break
				end
			end

		end

	end

	weldersById = fresh

end

------------------------------------------------------------------------------------------------
-- Who sees the icons
------------------------------------------------------------------------------------------------

-- The marine commander and marines in the field. A dead marine waiting to respawn is a
-- MarineSpectator, not a Marine, so is left out along with the spectators. Asked once a frame, not
-- once per nameplate.
local viewerFrame = -1
local viewerSees = false

local function GetViewerSeesIcons()

	local now = Shared.GetTime()

	if now ~= viewerFrame then

		viewerFrame = now

		local player = Client.GetLocalPlayer()

		-- The team test is the one GUIUnitStatus itself uses for the viewer's side.
		viewerSees = player ~= nil
			and PlayerUI_GetTeamType() == kMarineTeamType
			and (player:isa("Marine") or player:isa("Exo") or player:isa("MarineCommander"))

	end

	return viewerSees

end

------------------------------------------------------------------------------------------------
-- The icon
------------------------------------------------------------------------------------------------

local kIconCoords = nil
local kIconAspect = 1

-- The build menu cell for the welder, cropped to the drawing. Read through the game's own lookup so
-- the cell is found the same way the commander's buttons find it.
local function GetIconCoords()

	if not kIconCoords then

		local cell = GetTextureCoordinatesForIcon(kTechId.Welder)
		local inset = IT.kWelderIconCellInset

		kIconCoords = { cell[1] + inset[1], cell[2] + inset[2], cell[3] - inset[3], cell[4] - inset[4] }
		kIconAspect = (kIconCoords[3] - kIconCoords[1]) / (kIconCoords[4] - kIconCoords[2])

	end

	return kIconCoords

end

local function CreateIcon(blip)

	local coords = GetIconCoords()

	local icon = GUIManager:CreateGraphicItem()
	icon:SetAnchor(GUIItem.Middle, GUIItem.Top)
	icon:SetTexture(IT.kBuildMenuTexture)
	icon:SetTexturePixelCoordinates(coords[1], coords[2], coords[3], coords[4])
	icon:SetColor(IT.kWelderIconColor)
	icon:SetIsVisible(false)

	-- A child of the plate, so it moves, hides and is destroyed with it.
	blip.statusBg:AddChild(icon)
	blip.bitWelderIcon = icon

	return icon

end

-- Right of the name text, measured from the text as drawn: NameText is centered on the plate
-- (anchor Middle, Align_Center), so its right edge is half its width right of its position.
local function PlaceIcon(icon, nameText)

	local scale = nameText:GetScale()
	local position = nameText:GetPosition()
	local width = nameText:GetTextWidth(nameText:GetText()) * scale.x
	local lineHeight = nameText:GetTextHeight("!") * scale.y

	local height = lineHeight * IT.kWelderIconHeight
	local x = position.x + width / 2 + lineHeight * IT.kWelderIconGap
	local y = position.y + lineHeight * IT.kWelderIconCenter - height / 2

	icon:SetSize(Vector(height * kIconAspect, height, 0))
	icon:SetPosition(Vector(x, y, 0))

end

local function GetShouldShow(script, blip, blipData)

	if not IT.kShowWelderNameplateIcon or script.visible == false then
		return false
	end

	if not blipData.IsPlayer or blipData.TeamType ~= kMarineTeamType then
		return false
	end

	local nameText = blip.NameText

	if not nameText or not blip.statusBg or not nameText:GetIsVisible() then
		return false
	end

	-- Visible is not enough: in first person the plate stays in the list for every teammate within
	-- 13 m, but the game only fills in the name while you aim at them (PlayerUI_ShowsUnitStatusInfo,
	-- Player_Client.lua:418, plus a 0.2 s cache) and leaves it "" the rest of the time, with the bars
	-- hidden too. Found in game on 2026-10-18: the icon stayed over the marine with no plate showing.
	local text = nameText:GetText()

	if type(text) ~= "string" or not text:find("%S") then
		return false
	end

	if not GetViewerSeesIcons() then
		return false
	end

	RefreshWelders()

	return weldersById[blipData.UnitId] == true or blipData.HasWelder == true

end

local function UpdateWelderIcon(script, blipIndex)

	local blip = script.activeBlipList and script.activeBlipList[blipIndex]
	local blipData = script.activeStatusInfo and script.activeStatusInfo[blipIndex]

	if not blip or not blipData then
		return
	end

	local icon = blip.bitWelderIcon

	if not GetShouldShow(script, blip, blipData) then
		if icon then
			icon:SetIsVisible(false)
		end
		return
	end

	icon = icon or CreateIcon(blip)

	PlaceIcon(icon, blip.NameText)
	icon:SetIsVisible(true)

end

------------------------------------------------------------------------------------------------
-- The hook
------------------------------------------------------------------------------------------------

-- A fault here must never take the nameplates down with it, so the icon runs protected. After the
-- first error it says so once in the console and stops, rather than failing every frame.
local failed = false

local originalUpdateUnitStatusBlip = GUIUnitStatus.UpdateUnitStatusBlip

function GUIUnitStatus:UpdateUnitStatusBlip(blipIndex, localPlayerIsCommander, baseResearchRot, showHints, playerTeamType)

	originalUpdateUnitStatusBlip(self, blipIndex, localPlayerIsCommander, baseResearchRot, showHints, playerTeamType)

	if failed then
		return
	end

	local ok, err = pcall(UpdateWelderIcon, self, blipIndex)

	if not ok then
		failed = true
		Print("[Bleu's Improved Tooltips] welder nameplate icon disabled after an error: %s", tostring(err))
	end

end
