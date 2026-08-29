-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_NetworkMessages.lua
--
-- Post-hook on lua/NetworkMessages.lua, which loads in every VM, so the message is registered
-- identically on client and server.
--
-- A new message rather than reusing vanilla's "AbilityResult": that one's client handler
-- (NetworkMessages_Client.lua's OnCommandAbilityResult) bails unless
-- Client.GetLocalPlayer():GetIsCommander(), so it can never reach a field player. Nor can that be
-- hooked away - Client.HookNetworkMessage is handed the function by value at load, so redefining
-- the global afterwards does not change what is registered.
--
-- Duration is deliberately not sent. The client looks it up from TechData, exactly as vanilla's own
-- handler does, which keeps the message to two fields.

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_CooldownState.lua")

local IT = ImprovedTooltips

local kCooldownMessage =
{
	techId = "enum kTechId",
	startTime = "time",
	-- Set on the first message of a full resync (team join) so the client drops anything stale
	-- from a previous team or round. A resync with no active cooldowns is just this flag on its
	-- own, with techId None.
	clear = "boolean",
}

function BuildImprovedTooltipsCooldownMessage(techId, startTime, clear)

	return {
		techId = techId or kTechId.None,
		startTime = startTime or 0,
		clear = clear == true,
	}

end

Shared.RegisterNetworkMessage("ImprovedTooltipsCooldown", kCooldownMessage)

if Client then

	local function OnCooldownMessage(msg)

		if msg.clear then
			IT.ClearTeamCooldowns()
		end

		IT.SetTeamCooldown(msg.techId, msg.startTime)

	end

	Client.HookNetworkMessage("ImprovedTooltipsCooldown", OnCooldownMessage)

end
