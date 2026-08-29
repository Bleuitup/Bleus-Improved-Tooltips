-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_CooldownDial.lua
--
-- Post-hook on lua/Commander.lua, client side. Makes VANILLA's rotating dial on the commander
-- button work for a commander who did not personally cast the ability.
--
-- The mod's own panel already handles this, because it reads the mod's synced table. The button
-- dial does not - it reads gTechIdCooldowns via Commander:GetCooldownFraction, and on a client that
-- table is only ever written for the player who cast. Take the chair while Shade Ink is on
-- cooldown and the Shade's button shows nothing, even though the ability is genuinely blocked and
-- our panel says so.
--
-- Nothing needs to come from the server for this. By the time you sit down, this client has already
-- been receiving the team broadcast as a field player, so it knows the cooldowns - they just have
-- not been written anywhere vanilla looks. Becoming a commander is exactly the moment vanilla's
-- table is empty and ours is not, so that is when we replay ours into it.
--
-- Commander:OnInitialized is the hook: it runs in both VMs and vanilla itself does
-- `if Client then ... if self:GetIsLocalPlayer()` inside it, so the local-player test is valid
-- there.

if not Client then
	return
end

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_CooldownState.lua")

local IT = ImprovedTooltips

local originalOnInitialized = Commander.OnInitialized

function Commander:OnInitialized()

	originalOnInitialized(self)

	if self.GetIsLocalPlayer and self:GetIsLocalPlayer() then
		IT.PushAllCooldownsToVanillaDial(self)
	end

end
