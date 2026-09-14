-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/GUIImprovedTooltipsExoBars.lua
--
-- A bar and a percentage beside the crosshair for each exo arm - minigun heat, railgun charge, and
-- plasma launcher energy under CBM - for pilots who have hidden the exo viewmodel.
--
-- WHY THIS IS NEEDED. Vanilla does show these figures, but it paints them onto the viewmodel: the
-- minigun's heat gauge and the railgun's charge ring are GUIViews rendered into the weapon model's
-- own texture (Minigun.lua:390-400, Railgun.lua:364-375), and CBM's plasma launcher renders its dial
-- into the same railgun surface. Hide the viewmodel and the surface goes, taking the readout along.
-- The values themselves are ordinary network vars, so this reads exactly what vanilla reads.
--
-- WHEN IT SHOWS, settled with the user (2026-09-14). All of these:
--
--   * The Mods panel setting is on (IT.kShowExoWeaponBars, default on).
--   * The local player is a living exo.
--   * The exo viewmodel is hidden: Client.kHideViewModel, which ViewModelOption_Update
--     (NS2Utility.lua:1781) sets for "Hide all" and for "Custom" with the exo hidden. It is
--     recomputed whenever the local player changes (Client.lua:1812), so becoming an exo is covered.
--   * Marine HUD bars are "Default" (hudbars_m == 0). Centralized and NS1 already carry an exo weapon
--     readout on their own bars (NS2Utility.lua:84-99), averaged across both arms.
--
-- WHAT EACH ARM SHOWS. Detected by what the weapon exposes, not by class name, so vanilla, CBM and
-- CBM's dev branch all work with nothing hardcoded, and so would any other mod's arm built the same
-- way:
--
--   heatAmount (Minigun)                     HEAT: fills as it heats. Base color, blending to warn
--                                            then hot, and pulsing red once overheated.
--   GetChargeAmount + energyCost             ENERGY POOL (CBM PlasmaLauncher): fill is stored energy,
--                                            a tick marks the shot cost, read live. Dim below the
--                                            tick, CBM's own mode color once a shot is affordable.
--   GetChargeAmount only (Railgun)           CHARGE: 0 until the trigger is held, then fills. Turns
--                                            the ready color at 100%.
--   none of the above (Claw)                 nothing on that side.
--
-- Each arm is read on its own side. Vanilla's bars average the two, which hides the arm that matters.
--
-- THE LOOK. The ydy "4x wide" center HUD bar stroke - a solid fill inside a thin outlined track - at
-- twice its thickness, further from the crosshair so it clears the exo reticle's center. Drawn from
-- plain GUI items rather than sampling ui/centerhudbar.dds, so it looks the same whichever bar texture
-- a player has installed. Geometry follows GUIAdvancedHUDBars.lua:51-61: GUIScale, and the crosshair
-- scale when it is above 1.

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Config.lua")

local IT = ImprovedTooltips

class 'GUIImprovedTooltipsExoBars' (GUIScript)

-- The track, in fractions of the bar's thickness, copied from the ydy texture: a 10 texel track with
-- a strong outer edge (alpha 179) and a faint inner edge (alpha 72) on each side, and an 8 texel fill.
local kOuterEdgeAlpha = 179 / 255
local kInnerEdgeAlpha = 72 / 255
local kTickColor      = Color(1, 1, 1, 0.9)
local kOptionPollInterval = 0.5

local function Clamp01(value)
	return math.max(0, math.min(1, value))
end

local function LerpInto(out, a, b, t)
	t = Clamp01(t)
	out.r = a.r + (b.r - a.r) * t
	out.g = a.g + (b.g - a.g) * t
	out.b = a.b + (b.b - a.b) * t
	out.a = a.a + (b.a - a.a) * t
	return out
end

local function CopyInto(out, c, alpha)
	out.r, out.g, out.b, out.a = c.r, c.g, c.b, alpha or c.a
	return out
end

local function GetCrosshairScale()
	local scale = GetAdvancedOption and GetAdvancedOption("crosshairscale") or 1
	return (type(scale) == "number" and scale > 1) and scale or 1
end

local function GetHudBarsMode()
	local mode = GetAdvancedOption and GetAdvancedOption("hudbars_m") or 0
	return type(mode) == "number" and mode or 0
end

-- Shared.GetEntity(Entity.invalidId) is not guaranteed nil-safe, so the id is checked first.
local function GetSlotWeapon(holder, idField)
	local id = holder[idField]
	if not id or id == Entity.invalidId then
		return nil
	end
	return Shared.GetEntity(id)
end

