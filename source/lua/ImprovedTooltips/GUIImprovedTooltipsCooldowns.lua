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
-- Entries wrap three to a row. Aliens sit on the commander UI's smoke, marines on the commander
-- selection panel's scanline plate (1.08).
--
-- NOTE: this panel reads the client-side cooldown table, which vanilla never syncs to a commander
-- who did not personally cast the ability. Without the fix in ImprovedTooltips_CooldownSync.lua it
-- would be blind in exactly the cases it is most wanted. The two go together.

Script.Load("lua/GUIDial.lua")
Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Values.lua")
Script.Load("lua/ImprovedTooltips/ImprovedTooltips_CooldownState.lua")

local IT = ImprovedTooltips

class 'GUIImprovedTooltipsCooldowns' (GUIScript)

local kIconSize
local kEntrySpacing
local kPadding
local kTitleFontSize
local kSecondsFontSize
local kTitleGap
local kSecondsGap
local kRowSpacing
local kPlateBorder
local kPlateInsetX
local kPlateInsetTop
local kPlateInsetBottom

local kTitleText = "IN COOLDOWN"

-- Entries wrap after this many. The panel's left edge sits 210 from the right of the screen, so a
-- fourth icon in one row ran off it - and aliens reach four at the default 5 second cut-off (Shade
-- Ink 15, Hallucinate 12, Bone Wall 10, Heal Wave 6). A short last row is centered under the title.
local kColumns = 3

-- Marines get the commander selection panel's plate behind the panel: the same scanlines and frame
-- as the panel it sits beside (GUISelectionPanel.kSelectionTextureCoordinates). Nine-sliced, so the
-- frame and the cut corner keep their shape at any panel size; kPlateTexelBorder is the part of each
-- edge that must not stretch.
local kMarinePlateTexture = "ui/marine_commander_textures.dds"
local kMarinePlateCoords = { 466, 0, 466 + 312, 250 }
local kPlateTexelBorder = 34

-- The alien smoke mask's solid oval covers 16-84% of its width and 26-59% of its height, centered
-- 42% of the way down, not in the middle. Sized from these, the smoke clears the whole panel; the
-- old 1.6 x 2.2 around the texture's middle left the bottom row on the fading edge.
local kSmokeWidthFactor = 1.7
local kSmokeHeightFactor = 2.9
local kSmokeMaskCenterY = 0.42

local function UpdateScale()
	kIconSize         = GUIScale(48)
	kEntrySpacing     = GUIScale(12)
	kPadding          = GUIScale(12)
	kTitleFontSize    = GUIScale(16)
	kSecondsFontSize  = GUIScale(16)
	kTitleGap         = GUIScale(6)
	kSecondsGap       = GUIScale(2)
	kRowSpacing       = GUIScale(8)
	kPlateBorder      = GUIScale(17)
	kPlateInsetX      = GUIScale(8)
	kPlateInsetTop    = GUIScale(12)
	kPlateInsetBottom = GUIScale(8)
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

	local isAlien = self.teamType == kAlienTeamType
	local backingAlpha = isAlien and IT.kCooldownPanelAlienBackgroundAlpha
		or IT.kCooldownPanelMarineBackgroundAlpha

	self.background = GUIManager:CreateGraphicItem()
	self.background:SetLayer(kGUILayerCommanderHUD)
	self.background:SetAnchor(GUIItem.Right, GUIItem.Center)
	self.background:SetColor(Color(0, 0, 0, backingAlpha))
	self.background:SetIsVisible(false)

	-- Aliens get the smoky backdrop the rest of their commander UI uses. Same construction as
	-- GUICommanderTooltip:InitSmokeyBackground.
	--
	-- The backing plate is transparent for aliens (see the config). The smoke mask fades to nothing
	-- at its edges, so any flat color behind it shows up as a hard rectangle under soft smoke.
	if isAlien then
		self.smoke = GUIManager:CreateGraphicItem()
		self.smoke:SetAnchor(GUIItem.Middle, GUIItem.Center)
		self.smoke:SetShader("shaders/GUISmoke.surface_shader")
		self.smoke:SetTexture("ui/alien_logout_smkmask.dds")
		self.smoke:SetAdditionalTexture("noise", "ui/alien_commander_bg_smoke.dds")
		self.smoke:SetFloatParameter("correctionX", 0.5)
		self.smoke:SetFloatParameter("correctionY", 0.8)
		self.background:AddChild(self.smoke)
	else
		self:CreateMarinePlate()
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

