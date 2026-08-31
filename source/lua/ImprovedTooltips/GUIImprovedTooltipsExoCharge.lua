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
-- The reading is the same one vanilla uses for its own bars in GUIInsight_PlayerHealthbars.lua
-- :300-315, including the inversion on the minigun: heat is reported as remaining capacity, so
-- 100% means ready to fire and 0% means overheated. Both weapons therefore read "more is better",
-- which is the only way one number beside a crosshair is safe to glance at.
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

-- Fraction of "usable" left, 0..1, or nil when the weapon is neither an exo weapon we understand
-- nor present at all. Minigun is inverted so both weapons read the same direction.
local function GetWeaponFraction(weapon)

	if not weapon then
		return nil
	end

	if weapon:isa("Railgun") then
		return weapon:GetChargeAmount()
	end

	if weapon:isa("Minigun") then
		-- heatAmount is declared "float (0 to 1 by 0.01)" and is a plain field, not an accessor.
		local heat = weapon.heatAmount or 0
		return 1 - heat
	end

	return nil

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

function GUIImprovedTooltipsExoCharge:UpdateFigure(item, fraction)

	if not item then
		return
	end

	if not fraction then
		item:SetIsVisible(false)
		return
	end

	local percent = math.floor(math.max(0, math.min(1, fraction)) * 100 + 0.5)

	item:SetText(string.format("%d%%", percent))
	item:SetColor(percent <= IT.kExoChargeWarnBelow and IT.kExoChargeWarnColor or IT.kExoChargeColor)
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

	self:UpdateFigure(self.left,  GetWeaponFraction(GetSlotWeapon(holder, "leftWeaponId")))
	self:UpdateFigure(self.right, GetWeaponFraction(GetSlotWeapon(holder, "rightWeaponId")))

end
