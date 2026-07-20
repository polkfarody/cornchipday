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

# Assets/generated is organized into subfolders (characters/<name>/, items/,
# environment/level1|2/) so it doesn't turn into one flat pile of 100+ files.
# This maps a sprite's Name to its subfolder so generation writes straight to
# the right place instead of needing a manual sort afterward.
function Get-AssetSubdir([string]$name) {
    if ($name -match "^(.+)_extras_grid$") {
        return "characters\$($Matches[1])"
    }
    if ($name -like "*_grid") {
        $character = $name -replace "_grid$", ""
        return "characters\$character"
    }
    if ($name -in @("salsa_obstacle", "lettuce_ingredient", "cheese_ingredient", "guac_ingredient", "tomato_ingredient", "sour_cream_ingredient", "crunchy_shell_ingredient", "bean_ingredient", "air_fryer_icon")) {
        return "items"
    }
    if ($name -like "l1_*") {
        return "environment\level1"
    }
    if ($name -like "l2_*") {
        return "environment\level2"
    }
    if ($name -like "l3_*") {
        return "environment\level3"
    }
    if ($name -like "l4_*") {
        return "environment\level4"
    }
    if ($name -like "l5_*") {
        return "environment\level5"
    }
    if ($name -like "l6_*") {
        return "environment\level6"
    }
    return ""
}

