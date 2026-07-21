extends Area2D

# Placed along a level; fires once when the player passes through, spawning
# an obstacle from off-screen. Kept data-driven (scene + position exported)
# so later levels can reuse this node with different obstacles/placements.
@export var obstacle_scene: PackedScene
@export var spawn_position: Vector2

var has_triggered := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if has_triggered or not body.is_in_group("player"):
		return
	has_triggered = true
	var obstacle := obstacle_scene.instantiate()
	# Real bug caught via live playtest: add_child()-ing straight from this
	# Area2D's own body_entered callback can hit Godot's "Can't change this
	# state while flushing queries" -- same class of bug as boss.gd's
	# ingredient/split spawns and level_base.gd's sky-drop pickup, same fix.
	_finish_spawn.call_deferred(obstacle)

func _finish_spawn(obstacle: Node) -> void:
	get_tree().current_scene.add_child(obstacle)
	obstacle.global_position = spawn_position
