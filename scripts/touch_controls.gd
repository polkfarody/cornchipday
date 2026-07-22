extends Control

# F44: on-screen touch controls for the mobile Web export. Drives the same
# ui_* actions player.gd already reads via its input_left/right/up/down/jump
# exported vars (default to those names) through Input.action_press/release
# -- zero gameplay script changes needed. Desktop/native builds never see
# this: gated off via OS.has_feature("web") since there's no reliable touch-
# vs-mouse detection worth the complexity here.
# Up/Down are always shown (not just when spin-dash/tomato power are
# granted) because input_up/input_down also drive ClimbZone climbing, which
# isn't ability-gated.

const VIEWPORT_SIZE := Vector2(1280, 720)
const BUTTON_SIZE := Vector2(90, 90)
const BUTTON_MARGIN := 24.0
const BUTTON_GAP := 12.0
const BUTTON_ALPHA := 0.55

# FB34: WorldMap reuses this same scene for its d-pad (move between nodes)
# and accept button (enter the selected level), but "JUMP" doesn't make
# sense outside gameplay -- relabel via this export instead of duplicating
# the scene.
@export var accept_label: String = "JUMP"

func _ready() -> void:
	if not OS.has_feature("web"):
		queue_free()
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var dpad_x := BUTTON_MARGIN
	var dpad_bottom_y := VIEWPORT_SIZE.y - BUTTON_MARGIN - BUTTON_SIZE.y
	_add_button("<", "ui_left", Vector2(dpad_x, dpad_bottom_y))
	_add_button(">", "ui_right", Vector2(dpad_x + BUTTON_SIZE.x + BUTTON_GAP, dpad_bottom_y))
	_add_button("^", "ui_up", Vector2(dpad_x, dpad_bottom_y - BUTTON_SIZE.y - BUTTON_GAP))
	_add_button("v", "ui_down", Vector2(dpad_x + BUTTON_SIZE.x + BUTTON_GAP, dpad_bottom_y - BUTTON_SIZE.y - BUTTON_GAP))

	var jump_pos := Vector2(VIEWPORT_SIZE.x - BUTTON_MARGIN - BUTTON_SIZE.x, dpad_bottom_y)
	_add_button(accept_label, "ui_accept", jump_pos)

func _add_button(button_label: String, action: StringName, button_position: Vector2) -> void:
	var button := Button.new()
	button.text = button_label
	button.position = button_position
	button.size = BUTTON_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.modulate = Color(1.0, 1.0, 1.0, BUTTON_ALPHA)
	button.add_theme_font_size_override("font_size", 28)
	button.button_down.connect(func(): Input.action_press(action))
	button.button_up.connect(func(): Input.action_release(action))
	add_child(button)
