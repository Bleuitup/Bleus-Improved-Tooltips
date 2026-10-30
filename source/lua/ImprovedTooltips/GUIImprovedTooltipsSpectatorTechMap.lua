-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/GUIImprovedTooltipsSpectatorTechMap.lua
--
-- The tech map for neutral spectators. Hold the tech map key (the player's own ShowTechMap binding,
-- J by default) to show it, and press 1 or 2 while holding it for the marine or alien map. The same
-- controls as NSL Mod's spectator tech maps (by Dragon, MIT licensed); this is the mod's own code.
-- Registered for the spectator team in ImprovedTooltips_ClientUI.lua.
--
-- It is the game's own GUITechMap (CBM's, when CBM is loaded) drawn for a chosen team. GUITechMap
-- picks its layout from PlayerUI_GetTeamType() in Initialize and checks it again in every Update,
-- rebuilding itself if it changed; a spectator's own team type is neither side's. So for the length
-- of those two calls only, PlayerUI_GetTeamType answers with the chosen team, and is put back even if
-- the call fails.
--
-- The tree it draws is the client's single tech tree (GetTechTree()), which the server fills with the
-- chosen team's nodes on request (ImprovedTooltips_SpectatorTechTree.lua). Switching team asks for
-- the other tree; the server's baseline clears the old one first. The marine tree is asked for as
-- soon as the script starts, so the map is ready the first time the key is held.
--
-- 1 and 2 are fixed keys, as on NSL servers. While the tech map key is held they are taken by the
-- map, so they do not also switch the spectator camera mode, which is what they do otherwise.
--
-- When NSL Mod is loaded (kNSLPluginBuild) it already gives spectators this, so this script stays
-- empty and asks for nothing.

Script.Load("lua/GUITechMap.lua")

class 'GUIImprovedTooltipsSpectatorTechMap' (GUITechMap)

local kTeamTypeForTeam = { [1] = kMarineTeamType, [2] = kAlienTeamType }

-- Kept across a rebuild (a resolution change destroys and recreates the script).
local chosenTeam = 1

local function GetNSLLoaded()
	return kNSLPluginBuild ~= nil
end

-- Runs fn with PlayerUI_GetTeamType answering the chosen team's type, and restores it afterwards.
local function AsChosenTeam(self, fn, ...)

	local saved = PlayerUI_GetTeamType
	local teamType = kTeamTypeForTeam[self.bitTeam]

	PlayerUI_GetTeamType = function() return teamType end

	local ok, err = pcall(fn, self, ...)

	PlayerUI_GetTeamType = saved

	if not ok then
		error(err, 0)
	end

end

local function RequestTree(teamNumber)
	Client.SendNetworkMessage("ImprovedTooltipsSpectatorTechTree", { teamNumber = teamNumber }, true)
end

function GUIImprovedTooltipsSpectatorTechMap:Initialize()

	self.bitDisabled = GetNSLLoaded()

	if self.bitDisabled then
		return
	end

	self.bitTeam = chosenTeam

	-- GUITechMap:Initialize clears techMapButton; a rebuild while the key is held keeps it held.
	local held = self.techMapButton

	AsChosenTeam(self, GUITechMap.Initialize)

	self.techMapButton = held or false

	RequestTree(self.bitTeam)

end

function GUIImprovedTooltipsSpectatorTechMap:Uninitialize()

	if self.bitDisabled then
		return
	end

	GUITechMap.Uninitialize(self)

end

function GUIImprovedTooltipsSpectatorTechMap:Update(deltaTime)

	if self.bitDisabled or not self.background then
		return
	end

	AsChosenTeam(self, GUITechMap.Update, deltaTime)

end

local function SwitchTeam(self, teamNumber)

	chosenTeam = teamNumber

	GUITechMap.Uninitialize(self)
	self:Initialize()

end

function GUIImprovedTooltipsSpectatorTechMap:SendKeyEvent(key, down)

	if self.bitDisabled then
		return false
	end

	if GetIsBinding(key, "ShowTechMap") then
		self.techMapButton = down
		return false
	end

	if self.techMapButton and (key == InputKey.Num1 or key == InputKey.Num2) then

		if down then
			local teamNumber = key == InputKey.Num1 and 1 or 2
			if teamNumber ~= self.bitTeam then
				SwitchTeam(self, teamNumber)
			end
		end

		-- Taken while the map key is held, so the camera mode does not switch as well.
		return true

	end

	return false

end
