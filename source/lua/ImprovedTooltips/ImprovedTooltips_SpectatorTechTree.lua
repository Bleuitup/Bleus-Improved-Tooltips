-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_SpectatorTechTree.lua
--
-- Post-hook on lua/TechTree_Server.lua (server only). Lets a neutral spectator receive one playing
-- team's tech tree, so the tech map can be shown to them (GUIImprovedTooltipsSpectatorTechMap.lua).
-- The same controls and approach as NSL Mod's spectator tech maps (by Dragon, MIT licensed); this
-- is the mod's own code.
--
-- WHY SPECTATORS HAVE NO TECH TREE. PlayingTeam:UpdateTechTree (PlayingTeam.lua:871) sends the tree
-- only to the team's own players: SendTechTreeBase to those who just joined, then
-- SendTechTreeUpdates(players) once a second (kTechTreeUpdateTime = 1). The spectator team has no
-- tech tree code at all, and the client holds a single tree (Client.lua's gTechTree), so a spectator
-- can follow one team's at a time.
--
-- HOW A SPECTATOR IS ADDED. TechTree:SendTechTreeUpdates is wrapped: when it is about to send a
-- team's changes, the spectators who asked for that team are added to a copy of the list it was
-- given. Anyone whose last baseline came from a different tree object - just subscribed, switched
-- team, or the round reset and built new trees - is sent the full baseline first with the game's own
-- SendTechTreeBase, which begins with a ClearTechTree. NSL instead changes what Team:GetPlayers
-- returns while the tree updates; wrapping the one send leaves every other caller alone.
--
-- WHO MAY ASK. Only a neutral spectator (team kSpectatorIndex). A dead player watching their own
-- team is a TeamSpectator on team 1 or 2 and keeps that team's tree as vanilla gives it; letting
-- them ask for the other team would show them the enemy's tech. A subscription is dropped as soon
-- as its player is no longer a neutral spectator; joining a team gets them that team's baseline from
-- vanilla, which clears the old tree first.
--
-- NSL MOD DOES THE SAME, under its own message. When it is loaded (kNSLPluginBuild) this stands
-- down, so a spectator never gets two trees interleaved.

if not Server then
	return
end

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Config.lua")

local IT = ImprovedTooltips

if type(TechTree) ~= "table" or type(TechTree.SendTechTreeUpdates) ~= "function" then
	return
end

local function GetNSLLoaded()
	return kNSLPluginBuild ~= nil
end

-- Client id -> { team = 1 or 2, tree = the tree object the last baseline came from, or nil }.
-- Keyed by client rather than player entity: the entity changes on every class change.
local subscriptions = { }

local function GetNeutralSpectator(client)

	local player = client and client:GetControllingPlayer()

	if player and player:isa("Spectator") and player:GetTeamNumber() == kSpectatorIndex then
		return player
	end

	return nil

end

function IT.OnSpectatorTechTreeRequest(client, teamNumber)

	if GetNSLLoaded() or not client then
		return
	end

	local player = GetNeutralSpectator(client)

	if not player then
		return
	end

	local id = client:GetId()

	if teamNumber == 1 or teamNumber == 2 then

		local current = subscriptions[id]

		if not current or current.team ~= teamNumber then
			-- The baseline goes out with the team's next update, within a second.
			subscriptions[id] = { team = teamNumber, tree = nil }
		end

	elseif subscriptions[id] then

		subscriptions[id] = nil
		Server.SendNetworkMessage(player, "ClearTechTree", { }, true)

	end

end

-- Which playing team a tree belongs to, 1 or 2, or nil.
local function GetTeamNumberOfTree(tree)

	local gamerules = GetGamerules and GetGamerules()

	if not gamerules then
		return nil
	end

	for teamNumber = 1, 2 do
		local team = gamerules:GetTeam(teamNumber)
		if team and team.techTree == tree then
			return teamNumber
		end
	end

	return nil

end

-- The spectators to add to this tree's sends. Sends a baseline where one is due, and drops anyone
-- who has left, joined a team or disconnected.
local function CollectSpectators(tree)

	local teamNumber = GetTeamNumberOfTree(tree)

	if not teamNumber then
		return nil
	end

	local added = nil

	for id, subscription in pairs(subscriptions) do

		local client = Server.GetClientById(id)
		local player = GetNeutralSpectator(client)

		if not player then

			subscriptions[id] = nil

		elseif subscription.team == teamNumber then

			if subscription.tree ~= tree and tree:SendTechTreeBase(player) then
				subscription.tree = tree
			end

			-- Updates only make sense on top of this tree's baseline; until it has gone out
			-- (SendTechTreeBase sends nothing before the tree is complete) the spectator waits.
			if subscription.tree == tree then
				added = added or { }
				added[#added + 1] = player
			end

		end

	end

	return added

end

-- A fault here must never stop a team's own players getting their tech tree, so the spectator part
-- runs protected and, after one error, says so once and stops.
local failed = false

local originalSendTechTreeUpdates = TechTree.SendTechTreeUpdates

function TechTree:SendTechTreeUpdates(playerList)

	if failed or GetNSLLoaded() or next(subscriptions) == nil then
		return originalSendTechTreeUpdates(self, playerList)
	end

	local ok, added = pcall(CollectSpectators, self)

	if not ok then
		failed = true
		subscriptions = { }
		Print("[Bleu's Improved Tooltips] spectator tech maps disabled after an error: %s", tostring(added))
		return originalSendTechTreeUpdates(self, playerList)
	end

	if not added then
		return originalSendTechTreeUpdates(self, playerList)
	end

	local players = { }

	for i = 1, #(playerList or { }) do
		players[i] = playerList[i]
	end

	for i = 1, #added do
		players[#players + 1] = added[i]
	end

	return originalSendTechTreeUpdates(self, players)

end

-- For a harness: the live subscriptions.
IT._spectatorTechTreeDebug = { GetSubscriptions = function() return subscriptions end }
