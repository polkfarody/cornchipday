extends Node2D

# Manual parallax: shifts this holder (and everything under it) at a
# fraction of the camera's movement, so its children appear farther away
# than normal foreground content. Deliberately not Godot's own
# ParallaxBackground/ParallaxLayer -- that's a CanvasLayer, and getting a
# CanvasLayer's draw order right relative to plain scene content (the sky
# bands, ground, etc.) proved unreliable in practice. Staying a plain Node2D
# means the existing tree-order depth ordering (drawn after the sky bands,
# before gameplay content) keeps working exactly like every other background
# decoration in the level, with the scroll math handled separately here.
@export var motion_scale: float = 0.4

var _camera: Camera2D
var _camera_start: Vector2
var _tracking := false

func _process(_delta: float) -> void:
	if not _tracking:
		_camera = get_viewport().get_camera_2d()
		if _camera == null:
			return
		_camera_start = _camera.global_position
		_tracking = true
	position = (_camera.global_position - _camera_start) * (1.0 - motion_scale)
