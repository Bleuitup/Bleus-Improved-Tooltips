-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_BarLayers.lua
--
-- Opacity for the Centralized HUD bars, by drawing the bar art several times over itself.
--
-- WHY LAYERS. A GUI item's color can only fade its texture, never make it more opaque than the art
-- itself, and vanilla's ui/centerhudbar.dds peaks at alpha 76/255, about 30%. The "HL2 Center Hudbar
-- Fix" Workshop mod gets its look by replacing that texture - which is the same file the ydy bars mod
-- replaces, so the two cannot both apply. Shipping an opaque copy of our own would have the same
-- problem: it would paint over whatever bar texture a player installed.
--
-- Stacking copies of whatever texture IS installed avoids both. n copies of art at alpha a composite
-- to 1 - (1 - a)^n: vanilla's 30% becomes 51% at two, 83% at five. Art that is already opaque, like
-- ydy's fill, stays exactly as it is, so an installed bar texture always supersedes vanilla's art.
--
-- The target opacity is continuous: whole copies, plus a partial alpha on the last one so that the
-- composite lands on the value asked for. At the floor - vanilla's own 30% - it is one copy at full
-- alpha, which is vanilla unchanged, and the layering is skipped altogether.

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Config.lua")

local IT = ImprovedTooltips

-- Peak alpha of vanilla's centerhudbar.dds fill, measured from the texture (76 of 255).
IT.kVanillaBarArtAlpha = 76 / 255

-- Returns the number of copies and the alpha factor for the last one.
function IT.GetBarLayering(opacity)

	local a = IT.kVanillaBarArtAlpha
	local maxLayers = math.max(1, IT.kCentralizedBarMaxLayers or 8)
	local target = math.max(a, math.min(1, opacity or 1))

	if target >= 0.999 then
		return maxLayers, 1
	end

	local count = math.ceil(math.log(1 - target) / math.log(1 - a) - 1e-6)
	count = math.max(1, math.min(maxLayers, count))

	-- Solve 1 - (1 - a)^(count - 1) * (1 - a * f) = target for f.
	local factor = (1 - (1 - target) / ((1 - a) ^ (count - 1))) / a
	factor = math.max(0, math.min(1, factor))

	return count, factor

end

-- True when the layering would reproduce vanilla exactly, so nothing needs creating.
function IT.GetBarLayeringIsVanilla(count, factor)
	return count <= 1 and factor >= 0.99
end

-- The composite alpha of `count` copies of something drawn at `baseAlpha`, last copy scaled by
-- `factor`. Used for the mod-drawn ydy style, which has no texture to stack.
function IT.GetLayeredAlpha(baseAlpha, count, factor)
	return 1 - (1 - baseAlpha) ^ (count - 1) * (1 - baseAlpha * factor)
end

-- `count` animated graphic items owned by `script`, so GUIAnimatedScript.Uninitialize destroys them
-- with the rest of the bars.
function IT.CreateBarCopies(script, count, texture)

	local copies = { }

	for i = 1, count do
		local copy = script:CreateAnimatedGraphicItem()
		copy:SetAnchor(GUIItem.Middle, GUIItem.Center)
		copy:SetLayer(kGUILayerPlayerHUD)
		copy:SetIsScaling(false)
		if texture then
			copy:SetTexture(texture)
		end
		copy:SetIsVisible(false)
		copies[i] = copy
	end

	return copies

end

local scratchColor = Color(1, 1, 1, 1)

-- Sets every copy's geometry, texture region, color and visibility; the last copy's alpha is scaled.
function IT.SetBarCopies(copies, position, size, texCoords, color, visible, lastAlphaFactor)

	local last = #copies

	for i = 1, last do

		local guiItem = copies[i].guiItem

		guiItem:SetSize(size)
		guiItem:SetPosition(position)

		if texCoords then
			guiItem:SetTexturePixelCoordinates(texCoords[1], texCoords[2], texCoords[3], texCoords[4])
		end

		if i == last and lastAlphaFactor < 1 then
			scratchColor.r, scratchColor.g, scratchColor.b, scratchColor.a = color.r, color.g, color.b, color.a * lastAlphaFactor
			guiItem:SetColor(scratchColor)
		else
			guiItem:SetColor(color)
		end

		guiItem:SetIsVisible(visible)

	end

end

function IT.HideBarCopies(copies)
	for i = 1, #copies do
		copies[i].guiItem:SetIsVisible(false)
	end
end

-- Copies a vanilla bar item onto its layers, reading back what vanilla just set. The texture region
-- comes from guiItem.texPixCoords, which GUIAnimatedItem:SetTexturePixelCoordinates records
-- (GUIAnimatedItem.lua:505-509) because the engine item has no getter for it.
function IT.MirrorBarItem(item, copies, lastAlphaFactor, forceHidden)

	local guiItem = item.guiItem
	local visible = guiItem:GetIsVisible() and not forceHidden

	IT.SetBarCopies(copies, guiItem:GetPosition(), guiItem:GetSize(), guiItem.texPixCoords, guiItem:GetColor(), visible, lastAlphaFactor)

	return visible

end
