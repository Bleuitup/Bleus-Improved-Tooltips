-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_CooldownSync.lua
--
-- Post-hook on lua/Commander.lua. Fixes a vanilla bug: a commander who takes the chair while a
-- team ability is on cooldown never sees the cooldown, because nothing ever tells their client
-- about it.
--
-- What vanilla does
-- -----------------
-- Commander ability cooldowns live in a file-local table in lua/Commander.lua:
--
--     local gTechIdCooldowns = {}          -- keyed by TEAM NUMBER, not by player
--
-- So the cooldown is genuinely team-wide, and Commander_Server.lua's ProcessTechTreeAction blocks
-- a cast by asking GetIsTechOnCooldown against that team table. Three Shades cannot alternate Ink.
--
-- That table exists independently in the server VM and in every client VM, and nothing syncs them.
-- The only thing that ever populates a client's copy is Commander:OnAbilityResultMessage, driven by
-- the "AbilityResult" message - which Commander_Server.lua sends to the casting commander alone.
--
-- Vanilla even has the gap marked. Commander:SetTechCooldown ends with:
--
--     if Server then
--         -- send message to commander to sync the cd
--     end
--
-- an empty block. So: server-side enforcement is correct, and the rotating dial on the button is
-- simply blind for anyone who did not personally cast the ability. Hop out of the hive mid-Ink and
-- hop back in, or swap commanders, and the dial shows nothing while the cooldown is still enforced.
--
-- What this does
-- --------------
-- Replays the team's live cooldowns to a commander as ordinary "AbilityResult" messages. No new
-- network message is needed: vanilla's already carries (techId, success, castTime), and its client
-- handler sets the cooldown from exactly that.
--
-- gTechIdCooldowns is file-local and unreachable, but Commander:GetCooldownFraction is public and
-- reads it, so the original start time is recovered as
--
--     castTime = now - (1 - fraction) * duration
--
-- The set of abilities to check comes from TechData, like everything else in this mod, so modded
-- abilities are covered without being listed.

if not Server then
	return
end

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Values.lua")

local IT = ImprovedTooltips

local function SendCooldown(commander, techId, castTime)

	-- Bot commanders go through the same cast and login paths (bots/CommanderBrain.lua also calls
	-- SetTechCooldown), but there is no client behind them to message. Player:GetIsVirtual is
	-- server-side only, which is fine - this whole file is.
	if not commander or (commander.GetIsVirtual and commander:GetIsVirtual()) then
		return
	end

	Server.SendNetworkMessage(commander, "AbilityResult",
		BuildAbilityResultMessage(techId, true, castTime), true)

end

local function SyncTeamCooldowns(commander)

	local techIds = IT.GetTechIdsWithCooldown()
	local now = Shared.GetTime()

	for i = 1, #techIds do

		local techId = techIds[i]
		local fraction = commander:GetCooldownFraction(techId)

		-- GetCooldownFraction returns 0 (or nil, if the tech has no entry at all) when not on
		-- cooldown, and counts DOWN to 0 as the cooldown expires.
		if fraction and fraction > 0 then

			local duration = LookupTechData(techId, kTechDataCooldown, 0)

			if duration > 0 then
				SendCooldown(commander, techId, now - (1 - fraction) * duration)
			end

		end

	end

end

-- Only the login case needs handling. A team can have at most ONE commander at a time regardless of
-- how many command structures it owns: CommandStructure:GetIsPlayerValidForCommander requires
-- `not team:GetHasCommander()`, which is true if any Commander entity exists on the team, and
-- NS2Gamerules:OnCommanderLogin gates on the same thing. So there is never a second seated
-- commander to forward a cooldown to.
--
-- Every path that starts a cooldown already messages the one commander there is: the normal cast in
-- Commander_Server.lua, and Drifter.lua:525 for drifter-delivered clouds. What none of them handle
-- is a commander who was not in the chair at the time, which is what the sync below is for.
--
-- Sent on the commander's first move tick rather than at login. NetworkMessages_Client's handler
-- drops the message unless Client.GetLocalPlayer():GetIsCommander() is already true, and at login
-- the client has not necessarily swapped its local player over to the Commander entity yet. A move
-- tick only happens once the client is actually driving the commander, so it is a safe signal.
local originalOnProcessMove = Commander.OnProcessMove

function Commander:OnProcessMove(input)

	originalOnProcessMove(self, input)

	if not self.itCooldownsSynced then
		self.itCooldownsSynced = true
		SyncTeamCooldowns(self)
	end

end
