extends Node2D

# Shared logic for every level, reused via configuration rather than one
# script per level (same pattern as boss.gd being reused across bosses):
#   - The 3-life system: Player emits player_hit on every hit regardless of
#     source, and this is what actually decrements lives and restarts the
#     level at 0 -- Player itself just handles the per-hit stumble/respawn.
#   - Counts the scattered bean tokens (group "bean_token"); no on-screen
#     counter yet.
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

@export var level_number: int = 0  # 1-7, used to unlock level_number+1 on completion (GameProgress)
@export var grants_double_jump: bool = false  # Level 6+ (characters.txt Bestiary by Level) -- re-granted per level rather than persisted, see player.gd's has_double_jump comment

@onready var player: CharacterBody2D = $Player
@onready var life_icons: Array = [$HUD/Life1, $HUD/Life2, $HUD/Life3]

var lives := MAX_LIVES
var bean_tokens_collected := 0
var level_complete := false

func _ready() -> void:
	player.player_hit.connect(_on_player_hit)
	if grants_double_jump:
		player.grant_double_jump()
	for token in get_tree().get_nodes_in_group("bean_token"):
		token.collected.connect(_on_bean_token_collected)
	for pickup in get_tree().get_nodes_in_group("life_pickup"):
		pickup.collected.connect(_on_life_pickup_collected)
	_setup_level_bounds()

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
	if lives <= 0:
		await get_tree().create_timer(RESTART_DELAY).timeout
		get_tree().reload_current_scene()

func _on_bean_token_collected() -> void:
	bean_tokens_collected += 1

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
