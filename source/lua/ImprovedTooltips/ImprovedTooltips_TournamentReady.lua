-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_TournamentReady.lua
--
-- Post-hook on lua/GUIScoreboard.lua. Marks each team's scoreboard header as ready or not ready
-- while Shine's tournament mode is waiting for both teams, by prefixing the header row:
--
--   [tick]  [Ready]      Frontiersmen (6 Players)  [skill badge]
--   [cross] [Not Ready]  Kharaa       (6 Players)  [skill badge]
--
-- The text is green for ready and red for not, and the glyph is drawn to the height of the text
-- beside it. 1.02 put a small pip in the corner of the skill badge instead; this is the same state
-- said louder, at the front of the row where it cannot be missed.
--
-- WHERE THE STATE COMES FROM. Shine already broadcasts it, but not as one canonical message. The
-- tournamentmode plugin picks whichever message suits the situation, and three of them move a team
-- between ready and not ready:
--
--   TeamReadyChange { Team, IsReady }        server.lua:180,189,345,365. Both directions, but
--       ReadyTeam only sends it when the OTHER team is already ready.
--   TeamReadyWaiting { ReadyTeam, Waiting }  server.lua:350. The first team to ready. Only sent
--       when the other team is not ready, so it settles the state of both.
--   TeamPlayerNotReady { Team, PlayerName }  server.lua:413. A player on a ready team backing out.
--       UnReadyTeam is then called without its notify flag, so no TeamReadyChange follows and this
--       is the only word a client gets that the team is no longer ready.
--
-- Listening to TeamReadyChange alone therefore misses the most ordinary case of all: the first
-- team to ready up. The plugin's client half keeps none of this - it only prints a notification
-- (client.lua:76,84,113) - so this file keeps its own table.
--
-- It wraps the plugin's own receivers rather than hooking the raw network messages. The messages
-- are registered as "SH_tournamentmode_<Name>" (Shine builds the name in
-- core/shared/base_plugin/networking.lua:87), but they only exist once the plugin has loaded, and
-- this mod has no ordering relationship with Shine at all. Wrapping is safe and late-bound:
-- Shine's dispatcher looks the receiver up on the plugin table at call time (networking.lua:102),
-- not at registration, so a wrapper installed later still runs. We look for the plugin each frame
-- until it is there, and if tournament mode is never enabled nothing happens.
--
-- LAYING OUT THE ROW. Vanilla flows it left to right from x=10: the team name, then the skill
-- badge at GetTextWidth(header) + 20 (GUIScoreboard.lua:1153). Two things make that awkward to
-- prefix:
--
--   1. That badge position is CACHED. Line 1142 guards it on the team's summed skill changing, so
--      it moves when someone joins or leaves and not otherwise. Shift the name and the badge stays
--      put, on top of it. So this file drives the badge x itself on every update, in both states,
--      reproducing vanilla's own formula when there is no prefix to add.
--   2. There is not much room. The player column headers start at kPlayerItemWidth on a screen
--      under 1280 wide, and at GetTeamItemWidth() - kTeamColumnSpacingX * 10 above it - 275 and
--      400 respectively. A prefix plus a long name plus the badge can reach past that, and
--      tournament mode is exactly where it would: admins set custom team names through the plugin,
--      up to 25 characters.
--
-- So the row is MEASURED, not assumed. If glyph, text, name and badge do not fit before the column
-- headers, the text is dropped and the glyph alone is kept - still at the front of the row, still
-- unmissable, just quieter. Nothing is ever drawn over the columns.
--
-- KNOWN GAP, and it is Shine's rather than ours: all three messages fire on a CHANGE. There is no
-- message carrying the current state, so a client connecting mid-pregame does not learn that a
-- team is already ready until the next toggle. The default is "not ready", so the wrong answer is
-- a cross on a team that is ready, which corrects itself the moment anything changes. Fixing it
-- properly needs something new from the Shine side.

if not Client then
	return
end

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Config.lua")

local IT = ImprovedTooltips

local kTexture = "ui/bleu_tooltip_icons.dds"

-- Cells 5 and 6 of the mod's own 448x64 sheet, seven cells of 64. See tools/build_icons.ps1.
local kReadyCoords    = { 5 * 64, 0, 6 * 64, 64 }
local kNotReadyCoords = { 6 * 64, 0, 7 * 64, 64 }

-- Keyed by team number, so it lines up with Shine's Team field directly.
local readyStates = { }

local hookedPlugin = nil
local lastGameStarted = false