function GUIImprovedTooltipsExoBars:Initialize()

	self.crosshairScale = GetCrosshairScale()
	self.hudBarsMode = GetHudBarsMode()
	self.nextOptionPoll = 0

	local scale = self.crosshairScale
	local function Px(value)
		return math.max(1, math.floor(GUIScale(value) * scale + 0.5))
	end

	self.inner  = Px(IT.kExoBarInnerOffset)
	self.thick  = math.max(4, Px(IT.kExoBarThickness))
	self.height = Px(IT.kExoBarHeight)
	self.edge   = math.max(1, math.floor(self.thick / 10 + 0.5))
	self.tickHeight = math.max(2, self.edge * 2)
	self.textGap = Px(IT.kExoBarTextGap)
	self.fontSize = GUIScale(IT.kExoBarFontSize) * scale

	self.left  = self:CreateBar(-1)
	self.right = self:CreateBar(1)

	-- Kept across a rebuild, so a crosshair scale change cannot undo the game hiding the HUD.
	if self.visible == nil then
		self.visible = true
	end

end

function GUIImprovedTooltipsExoBars:CreateBar(side)

	local thick, height, edge = self.thick, self.height, self.edge

	local bar = { }

	bar.root = GUIManager:CreateGraphicItem()
	bar.root:SetLayer(kGUILayerPlayerHUD)
	bar.root:SetAnchor(GUIItem.Middle, GUIItem.Center)
	bar.root:SetColor(Color(0, 0, 0, 0))
	bar.root:SetSize(Vector(thick, height, 0))
	local x = side < 0 and -(self.inner + thick) or self.inner
	bar.root:SetPosition(Vector(x, -height / 2, 0))
	bar.root:SetIsVisible(false)

	local function Strip(xOffset, width, alpha)
		local item = GUIManager:CreateGraphicItem()
		item:SetAnchor(GUIItem.Left, GUIItem.Top)
		item:SetPosition(Vector(xOffset, 0, 0))
		item:SetSize(Vector(width, height, 0))
		item:SetColor(Color(1, 1, 1, alpha))
		bar.root:AddChild(item)
		return item
	end

	Strip(0, edge, kOuterEdgeAlpha)
	Strip(edge, edge, kInnerEdgeAlpha)
	Strip(thick - 2 * edge, edge, kInnerEdgeAlpha)
	Strip(thick - edge, edge, kOuterEdgeAlpha)

	bar.fill = GUIManager:CreateGraphicItem()
	bar.fill:SetAnchor(GUIItem.Left, GUIItem.Top)
	bar.fill:SetColor(Color(1, 1, 1, 1))
	bar.root:AddChild(bar.fill)

	bar.tick = GUIManager:CreateGraphicItem()
	bar.tick:SetAnchor(GUIItem.Left, GUIItem.Top)
	bar.tick:SetSize(Vector(thick, self.tickHeight, 0))
	bar.tick:SetColor(kTickColor)
	bar.tick:SetIsVisible(false)
	bar.root:AddChild(bar.tick)

	-- Same text construction as the In Cooldown panel's seconds, which is proven in game.
	bar.text = GUIManager:CreateTextItem()
	bar.text:SetFontSize(self.fontSize)
	bar.text:SetScale(GetScaledVector())
	bar.text:SetAnchor(GUIItem.Middle, GUIItem.Bottom)
	bar.text:SetTextAlignmentX(GUIItem.Align_Center)
	bar.text:SetTextAlignmentY(GUIItem.Align_Min)
	bar.text:SetPosition(Vector(0, self.textGap, 0))
	bar.text:SetFontIsBold(true)
	bar.text:SetFontName(Fonts.kAgencyFB_Small)
	GUIMakeFontScale(bar.text)
	bar.root:AddChild(bar.text)

	bar.color = Color(1, 1, 1, 1)
	bar.lastPercent = -1

	return bar

end

function GUIImprovedTooltipsExoBars:Uninitialize()

	for _, bar in ipairs({ self.left, self.right }) do
		if bar and bar.root then
			-- Destroying the root destroys its children with it.
			GUI.DestroyItem(bar.root)
			bar.root = nil
		end
	end

	self.left, self.right = nil, nil

end

function GUIImprovedTooltipsExoBars:OnResolutionChanged()
	self:Uninitialize()
	self:Initialize()
end

function GUIImprovedTooltipsExoBars:SetIsVisible(isVisible)
	self.visible = isVisible
	if not isVisible then
		self:HideBoth()
	end
end

function GUIImprovedTooltipsExoBars:GetIsVisible()
	return self.visible
end

function GUIImprovedTooltipsExoBars:HideBoth()
	if self.left then self.left.root:SetIsVisible(false) end
	if self.right then self.right.root:SetIsVisible(false) end
end

