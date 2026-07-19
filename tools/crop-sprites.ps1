# Processes every PNG in Assets/generated:
#   - "*_grid.png" files (one per character, an 8-pose grid: 4 cols x 2 rows)
#     get their magenta background keyed out, each of the 8 poses isolated as
#     its own connected blob, sorted into reading order (row-major), cropped,
#     and normalized onto a shared per-character canvas (bottom-center
#     anchored, so the character's feet stay at a consistent position across
#     frames instead of jittering between poses of different heights).
#     Output: "<name-without-_grid>_frame1.png" .. "_frame8.png".
#   - Every other PNG (props: the salsa obstacle, the lettuce ingredient) is
#     treated as a single still image: background keyed out, kept only the
#     largest connected blob (discarding small artifacts like a watermark),
#     cropped to that blob's bounding box, and overwritten in place.
#
# Chroma key: the generator prompt asks for solid magenta (#FF00FF), but the
# model still draws a soft drop shadow under each character despite being
# told not to. That shadow is just the background color multiplicatively
# darkened -- same hue and saturation, lower brightness -- which is exactly
# what you'd expect from a translucent black shadow layered over a flat
# color. So instead of matching one fixed RGB value, we key on hue+saturation
# (sampled from a corner pixel of each image, in case the exact magenta
# shade drifts between generations) and ignore brightness entirely. That
# catches the whole background-to-shadow gradient in one pass, while still
# leaving character colors alone (yellow/brown/red/green are all far enough
# away in hue, and outline/highlight pixels have too-low saturation to match).

Add-Type -AssemblyName System.Drawing

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$dir = Join-Path $projectRoot "Assets\generated"
$padding = 10
$hueTolerance = 30       # degrees
$minSaturation = 0.35    # below this, treat as not-background regardless of hue (whites/blacks/outlines)
$minComponentFraction = 0.005  # ignore blobs smaller than this fraction of the image area (noise/watermarks)

function Get-HueSaturation([byte]$r, [byte]$g, [byte]$b) {
    $rn = $r / 255.0; $gn = $g / 255.0; $bn = $b / 255.0
    $max = [Math]::Max($rn, [Math]::Max($gn, $bn))
    $min = [Math]::Min($rn, [Math]::Min($gn, $bn))
    $delta = $max - $min
    if ($max -le 0) { return @(0, 0) }
    $sat = $delta / $max
    if ($delta -eq 0) {
        $hue = 0
    } elseif ($max -eq $rn) {
        $hue = 60 * (($gn - $bn) / $delta)
    } elseif ($max -eq $gn) {
        $hue = 60 * ((($bn - $rn) / $delta) + 2)
    } else {
        $hue = 60 * ((($rn - $gn) / $delta) + 4)
    }
    if ($hue -lt 0) { $hue += 360 }
    return @($hue, $sat)
}

function Get-HueDistance([double]$a, [double]$b) {
    $d = [Math]::Abs($a - $b) % 360
    if ($d -gt 180) { $d = 360 - $d }
    return $d
}

function Get-ReferenceHue([byte[]]$bytes, [int]$stride) {
    # Corner pixels are always background, never character or shadow.
    $r = $bytes[2]; $g = $bytes[1]; $b = $bytes[0]
    return (Get-HueSaturation $r $g $b)[0]
}

function Test-IsBackgroundPixel([byte]$r, [byte]$g, [byte]$b, [double]$refHue) {
    $hs = Get-HueSaturation $r $g $b
    if ($hs[1] -lt $minSaturation) { return $false }
    return (Get-HueDistance $hs[0] $refHue) -le $hueTolerance
}

function Remove-MagentaBackground([byte[]]$bytes, [int]$w, [int]$h, [int]$stride, [double]$refHue) {
    $visited = New-Object bool[] ($w * $h)
    $stack = New-Object System.Collections.Generic.Stack[int]

    for ($x = 0; $x -lt $w; $x++) {
        $stack.Push($x)
        $stack.Push(($h - 1) * $w + $x)
    }
    for ($y = 0; $y -lt $h; $y++) {
        $stack.Push($y * $w)
        $stack.Push($y * $w + ($w - 1))
    }

    while ($stack.Count -gt 0) {
        $idx = $stack.Pop()
        if ($visited[$idx]) { continue }
        $visited[$idx] = $true

        $px = $idx % $w
        $py = [Math]::Floor($idx / $w)
        $off = $py * $stride + $px * 4
        $b = $bytes[$off]; $g = $bytes[$off + 1]; $r = $bytes[$off + 2]

        if (-not (Test-IsBackgroundPixel $r $g $b $refHue)) { continue }
        $bytes[$off + 3] = 0

        if ($px -gt 0) { $n = $idx - 1; if (-not $visited[$n]) { $stack.Push($n) } }
        if ($px -lt $w - 1) { $n = $idx + 1; if (-not $visited[$n]) { $stack.Push($n) } }
        if ($py -gt 0) { $n = $idx - $w; if (-not $visited[$n]) { $stack.Push($n) } }
        if ($py -lt $h - 1) { $n = $idx + $w; if (-not $visited[$n]) { $stack.Push($n) } }
    }
}

