-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_ResearchStack.lua
--
-- Post-hook on lua/Hud/GUIEvent.lua, the research notification stack on the left. Client only.
--
-- Three jobs, all for the alien stack except the first.
--
-- SWITCHING MODE MID-ROUND. ImprovedTooltips_ResearchNotifications.lua keeps hive research out of
-- this stack in HIVE PANEL ONLY, but only sees notifications as they are queued, so on its own a mode
-- change left the stack as it was. So whenever the filter's answer changes - the HIVE RESEARCH
-- DISPLAY setting, the hive status panel option, or anything else it checks - the stack is rebuilt
-- the way GUIEvent:Initialize builds it: cleared, then every research in progress queued again, this
-- time through the current filter.
--
-- THE "TRAIT AVAILABLE" SOUND, for the alien stack. GUIEvent plays it itself
-- (TriggerEffects("upgrade_complete"), GUIEvent.lua:348), but only for a notification it is showing
-- when the research completes, and aliens are shown three. That loses sounds in two ways:
--
--   - Research hidden by HIVE PANEL ONLY is never shown, so it never sounds.
--   - With more than three researches running, a notification pushed below the three is faded out,
--     destroyed and dropped from GUIEvent's list (see below), so it is never there to complete.
--     Seen in testing with three hive type upgrades and three abilities at once.
--
-- So the alien stack's sound is taken over here. Every research in progress is watched directly
-- (TechTree:GetResearchInProgressTable, which GUIEvent itself uses), and when one stops being in
-- progress the sound plays if it completed: its progress is exactly 1, GUIEvent's own test, read
-- before GUIEvent's update can clear it. A research that stopped short of 1 was cancelled and makes
-- no sound. Several completing in the same frame play it once. GUIEvent's own call is silenced while
-- it updates, so nothing plays twice. It still only runs while the alien HUD does, as before. The
-- marine stack is left entirely alone.
--
-- RESEARCH PUSHED OUT OF THE STACK. GUIEvent keeps its notifications sorted by time left and shows
-- three. When a new one sorts above the last shown, it is inserted and the one pushed to fourth is
-- faded out, which also marks it for destruction; once destroyed it is left out of the list GUIEvent
-- carries to the next update. Its research is still running, but nothing will ever queue it again, so
-- it never reappears when a place frees up. Found in testing: of six researches the last three never
-- showed. So after each update, any research still in progress that is neither in GUIEvent's list nor
-- waiting in the player's queue is queued again. It sorts below the three shown, so it waits in the
-- list and is shown when a place frees, as GUIEvent intended. Hive research hidden by HIVE PANEL ONLY
-- goes back through the same filter and stays hidden.

if not Client then
	return
end

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Values.lua")

local IT = ImprovedTooltips

local kCompleteEffect = "upgrade_complete"

-- GUIEvent.Update as it was before this file wrapped it.
local originalUpdate = GUIEvent.Update

local function GetIsPanelOnlyActive()
	return IT.GetIsHivePanelOnlyActiveFor ~= nil and IT.GetIsHivePanelOnlyActiveFor(Client.GetLocalPlayer())
end

local function GetResearchKey(research)
	return tostring(research.techId) .. ":" .. tostring(research.entityId)
end

local function GetResearchInProgress(techTree)

	local list = { }
	techTree:GetResearchInProgressTable(list)

	local set = { }
	for i = 1, #list do
		set[GetResearchKey(list[i])] = { techId = list[i].techId, entityId = list[i].entityId }
	end
	return set

end

-- Returns true when a research watched last frame has completed since.
local function UpdateWatchedResearch(self, techTree)

	local current = GetResearchInProgress(techTree)
	local completed = false

	if self.itWatchedResearch then

		for key, research in pairs(self.itWatchedResearch) do

			if not current[key] then

				local techNode = techTree:GetTechNode(research.techId)
				if techNode and techNode:GetResearchProgress(research.entityId) == 1 then
					completed = true
				end

			end

		end

	end

	self.itWatchedResearch = current
	return completed

end

-- Runs the original update with its completion sound swallowed. Entities are userdata, so the
-- method cannot be shadowed on the player itself (rawget on one raises, found in testing); it is
-- swapped on the player's class table instead, where every call on an instance looks it up, for
-- exactly the duration of the update, and put back even if the update throws. If the class table
-- cannot be found the update runs unsilenced - at worst a sound plays twice, never an error.
local function UpdateSilenced(self, ...)

	local player = Client.GetLocalPlayer()
	local classTable = player and player.GetClassName and _G[player:GetClassName()]
	if type(classTable) ~= "table" or not player.TriggerEffects then
		return originalUpdate(self, ...)
	end

	local previous = rawget(classTable, "TriggerEffects")
	local triggerEffects = player.TriggerEffects

	rawset(classTable, "TriggerEffects", function(target, effectName, ...)
		if effectName == kCompleteEffect then
			return
		end
		return triggerEffects(target, effectName, ...)
	end)

	local ok, err = pcall(originalUpdate, self, ...)

	rawset(classTable, "TriggerEffects", previous)

	if not ok then
		error(err, 0)
	end

end

-- Queues again any research in progress that GUIEvent has lost track of. See the header.
local function RequeueDroppedResearch(self, techTree)

	local player = Client.GetLocalPlayer()
	if not player or not HasMixin(player, "GUINotification") then
		return
	end

	local known = { }
	for _, data in ipairs(self.notificationsData or { }) do
		known[GetResearchKey(data)] = true
	end
	for _, queued in ipairs(player.notifications or { }) do
		known[GetResearchKey(queued)] = true
	end

	local inProgress = { }
	techTree:GetResearchInProgressTable(inProgress)

	for _, v in ipairs(inProgress) do
		if not known[GetResearchKey(v)] then
			player:AddNotification({ techId = v.techId, entityId = v.entityId, source = kResearchNotificationSource.CatchUpSync })
		end
	end

end

-- Mirrors the catch-up half of GUIEvent:Initialize.
local function RebuildStack(self)

	self:ClearNotifications()

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

	local result = originalInitialize(self, ...)
	self.itPanelOnlyActive = GetIsPanelOnlyActive()
	-- Start from what is already running, so joining mid-round plays nothing.
	self.itWatchedResearch = nil
	return result

end

function GUIEvent:Update(deltaTime, newNotification, ...)

	local panelOnly = GetIsPanelOnlyActive()

	if self.itPanelOnlyActive ~= nil and self.itPanelOnlyActive ~= panelOnly then

		-- The notification handed in this frame was already taken off the queue. It is research in
		-- progress, so the rebuild queues it again; passing it on as well would show it twice.
		newNotification = nil
		RebuildStack(self)

	end

	self.itPanelOnlyActive = panelOnly

	local techTree = GetTechTree and GetTechTree()
	if self.useMarineStyle or not techTree then
		return originalUpdate(self, deltaTime, newNotification, ...)
	end

	-- Before the original update, which may clear a completed hive upgrade's progress.
	local completed = UpdateWatchedResearch(self, techTree)

	UpdateSilenced(self, deltaTime, newNotification, ...)
	RequeueDroppedResearch(self, techTree)

	if completed then
		local player = Client.GetLocalPlayer()
		if player and player.TriggerEffects then
			player:TriggerEffects(kCompleteEffect)
		end
	end

end