local function GetTournamentPlugin()

	if not Shine or not Shine.IsExtensionEnabled then
		return nil
	end

	local enabled, plugin = Shine:IsExtensionEnabled("tournamentmode")

	if not enabled then
		return nil
	end

	return plugin

end

-- The receivers worth wrapping, and what each one says about a team. Keyed by method name so the
-- wrapper below can install them all in one pass, and so a Shine version that drops one of these
-- simply leaves it unwrapped rather than erroring.
local kReceivers = {

	ReceiveTeamReadyChange = function(data)
		if data.Team then
			readyStates[data.Team] = data.IsReady == true
		end
	end,

	ReceiveTeamReadyWaiting = function(data)
		-- Only sent when the waiting team is not ready, so both ends of it are known here.
		if data.ReadyTeam then
			readyStates[data.ReadyTeam] = true
		end
		if data.WaitingTeam then
			readyStates[data.WaitingTeam] = false
		end
	end,

	ReceiveTeamPlayerNotReady = function(data)
		if data.Team then
			readyStates[data.Team] = false
		end
	end,

}

-- Wrapped once per plugin instance. Compared by identity rather than by a boolean so that a plugin
-- reloaded mid-session is wrapped again rather than left un-hooked.
local function EnsurePluginHook(plugin)

	if hookedPlugin == plugin then
		return
	end

	for name, apply in pairs(kReceivers) do

		local original = plugin[name]

		if original then

			plugin[name] = function(self, data)

				original(self, data)

				if data then
					apply(data)
				end

			end

		end

	end

	hookedPlugin = plugin

end

-- Vanilla's own row metrics, unscaled. The first two match GUIScoreboard.lua:165 and :1153; the
-- badge width is kPlayerSkillIconSize.x (:79), which is a file-local there and cannot be read.
local kRowStartX = 10
local kRowTopY = 5
local kNameToBadgeGap = 10
local kBadgeWidth = 62

-- Where vanilla's player column headers begin (GUIScoreboard.lua:194). Reproduced rather than read
-- because it is a local there too; if this ever drifts, the symptom is a prefix that overlaps the
-- Score column instead of shortening itself.
local function GetColumnStartX(self)

	if GUIScoreboard.screenWidth < 1280 then
		return GUIScoreboard.kPlayerItemWidth
	end

	return self:GetTeamItemWidth() - GUIScoreboard.kTeamColumnSpacingX * 10

end

-- Made lazily and cached on the team table. Both items are children of the team background, like
-- vanilla's name and badge, so a scoreboard rebuilt on a resolution change takes them with it.
local function GetPrefix(team)

	if not team.itReadyPrefix then

		local background = team.GUIs and team.GUIs.Background

		if not background then
			return nil
		end

		local glyph = GUIManager:CreateGraphicItem()
		glyph:SetTexture(kTexture)
		glyph:SetAnchor(GUIItem.Left, GUIItem.Top)
		-- The scoreboard clips its contents and every item vanilla parents in here sets the same
		-- stencil function. Without it these draw outside the clip.
		glyph:SetStencilFunc(GUIItem.NotEqual)
		glyph:SetIsVisible(false)
		background:AddChild(glyph)

		local text = GUIManager:CreateTextItem()
		-- Same font and scale as the team name, so the label sits on the name's baseline and the
		-- two scale together.
		text:SetFontName(GUIScoreboard.kTeamNameFontName)
		text:SetScale(Vector(1, 1, 1) * GUIScoreboard.kScalingFactor)
		GUIMakeFontScale(text)
		text:SetAnchor(GUIItem.Left, GUIItem.Top)
		text:SetTextAlignmentX(GUIItem.Align_Min)
		text:SetTextAlignmentY(GUIItem.Align_Min)
		text:SetStencilFunc(GUIItem.NotEqual)
		text:SetIsVisible(false)
		background:AddChild(text)

		team.itReadyPrefix = { glyph = glyph, text = text }

	end

	return team.itReadyPrefix

end

local function HidePrefix(team)

	local prefix = team.itReadyPrefix

	if prefix then
		prefix.glyph:SetIsVisible(false)
		prefix.text:SetIsVisible(false)
	end

end

