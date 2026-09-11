-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_MapBlipColor.lua
--
-- Post-hook on lua/MapBlip.lua. Colors marine player blips on the map by the weapon each one is
-- carrying, so a glance at the map says where the shotguns are rather than only where bodies are.
-- The big map and the minimaps are switched separately; see GetIsEnabledFor. The big map is on by
-- default from 1.04a, the minimap off.
--
-- THE COLORS ARE THE COMMANDER'S OWN, AND ARE READ FROM THE GAME. NS2 has three per-weapon
-- palettes and they are not shown to the same people:
--
--   the outline glow on the model   ui/marine_outline_lookup.dds, indexed from EquipmentOutline.lua
--                                   everyone, the commander included (CommanderGlowMixin.lua:32)
--   the ammo bar, top-down          GUIUnitStatus.lua:57-64, keyed by kTechId
--                                   THE COMMANDER
--   the ammo bar, spectating        GUIInsight_PlayerHealthbars.lua:42-56, keyed by kMapName
--                                   spectators only (GUIInsight_Overhead.lua:224)
--
-- The middle one is what this uses. A commander reading this map is reading those bars on the same
-- screen at the same moment, so the map agreeing with them is worth more than agreeing with either
-- of the others. All three match exactly on shotgun, grenade launcher and flamethrower anyway; they
-- differ on HMG by a shade, and on the rifle three ways, where the map takes the commander's teal.
--
-- WHY THE BASE COLOR IS FED RATHER THAN THE RESULT RETURNED. Vanilla's GetMapBlipColor picks a
-- color by blip type and THEN transforms it (MapBlip.lua:301):
--
--     if MapBlip.kFriendsHighlightingEnabled and friendTeams[blipTeam] then
--         sat = sat * .5
--
-- Steam friends are not a separate color, they are half the saturation of whatever was chosen. A
-- wrapper that returned a weapon color would land after that block and wipe it. So this sets
-- MapBlip.kCustomMarineColor for the duration of the original call and puts it back afterwards:
-- the friend tint composes on top by itself, and the hallucination check and the commander's
-- same-building highlight are untouched. A friend with an HMG comes out half-saturated red.
--
-- IT IS GATED ON THE VIEWER'S TEAM, NOT ON THE BLIP. An alien can see a marine blip: MapBlip.lua:326
-- deliberately shows Steam friends across teams - "Used to be a bug, now it's a feature" - and
-- vanilla guards a related leak two lines later with "Don't give the enemy privileged information!"
-- Coloring by blip type alone would tell the alien team what their friend is carrying. So this
-- only applies when the local player is on the marine team, or spectating, where every loadout is
-- visible anyway.
--
-- EXOS ARE LEFT ON THE PLAIN MARINE COLOR, deliberately, but not for the reason first written
-- here. Vanilla DOES have exo colors - GUIInsight_PlayerHealthbars.kAmmoColors:53-54 gives minigun
-- red and railgun orange on those ammo bars. The reason is CBM: an exo there is modular
-- and can carry any combination of guns, so there is no single weapon to color one by and a
-- minigun/railgun split would be wrong the moment CBM retuned a loadout. Only Marine and
-- JetpackMarine blips are touched; kMinimapBlipType.Exo falls through to the flat marine color.
--
-- THE LOCAL PLAYER'S OWN MARKER IS NOT A MapBlip and cannot be reached from here. It is a separate
-- player icon with its own setting, AdvancedOptions["minimaparrowcolor"] (AdvancedOptions.lua:1066)
-- applied through minimapScript:SetPlayerIconColor. Nothing here needs to exclude it.
--
-- COLORBLIND MODE NEEDS NOTHING. NS2 has no Lua-side colorblind handling at all; it is a render
-- setting, Client.SetRenderSetting("colorblind_mode", n) in Render.lua:78, applied to the whole
-- frame downstream of everything. These colors get the same filter as every other color in the
-- game, for free.

if not Client then
	return
end

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Config.lua")

