-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_AdvancedHUDBars.lua
--
-- Post-hook on lua/GUIAdvancedHUDBars.lua. With marine HUD bars on "Centralized", hides vanilla's
-- right-hand weapon bar and its number while the mod's exo weapon bars are on screen, so a pilot
-- does not get two readouts beside the crosshair (user, 2026-09-14).
--
-- WHY ONLY CENTRALIZED. Its bars sit 32-64 px either side of the crosshair, next to the exo bars at
-- 74 px, and for an exo the right one squeezes both arms into a single averaged value
-- (GetWeaponAmmoFraction, NS2Utility.lua:84-99). NS1 draws its bars in the bottom corners, where
-- they neither crowd the exo bars nor were asked to go.
--
-- WHAT IS HIDDEN. The right side only: rightBarBg, rightBar, reserveBar (created only in some
-- modes, GUIAdvancedHUDBars.lua:187), and ammoText / ammoTextBg, its number. The left side - exo
-- armor - is untouched.
--
-- WHEN. Exactly while IT.GetExoWeaponBarsActive() is true: an exo, the setting on, the viewmodel
-- hidden. With the viewmodel shown the mod draws no bars, so vanilla's stays.
--
-- HOW. Vanilla's Update sets these items visible again every frame (GUIAdvancedHUDBars.lua:246-400),
-- so they are hidden after it runs, every frame. The mode is cached at Initialize: changing HUD
-- bars restarts GUIMarineHUD, which destroys and recreates this script (AdvancedOptions.lua:328,
-- GUIMarineHUD.lua:583-591). Neither CBM nor B2TP replaces this file.

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_ExoBarsState.lua")

local IT = ImprovedTooltips

if type(GUIAdvancedHUDBars) ~= "table" or type(GUIAdvancedHUDBars.Update) ~= "function" then
	return
end

local kCentralized = 1
local kRightSideItems = { "rightBarBg", "rightBar", "reserveBar", "ammoText", "ammoTextBg" }

local originalInitialize = GUIAdvancedHUDBars.Initialize

function GUIAdvancedHUDBars:Initialize(...)

	originalInitialize(self, ...)

	local isMarine = Client.GetLocalPlayer() and Client.GetLocalPlayer():GetTeamNumber() == kTeam1Index
	self.itIsCentralizedMarine = isMarine and GetAdvancedOption("hudbars_m") == kCentralized

end

local originalUpdate = GUIAdvancedHUDBars.Update

function GUIAdvancedHUDBars:Update(deltaTime)

	originalUpdate(self, deltaTime)

	if not self.itIsCentralizedMarine or not IT.GetExoWeaponBarsActive() then
		return
	end

	for _, field in ipairs(kRightSideItems) do
		local item = self[field]
		if item then
			item:SetIsVisible(false)
		end
	end

end