-- Positions and shows whatever fits, and returns how far the team name has to move right to clear
-- it. Zero means nothing was drawn and the row keeps vanilla's layout exactly.
local function LayOutPrefix(self, team, nameItem, nameWidth, isReady)

	local prefix = GetPrefix(team)

	if not prefix then
		return 0
	end

	local scale = GUIScoreboard.kScalingFactor
	local label = isReady and IT.kReadyLabelText or IT.kNotReadyLabelText
	local coords = isReady and kReadyCoords or kNotReadyCoords

	prefix.text:SetText(label)
	prefix.text:SetColor(isReady and IT.kReadyLabelColor or IT.kNotReadyLabelColor)

	-- Measured rather than assumed, so the glyph tracks whatever the font does at this resolution.
	local textHeight = nameItem:GetTextHeight(label)
	local glyphSize = textHeight * IT.kReadyGlyphHeightScale
	local textWidth = prefix.text:GetTextWidth(label)

	local withText = glyphSize + IT.kReadyGlyphGap + textWidth + IT.kReadyLabelGap
	local glyphOnly = glyphSize + IT.kReadyLabelGap

	-- What is left before the player column headers once the name and badge have had their share.
	local budget = GetColumnStartX(self) - kRowStartX - nameWidth - kNameToBadgeGap - kBadgeWidth
	local showText = withText <= budget

	prefix.glyph:SetSize(Vector(glyphSize, glyphSize, 0) * scale)
	prefix.glyph:SetPosition(Vector(kRowStartX, kRowTopY + (textHeight - glyphSize) * 0.5, 0) * scale)
	prefix.glyph:SetTexturePixelCoordinates(coords[1], coords[2], coords[3], coords[4])
	prefix.glyph:SetIsVisible(true)

	if showText then
		prefix.text:SetPosition(Vector(kRowStartX + glyphSize + IT.kReadyGlyphGap, kRowTopY, 0) * scale)
		prefix.text:SetIsVisible(true)
	else
		prefix.text:SetIsVisible(false)
	end

	return showText and withText or glyphOnly

end

-- The plugin, but only while a pre-game is actually waiting on it. Also does the bookkeeping for
-- leaving a started game, which is where last round's ready states have to be dropped: the plugin
-- empties its own table in StartGame (server.lua:213) and resends nothing.
local function GetWaitingPlugin()

	local gameInfo = GetGameInfoEntity()

	if gameInfo ~= nil and gameInfo:GetGameStarted() then
		lastGameStarted = true
		return nil
	end

	if lastGameStarted then
		lastGameStarted = false
		readyStates = { }
	end

	local plugin = GetTournamentPlugin()

	if not plugin then
		return nil
	end

	EnsurePluginHook(plugin)

	return plugin

end

local originalUpdateTeam = GUIScoreboard.UpdateTeam

function GUIScoreboard:UpdateTeam(updateTeam)

	originalUpdateTeam(self, updateTeam)

	local gui = updateTeam.GUIs

	if not gui or not gui.TeamName or not gui.TeamSkill then
		return
	end

	local teamNumber = updateTeam.TeamNumber
	local nameItem = gui.TeamName

	-- Vanilla assembles the header text into a local and keeps no copy, so it is read back off the
	-- item it was just written to (GUIScoreboard.lua:815).
	local nameWidth = nameItem:GetTextWidth(nameItem:GetText())

	local shift = 0

	-- Playing teams only. The ready room has a header row but no readiness.
	local isPlayingTeam = teamNumber == kTeam1Index or teamNumber == kTeam2Index

	-- An empty team cannot be ready, and vanilla hides its skill badge for the same reason
	-- (GUIScoreboard.lua:1155). The prefix hangs off the team background rather than the badge, so
	-- it does not inherit that and has to make the same call itself.
	local hasPlayers = updateTeam.PlayerList ~= nil and #updateTeam.PlayerList > 0

	if IT.kShowTournamentReadyLabels and isPlayingTeam and hasPlayers and GetWaitingPlugin() then
		shift = LayOutPrefix(self, updateTeam, nameItem, nameWidth, readyStates[teamNumber] == true)
	else
		HidePrefix(updateTeam)
	end

	-- Driven on every update, in both states. Vanilla only repositions the badge when the team's
	-- summed skill changes (GUIScoreboard.lua:1142), so leaving it alone after shifting the name
	-- would strand it on top of the name until someone joined or left. With shift at zero this is
	-- vanilla's own formula, GetTextWidth(header) + 20.
	local scale = GUIScoreboard.kScalingFactor

	nameItem:SetPosition(Vector(kRowStartX + shift, kRowTopY, 0) * scale)
	gui.TeamSkill:SetPosition(Vector(kRowStartX + shift + nameWidth + kNameToBadgeGap, kRowTopY, 0) * scale)

end