local IT = ImprovedTooltips
-- THE COLORS ARE READ FROM THE GAME, NOT WRITTEN DOWN, whenever that is possible.
--
-- GUIUnitStatus.lua:57-64 holds kAmmoBarColors, keyed by kTechId: it is what colors the ammo bar
-- under each marine in the COMMANDER's top-down view, and it is therefore the palette a commander
-- is already reading on the same screen as this map. CBM extends it with kTechId.Submachinegun,
-- and any other mod adding a weapon would do the same, so reading it means never hardcoding a mod's
-- colors here.
--
-- It is a file-local, so it cannot simply be indexed. It CAN be pulled out of the upvalues of a
-- function that closes over it - GUIUnitStatus:UpdateUnitStatusBlip, which uses it at :678 - with
-- debug.getupvalue. That is a normal technique in this ecosystem rather than a trick: Shine ships a
-- wrapper for it (shine/lib/debug.lua) and NSL uses it too.
--
-- The bridge from a blip to that table is by NAME. kPlayerStatus and kTechId use identical names
-- for every weapon that matters - Shotgun, GrenadeLauncher, Flamethrower, HeavyMachineGun, and
-- CBM's Submachinegun - so a status resolves to a techId with no table of our own. kTechId is an
-- ENGINE enum that RAISES on an unknown name, hence IT.GetTechIdByName, which rawgets.
--
-- The written-down table below is the fallback for when that read fails: an NS2 build that drops
-- the debug library, a scoreboard mod that replaces GUIUnitStatus with something shaped
-- differently, or a rename. Its values are the commander palette's, copied.
local kFallbackColors = { }

local function MapWeapon(statusName, color)

	local status = kPlayerStatus and rawget(kPlayerStatus, statusName)

	if status ~= nil and color ~= nil then
		kFallbackColors[status] = color
	end

end

MapWeapon("Rifle",           IT.kMapBlipColorRifle)
MapWeapon("Shotgun",         IT.kMapBlipColorShotgun)
MapWeapon("GrenadeLauncher", IT.kMapBlipColorGrenadeLauncher)
MapWeapon("Flamethrower",    IT.kMapBlipColorFlamethrower)
MapWeapon("HeavyMachineGun", IT.kMapBlipColorHeavyMachineGun)
MapWeapon("Submachinegun",   IT.kMapBlipColorSubmachinegun)

-- IT IS THE PRIMARY WEAPON, NOT THE ONE IN HAND, and that falls out of the data source rather than
-- needing work: Marine:GetPlayerStatusDesc reads GetWeaponInHUDSlot(1) - the primary slot - so a
-- shotgunner who switches to a welder or a pistol still reports Shotgun. Which is the behavior
-- wanted: the map should say what that marine can bring, not what is momentarily raised.
--
-- Nothing is excluded here. An earlier version held rifles back on the theory that they should stay
-- the plain team color; the user corrected it. A rifle IS a primary weapon and takes the
-- commander palette's teal like any other. Pistols, axes and welders never appear at all, since
-- kPlayerStatus has no value for them - they can only ever sit in slots 2 and 3.

local commanderPalette = nil
local paletteResolved = false

local function GetCommanderPalette()

	if paletteResolved then
		return commanderPalette
	end

	if not IT.kMapBlipReadCommanderPalette then
		paletteResolved = true
		return nil
	end

	-- Not an error yet: GUIUnitStatus may simply not have loaded. Try again next time rather than
	-- giving up and falling back for the rest of the session.
	if not GUIUnitStatus or type(GUIUnitStatus.UpdateUnitStatusBlip) ~= "function" then
		return nil
	end

	paletteResolved = true

	if type(debug) ~= "table" or type(debug.getupvalue) ~= "function" then
		return nil
	end

	local index = 1

	while true do

		local name, value = debug.getupvalue(GUIUnitStatus.UpdateUnitStatusBlip, index)

		if name == nil then
			break
		end

		if name == "kAmmoBarColors" and type(value) == "table" then
			commanderPalette = value
			break
		end

		index = index + 1

	end

	return commanderPalette

end

-- Resolved once per status rather than per blip: this runs inside the minimap's per-blip loop.
local resolvedColors = { }

