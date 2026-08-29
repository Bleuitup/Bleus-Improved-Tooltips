-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_CooldownSync.lua
--
-- Post-hook on lua/Commander.lua. Tells the whole team when a commander ability goes on cooldown,
-- which vanilla never does for anyone but the commander who cast it.
--
-- What vanilla does
-- -----------------
-- Cooldowns live in a file-local table in lua/Commander.lua:
--
--     local gTechIdCooldowns = {}          -- keyed by TEAM NUMBER, not by player
--
-- So they are genuinely team-wide, and Commander_Server.lua's ProcessTechTreeAction blocks a cast
-- by checking that team table. Three Shades cannot alternate Ink.
--
-- That table exists independently in the server VM and in every client VM, and nothing syncs them.
-- The only thing that populates a client's copy is the "AbilityResult" message, which the server
-- sends to the casting commander alone. Vanilla even marks the gap - Commander:SetTechCooldown ends
-- with an empty:
--
--     if Server then
--         -- send message to commander to sync the cd
--     end
--
-- Consequences: server-side enforcement is correct, but the rotating dial is blind for anyone who
-- did not personally cast - a commander who took the chair mid-cooldown, one who has just left it,
-- and every field player.
--
-- The join-time resync lives in ImprovedTooltips_CooldownJoin.lua; the helpers both use are in
-- ImprovedTooltips_CooldownState.lua, which depends on no class and so is safe to load from either
-- hook regardless of the order the game loads Commander.lua and NS2Gamerules.lua in.
--
-- A team has at most ONE commander at a time whatever the number of command structures
-- (CommandStructure:GetIsPlayerValidForCommander requires `not team:GetHasCommander()`), so there
-- is no second-commander case to handle - only the rest of the team.

if not Server then
	return
end

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Values.lua")
Script.Load("lua/ImprovedTooltips/ImprovedTooltips_CooldownState.lua")

local IT = ImprovedTooltips

local originalSetTechCooldown = Commander.SetTechCooldown

function Commander:SetTechCooldown(techId, cooldownDuration, startTime)

	originalSetTechCooldown(self, techId, cooldownDuration, startTime)

	if not techId or techId == kTechId.None then
		return
	end

	if type(cooldownDuration) == "number" and cooldownDuration > 0 then
		IT.BroadcastCooldown(self:GetTeamNumber(), techId, startTime)
	end

end
