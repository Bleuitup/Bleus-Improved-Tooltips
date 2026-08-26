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

# 2 - research time: hourglass. Rounded caps, concave glass drawn as an outline, upper bulb solid
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