local function GetColorForStatus(status)

	local cached = resolvedColors[status]

	if cached ~= nil then
		return cached or nil
	end

	local statusName = kPlayerStatus and kPlayerStatus[status]

	if type(statusName) ~= "string" then
		resolvedColors[status] = false
		return nil
	end

	local palette = GetCommanderPalette()
	local color

	if palette then

		local techId = IT.GetTechIdByName(statusName)

		if techId then
			color = palette[techId]
		end

	end

	color = color or kFallbackColors[status]

	-- Only remembered once the palette question is settled. Caching before GUIUnitStatus has loaded
	-- would pin every weapon to the fallback for the rest of the session.
	if paletteResolved then
		resolvedColors[status] = color or false
	end

	return color

end

-- The join from a blip to a weapon. A blip knows its owner entity id (MapBlip.lua:110); a
-- PlayerInfoEntity knows a playerId and a status, and status IS the weapon - kPlayerStatus carries
-- Rifle, Shotgun, GrenadeLauncher, Flamethrower, HeavyMachineGun as values (Globals.lua:182). It is
-- already networked to every client because the scoreboard is built from it, so nothing new is sent.
--
-- Rebuilt on an interval rather than per blip per frame: GetMapBlipColor runs once for every blip
-- on every minimap update, and walking the entity list inside that would be many times the work of
-- the drawing it feeds.
local statusByOwner = { }
local nextRefresh = 0

local function RefreshStatuses()

	local now = Shared.GetTime()

	if now < nextRefresh then
		return
	end

	nextRefresh = now + IT.kMapBlipColorRefreshInterval

	local fresh = { }

	for _, info in ientitylist(Shared.GetEntitiesWithClassname("PlayerInfoEntity")) do

		local id = info.playerId

		if id and id ~= Entity.invalidId then
			fresh[id] = info.status
		end

	end

	statusByOwner = fresh

end

-- Marine and jetpacker only. Exo is deliberately absent; see the note at the top.
local kColorableBlipTypes = { }

if kMinimapBlipType then
	kColorableBlipTypes[kMinimapBlipType.Marine] = true
	kColorableBlipTypes[kMinimapBlipType.JetpackMarine] = true
end

-- Marine side or spectating. minimap.spectating is vanilla's own notion, used a few lines into
-- GetMapBlipColor itself, so this agrees with whatever the game already decided.
local function GetIsViewerAllowed(minimap)

	if minimap and minimap.spectating then
		return true
	end

	local player = Client.GetLocalPlayer()

	return player ~= nil and player:GetTeamNumber() == kTeam1Index

end

local function GetWeaponColor(blip)

	if not kColorableBlipTypes[blip.mapBlipType] then
		return nil
	end

	RefreshStatuses()

	local status = statusByOwner[blip:GetOwnerEntityId()]

	return status and GetColorForStatus(status) or nil

end

-- One toggle for the big map, one for every minimap (1.04). Every map on screen is a
-- GUIMinimapFrame, and the frame passed in says which one it is by its mode (GUIMinimapFrame.lua:30-32):
--
--   kModeBig    the map on the map key, for field players and commanders alike
--   kModeZoom   the marine HUD's own minimap, top left - a second instance that never leaves this
--               mode (GUIMarineHUD.lua:372, and the note at GUIMinimapFrame.lua:228)
--   kModeMini   the commander's and the spectator's corner minimap (Commander_Client.lua:767)
--
-- So "big" is the one test and anything else counts as a minimap. Read per call rather than cached
-- per frame, because an overhead view flips a single instance between mini and big.
local function GetIsEnabledFor(minimap)

	local isBigMap = minimap ~= nil and GUIMinimapFrame ~= nil and minimap.comMode == GUIMinimapFrame.kModeBig

	if isBigMap then
		return IT.kColorMarineBlipsByWeapon
	end

	return IT.kColorMarineMinimapBlipsByWeapon

end

local originalGetMapBlipColor

