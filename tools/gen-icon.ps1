# Genera el icono de DocxViewer.
#   - DocxViewer.ico + public\favicon.ico  -> PNG (nitido, para el shell y la web)
#   - build\app.ico                        -> DIB clasico (para incrustar con csc /win32icon)
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'
$root   = Split-Path -Parent $PSScriptRoot
$sizes  = @(16, 24, 32, 48, 64, 128, 256)

function New-IconBitmap([int]$s) {
    $bmp = New-Object System.Drawing.Bitmap($s, $s, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.Clear([System.Drawing.Color]::Transparent)

    $r = [float]($s * 0.22)
    $rect = New-Object System.Drawing.RectangleF(0, 0, $s, $s)
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc(0, 0, $r * 2, $r * 2, 180, 90)
    $path.AddArc($s - $r * 2, 0, $r * 2, $r * 2, 270, 90)
    $path.AddArc($s - $r * 2, $s - $r * 2, $r * 2, $r * 2, 0, 90)
    $path.AddArc(0, $s - $r * 2, $r * 2, $r * 2, 90, 90)
    $path.CloseFigure()

    $c1 = [System.Drawing.Color]::FromArgb(255, 52, 122, 198)
    $c2 = [System.Drawing.Color]::FromArgb(255, 21, 66, 120)
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $c1, $c2, 60.0)
    $g.FillPath($brush, $path)

    $px = [float]($s * 0.245); $py = [float]($s * 0.155)
    $pw = [float]($s * 0.51);  $ph = [float]($s * 0.69)
    $fold = [float]($s * 0.17)
    $leaf = New-Object System.Drawing.Drawing2D.GraphicsPath
    $leaf.AddPolygon(@(
        (New-Object System.Drawing.PointF($px, $py)),
        (New-Object System.Drawing.PointF(($px + $pw - $fold), $py)),
        (New-Object System.Drawing.PointF(($px + $pw), ($py + $fold))),
        (New-Object System.Drawing.PointF(($px + $pw), ($py + $ph))),
        (New-Object System.Drawing.PointF($px, ($py + $ph)))
    ))
    $white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $g.FillPath($white, $leaf)

    $corner = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 198, 216, 236))
    $g.FillPolygon($corner, @(
        (New-Object System.Drawing.PointF(($px + $pw - $fold), $py)),
        (New-Object System.Drawing.PointF(($px + $pw), ($py + $fold))),
        (New-Object System.Drawing.PointF(($px + $pw - $fold), ($py + $fold)))
    ))

    if ($s -ge 24) {
        $fs = [float]($s * 0.34)
        $font = New-Object System.Drawing.Font('Calibri', $fs, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
        $sf = New-Object System.Drawing.StringFormat
        $sf.Alignment = [System.Drawing.StringAlignment]::Center
        $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
        $area = New-Object System.Drawing.RectangleF($px, ($py + $ph * 0.20), $pw, ($ph * 0.70))
        $blue = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 31, 90, 160))
        $g.DrawString('W', $font, $blue, $area, $sf)
        $font.Dispose(); $blue.Dispose(); $sf.Dispose()
    }

    $g.Dispose()
    $brush.Dispose(); $white.Dispose(); $corner.Dispose(); $path.Dispose(); $leaf.Dispose()
    return $bmp
}

function Get-PngBytes([System.Drawing.Bitmap]$bmp) {
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $bytes = $ms.ToArray()
    $ms.Dispose()
    return ,$bytes
}

function Get-DibBytes([System.Drawing.Bitmap]$bmp) {
    $s = $bmp.Width
    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($ms)

    # BITMAPINFOHEADER
    $bw.Write([UInt32]40)
    $bw.Write([Int32]$s)
    $bw.Write([Int32]($s * 2))     # alto doble: XOR + AND
    $bw.Write([UInt16]1)
    $bw.Write([UInt16]32)
    $bw.Write([UInt32]0)           # BI_RGB
    $bw.Write([UInt32]($s * $s * 4))
    $bw.Write([Int32]0); $bw.Write([Int32]0)
    $bw.Write([UInt32]0); $bw.Write([UInt32]0)

    $rect = New-Object System.Drawing.Rectangle(0, 0, $s, $s)
    $data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $row = New-Object byte[] ($s * 4)
    for ($y = $s - 1; $y -ge 0; $y--) {
        [System.Runtime.InteropServices.Marshal]::Copy([IntPtr]($data.Scan0.ToInt64() + $y * $data.Stride), $row, 0, $s * 4)
        $bw.Write($row)
    }
    $bmp.UnlockBits($data)

    # mascara AND: 1bpp, filas alineadas a 4 bytes, todo 0 (opaco por alfa)
    $maskRow = [Math]::Floor(($s + 31) / 32) * 4
    $zero = New-Object byte[] $maskRow
    for ($y = 0; $y -lt $s; $y++) { $bw.Write($zero) }

    $bw.Flush()
    $bytes = $ms.ToArray()
    $bw.Dispose(); $ms.Dispose()
    return ,$bytes
}

function Write-Ico([string]$file, [scriptblock]$encoder) {
    $entries = New-Object System.Collections.ArrayList
    foreach ($s in $sizes) {
        $bmp = New-IconBitmap $s
        $bytes = & $encoder $bmp
        $bmp.Dispose()
        [void]$entries.Add(@{ Size = $s; Bytes = $bytes })
    }

    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($ms)
    $bw.Write([UInt16]0)
    $bw.Write([UInt16]1)
    $bw.Write([UInt16]$entries.Count)

    $offset = 6 + 16 * $entries.Count
    foreach ($e in $entries) {
        $dim = if ($e.Size -ge 256) { 0 } else { $e.Size }
        $bw.Write([Byte]$dim)
        $bw.Write([Byte]$dim)
        $bw.Write([Byte]0)
        $bw.Write([Byte]0)
        $bw.Write([UInt16]1)
        $bw.Write([UInt16]32)
        $bw.Write([UInt32]$e.Bytes.Length)
        $bw.Write([UInt32]$offset)
        $offset += $e.Bytes.Length
    }
    foreach ($e in $entries) { $bw.Write([Byte[]]$e.Bytes) }
    $bw.Flush()
    $dir = Split-Path -Parent $file
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllBytes($file, $ms.ToArray())
    $bw.Dispose(); $ms.Dispose()
    Write-Host ("OK  {0}  ({1} bytes)" -f $file, (Get-Item $file).Length)
}

Write-Ico (Join-Path $root 'DocxViewer.ico') { param($b) Get-PngBytes $b }
Write-Ico (Join-Path $root 'public\favicon.ico') { param($b) Get-PngBytes $b }
Write-Ico (Join-Path $root 'build\app.ico') { param($b) Get-DibBytes $b }
