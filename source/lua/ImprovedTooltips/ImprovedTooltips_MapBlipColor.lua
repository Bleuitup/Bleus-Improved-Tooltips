-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_MapBlipColor.lua
--
-- Post-hook on lua/MapBlip.lua. Colours marine player blips on the map by the weapon each one is
-- carrying, so a glance at the map says where the shotguns are rather than only where bodies are.
-- Off by default: it is more to read, and not everyone wants it.
--
-- THE COLOURS ARE VANILLA'S OWN. EquipmentOutline.lua:17-27 already maps weapon class to a colour
-- for the outline you see on a dropped weapon in the world, sampled by index out of
-- ui/marine_outline_lookup.dds. Those exact five values are reused here, so a shotgun is the same
-- green on the map as it is on the floor and there is one mapping to learn rather than two.
-- Anything not in that list - rifle, pistol, welder, axe - is left alone entirely and keeps the
-- player's own playercolor_m, which is both what vanilla's palette does with them and what the
-- user asked for.
--
-- WHY THE BASE COLOUR IS FED RATHER THAN THE RESULT RETURNED. Vanilla's GetMapBlipColor picks a
-- colour by blip type and THEN transforms it (MapBlip.lua:301):
--
--     if MapBlip.kFriendsHighlightingEnabled and friendTeams[blipTeam] then
--         sat = sat * .5
--
-- Steam friends are not a separate colour, they are half the saturation of whatever was chosen. A
-- wrapper that returned a weapon colour would land after that block and wipe it. So this sets
-- MapBlip.kCustomMarineColor for the duration of the original call and puts it back afterwards:
-- the friend tint composes on top by itself, and the hallucination check and the commander's
-- same-building highlight are untouched. A friend with an HMG comes out half-saturated red.
--
-- IT IS GATED ON THE VIEWER'S TEAM, NOT ON THE BLIP. An alien can see a marine blip: MapBlip.lua:326
-- deliberately shows Steam friends across teams - "Used to be a bug, now it's a feature" - and
-- vanilla guards a related leak two lines later with "Don't give the enemy privileged information!"
-- Colouring by blip type alone would tell the alien team what their friend is carrying. So this
-- only applies when the local player is on the marine team, or spectating, where every loadout is
-- visible anyway.
--
-- EXOS ARE LEFT ON THE PLAIN MARINE COLOUR, deliberately. Vanilla's palette has no exo entry, and
-- under CBM an exo is modular - any combination of guns - so there is no one weapon to colour it
-- by. Only Marine and JetpackMarine blips are touched; kMinimapBlipType.Exo falls through.
--
-- THE LOCAL PLAYER'S OWN MARKER IS NOT A MapBlip and cannot be reached from here. It is a separate
-- player icon with its own setting, AdvancedOptions["minimaparrowcolor"] (AdvancedOptions.lua:1066)
-- applied through minimapScript:SetPlayerIconColor. Nothing here needs to exclude it.
--
-- COLOURBLIND MODE NEEDS NOTHING. NS2 has no Lua-side colourblind handling at all; it is a render
-- setting, Client.SetRenderSetting("colorblind_mode", n) in Render.lua:78, applied to the whole
-- frame downstream of everything. These colours get the same filter as every other colour in the
-- game, for free.

if not Client then
	return
end

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Config.lua")

local IT = ImprovedTooltips

-- Built rather than written as a literal table, because kPlayerStatus is an ordinary Lua enum that
-- a mod is free to reshape. A missing name yields nil and is skipped rather than raising on
-- t[nil] = v.
local kWeaponColors = { }

local function MapWeapon(statusName, color)

	local status = kPlayerStatus and rawget(kPlayerStatus, statusName)

	if status ~= nil and color ~= nil then
		kWeaponColors[status] = color
	end

end

MapWeapon("Shotgun",         IT.kMapBlipColorShotgun)
MapWeapon("GrenadeLauncher", IT.kMapBlipColorGrenadeLauncher)
MapWeapon("Flamethrower",    IT.kMapBlipColorFlamethrower)
MapWeapon("HeavyMachineGun", IT.kMapBlipColorHeavyMachineGun)

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

	return status and kWeaponColors[status] or nil

end

local originalGetMapBlipColor = MapBlip.GetMapBlipColor

function MapBlip:GetMapBlipColor(minimap, item)

	if not IT.kColorMarineBlipsByWeapon then
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
	-- fault inside vanilla cannot leave every marine on the map stuck at one weapon's colour.
	local saved = MapBlip.kCustomMarineColor
	MapBlip.kCustomMarineColor = color

	local ok, result = pcall(originalGetMapBlipColor, self, minimap, item)

	MapBlip.kCustomMarineColor = saved

	if not ok then
		error(result)
	end

	return result

end
