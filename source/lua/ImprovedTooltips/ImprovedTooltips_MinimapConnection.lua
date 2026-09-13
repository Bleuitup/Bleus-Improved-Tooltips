-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_MinimapConnection.lua
--
-- Post-hook on lua/GUIMinimapConnection.lua. Draws the phase gate arrows on the commander's and the
-- spectator's corner minimap, where vanilla leaves them out.
--
-- WHERE THEY GO MISSING. One condition, GUIMinimapConnection.lua:32:
--
--     local animatedArrows = not modeIsMini and teamNumber == kTeam1Index
--                            and #GetEntitiesForTeam("MapConnector", kTeam1Index) > 2
--
-- modeIsMini is true only for GUIMinimapFrame.kModeMini - the overhead corner minimap
-- (Commander_Client.lua:767, and the spectator's). The big map is kModeBig and the marine HUD's
-- minimap is kModeZoom, so both get arrows. That one flag gates the static arrows (kLineMode > 0)
-- and the animation (kLineMode > 1) alike, and also thins the line from 10 to 6 (:44).
--
-- WHAT THIS DOES. When the line would have had arrows anywhere else, it calls vanilla as though the
-- map were not the corner minimap. So the player's own "pglines" choice (Advanced > Map), the
-- marines-only rule and the more-than-two-gates rule all still come from vanilla. The line is 10
-- thick, the same as the marine HUD's minimap, which is about this size and already carries arrows;
-- at vanilla's 6 the 16 pixel arrow art is squashed past reading.
--
-- Every other line - solid mode, alien tunnels, two gates or fewer - goes to vanilla untouched, so
-- lines without arrows keep vanilla's thin corner-map look.

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Config.lua")

local IT = ImprovedTooltips

if type(GUIMinimapConnection) ~= "table" or type(GUIMinimapConnection.UpdateAnimation) ~= "function" then
	return
end

-- Mirrors the arrow condition at GUIMinimapConnection.lua:32 and :40, minus the corner-map term.
local function WouldHaveArrows(teamNumber)

	if teamNumber ~= kTeam1Index then
		return false
	end

	if not GUIMinimapConnection.kLineMode or GUIMinimapConnection.kLineMode <= 0 then
		return false
	end

	return #GetEntitiesForTeam("MapConnector", kTeam1Index) > 2

end

local originalUpdateAnimation = GUIMinimapConnection.UpdateAnimation

function GUIMinimapConnection:UpdateAnimation(teamNumber, modeIsMini)

	if modeIsMini and IT.kCommanderMinimapPhaseGateArrows and WouldHaveArrows(teamNumber) then
		return originalUpdateAnimation(self, teamNumber, false)
	end

	return originalUpdateAnimation(self, teamNumber, modeIsMini)

end
