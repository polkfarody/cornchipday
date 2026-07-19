# Generates first-pass sprites via the Gemini API (Google AI Studio), using
# the prompts derived from characters.txt / game-brief.txt. Requires a .env
# file in the project root with GEMINI_API_KEY=<your key> (copy .env.example).
#
# Sprites are requested on a solid magenta (#FF00FF) background rather than
# "transparent" -- diffusion image models can't natively output real alpha,
# so a transparency request just yields a checkerboard baked into opaque
# pixels. Solid magenta gives crop-sprites.ps1 a reliable color to key out.
# Drop shadows are explicitly forbidden in the prompt: a soft shadow blends
# with the magenta rather than matching it exactly, so it survives simple
# chroma-key thresholding as a dark smudge.
#
# Each character is requested as a single "*_grid.png" image containing an
# 8-pose grid (4 columns x 2 rows), read left-to-right then top-to-bottom:
#   1) idle                 2) idle variant (blink/weight shift)
#   3) move, phase A        4) move, phase B
#   5) signature action, phase A   6) signature action, phase B
#   7) hit/dazed reaction    8) celebrate (Cornchip/Wrap) or defeated (enemies)
# crop-sprites.ps1 slices each grid into 8 separate frame files.
#
# Non-character props (the salsa obstacle, the lettuce ingredient) stay as
# single still images -- "8 poses" doesn't apply to a static splat or leaf.
#
# Output lands in Assets/generated/ as PNGs, meant to replace the placeholder
# Polygon2D shapes currently in the Godot scenes.
#
# Usage:
#   .\generate-sprites.ps1            # generate all sprites (careful -- costs money per image)
#   .\generate-sprites.ps1 -Only cornchip_grid   # generate just one, by Name
#
# Reference images: every request includes cornchip_frame1.png and
# hot_sauce_boss_frame1.png as image inputs alongside the text prompt, so
# new characters match the established art style instead of relying on
# prompt wording alone to stay consistent.

