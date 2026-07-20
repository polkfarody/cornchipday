extends Node2D

# Shared logic for every level, reused via configuration rather than one
# script per level (same pattern as boss.gd being reused across bosses):
#   - The 3-life system: Player emits player_hit on every hit regardless of
#     source, and this is what actually decrements lives and restarts the
#     level at 0 -- Player itself just handles the per-hit stumble/respawn.
#   - Counts the scattered bean tokens (group "bean_token"); no on-screen
#     counter yet.
#   - Transitions to `next_level_path` once the level's ingredient is
#     collected. Bosses call register_level_ingredient() on whichever node
#     is get_tree().current_scene when they spawn the ingredient, since the
#     ingredient doesn't exist until then and a boss can't assume it'll
#     still be alive by the time the player actually walks over and grabs
#     it a few seconds later.

const MAX_LIVES := 3
const RESTART_DELAY := 0.6
const LEVEL_COMPLETE_DELAY := 1.2

@export var next_level_path: String = ""
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

func register_level_ingredient(ingredient: Node) -> void:
	ingredient.collected.connect(_on_level_ingredient_collected)

func _on_level_ingredient_collected() -> void:
	if level_complete:
		return
	level_complete = true
	await get_tree().create_timer(LEVEL_COMPLETE_DELAY).timeout
	if next_level_path != "":
		get_tree().change_scene_to_file(next_level_path)