-- Nine pieces of the selection panel's plate, in column-major order. Texture coordinates are fixed
-- here; positions and sizes follow the panel in LayoutMarinePlate.
function GUIImprovedTooltipsCooldowns:CreateMarinePlate()

	local x1, y1, x2, y2 = kMarinePlateCoords[1], kMarinePlateCoords[2], kMarinePlateCoords[3], kMarinePlateCoords[4]
	local b = kPlateTexelBorder
	local xs = { x1, x1 + b, x2 - b, x2 }
	local ys = { y1, y1 + b, y2 - b, y2 }

	self.platePieces = { }

	for i = 1, 3 do
		for j = 1, 3 do
			local piece = GUIManager:CreateGraphicItem()
			piece:SetAnchor(GUIItem.Left, GUIItem.Top)
			piece:SetTexture(kMarinePlateTexture)
			piece:SetTexturePixelCoordinates(xs[i], ys[j], xs[i + 1], ys[j + 1])
			self.background:AddChild(piece)
			table.insert(self.platePieces, piece)
		end
	end

end

-- The plate reaches a little past the panel, more at the top so the title sits inside the frame.
function GUIImprovedTooltipsCooldowns:LayoutMarinePlate(width, height)

	local x0 = -kPlateInsetX
	local y0 = -kPlateInsetTop
	local w = width + kPlateInsetX * 2
	local h = height + kPlateInsetTop + kPlateInsetBottom
	local b = kPlateBorder

	local xs = { 0, b, w - b, w }
	local ys = { 0, b, h - b, h }

	local n = 0
	for i = 1, 3 do
		for j = 1, 3 do
			n = n + 1
			local piece = self.platePieces[n]
			piece:SetPosition(Vector(x0 + xs[i], y0 + ys[j], 0))
			piece:SetSize(Vector(xs[i + 1] - xs[i], ys[j + 1] - ys[j], 0))
		end
	end

end

-- Entries are pooled: the panel rarely shows more than two at once, and creating GUI items every
-- frame a cooldown ticks would be wasteful.
function GUIImprovedTooltipsCooldowns:GetEntry(index)

	if self.entries[index] then
		return self.entries[index]
	end

	-- Each entry sits on the same button plate the production/research display uses
	-- (GUIProduction.lua), which is what gives the row its own shape. Before this the panel drew one
	-- flat translucent rectangle behind everything, which read as a hard-edged box - obvious on the
	-- alien side under the soft smoke, and just as wrong on the marine side where there is no smoke
	-- to distract from it.
	local plate = GUIManager:CreateGraphicItem()
	plate:SetAnchor(GUIItem.Left, GUIItem.Top)
	plate:SetSize(Vector(kIconSize, kIconSize, 0))
	plate:SetTexture((self.teamType == kAlienTeamType)
		and "ui/alien_buildmenu_buttonbg.dds"
		or  "ui/marine_buildmenu_buttonbg.dds")
	self.background:AddChild(plate)

	local icon = GUIManager:CreateGraphicItem()
	icon:SetAnchor(GUIItem.Left, GUIItem.Top)
	icon:SetSize(Vector(kIconSize, kIconSize, 0))
	icon:SetTexture(IT.kBuildMenuTexture)
	plate:AddChild(icon)

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

	local entry = { plate = plate, icon = icon, dial = dial, seconds = seconds }
	self.entries[index] = entry

	return entry

end

function GUIImprovedTooltipsCooldowns:HideFrom(index)

	for i = index, #self.entries do
		local entry = self.entries[i]
		entry.plate:SetIsVisible(false)
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
	self.platePieces = nil
	self.title = nil

end

