# Bleu's Improved Tooltips - icon atlas generator
#
# Produces source/ui/bleu_tooltip_icons.dds: a 320x64 sheet of five 64x64 cells, in this order:
#
#   0 research (hourglass)  1 cooldown (stopwatch)  2 speed, marine (chevron)
#   3 health (cross)        4 armour (shield)
#
# The cell order is what ImprovedTooltips_TooltipGUI.lua's kOwnIconCoords indexes into - change one
# and change the other.
#
# The glyphs are pure white with an alpha mask, because the mod tints them per team at runtime
# (IT.kMarineIconColor / IT.kAlienIconColor) via GUIItem:SetColor, which multiplies.
#
# Nothing here is drawn from scratch except the hourglass and stopwatch. The rest is vanilla art,
# resampled - the mod invents as little as possible:
#
#   health, armour -> vanilla's own selection-panel glyphs, resampled to match the other icons in
#                     size and made fully opaque. See the block that builds them for why they are
#                     baked in rather than drawn from the vanilla atlas at runtime.
#   marine speed   -> ui/marine_buildmenu_insight.dds row 2 column 4, mirrored to point right and
#                     lifted off its button plate.
#
# The one icon still used straight from vanilla at runtime, with no cell here, is ALIEN speed: the
# Celerity icon, index 64 in ui/buildmenu.dds (cell 4,5). It already points right, reads as motion,
# and CBM assigns the same index to SpurPassive.
#
# Requires nvcompress.exe and nvdecompress.exe, which ship with the game under utils/.

param(
    [string]$NS2 = "D:\SteamLibrary\steamapps\common\Natural Selection 2"
)

Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root "source\ui"
if (-not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Force -LiteralPath $outDir | Out-Null }
$png = Join-Path $env:TEMP "bleu_tooltip_icons.png"
$dds = Join-Path $outDir "bleu_tooltip_icons.dds"

$CELL = 64
$SS   = 4     # supersample factor; glyphs are drawn at 4x and downsampled for clean edges

$atlas = New-Object System.Drawing.Bitmap(($CELL*5), $CELL, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$ag = [System.Drawing.Graphics]::FromImage($atlas)
$ag.Clear([System.Drawing.Color]::Transparent)
$ag.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$ag.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

function New-Canvas {
    $b = New-Object System.Drawing.Bitmap(($CELL*$SS), ($CELL*$SS), [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($b)
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    return @($b, $g)
}
# Pt/Rct rather than P/R: R is a built-in alias for Invoke-History and silently eats the call.
function Pt($x,$y)       { New-Object System.Drawing.PointF(($x*$SS), ($y*$SS)) }
function Rct($x,$y,$w,$h){ New-Object System.Drawing.RectangleF(($x*$SS),($y*$SS),($w*$SS),($h*$SS)) }
function Commit($bmp, $slot) {
    $ag.DrawImage($bmp,
        (New-Object System.Drawing.Rectangle(($slot*$CELL), 0, $CELL, $CELL)),
        (New-Object System.Drawing.Rectangle(0, 0, ($CELL*$SS), ($CELL*$SS))),
        [System.Drawing.GraphicsUnit]::Pixel)
    $bmp.Dispose()
}
function RoundRect($x, $y, $w, $h, $r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r*2
    $p.AddArc(($x*$SS),            ($y*$SS),            ($d*$SS), ($d*$SS), 180, 90)
    $p.AddArc((($x+$w-$d)*$SS),    ($y*$SS),            ($d*$SS), ($d*$SS), 270, 90)
    $p.AddArc((($x+$w-$d)*$SS),    (($y+$h-$d)*$SS),    ($d*$SS), ($d*$SS),   0, 90)
    $p.AddArc(($x*$SS),            (($y+$h-$d)*$SS),    ($d*$SS), ($d*$SS),  90, 90)
    $p.CloseFigure()
    return $p
}

$white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)

# 0 - research time: hourglass. Rounded caps, concave glass drawn as an outline, upper bulb solid
# with sand, lower bulb holding a mound with a stream falling into it. The first version of this
# was a flat bowtie - two bars and two solid triangles - which read as too plain; the sand and the
# curved glass are what make it recognisable at the ~32px it actually renders at.
$r = New-Canvas; $b = $r[0]; $g = $r[1]
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.FillPath($white, (RoundRect 11 4 42 7 2.5))     # top cap
$g.FillPath($white, (RoundRect 11 53 42 7 2.5))    # bottom cap
$glassPen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, (3.5*$SS))
$glassPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round

$upper = New-Object System.Drawing.Drawing2D.GraphicsPath
$upper.AddLine((Pt 16 11), (Pt 48 11))
$upper.AddBezier((Pt 48 11), (Pt 47 22), (Pt 36 27), (Pt 32 31))
$upper.AddBezier((Pt 32 31), (Pt 28 27), (Pt 17 22), (Pt 16 11))
$g.FillPath($white, $upper)                        # bulb full of sand
$g.DrawPath($glassPen, $upper)

$lower = New-Object System.Drawing.Drawing2D.GraphicsPath
$lower.AddLine((Pt 16 53), (Pt 48 53))
$lower.AddBezier((Pt 48 53), (Pt 47 42), (Pt 36 37), (Pt 32 33))
$lower.AddBezier((Pt 32 33), (Pt 28 37), (Pt 17 42), (Pt 16 53))
$g.DrawPath($glassPen, $lower)

$mound = New-Object System.Drawing.Drawing2D.GraphicsPath
$mound.AddLine((Pt 19 51.5), (Pt 45 51.5))
$mound.AddBezier((Pt 45 51.5), (Pt 41 44.5), (Pt 35 42), (Pt 32 42))
$mound.AddBezier((Pt 32 42), (Pt 29 42), (Pt 23 44.5), (Pt 19 51.5))
$g.FillPath($white, $mound)
$g.FillRectangle($white, (Rct 31.25 30 1.5 11))    # falling stream
$g.Dispose(); Commit $b 0

# 1 - cooldown: stopwatch, ring plus stem plus two hands.
$r = New-Canvas; $b = $r[0]; $g = $r[1]
$ringPen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, (5*$SS))
$g.FillRectangle($white, (Rct 27 5 10 7))
$g.DrawEllipse($ringPen, (Rct 9 13 46 46))
$handPen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, (4.5*$SS))
$handPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$handPen.EndCap   = [System.Drawing.Drawing2D.LineCap]::Round
$g.DrawLine($handPen, (Pt 32 36), (Pt 32 22))
$g.DrawLine($handPen, (Pt 32 36), (Pt 43 36))
$g.Dispose(); Commit $b 1

