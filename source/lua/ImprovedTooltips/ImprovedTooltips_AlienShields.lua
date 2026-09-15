-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_AlienShields.lua
--
-- Reads an alien's three shields and turns them into bar segments, for the shield bar beside the
-- Centralized HUD bars (ImprovedTooltips_AdvancedHUDBars.lua).
--
-- HOW VANILLA DOES IT. PlayerUI_GetMucousShieldHP (Alien_Client.lua:329) adds up three sources, each
-- rounded up, and the maxima of only the sources currently above zero:
--
--   mucous      MucousableMixin     GetMuscousShieldAmount (sic) / GetMaxShieldAmount
--   babblers    BabblerClingMixin   GetBabblerShieldAmount / GetMaxBabblerShieldAmount
--   vampirism   ShieldableMixin     GetOverShieldAmount / GetMaxOverShieldAmount - the "overshield",
--                                   leeched health added per hit (DamageTypes.lua:158) and capped at
--                                   1.5 x max health x the class's vampirism scalar x 3 (three shells)
--
-- The default HUD draws one ring at sum / sum-of-maxima - relative, full when every active shield is
-- at its own cap - with one combined green number. With Centralized or NS1 bars the ring is hidden
-- (GUIAlienHUD.lua:286, :734) and only the corner number remains. CBM dev keeps the same.
--
-- WHAT THIS ADDS. The same three values, but kept apart so each is its own colored segment, in the
-- order damage eats them (DamageTypes.lua:303-318: mucous first, then the overshield, then babblers).
-- Bottom to top that is babblers, vampirism, mucous, so the segment nearest the top empties first.

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Config.lua")

local IT = ImprovedTooltips

-- Bottom to top.
IT.kAlienShieldOrder = { "babbler", "vampirism", "mucous" }

IT.kShieldScaleRelative = 0
IT.kShieldScaleAbsolute = 1

-- Methods are called only if present, and under pcall. GetMaxOverShieldAmount indexes a table of
-- class scalars that has no Embryo entry and does nil * 3, so it must never be allowed to throw
-- into the HUD.
local function SafeNumber(object, methodName)

	local method = object[methodName]
	if type(method) ~= "function" then
		return 0
	end

	local ok, value = pcall(method, object)
	return (ok and type(value) == "number") and value or 0

end

-- Fills `out` in place, to avoid building tables every frame:
--   out.current[source], out.max[source], out.total
-- Current values are rounded up and a maximum is only read for a source above zero, as vanilla does.
function IT.ReadAlienShields(player, out)

	local current, max = out.current, out.max

	current.mucous = math.ceil(SafeNumber(player, "GetMuscousShieldAmount"))
	max.mucous = current.mucous > 0 and SafeNumber(player, "GetMaxShieldAmount") or 0

	current.babbler = math.ceil(SafeNumber(player, "GetBabblerShieldAmount"))
	max.babbler = current.babbler > 0 and SafeNumber(player, "GetMaxBabblerShieldAmount") or 0

	if HasMixin(player, "Shieldable") then
		current.vampirism = math.ceil(SafeNumber(player, "GetOverShieldAmount"))
		max.vampirism = current.vampirism > 0 and SafeNumber(player, "GetMaxOverShieldAmount") or 0
	else
		current.vampirism = 0
		max.vampirism = 0
	end

	out.total = current.mucous + current.babbler + current.vampirism

	return out

end

function IT.NewAlienShieldReading()
	return { current = { }, max = { }, total = 0 }
end

-- Fills `segments[source] = { from, to }` as fractions of the bar, bottom-up, and returns the filled
-- fraction. Sources at zero get from == to.
--
--   Relative: each segment is its current value over the sum of the active sources' maxima, as the
--             vanilla ring measures. A full bar means every active shield is at its cap.
--   Absolute: each segment is its current value over max health + max armor in health points, the
--             same scale the Centralized health bar uses (GUIAdvancedHUDBars.lua:265-270).
function IT.GetAlienShieldSegments(player, reading, scaleMode, segments)

	local denominator

	if scaleMode == IT.kShieldScaleAbsolute then
		local maxHealth = SafeNumber(player, "GetMaxHealth")
		local maxArmor = SafeNumber(player, "GetMaxArmor") * (kHealthPointsPerArmor or 2)
		denominator = maxHealth + maxArmor
	else
		denominator = reading.max.mucous + reading.max.babbler + reading.max.vampirism
	end

	if denominator <= 0 then
		denominator = math.max(1, reading.total)
	end

	local at = 0

	for _, source in ipairs(IT.kAlienShieldOrder) do

		local segment = segments[source] or { 0, 0 }
		segments[source] = segment

		local length = math.max(0, reading.current[source]) / denominator
		length = math.min(length, 1 - at)

		segment[1] = at
		segment[2] = at + length
		at = at + length

	end

	return at

end
