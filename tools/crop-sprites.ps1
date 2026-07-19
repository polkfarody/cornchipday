# Removes the solid magenta (#FF00FF) chroma-key background from each PNG in
# Assets/generated, keeps only the largest connected foreground blob (so any
# stray watermark/logo artifact gets discarded rather than pinning the crop
# to the full canvas), and crops to that blob's bounding box plus padding.
# Overwrites each PNG in place.

Add-Type -AssemblyName System.Drawing

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$dir = Join-Path $projectRoot "Assets\generated"
$padding = 10
$magentaTolerance = 60  # per-channel distance from (255, 0, 255) to count as background

function Test-IsMagentaPixel([byte]$r, [byte]$g, [byte]$b) {
    return ([Math]::Abs([int]$r - 255) -le $magentaTolerance) -and
           ([Math]::Abs([int]$g - 0) -le $magentaTolerance) -and
           ([Math]::Abs([int]$b - 255) -le $magentaTolerance)
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

    # Flood fill (iterative, stack-based) from every border pixel, clearing
    # alpha for any magenta-background pixel connected to the edge.
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

        if (-not (Test-IsMagentaPixel $r $g $b)) { continue }

        $bytes[$off + 3] = 0

        if ($px -gt 0) { $n = $idx - 1; if (-not $visited[$n]) { $stack.Push($n) } }
        if ($px -lt $w - 1) { $n = $idx + 1; if (-not $visited[$n]) { $stack.Push($n) } }
        if ($py -gt 0) { $n = $idx - $w; if (-not $visited[$n]) { $stack.Push($n) } }
        if ($py -lt $h - 1) { $n = $idx + $w; if (-not $visited[$n]) { $stack.Push($n) } }
    }

    # Label connected components of remaining (alpha > 10) pixels; keep only
    # the largest one, discarding small leftover artifacts.
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
