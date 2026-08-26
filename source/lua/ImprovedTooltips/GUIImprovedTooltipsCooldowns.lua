-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/GUIImprovedTooltipsCooldowns.lua
--
-- The "In Cooldown" panel: a small titled panel on the right of the commander's screen listing the
-- team abilities currently on cooldown, each with vanilla's rotating dial and the seconds left.
--
-- Commander ability cooldowns are keyed by team number, not by player (see
-- ImprovedTooltips_CooldownSync.lua), so a Shade Ink on cooldown blocks every Shade on the team.
-- The button dial only tells you that while you are looking at the Shade's button; this panel keeps
-- it on screen.
--
-- The dial is vanilla's own GUIDial with the same per-team cooldown textures GUICommanderButtons
-- uses, so it looks and spins exactly like the one on the button.
--
-- NOTE: this panel reads the client-side cooldown table, which vanilla never syncs to a commander
-- who did not personally cast the ability. Without the fix in ImprovedTooltips_CooldownSync.lua it
-- would be blind in exactly the cases it is most wanted. The two go together.

Script.Load("lua/GUIDial.lua")
Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Values.lua")

local IT = ImprovedTooltips

class 'GUIImprovedTooltipsCooldowns' (GUIScript)

local kIconSize
local kEntrySpacing
local kPadding
local kTitleFontSize
local kSecondsFontSize
local kTitleGap
local kSecondsGap

local kTitleText = "IN COOLDOWN"

local function UpdateScale()
	kIconSize        = GUIScale(48)
	kEntrySpacing    = GUIScale(12)
	kPadding         = GUIScale(12)
	kTitleFontSize   = GUIScale(16)
	kSecondsFontSize = GUIScale(16)
	kTitleGap        = GUIScale(6)
	kSecondsGap      = GUIScale(2)
end

-- PlayerUI_GetTeamType rather than player:GetTeamType(): GetTeamType is defined on Commander, not
-- on Player, and this is the accessor GUICommanderButtons itself uses.
local function GetTeamType()
	return PlayerUI_GetTeamType() or kMarineTeamType
end

-- Mirrors kHealthCircleSettings in GUICommanderButtons, sized to our icon instead of a button.
-- Anchoring bottom-left with a zero offset makes GUIDial's own -BackgroundHeight offset land the
-- dial exactly over an equally sized parent icon, which is how the buttons do it.
local function GetDialSettings(teamType)

	local texture = (teamType == kAlienTeamType)
		and "ui/alien_command_cooldown.dds"
		or  "ui/marine_command_cooldown.dds"

	return {
		BackgroundWidth        = kIconSize,
		BackgroundHeight       = kIconSize,
		BackgroundAnchorX      = GUIItem.Left,
		BackgroundAnchorY      = GUIItem.Bottom,
		BackgroundOffset       = Vector(0, 0, 0),
		BackgroundTextureName  = texture,
		BackgroundTextureX1    = 0,
		BackgroundTextureY1    = 0,
		BackgroundTextureX2    = 128,
		BackgroundTextureY2    = 128,
		ForegroundTextureName  = texture,
		ForegroundTextureWidth = 128,
		ForegroundTextureHeight= 128,
		ForegroundTextureX1    = 128,
		ForegroundTextureY1    = 0,
		ForegroundTextureX2    = 256,
		ForegroundTextureY2    = 128,
		InheritParentAlpha     = false,
	}

end

function GUIImprovedTooltipsCooldowns:Initialize()

	UpdateScale()

	self.teamType = GetTeamType()
	self.entries = { }
	self.activeCount = 0

	self.background = GUIManager:CreateGraphicItem()
	self.background:SetLayer(kGUILayerCommanderHUD)
	self.background:SetAnchor(GUIItem.Right, GUIItem.Center)
	self.background:SetColor(Color(0, 0, 0, 0.55))
	self.background:SetIsVisible(false)

	-- Aliens get the smoky backdrop the rest of their commander UI uses. Same construction as
	-- GUICommanderTooltip:InitSmokeyBackground.
	if self.teamType == kAlienTeamType then
		self.background:SetColor(Color(0, 0, 0, 0.35))
		self.smoke = GUIManager:CreateGraphicItem()
		self.smoke:SetAnchor(GUIItem.Middle, GUIItem.Center)
		self.smoke:SetShader("shaders/GUISmoke.surface_shader")
		self.smoke:SetTexture("ui/alien_logout_smkmask.dds")
		self.smoke:SetAdditionalTexture("noise", "ui/alien_commander_bg_smoke.dds")
		self.smoke:SetFloatParameter("correctionX", 0.5)
		self.smoke:SetFloatParameter("correctionY", 0.8)
		self.background:AddChild(self.smoke)
	end

	self.title = GUIManager:CreateTextItem()
	self.title:SetFontSize(kTitleFontSize)
	self.title:SetScale(GetScaledVector())
	self.title:SetAnchor(GUIItem.Middle, GUIItem.Top)
	self.title:SetTextAlignmentX(GUIItem.Align_Center)
	self.title:SetTextAlignmentY(GUIItem.Align_Min)
	self.title:SetPosition(Vector(0, kPadding * 0.5, 0))
	self.title:SetColor(self.teamType == kAlienTeamType and IT.kAlienIconColor or IT.kMarineIconColor)
	self.title:SetFontIsBold(true)
	self.title:SetFontName(Fonts.kAgencyFB_Small)
	self.title:SetText(kTitleText)
	GUIMakeFontScale(self.title)
	self.background:AddChild(self.title)

	self:UpdatePosition()

