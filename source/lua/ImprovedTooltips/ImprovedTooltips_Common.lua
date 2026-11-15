-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_Common.lua
--
-- Small helpers more than one feature needs, kept in one place so they cannot drift apart.
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
-- Since 1.2 only the two scoreboard cells are used; the tooltip glyphs went vanilla with build 345,
-- but their cells stay so the order holds.
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
-- edges, which magnifies the glyph without touching the sheet.
function IT.GetOwnIconCoords(cellName, inset)
	local left = IT.kOwnIconCell[cellName] * 64
	inset = inset or 0
	return { left + inset, inset, left + 64 - inset, 64 - inset }
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
-- Nutrient mist: is it doing anything for this entity?
------------------------------------------------------------------------------------------------
--
-- Mist marks an entity with CatalystMixin's networked isCatalysted flag, and only when
-- CatalystMixin:GetCanCatalyst says it should: growing, an embryo, a damaged cyst, or a structure
-- off infestation. Two of those reasons do nothing in the game's own code (checked 2026-10-30, and
-- again on build 345 on 2026-11-14):
--
--   - Off infestation: AlienTeam's off-infestation damage (2% of max health a second, at least 20)
--     never checks the flag, so a grown harvester off infestation starves misted or not.
--   - Damaged cyst: CatalystMixin's heal constants are never used, so mist heals nothing. It does
--     stop a DISCONNECTED cyst's starvation damage (Cyst_Server.lua:353 in build 345), grown or not.
--
-- So an entity counts as helped when it is flagged AND it is an embryo (evolves faster), still
-- growing (matures faster, MaturityMixin:GetMaturityMistBonus), or a disconnected cyst. A grown
-- structure is never badged, whatever the flag says. Client-safe: the flag, maturityFraction and the
-- cyst's connected state are all network fields.
function IT.GetIsMistHelping(entity)

	if not entity or not HasMixin(entity, "Catalyst") or not entity:GetIsCatalysted() then
		return false
	end

	if entity:isa("Embryo") then
		return true
	end

	local growing = HasMixin(entity, "Maturity") and not entity:GetIsMature()

	if entity:isa("Cyst") then
		return growing or not entity.connected
	end

	return growing

end