-- The options this depends on are read on an interval rather than every frame, and a crosshair scale
-- change rebuilds the geometry, since GUIAdvancedHUDBars only picks that up on a restart.
function GUIImprovedTooltipsExoBars:PollOptions()

	local now = Shared.GetTime()
	if now < self.nextOptionPoll then
		return
	end
	self.nextOptionPoll = now + kOptionPollInterval

	self.hudBarsMode = GetHudBarsMode()

	if GetCrosshairScale() ~= self.crosshairScale then
		self:Uninitialize()
		self:Initialize()
	end

end

function GUIImprovedTooltipsExoBars:GetHolderIfShown()

	if not self.visible or not IT.kShowExoWeaponBars then
		return nil
	end

	local player = Client.GetLocalPlayer()
	if not player or not player:isa("Exo") or not player:GetIsAlive() then
		return nil
	end

	if Client.kHideViewModel ~= true then
		return nil
	end

	self:PollOptions()

	if self.hudBarsMode ~= 0 then
		return nil
	end

	local holder = player:GetActiveWeapon()
	if not holder or not holder:isa("ExoWeaponHolder") then
		return nil
	end

	return holder

end

function GUIImprovedTooltipsExoBars:SetFill(bar, fraction)
	local fillHeight = self.height * fraction
	local innerWidth = self.thick - 2 * self.edge
	bar.fill:SetSize(Vector(innerWidth, fillHeight, 0))
	bar.fill:SetPosition(Vector(self.edge, self.height - fillHeight, 0))
end

function GUIImprovedTooltipsExoBars:UpdateBar(bar, weapon)

	if not bar then
		return
	end

	if not weapon then
		bar.root:SetIsVisible(false)
		return
	end

	local color = bar.color
	local fraction
	local tickAt

	if type(weapon.heatAmount) == "number" then

		fraction = Clamp01(weapon.heatAmount)

		if weapon.overheated == true or fraction >= 1 then
			-- Vanilla's own warning pulse, GUIAdvancedHUDBars.lua:256.
			color.r = 0.5 + ((math.sin(Shared.GetTime() * 10) + 1) / 2) * 0.5
			color.g, color.b, color.a = 0, 0, 1
		elseif fraction < IT.kExoBarHeatWarnFrom then
			CopyInto(color, IT.kExoBarBaseColor)
		elseif fraction < IT.kExoBarHeatWarnAt then
			LerpInto(color, IT.kExoBarBaseColor, IT.kExoBarWarnColor,
				(fraction - IT.kExoBarHeatWarnFrom) / (IT.kExoBarHeatWarnAt - IT.kExoBarHeatWarnFrom))
		else
			LerpInto(color, IT.kExoBarWarnColor, IT.kExoBarHotColor,
				(fraction - IT.kExoBarHeatWarnAt) / (1 - IT.kExoBarHeatWarnAt))
		end

	elseif type(weapon.GetChargeAmount) == "function" then

		local ok, amount = pcall(weapon.GetChargeAmount, weapon)
		if not ok or type(amount) ~= "number" then
			bar.root:SetIsVisible(false)
			return
		end

		fraction = Clamp01(amount)

		if type(weapon.energyCost) == "number" then
			tickAt = Clamp01(weapon.energyCost)
			if fraction >= tickAt then
				CopyInto(color, weapon.fireMode == "MultiShot" and IT.kExoBarPoolMultiReadyColor or IT.kExoBarPoolReadyColor)
			else
				CopyInto(color, IT.kExoBarBaseColor, IT.kExoBarPoolNotReadyAlpha)
			end
		elseif fraction >= 1 then
			CopyInto(color, IT.kExoBarChargeReadyColor)
		else
			CopyInto(color, IT.kExoBarBaseColor)
		end

	else
		bar.root:SetIsVisible(false)
		return
	end

	self:SetFill(bar, fraction)
	bar.fill:SetColor(color)

	if tickAt then
		bar.tick:SetPosition(Vector(0, self.height * (1 - tickAt) - self.tickHeight / 2, 0))
		bar.tick:SetIsVisible(true)
	else
		bar.tick:SetIsVisible(false)
	end

	local percent = math.floor(fraction * 100 + 0.5)
	if percent ~= bar.lastPercent then
		bar.text:SetText(string.format("%d%%", percent))
		bar.lastPercent = percent
	end
	bar.text:SetColor(color)

	bar.root:SetIsVisible(true)

end

function GUIImprovedTooltipsExoBars:Update(deltaTime)

	PROFILE("GUIImprovedTooltipsExoBars:Update")

	local holder = self:GetHolderIfShown()
	if not holder then
		self:HideBoth()
		return
	end

	self:UpdateBar(self.left,  GetSlotWeapon(holder, "leftWeaponId"))
	self:UpdateBar(self.right, GetSlotWeapon(holder, "rightWeaponId"))

end
