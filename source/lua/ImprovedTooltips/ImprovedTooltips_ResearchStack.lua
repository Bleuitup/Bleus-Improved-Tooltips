-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_ResearchStack.lua
--
-- Post-hook on lua/Hud/GUIEvent.lua, the research notification stack on the left. Client only.
--
-- ImprovedTooltips_ResearchNotifications.lua keeps hive research out of this stack in HIVE PANEL
-- ONLY, at the moment a notification is queued. Two things follow from filtering there, and this
-- file handles both.
--
-- SWITCHING MODE MID-ROUND. The filter only sees notifications as they arrive, so on its own a mode
-- change left the stack as it was: research already shown stayed after switching to HIVE PANEL
-- ONLY, and research already hidden did not come back after switching away. So whenever the
-- filter's answer changes - the HIVE RESEARCH DISPLAY setting, the hive status panel option, or
-- anything else it checks - the stack is rebuilt the way GUIEvent:Initialize builds it: cleared,
-- then every research in progress queued again, this time through the current filter.
--
-- THE "TRAIT AVAILABLE" SOUND. GUIEvent plays it itself when a notification it shows turns
-- complete, with Client.GetLocalPlayer():TriggerEffects("upgrade_complete") (GUIEvent.lua:348), so
-- hiding the notification silenced it. The sound is played here for hidden research instead, with
-- GUIEvent's rules:
--
--   - checked from GUIEvent:Update, so it only happens while the alien HUD is running, as before;
--   - complete means the tech node's progress for that entity is exactly 1;
--   - a research neither complete nor still in progress was cancelled, and makes no sound;
--   - the list starts clean whenever the stack does.

if not Client then
	return
end

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Values.lua")

local IT = ImprovedTooltips

IT.hiddenResearchNotifications = IT.hiddenResearchNotifications or { }

local function GetIsPanelOnlyActive()
	return IT.GetIsHivePanelOnlyActiveFor ~= nil and IT.GetIsHivePanelOnlyActiveFor(Client.GetLocalPlayer())
end

local function UpdateHiddenResearch()

	local hidden = IT.hiddenResearchNotifications
	if not next(hidden) then
		return
	end

	local techTree = GetTechTree and GetTechTree()
	if not techTree then
		return
	end

	for key, research in pairs(hidden) do

		local techNode = techTree:GetTechNode(research.techId)
		if not techNode then

			hidden[key] = nil

		else

			-- GUIEvent falls back to the item's lastProgress, which is never moved off 0.
			local progress = techNode:GetResearchProgress(research.entityId) or 0

			if progress == 1 then

				hidden[key] = nil

				local player = Client.GetLocalPlayer()
				if player and player.TriggerEffects then
					player:TriggerEffects("upgrade_complete")
				end

			elseif not techTree:GetResearchInProgress(research.techId, research.entityId) then

				hidden[key] = nil

			end

		end

	end

end

-- Mirrors the catch-up half of GUIEvent:Initialize.
local function RebuildStack(self)

	self:ClearNotifications()
	IT.hiddenResearchNotifications = { }

	local player = Client.GetLocalPlayer()
	if not player or not HasMixin(player, "GUINotification") then
		return
	end

	-- Anything still queued would otherwise be added twice.
	player.notifications = { }

	local techTree = GetTechTree and GetTechTree()
	if not techTree then
		return
	end

	local inProgress = { }
	techTree:GetResearchInProgressTable(inProgress)

	for _, v in ipairs(inProgress) do
		player:AddNotification({ techId = v.techId, entityId = v.entityId, source = kResearchNotificationSource.CatchUpSync })
	end

end

local originalInitialize = GUIEvent.Initialize
function GUIEvent:Initialize(...)

	-- Before the original, which re-adds the research still in progress.
	IT.hiddenResearchNotifications = { }
	local result = originalInitialize(self, ...)
	self.itPanelOnlyActive = GetIsPanelOnlyActive()
	return result

end

local originalUpdate = GUIEvent.Update
function GUIEvent:Update(deltaTime, newNotification, ...)

	local panelOnly = GetIsPanelOnlyActive()

	if self.itPanelOnlyActive ~= nil and self.itPanelOnlyActive ~= panelOnly then

		-- The notification handed in this frame was already taken off the queue. It is research in
		-- progress, so the rebuild queues it again; passing it on as well would show it twice.
		newNotification = nil
		RebuildStack(self)

	end

	self.itPanelOnlyActive = panelOnly

	originalUpdate(self, deltaTime, newNotification, ...)
	UpdateHiddenResearch()

end
