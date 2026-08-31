-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/GUIImprovedTooltipsExoCharge.lua
--
-- Minigun and railgun charge as a percentage beside the crosshair, for exo pilots who have hidden
-- their viewmodel.
--
-- WHY THIS IS NEEDED. Vanilla does show both figures, but it draws them into the viewmodel: the
-- minigun's heat gauge and the railgun's charge ring are GUIViews rendered onto the weapon model's
-- own texture -- Minigun.lua:390-400 renders "lua/GUI<Slot>MinigunDisplay.lua" into
-- "*exo_minigun_<slot>", Railgun.lua:364-375 does the same into "*exo_railgun_<slot>". Hide the
-- viewmodel and the surface those are painted on goes with it, taking the readout along.
--
-- Vanilla knows the hidden-viewmodel exo is a special case and already patches part of it:
-- GUIMarineHUD.lua:979-990 restores the armour text for exactly this combination. It does nothing
-- about weapon charge.
--
-- IMPORTANT, because it is easy to assume otherwise: the charge values are NOT locked inside the
-- animation. Both are ordinary network vars -- Minigun's "heatAmount" is a float 0..1
-- (Minigun.lua:68) and Railgun's "timeChargeStarted" is a time (Railgun.lua:38) behind the public
-- Railgun:GetChargeAmount() (Railgun.lua:203). Only the *rendering surface* is tied to the
-- viewmodel. So this script reads the same numbers vanilla does; nothing is being reverse
-- engineered out of animation state.
--
-- The values come from the same place vanilla's own bars read them (GUIInsight_PlayerHealthbars.lua
-- :300-315), but they are presented differently, on the user's call (2026-08-31):
--
--   Minigun  shows HEAT.    0% = cool, 100% = overheated.  Higher is worse.
--   Railgun  shows CHARGE.  0% = empty, 100% = ready.      Higher is better.
--
-- Vanilla's bar inverts the minigun to "remaining capacity" so both weapons fill the same
-- direction. That is deliberately not done here: the figure is labelled by what the weapon is
-- actually doing, and "heat" counting up is what a pilot expects. The cost is that the two weapons
-- read in OPPOSITE directions, so there is no single warning threshold - each weapon carries its
-- own, and kExoChargeWarnAbove/kExoChargeReadyAt are separate settings for that reason.
--
-- Unlike vanilla's bar, the two slots are NOT averaged. An exo's arms overheat independently and
-- averaging them hides the one that matters; each slot gets its own figure on its own side.

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Config.lua")

local IT = ImprovedTooltips

class 'GUIImprovedTooltipsExoCharge' (GUIScript)

local kFontSize
local kOffsetX
local kOffsetY

local function UpdateScale()
	kFontSize = GUIScale(IT.kExoChargeFontSize)
	kOffsetX  = GUIScale(IT.kExoChargeOffsetX)
	kOffsetY  = GUIScale(IT.kExoChargeOffsetY)
end

-- Returns the fraction to print (0..1) and which way it reads: "heat" counts up towards bad,
-- "charge" counts up towards ready. nil means this is not a weapon we show a figure for.
local function GetWeaponFraction(weapon)

	if not weapon then
		return nil, nil
	end

	if weapon:isa("Railgun") then
		return weapon:GetChargeAmount(), "charge"
	end

	if weapon:isa("Minigun") then
		-- heatAmount is declared "float (0 to 1 by 0.01)" and is a plain field, not an accessor.
		-- Shown as-is: heat counting up, not vanilla's inverted "capacity remaining".
		return weapon.heatAmount or 0, "heat"
	end

	return nil, nil

end

-- Shared.GetEntity(Entity.invalidId) is not guaranteed to be nil-safe across versions, so the id is
-- checked before it is dereferenced.
local function GetSlotWeapon(holder, idField)

	local id = holder[idField]
	if not id or id == Entity.invalidId then
		return nil
	end

	return Shared.GetEntity(id)

end

function GUIImprovedTooltipsExoCharge:Initialize()

	UpdateScale()

	self.left  = self:CreateFigure(GUIItem.Align_Max)
	self.right = self:CreateFigure(GUIItem.Align_Min)

	self.visible = true

