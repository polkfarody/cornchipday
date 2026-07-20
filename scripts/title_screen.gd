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

@onready var cornchip: AnimatedSprite2D = $Cornchip
@onready var prompt_icon: Polygon2D = $PromptIcon

var bob_time := 0.0

func _ready() -> void:
	cornchip.play("idle")

func _process(delta: float) -> void:
	bob_time += delta * BOB_SPEED
	prompt_icon.position.y = PROMPT_BASE_Y + sin(bob_time) * BOB_AMPLITUDE
	if Input.is_action_just_pressed("ui_accept"):
		get_tree().change_scene_to_file("res://scenes/WorldMap.tscn")