$referenceImagePaths = @(
    (Join-Path $outDir "characters\cornchip\cornchip_frame1.png"),
    (Join-Path $outDir "characters\hot_sauce_boss\hot_sauce_boss_frame1.png")
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

$styleSuffix = "Flat vector illustration style, thick clean outlines, bright saturated colors, flat shading, no gradients. Background must be solid flat magenta (#FF00FF) throughout the entire image, completely uniform, no pattern, no checkerboard, no watermark, no logo. Absolutely no drop shadows or shadow of any kind beneath or around any character or object. Absolutely no text, words, letters, or readable labels anywhere in the image -- any product labels, signage, or packaging must be plain solid color with zero wording (this is for a game aimed at children too young to read)."

# For tileable ground/hazard textures -- NOT icon-on-magenta assets. The whole
# canvas IS the texture, so no chroma-key background and no cropping applies
# (crop-sprites.ps1 explicitly skips *_hazard_fill.png / *_ground_tile.png).
$textureSuffix = "Flat vector illustration style, thick clean outlines, bright saturated colors, flat shading. The entire image must be a seamless, tileable pattern designed to repeat edge-to-edge with no visible seam and no single-object silhouette floating on a separate background -- the whole canvas is the texture itself. No watermark, no logo, no text."

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
        "a dizzy, defeated pose, wilted, peeling apart at the edges") },
    @{ Name = "big_red_grid"; Prompt = (Grid-Prompt `
        "a giant round tomato character, shiny deep-red skin, a small green leafy stem-cap on top, small comedic cartoon legs, a big blustery determined face." `
        "shuffling/waddling side to side with a heavy stomp, leaning left then right" `
        "cracking apart down the middle, a glowing crack appearing then widening, about to split in two" `
        "fully split into two round halves flying apart from each other, mid-split") },
    @{ Name = "cherry_tomato_grid"; Prompt = (Grid-Prompt `
        "a small round cherry tomato character, glossy bright-red skin, a tiny green stem, small comedic stick legs, big round energetic cartoon eyes, a playful grin." `
        "darting quickly side to side, an energetic fast hop, alternating a slight lean left and right" `
        "a quick playful pouncing lunge toward the viewer, crouching low then springing forward" `
        "a dizzy, defeated pose, slightly squished"); Model = "gemini-3-pro-image" },
    @{ Name = "sour_cream_sam_grid"; Prompt = (Grid-Prompt `
        "a friendly tub of sour cream character, smooth pale-white creamy body with a slight dollop-swirl on top, small comedic cartoon legs, a big blustery cool-tempered face." `
        "shuffling side to side with a cold shiver, leaning left then right" `
        "exhaling a chilling frosty breath, breath fogging then a burst of cold mist" `
        "a dizzy, defeated pose, slightly melted/drooping") },
    @{ Name = "ice_cube_grid"; Prompt = (Grid-Prompt `
        "a cartoon ice cube character, translucent pale-blue with sharp geometric edges and visible sparkle highlights, small comedic stick legs, big round cartoon eyes, a mischievous grin." `
        "sliding/skating quickly side to side, an energetic fast slide, alternating a slight lean left and right" `
        "a quick spinning slide-dash toward the viewer, crouching low then sliding forward" `
        "a dizzy, defeated pose, partially melted into a puddle") },
    @{ Name = "chive_bit_grid"; Prompt = (Grid-Prompt `
        "a tiny cartoon chive sprout character, thin bright-green stalks bundled together, small comedic stick legs, big round cartoon eyes, a cheeky grin, noticeably smaller and simpler than other characters." `
        "hopping/bouncing quickly in place, an energetic tiny hop, alternating a slight lean left and right" `
        "a quick playful tumble/somersault toward the viewer" `
        "a dizzy, defeated pose, slightly squished") },
    @{ Name = "iron_skillet_grid"; Prompt = (Grid-Prompt `
        "a cast-iron skillet character with a wooden handle, dark metallic body with a browned/seasoned texture, small comedic cartoon legs, a big fiery intense face." `
        "shuffling side to side with a sizzle, leaning left then right" `
        "radiating heat waves, glowing red-hot around the rim, heat shimmer intensifying" `
        "a dizzy, defeated pose, slightly dented") },
    @{ Name = "grease_splatter_grid"; Prompt = (Grid-Prompt `
        "a cartoon splatter of hot sizzling grease, glossy amber-brown blob shape with small bubble details, small comedic stick legs, a mischievous crackling expression." `
        "hopping/sizzling in place with small bubbling pops, alternating a slight lean left and right" `
        "a quick bubbling burst, popping outward then settling" `
        "a dizzy, defeated pose, slightly flattened") },

    # Level 1/2 environment art pass (feature.md F11) -- obstacles, scenery,
    # and window/parallax views are icon-on-magenta like everything above;
    # hazard-fill and ground-tile textures use $textureSuffix instead (no
    # magenta, no cropping -- see crop-sprites.ps1's skip list).
    @{ Name = "l1_obstacle_small"; Prompt = "A cartoon obstacle for a platformer: a single stack of two red salsa jars with cartoon labels, glossy glass, a small comedic wobble to the stack. $styleSuffix"; Model = "gemini-3-pro-image" },
    @{ Name = "l1_obstacle_medium"; Prompt = "A cartoon obstacle for a platformer: a small pyramid of three stacked red salsa jars with cartoon labels, glossy glass. $styleSuffix"; Model = "gemini-3-pro-image" },
    @{ Name = "l1_obstacle_large"; Prompt = "A cartoon obstacle for a platformer: a tall pyramid of five stacked red salsa jars with cartoon labels, glossy glass, slightly leaning for a comedic wobble. $styleSuffix"; Model = "gemini-3-pro-image" },
    @{ Name = "l1_hazard_fill"; Prompt = "A texture of bubbling hot molten salsa, glossy red-orange surface with bubble highlights and a subtle simmering texture. $textureSuffix" },
    @{ Name = "l1_ground_tile"; Prompt = "A texture of warm terracotta patio floor tiles, small grout lines between square tiles, warm reddish-brown tones. No characters, faces, or creatures of any kind anywhere in the tile pattern. $textureSuffix"; NoRefs = $true; Model = "gemini-3-pro-image" },
    @{ Name = "l1_cactus"; Prompt = "A simple cartoon saguaro cactus silhouette for a platformer background, two side arms, bright green with lighter highlight lines. $styleSuffix" },
    @{ Name = "l1_string_lights"; Prompt = "Three separate small round light bulbs of different colors (one red, one yellow, one green) connected in a row by a single thin curved wire, resembling a strand of festive party string lights, for a platformer background decoration. $styleSuffix"; Model = "gemini-3-pro-image" },
    @{ Name = "l1_window_view"; Prompt = "A wooden cantina-style window frame set into a warm adobe wall, with a hazy, softer-detailed distant desert scene visible through the glass: silhouettes of far-off cacti and low hills under a warm sunset sky, suggesting depth beyond the window. No characters, faces, or creatures anywhere in the scene -- empty scenery only. $styleSuffix"; NoRefs = $true; Model = "gemini-3-pro-image" },
    @{ Name = "l2_obstacle_small"; Prompt = "A cartoon obstacle for a platformer: a single nacho serving tray standing on its edge, red plastic basket-style tray with a few tortilla chips visible. $styleSuffix" },
    @{ Name = "l2_obstacle_medium"; Prompt = "A cartoon obstacle for a platformer: two stacked nacho serving trays, red plastic basket-style trays with tortilla chips visible. $styleSuffix" },
    @{ Name = "l2_obstacle_large"; Prompt = "A cartoon obstacle for a platformer: three stacked nacho serving trays topped with a block of yellow cheese, red plastic basket-style trays with tortilla chips visible. $styleSuffix" },
    @{ Name = "l2_hazard_fill"; Prompt = "A texture of bubbling molten nacho cheese, glossy orange-yellow surface with bubble highlights and a subtle melty texture. $textureSuffix" },
    @{ Name = "l2_ground_tile"; Prompt = "A texture of a checkered nacho-bar floor, alternating warm yellow and tan square tiles. Plain tiles only -- no characters, faces, creatures, or icons of any kind in the pattern. $textureSuffix"; NoRefs = $true; Model = "gemini-3-pro-image" },
    @{ Name = "l2_chip"; Prompt = "A single cartoon tortilla chip, triangular, golden-tan with small brown speckles, for a platformer background decoration. $styleSuffix" },
    @{ Name = "l2_cheese_drip"; Prompt = "A single cartoon cheese drip/dollop hanging shape, glossy orange-yellow, for a platformer background decoration. $styleSuffix" },
    @{ Name = "l2_window_view"; Prompt = "A window frame set into a tiled cheese-yellow kitchen wall, with a hazy, softer-detailed distant scene visible through the glass: a softly-lit dining area or second kitchen counter, suggesting depth beyond the window. No characters, faces, or creatures anywhere in the scene -- empty scenery only. $styleSuffix"; NoRefs = $true },

    # Level 3-6 environment art pass (equivalent to F11) -- every asset here
    # uses gemini-3-pro-image from the start (per direct user instruction)
    # rather than the flash-then-regen detour F11 needed for L1/L2. Obstacle
    # prompts deliberately omit "with labels" (the wording that caused F11's
    # readable-text defect on the L1 salsa jars).
    @{ Name = "l3_obstacle_small"; Prompt = "A cartoon obstacle for a platformer: a single wooden crate stacked with whole green avocados, rustic slatted wood, no text or labels. $styleSuffix"; Model = "gemini-3-pro-image" },
    @{ Name = "l3_obstacle_medium"; Prompt = "A cartoon obstacle for a platformer: two stacked wooden crates of whole green avocados, rustic slatted wood, no text or labels. $styleSuffix"; Model = "gemini-3-pro-image" },
    @{ Name = "l3_obstacle_large"; Prompt = "A cartoon obstacle for a platformer: three stacked wooden crates of whole green avocados, topped with one oversized prize avocado, rustic slatted wood, no text or labels. $styleSuffix"; Model = "gemini-3-pro-image" },
    @{ Name = "l3_hazard_fill"; Prompt = "A texture of bubbling chunky green guacamole, glossy surface with visible avocado chunk highlights. No characters, faces, or creatures of any kind anywhere in the pattern -- plain food texture only. $textureSuffix"; NoRefs = $true; Model = "gemini-3-pro-image" },
    @{ Name = "l3_ground_tile"; Prompt = "A texture of weathered wooden produce-stand planking, greenish-brown wood grain, plain boards only -- no characters, faces, or creatures of any kind anywhere in the pattern. $textureSuffix"; NoRefs = $true; Model = "gemini-3-pro-image" },
    @{ Name = "l3_lime_bunch"; Prompt = "A hanging bunch of whole limes tied together with a simple twine bow, for a platformer background decoration. $styleSuffix"; Model = "gemini-3-pro-image" },
    @{ Name = "l3_onion_braid"; Prompt = "A hanging braided string of whole onions, for a platformer background decoration. $styleSuffix"; Model = "gemini-3-pro-image" },
    @{ Name = "l3_window_view"; Prompt = "A rustic wooden market-stall awning frame, with a hazy, softer-detailed distant scene visible beyond it: silhouettes of more produce stands and crates under daylight, suggesting depth beyond the frame. No characters, faces, or creatures anywhere in the scene -- empty scenery only. $styleSuffix"; NoRefs = $true; Model = "gemini-3-pro-image" },

    @{ Name = "l4_obstacle_small"; Prompt = "A cartoon obstacle for a platformer: a single wooden crate of round red tomatoes, rustic slatted wood, no text or labels. $styleSuffix"; Model = "gemini-3-pro-image" },
    @{ Name = "l4_obstacle_medium"; Prompt = "A cartoon obstacle for a platformer: two stacked wooden crates of round red tomatoes, rustic slatted wood, no text or labels. No characters, faces, or creatures of any kind anywhere in the image -- the crates themselves only, nothing standing in front of or beside them. $styleSuffix"; NoRefs = $true; Model = "gemini-3-pro-image" },
    @{ Name = "l4_obstacle_large"; Prompt = "A cartoon obstacle for a platformer: three stacked wooden crates of round red tomatoes, topped with one oversized tomato, rustic slatted wood, no text or labels. $styleSuffix"; Model = "gemini-3-pro-image" },
    @{ Name = "l4_hazard_fill"; Prompt = "A texture of spilled glossy red marinara/tomato sauce, smooth glossy surface with subtle simmering highlights. $textureSuffix"; Model = "gemini-3-pro-image" },
    @{ Name = "l4_ground_tile"; Prompt = "A texture of outdoor cobblestone market-square paving, warm red-brown stone tones, plain stones only -- no characters, faces, or creatures of any kind anywhere in the pattern. $textureSuffix"; NoRefs = $true; Model = "gemini-3-pro-image" },
    @{ Name = "l4_chili_string"; Prompt = "A hanging string of red chili peppers tied together, for a platformer background decoration. $styleSuffix"; Model = "gemini-3-pro-image" },
    @{ Name = "l4_awning_bunting"; Prompt = "A small triangle of red-and-white striped market bunting/awning fabric, for a platformer background decoration. $styleSuffix"; Model = "gemini-3-pro-image" },
    @{ Name = "l4_window_view"; Prompt = "A red-and-white striped market-stall awning frame, with a hazy, softer-detailed distant scene visible beyond it: silhouettes of more market stalls and rooftops under daylight, suggesting depth beyond the frame. No characters, faces, or creatures anywhere in the scene -- empty scenery only. $styleSuffix"; NoRefs = $true; Model = "gemini-3-pro-image" },

    @{ Name = "l5_obstacle_small"; Prompt = "A cartoon obstacle for a platformer: a single frosty white plastic tub with a light coating of frost, no text or labels. $styleSuffix"; Model = "gemini-3-pro-image" },
    @{ Name = "l5_obstacle_medium"; Prompt = "A cartoon obstacle for a platformer: two stacked frosty white plastic tubs with a light coating of frost, no text or labels. $styleSuffix"; Model = "gemini-3-pro-image" },
    @{ Name = "l5_obstacle_large"; Prompt = "A cartoon obstacle for a platformer: three stacked frosty white plastic tubs with a heavy coating of frost and small icicles, no text or labels. $styleSuffix"; Model = "gemini-3-pro-image" },
    @{ Name = "l5_hazard_fill"; Prompt = "A texture of icy pale-blue slush, glossy surface with frost-crystal highlights and subtle cracks. $textureSuffix"; Model = "gemini-3-pro-image" },
    @{ Name = "l5_ground_tile"; Prompt = "A texture of steel walk-in-fridge flooring with light frost patches, cool blue-gray metallic tones, plain flooring only -- no characters, faces, or creatures of any kind anywhere in the pattern. $textureSuffix"; NoRefs = $true; Model = "gemini-3-pro-image" },
    @{ Name = "l5_icicles"; Prompt = "A cluster of hanging translucent pale-blue icicles, for a platformer background decoration. $styleSuffix"; Model = "gemini-3-pro-image" },
    @{ Name = "l5_frost_puff"; Prompt = "A frosted metal shelf-edge with small puffs of cold mist rising off it, for a platformer background decoration. $styleSuffix"; Model = "gemini-3-pro-image" },
    @{ Name = "l5_window_view"; Prompt = "A frosted metal fridge-shelving frame, with a hazy, softer-detailed distant scene visible beyond it: silhouettes of more shelving deeper in a walk-in fridge under cool blue light with soft fog, suggesting depth beyond the frame. No characters, faces, or creatures anywhere in the scene -- empty scenery only. $styleSuffix"; NoRefs = $true; Model = "gemini-3-pro-image" },

    @{ Name = "l6_obstacle_small"; Prompt = "A cartoon obstacle for a platformer: a single stack of golden crunchy taco shells, no text or labels. $styleSuffix"; Model = "gemini-3-pro-image" },
    @{ Name = "l6_obstacle_medium"; Prompt = "A cartoon obstacle for a platformer: two stacked crates of golden crunchy taco shells, no text or labels. $styleSuffix"; Model = "gemini-3-pro-image" },
    @{ Name = "l6_obstacle_large"; Prompt = "A cartoon obstacle for a platformer: three stacked crates of golden crunchy taco shells topped with a metal spice tin with a warm heat glow, no text or labels. $styleSuffix"; Model = "gemini-3-pro-image" },
    @{ Name = "l6_hazard_fill"; Prompt = "A texture of bubbling hot amber-brown grease, glossy surface with small bubble highlights. $textureSuffix"; Model = "gemini-3-pro-image" },
    @{ Name = "l6_ground_tile"; Prompt = "A texture of a dark metal sizzling griddle surface with subtle grill marks and a warm orange glow, plain metal only -- no characters, faces, or creatures of any kind anywhere in the pattern. $textureSuffix"; NoRefs = $true; Model = "gemini-3-pro-image" },
    @{ Name = "l6_utensil_rack"; Prompt = "A hanging spatula and tongs on a small rack, for a platformer background decoration. $styleSuffix"; Model = "gemini-3-pro-image" },
    @{ Name = "l6_shell_stack"; Prompt = "A small stack of golden crunchy taco shells, for a platformer background decoration. $styleSuffix"; Model = "gemini-3-pro-image" },
    @{ Name = "l6_window_view"; Prompt = "A dark metal griddle vent-hood frame, with a hazy, softer-detailed distant kitchen scene visible beyond it: silhouettes of more kitchen equipment and shelving lit by warm orange lighting, suggesting depth beyond the frame. No translucent overlay effects, fog, or haze layered on top of the objects -- solid flat-shaded silhouettes only. No characters, faces, or creatures anywhere in the scene -- empty scenery only. $styleSuffix"; NoRefs = $true; Model = "gemini-3-pro-image" },

    @{ Name = "guac_ingredient"; Prompt = "A cute cartoon scoop of green guacamole in a small bowl, collectible icon for a kids' video game, glossy highlight, centered composition. $styleSuffix"; Model = "gemini-3-pro-image" },
    @{ Name = "tomato_ingredient"; Prompt = "A cartoon whole red tomato collectible icon for a kids' video game, glossy highlight, small green stem, centered composition. $styleSuffix"; Model = "gemini-3-pro-image" },
    @{ Name = "sour_cream_ingredient"; Prompt = "A cartoon dollop of white sour cream collectible icon for a kids' video game, glossy highlight, centered composition. $styleSuffix"; Model = "gemini-3-pro-image" },
    @{ Name = "crunchy_shell_ingredient"; Prompt = "A cartoon golden crunchy taco shell collectible icon for a kids' video game, glossy highlight, centered composition. $styleSuffix"; Model = "gemini-3-pro-image" },

    # Phase 5 full-playtest feedback: generic assets (beans, Air Fryer) that
    # never got real art in any prior pass, plus per-level maze-tier walkway
    # textures so L3-6's raised path (F22) looks distinct per level instead
    # of reusing the same gray Polygon2D everywhere.
    @{ Name = "bean_ingredient"; Prompt = "A cute cartoon pinto bean collectible icon for a kids' video game, warm brown with a glossy highlight and a subtle darker speckle pattern, centered composition. $styleSuffix"; Model = "gemini-3-pro-image" },
    @{ Name = "air_fryer_icon"; Prompt = "A cartoon air fryer kitchen appliance power-up icon for a kids' video game, compact rounded body, warm silver and red color, a small glowing dial, centered composition. $styleSuffix"; Model = "gemini-3-pro-image" },
    @{ Name = "l3_maze_tier"; Prompt = "A texture of a raised wooden produce-crate walkway plank, rustic slatted wood matching a farmers-market produce stand, plain boards only -- no characters, faces, or creatures of any kind anywhere in the pattern. $textureSuffix"; NoRefs = $true; Model = "gemini-3-pro-image" },
    @{ Name = "l4_maze_tier"; Prompt = "A texture of a raised wooden market-stall walkway plank, weathered wood matching an outdoor market stall, plain boards only -- no characters, faces, or creatures of any kind anywhere in the pattern. $textureSuffix"; NoRefs = $true; Model = "gemini-3-pro-image" },
    @{ Name = "l5_maze_tier"; Prompt = "A texture of a raised frosted steel walkway plank, cool blue-gray metal with light frost patches matching a walk-in fridge, plain metal only -- no characters, faces, or creatures of any kind anywhere in the pattern. $textureSuffix"; NoRefs = $true; Model = "gemini-3-pro-image" },
    @{ Name = "l6_maze_tier"; Prompt = "A texture of a raised dark griddle-metal walkway plank with a warm orange glow along its edges, matching a sizzling griddle kitchen, plain metal only -- no characters, faces, or creatures of any kind anywhere in the pattern. $textureSuffix"; NoRefs = $true; Model = "gemini-3-pro-image" },

    # Supplementary pose sheets for two already-established characters
    # (Cornchip, Wrap) -- NOT the standard 8-pose Grid-Prompt template, since
    # these add a handful of new poses to an existing character rather than
    # introducing a new one. crop-sprites.ps1's grid-slicer normalizes these
    # onto the SAME canvas size as that character's existing frames (see its
    # $targetCanvasOverrides) so Cornchip/Wrap don't visibly resize when the
    # game switches to one of these new animations.
    @{ Name = "cornchip_extras_grid"; Prompt = (
        "A 2D side-view platformer game character sprite sheet depicting 4 new poses for the same corn-chip character shown in the reference images (upside-down triangle shape, warm golden-yellow with subtle corn speckles, small comedic stick legs, big round friendly cartoon eyes).`n" +
        "The 4 poses, arranged as a 2x2 grid in reading order (left-to-right, top-to-bottom): 1) crouched down tightly with knees pulled up to its chest and arms wrapped in, coiled like a spring about to launch into a spin -- still clearly the same upside-down-triangle-shaped character, not a circular or ball shape, with a couple of small motion-blur speed lines beside it hinting at rotation. 2) leaning back with legs skidding sideways on ice, arms out for balance, small motion lines trailing behind its feet. 3) running, right leg passing directly under the body, left leg trailing back -- an in-between stride position. 4) running, left leg passing directly under the body, right leg trailing back -- the mirrored in-between stride position.`n" +
        "The character's design, colors, and proportions must stay exactly consistent with the reference images across all 4 cells, with generous empty magenta space between every pose so no two poses touch or overlap. $styleSuffix"
    ); Model = "gemini-3-pro-image" },
    @{ Name = "wrap_extras_grid"; Prompt = (
        "A 2D side-view platformer game character sprite sheet depicting 3 new poses for the same round tubular burrito/wrap character shown in the reference images (tan-beige tortilla color with a visible fold seam, small comedic stick legs, big expressive round cartoon eyes).`n" +
        "The 3 poses, arranged in a single horizontal row, left to right: 1) with 2-3 distinct round ingredient bulges poking out along its body, like a snake that swallowed a few eggs -- each bulge a separate clearly-defined rounded lump under the tortilla surface, not just a bumpy or scaly texture, tortilla stretched slightly around them, same neutral happy expression as the reference. 2) with 4-5 distinct round ingredient bulges poking out along its body, each a separate clearly-defined rounded lump, tortilla stretched further and looking pleasantly full, expression starting to look pleased and content. 3) completely packed with distinct round ingredient bulges along its whole body so it looks visibly plump and full, wearing a big warm satisfied smile, eyes happy and relaxed.`n" +
        "The character's design, colors, and proportions must stay exactly consistent with the reference images across all 3 cells, with generous empty magenta space between every pose so no two poses touch or overlap. $styleSuffix"
    ); ExtraRefs = @("characters\wrap\wrap_frame1.png"); Model = "gemini-3-pro-image" }
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
    $refsForThis = if ($sprite.NoRefs) { @() } else { $referenceImageInputs }
    # ExtraRefs: additional character-specific reference images (e.g. that
    # character's own existing frame1) on top of the fixed cornchip/hot-sauce
    # style refs above -- used when generating new poses for an *existing*
    # character, so the model matches that character's specific design
    # (colors, proportions) rather than just the general house style.
    if ($sprite.ExtraRefs) {
        foreach ($extraRefRel in $sprite.ExtraRefs) {
            $extraRefPath = Join-Path $outDir $extraRefRel
            if (Test-Path $extraRefPath) {
                $extraBytes = [IO.File]::ReadAllBytes($extraRefPath)
                $refsForThis += @{
                    type      = "image"
                    mime_type = "image/png"
                    data      = [Convert]::ToBase64String($extraBytes)
                }
            } else {
                Write-Warning "ExtraRef not found, skipping: $extraRefPath"
            }
        }
    }
    $inputItems = @(@{ type = "text"; text = $sprite.Prompt }) + $refsForThis
    $modelForThis = if ($sprite.Model) { $sprite.Model } else { "gemini-3.1-flash-image" }
    $body = @{
        model = $modelForThis
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
            # The API has been observed returning JPEG-encoded bytes (magic
            # number FF D8 FF) even when saved with a .png extension -- this
            # loads fine in most previewers but Godot's texture importer
            # rejects it outright ("Failed loading resource"). Re-encode
            # through System.Drawing so what's on disk always matches its
            # extension.
            if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xD8 -and $bytes[2] -eq 0xFF) {
                Write-Warning "$($sprite.Name): API returned JPEG bytes labeled .png -- re-encoding as real PNG"
                Add-Type -AssemblyName System.Drawing
                $srcMs = New-Object System.IO.MemoryStream(, $bytes)
                $srcBmp = [System.Drawing.Bitmap]::FromStream($srcMs)
                $pngMs = New-Object System.IO.MemoryStream
                $srcBmp.Save($pngMs, [System.Drawing.Imaging.ImageFormat]::Png)
                $bytes = $pngMs.ToArray()
                $srcBmp.Dispose(); $srcMs.Dispose(); $pngMs.Dispose()
            }
            $subdir = Get-AssetSubdir $sprite.Name
            $targetDir = if ($subdir) { Join-Path $outDir $subdir } else { $outDir }
            New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
            $outPath = Join-Path $targetDir "$($sprite.Name).png"
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
