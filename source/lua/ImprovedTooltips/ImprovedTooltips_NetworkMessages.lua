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

		-- Keep vanilla's own table in step while commanding, so the button dial cannot drift from
		-- the panel. Vanilla already messages the commander for anything they cast, so this is
		-- usually a no-op writing the same value - SetTechCooldown updates in place, so that is
		-- harmless. It matters for any cooldown started by a route that does not message them.
		local player = Client.GetLocalPlayer()
		if player and player.GetIsCommander and player:GetIsCommander() then
			IT.ApplyCooldownToVanillaDial(player, msg.techId, msg.startTime)
		end

	end

	Client.HookNetworkMessage("ImprovedTooltipsCooldown", OnCooldownMessage)

end

------------------------------------------------------------------------------------------------
-- Hive state, for the alien hive status HUD
------------------------------------------------------------------------------------------------
--
-- Keyed by location rather than by hive entity, because that is what GUIHiveStatus works in: its
-- slots are created per locationId and vanilla's own data for them comes from AlienTeamInfo keyed
-- the same way. See ImprovedTooltips_HiveState.lua for why this cannot be read off the Hive.

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_HiveState.lua")

local kHiveStateMessage =
{
	-- A location id is Shared.GetStringIndex(locationName) (ScriptActor_Server.lua:180), not an
	-- entity id. AlienTeamInfo declares its own as "entityid" and gets away with it, but an integer
	-- is what this actually is, and 0 is what ScriptActor initialises it to.
	locationId = "integer",
	-- Matches Hive.lua's own network var range.
	biomass = "integer (0 to 6)",
	-- Any research at all: biomass, a lifeform ability, or a hive type upgrade. Deliberately not
	-- which one, and not a progress fraction - the HUD only shows that the hive is busy.
	researching = "boolean",
	-- Set on the first message of a full resync (team join) so the client drops anything stale
	-- from a previous team or round.
	clear = "boolean",
}

function BuildImprovedTooltipsHiveStateMessage(locationId, biomass, researching, clear)

	return {
		locationId = locationId or 0,
		biomass = math.max(0, math.min(6, biomass or 0)),
		researching = researching == true,
		clear = clear == true,
	}

end

Shared.RegisterNetworkMessage("ImprovedTooltipsHiveState", kHiveStateMessage)

if Client then

	local function OnHiveStateMessage(msg)

		if msg.clear then
			IT.ClearHiveState()
		end

		IT.SetHiveState(msg.locationId, msg.biomass, msg.researching)

	end

	Client.HookNetworkMessage("ImprovedTooltipsHiveState", OnHiveStateMessage)

end