end

function GUIImprovedTooltipsCooldowns:UpdatePosition()

	local offset = IT.kCooldownPanelOffset
	self.background:SetPosition(Vector(GUIScale(offset.x), GUIScale(offset.y), 0))

end

-- Entries are pooled: the panel rarely shows more than two at once, and creating GUI items every
-- frame a cooldown ticks would be wasteful.
function GUIImprovedTooltipsCooldowns:GetEntry(index)

	if self.entries[index] then
		return self.entries[index]
	end

	local icon = GUIManager:CreateGraphicItem()
	icon:SetAnchor(GUIItem.Left, GUIItem.Top)
	icon:SetSize(Vector(kIconSize, kIconSize, 0))
	icon:SetTexture("ui/buildmenu.dds")
	self.background:AddChild(icon)

	local dial = GUIDial()
	dial:Initialize(GetDialSettings(self.teamType))
	dial:GetLeftSide():SetBlendTechnique(GUIItem.Add)
	dial:GetRightSide():SetBlendTechnique(GUIItem.Add)
	icon:AddChild(dial:GetBackground())

	local seconds = GUIManager:CreateTextItem()
	seconds:SetFontSize(kSecondsFontSize)
	seconds:SetScale(GetScaledVector())
	seconds:SetAnchor(GUIItem.Middle, GUIItem.Bottom)
	seconds:SetTextAlignmentX(GUIItem.Align_Center)
	seconds:SetTextAlignmentY(GUIItem.Align_Min)
	seconds:SetPosition(Vector(0, kSecondsGap, 0))
	seconds:SetColor(Color(1, 1, 1, 1))
	seconds:SetFontIsBold(true)
	seconds:SetFontName(Fonts.kAgencyFB_Small)
	GUIMakeFontScale(seconds)
	icon:AddChild(seconds)

	local entry = { icon = icon, dial = dial, seconds = seconds }
	self.entries[index] = entry

	return entry

end

function GUIImprovedTooltipsCooldowns:HideFrom(index)

	for i = index, #self.entries do
		local entry = self.entries[i]
		entry.icon:SetIsVisible(false)
		entry.dial:SetIsVisible(false)
	end

end

function GUIImprovedTooltipsCooldowns:Uninitialize()

	for i = 1, #self.entries do
		self.entries[i].dial:Uninitialize()
	end
	self.entries = { }

	if self.background then
		GUI.DestroyItem(self.background)
		self.background = nil
	end

	self.smoke = nil
	self.title = nil

end

function GUIImprovedTooltipsCooldowns:OnResolutionChanged()
	self:Uninitialize()
	self:Initialize()
end

local function GetActiveCooldowns(player)

	local active = { }

	if not player or not player.GetCooldownFraction or not player.GetIsCommander or not player:GetIsCommander() then
		return active
	end

	local techIds = IT.GetTechIdsWithCooldown(IT.kCooldownPanelMinDuration)

	for i = 1, #techIds do

		local techId = techIds[i]
		local fraction = player:GetCooldownFraction(techId)

		if fraction and fraction > 0 then
			local duration = LookupTechData(techId, kTechDataCooldown, 0)
			table.insert(active, {
				techId = techId,
				fraction = fraction,
				remaining = fraction * duration,
			})
		end

	end

	return active

end

function GUIImprovedTooltipsCooldowns:Update(deltaTime)

	PROFILE("GUIImprovedTooltipsCooldowns:Update")

	if not IT.kShowCooldownPanel then
		self.background:SetIsVisible(false)
		return
	end

	local player = Client.GetLocalPlayer()
	local active = GetActiveCooldowns(player)

	if #active == 0 then
		self.background:SetIsVisible(false)
		self:HideFrom(1)
		return
	end

	local isMarine = self.teamType ~= kAlienTeamType

	-- Size the panel to what is actually showing, then lay the entries out left to right under
	-- the title.
	local titleHeight = self.title:GetTextHeight(kTitleText) * self.title:GetScale().y
	local rowHeight = kIconSize + (IT.kCooldownPanelShowSeconds and (kSecondsGap + kSecondsFontSize) or 0)
	local width = kPadding * 2 + #active * kIconSize + (#active - 1) * kEntrySpacing
	local height = kPadding * 1.5 + titleHeight + kTitleGap + rowHeight

	self.background:SetSize(Vector(width, height, 0))
	self.background:SetIsVisible(true)

	if self.smoke then
		self.smoke:SetSize(Vector(width * 1.6, height * 2.2, 0))
		self.smoke:SetPosition(Vector(-width * 0.8, -height * 1.1, 0))
	end

	local x = kPadding
	local y = kPadding * 0.5 + titleHeight + kTitleGap

	for i = 1, #active do

		local item = active[i]
		local entry = self:GetEntry(i)

		entry.icon:SetIsVisible(true)
		entry.icon:SetPosition(Vector(x, y, 0))
		entry.icon:SetTexturePixelCoordinates(GUIUnpackCoords(GetTextureCoordinatesForIcon(item.techId, isMarine)))

		entry.dial:SetIsVisible(true)
		entry.dial:SetPercentage(item.fraction)
		entry.dial:Update(deltaTime)

		entry.seconds:SetIsVisible(IT.kCooldownPanelShowSeconds)
		if IT.kCooldownPanelShowSeconds then
			entry.seconds:SetText(ToString(math.ceil(item.remaining)))
		end

		x = x + kIconSize + kEntrySpacing

	end

	self:HideFrom(#active + 1)

end
