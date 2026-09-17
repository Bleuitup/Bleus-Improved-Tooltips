-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_ResearchSound.lua
--
-- Post-hook on lua/Hud/GUIEvent.lua. Client only.
--
-- GUIEvent, the research notification stack on the left, is also what plays the "trait available"
-- sound: when a notification it shows turns complete, it calls
-- Client.GetLocalPlayer():TriggerEffects("upgrade_complete") (GUIEvent.lua:348). In HIVE PANEL ONLY,
-- ImprovedTooltips_ResearchNotifications.lua keeps hive research out of that stack, which would
-- silence the sound too. This plays it for those researches instead, copying GUIEvent's rules:
--
--   - checked from GUIEvent:Update, so it only happens while the alien HUD is running, as before;
--   - complete means the tech node's progress for that entity is exactly 1;
--   - a research neither complete nor still in progress was cancelled, and makes no sound;
--   - GUIEvent:Initialize starts from a clean list, as vanilla clears its queue there and re-adds
--     every research still in progress.

if not Client then
	return
end

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Values.lua")

local IT = ImprovedTooltips

IT.hiddenResearchNotifications = IT.hiddenResearchNotifications or { }

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

local originalInitialize = GUIEvent.Initialize
function GUIEvent:Initialize(...)

	-- Before the original, which re-adds the research still in progress.
	IT.hiddenResearchNotifications = { }
	return originalInitialize(self, ...)

end

local originalUpdate = GUIEvent.Update
function GUIEvent:Update(...)

	originalUpdate(self, ...)
	UpdateHiddenResearch()

end