param(
    [string]$Only = $null
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$envFile = Join-Path $projectRoot ".env"

if (-not (Test-Path $envFile)) {
    Write-Error "Missing .env file at $envFile. Copy .env.example to .env and add your Gemini API key."
    exit 1
}

$apiKey = $null
foreach ($line in Get-Content $envFile) {
    if ($line -match '^\s*GEMINI_API_KEY\s*=\s*(.+?)\s*$') {
        $apiKey = $Matches[1].Trim()
    }
}
if (-not $apiKey -or $apiKey -eq "your-key-here") {
    Write-Error "GEMINI_API_KEY not set in $envFile"
    exit 1
}

$outDir = Join-Path $projectRoot "Assets\generated"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$referenceImagePaths = @(
    (Join-Path $outDir "cornchip_frame1.png"),
    (Join-Path $outDir "hot_sauce_boss_frame1.png")
)
$referenceImageInputs = @()
foreach ($refPath in $referenceImagePaths) {
    if (Test-Path $refPath) {
        $refBytes = [IO.File]::ReadAllBytes($refPath)
        $referenceImageInputs += @{
            type      = "image"
            mime_type = "image/png"
            data      = [Convert]::ToBase64String($refBytes)
        }
    } else {
        Write-Warning "Reference image not found, skipping: $refPath"
    }
}

$styleSuffix = "Flat vector illustration style, thick clean outlines, bright saturated colors, flat shading, no gradients. Background must be solid flat magenta (#FF00FF) throughout the entire image, completely uniform, no pattern, no checkerboard, no watermark, no logo, no text. Absolutely no drop shadows or shadow of any kind beneath or around any character or object."

$gridSuffix = "Arrange as a clean 4-column by 2-row grid of the 8 poses listed above, left-to-right then top-to-bottom, with generous empty magenta space between every pose so no two poses touch or overlap. The character's design, colors, and proportions must stay exactly consistent across all 8 cells. $styleSuffix"

function Grid-Prompt([string]$character, [string]$move, [string]$action, [string]$pose8) {
    return "A 2D side-view platformer game character sprite sheet depicting: $character`n" +
           "The 8 poses: 1) idle standing pose. 2) idle pose variant, a subtle blink or weight shift. 3) $move (phase A). 4) $move (phase B). 5) $action (phase A). 6) $action (phase B). 7) a dazed/hit reaction pose. 8) $pose8.`n" +
           $gridSuffix
}

$sprites = @(
    @{ Name = "cornchip_grid"; Prompt = (Grid-Prompt `
        "a walking corn chip shaped like an upside-down triangle (wide at top, pointed at bottom), warm golden-yellow with subtle corn speckles, small comedic stick legs, big round friendly cartoon eyes, simple mouth." `
        "running, one leg forward and one leg back, leaning slightly forward" `
        "jumping, crouching down then airborne with legs tucked up" `
        "celebrating happily, arms up, big smile") },
    @{ Name = "wrap_grid"; Prompt = (Grid-Prompt `
        "a round tubular burrito/wrap, tan-beige tortilla color with a visible fold seam, small comedic stick legs, big expressive round cartoon eyes, a stubborn/proud mouth expression." `
        "walking with arms crossed stubbornly, alternating a slight lean left and right" `
        "throwing a food obstacle, winding up then following through" `
        "a warmer, softer smiling pose") },
    @{ Name = "hot_sauce_boss_grid"; Prompt = (Grid-Prompt `
        "a happy squeeze bottle of hot sauce whose cap is shaped like a sombrero, small comedic cartoon legs, an expressive face, glowing lava-like sauce visible at the nozzle." `
        "shuffling side to side, leaning left then right" `
        "firing sauce from the hat opening, sauce glowing brighter then spraying out" `
        "a dizzy, defeated pose with the sombrero tilted and swirly eyes") },
    @{ Name = "avocado_boss_grid"; Prompt = (Grid-Prompt `
        "a dancing avocado with small comedic cartoon legs, an expressive happy face, glossy pit visible." `
        "dancing, leaning left then right mid-dance" `
        "jumping and dropping guacamole, airborne then landing with guacamole splattering below" `
        "a dizzy, defeated pose, slightly squished") },
    @{ Name = "cheese_enemy_grid"; Prompt = (Grid-Prompt `
        "a friendly-looking wedge of yellow cheese with small comedic cartoon legs and a sleepy, mischievous expression, small visible cheese holes." `
        "shuffling side to side sleepily, leaning left then right" `
        "yawning widely, mouth opening then a full wide yawn with eyes closed" `
        "a dizzy, defeated pose, slightly flattened") },
    @{ Name = "salsa_bowl_boss_grid"; Prompt = (Grid-Prompt `
        "a rolling bowl full of red salsa, mounted on small corn-cob-shaped wheels, with big cartoon eyes and a mouth on the front of the bowl." `
        "rolling forward, corn wheels at two different rotation angles" `
        "firing a tomato chunk, the chunk forming then flying out" `
        "a dizzy, defeated pose, tipped over on its side") },
    @{ Name = "salsa_obstacle"; Prompt = "A cartoon thrown food projectile: a small round blob of red salsa with a comedic wobbly splat shape, glossy highlight. $styleSuffix" },
    @{ Name = "lettuce_ingredient"; Prompt = "A cute cartoon lettuce leaf collectible icon for a kids' video game, bright green with a glossy highlight, centered composition. $styleSuffix" },
    @{ Name = "cheese_ingredient"; Prompt = "A cartoon wedge of yellow cheese collectible icon for a kids' video game, glossy highlight, simple visible holes, centered composition. $styleSuffix" },
    @{ Name = "queso_grande_grid"; Prompt = (Grid-Prompt `
        "a giant bubbling pot of nacho cheese fondue: a wide bowl-shaped body, warm orange-yellow molten cheese color, cartoon eyes and mouth on the front, small comedic stick legs, bubbles/steam rising from the top." `
        "wobbling/bubbling in place, alternating a slight lean left and right" `
        "dripping a cheese glob from its rim, the glob stretching down then dropping off" `
        "a dizzy, defeated pose, tipped over, cheese drooping") },
    @{ Name = "jalapeno_grid"; Prompt = (Grid-Prompt `
        "a cartoon jalapeño pepper character, glossy green skin, small comedic stick legs, big round friendly-but-mischievous cartoon eyes, simple mouth." `
        "hopping, crouching down then springing up" `
        "a spicy wink/taunt, one eye winking with a small heat-wave squiggle above its head" `
        "a dizzy, defeated pose, slightly wilted") },
    @{ Name = "lime_grid"; Prompt = (Grid-Prompt `
        "a wedge of lime with visible juicy green segments and white pith, small comedic stick legs, big round cartoon eyes, a mischievous grin." `
        "hopping/bouncing in place, alternating a slight lean left and right" `
        "squirting a stream of lime juice from a small pucker in its segments, the stream appearing then spraying out" `
        "a dizzy, defeated pose, slightly squished, juice dripping") },
    @{ Name = "onion_grid"; Prompt = (Grid-Prompt `
        "a round onion with visible papery outer layers, small comedic stick legs, big round cartoon eyes, a sly smirking expression." `
        "swaying gently side to side, alternating a slight lean left and right" `
        "releasing wavy stink-fume lines from the top, fumes appearing then wafting upward" `
        "a dizzy, defeated pose, wilted, peeling apart at the edges") }
)

if ($Only) {
    $sprites = $sprites | Where-Object { $_.Name -eq $Only }
    if (-not $sprites) {
        Write-Error "No sprite named '$Only' in the list."
        exit 1
    }
}

$maxRetries = 4

foreach ($sprite in $sprites) {
    Write-Host "Generating $($sprite.Name)..."
    $inputItems = @(@{ type = "text"; text = $sprite.Prompt }) + $referenceImageInputs
    $body = @{
        model = "gemini-3.1-flash-image"
        input = $inputItems
    } | ConvertTo-Json -Depth 10

    $attempt = 0
    $succeeded = $false
    while (-not $succeeded -and $attempt -le $maxRetries) {
        $attempt++
        try {
            $response = Invoke-RestMethod -Uri "https://generativelanguage.googleapis.com/v1beta/interactions" `
                -Method Post `
                -Headers @{ "x-goog-api-key" = $apiKey } `
                -ContentType "application/json" `
                -Body $body

            $imageData = $null
            foreach ($step in $response.steps) {
                foreach ($item in $step.content) {
                    if ($item.type -eq "image") {
                        $imageData = $item.data
                        break
                    }
                }
                if ($imageData) { break }
            }

            if (-not $imageData) {
                Write-Warning "No image returned for $($sprite.Name). Response: $($response | ConvertTo-Json -Depth 10)"
                break
            }

            $bytes = [Convert]::FromBase64String($imageData)
            $outPath = Join-Path $outDir "$($sprite.Name).png"
            [IO.File]::WriteAllBytes($outPath, $bytes)
            Write-Host "Saved $outPath"
            $succeeded = $true
        } catch {
            $statusCode = $null
            if ($_.Exception.Response) {
                $statusCode = [int]$_.Exception.Response.StatusCode
            }
            if ($statusCode -eq 429 -and $attempt -le $maxRetries) {
                $waitSeconds = 15 * $attempt
                Write-Warning "$($sprite.Name): rate limited (429), retry $attempt/$maxRetries in ${waitSeconds}s..."
                Start-Sleep -Seconds $waitSeconds
            } else {
                Write-Warning "Failed to generate $($sprite.Name): $_"
                break
            }
        }
    }

    # Small gap between sprites regardless of outcome, to stay under per-minute limits.
    Start-Sleep -Seconds 5
}
