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
