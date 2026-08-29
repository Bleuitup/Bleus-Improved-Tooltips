-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_Values.lua
--
-- Works out which extra numbers a given techId should show, and what those numbers are right now.
--
-- The guiding idea is that no per-tech table is maintained here. Every value already lives in
-- TechData under a key the tech cannot function without, so reading the key IS the detection:
--
--   kTechDataResearchTimeKey  -> research/upgrade duration   (77 vanilla entries)
--   kTechDataMaxHealth        -> health                      (81 vanilla entries)
--   kTechDataMaxArmor         -> armor
--   kTechDataCooldown         -> cast/drop cooldown          (19 vanilla entries)
--
-- A mod that adds tech has to populate these for the tech to work at all, so CBM's Advanced Shade,
-- CompMod's Charge and B2TP's MedTech all get improved tooltips without this mod knowing they
-- exist.
--
-- The exception is a value vanilla computes at spawn time instead of storing in TechData - Bone
-- Wall's biomass scaling being the one vanilla case. Those go through the resolver registry below,
-- which is the public extension point for other mods.

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Config.lua")

ImprovedTooltips = ImprovedTooltips or { }
local IT = ImprovedTooltips

IT.kVersion = "0.86"

-- The extra fields this mod can show. Used as keys throughout, including in the public API.
IT.kFields = { "health", "armor", "researchTime", "cooldown", "speed" }

-- Broad classification of what a techId IS, derived from the tech tree rather than a hand-kept
-- list. Not used to decide which numbers to show - that is driven purely by which TechData keys
-- exist - but exposed because it is useful for suppression rules and for debugging coverage.
IT.kCategory = {
	Tech      = "tech",       -- researches and upgrades: Armor 3, Stomp, Biomass
	Structure = "structure",  -- anything dropped or manufactured: Armory, Hive, Drifter, ARC
	Cast      = "cast",       -- commander abilities: Bone Wall, Power Surge, Nutrient Mist
	None      = "none",       -- orders, menus, and anything without a tech node
}

local kCategoryByTechType = nil

local function BuildCategoryLookup()

	kCategoryByTechType = {
		[kTechType.Research]           = IT.kCategory.Tech,
		[kTechType.Upgrade]            = IT.kCategory.Tech,
		[kTechType.Build]              = IT.kCategory.Structure,
		[kTechType.EnergyBuild]        = IT.kCategory.Structure,
		[kTechType.Buy]                = IT.kCategory.Structure,
		[kTechType.Manufacture]        = IT.kCategory.Structure,
		[kTechType.EnergyManufacture]  = IT.kCategory.Structure,
		[kTechType.PlasmaManufacture]  = IT.kCategory.Structure,
		[kTechType.Action]             = IT.kCategory.Cast,
		[kTechType.Activation]         = IT.kCategory.Cast,
	}

end

function IT.GetTechCategory(techId)

	if not kCategoryByTechType then
		BuildCategoryLookup()
	end

	local techTree = GetTechTree()
	local techNode = techTree and techTree:GetTechNode(techId)
	if not techNode then
		return IT.kCategory.None
	end

	return kCategoryByTechType[techNode:GetTechType()] or IT.kCategory.None

end

------------------------------------------------------------------------------------------------
-- Resolver registry - the public API for other mods
------------------------------------------------------------------------------------------------

-- resolvers[field][techId] = function(techId) -> number
-- suppressed[field][techId] = true
--
-- Parked on the shared table rather than being plain locals so that a Script.Load with reload set
-- (the dev console does this) refreshes the code without discarding registrations another mod
-- made against the previous copy.
local resolvers = IT._resolvers
local suppressed = IT._suppressed

if not resolvers then
	resolvers = { }
	suppressed = { }
	IT._resolvers = resolvers
	IT._suppressed = suppressed
end

-- Filled in per field rather than only when the tables are first created, so adding a field to
-- kFields does not leave a nil subtable behind on a reload that reused the existing tables.
for i = 1, #IT.kFields do
	resolvers[IT.kFields[i]] = resolvers[IT.kFields[i]] or { }
	suppressed[IT.kFields[i]] = suppressed[IT.kFields[i]] or { }
