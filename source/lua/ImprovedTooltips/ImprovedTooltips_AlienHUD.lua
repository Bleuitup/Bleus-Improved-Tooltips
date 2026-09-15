-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_AlienHUD.lua
--
-- Post-hook on lua/GUIAlienHUD.lua. With Centralized HUD bars and the mod's shield bar on, hides
-- vanilla's shield number in the bottom-left corner: the shield total is shown in the center, under
-- the shield bar, instead (ImprovedTooltips_AdvancedHUDBars.lua).
--
-- Vanilla already hides its shield RING in this mode but keeps that number
-- (GUIAlienHUD.lua:734, :753-755), and sets its visibility every frame from UpdateMucousBall, which is
-- a file-local called from Update - hence hiding it after Update. CBM dev replaces this file but keeps
-- mucousText, cachedHudBarsOption and the same call (its GUIAlienHUD.lua:770-774).

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Config.lua")

local IT = ImprovedTooltips

if type(GUIAlienHUD) ~= "table" or type(GUIAlienHUD.Update) ~= "function" then
	return
end

local kCentralized = 1

local originalUpdate = GUIAlienHUD.Update

function GUIAlienHUD:Update(deltaTime)

	originalUpdate(self, deltaTime)

	if IT.kShowCentralizedShields and self.cachedHudBarsOption == kCentralized and self.mucousText then
		self.mucousText:SetIsVisible(false)
	end

end
