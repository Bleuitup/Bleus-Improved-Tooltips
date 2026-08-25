# Bleu's Improved Tooltips - Workshop preview image generator
#
# Produces a 512x512 preview.jpg in the repo root. Steam wants a square preview and 512x512 is the
# size the other mods in this workspace settled on; do not upload a larger one.
#
# This is a functional placeholder built from the mod's own icon set - replace it with a real
# in-game screenshot of an improved tooltip once there is one worth showing.

Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$dds  = Join-Path $root "source\ui\bleu_tooltip_icons.dds"
$out  = Join-Path $root "preview.jpg"
$S = 512

if (-not (Test-Path -LiteralPath $dds)) { throw "run tools\build_icons.ps1 first - $dds not found" }

# Read the icon sheet straight out of the uncompressed-RGBA DDS: 128-byte header, then BGRA rows.
$b = [System.IO.File]::ReadAllBytes($dds)
$h = [BitConverter]::ToUInt32($b, 12)
$w = [BitConverter]::ToUInt32($b, 16)
$sheet = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
$data = $sheet.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
[System.Runtime.InteropServices.Marshal]::Copy($b, 128, $data.Scan0, $w*$h*4)
$sheet.UnlockBits($data)

$img = New-Object System.Drawing.Bitmap($S, $S, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$g = [System.Drawing.Graphics]::FromImage($img)
$g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

# Background: vertical fade, marine blue into alien orange, since the mod serves both commanders.
$grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Point(0,0)), (New-Object System.Drawing.Point(0,$S)),
    [System.Drawing.Color]::FromArgb(255,14,26,38), [System.Drawing.Color]::FromArgb(255,38,20,10))
$g.FillRectangle($grad, 0, 0, $S, $S)

# Icon row, tinted warm so it reads on either half.
$cm = New-Object System.Drawing.Imaging.ColorMatrix
$cm.Matrix00 = 1.0; $cm.Matrix11 = 0.84; $cm.Matrix22 = 0.52
$ia = New-Object System.Drawing.Imaging.ImageAttributes
$ia.SetColorMatrix($cm)
$cell = 96; $gap = 24
$totalW = 4*$cell + 3*$gap
$x0 = [int](($S - $totalW) / 2)
$y0 = 228
for ($i = 0; $i -lt 4; $i++) {
    $dst = New-Object System.Drawing.Rectangle(($x0 + $i*($cell+$gap)), $y0, $cell, $cell)
    $g.DrawImage($sheet, $dst, ($i*64), 0, 64, 64, [System.Drawing.GraphicsUnit]::Pixel, $ia)
}

function Draw-Centered($text, $fontName, $size, $style, $color, $y) {
    $font = New-Object System.Drawing.Font($fontName, $size, $style)
    $brush = New-Object System.Drawing.SolidBrush($color)
    $sz = $g.MeasureString($text, $font)
    $g.DrawString($text, $font, $brush, [single](($S - $sz.Width)/2), [single]$y)
    $font.Dispose(); $brush.Dispose()
}

Draw-Centered "BLEU'S"           "Segoe UI" 30 ([System.Drawing.FontStyle]::Bold)    ([System.Drawing.Color]::FromArgb(255,150,170,190))  74
Draw-Centered "IMPROVED"         "Segoe UI" 46 ([System.Drawing.FontStyle]::Bold)    ([System.Drawing.Color]::FromArgb(255,236,242,248)) 108
Draw-Centered "TOOLTIPS"         "Segoe UI" 46 ([System.Drawing.FontStyle]::Bold)    ([System.Drawing.Color]::FromArgb(255,236,242,248)) 156
Draw-Centered "health  -  armour  -  research  -  cooldown" "Segoe UI" 17 ([System.Drawing.FontStyle]::Regular) ([System.Drawing.Color]::FromArgb(255,214,170,110)) 330
Draw-Centered "on every commander tooltip"                  "Segoe UI" 17 ([System.Drawing.FontStyle]::Regular) ([System.Drawing.Color]::FromArgb(255,150,160,175)) 358
Draw-Centered "CLIENT SIDE  -  WORKS WITH OTHER MODS"       "Segoe UI" 14 ([System.Drawing.FontStyle]::Bold)    ([System.Drawing.Color]::FromArgb(255,120,132,146)) 434

$g.Dispose()

$enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$ps = New-Object System.Drawing.Imaging.EncoderParameters(1)
$ps.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, 92)
$img.Save($out, $enc, $ps)
$img.Dispose(); $sheet.Dispose()

Write-Output "wrote $out (512x512)"
