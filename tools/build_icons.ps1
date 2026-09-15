# Bleu's Improved Tooltips - icon atlas generator
#
# Produces source/ui/bleu_tooltip_icons.dds: a 448x64 sheet of seven 64x64 cells, in this order:
#
#   0 research (hourglass)  1 cooldown (stopwatch)  2 speed, marine (chevron)
#   3 health (cross)        4 armor (shield)
#   5 ready (tick)          6 not ready (cross)
#
# The cell order is what ImprovedTooltips_TooltipGUI.lua's kOwnIconCoords indexes into - change one
# and change the other.
#
# The glyphs are pure white with an alpha mask, because the mod tints them per team at runtime
# (IT.kMarineIconColor / IT.kAlienIconColor) via GUIItem:SetColor, which multiplies.
#
# The hourglass, stopwatch and marine speed chevrons are drawn here. The rest is vanilla art,
# resampled - the mod invents as little as possible:
#
#   health, armor -> vanilla's own selection-panel glyphs, resampled to match the other icons in
#                     size and made fully opaque. See the block that builds them for why they are
#                     baked in rather than drawn from the vanilla atlas at runtime.
#
# 1.06 GLYPH REFRESH, approved by the user on 2026-09-15 (worked out with ChatGPT Codex; the preview
# builders live in "Glyph Consistency Review" beside the repo). At the end of the build:
#   * the hourglass and stopwatch get a soft vanilla-style glow, then are scaled down uniformly - the
#     hourglass to 88%, the stopwatch to 93% - never stretched, details kept;
#   * the marine speed icon becomes flat double chevrons with the same glow, replacing the beveled
#     chevron that used to be lifted from ui/marine_buildmenu_insight.dds;
#   * cells 3-6 (health, armor, the ready pips) are verified pixel-identical before and after, and the
#     build stops if they are not. Health and armor are the benchmark and must never change.
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

$CELLS = 7

