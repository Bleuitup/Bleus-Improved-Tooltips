-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_Common.lua
--
-- Small helpers more than one feature needs, kept in one place so they cannot drift apart. The
-- spectator supply counter once read the top bar's icon theme with the wrong field names while the
-- commander tooltip read it correctly, because each had its own copy.
--
-- Depends on no class and reads game globals only when called, so any file can load it at any
-- point in the game's load order.

ImprovedTooltips = ImprovedTooltips or { }
local IT = ImprovedTooltips

------------------------------------------------------------------------------------------------
-- Textures
------------------------------------------------------------------------------------------------

-- Vanilla's atlas of every tech icon: 12 columns of 80px cells.
IT.kBuildMenuTexture = "ui/buildmenu.dds"

-- The mod's own sheet, 448x64: seven 64px cells in one row, all white so they take a tint exactly.
-- Built by tools/build_icons.ps1, and the cell ORDER is part of the contract - append, never reorder.
IT.kOwnIconTexture = "ui/bleu_tooltip_icons.dds"
IT.kOwnIconCell =
{
	research = 0,   -- hourglass
	cooldown = 1,   -- stopwatch
	speedMarine = 2,
	health = 3,
	armor = 4,
	ready = 5,      -- tick, scoreboard
	notReady = 6,   -- cross, scoreboard
}

-- Pixel coordinates of one cell of the mod's sheet, optionally sampling a window inset from its
-- edges. An inset magnifies the glyph without touching the sheet: see the health and armor notes in
-- ImprovedTooltips_TooltipGUI.lua.
function IT.GetOwnIconCoords(cellName, inset)
	local left = IT.kOwnIconCell[cellName] * 64
	inset = inset or 0
	return { left + inset, inset, left + 64 - inset, 64 - inset }
end

------------------------------------------------------------------------------------------------
-- The top bar's supply icon
------------------------------------------------------------------------------------------------
--
-- The HUD top bar (lua/Hud2) marks supply with a dedicated icon per team, declared in
-- GUIHudSupply.kThemeData: the texture once at theme.icon, and each team's region at
-- theme[teamType].pxCoords (GUIHudSupply.lua:22-35). Read from there so a mod re-theming the top
-- bar re-themes everything using this; the literals are only a fallback.

local kFallbackSupplyTexture = "ui/hud2/team_info_atlas.dds"

function IT.GetTopBarSupplyIcon(teamType)

	local theme = GUIHudSupply and GUIHudSupply.kThemeData
	local teamTheme = theme and theme[teamType]

	if theme and theme.icon and teamTheme and teamTheme.pxCoords then
		return theme.icon, teamTheme.pxCoords
	end

	if teamType == kMarineTeamType then
		return kFallbackSupplyTexture, { 50, 100, 100, 150 }
	end

	return kFallbackSupplyTexture, { 0, 100, 50, 150 }

end

------------------------------------------------------------------------------------------------
-- Catching GUI items as a script creates them
------------------------------------------------------------------------------------------------
--
-- For scripts that keep their items in file-locals and store nothing on self, so nothing can be
-- reached after the fact. GUIManager.CreateGraphicItem is wrapped for exactly the duration of
-- fn(...), everything it creates is collected, and the original is put back before anything else -
-- including before re-raising an error from fn. Lua is single threaded and fn runs synchronously,
-- so nothing else can create items in that window.
--
-- Returns the list of items created. If the method cannot be wrapped, fn still runs and the list is
-- empty.
function IT.CaptureCreatedGraphicItems(fn, ...)

	local manager = GUIManager
	local original = manager and manager.CreateGraphicItem
	local created = { }

	if type(original) ~= "function" then
		fn(...)
		return created
	end

	manager.CreateGraphicItem = function(...)
		local item = original(...)
		created[#created + 1] = item
		return item
	end

	local ok, err = pcall(fn, ...)

	manager.CreateGraphicItem = original

	if not ok then
		error(err, 0)
	end

	return created

end

-- The texture of a captured item, or nil for anything that is not a graphic item.
function IT.GetItemTexture(item)
	return item and type(item.GetTexture) == "function" and item:GetTexture() or nil
end

------------------------------------------------------------------------------------------------
-- Biomass level tech ids
------------------------------------------------------------------------------------------------
--
-- Mirrors the file-local kBioMassTechIds in AlienTeam.lua. The index IS the team biomass level the
-- node stands for, so the list stays positional: a name a mod has removed leaves false in its place
-- rather than closing the gap. Looked up by name, since the engine enum raises on a missing one.
-- Built on first use, when kTechId is complete.

local kBioMassNames =
{
	"BioMassOne", "BioMassTwo", "BioMassThree", "BioMassFour", "BioMassFive", "BioMassSix",
	"BioMassSeven", "BioMassEight", "BioMassNine", "BioMassTen", "BioMassEleven", "BioMassTwelve",
}

local bioMassTechIds = nil

function IT.GetBioMassTechIds()

	if not bioMassTechIds then
		local ids = { }
		for i = 1, #kBioMassNames do
			ids[i] = IT.GetTechIdByName(kBioMassNames[i]) or false
		end
		bioMassTechIds = ids
	end

	return bioMassTechIds

end

------------------------------------------------------------------------------------------------
-- Tech lookup by name
------------------------------------------------------------------------------------------------
--
-- kTechId is an ENGINE enum, not a plain table, and indexing it with a name it does not hold raises
--
--     Element 'DualMinigun' doesn't exist in the enum
--
-- rather than returning nil. Vanilla has UpgradeToDualMinigun but no DualMinigun, so deriving a
-- name and looking it up throws on a perfectly ordinary install. The entries live directly in the
-- underlying table - pairs() walks them - so rawget reads them without the metamethod that raises.
-- Use this for ANY name that might not exist: tech from a mod that may not be loaded, or a name
-- derived from another name.
function IT.GetTechIdByName(name)

	if type(name) ~= "string" or type(kTechId) ~= "table" then
		return nil
	end

	local techId = rawget(kTechId, name)

	return type(techId) == "number" and techId or nil

end

------------------------------------------------------------------------------------------------
-- Server: sending the mod's messages
------------------------------------------------------------------------------------------------

if not Server then
	return
end

-- Bots go through the same cast and join paths as people but have no client to message.
function IT.SendToPlayer(player, messageName, message)

	if not player or (player.GetIsVirtual and player:GetIsVirtual()) then
		return
	end

	Server.SendNetworkMessage(player, messageName, message, true)

end

function IT.SendToTeam(teamNumber, messageName, message)
	for _, player in ipairs(GetEntitiesForTeam("Player", teamNumber)) do
		IT.SendToPlayer(player, messageName, message)
	end
end
