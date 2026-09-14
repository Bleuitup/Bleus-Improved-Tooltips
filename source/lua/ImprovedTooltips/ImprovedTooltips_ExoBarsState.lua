-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_ExoBarsState.lua
--
-- The one answer to "are the exo weapon bars on screen right now", shared by the bars themselves
-- (GUIImprovedTooltipsExoBars.lua) and by the Centralized HUD bars hook that hides vanilla's weapon
-- bar while they are (ImprovedTooltips_AdvancedHUDBars.lua). One function, so the two can never
-- disagree and leave a pilot with both readouts or with neither.

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Config.lua")

local IT = ImprovedTooltips

-- Returns true and the ExoWeaponHolder when the bars should show, false otherwise.
--
-- The only conditions are the Mods panel setting and a hidden exo viewmodel. Client.kHideViewModel
-- is set by ViewModelOption_Update (NS2Utility.lua:1781) for "Hide all", or "Custom" with the exo
-- hidden, and recomputed whenever the local player changes (Client.lua:1812). Marine HUD bars style
-- is deliberately not a condition; see GUIImprovedTooltipsExoBars.lua.
function IT.GetExoWeaponBarsActive()

	if not IT.kShowExoWeaponBars then
		return false
	end

	local player = Client.GetLocalPlayer()
	if not player or not player:isa("Exo") or not player:GetIsAlive() then
		return false
	end

	if Client.kHideViewModel ~= true then
		return false
	end

	local holder = player:GetActiveWeapon()
	if not holder or not holder:isa("ExoWeaponHolder") then
		return false
	end

	return true, holder

end