end

function GUIImprovedTooltipsExoCharge:CreateFigure(alignX)

	local item = GUIManager:CreateTextItem()
	item:SetFontName(Fonts.kAgencyFB_Small)
	item:SetFontSize(kFontSize)
	item:SetScale(GetScaledVector())
	item:SetAnchor(GUIItem.Middle, GUIItem.Center)
	item:SetTextAlignmentX(alignX)
	item:SetTextAlignmentY(GUIItem.Align_Center)
	item:SetFontIsBold(true)
	item:SetColor(IT.kExoChargeColor)
	item:SetIsVisible(false)
	GUIMakeFontScale(item)

	-- Align_Max sits to the LEFT of the anchor and Align_Min to the right, so the sign of the
	-- offset follows the alignment rather than being written out twice.
	local x = (alignX == GUIItem.Align_Max) and -kOffsetX or kOffsetX
	item:SetPosition(Vector(x, kOffsetY, 0))

	return item

end

function GUIImprovedTooltipsExoCharge:Uninitialize()

	if self.left then
		GUI.DestroyItem(self.left)
		self.left = nil
	end

	if self.right then
		GUI.DestroyItem(self.right)
		self.right = nil
	end

end

function GUIImprovedTooltipsExoCharge:OnResolutionChanged()

	self:Uninitialize()
	self:Initialize()

end

function GUIImprovedTooltipsExoCharge:SetIsVisible(isVisible)

	self.visible = isVisible

	if not isVisible then
		self:HideBoth()
	end

end

function GUIImprovedTooltipsExoCharge:GetIsVisible()
	return self.visible
end

function GUIImprovedTooltipsExoCharge:HideBoth()

	if self.left then
		self.left:SetIsVisible(false)
	end

	if self.right then
		self.right:SetIsVisible(false)
	end

end

function GUIImprovedTooltipsExoCharge:UpdateFigure(item, fraction, kind)

	if not item then
		return
	end

	if not fraction then
		item:SetIsVisible(false)
		return
	end

	local percent = math.floor(math.max(0, math.min(1, fraction)) * 100 + 0.5)

	-- The two weapons read in opposite directions, so each gets its own test: a hot minigun is the
	-- warning, a full railgun is the good news.
	local highlight
	if kind == "heat" then
		highlight = percent >= IT.kExoChargeWarnAbove and IT.kExoChargeWarnColor or nil
	else
		highlight = percent >= IT.kExoChargeReadyAt and IT.kExoChargeReadyColor or nil
	end

	item:SetText(string.format("%d%%", percent))
	item:SetColor(highlight or IT.kExoChargeColor)
	item:SetIsVisible(true)

end

function GUIImprovedTooltipsExoCharge:Update(deltaTime)

	PROFILE("GUIImprovedTooltipsExoCharge:Update")

	if not self.visible or not IT.kShowExoChargeNumbers then
		self:HideBoth()
		return
	end

	local player = Client.GetLocalPlayer()
	if not player or not player:isa("Exo") then
		self:HideBoth()
		return
	end

	-- The whole point of the script. Client.kHideViewModel is recomputed by ViewModelOption_Update
	-- (NS2Utility.lua:1781) whenever any of the drawviewmodel options change, and is the same flag
	-- vanilla's own hidden-viewmodel exo path tests at GUIMarineHUD.lua:980.
	if IT.kExoChargeOnlyWhenViewModelHidden and Client.kHideViewModel ~= true then
		self:HideBoth()
		return
	end

	local holder = player:GetActiveWeapon()
	if not holder or not holder:isa("ExoWeaponHolder") then
		self:HideBoth()
		return
	end

	-- GetWeaponFraction returns two values and must therefore stay in FINAL argument position:
	-- Lua truncates a multi-value call to one value anywhere else, which would silently drop the
	-- "heat"/"charge" kind and make every figure behave like a railgun.
	self:UpdateFigure(self.left,  GetWeaponFraction(GetSlotWeapon(holder, "leftWeaponId")))
	self:UpdateFigure(self.right, GetWeaponFraction(GetSlotWeapon(holder, "rightWeaponId")))

end