$atlas = New-Object System.Drawing.Bitmap(($CELL*$CELLS), $CELL, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
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

# Draws a canvas into its cell scaled so the glyph's own bounding box ends up $TARGET pixels across,
# centered. Used for the two glyphs drawn from scratch here.
#
# Why they need it and the vanilla art does not: the health cross and armor shield are baked at 39
# of the 64px cell and the tooltip samples a centered 48px window of it, so they render at 39/48 =
# 81% of the icon box. The hourglass and stopwatch are sampled over the WHOLE cell, so to match that
# 81% their glyph has to be 0.8125 * 64 = 52px. Drawn as-is they came out 57 tall, which is why they
# looked bigger than everything beside them.
#
# Measuring the result rather than hand-tuning every coordinate means the drawing code stays free to
# change without the sizes drifting apart again.
$TARGET = 52

function Measure-Glyph($bmp) {
    $w = $bmp.Width; $h = $bmp.Height
    $rect = New-Object System.Drawing.Rectangle 0,0,$w,$h
    $data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $bytes = New-Object byte[] ($w*$h*4)
    [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
    $bmp.UnlockBits($data)
    $minX=$w; $maxX=-1; $minY=$h; $maxY=-1
    for ($y=0; $y -lt $h; $y++) {
        $row = $y*$w*4
        for ($x=0; $x -lt $w; $x++) {
            if ($bytes[$row + $x*4 + 3] -gt 8) {
                if ($x -lt $minX){$minX=$x}; if ($x -gt $maxX){$maxX=$x}
                if ($y -lt $minY){$minY=$y}; if ($y -gt $maxY){$maxY=$y}
            }
        }
    }
    return @($minX, $minY, ($maxX-$minX+1), ($maxY-$minY+1))
}

function CommitFitted($bmp, $slot) {
    $m = Measure-Glyph $bmp
    if ($m[2] -le 0) { Commit $bmp $slot; return }
    $scale = $TARGET / [Math]::Max($m[2], $m[3])
    $dw = $m[2] * $scale; $dh = $m[3] * $scale
    $dst = New-Object System.Drawing.RectangleF (($slot*$CELL) + ($CELL-$dw)/2), (($CELL-$dh)/2), $dw, $dh
    $src = New-Object System.Drawing.RectangleF $m[0], $m[1], $m[2], $m[3]
    $ag.DrawImage($bmp, $dst, $src, [System.Drawing.GraphicsUnit]::Pixel)
    $bmp.Dispose()
}
$white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)

# 0 - research time: hourglass. Caps, concave glass as an outline, and sand that is PARTLY through:
# a band still in the upper bulb, a mound in the lower one, a stream between them. A full upper bulb
# reads as "not started" rather than "time passing", which is what it looked like in 1.02.
#
# Width is deliberately 1.02's. Widening it to square up the aspect was tried on 2026-09-08 and the
# user rejected it on sight - it reads as a stretched glyph, not a bigger one. The narrow proportion
# is the hourglass. Do not widen it again.
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

# The sand still to fall. It rests ON the neck, not under the cap: in a half-run hourglass the top
# bulb is empty above the sand line and full below it, so the fill is the LOWER part of that bulb
# and comes out as a wedge narrowing into the neck. Clipped as a region rather than drawn as a
# second path, so its edges follow the glass exactly however the curve is retuned.
$sand = New-Object System.Drawing.Region($upper)
$sand.Intersect((Rct 10 20.5 44 11))
$g.FillRegion($white, $sand)
$sand.Dispose()
$g.DrawPath($glassPen, $upper)

$lower = New-Object System.Drawing.Drawing2D.GraphicsPath
$lower.AddLine((Pt 16 53), (Pt 48 53))
$lower.AddBezier((Pt 48 53), (Pt 47 42), (Pt 36 37), (Pt 32 33))
$lower.AddBezier((Pt 32 33), (Pt 28 37), (Pt 17 42), (Pt 16 53))
$g.DrawPath($glassPen, $lower)

# A low mound, 3px tall. Until 2026-09-15 it rose to y 42, two thirds of the way to the neck: clean it
# read fine, but once the 1.06 glow was added it bled into the bottom cap and the lower bulb looked
# full. The user picked this height ("B") from a sheet of glowed candidates. The stream is lengthened
# to still land on it.
$mound = New-Object System.Drawing.Drawing2D.GraphicsPath
$mound.AddLine((Pt 22.5 51.5), (Pt 41.5 51.5))
$mound.AddBezier((Pt 41.5 51.5), (Pt 38.555 49.28), (Pt 34.185 48.5), (Pt 32 48.5))
$mound.AddBezier((Pt 32 48.5), (Pt 29.815 48.5), (Pt 25.445 49.28), (Pt 22.5 51.5))
$g.FillPath($white, $mound)
$g.FillRectangle($white, (Rct 31.25 30 1.5 17.5))    # falling stream
$g.Dispose(); CommitFitted $b 0

# 1 - cooldown: stopwatch. Ring, a crown on top, and a start button on the shoulder at 45 degrees.
# 1.02 drew a bare ring with a rectangular stem, which read as a wall clock rather than a stopwatch;
# the crown and the angled button are what name it, and they cost two shapes.
$r = New-Canvas; $b = $r[0]; $g = $r[1]
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

$ringPen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, (5*$SS))
$g.DrawEllipse($ringPen, (Rct 11 17 42 42))

# Crown: a stem off the top of the ring and a wider cap above it, the way a real one is knurled.
$g.FillPath($white, (RoundRect 28 11 8 8 1.5))
$g.FillPath($white, (RoundRect 25 5 14 7 2.5))

# Start button: a stub on the shoulder at 45 degrees, sitting entirely OUTSIDE the ring. The first
# attempt started it at radius 19 and it crossed the stroke, reading as a line drawn through the
# watch rather than a button on it.
#
# Geometry so it touches and does not cross: center (32, 38), ring radius 21 with a 5-wide stroke,
# so the outer edge is at radius 23.5 - at 45 degrees that is (32 + 23.5*cos45, 38 - 23.5*sin45) =
# (48.6, 21.4). A round cap extends half the pen width beyond the endpoint, so with a 6-wide pen the
# line would have to START 3 further out along the radius for its cap to land exactly on that edge.
# It starts fractionally inside that instead, at (50, 20), so the cap overlaps the stroke by about a
# pixel and the stub reads as attached rather than as a floating speck at 32px. It still stops well
# clear of the stroke's inner edge at radius 18.5, which is where crossing would start.
$btnPen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, (6*$SS))
$btnPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$btnPen.EndCap   = [System.Drawing.Drawing2D.LineCap]::Round
$g.DrawLine($btnPen, (Pt 50 20), (Pt 53.5 16.5))

