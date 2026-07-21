extends Node2D

# Shared logic for every level, reused via configuration rather than one
# script per level (same pattern as boss.gd being reused across bosses):
#   - The 3-life system: Player emits player_hit on every hit regardless of
#     source, and this is what actually decrements lives and restarts the
#     level at 0 -- Player itself just handles the per-hit stumble/respawn.
#   - Counts the scattered bean tokens (group "bean_token") and shows a
#     collected/total counter in the HUD (FB24), plus adds every collected
#     bean to GameProgress's persisted lifetime total.
#   - Returns to WorldMap.tscn once the level's ingredient is collected
#     (Phase 4 world map, confirmed 2026-07-20 -- previously chained
#     straight into next_level_path; the map is now the hub between every
#     level). Bosses call register_level_ingredient() on whichever node is
#     get_tree().current_scene when they spawn the ingredient, since the
#     ingredient doesn't exist until then and a boss can't assume it'll
#     still be alive by the time the player actually walks over and grabs
#     it a few seconds later.

const MAX_LIVES := 3
const RESTART_DELAY := 0.6
const LEVEL_COMPLETE_DELAY := 1.2
const WORLD_MAP_PATH := "res://scenes/WorldMap.tscn"

# FB29: derived from the level's own "Ground*" StaticBody2D pieces (all
# scenes follow this naming convention -- see boss.gd's own reliance on
# "Ground" prefix for floor-ahead patrol checks) rather than hand-authored
# per level, so it stays correct automatically as levels get edited.
const BOUNDARY_WALL_HEIGHT := 4000.0
const BOUNDARY_MARGIN := 40.0
const PIT_FALL_CAMERA_MARGIN := 120.0  # lets a pit-fall dip the camera a little for game feel, without scrolling into the empty space below the level

# FB30: full-run-feedback.txt asked for extra lives to be harder to come by,
# and specifically for one to "drop from the sky" as a comeback chance once
# down to the last life -- rather than only ever sitting in a fixed spot on
# the level's main path. Spawns above wherever the player currently is (the
# rolling checkpoint means that's also roughly where they'll respawn) and
# tweens down to rest on the ground, so it's always somewhere the player can
# actually reach without backtracking.
const SKY_LIFE_DROP_SCENE := preload("res://scenes/LifePickup.tscn")
const SKY_LIFE_DROP_HEIGHT_ABOVE := 500.0
const SKY_LIFE_DROP_FALL_TIME := 0.6

# FB24: built at runtime rather than hand-added to all 7 level scenes, same
# reasoning as the boundary walls above -- one place to change, and it can't
# drift out of sync between levels.
const BEAN_ICON_TEXTURE := preload("res://Assets/generated/items/bean_ingredient.png")

@export var level_number: int = 0  # 1-7, used to unlock level_number+1 on completion (GameProgress)
@export var grants_double_jump: bool = false  # Level 6+ (characters.txt Bestiary by Level) -- re-granted per level rather than persisted, see player.gd's has_double_jump comment

@onready var player: CharacterBody2D = $Player
@onready var life_icons: Array = [$HUD/Life1, $HUD/Life2, $HUD/Life3]

var lives := MAX_LIVES
var bean_tokens_collected := 0
var bean_total := 0
var bean_count_label: Label
var level_complete := false
var level_floor_y := 592.0  # overwritten by _setup_level_bounds() from the level's real ground pieces

func _ready() -> void:
	player.player_hit.connect(_on_player_hit)
	if grants_double_jump:
		player.grant_double_jump()
	bean_total = get_tree().get_nodes_in_group("bean_token").size()
	for token in get_tree().get_nodes_in_group("bean_token"):
		token.collected.connect(_on_bean_token_collected)
	for pickup in get_tree().get_nodes_in_group("life_pickup"):
		pickup.collected.connect(_on_life_pickup_collected)
	_setup_level_bounds()
	_setup_bean_hud()

func _setup_bean_hud() -> void:
	if bean_total <= 0:
		return
	var hud: CanvasLayer = $HUD
	var icon := TextureRect.new()
	icon.texture = BEAN_ICON_TEXTURE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	icon.offset_left = 20.0
	icon.offset_top = 64.0
	icon.offset_right = 56.0
	icon.offset_bottom = 100.0
	hud.add_child(icon)

	bean_count_label = Label.new()
	bean_count_label.offset_left = 62.0
	bean_count_label.offset_top = 64.0
	bean_count_label.offset_right = 200.0
	bean_count_label.offset_bottom = 100.0
	bean_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bean_count_label.add_theme_font_size_override("font_size", 28)
	bean_count_label.add_theme_color_override("font_color", Color.WHITE)
	bean_count_label.add_theme_color_override("font_outline_color", Color.BLACK)
	bean_count_label.add_theme_constant_override("outline_size", 4)
	bean_count_label.text = "0/%d" % bean_total
	hud.add_child(bean_count_label)

