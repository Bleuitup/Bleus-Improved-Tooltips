-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_MapBlipDiagnostics.lua
--
-- Two console commands for diagnosing the marine map blip colors, loaded at the end of
-- ImprovedTooltips_MapBlipColor.lua. They do nothing unless typed.
--
--   it_blipcolors   which weapon colors resolved, and whether the commander's palette was read
--   it_blipstate    every link from the setting to a colored blip, checked one by one
--
-- They read that file's state through IT._mapBlipDebug, and report its install result rather than
-- recomputing it. The install is wrapped in pcall there, so a failure cannot take these commands
-- down with it - an earlier version called Class_ReplaceMethod at the top level, where an assert
-- would have aborted the file part way, killing the commands that exist to report exactly that.
--
-- Note which VM this is. The settings panel is hooked onto a menu data file and loads in the MAIN
-- MENU VM; the map blip file is hooked onto lua/MapBlip.lua and only ever loads in the CLIENT VM,
-- once a map is running. Seeing the option in the menu says nothing about whether it loaded, and
-- neither command exists at the main menu even when everything is correct.

if not Client then
	return
end

local IT = ImprovedTooltips
local debugState = IT and IT._mapBlipDebug

if not debugState then
	return
end

local function Say(fmt, ...)
	Shared.Message("[Improved Tooltips] " .. string.format(fmt, ...))
end

local function FormatColor(color)
	return string.format("#%02X%02X%02X",
		math.floor(color.r * 255 + 0.5),
		math.floor(color.g * 255 + 0.5),
		math.floor(color.b * 255 + 0.5))
end

-- A console dump, because the risky half of the map blip file cannot be seen on the map. Reading the
-- commander's palette out of a file-local either works or silently falls back to the written-down
-- copy, and the two look nearly identical in game - the only visible tell is a modded weapon such
-- as CBM's SMG coming out uncolored. "it_blipcolors" answers it directly, with no bots, no weapons
-- and no round in progress.
Event.Hook("Console_it_blipcolors", function()

	local palette = debugState.GetCommanderPalette()

	Say("setting: big map %s, minimap %s",
		IT.kColorMarineBlipsByWeapon and "ON" or "off",
		IT.kColorMarineMinimapBlipsByWeapon and "ON" or "off")

	Say("palette: %s", palette and "read from GUIUnitStatus at runtime" or "CONFIG FALLBACK - the runtime read failed")

	if not kPlayerStatus then
		Say("kPlayerStatus is missing; nothing to resolve")
		return
	end

	local found = 0

	for name, status in pairs(kPlayerStatus) do

		if type(name) == "string" and type(status) == "number" then

			local color = debugState.GetColorForStatus(status)

			if color then
				found = found + 1
				Say("  %-18s %s", name, FormatColor(color))
			end

		end

	end

	Say("%d weapon colors resolved. Anything not listed keeps the plain marine color.", found)

end)

-- Live state, for when the colors resolve but nothing changes on the map. Every link in the chain
-- is checked separately so the answer is which one is broken, not that something is.
Event.Hook("Console_it_blipstate", function()

	Say("setting kColorMarineBlipsByWeapon (big map) = %s, kColorMarineMinimapBlipsByWeapon = %s",
		tostring(IT.kColorMarineBlipsByWeapon), tostring(IT.kColorMarineMinimapBlipsByWeapon))

	-- 1. Is our wrapper actually the function the game will call?
	Say("install: %s", debugState.GetInstallResult())
	Say("hook on MapBlip = %s, on PlayerMapBlip = %s",
		tostring(MapBlip.GetMapBlipColor == debugState.hook),
		tostring(PlayerMapBlip ~= nil and PlayerMapBlip.GetMapBlipColor == debugState.hook))

	-- 2. Would we be allowed to color anything from where we are sitting?
	local player = Client.GetLocalPlayer()
	local team = player and player:GetTeamNumber()
	Say("local player team = %s (marine is %s), allowed without spectating = %s",
		tostring(team), tostring(kTeam1Index), tostring(team == kTeam1Index))

	-- 3. Does the weapon table have anything in it?
	debugState.RefreshStatuses()

	local infoCount = 0

	for _, info in ientitylist(Shared.GetEntitiesWithClassname("PlayerInfoEntity")) do
		infoCount = infoCount + 1
		local statusName = kPlayerStatus and kPlayerStatus[info.status]
		Say("  PlayerInfoEntity: playerId=%s name=%s status=%s",
			tostring(info.playerId), tostring(info.playerName), tostring(statusName))
	end

	Say("PlayerInfoEntity count = %d", infoCount)

	-- 4. Do the blips join up to it? This is the join that has to work.
	local statusByOwner = debugState.GetStatusByOwner()
	local blipCount, marineBlips, matched = 0, 0, 0

	-- PlayerMapBlip, not MapBlip: players get the subclass (MapBlipMixin.lua:59-64).
	for _, blip in ientitylist(Shared.GetEntitiesWithClassname("PlayerMapBlip")) do

		blipCount = blipCount + 1

		if debugState.colorableBlipTypes[blip.mapBlipType] then

			marineBlips = marineBlips + 1

			local owner = blip:GetOwnerEntityId()
			local status = statusByOwner[owner]
			local color = status and debugState.GetColorForStatus(status)

			if color then
				matched = matched + 1
			end

			Say("  marine blip: owner=%s status=%s color=%s",
				tostring(owner),
				tostring(status and kPlayerStatus[status]),
				color and FormatColor(color) or "none")

		end

	end

	Say("PlayerMapBlips: %d total, %d marine or jetpacker, %d resolved to a color", blipCount, marineBlips, matched)

end)
