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
-- marines-only rule and the more-than-two-gates rule all still come from vanilla.
--
-- SIZE. Vanilla's arrows are the same size on every map, 10 tall with one every 64, whatever the
-- map's scale. At that size (1.05 to 1.07) they looked about three times too big against the
-- corner map's rooms. Since 1.08 the art is shrunk evenly by IT.kCommanderMinimapPhaseGateArrowScale
-- (0.42: the marine HUD minimap's proportion at default zoom) - repeated more often and drawn
-- thinner - rather than only thinned, which is what vanilla's 6 does and squashes the arrows.
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

-- Mirrors kLineTextureCoord and the animation term at GUIMinimapConnection.lua:17 and :33.
local kArtLength = 64
local kArtRow = 16
local kArtRowHeight = 16

-- Redraws the arrow line vanilla just set up, smaller: the art repeats every kArtLength * scale
-- instead of every kArtLength, and the line is that much thinner. Same texture, same animation
-- phase, so it still moves one arrow a second.
local function ScaleArrows(connection, scale)

	local line = connection.line
	if not line or not connection.length then
		return
	end

	local animation = GUIMinimapConnection.kLineMode > 1 and (Shared.GetTime() % 1) or 0
	local x1 = -animation * kArtLength
	local x2 = x1 + connection.length / scale

	line:SetTexturePixelCoordinates(x1, kArtRow, x2, kArtRow + kArtRowHeight)
	line:SetSize(Vector(connection.length, GUIScale(10) * scale, 0))

end

function GUIMinimapConnection:UpdateAnimation(teamNumber, modeIsMini)

	if modeIsMini and IT.kCommanderMinimapPhaseGateArrows and WouldHaveArrows(teamNumber) then

		local result = originalUpdateAnimation(self, teamNumber, false)

		local scale = IT.kCommanderMinimapPhaseGateArrowScale
		if self.isVisible and scale and scale > 0 and scale < 1 then
			ScaleArrows(self, scale)
		end

		return result

	end

	return originalUpdateAnimation(self, teamNumber, modeIsMini)

end