end

local function IsValidField(field)
	return resolvers[field] ~= nil
end

-- Register a function that computes a field's live value for one techId, overriding the plain
-- TechData lookup. The function is called every frame the tooltip is visible, so keep it cheap.
-- Return 0 or nil to hide the field.
--
--   ImprovedTooltips.RegisterResolver("health", kTechId.BoneWall, function(techId) ... end)
function IT.RegisterResolver(field, techId, resolverFunction)

	if not IsValidField(field) then
		Print("ImprovedTooltips.RegisterResolver: unknown field '%s'", ToString(field))
		return false
	end

	resolvers[field][techId] = resolverFunction
	return true

end

-- Hide a field for one techId even though TechData carries a value for it. For tech where the
-- stored number exists for the engine's benefit but would mislead a commander.
function IT.SuppressField(field, techId)

	if not IsValidField(field) then
		Print("ImprovedTooltips.SuppressField: unknown field '%s'", ToString(field))
		return false
	end

	suppressed[field][techId] = true
	return true

end

------------------------------------------------------------------------------------------------
-- Value resolution
------------------------------------------------------------------------------------------------

-- Movement speed is the one field with no TechData key at all - it lives as a class constant,
-- `<Class>.kMoveSpeed`, on the six things that move: ARC 2.0, Shade 2.5, Shift 2.9, Whip 3.5,
-- MAC 6, Drifter 11.
--
-- Rather than keep a techId -> class table, the class is derived. kTechId is bidirectional (see
-- GetTechIdsWithCooldown), so kTechId[techId] gives the enum's own name - "ARC", "MAC", "Drifter",
-- "Whip" - and NS2 classes are globals under exactly those names. A modded mover whose techId is
-- named after its class is therefore picked up with no registration, same as everything else here.
--
-- The lookup is deliberately paranoid: plenty of techId names collide with unrelated globals
-- (kTechId.Move and the Move hotkey table, for one), so a hit only counts if it is a table carrying
-- a positive numeric kMoveSpeed.
local function LookupClassMoveSpeed(techId)

	local className = kTechId[techId]
	if type(className) ~= "string" then
		return 0
	end

	local class = _G[className]
	if type(class) ~= "table" then
		return 0
	end

	local speed = class.kMoveSpeed
	return (type(speed) == "number" and speed > 0) and speed or 0

end

local kDefaultLookup = {
	health       = function(techId) return LookupTechData(techId, kTechDataMaxHealth, 0) end,
	armor        = function(techId) return LookupTechData(techId, kTechDataMaxArmor, 0) end,
	researchTime = function(techId) return LookupTechData(techId, kTechDataResearchTimeKey, 0) end,
	cooldown     = function(techId) return LookupTechData(techId, kTechDataCooldown, 0) end,
	speed        = LookupClassMoveSpeed,
}

function IT.GetValue(field, techId)

	if not IsValidField(field) or suppressed[field][techId] then
		return 0
	end

	local resolver = resolvers[field][techId] or kDefaultLookup[field]
	local value = resolver(techId)

	return (type(value) == "number" and value > 0) and value or 0

end

-- Returns the full set of extra values for a techId, or nil if there is nothing extra to show.
-- Called once per frame while a tooltip is up.
function IT.GetValues(techId)

	if not techId or techId == kTechId.None then
		return nil
	end

	local values = {
		health       = IT.GetValue("health", techId),
		armor        = IT.GetValue("armor", techId),
		researchTime = IT.GetValue("researchTime", techId),
		cooldown     = IT.GetValue("cooldown", techId),
		speed        = IT.GetValue("speed", techId),
	}

	for i = 1, #IT.kFields do
		if values[IT.kFields[i]] > 0 then
			return values
		end
	end

	return nil

end

------------------------------------------------------------------------------------------------
-- Cooldown tech enumeration
------------------------------------------------------------------------------------------------

