-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_AlienHUD.lua
--
-- Post-hook on lua/GUIAlienHUD.lua. With Centralized HUD bars and the shield bar on, hides vanilla's
-- green shield number in the bottom-left corner: the total is shown under the shield bar instead
-- (ImprovedTooltips_ShieldBar.lua). 1.21.
--
-- Vanilla already hides its shield RING with Centralized bars (GUIAlienHUD.lua:563) but keeps the
-- number, and sets the number's visibility on every update from UpdateMucousBall, a file-local that
-- GUIAlienHUD:Update calls (:1056-1058, :1279). So it is hidden again straight after Update.

if not Client then
	return
end

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Config.lua")

local IT = ImprovedTooltips

if type(GUIAlienHUD) ~= "table" or type(GUIAlienHUD.Update) ~= "function" then
	return
end

local kCentralized = 1

local originalUpdate = GUIAlienHUD.Update
function GUIAlienHUD:Update(deltaTime)

	originalUpdate(self, deltaTime)

	if IT.kShowAlienShieldBar and self.cachedHudBarsOption == kCentralized and self.mucousText then
		self.mucousText:SetIsVisible(false)
	end

end
