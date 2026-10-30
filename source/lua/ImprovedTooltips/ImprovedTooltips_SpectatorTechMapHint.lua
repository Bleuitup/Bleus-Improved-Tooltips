-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_SpectatorTechMapHint.lua
--
-- Post-hook on lua/GUIInsight_Overhead.lua. Adds the spectator tech maps to the key hints along the
-- bottom of the overhead spectator view, in the words NSL servers use: "[J+(1/2)] Toggle TechMaps",
-- with the player's own tech map key in place of J. The line is rebuilt exactly as vanilla builds it
-- in GUIInsight_Overhead:Initialize: word wrapped to the screen less 260, then raised by 20 per line.
--
-- Stands down when NSL Mod is loaded (kNSLPluginBuild): its own hint says the same thing.

if not Client then
	return
end

if type(GUIInsight_Overhead) ~= "table" or type(GUIInsight_Overhead.Initialize) ~= "function" then
	return
end

local function AddHint(script)

	local keyHints = script.keyHints

	if not keyHints or kNSLPluginBuild ~= nil then
		return
	end

	local text = string.gsub(keyHints:GetText(), "\n", " ")
	text = text .. " " .. string.format("[%s+(1/2)] Toggle TechMaps", BindingsUI_GetInputValue("ShowTechMap"))

	local wrapped, _, numLines = WordWrap(keyHints, text, 0, Client.GetScreenWidth() - GUIScale(260))

	keyHints:SetPosition(Vector(GUIScale(10), -GUIScale(20 * numLines), 0))
	keyHints:SetText(wrapped)

end

local failed = false
local originalInitialize = GUIInsight_Overhead.Initialize

function GUIInsight_Overhead:Initialize()

	originalInitialize(self)

	if failed then
		return
	end

	local ok, err = pcall(AddHint, self)

	if not ok then
		failed = true
		Print("[Bleu's Improved Tooltips] spectator tech map hint disabled after an error: %s", tostring(err))
	end

end
