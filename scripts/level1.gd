extends Node2D

# Owns the 3-life system: Player emits player_hit on every hit regardless of
# source (obstacle, enemy, boss), and this is what actually decrements lives
# and restarts the level at 0 -- Player itself just handles the per-hit
# stumble/respawn feel. Also counts the scattered bean tokens (group
# "bean_token"; beans are the main collectible currency, lettuce stays an
# ingredient only -- see additions.txt), though there's no on-screen counter
# for them yet.

const MAX_LIVES := 3
const RESTART_DELAY := 0.6

@onready var player: CharacterBody2D = $Player
@onready var life_icons: Array = [$HUD/Life1, $HUD/Life2, $HUD/Life3]

var lives := MAX_LIVES
var bean_tokens_collected := 0

func _ready() -> void:
	player.player_hit.connect(_on_player_hit)
	for token in get_tree().get_nodes_in_group("bean_token"):
		token.collected.connect(_on_bean_token_collected)

func _on_player_hit() -> void:
	lives -= 1
	if lives >= 0 and lives < life_icons.size():
		life_icons[lives].visible = false
	if lives <= 0:
		await get_tree().create_timer(RESTART_DELAY).timeout
		get_tree().reload_current_scene()

func _on_bean_token_collected() -> void:
	bean_tokens_collected += 1
