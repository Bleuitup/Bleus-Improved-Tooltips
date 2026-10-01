-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_InsightSupply.lua
--
-- Post-hook on lua/GUIInsight_TopBar.lua. Adds a supply counter for each team to the spectator top
-- bar, which shows resources, resource towers and - on the alien side - biomass, but never supply.
--
-- No new networking. TeamInfo.supplyUsed is an ordinary network var with TeamInfo:GetSupplyUsed()
-- (TeamInfo.lua:42, :348), and the maximum comes from GetMaxSupplyForTeam (NS2Utility.lua:257).
-- The bar already reads both teams' TeamInfo for resources and biomass.
--
-- WHY THE ITEMS ARE MADE HERE RATHER THAN FETCHED. GUIInsight_TopBar keeps every item in a
-- file-local and stores nothing on self, so there is no handle to hang anything off - the same
-- problem ImprovedTooltips_InsightTopBar.lua solves by catching items as they are created. The
-- background is caught the same way here, by its texture, and the supply items are parented to it.
--
-- GEOMETRY, measured from vanilla (GUIInsight_TopBar.lua:139, :219-224). The bar is 512 wide and
-- centered, so its own middle is at 256. Marine items anchor Left and are positioned from the bar's
-- left edge; everything else anchors Right and is positioned leftward from its right edge. In
-- absolute terms across the bar:
--
--   marine extractors  50      marine resources 130      CENTER 256
--   alien resources   317      alien harvesters 397      alien biomass 507
--
-- The first attempt squeezed both counters INSIDE those 512 pixels and they collided with what was
-- already there. The bar is only 512 wide on a screen that is not, so the space either side of it is
-- empty and unused - which is where these go.
--
--   marine supply   left of the bar entirely, outside its left edge
--   alien supply    the slot biomass used to occupy, hard against the right edge
--   alien biomass   pushed further right, out past the bar, one place further out
--
-- Moving vanilla's biomass counter is the one thing here that touches an existing item. Its icon and
-- its text are both children of a holder created by vanilla's CreateIconTextItem, so shifting the
-- HOLDER moves the pair together and leaves their relative layout alone. The holder is reached with
-- icon:GetParent(), the icon having been found by its texture.

if not Client then
	return
end

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Config.lua")
Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Common.lua")

local IT = ImprovedTooltips

local kBackgroundTexture = "ui/topbar.dds"

local supplyItems = { }

local function CreateSupplyItem(background, teamNumber, teamType, offset)

	local iconSize = GUIScale(Vector(32, 32, 0))
	-- The same icon the commander tooltip uses, from the HUD top bar's own theme.
	local texture, coords = IT.GetTopBarSupplyIcon(teamType)

	-- Anchoring follows vanilla's own CreateIconTextItem: marines from the left edge, everyone else
	-- from the right. Mixing the two is what makes the offsets read as mirrored.
	local anchorX = (teamNumber == kTeam1Index) and GUIItem.Left or GUIItem.Right

	local holder = GUIManager:CreateGraphicItem()
	holder:SetAnchor(anchorX, GUIItem.Top)
	holder:SetColor(Color(0, 0, 0, 0))
	holder:SetSize(iconSize)
	background:AddChild(holder)

	local icon = GUIManager:CreateGraphicItem()
	icon:SetAnchor(GUIItem.Left, GUIItem.Top)
	icon:SetSize(iconSize)
	icon:SetPosition(offset)
	icon:SetTexture(texture)

	if coords then
		icon:SetTexturePixelCoordinates(coords[1], coords[2], coords[3], coords[4])
	end

	holder:AddChild(icon)

	local text = GUIManager:CreateTextItem()
	text:SetFontName(Fonts.kAgencyFB_Small)
	text:SetScale(GetScaledVector())
	text:SetAnchor(GUIItem.Left, GUIItem.Center)
	text:SetTextAlignmentX(GUIItem.Align_Min)
	text:SetTextAlignmentY(GUIItem.Align_Center)
	text:SetColor(Color(1, 1, 1, 1))
	text:SetPosition(offset + Vector(iconSize.x + GUIScale(5), 0, 0))
	GUIMakeFontScale(text)
	holder:AddChild(text)

	supplyItems[teamNumber] = { holder = holder, icon = icon, text = text }

end

local originalInitialize = GUIInsight_TopBar.Initialize

function GUIInsight_TopBar:Initialize()

	supplyItems = { }

	if not IT.kShowSpectatorSupply then
		return originalInitialize(self)
	end

	local created = IT.CaptureCreatedGraphicItems(originalInitialize, self)

	local background
	local biomassIcon

	for i = 1, #created do

		local item = created[i]
		local texture = IT.GetItemTexture(item)

		if texture == kBackgroundTexture and not background then
			background = item
		elseif texture == IT.kBuildMenuTexture and not biomassIcon then
			-- The build menu atlas appears exactly once on this bar, for the biomass icon.
			biomassIcon = item
		end

	end

	if not background then
		return
	end

	-- Push vanilla's biomass pair one place further out, freeing the slot beside the right edge for
	-- alien supply. Moving the holder rather than the icon takes the number with it.
	if biomassIcon and type(biomassIcon.GetParent) == "function" then

		local holder = biomassIcon:GetParent()

		if holder and holder ~= background then
			holder:SetPosition(Vector(GUIScale(IT.kSpectatorBiomassShiftX), 0, 0))
		end

	end

	local yoffset = GUIScale(4)

	CreateSupplyItem(background, kTeam1Index, kMarineTeamType,
		Vector(GUIScale(IT.kSpectatorSupplyMarineX), yoffset, 0))

	CreateSupplyItem(background, kTeam2Index, kAlienTeamType,
		Vector(GUIScale(IT.kSpectatorSupplyAlienX), yoffset, 0))

end

local originalUpdate = GUIInsight_TopBar.Update

function GUIInsight_TopBar:Update(deltaTime)

	originalUpdate(self, deltaTime)

	if not IT.kShowSpectatorSupply then
		return
	end

	for teamNumber, items in pairs(supplyItems) do

		local teamInfo = GetTeamInfoEntity(teamNumber)
		local used = (teamInfo and teamInfo.GetSupplyUsed) and teamInfo:GetSupplyUsed() or 0
		local max = GetMaxSupplyForTeam and GetMaxSupplyForTeam(teamNumber) or 0

		-- Formatted like the biomass counter beside it, which reads "%d / 12"
		-- (GUIInsight_TopBar.lua:121-128), so the two read as the same kind of thing.
		items.text:SetText(string.format("%d / %d", used, max))

	end

end