function Get-ConnectedComponents([byte[]]$bytes, [int]$w, [int]$h, [int]$stride) {
    $label = New-Object int[] ($w * $h)
    for ($i = 0; $i -lt $label.Length; $i++) { $label[$i] = -1 }
    $sizes = New-Object System.Collections.Generic.List[int]
    $ccStack = New-Object System.Collections.Generic.Stack[int]
    $nextLabel = 0

    for ($start = 0; $start -lt ($w * $h); $start++) {
        if ($label[$start] -ge 0) { continue }
        $sx = $start % $w
        $sy = [Math]::Floor($start / $w)
        $sOff = $sy * $stride + $sx * 4
        if ($bytes[$sOff + 3] -le 10) { continue }

        $size = 0
        $ccStack.Push($start)
        $label[$start] = $nextLabel
        while ($ccStack.Count -gt 0) {
            $idx = $ccStack.Pop()
            $size++
            $px = $idx % $w
            $py = [Math]::Floor($idx / $w)

            $neighbors = @()
            if ($px -gt 0) { $neighbors += ($idx - 1) }
            if ($px -lt $w - 1) { $neighbors += ($idx + 1) }
            if ($py -gt 0) { $neighbors += ($idx - $w) }
            if ($py -lt $h - 1) { $neighbors += ($idx + $w) }

            foreach ($n in $neighbors) {
                if ($label[$n] -ge 0) { continue }
                $nx = $n % $w
                $ny = [Math]::Floor($n / $w)
                $nOff = $ny * $stride + $nx * 4
                if ($bytes[$nOff + 3] -gt 10) {
                    $label[$n] = $nextLabel
                    $ccStack.Push($n)
                }
            }
        }
        $sizes.Add($size)
        $nextLabel++
    }

    return @{ Label = $label; Sizes = $sizes }
}

function Get-ComponentBoxes([int[]]$label, [int]$w, [int]$h, [System.Collections.Generic.List[int]]$sizes, [double]$minArea) {
    $boxes = @{}
    for ($lbl = 0; $lbl -lt $sizes.Count; $lbl++) {
        if ($sizes[$lbl] -ge $minArea) {
            $boxes[$lbl] = @{ MinX = $w; MinY = $h; MaxX = -1; MaxY = -1 }
        }
    }
    for ($y = 0; $y -lt $h; $y++) {
        for ($x = 0; $x -lt $w; $x++) {
            $lbl = $label[$y * $w + $x]
            if ($lbl -ge 0 -and $boxes.ContainsKey($lbl)) {
                $box = $boxes[$lbl]
                if ($x -lt $box.MinX) { $box.MinX = $x }
                if ($x -gt $box.MaxX) { $box.MaxX = $x }
                if ($y -lt $box.MinY) { $box.MinY = $y }
                if ($y -gt $box.MaxY) { $box.MaxY = $y }
            }
        }
    }
    return $boxes
}

