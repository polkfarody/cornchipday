# One-off fix for magenta pockets that survive crop-sprites.ps1's border
# flood-fill because they're fully enclosed by outline pixels (documented
# limitation -- see crop-sprites.ps1's Remove-MagentaBackground comment and
# plan.md's F11 history). Border-reachable magenta is already gone by the
# time this runs, so any surviving magenta-hued pixel is by definition an
# enclosed pocket -- no flood-fill-from-border needed here, just a straight
# hue/saturation match per pixel, grouped into connected components so a
# -MaxPocketPx cap can spare large legitimate art (e.g. a gradient sky) while
# still catching small slivers (crate slat gaps, bow loops, braid ties).
# Deliberately a standalone, discardable script (not folded into
# crop-sprites.ps1) since it's only safe to run after per-file visual
# verification that the image has no intentional magenta/pink content --
# see this project's own established "manual, visually-verified per-asset"
# rule for leftover-sliver fixes.

param(
    [Parameter(Mandatory = $true)][string[]]$Files,
    [int]$MaxPocketPx = -1   # -1 = no size cap (only use after full-image visual check)
)

Add-Type -AssemblyName System.Drawing

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$dir = Join-Path $projectRoot "Assets\generated"

$refHue = 300.0   # #FF00FF
$hueTolerance = 30
$minSaturation = 0.35

function Get-HueSaturation([byte]$r, [byte]$g, [byte]$b) {
    $rn = $r / 255.0; $gn = $g / 255.0; $bn = $b / 255.0
    $max = [Math]::Max($rn, [Math]::Max($gn, $bn))
    $min = [Math]::Min($rn, [Math]::Min($gn, $bn))
    $delta = $max - $min
    if ($max -le 0) { return @(0, 0) }
    $sat = $delta / $max
    if ($delta -eq 0) { $hue = 0 }
    elseif ($max -eq $rn) { $hue = 60 * (($gn - $bn) / $delta) }
    elseif ($max -eq $gn) { $hue = 60 * ((($bn - $rn) / $delta) + 2) }
    else { $hue = 60 * ((($rn - $gn) / $delta) + 4) }
    if ($hue -lt 0) { $hue += 360 }
    return @($hue, $sat)
}

function Get-HueDistance([double]$a, [double]$b) {
    $d = [Math]::Abs($a - $b) % 360
    if ($d -gt 180) { $d = 360 - $d }
    return $d
}

Get-ChildItem -Path $dir -Filter "*.png" -Recurse | Where-Object { $Files -contains $_.Name } | ForEach-Object {
    $path = $_.FullName
    $fileBytes = [System.IO.File]::ReadAllBytes($path)
    $ms = New-Object System.IO.MemoryStream(, $fileBytes)
    $bmp = [System.Drawing.Bitmap]::FromStream($ms)
    $w = $bmp.Width; $h = $bmp.Height
    $rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
    $data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $stride = $data.Stride
    $bytes = New-Object byte[] ($stride * $h)
    [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)

    # Mark every pixel matching background hue/sat.
    $isBg = New-Object bool[] ($w * $h)
    for ($y = 0; $y -lt $h; $y++) {
        $rowOff = $y * $stride
        for ($x = 0; $x -lt $w; $x++) {
            $off = $rowOff + $x * 4
            if ($bytes[$off + 3] -le 10) { continue }
            $b = $bytes[$off]; $g = $bytes[$off + 1]; $r = $bytes[$off + 2]
            $hs = Get-HueSaturation $r $g $b
            if ($hs[1] -ge $minSaturation -and (Get-HueDistance $hs[0] $refHue) -le $hueTolerance) {
                $isBg[$y * $w + $x] = $true
            }
        }
    }

    # Group matching pixels into connected components so -MaxPocketPx can
    # spare large regions (e.g. an intentionally warm/pink sky gradient).
    $label = New-Object int[] ($w * $h)
    for ($i = 0; $i -lt $label.Length; $i++) { $label[$i] = -1 }
    $sizes = New-Object System.Collections.Generic.List[int]
    $stack = New-Object System.Collections.Generic.Stack[int]
    $nextLabel = 0
    for ($start = 0; $start -lt ($w * $h); $start++) {
        if (-not $isBg[$start] -or $label[$start] -ge 0) { continue }
        $size = 0
        $stack.Push($start); $label[$start] = $nextLabel
        while ($stack.Count -gt 0) {
            $idx = $stack.Pop(); $size++
            $px = $idx % $w; $py = [Math]::Floor($idx / $w)
            $neighbors = @()
            if ($px -gt 0) { $neighbors += ($idx - 1) }
            if ($px -lt $w - 1) { $neighbors += ($idx + 1) }
            if ($py -gt 0) { $neighbors += ($idx - $w) }
            if ($py -lt $h - 1) { $neighbors += ($idx + $w) }
            foreach ($n in $neighbors) {
                if ($isBg[$n] -and $label[$n] -lt 0) { $label[$n] = $nextLabel; $stack.Push($n) }
            }
        }
        $sizes.Add($size)
        $nextLabel++
    }

    $removed = 0
    for ($i = 0; $i -lt ($w * $h); $i++) {
        $lbl = $label[$i]
        if ($lbl -lt 0) { continue }
        if ($MaxPocketPx -ge 0 -and $sizes[$lbl] -gt $MaxPocketPx) { continue }
        $x = $i % $w; $y = [Math]::Floor($i / $w)
        $off = $y * $stride + $x * 4
        $bytes[$off] = 0; $bytes[$off + 1] = 0; $bytes[$off + 2] = 0; $bytes[$off + 3] = 0
        $removed++
    }

    [System.Runtime.InteropServices.Marshal]::Copy($bytes, 0, $data.Scan0, $bytes.Length)
    $bmp.UnlockBits($data)
    if ($removed -gt 0) {
        $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
        Write-Host "$($_.Name): cleared $removed leftover-magenta pixels across $($sizes.Count) candidate pocket(s)"
    } else {
        Write-Host "$($_.Name): no matching pockets found"
    }
    $bmp.Dispose(); $ms.Dispose()
}
