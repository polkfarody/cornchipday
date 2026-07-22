extends Node2D

# Phase 4 title screen (confirmed 2026-07-20): the game's actual entry point
# now (see project.godot's run/main_scene, previously Level1.tscn directly).
# "Corn Chip Day" is the one piece of text exempted from the no-reading-
# required pillar -- it's the game's name, same as a box cover; everything
# else here (the bouncing prompt icon, Cornchip's idle animation) stays
# icon/animation-driven, not text.

const PROMPT_BASE_Y := 520.0
const BOB_SPEED := 4.0
const BOB_AMPLITUDE := 10.0

# FB: idle used to loop the open-eyes/wink frames continuously (a full cycle
# every 0.8s), reading as too frequent/nervous. Held still on the plain
# open-eyes pose (frame 0) most of the time instead, cutting to the wink
# (frame 1) only for a brief BLINK_DURATION on a randomized timer -- reuses
# the same 2 existing frames, no new art needed.
const BLINK_MIN_INTERVAL := 2.5
const BLINK_MAX_INTERVAL := 5.0
const BLINK_DURATION := 0.15

@onready var cornchip: AnimatedSprite2D = $Cornchip
@onready var prompt_icon: Polygon2D = $PromptIcon

var bob_time := 0.0
var blink_timer := 0.0
var is_blinking := false

func _ready() -> void:
	cornchip.stop()
	cornchip.animation = "idle"
	cornchip.frame = 0
	blink_timer = randf_range(BLINK_MIN_INTERVAL, BLINK_MAX_INTERVAL)

func _process(delta: float) -> void:
	bob_time += delta * BOB_SPEED
	prompt_icon.position.y = PROMPT_BASE_Y + sin(bob_time) * BOB_AMPLITUDE

	blink_timer -= delta
	if blink_timer <= 0.0:
		if is_blinking:
			is_blinking = false
			cornchip.frame = 0
			blink_timer = randf_range(BLINK_MIN_INTERVAL, BLINK_MAX_INTERVAL)
		else:
			is_blinking = true
			cornchip.frame = 1
			blink_timer = BLINK_DURATION

	if Input.is_action_just_pressed("ui_accept"):
		_go_to_world_map()

# FB34: phone browsers have no keyboard, so ui_accept never fires there --
# a screen tap is the touch equivalent of "continue" on this screen.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_go_to_world_map()

func _go_to_world_map() -> void:
	get_tree().change_scene_to_file("res://scenes/WorldMap.tscn")