# 2 - speed, marine: the double chevron from ui/marine_buildmenu_insight.dds row 2 column 4
# (12 columns of 80px, so x 240-320, y 80-160). Vanilla's points left, so it is mirrored.
#
# It sits on a rounded dark button plate, and unlike the buy-menu glyphs that plate is opaque - the
# alpha channel is no use for separating them. Luminance works instead: the plate is near-black, the
# chevron is bright cyan. So luminance becomes the alpha mask and the colour is flattened to white,
# which also lets the runtime team tint apply cleanly.
$nvdecompress = Join-Path $NS2 "utils\nvdecompress.exe"
if (-not (Test-Path -LiteralPath $nvdecompress)) { throw "nvdecompress.exe not found at $nvdecompress" }

$insightDds = Join-Path $NS2 "ns2\ui\marine_buildmenu_insight.dds"
$workDds = Join-Path $env:TEMP "bit_insight.dds"
$workTga = [System.IO.Path]::ChangeExtension($workDds, ".tga")
Copy-Item -LiteralPath $insightDds -Destination $workDds -Force
& $nvdecompress $workDds | Out-Null
if (-not (Test-Path -LiteralPath $workTga)) { throw "nvdecompress produced no TGA for $insightDds" }

$srcW = 960
$tga = [System.IO.File]::ReadAllBytes($workTga)
$chevron = New-Object System.Drawing.Bitmap(80, 80, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
for ($y = 0; $y -lt 80; $y++) {
    for ($x = 0; $x -lt 80; $x++) {
        # 18-byte TGA header, BGRA, top-left origin. Source cell starts at (240, 80).
        $i = 18 + ((($y + 80) * $srcW) + ($x + 240)) * 4
        $lum = [int](0.114*$tga[$i] + 0.587*$tga[$i+1] + 0.299*$tga[$i+2])
        # The plate floor sits around 25-40; lift off it so it goes fully clear.
        $a = [int]((($lum - 45) * 255.0) / (200 - 45))
        if ($a -lt 0) { $a = 0 }; if ($a -gt 255) { $a = 255 }
        $chevron.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($a, 255, 255, 255))
    }
}

$r = New-Canvas; $b = $r[0]; $g = $r[1]
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
# Negative width mirrors horizontally, turning vanilla's "<<" into ">>".
$pad = 6 * $SS
#
# Cropped to (14,10)-(74,70) rather than the full 80x80 cell. Luminance alone cannot remove the
# plate, because its rounded border is as bright as the chevron itself - but the border only touches
# the cell's outer edge. Measured glyph extent is x 20-70, y 12-66, so this crop clears the border
# on all four sides while keeping the whole glyph.
$g.DrawImage($chevron,
    (New-Object System.Drawing.Rectangle(($CELL*$SS - $pad), $pad, (-($CELL*$SS - 2*$pad)), ($CELL*$SS - 2*$pad))),
    (New-Object System.Drawing.Rectangle(14, 10, 60, 60)),
    [System.Drawing.GraphicsUnit]::Pixel)
