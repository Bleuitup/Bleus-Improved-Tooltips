-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_NetworkMessages.lua
--
-- Post-hook on lua/NetworkMessages.lua, which loads in every VM, so the message is registered
-- identically on client and server.
--
-- Until 1.2 this also carried team cooldowns and per-hive state. Build 345 syncs both itself, so
-- those two messages were removed.

ImprovedTooltips = ImprovedTooltips or { }
local IT = ImprovedTooltips

------------------------------------------------------------------------------------------------
-- Spectator tech maps (1.12)
------------------------------------------------------------------------------------------------
--
-- Client to server: a neutral spectator asks for one team's tech tree, 1 marines or 2 aliens, or 0
-- for none. The tree itself travels in vanilla's own TechNodeBase / TechNodeUpdate messages, the ones
-- a team's players get; see ImprovedTooltips_SpectatorTechTree.lua. The server handler is looked up
-- through IT at call time, because HookNetworkMessage keeps the function it is given and the handler
-- lives in a file that loads later.

Shared.RegisterNetworkMessage("ImprovedTooltipsSpectatorTechTree", { teamNumber = "integer (0 to 2)" })

if Server then

	Server.HookNetworkMessage("ImprovedTooltipsSpectatorTechTree", function(client, msg)
		if IT.OnSpectatorTechTreeRequest then
			IT.OnSpectatorTechTreeRequest(client, msg.teamNumber)
		end
	end)

end
