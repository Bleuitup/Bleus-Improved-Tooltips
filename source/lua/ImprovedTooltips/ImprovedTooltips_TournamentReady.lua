-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_TournamentReady.lua
--
-- Post-hook on lua/GUIScoreboard.lua. Puts a tick or a cross in the corner of each team's skill
-- badge while Shine's tournament mode is waiting for both teams to ready up.
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

local function GetPip(team)

	if not team.itReadyPip then

		local badge = team.GUIs and team.GUIs.TeamSkill

		if not badge then
			return nil
		end

		local item = GUIManager:CreateGraphicItem()
		item:SetTexture(kTexture)
		item:SetAnchor(GUIItem.Right, GUIItem.Bottom)
		-- The scoreboard clips its contents, and every item vanilla parents in here sets the same
		-- stencil function. Without it the pip draws outside the clip.
		item:SetStencilFunc(GUIItem.NotEqual)
		item:SetIsVisible(false)
		badge:AddChild(item)

		team.itReadyPip = item

	end

	return team.itReadyPip

end

local function HideAllPips(self)

	for _, team in ipairs(self.teams or { }) do
		if team.itReadyPip then
			team.itReadyPip:SetIsVisible(false)
		end
	end

end

local originalUpdate = GUIScoreboard.Update

function GUIScoreboard:Update(deltaTime)

	originalUpdate(self, deltaTime)

	if not IT.kShowTournamentReadyPips then
		return
	end

	local gameInfo = GetGameInfoEntity()
	local started = gameInfo ~= nil and gameInfo:GetGameStarted()

	-- Readiness stops meaning anything once the round is under way, so the pips come off entirely.
	-- Clearing on the way back out of a started game also drops last round's states, which the
	-- plugin does not resend.
	if started then
		if not lastGameStarted then
			lastGameStarted = true
		end
		HideAllPips(self)
		return
	end

	if lastGameStarted then
		lastGameStarted = false
		readyStates = { }
	end

	local plugin = GetTournamentPlugin()

	if not plugin then
		HideAllPips(self)
		return
	end

	EnsurePluginHook(plugin)

	for _, team in ipairs(self.teams or { }) do

		local teamNumber = team.TeamNumber

		-- Playing teams only. The ready room has a skill badge slot but no readiness.
		if teamNumber == kTeam1Index or teamNumber == kTeam2Index then

			local badge = team.GUIs and team.GUIs.TeamSkill
			local pip = badge and GetPip(team)

			if pip then

				-- The pip rides the badge, so it inherits the badge's own visibility - which
				-- vanilla turns off for a team with no players (GUIScoreboard.lua:1142-1156). An
				-- empty team cannot be ready, so that is the behaviour we want anyway.
				local badgeSize = badge:GetSize()
				local size = badgeSize.y * IT.kReadyPipScale
				-- Anchored to the badge's lower right, so backing off by the pip's own size sits
				-- it flush in the corner; the inset then carries it in towards the centre.
				local offset = -size * (1 + IT.kReadyPipInset)

				pip:SetSize(Vector(size, size, 0))
				pip:SetPosition(Vector(offset, offset, 0))

				local coords = readyStates[teamNumber] and kReadyCoords or kNotReadyCoords
				pip:SetTexturePixelCoordinates(coords[1], coords[2], coords[3], coords[4])
				pip:SetIsVisible(true)

			end

		end

	end

end
