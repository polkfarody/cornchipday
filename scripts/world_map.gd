extends Node2D

# Phase 4 world map (confirmed 2026-07-20): one connected path, not true
# branching -- the avatar walks node-to-node in whichever screen-direction
# each connection actually points (the path curves for visual variety,
# SMB3-style), computed from the node markers' own positions rather than
# hardcoded per segment, so the .tscn layout stays the single source of
# truth. Locked nodes (level_number > GameProgress.highest_unlocked_level)
# simply can't be walked onto -- forward movement past the frontier is
# refused; walking back to any already-unlocked node and pressing accept
# replays it (e.g. for more beans), no separate code path needed for that.

const MOVE_SPEED := 500.0
const LOCKED_TINT := Color(0.4, 0.4, 0.4, 1.0)

@onready var avatar: AnimatedSprite2D = $Avatar
@onready var node_markers: Array = [$Node1, $Node2, $Node3, $Node4, $Node5, $Node6, $Node7]
@onready var path_line: Line2D = $PathLine

var node_positions: Array = []
var current_index := 0
var is_moving := false

func _ready() -> void:
	for marker in node_markers:
		node_positions.append(marker.position)
	path_line.points = PackedVector2Array(node_positions)
	current_index = clampi(GameProgress.last_played_level - 1, 0, node_positions.size() - 1)
	avatar.position = node_positions[current_index]
	avatar.play("idle")
	_refresh_node_visuals()

func _refresh_node_visuals() -> void:
	for i in node_markers.size():
		node_markers[i].modulate = LOCKED_TINT if not GameProgress.is_unlocked(i + 1) else Color.WHITE

func _process(_delta: float) -> void:
	if is_moving:
		return
	if Input.is_action_just_pressed("ui_accept"):
		_enter_current_level()
		return
	var dir := Vector2.ZERO
	if Input.is_action_just_pressed("ui_right"):
		dir = Vector2.RIGHT
	elif Input.is_action_just_pressed("ui_left"):
		dir = Vector2.LEFT
	elif Input.is_action_just_pressed("ui_up"):
		dir = Vector2.UP
	elif Input.is_action_just_pressed("ui_down"):
		dir = Vector2.DOWN
	if dir != Vector2.ZERO:
		_try_move(dir)

func _try_move(input_dir: Vector2) -> void:
	var target_index := -1
	if current_index + 1 < node_positions.size() and GameProgress.is_unlocked(current_index + 2):
		var delta: Vector2 = node_positions[current_index + 1] - node_positions[current_index]
		if _matches_direction(delta, input_dir):
			target_index = current_index + 1
	if target_index == -1 and current_index - 1 >= 0:
		var delta_back: Vector2 = node_positions[current_index - 1] - node_positions[current_index]
		if _matches_direction(delta_back, input_dir):
			target_index = current_index - 1
	if target_index != -1:
		_move_to(target_index)

func _matches_direction(delta: Vector2, input_dir: Vector2) -> bool:
	if delta.length() < 1.0:
		return false
	var primary: Vector2
	if absf(delta.x) >= absf(delta.y):
		primary = Vector2.RIGHT if delta.x > 0 else Vector2.LEFT
	else:
		primary = Vector2.DOWN if delta.y > 0 else Vector2.UP
	return primary == input_dir

func _move_to(target_index: int) -> void:
	is_moving = true
	current_index = target_index
	avatar.play("run")
	var target_pos: Vector2 = node_positions[target_index]
	var duration: float = avatar.position.distance_to(target_pos) / MOVE_SPEED
	var tween := create_tween()
	tween.tween_property(avatar, "position", target_pos, duration)
	tween.tween_callback(_on_move_finished)

func _on_move_finished() -> void:
	is_moving = false
	avatar.play("idle")

func _enter_current_level() -> void:
	var level_number := current_index + 1
	GameProgress.last_played_level = level_number
	get_tree().change_scene_to_file(GameProgress.level_scene_path(level_number))