# FB29: the camera used to be able to scroll arbitrarily far down/left/right
# of the level's actual content -- most visible as a jarring dip into empty
# space below a pit before the FALL_RESPAWN_Y stun-and-respawn kicked in, but
# also let the player walk clean off either end of the level. Both fixed the
# same way: derive the level's real bounds from its own ground pieces.
func _setup_level_bounds() -> void:
	var min_left := INF
	var max_right := -INF
	var max_floor_y := -INF
	for child in get_children():
		if not (child is StaticBody2D and child.name.begins_with("Ground")):
			continue
		for sub in child.get_children():
			if sub is CollisionShape2D and sub.shape is RectangleShape2D:
				var shape: RectangleShape2D = sub.shape
				var center_x: float = child.position.x + sub.position.x
				var center_y: float = child.position.y + sub.position.y
				min_left = min(min_left, center_x - shape.size.x / 2.0)
				max_right = max(max_right, center_x + shape.size.x / 2.0)
				max_floor_y = max(max_floor_y, center_y - shape.size.y / 2.0)
	if min_left == INF:
		return

	var camera: Camera2D = player.get_node("Camera2D")
	camera.limit_left = int(min_left)
	camera.limit_right = int(max_right)
	camera.limit_bottom = int(max_floor_y + PIT_FALL_CAMERA_MARGIN)
	level_floor_y = max_floor_y

	_add_boundary_wall(min_left - BOUNDARY_MARGIN, "BoundaryWallLeft")
	_add_boundary_wall(max_right + BOUNDARY_MARGIN, "BoundaryWallRight")

func _add_boundary_wall(x: float, wall_name: String) -> void:
	var wall := StaticBody2D.new()
	wall.name = wall_name
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20.0, BOUNDARY_WALL_HEIGHT)
	collision.shape = shape
	wall.add_child(collision)
	wall.position = Vector2(x, 0.0)
	add_child(wall)

func _on_player_hit() -> void:
	if level_complete:
		return
	lives -= 1
	if lives >= 0 and lives < life_icons.size():
		life_icons[lives].visible = false
	if lives == 1:
		_spawn_sky_life_drop()
	if lives <= 0:
		await get_tree().create_timer(RESTART_DELAY).timeout
		get_tree().reload_current_scene()

func _spawn_sky_life_drop() -> void:
	var pickup: Area2D = SKY_LIFE_DROP_SCENE.instantiate()
	pickup.collected.connect(_on_life_pickup_collected)
	add_child(pickup)
	var target_y := level_floor_y - 20.0
	pickup.position = Vector2(player.global_position.x, target_y - SKY_LIFE_DROP_HEIGHT_ABOVE)
	var tween := create_tween()
	tween.tween_property(pickup, "position:y", target_y, SKY_LIFE_DROP_FALL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _on_bean_token_collected() -> void:
	bean_tokens_collected += 1
	GameProgress.add_beans(1)
	if bean_count_label:
		bean_count_label.text = "%d/%d" % [bean_tokens_collected, bean_total]

# Extra-life pickup (feature.md backlog, direct user request): capped at
# MAX_LIVES so the icon-only HUD never needs a 4th slot or a number. Reveals
# the icon this exact life level corresponds to, mirroring how
# _on_player_hit hides icons by index.
func _on_life_pickup_collected() -> void:
	if lives >= MAX_LIVES:
		return
	if lives < life_icons.size():
		life_icons[lives].visible = true
	lives += 1

func register_level_ingredient(ingredient: Node) -> void:
	ingredient.collected.connect(_on_level_ingredient_collected)

func _on_level_ingredient_collected() -> void:
	if level_complete:
		return
	level_complete = true
	if level_number > 0:
		GameProgress.unlock_level(level_number + 1)
		GameProgress.last_played_level = level_number
	await get_tree().create_timer(LEVEL_COMPLETE_DELAY).timeout
	get_tree().change_scene_to_file(WORLD_MAP_PATH)