function GUIImprovedTooltipsCooldowns:OnResolutionChanged()
	self:Uninitialize()
	self:Initialize()
end

-- Reads the mod's own team cooldown table, not Commander:GetCooldownFraction. The latter only
-- exists on a Commander, and on a client is only ever populated for the player who cast - so the
-- panel would be blank for field players and for a commander who just left the chair. See
-- ImprovedTooltips_CooldownState.lua.
local function GetActiveCooldowns(player)

	local active = { }

	-- Ready room and unassigned players have no team cooldowns to show. ClientUI already keeps most
	-- scripts out of the ready room, but a spectator can reach here.
	local teamNumber = player and player.GetTeamNumber and player:GetTeamNumber()
	if teamNumber ~= kTeam1Index and teamNumber ~= kTeam2Index then
		return active
	end

	local techIds = IT.GetTechIdsWithCooldown(IT.kCooldownPanelMinDuration)

	for i = 1, #techIds do

		local techId = techIds[i]
		local fraction = IT.GetTeamCooldownFraction(techId)

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

	-- The panel is registered for Player, so it now survives class changes - including commander to
	-- field player. That means it also survives a team switch, after which the cached team styling
	-- (dial texture, tint, smoke) would be wrong. Rebuild when the team actually changes.
	if PlayerUI_GetTeamType() ~= self.teamType then
		self:Uninitialize()
		self:Initialize()
	end

	local player = Client.GetLocalPlayer()
	local active = GetActiveCooldowns(player)

	if #active == 0 then
		self.background:SetIsVisible(false)
		self:HideFrom(1)
		return
	end

	local isMarine = self.teamType ~= kAlienTeamType

	-- Size the panel to what is actually showing: up to kColumns entries a row, as many rows as
	-- needed, under the title. The top edge stays put and the panel grows downward.
	local titleHeight = self.title:GetTextHeight(kTitleText) * self.title:GetScale().y
	local rowHeight = kIconSize + (IT.kCooldownPanelShowSeconds and (kSecondsGap + kSecondsFontSize) or 0)
	local columns = math.min(#active, kColumns)
	local rows = math.ceil(#active / kColumns)
	local width = kPadding * 2 + columns * kIconSize + (columns - 1) * kEntrySpacing
	local height = kPadding * 1.5 + titleHeight + kTitleGap + rows * rowHeight + (rows - 1) * kRowSpacing

	self.background:SetSize(Vector(width, height, 0))
	self.background:SetIsVisible(true)

	if self.smoke then
		local smokeWidth = width * kSmokeWidthFactor
		local smokeHeight = height * kSmokeHeightFactor
		self.smoke:SetSize(Vector(smokeWidth, smokeHeight, 0))
		self.smoke:SetPosition(Vector(-smokeWidth * 0.5, -smokeHeight * kSmokeMaskCenterY, 0))
	end

	if self.platePieces then
		self:LayoutMarinePlate(width, height)
	end

	local top = kPadding * 0.5 + titleHeight + kTitleGap

	for i = 1, #active do

		local item = active[i]
		local entry = self:GetEntry(i)

		local row = math.floor((i - 1) / kColumns)
		local column = (i - 1) % kColumns
		local inRow = math.min(kColumns, #active - row * kColumns)
		local x = kPadding + (columns - inRow) * (kIconSize + kEntrySpacing) * 0.5 + column * (kIconSize + kEntrySpacing)
		local y = top + row * (rowHeight + kRowSpacing)

		entry.plate:SetIsVisible(true)
		entry.plate:SetPosition(Vector(x, y, 0))
		entry.icon:SetTexturePixelCoordinates(GUIUnpackCoords(GetTextureCoordinatesForIcon(item.techId, isMarine)))

		entry.dial:SetIsVisible(true)
		entry.dial:SetPercentage(item.fraction)
		entry.dial:Update(deltaTime)

		entry.seconds:SetIsVisible(IT.kCooldownPanelShowSeconds)
		if IT.kCooldownPanelShowSeconds then
			entry.seconds:SetText(ToString(math.ceil(item.remaining)))
		end

	end

	self:HideFrom(#active + 1)

end