$handPen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, (4.5*$SS))
$handPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$handPen.EndCap   = [System.Drawing.Drawing2D.LineCap]::Round
$g.DrawLine($handPen, (Pt 32 38), (Pt 32 26))      # 12 o'clock
$g.DrawLine($handPen, (Pt 32 38), (Pt 43 38))      # and 3 o'clock; the user settled this pairing
$g.Dispose(); CommitFitted $b 1

# 2 - speed, marine: drawn in the 1.06 glyph refresh at the end of this script. Up to 1.05 it was the
# beveled double chevron from ui/marine_buildmenu_insight.dds row 2 column 4, mirrored and lifted off
# its button plate by luminance; the user approved a leaner flat version on 2026-09-15.
$nvdecompress = Join-Path $NS2 "utils\nvdecompress.exe"
if (-not (Test-Path -LiteralPath $nvdecompress)) { throw "nvdecompress.exe not found at $nvdecompress" }

# 3, 4 - health cross and armor shield, resampled from ui/alien_commander_textures.dds at
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
#   * COLOR. Flattening to white means the runtime team tint lands on the exact target color
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

    # Fit into the cell at VANILLA's proportion, not the mod's.
    #
    # Vanilla draws these glyphs at ~29px inside a 48x48 cell, about 61% of it. The mod's own glyphs
    # fill ~81%. Baking at 81% made the tooltips right but blew up vanilla's selection panel, which
    # draws the same cell into an item size it sets itself - same box, bigger glyph inside it.
    #
    # So they are baked at vanilla's 61% and the TOOLTIP magnifies instead, by sampling a smaller
    # centered window of the cell (see kOwnIconCoords). Sampling inward cannot bleed into the
    # neighboring cells, whereas sampling outward to shrink them would.
    $box = 39                       # 39/64 = 61%, matching vanilla; a 48px window gives 39/48 = 81%
    $pad = ($CELL - $box) / 2
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
Add-CommanderGlyph 48 11 11 37 36  4    # armor shield

# ---------------------------------------------------------------------------------------------
# Slots 5 and 6: the tournament mode ready pip - a tick, and a cross.
#
# Unlike every other cell here these are drawn IN COLOR rather than white. The rest are baked white
# and opaque so SetColor can tint them per team; green and red are semantic, never team colors, so
# there is nothing to tint and a two-item shape-plus-glyph construction would be wasted on a pip
# roughly sixteen pixels across.
#
# Shape carries the meaning and color only reinforces it: a tick against a cross survives red-green
# color blindness, a green square against a red one does not.
#
# The rounded plate is deliberately not the full cell. These sit in the corner of the scoreboard's
# team skill badge, so the glyph needs to read at a third of that badge's height.
# ---------------------------------------------------------------------------------------------

function Add-ReadyPip($slot, $fill, $tick) {

    $c = New-Canvas
    $bmp = $c[0]
    $g = $c[1]

    $plate = RoundRect 6 6 52 52 14
    $brush = New-Object System.Drawing.SolidBrush($fill)
    $g.FillPath($brush, $plate)
    $brush.Dispose()
    $plate.Dispose()

    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, (7 * $SS))
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap   = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round

    if ($tick) {
        # Steep upstroke, so it never reads as the speed chevron in slot 2.
        $g.DrawLines($pen, @( (Pt 18 33), (Pt 28 43), (Pt 46 21) ))
    } else {
        $g.DrawLine($pen, (Pt 21 21), (Pt 43 43))
        $g.DrawLine($pen, (Pt 43 21), (Pt 21 43))
    }

    $pen.Dispose()
    $g.Dispose()
    Commit $bmp $slot

}