$g.Dispose(); Commit $b 2
$chevron.Dispose()

# 3, 4 - health cross and armour shield, resampled from ui/alien_commander_textures.dds at
# (0,363)-(48,411) and (48,363)-(96,411). These are vanilla's own selection-panel glyphs, the ones
# that appear when you click a structure.
#
# They are baked into this sheet rather than drawn from the vanilla atlas at runtime for three
# reasons, all of which came out of testing:
#   * SIZE. In the source they occupy only ~29px of a 48px cell, so drawn at our icon size they came
#     out visibly smaller than the hourglass and stopwatch beside them. Cropping to the measured
#     glyph bounds and rescaling makes them match.
#   * ALPHA. The source tops out at alpha 233 (marine's copy only reaches 149), so they rendered
#     slightly translucent next to the fully opaque drawn glyphs. SetColor multiplies, so alpha
#     cannot be raised at runtime - it has to be fixed in the texture.
#   * COLOUR. Flattening to white means the runtime team tint lands on the exact target colour
#     instead of compounding with the art's own amber, which previously meant health could not be
#     tinted at all (multiply only darkens).
#
# The alien copy is the source for both teams because its alpha is the higher of the two; the glyph
# shapes are identical between the atlases, only the palette differs, and the palette is discarded.
$commanderDds = Join-Path $NS2 "ns2\ui\alien_commander_textures.dds"
$cmdWork = Join-Path $env:TEMP "bit_commander.dds"
$cmdTga = [System.IO.Path]::ChangeExtension($cmdWork, ".tga")
Copy-Item -LiteralPath $commanderDds -Destination $cmdWork -Force
& $nvdecompress $cmdWork | Out-Null
if (-not (Test-Path -LiteralPath $cmdTga)) { throw "nvdecompress produced no TGA for $commanderDds" }

$cmdBytes = [System.IO.File]::ReadAllBytes($cmdTga)
$cmdW = 1024
$kSourceMaxAlpha = 233   # measured; scaling by 255/this makes the glyph core fully opaque

# $bounds are the measured tight extents of the glyph inside its 48x48 cell.
function Add-CommanderGlyph($cellX, $bx1, $by1, $bx2, $by2, $slot) {

    $gw = $bx2 - $bx1 + 1
    $gh = $by2 - $by1 + 1
    $glyph = New-Object System.Drawing.Bitmap($gw, $gh, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

    for ($y = 0; $y -lt $gh; $y++) {
        for ($x = 0; $x -lt $gw; $x++) {
            $i = 18 + (((($y + $by1 + 363)) * $cmdW) + ($x + $bx1 + $cellX)) * 4
            $a = [int]($cmdBytes[$i+3] * 255.0 / $kSourceMaxAlpha)
            if ($a -gt 255) { $a = 255 }
            $glyph.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($a, 255, 255, 255))
        }
    }

    # Fit into the cell preserving aspect, with the same padding the other glyphs use.
    $pad = 6
    $box = $CELL - 2*$pad
    $scale = [Math]::Min($box / $gw, $box / $gh)
    $dw = [int]($gw * $scale); $dh = [int]($gh * $scale)
    $dx = $slot*$CELL + [int](($CELL - $dw) / 2)
    $dy = [int](($CELL - $dh) / 2)

    $ag.DrawImage($glyph,
        (New-Object System.Drawing.Rectangle($dx, $dy, $dw, $dh)),
        (New-Object System.Drawing.Rectangle(0, 0, $gw, $gh)),
        [System.Drawing.GraphicsUnit]::Pixel)
    $glyph.Dispose()
}

Add-CommanderGlyph 0  10 8  38 36  3    # health cross
Add-CommanderGlyph 48 11 11 37 36  4    # armour shield

$ag.Dispose()
$atlas.Save($png, [System.Drawing.Imaging.ImageFormat]::Png)
$atlas.Dispose()

# Uncompressed RGBA rather than DXT: the sheet is tiny (64KB plus mips) and DXT block artefacts
# are very visible on hard-edged white glyphs against full transparency.
$nvcompress = Join-Path $NS2 "utils\nvcompress.exe"
if (-not (Test-Path -LiteralPath $nvcompress)) { throw "nvcompress.exe not found at $nvcompress - pass -NS2 <install path>" }
& $nvcompress -rgb -alpha -highqual $png $dds
if ($LASTEXITCODE -ne 0) { throw "nvcompress failed with exit code $LASTEXITCODE" }

Write-Output "wrote $dds"
