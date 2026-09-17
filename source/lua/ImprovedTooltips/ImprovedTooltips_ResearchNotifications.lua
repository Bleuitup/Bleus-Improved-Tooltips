-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_ResearchNotifications.lua
--
-- Post-hook on lua/Hud/GUINotificationMixin.lua. Client only.
--
-- In the HIVE PANEL ONLY display mode, research done in a hive no longer adds a research
-- notification on the left, because the hive status panel already shows it in that hive's row.
--
-- Every research notification enters through GUINotificationMixin:AddNotification: the tech tree's
-- network handlers (TechTree_Client.lua, for plain and per-entity research) and GUIEvent's catch-up
-- sync on joining a team all call it, and GUIEvent only ever draws what it hands back. Filtering
-- here, rather than in GUIEvent, means a notification stack that replaces GUIEvent but still reads
-- the player's queue is filtered too.
--
-- Mixins copy their functions onto a class when it calls InitMixin. Alien.lua, Marine.lua and
-- Exo.lua all Script.Load this file first and InitMixin later, and a post-hook runs straight after
-- the file loads, so the wrapped function is the one every player gets.
--
-- WHAT COUNTS AS RESEARCH IN A HIVE. Only what a Hive or the EvolutionChamber it owns researches:
--
--   - biomass researches and the three hive type upgrades, which the Hive runs, and
--   - every lifeform ability in EvolutionChamber.kUpgradeButtons, read at runtime so mods that add
--     one (CBM's Babbler Bomb) are covered.
--
-- Plus, as a safety net, any tech the server currently reports a hive or chamber researching.
-- Everything else is left alone, deliberately: CBM's Advanced Crag, Shift, Shade and Whip upgrades
-- run on the structure itself, the Infested Tunnel upgrade on the tunnel, and marine research on
-- marine buildings - none of those are in a hive row, so their notifications stay.
--
-- Both the start of a hive research and its completion or cancellation share one notification in
-- GUIEvent, so filtering the notification removes all three for those researches. The "trait
-- available" sound GUIEvent would have played is kept by ImprovedTooltips_ResearchStack.lua, which
-- watches research directly rather than through notifications.

if not Client then
	return
end

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Values.lua")
Script.Load("lua/ImprovedTooltips/ImprovedTooltips_HiveState.lua")

local IT = ImprovedTooltips

local kHiveResearchNames =
{
	"ResearchBioMassOne", "ResearchBioMassTwo", "ResearchBioMassThree", "ResearchBioMassFour",
	"UpgradeToCragHive", "UpgradeToShadeHive", "UpgradeToShiftHive",
}

local hiveResearchSet = nil

local function GetHiveResearchSet()

	if hiveResearchSet then
		return hiveResearchSet
	end

	if not kTechId or not EvolutionChamber or not EvolutionChamber.kUpgradeButtons then
		return nil
	end

	local set = { }

	for i = 1, #kHiveResearchNames do
		local techId = IT.GetTechIdByName(kHiveResearchNames[i])
		if techId then
			set[techId] = true
		end
	end

	for _, buttons in pairs(EvolutionChamber.kUpgradeButtons) do
		for i = 1, #buttons do
			local techId = buttons[i]
			if techId and techId ~= kTechId.None then
				set[techId] = true
			end
		end
	end

	hiveResearchSet = set
	return set

end

local function GetIsPanelOnlyActiveFor(player)

	if IT.kHiveResearchDisplay ~= IT.kHiveResearchDisplayPanelOnly or not IT.kShowHiveResearchIcon then
		return false
	end

	-- The hive panel is for field aliens only (kShowAsClass["Alien"] in ClientUI.lua), so never hide
	-- anything from anyone else.
	if not player or not player.isa or not player:isa("Alien") then
		return false
	end

	-- With the panel switched off under Advanced Options, nothing would replace the notification.
	if GetAdvancedOption and not GetAdvancedOption("hivestatus") then
		return false
	end

	return true

end

-- ImprovedTooltips_ResearchStack.lua watches this to rebuild the stack when it changes mid-round.
IT.GetIsHivePanelOnlyActiveFor = GetIsPanelOnlyActiveFor

local originalAddNotification = GUINotificationMixin.AddNotification

if originalAddNotification then

	function GUINotificationMixin:AddNotification(notification)

		if notification and notification.techId and GetIsPanelOnlyActiveFor(self) then

			local set = GetHiveResearchSet()
			if (set and set[notification.techId]) or IT.GetIsResearchedInHive(notification.techId) then
				return
			end

		end

		return originalAddNotification(self, notification)

	end

end