# Green and red chosen for contrast against the dark scoreboard rather than sampled from vanilla,
# which has no equivalent pair.
Add-ReadyPip 5 ([System.Drawing.Color]::FromArgb(255, 46, 168, 74))  $true    # ready, tick
Add-ReadyPip 6 ([System.Drawing.Color]::FromArgb(255, 208, 48, 48))  $false   # not ready, cross

$ag.Dispose()

# ---------------------------------------------------------------------------------------------
# 1.06 glyph refresh: glow, uniform resize, flat marine chevrons.
#
# Reproduces the preview the user approved on 2026-09-15 ("Glyph Consistency Review\
# build_preview.ps1" and "build_resized_preview.ps1") exactly, step for step, so the atlas this
# writes matches "candidate-resized-flat-speed.png".
#
# Glow recipe, per 64px cell, from the alpha mask only (color stays white for the runtime tint):
#   core  = 0.4 * mask + 0.6 * GaussianBlur(mask, 0.70)
#   halo  = GaussianBlur(mask, 2.5)
#   alpha = core + 0.85 * halo * (1 - core)
# with the outermost texel ring forced clear so the halo never bleeds into a neighboring cell.
#
# Order matters and follows the preview: the hourglass and stopwatch are glowed at full size and the
# result scaled; the chevrons are drawn, scaled into their cell, and glowed there.
#
# Judge optical size through the tooltip's sampling windows, not raw cell bounds: health and armor are
# sampled through a 48px window, the custom glyphs through the full 64px cell (kOwnIconCoords).
# ---------------------------------------------------------------------------------------------

Add-Type -TypeDefinition @'
using System;
using System.Drawing;
public static class BitGlyphGlow {
    static double[] Blur(double[] a, int w, int h, double sigma) {
        int r = (int)Math.Ceiling(3 * sigma);
        var k = new double[2 * r + 1]; double sum = 0;
        for (int i = -r; i <= r; i++) { k[i + r] = Math.Exp(-i * i / (2 * sigma * sigma)); sum += k[i + r]; }
        for (int i = 0; i < k.Length; i++) k[i] /= sum;
        var tmp = new double[a.Length]; var dst = new double[a.Length];
        for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) for (int q = -r; q <= r; q++) { int xx = x + q; if (xx >= 0 && xx < w) tmp[y * w + x] += a[y * w + xx] * k[q + r]; }
        for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) for (int q = -r; q <= r; q++) { int yy = y + q; if (yy >= 0 && yy < h) dst[y * w + x] += tmp[yy * w + x] * k[q + r]; }
        return dst;
    }
    // Glows one 64px cell of the atlas in place, starting at cellX.
    public static void Apply(Bitmap atlas, int cellX, double softness, double sigma, double glow, double glowSigma) {
        var mask = new double[64 * 64];
        for (int y = 0; y < 64; y++) for (int x = 0; x < 64; x++) mask[y * 64 + x] = atlas.GetPixel(cellX + x, y).A / 255.0;
        var soft = Blur(mask, 64, 64, sigma); var halo = Blur(mask, 64, 64, glowSigma);
        for (int y = 0; y < 64; y++) for (int x = 0; x < 64; x++) {
            int i = y * 64 + x;
            double core = (1 - softness) * mask[i] + softness * soft[i];
            double a = core + glow * halo[i] * (1 - core);
            if (x == 0 || x == 63 || y == 0 || y == 63) a = 0;
            atlas.SetPixel(cellX + x, y, Color.FromArgb((int)Math.Round(Math.Max(0, Math.Min(1, a)) * 255), 255, 255, 255));
        }
    }
    // Throws if any pixel from firstX onward differs between the two atlases.
    public static void CheckProtected(Bitmap before, Bitmap after, int firstX) {
        for (int y = 0; y < before.Height; y++) for (int x = firstX; x < before.Width; x++)
            if (before.GetPixel(x, y).ToArgb() != after.GetPixel(x, y).ToArgb())
                throw new Exception("Protected atlas pixel changed at " + x + "," + y);
    }
}
'@ -ReferencedAssemblies @([System.Drawing.Bitmap].Assembly.Location, [System.Drawing.Color].Assembly.Location)

$kGlowSoftness = 0.60; $kGlowSigma = 0.70; $kGlowStrength = 0.85; $kGlowHaloSigma = 2.5
$kProtectedFromX = 3 * $CELL      # cells 3-6: health, armor, ready, not ready