local function ColorMapBlipByWeapon(self, minimap, item)

	if not GetIsEnabledFor(minimap) then
		return originalGetMapBlipColor(self, minimap, item)
	end

	if not GetIsViewerAllowed(minimap) then
		return originalGetMapBlipColor(self, minimap, item)
	end

	local color = GetWeaponColor(self)

	if not color then
		return originalGetMapBlipColor(self, minimap, item)
	end

	-- Swapped in only for the duration of the call, and restored even if that call raises, so a
	-- fault inside vanilla cannot leave every marine on the map stuck at one weapon's color. The
	-- original reads MapBlip.kCustomMarineColor by name whichever class it was copied onto, so
	-- setting it here reaches every one of them.
	local saved = MapBlip.kCustomMarineColor
	MapBlip.kCustomMarineColor = color

	local ok, result = pcall(originalGetMapBlipColor, self, minimap, item)

	MapBlip.kCustomMarineColor = saved

	if not ok then
		error(result)
	end

	return result

end

-- INSTALLING THE HOOK, DEFENSIVELY, AND SAYING SO.
--
-- Two things have to be true and neither is guaranteed:
--
--   1. Players get a PlayerMapBlip, not a MapBlip (MapBlipMixin.lua:59-64), and NS2's class system
--      COPIES methods into derived classes rather than delegating through __index. So assigning to
--      MapBlip.GetMapBlipColor alone leaves PlayerMapBlip holding its own copy and does nothing.
--   2. Class_ReplaceMethod (core/lua/Class.lua) is the sanctioned way to do it, but it asserts on
--      both `original ~= nil` and `Script.GetDerivedClasses(...) ~= nil` as it recurses. An assert
--      here would abort this file part way, taking the console commands with it and leaving no
--      trace but a log line - which is exactly what a silent failure looks like from the outside.
--
-- So the replacement is done by hand: set it on MapBlip, then on each known subclass that is still
-- holding the original. Same effect, no assert, and the result is reported rather than assumed.
local kInstallResult = "not attempted"

