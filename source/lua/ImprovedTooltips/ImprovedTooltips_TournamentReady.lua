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
-- LAYING OUT THE ROW. The prefix goes at the front, which means everything already there has to
-- move right by its width. Three things make that harder than it sounds:
--
--   1. The row's order is NOT fixed, because the scoreboard file itself is not. Vanilla flows it
--      name-then-badge from x=10, with the badge at GetTextWidth(header) + 20
--      (GUIScoreboard.lua:1153); Devnull's Enhanced Scoreboard replaces the whole file and flows it
--      badge-then-name. So nothing here assumes an order: the host's positions are read back and
--      only ever shifted. See TrackBase below.
--   2. Vanilla's badge position is CACHED. Line 1142 guards it on the team's summed skill changing,
--      so it moves when someone joins or leaves and not otherwise; Devnull's never moves at all.
--      Either way a shift has to be re-applied every update rather than written once.
--   3. There is not much room. The player column headers start at kPlayerItemWidth on a screen
--      under 1280 wide, and at GetTeamItemWidth() - kTeamColumnSpacingX * 10 above it - 275 and
--      400 respectively. The name is always the NAME_TEAM_n locale string (GUIScoreboard.lua:780);
--      tournament mode's custom names go to the Insight spectator bar through Insight.lua's "teams"
--      command, never here. But "Frontiersmen (12 Players)" plus a glyph plus "[Not Ready]" plus
--      the badge is already close to the wide-screen budget and past it on a narrow one, and a
--      wordier language would push it further.
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

-- Where the host's player column headers begin, unscaled. Vanilla computes this at
-- GUIScoreboard.lua:194 and Devnull's Enhanced Scoreboard reproduces it exactly, so the same
-- expression serves both. If a scoreboard mod ever changes it, the symptom is a prefix that
-- overlaps the Score column instead of shortening itself.
local function GetColumnStartX(self)

	if GUIScoreboard.screenWidth < 1280 then
		return GUIScoreboard.kPlayerItemWidth
	end

	return self:GetTeamItemWidth() - GUIScoreboard.kTeamColumnSpacingX * 10

end

-- NOTHING ABOUT THE ROW'S LAYOUT IS ASSUMED, and the first version of this file got that wrong.
-- It hardcoded vanilla's order - name at x=10, badge after it at GetTextWidth + 20 - and wrote both
-- positions from those constants. Devnull's Enhanced Scoreboard (Workshop 2597529958) replaces
-- lua/GUIScoreboard.lua wholesale and lays the header out the other way round: the skill badge is
-- pinned at x=10 and the name starts at 10 plus the badge width (its GUIScoreboard.lua:350-360),
-- and it never repositions the badge afterwards. Writing vanilla's arrangement over that moved
-- somebody else's badge from the front of the row to the back of it.
--
-- So this reads back where the host put each item and only ever SHIFTS it, preserving whatever
-- order the host chose. The prefix goes at the leftmost of the two, and both move right by its
-- width. Telling a host write apart from our own is the whole trick: whatever we did not write
-- ourselves last frame is the host's, and becomes the new base. That covers vanilla recomputing
-- the badge x when a team's summed skill changes (:1142), a resolution change, and a scoreboard
-- mod that positions on some schedule of its own.
local function TrackBase(layout, item, baseKey, setKey)

	local x = item:GetPosition().x

	-- A tolerance rather than equality, because these are pixel positions that have been through a
	-- scale multiply.
	if layout[setKey] == nil or math.abs(x - layout[setKey]) > 0.01 then
		layout[baseKey] = x
	end

	return layout[baseKey]

end

-- Made lazily and cached on the team table. Both items are children of the team background, like
-- the host's own name and badge, so a scoreboard rebuilt on a resolution change takes them with it.
local function GetPrefix(team)

	if not team.itReadyPrefix then

		local background = team.GUIs and team.GUIs.Background

		if not background then
			return nil
		end

		local glyph = GUIManager:CreateGraphicItem()
		glyph:SetTexture(kTexture)
		glyph:SetAnchor(GUIItem.Left, GUIItem.Top)
		-- The scoreboard clips its contents and every item the host parents in here sets the same
		-- stencil function. Without it these draw outside the clip.
		glyph:SetStencilFunc(GUIItem.NotEqual)
		glyph:SetIsVisible(false)
		background:AddChild(glyph)

		local text = GUIManager:CreateTextItem()
		text:SetAnchor(GUIItem.Left, GUIItem.Top)
		text:SetTextAlignmentX(GUIItem.Align_Min)
		text:SetTextAlignmentY(GUIItem.Align_Min)
		text:SetStencilFunc(GUIItem.NotEqual)
		text:SetIsVisible(false)
		background:AddChild(text)

		team.itReadyPrefix = { glyph = glyph, text = text }
		team.itReadyLayout = { }

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

