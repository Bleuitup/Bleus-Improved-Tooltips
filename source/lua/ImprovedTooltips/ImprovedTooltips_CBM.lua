-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_CBM.lua
--
-- The one mod-specific module in this mod, and a deliberate exception to the rule that nothing here
-- knows about any particular mod.
--
-- Everything else works by asking TechData and the tech tree what they hold, which covers any mod
-- that adds tech the ordinary way. CBM does two things that cannot be reached that way:
--
--   1. It colour-codes its own tech. The biomass 5 research is marked out in purple, on the hive
--      model and in CBM's own UI, and matching that is a judgement about CBM's art rather than a
--      value that can be read from anywhere.
--
--   2. It makes structure movement speed depend on live state. A CBM Crag, Shade, Shift or Whip
--      does not hold a speed constant; GetMaxSpeed multiplies a base by 1.25 normally, by 0.5 when
--      electrified, and for the Fortress variants by a factor that rises with how long the
--      structure has stood on infestation. There is no single stored number to read, so without
--      this module the tooltip falls back to the raw base constant, which is neither the normal
--      speed nor the Fortress one.
--
-- It is contained: nothing outside this file mentions CBM, and if CBM is not loaded this module
-- registers nothing at all and vanilla and B2TP behave exactly as they did before it existed.

-- Deliberately does NOT Script.Load Values.lua: Values.lua loads this file at its own bottom, once
-- its registry functions exist, and loading it back would be a cycle. Nothing else loads this.
ImprovedTooltips = ImprovedTooltips or { }

local IT = ImprovedTooltips

------------------------------------------------------------------------------------------------
-- Detection
------------------------------------------------------------------------------------------------
--
-- By the tech it adds rather than by a name or a version. kTechId.FortressCrag exists only under
-- CBM, so its presence is the question actually being asked: "is the tech this module knows how to
-- describe here?" A renamed or forked CBM that still ships Fortress structures is still handled,
-- and a mod that happens to be called CBM but ships none of this is correctly left alone.

local function GetIsCBMLoaded()
	-- Through the safe lookup: under vanilla the name is absent, and indexing the enum with a name
	-- it does not hold raises rather than answering nil.
	return IT.GetTechIdByName("FortressCrag") ~= nil
end

------------------------------------------------------------------------------------------------
-- Speed
------------------------------------------------------------------------------------------------
--
-- CBM's accessors, reduced to the number worth printing. From Crag.lua, and Shade and Shift are
-- identical:
--
--     if self:GetTechId() == kTechId.FortressCrag then
--         return Crag.kMoveSpeed * (0.5 + 0.5 * self.infestationSpeedCharge / Crag.kMaxInfestationCharge)
--     end
--     if self.electrified then return Crag.kMoveSpeed * 0.5 end
--     return Crag.kMoveSpeed * 1.25
--
-- The charge climbs at 2 per second while the structure is on infestation and drains at 1 per
-- second off it, clamped to kMaxInfestationCharge, so a structure sitting on infestation is at full
-- charge. Alien structures are meant to be on infestation, so that is the speed quoted here - the
-- same convention as quoting an ARC's speed off infestation, which is where an ARC is meant to be.
--
-- Multipliers at full charge:
--
--   Crag / Shade / Shift          1.25        Fortress variants   1.0
--   Whip                          1.25        FortressWhip        1.25   (1.75 while frenzied)
--
-- A Fortress Crag, Shade or Shift is genuinely slower than the plain structure. A Fortress Whip on
-- full charge matches a plain Whip and beats it in frenzy, which is why its number does not move.
local kSpeedMultipliers =
{
	Crag         = 1.25,
	Shade        = 1.25,
	Shift        = 1.25,
	Whip         = 1.25,
	FortressCrag  = 1.0,
	FortressShade = 1.0,
	FortressShift = 1.0,
	FortressWhip  = 1.25,
}

-- Which class holds the base constant for each. The Fortress classes inherit from their plain
-- counterparts and add no speed of their own.
local kSpeedBaseClass =
{
	Crag = "Crag", FortressCrag = "Crag",
	Shade = "Shade", FortressShade = "Shade",
	Shift = "Shift", FortressShift = "Shift",
	Whip = "Whip", FortressWhip = "Whip",
}

-- CBM keeps the whip's base speed in a file-local, unreachable from here, but
-- Whip:OverrideRepositioningSpeed returns it and touches no instance state, so it can be called
-- statically. Crag, Shade and Shift expose theirs as a class field directly.
local function GetBaseSpeed(className)

	local class = _G[className]

	if type(class) ~= "table" then
		return 0
	end

	local speed = class.kMoveSpeed

	if type(speed) == "number" and speed > 0 then
		return speed
	end

	if type(class.OverrideRepositioningSpeed) == "function" then
		local ok, value = pcall(class.OverrideRepositioningSpeed)
		if ok and type(value) == "number" and value > 0 then
			return value
		end
	end

	return 0

end

local function RegisterSpeeds()

	for name, multiplier in pairs(kSpeedMultipliers) do

		local techId = IT.GetTechIdByName(name)

		if techId then
			-- Resolved inside the closure rather than now, so a mod loading after this one and
			-- changing a base constant is still reflected.
			IT.RegisterResolver("speed", techId, function()
				local base = GetBaseSpeed(kSpeedBaseClass[name])
				return base > 0 and base * multiplier or 0
			end)
		end

	end

end

------------------------------------------------------------------------------------------------
-- Biomass 5
------------------------------------------------------------------------------------------------
--
-- CBM's fourth +1 biomass research takes a hive to 5 and is gated behind kCBMaddon, the flag that
-- turns on CBM's extra content. It needs no support of its own: the hive HUD already draws one icon
-- per biomass research and reads its art through GetTextureCoordinatesForIcon, so CBM's own icon
-- for it appears with no help from here.
--
-- What does need saying is the colour. CBM marks the biomass 5 hive out in purple - a distinct
-- model material, hive_adv.material - and the icon should carry that so the HUD agrees with what
-- the player sees standing in the room. Every other biomass icon stays untinted, as vanilla draws
-- them.
local function RegisterBiomassFiveColor()

	local techId = IT.GetTechIdByName("ResearchBioMassFour")

	if not IT.kColorCBMBiomassFive or not techId then
		return
	end

	-- kCBMaddon is what actually enables the research (Hive:GetTechButtons offers it only when the
	-- flag is set), so an edition of CBM with the extra content switched off is left alone.
	if kCBMaddon ~= true then
		return
	end

	IT.RegisterIconColor(techId, IT.kCBMBiomassFiveColor)

end

------------------------------------------------------------------------------------------------

function IT.ApplyCBMCompat()

	if not IT.kEnableCBMCompat or not GetIsCBMLoaded() then
		return
	end

	RegisterSpeeds()
	RegisterBiomassFiveColor()

end