$fullRect = New-Object System.Drawing.Rectangle 0, 0, $atlas.Width, $atlas.Height
$beforeRefresh = $atlas.Clone($fullRect, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

# Hourglass and stopwatch: glow at full size on a copy, then draw that copy back scaled.
$glowed = $atlas.Clone($fullRect, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
[BitGlyphGlow]::Apply($glowed, 0,       $kGlowSoftness, $kGlowSigma, $kGlowStrength, $kGlowHaloSigma)
[BitGlyphGlow]::Apply($glowed, $CELL,   $kGlowSoftness, $kGlowSigma, $kGlowStrength, $kGlowHaloSigma)

$rg = [System.Drawing.Graphics]::FromImage($atlas)
$rg.CompositingMode   = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
$rg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$rg.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

# Uniform, never per axis: widening the hourglass was rejected on sight on 2026-09-08.
$kTimeGlyphScales = @(0.88, 0.93)   # hourglass 12% smaller, stopwatch 7% smaller
for ($slot = 0; $slot -lt 2; $slot++) {
    $rg.FillRectangle([System.Drawing.Brushes]::Transparent, ($slot * $CELL), 0, $CELL, $CELL)
    $side = [float]($CELL * $kTimeGlyphScales[$slot]); $inset = [float](($CELL - $side) / 2)
    $rg.DrawImage($glowed,
        (New-Object System.Drawing.RectangleF (($slot * $CELL) + $inset), $inset, $side, $side),
        (New-Object System.Drawing.RectangleF ($slot * $CELL), 0, $CELL, $CELL),
        [System.Drawing.GraphicsUnit]::Pixel)
}
$glowed.Dispose()

# Marine speed: flat double chevrons, constant-width strokes, no bevel. 64px coordinates, drawn at 4x.
$marine = New-Object System.Drawing.Bitmap (64 * $SS), (64 * $SS), ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$mg = [System.Drawing.Graphics]::FromImage($marine)
$mg.Clear([System.Drawing.Color]::Transparent)
$mg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$mg.ScaleTransform($SS, $SS)
$chevronPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), 5.2
$chevronPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Flat
$chevronPen.EndCap   = [System.Drawing.Drawing2D.LineCap]::Flat
$chevronPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
foreach ($cx in @(18, 32)) {
    $mg.DrawLines($chevronPen, [System.Drawing.PointF[]]@(
        (New-Object System.Drawing.PointF $cx, 13),
        (New-Object System.Drawing.PointF ($cx + 10), 32),
        (New-Object System.Drawing.PointF $cx, 51)))
}
$chevronPen.Dispose(); $mg.Dispose()

$rg.FillRectangle([System.Drawing.Brushes]::Transparent, (2 * $CELL), 0, $CELL, $CELL)
$rg.DrawImage($marine, (New-Object System.Drawing.Rectangle (2 * $CELL), 0, $CELL, $CELL), 0, 0, (64 * $SS), (64 * $SS), [System.Drawing.GraphicsUnit]::Pixel)
$marine.Dispose(); $rg.Dispose()

[BitGlyphGlow]::Apply($atlas, (2 * $CELL), $kGlowSoftness, $kGlowSigma, $kGlowStrength, $kGlowHaloSigma)

[BitGlyphGlow]::CheckProtected($beforeRefresh, $atlas, $kProtectedFromX)
$beforeRefresh.Dispose()

$atlas.Save($png, [System.Drawing.Imaging.ImageFormat]::Png)
$atlas.Dispose()

# Uncompressed RGBA rather than DXT: the sheet is tiny (64KB plus mips) and DXT block artifacts
# are very visible on hard-edged white glyphs against full transparency.
$nvcompress = Join-Path $NS2 "utils\nvcompress.exe"
if (-not (Test-Path -LiteralPath $nvcompress)) { throw "nvcompress.exe not found at $nvcompress - pass -NS2 <install path>" }
& $nvcompress -rgb -alpha -highqual $png $dds
if ($LASTEXITCODE -ne 0) { throw "nvcompress failed with exit code $LASTEXITCODE" }

Write-Output "wrote $dds"
