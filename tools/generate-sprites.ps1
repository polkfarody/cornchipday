# Generates first-pass sprites via the Gemini API (Google AI Studio), using
# the prompts derived from characters.txt / game-brief.txt. Requires a .env
# file in the project root with GEMINI_API_KEY=<your key> (copy .env.example).
#
# Sprites are requested on a solid magenta (#FF00FF) background rather than
# "transparent" -- diffusion image models can't natively output real alpha,
# and asking for "transparent background" just gets you a picture of a
# checkerboard baked into opaque pixels. Solid magenta gives crop-sprites.ps1
# a reliable color to key out. None of the current cast uses magenta/pink,
# so there's no risk of keying out part of a character.
#
# Output lands in Assets/generated/ as PNGs, meant to replace the placeholder
# Polygon2D shapes currently in the Godot scenes.
#
# Usage:
#   .\generate-sprites.ps1            # generate all sprites
#   .\generate-sprites.ps1 -Only cornchip_idle   # generate just one, by Name

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

$bgSuffix = "2D side-view platformer game sprite, flat vector illustration style, thick clean outlines, bright saturated colors, flat shading. Background must be solid flat magenta (#FF00FF), completely uniform with no gradient, no pattern, no checkerboard, no watermark, no logo, and no text anywhere in the image."

$sprites = @(
    @{ Name = "cornchip_idle"; Prompt = "A cheerful cartoon video-game character standing in a neutral idle pose: a walking corn chip shaped like an upside-down triangle (wide at top, pointed at bottom), warm golden-yellow with subtle corn speckles, small comedic stick legs, big round friendly cartoon eyes, simple open smiling mouth. $bgSuffix" },
    @{ Name = "cornchip_run"; Prompt = "The same cheerful corn chip character -- upside-down triangle shape, golden-yellow with corn speckles, comedic stick legs, big round friendly eyes, smiling mouth -- in a mid-run pose, one leg stretched forward and one leg back, body leaning slightly forward as if running. $bgSuffix" },
    @{ Name = "cornchip_jump"; Prompt = "The same cheerful corn chip character -- upside-down triangle shape, golden-yellow with corn speckles, comedic stick legs, big round friendly eyes, smiling mouth -- in a mid-air jump pose, both legs tucked up beneath the body. $bgSuffix" },
    @{ Name = "cornchip_hit"; Prompt = "The same corn chip character -- upside-down triangle shape, golden-yellow with corn speckles, comedic stick legs -- in a comedic dazed reaction pose, eyes squeezed shut or dazed, body slightly squashed and tilted as if stumbling. $bgSuffix" },
    @{ Name = "wrap_idle"; Prompt = "A cartoon video-game character standing in a neutral idle pose: a round tubular burrito/wrap, tan-beige tortilla color with a visible fold seam, small comedic stick legs, big expressive round cartoon eyes, a stubborn/proud mouth expression. $bgSuffix" },
    @{ Name = "salsa_obstacle"; Prompt = "A cartoon thrown food projectile: a small round blob of red salsa with a comedic wobbly splat shape, glossy highlight. $bgSuffix" },
    @{ Name = "lettuce_ingredient"; Prompt = "A cute cartoon lettuce leaf collectible icon for a kids' video game, bright green with a glossy highlight, centered composition. $bgSuffix" },
    @{ Name = "hot_sauce_boss_idle"; Prompt = "A cartoon video-game boss character standing in a neutral idle pose: a happy squeeze bottle of hot sauce whose cap is shaped like a sombrero, small comedic cartoon legs, an expressive face, glowing lava-like sauce visible at the nozzle. $bgSuffix" },
    @{ Name = "avocado_boss_idle"; Prompt = "A cartoon video-game boss character: a dancing avocado with small comedic cartoon legs mid dance pose, an expressive happy face, glossy pit visible, a small puddle of guacamole near its feet. $bgSuffix" },
    @{ Name = "cheese_enemy_idle"; Prompt = "A cartoon video-game enemy character standing in a neutral idle pose: a friendly-looking wedge of yellow cheese with small comedic cartoon legs and a sleepy, mischievous expression, small visible cheese holes. $bgSuffix" },
    @{ Name = "salsa_bowl_boss_idle"; Prompt = "A cartoon video-game boss character: a rolling bowl full of red salsa, mounted on small corn-cob-shaped wheels, with big cartoon eyes and a mouth on the front of the bowl, appearing mid-roll. $bgSuffix" }
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
    $body = @{
        model = "gemini-3.1-flash-lite-image"
        input = @(@{ type = "text"; text = $sprite.Prompt })
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
