# Bleu's Improved Tooltips - icon atlas generator
#
# Produces source/ui/bleu_tooltip_icons.dds: a 256x64 sheet of four 64x64 cells, in this order:
#
#   0 health (cross)   1 armor (shield)   2 research time (hourglass)   3 cooldown (stopwatch)
#
# The cell order is what ImprovedTooltips_TooltipGUI.lua's kIconCoords indexes into - change one
# and change the other.
#
# The glyphs are pure white with an alpha mask, because the mod tints them per team at runtime
# (IT.kMarineIconColor / IT.kAlienIconColor) via GUIItem:SetColor, which multiplies.
#
# Why drawn rather than lifted from vanilla: the health cross and armor shield DO exist in
# ui/alien_buymenu.dds at (854,318)-(887,351) and (887,318)-(920,351), and extracting them works
# (use the source alpha channel, not luminance - they sit on a rounded button plate whose alpha
# runs to about 65). But they are soft, gradient-shaded buy-menu art, and next to a crisp
# hourglass they read as a different icon set. Drawing all four keeps the row consistent, stays
# sharp at the ~32px the tooltip actually renders them at, and does not break if another mod
# replaces alien_buymenu.dds.
#
# Requires nvcompress.exe, which ships with the game under utils/.

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

$atlas = New-Object System.Drawing.Bitmap(($CELL*4), $CELL, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
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

$white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)

# 0 - health: a plain cross, matching the proportions of vanilla's buy-menu health glyph.
$r = New-Canvas; $b = $r[0]; $g = $r[1]
$arm = 12; $len = 46; $c = 32
$g.FillRectangle($white, (Rct ($c-$arm/2) ($c-$len/2) $arm $len))
$g.FillRectangle($white, (Rct ($c-$len/2) ($c-$arm/2) $len $arm))
$g.Dispose(); Commit $b 0

# 1 - armor: flat-topped shield tapering to a point, matching vanilla's shape.
$r = New-Canvas; $b = $r[0]; $g = $r[1]
$g.FillPolygon($white, @((Pt 11 11), (Pt 53 11), (Pt 53 34), (Pt 32 55), (Pt 11 34)))
$g.Dispose(); Commit $b 1

# 2 - research time: hourglass, two bars and two triangles meeting at the waist.
$r = New-Canvas; $b = $r[0]; $g = $r[1]
$g.FillRectangle($white, (Rct 13 6 38 6))
$g.FillRectangle($white, (Rct 13 52 38 6))
$g.FillPolygon($white, @((Pt 17 12), (Pt 47 12), (Pt 32 31)))
$g.FillPolygon($white, @((Pt 32 33), (Pt 47 52), (Pt 17 52)))
$g.Dispose(); Commit $b 2

# 3 - cooldown: stopwatch, ring plus stem plus two hands.
$r = New-Canvas; $b = $r[0]; $g = $r[1]
$ringPen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, (5*$SS))
$g.FillRectangle($white, (Rct 27 5 10 7))
$g.DrawEllipse($ringPen, (Rct 9 13 46 46))
$handPen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, (4.5*$SS))
$handPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$handPen.EndCap   = [System.Drawing.Drawing2D.LineCap]::Round
$g.DrawLine($handPen, (Pt 32 36), (Pt 32 22))
$g.DrawLine($handPen, (Pt 32 36), (Pt 43 36))
$g.Dispose(); Commit $b 3

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
