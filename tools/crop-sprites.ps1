# The raw Gemini/AI Studio sprite exports are NOT actually transparent --
# every pixel has alpha=255, and the "transparent" checkerboard is baked in
# as opaque neutral-gray pixels (~217,217,217 and ~171,171,171). This script:
#   1. Flood-fills inward from the image border, clearing any pixel that's
#      part of that connected checkerboard region to real alpha=0.
#   2. Crops the result to the bounding box of what's left, plus padding.
# Overwrites each PNG in Assets/generated in place.

Add-Type -AssemblyName System.Drawing

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$dir = Join-Path $projectRoot "Assets\generated"
$padding = 10
$grayTolerance = 6      # how close R/G/B must be to each other to count as "neutral gray"
$checkerTolerance = 14  # how close the gray value must be to one of the two checker shades
$checkerShades = @(217, 171)

function Test-IsCheckerPixel([byte]$b, [byte]$g, [byte]$r) {
    if (([Math]::Abs([int]$r - [int]$g) -gt $grayTolerance) -or
        ([Math]::Abs([int]$g - [int]$b) -gt $grayTolerance) -or
        ([Math]::Abs([int]$r - [int]$b) -gt $grayTolerance)) {
        return $false
    }
    $avg = ([int]$r + [int]$g + [int]$b) / 3
    foreach ($shade in $checkerShades) {
        if ([Math]::Abs($avg - $shade) -le $checkerTolerance) { return $true }
    }
    return $false
}

Get-ChildItem "$dir\*.png" | ForEach-Object {
    $path = $_.FullName
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

    # Flood fill (iterative, stack-based) from every border pixel.
    $visited = New-Object bool[] ($w * $h)
    $stack = New-Object System.Collections.Generic.Stack[int]

    for ($x = 0; $x -lt $w; $x++) {
        $stack.Push($x)                      # top row
        $stack.Push(($h - 1) * $w + $x)       # bottom row
    }
    for ($y = 0; $y -lt $h; $y++) {
        $stack.Push($y * $w)                  # left col
        $stack.Push($y * $w + ($w - 1))       # right col
    }

    while ($stack.Count -gt 0) {
        $idx = $stack.Pop()
        if ($visited[$idx]) { continue }
        $visited[$idx] = $true

        $px = $idx % $w
        $py = [Math]::Floor($idx / $w)
        $off = $py * $stride + $px * 4
        $b = $bytes[$off]; $g = $bytes[$off + 1]; $r = $bytes[$off + 2]

        if (-not (Test-IsCheckerPixel $b $g $r)) { continue }

        $bytes[$off + 3] = 0   # clear alpha

        if ($px -gt 0) { $n = $idx - 1; if (-not $visited[$n]) { $stack.Push($n) } }
        if ($px -lt $w - 1) { $n = $idx + 1; if (-not $visited[$n]) { $stack.Push($n) } }
        if ($py -gt 0) { $n = $idx - $w; if (-not $visited[$n]) { $stack.Push($n) } }
        if ($py -lt $h - 1) { $n = $idx + $w; if (-not $visited[$n]) { $stack.Push($n) } }
    }

    # Second pass: label connected components of remaining (alpha > 10)
    # pixels and keep only the largest one -- discards small leftover
    # artifacts (e.g. a watermark icon) that would otherwise pin the
    # bounding box to the full canvas.
    $label = New-Object int[] ($w * $h)
    for ($i = 0; $i -lt $label.Length; $i++) { $label[$i] = -1 }
    $componentSizes = New-Object System.Collections.Generic.List[int]
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
        $componentSizes.Add($size)
        $nextLabel++
    }

    if ($componentSizes.Count -eq 0) {
        Write-Warning "$($_.Name): nothing left after background removal, skipping"
        $bmp.Dispose(); $ms.Dispose()
        return
    }

    $largestLabel = 0
    $largestSize = $componentSizes[0]
    for ($i = 1; $i -lt $componentSizes.Count; $i++) {
        if ($componentSizes[$i] -gt $largestSize) {
            $largestSize = $componentSizes[$i]
            $largestLabel = $i
        }
    }

    # Clear alpha for every foreground pixel that isn't part of the main blob.
    $minX = $w; $maxX = -1; $minY = $h; $maxY = -1
    for ($y = 0; $y -lt $h; $y++) {
        $rowOff = $y * $stride
        for ($x = 0; $x -lt $w; $x++) {
            $idx = $y * $w + $x
            if ($label[$idx] -eq $largestLabel) {
                if ($x -lt $minX) { $minX = $x }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($y -gt $maxY) { $maxY = $y }
            } elseif ($label[$idx] -ge 0) {
                $bytes[$rowOff + $x * 4 + 3] = 0
            }
        }
    }

    [System.Runtime.InteropServices.Marshal]::Copy($bytes, 0, $data.Scan0, $bytes.Length)
    $bmp.UnlockBits($data)

    if ($maxX -lt 0) {
        Write-Warning "$($_.Name): nothing left after background removal, skipping"
        $bmp.Dispose(); $ms.Dispose()
        return
    }

    $minX = [Math]::Max(0, $minX - $padding)
    $minY = [Math]::Max(0, $minY - $padding)
    $maxX = [Math]::Min($w - 1, $maxX + $padding)
    $maxY = [Math]::Min($h - 1, $maxY + $padding)
    $cropW = $maxX - $minX + 1
    $cropH = $maxY - $minY + 1

    $cropRect = New-Object System.Drawing.Rectangle $minX, $minY, $cropW, $cropH
    $cropped = $bmp.Clone($cropRect, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $bmp.Dispose()
    $ms.Dispose()

    $cropped.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $cropped.Dispose()

    Write-Host "$($_.Name): $w x $h -> $cropW x $cropH (background removed)"
}