-- Every techId carrying a cooldown, found the same way everything else here is: by asking TechData
-- rather than keeping a list. Used by the cooldown sync (server) and the "In Cooldown" panel
-- (client), and it picks up modded abilities for free.
--
-- Built once on first use rather than at load time, because TechData is assembled during startup
-- and mods post-hook it - asking too early would miss whatever had not been added yet.
local cooldownTechIds = nil

function IT.GetTechIdsWithCooldown(minDuration)

	if not cooldownTechIds then

		cooldownTechIds = { }

		for name, techId in pairs(kTechId) do
			-- kTechId carries reverse string lookups and a Max sentinel alongside the real values.
			if type(techId) == "number" and type(name) == "string" and name ~= "Max" and techId ~= kTechId.None then
				local cooldown = LookupTechData(techId, kTechDataCooldown, 0)
				if type(cooldown) == "number" and cooldown > 0 then
					table.insert(cooldownTechIds, techId)
				end
			end
		end

		-- pairs() order is undefined; sort so the panel lists abilities consistently between
		-- clients and across rounds rather than in whatever order the hash walk produced.
		table.sort(cooldownTechIds)

	end

	if not minDuration or minDuration <= 0 then
		return cooldownTechIds
	end

	local filtered = { }
	for i = 1, #cooldownTechIds do
		local techId = cooldownTechIds[i]
		if LookupTechData(techId, kTechDataCooldown, 0) >= minDuration then
			table.insert(filtered, techId)
		end
	end

	return filtered

end

------------------------------------------------------------------------------------------------
-- Vanilla dynamic values
------------------------------------------------------------------------------------------------

-- Bone Wall is the one vanilla case where the real health is computed at spawn rather than stored
-- in TechData: BoneWall:OnInitialized reads the team's biomass level and calls SetMaxHealth. See
-- ns2/lua/CommAbilities/Alien/BoneWall.lua. Mirrored here so the tooltip tracks biomass live -
-- at biomass 9 the stored TechData value of 100 would be off by 800.
local function GetAlienBioMassLevel()

	local teamInfo = GetTeamInfoEntity(kTeam2Index)
	if teamInfo and teamInfo.GetBioMassLevel then
		return teamInfo:GetBioMassLevel()
	end

	return 0

end

-- An ARC is a different unit depending on its stance, and vanilla stores both sets:
-- kARCArmor = 400 undeployed against kARCDeployedArmor = 0 (BalanceHealth.lua:100-101), and it
-- cannot move at all once deployed. ARC.lua:212-213 keeps both as undeployedArmor/deployedArmor.
--
-- kTechId.ARC itself carries the undeployed values in TechData and moves at ARC.kMoveSpeed, so it
-- needs nothing. The two stance buttons carry no TechData at all, which leaves them free to
-- describe the state they put the ARC INTO - so the Deploy button reads "0 armour, no speed",
-- making the cost of deploying visible at the moment you are choosing it.
-- The constants are read inside the resolvers, not captured here: this file is loaded from a
-- post-hook and there is no guarantee ARC.lua or BalanceHealth.lua have run yet at registration
-- time. Resolvers only run while a tooltip is on screen, by which point everything is loaded.
local function RegisterArcStance(techId, getArmor, getSpeed)

	IT.RegisterResolver("armor", techId, getArmor)
	IT.RegisterResolver("speed", techId, getSpeed)
	IT.RegisterResolver("health", techId, function()
		return LookupTechData(kTechId.ARC, kTechDataMaxHealth, 0)
	end)

end

if kTechId.ARCDeploy then
	RegisterArcStance(kTechId.ARCDeploy,
		function() return kARCDeployedArmor or 0 end,
		function() return 0 end)
end

if kTechId.ARCUndeploy then
	RegisterArcStance(kTechId.ARCUndeploy,
		function() return kARCArmor or 0 end,
		function() return ARC and ARC.kMoveSpeed or 0 end)
end

IT.RegisterResolver("health", kTechId.BoneWall, function(techId)

	local base = LookupTechData(techId, kTechDataMaxHealth, 0)
	local perBioMass = kBoneWallHealthPerBioMass or 0
	local level = math.max(0, GetAlienBioMassLevel() - 1)

	return base + level * perBioMass

end)
