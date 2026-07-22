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

# FB34: mobile Web has no keyboard for ui_left/right/up/down/accept -- reuse
# the same TouchControls scene levels use (d-pad to move between nodes,
# accept button to enter the selected one), relabeled since "JUMP" doesn't
# apply here. Self-removes on non-web builds (see touch_controls.gd).
const TOUCH_CONTROLS_SCENE := preload("res://scenes/TouchControls.tscn")

@onready var avatar: AnimatedSprite2D = $Avatar
@onready var node_markers: Array = [$Node1, $Node2, $Node3, $Node4, $Node5, $Node6, $Node7]
@onready var path_line: Line2D = $PathLine
@onready var bean_count_label: Label = $BeanCount/Label

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
	bean_count_label.text = str(GameProgress.total_beans_collected)
	_refresh_node_visuals()
	var touch_controls: Node = TOUCH_CONTROLS_SCENE.instantiate()
	touch_controls.set("accept_label", "GO")
	add_child(touch_controls)

# FB16: locked levels show a dimmed icon plus a small padlock built
# procedurally (Polygon2D body + a Line2D arc for the shackle) rather than a
# new generated asset -- cheap, and there's nothing level-specific about a
# padlock shape that would benefit from per-level art anyway.
func _refresh_node_visuals() -> void:
	for i in node_markers.size():
		var node: Node2D = node_markers[i]
		var locked := not GameProgress.is_unlocked(i + 1)
		node.modulate = LOCKED_TINT if locked else Color.WHITE
		var existing_lock := node.get_node_or_null("LockIcon")
		if locked and existing_lock == null:
			node.add_child(_build_lock_icon())
		elif not locked and existing_lock != null:
			existing_lock.queue_free()

func _build_lock_icon() -> Node2D:
	var lock := Node2D.new()
	lock.name = "LockIcon"
	lock.z_index = 1

	var body := Polygon2D.new()
	body.color = Color(0.15, 0.15, 0.15, 1.0)
	body.polygon = PackedVector2Array([Vector2(-11, -2), Vector2(11, -2), Vector2(11, 14), Vector2(-11, 14)])
	lock.add_child(body)

	var shackle := Line2D.new()
	shackle.width = 4.0
	shackle.default_color = Color(0.15, 0.15, 0.15, 1.0)
	var points := PackedVector2Array()
	for j in range(9):
		var t := float(j) / 8.0
		var angle := PI + t * PI
		points.append(Vector2(cos(angle) * 8.0, -2.0 + sin(angle) * 8.0))
	shackle.points = points
	lock.add_child(shackle)

	return lock

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
