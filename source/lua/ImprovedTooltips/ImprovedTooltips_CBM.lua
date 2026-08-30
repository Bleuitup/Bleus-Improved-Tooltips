-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_CBM.lua
--
-- The one mod-specific module in this mod, and a deliberate exception to the rule that nothing here
-- knows about any particular mod.
--
-- Everything else works by asking TechData and the tech tree what they hold, which covers any mod
-- that adds tech the ordinary way. One thing cannot be reached that way: CBM colour-codes its own
-- tech, marking the biomass 5 research out in purple on the hive model and in its own UI, and
-- matching that is a judgement about CBM's art rather than a value readable from anywhere.
--
-- It once carried speed corrections for CBM's Crag, Shade, Shift, Whip and Fortress structures,
-- which compute movement from live infestation charge rather than storing a constant. Those were
-- dropped for 1.0: the mod now shows the plain class speed everywhere, and getting CBM's live
-- figures right is not worth mod-specific arithmetic here.
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

	RegisterBiomassFiveColor()

end