-- The font is copied off the team name every update rather than taken from a constant. Vanilla's
-- GUIScoreboard.kTeamNameFontName happens to be the font its own team name uses; Devnull's is not.
-- That mod sets the name through SetFont with an Arial 13 table and leaves kTeamNameFontName as
-- Fonts.kInsight, so reading the constant put our label in a different typeface from the name
-- beside it. SetFont resolves to SetFontName plus a fitted scale (GUIItemExtras.lua:413-431), so
-- GetFontName and GetScale together describe whatever the host settled on, either way.
local function MatchFont(text, nameItem)

	local fontName = nameItem:GetFontName()

	if fontName then
		text:SetFontName(fontName)
	end

	text:SetScale(nameItem:GetScale())

end

-- Positions and shows whatever fits, and returns how far the row has to move right to clear it.
-- Everything here is in SCALED pixels, because the host's own item positions are, and this file no
-- longer knows what unscaled coordinates the host was working in.
local function LayOutPrefix(team, nameItem, nameY, rowStart, rightmost, limit, isReady)

	local prefix = GetPrefix(team)

	if not prefix then
		return 0
	end

	local label = isReady and IT.kReadyLabelText or IT.kNotReadyLabelText
	local coords = isReady and kReadyCoords or kNotReadyCoords

	MatchFont(prefix.text, nameItem)
	prefix.text:SetText(label)
	prefix.text:SetColor(isReady and IT.kReadyLabelColor or IT.kNotReadyLabelColor)

	-- GetTextWidth and GetTextHeight report unscaled, so each is taken against its own item's
	-- scale, the way vanilla does it at GUIScoreboard.lua:1058.
	local textHeight = nameItem:GetTextHeight(label) * nameItem:GetScale().x
	local labelWidth = prefix.text:GetTextWidth(label) * prefix.text:GetScale().x

	-- Gaps are fractions of the text height rather than fixed pixels, so they stay in proportion to
	-- whatever font the loaded scoreboard uses.
	local glyphSize = textHeight * IT.kReadyGlyphHeightScale
	local glyphGap = textHeight * IT.kReadyGlyphGap
	local labelGap = textHeight * IT.kReadyLabelGap

	local withText = glyphSize + glyphGap + labelWidth + labelGap
	local glyphOnly = glyphSize + labelGap
	local showText = rightmost + withText <= limit

	prefix.glyph:SetSize(Vector(glyphSize, glyphSize, 0))
	prefix.glyph:SetPosition(Vector(rowStart, nameY + (textHeight - glyphSize) * 0.5, 0))
	prefix.glyph:SetTexturePixelCoordinates(coords[1], coords[2], coords[3], coords[4])
	prefix.glyph:SetIsVisible(true)

	if showText then
		prefix.text:SetPosition(Vector(rowStart + glyphSize + glyphGap, nameY, 0))
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

	local nameItem = gui.TeamName
	local badgeItem = gui.TeamSkill

	-- Created up front, because the layout table lives beside it.
	if not GetPrefix(updateTeam) then
		return
	end

	local layout = updateTeam.itReadyLayout
	local nameBase = TrackBase(layout, nameItem, "nameBase", "nameSet")
	local badgeBase = TrackBase(layout, badgeItem, "badgeBase", "badgeSet")

	local nameY = nameItem:GetPosition().y
	local badgeY = badgeItem:GetPosition().y

	-- The host assembles the header text into a local and keeps no copy, so it is read back off the
	-- item it was just written to.
	local nameWidth = nameItem:GetTextWidth(nameItem:GetText()) * nameItem:GetScale().x

	local rowStart = math.min(nameBase, badgeBase)
	local rightmost = math.max(nameBase + nameWidth, badgeBase + badgeItem:GetSize().x)
	local limit = GetColumnStartX(self) * GUIScoreboard.kScalingFactor

	local teamNumber = updateTeam.TeamNumber

	-- Playing teams only. The ready room has a header row but no readiness.
	local isPlayingTeam = teamNumber == kTeam1Index or teamNumber == kTeam2Index

	-- An empty team cannot be ready, and the host hides its skill badge for the same reason. The
	-- prefix hangs off the team background rather than the badge, so it does not inherit that and
	-- has to make the same call itself.
	local hasPlayers = updateTeam.PlayerList ~= nil and #updateTeam.PlayerList > 0

	local shift = 0

	if IT.kShowTournamentReadyLabels and isPlayingTeam and hasPlayers and GetWaitingPlugin() then
		shift = LayOutPrefix(updateTeam, nameItem, nameY, rowStart, rightmost, limit,
			readyStates[teamNumber] == true)
	else
		HidePrefix(updateTeam)
	end

	-- Only ever a shift off the host's own positions, so whichever order it put the name and badge
	-- in survives. With shift at zero this puts both back exactly where the host had them.
	layout.nameSet = nameBase + shift
	layout.badgeSet = badgeBase + shift

	nameItem:SetPosition(Vector(layout.nameSet, nameY, 0))
	badgeItem:SetPosition(Vector(layout.badgeSet, badgeY, 0))

end
