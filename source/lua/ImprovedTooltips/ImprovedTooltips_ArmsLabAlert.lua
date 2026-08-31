-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_ArmsLabAlert.lua
--
-- Post-hook on lua/Hud/Marine/GUIMarineHUD.lua. Keeps the weapon and armour upgrade icons on screen,
-- in vanilla's own alert red, while the team has no working arms lab - instead of hiding them, which
-- is what vanilla does today and is indistinguishable from never having researched them.
--
-- VANILLA ALREADY WANTS THIS. GUIMarineHUD:Update ends with:
--
--     local useColor = kIconColors[kMarineTeamType]
--     if not MarineUI_GetHasArmsLab() then
--         useColor = Color(1, 0, 0, 1)
--     end
--     self.weaponLevel:SetColor(useColor)
--     self.armorLevel:SetColor(useColor)
--
-- but fifteen lines earlier, in the same function, it has already done:
--
--     self.armorLevel:SetIsVisible(armorLevel ~= 0)
--
-- and armorLevel came from PlayerUI_GetArmorLevel() called with NO argument, which asks the tech
-- node's GetHasTech() - live availability - rather than GetResearched(). Losing the arms lab drops
-- that to 0, so the icon is hidden and then painted red. The red branch is unreachable in exactly
-- the case it was written for. This file makes it reachable.
--
-- Destroyed and unpowered are the same event as far as any of this is concerned:
-- TechMixin:UpdateTechAvailability adds and removes a structure's techId on GetIsUnitActive, and
-- that requires powered AND alive AND built (NS2Utility.lua:571-577).
--
-- The distinction the fix relies on is vanilla's own: PlayerUI_GetArmorLevel takes a "researched"
-- flag (Player_Client.lua:3176) selecting GetResearched() over GetHasTech(). The HUD never passes
-- it. Marine:GetArmorLevel and Marine:GetWeaponLevel (Marine.lua:381, :406) are built on
-- GetResearched() and have no callers at all - somebody meant to tell "lost" apart from "never had".
--
-- To be clear about what the red means: the upgrade really is inactive. Marine:GetArmorAmount
-- (Marine.lua:439) uses the live GetHasTech, so armour genuinely drops without a working arms lab.
-- Hiding the icon was not a lie - it just could not be told apart from the early game.

if not Client then
	return
end

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Config.lua")

local IT = ImprovedTooltips

local kOriginalUpdate = GUIMarineHUD.Update

-- ShowNewArmorLevel / ShowNewWeaponLevel are no-ops at level 0 (GUIMarineHUD.lua:1007, :1018), so
-- the icon keeps whatever artwork the last real level set. That is why this only has to restore
-- visibility: the texture is still the right Armor-N or Weapons-N glyph.
--
-- Vanilla sets the red itself, after the visibility line, so by the time this runs the colour is
-- already correct. It is re-applied anyway rather than assumed, since a mod loading between us and
-- vanilla could have set it to something else.
local function RestoreLostUpgradeIcon(item, researchedLevel, showFn, self)

	if not item or researchedLevel == 0 then
		return
	end

	showFn(self, researchedLevel)
	item:SetColor(IT.kArmsLabLostColor)
	item:SetIsVisible(true)

end

function GUIMarineHUD:Update(deltaTime)

	kOriginalUpdate(self, deltaTime)

	if not IT.kShowLostArmsLabUpgrades then
		return
	end

	-- MarineUI_GetHasArmsLab is GetHasTech(player, kTechId.ArmsLab) (Marine_Client.lua:31), the same
	-- test vanilla uses two lines above for the colour.
	if MarineUI_GetHasArmsLab() then
		return
	end

	-- The "true" is the whole point: ever researched, rather than currently active.
	RestoreLostUpgradeIcon(self.armorLevel,  PlayerUI_GetArmorLevel(true),  self.ShowNewArmorLevel,  self)
	RestoreLostUpgradeIcon(self.weaponLevel, PlayerUI_GetWeaponLevel(true), self.ShowNewWeaponLevel, self)

end