Get-ChildItem "$dir\*.png" | ForEach-Object {
    $path = $_.FullName
    $isGrid = $_.Name -like "*_grid.png"

    $fileBytes = [System.IO.File]::ReadAllBytes($path)
    $ms = New-Object System.IO.MemoryStream(, $fileBytes)
    $bmp = [System.Drawing.Bitmap]::FromStream($ms)
    $w = $bmp.Width
    $h = $bmp.Height

    $rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
    $data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $stride = $data.Stride
    $bytes = New-Object byte[] ($stride * $h)
    [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)

    $refHue = Get-ReferenceHue $bytes $stride
    Remove-MagentaBackground $bytes $w $h $stride $refHue
    $cc = Get-ConnectedComponents $bytes $w $h $stride
    $minArea = $w * $h * $minComponentFraction
    $boxes = Get-ComponentBoxes $cc.Label $w $h $cc.Sizes $minArea

    $bmp.Dispose(); $ms.Dispose()

    if ($boxes.Count -eq 0) {
        Write-Warning "$($_.Name): nothing left after background removal, skipping"
        return
    }

    if (-not $isGrid) {
        # Single prop image: keep only the largest blob.
        $largestLabel = -1; $largestSize = -1
        foreach ($lbl in $boxes.Keys) {
            if ($cc.Sizes[$lbl] -gt $largestSize) { $largestSize = $cc.Sizes[$lbl]; $largestLabel = $lbl }
        }
        $box = $boxes[$largestLabel]
        for ($y = 0; $y -lt $h; $y++) {
            $rowOff = $y * $stride
            for ($x = 0; $x -lt $w; $x++) {
                $idx = $y * $w + $x
                if ($cc.Label[$idx] -ne $largestLabel -and $cc.Label[$idx] -ge 0) {
                    $bytes[$rowOff + $x * 4 + 3] = 0
                }
            }
        }
        $minX = [Math]::Max(0, $box.MinX - $padding)
        $minY = [Math]::Max(0, $box.MinY - $padding)
        $maxX = [Math]::Min($w - 1, $box.MaxX + $padding)
        $maxY = [Math]::Min($h - 1, $box.MaxY + $padding)

        $rebuilt = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $rdata = $rebuilt.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        [System.Runtime.InteropServices.Marshal]::Copy($bytes, 0, $rdata.Scan0, $bytes.Length)
        $rebuilt.UnlockBits($rdata)

        $cropRect = New-Object System.Drawing.Rectangle $minX, $minY, ($maxX - $minX + 1), ($maxY - $minY + 1)
        $cropped = $rebuilt.Clone($cropRect, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $rebuilt.Dispose()
        $cropped.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
        $cropped.Dispose()
        Write-Host "$($_.Name): cropped to $($cropRect.Width) x $($cropRect.Height)"
        return
    }

    # Grid image: sort surviving blobs into reading order (two rows, by center Y then center X).
    $midY = $h / 2
    $row1 = @(); $row2 = @()
    foreach ($lbl in $boxes.Keys) {
        $box = $boxes[$lbl]
        $cy = ($box.MinY + $box.MaxY) / 2
        if ($cy -lt $midY) { $row1 += $lbl } else { $row2 += $lbl }
    }
    $row1 = $row1 | Sort-Object { ($boxes[$_].MinX + $boxes[$_].MaxX) / 2 }
    $row2 = $row2 | Sort-Object { ($boxes[$_].MinX + $boxes[$_].MaxX) / 2 }
    $ordered = @($row1) + @($row2)

    if ($ordered.Count -ne 8) {
        Write-Warning "$($_.Name): expected 8 poses, found $($ordered.Count) -- check this grid image manually"
    }

    # Rebuild a bitmap with the cleaned alpha channel to crop frames from.
    $rebuilt = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $rdata = $rebuilt.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    [System.Runtime.InteropServices.Marshal]::Copy($bytes, 0, $rdata.Scan0, $bytes.Length)
    $rebuilt.UnlockBits($rdata)

    $frames = @()
    foreach ($lbl in $ordered) {
        $box = $boxes[$lbl]
        $minX = [Math]::Max(0, $box.MinX - $padding)
        $minY = [Math]::Max(0, $box.MinY - $padding)
        $maxX = [Math]::Min($w - 1, $box.MaxX + $padding)
        $maxY = [Math]::Min($h - 1, $box.MaxY + $padding)
        $fw = $maxX - $minX + 1
        $fh = $maxY - $minY + 1

        # Isolate just this label's pixels within the crop region.
        $frameBmp = New-Object System.Drawing.Bitmap $fw, $fh, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $frameData = $frameBmp.LockBits((New-Object System.Drawing.Rectangle 0, 0, $fw, $fh), [System.Drawing.Imaging.ImageLockMode]::WriteOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $frameStride = $frameData.Stride
        $frameBytes = New-Object byte[] ($frameStride * $fh)

        for ($y = 0; $y -lt $fh; $y++) {
            $srcY = $minY + $y
            for ($x = 0; $x -lt $fw; $x++) {
                $srcX = $minX + $x
                $srcIdx = $srcY * $w + $srcX
                if ($cc.Label[$srcIdx] -eq $lbl) {
                    $srcOff = $srcY * $stride + $srcX * 4
                    $dstOff = $y * $frameStride + $x * 4
                    $frameBytes[$dstOff] = $bytes[$srcOff]
                    $frameBytes[$dstOff + 1] = $bytes[$srcOff + 1]
                    $frameBytes[$dstOff + 2] = $bytes[$srcOff + 2]
                    $frameBytes[$dstOff + 3] = $bytes[$srcOff + 3]
                }
            }
        }
        [System.Runtime.InteropServices.Marshal]::Copy($frameBytes, 0, $frameData.Scan0, $frameBytes.Length)
        $frameBmp.UnlockBits($frameData)
        $frames += $frameBmp
    }
    $rebuilt.Dispose()

    # Normalize all frames for this character onto a shared canvas, anchored
    # bottom-center, so switching frames doesn't shift the character's feet.
    $maxW = ($frames | ForEach-Object { $_.Width } | Measure-Object -Maximum).Maximum
    $maxH = ($frames | ForEach-Object { $_.Height } | Measure-Object -Maximum).Maximum
    $baseName = $_.Name -replace '_grid\.png$', ''

    for ($i = 0; $i -lt $frames.Count; $i++) {
        $frame = $frames[$i]
        $canvas = New-Object System.Drawing.Bitmap $maxW, $maxH, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $gfx = [System.Drawing.Graphics]::FromImage($canvas)
        $gfx.Clear([System.Drawing.Color]::Transparent)
        $destX = [Math]::Floor(($maxW - $frame.Width) / 2)
        $destY = $maxH - $frame.Height
        $gfx.DrawImage($frame, $destX, $destY, $frame.Width, $frame.Height)
        $gfx.Dispose()
        $frame.Dispose()

        $outPath = Join-Path $dir "$($baseName)_frame$($i + 1).png"
        $canvas.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $canvas.Dispose()
    }

    Remove-Item $path
    Write-Host "$($_.Name): sliced into $($frames.Count) frames ($maxW x $maxH each)"
}