local function InstallHook()

	if type(MapBlip) ~= "table" or type(MapBlip.GetMapBlipColor) ~= "function" then
		kInstallResult = "FAILED - MapBlip.GetMapBlipColor is missing"
		return
	end

	originalGetMapBlipColor = MapBlip.GetMapBlipColor
	MapBlip.GetMapBlipColor = ColorMapBlipByWeapon

	local patched = { "MapBlip" }

	-- Named rather than discovered, because Script.GetDerivedClasses is the part of
	-- Class_ReplaceMethod that can assert. These are the only two subclasses MapBlip.lua declares
	-- (:461 and :497); a third would simply keep vanilla's color and be no worse than today.
	for _, name in ipairs({ "PlayerMapBlip", "ScanMapBlip" }) do

		local class = _G[name]

		if type(class) == "table" and rawget(class, "GetMapBlipColor") == originalGetMapBlipColor then
			class.GetMapBlipColor = ColorMapBlipByWeapon
			patched[#patched + 1] = name
		end

	end

	kInstallResult = "installed on " .. table.concat(patched, ", ")

end

local ok, err = pcall(InstallHook)

if not ok then
	kInstallResult = "FAILED - " .. tostring(err)
end


-- A console dump, because the risky half of this file cannot be seen on the map. Reading the
-- commander's palette out of a file-local either works or silently falls back to the written-down
-- copy, and the two look nearly identical in game - the only visible tell is a modded weapon such
-- as CBM's SMG coming out uncolored. "it_blipcolors" answers it directly, with no bots, no weapons
-- and no round in progress.
Event.Hook("Console_it_blipcolors", function()

	local palette = GetCommanderPalette()

	Shared.Message(string.format("[Improved Tooltips] setting: big map %s, minimap %s",
		IT.kColorMarineBlipsByWeapon and "ON" or "off",
		IT.kColorMarineMinimapBlipsByWeapon and "ON" or "off"))

	Shared.Message(string.format("[Improved Tooltips] palette: %s",
		palette and "read from GUIUnitStatus at runtime" or "CONFIG FALLBACK - the runtime read failed"))

	if not kPlayerStatus then
		Shared.Message("[Improved Tooltips] kPlayerStatus is missing; nothing to resolve")
		return
	end

	local found = 0

	for name, status in pairs(kPlayerStatus) do

		if type(name) == "string" and type(status) == "number" then

			local color = GetColorForStatus(status)

			if color then
				found = found + 1
				Shared.Message(string.format("[Improved Tooltips]   %-18s #%02X%02X%02X", name,
					math.floor(color.r * 255 + 0.5),
					math.floor(color.g * 255 + 0.5),
					math.floor(color.b * 255 + 0.5)))
			end

		end

	end

	Shared.Message(string.format("[Improved Tooltips] %d weapon colors resolved. Anything not listed keeps the plain marine color.", found))

end)

-- Live state, for when the colors resolve but nothing changes on the map. Every link in the chain
-- is checked separately so the answer is which one is broken, not that something is.
Event.Hook("Console_it_blipstate", function()

	local function Say(fmt, ...)
		Shared.Message("[Improved Tooltips] " .. string.format(fmt, ...))
	end

	Say("setting kColorMarineBlipsByWeapon (big map) = %s, kColorMarineMinimapBlipsByWeapon = %s",
		tostring(IT.kColorMarineBlipsByWeapon), tostring(IT.kColorMarineMinimapBlipsByWeapon))

	-- 1. Is our wrapper actually the function the game will call?
	Say("install: %s", kInstallResult)
	Say("hook on MapBlip = %s, on PlayerMapBlip = %s",
		tostring(MapBlip.GetMapBlipColor == ColorMapBlipByWeapon),
		tostring(PlayerMapBlip ~= nil and PlayerMapBlip.GetMapBlipColor == ColorMapBlipByWeapon))

	-- 2. Would we be allowed to color anything from where we are sitting?
	local player = Client.GetLocalPlayer()
	local team = player and player:GetTeamNumber()
	Say("local player team = %s (marine is %s), allowed without spectating = %s",
		tostring(team), tostring(kTeam1Index), tostring(team == kTeam1Index))

	-- 3. Does the weapon table have anything in it?
	RefreshStatuses()

	local infoCount = 0

	for _, info in ientitylist(Shared.GetEntitiesWithClassname("PlayerInfoEntity")) do
		infoCount = infoCount + 1
		local statusName = kPlayerStatus and kPlayerStatus[info.status]
		Say("  PlayerInfoEntity: playerId=%s name=%s status=%s",
			tostring(info.playerId), tostring(info.playerName), tostring(statusName))
	end

	Say("PlayerInfoEntity count = %d", infoCount)

	-- 4. Do the blips join up to it? This is the join that has to work.
	local blipCount, marineBlips, matched = 0, 0, 0

	-- PlayerMapBlip, not MapBlip: players get the subclass (MapBlipMixin.lua:59-64).
	for _, blip in ientitylist(Shared.GetEntitiesWithClassname("PlayerMapBlip")) do

		blipCount = blipCount + 1

		if kColorableBlipTypes[blip.mapBlipType] then

			marineBlips = marineBlips + 1

			local owner = blip:GetOwnerEntityId()
			local status = statusByOwner[owner]
			local color = status and GetColorForStatus(status)

			if color then
				matched = matched + 1
			end

			Say("  marine blip: owner=%s status=%s color=%s",
				tostring(owner),
				tostring(status and kPlayerStatus[status]),
				color and string.format("#%02X%02X%02X",
					math.floor(color.r * 255 + 0.5),
					math.floor(color.g * 255 + 0.5),
					math.floor(color.b * 255 + 0.5)) or "none")

		end

	end

	Say("PlayerMapBlips: %d total, %d marine or jetpacker, %d resolved to a color", blipCount, marineBlips, matched)

end)


-- Reporting kInstallResult rather than recomputing it, and the install above is wrapped in pcall so
-- it cannot throw and take these down with it. The previous version called Class_ReplaceMethod at
-- the top level, and an assert inside it would have aborted the file part way, killing the console
-- commands that exist to report exactly that fault.
--
-- Note which VM this is. The settings panel is hooked onto a menu data file and loads in the MAIN
-- MENU VM; this file is hooked onto lua/MapBlip.lua and only ever loads in the CLIENT VM, once a
-- map is running. Seeing the option in the menu says nothing about whether this file loaded, and
-- neither command exists at the main menu even when everything is correct.
