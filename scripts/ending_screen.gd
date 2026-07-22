extends Node2D

# FB21: a real ending screen, built after the user reopened the "let's
# discuss when we get to this" item and asked to proceed without further
# check-ins. Deliberately wordless celebration (no reading required, same
# pillar as the rest of the game) -- Cornchip and Wrap's own already-built
# celebration poses do the talking, plus confetti. Reuses the title screen's
# "Corn Chip Day" text (the one already-established exemption) rather than
# introducing new wording, and the same play-button prompt icon/motion.

const PROMPT_BASE_Y := 560.0
const BOB_SPEED := 4.0
const BOB_AMPLITUDE := 10.0

@onready var prompt_icon: Polygon2D = $PromptIcon

var bob_time := 0.0

func _ready() -> void:
	$Confetti.emitting = true

func _process(delta: float) -> void:
	bob_time += delta * BOB_SPEED
	prompt_icon.position.y = PROMPT_BASE_Y + sin(bob_time) * BOB_AMPLITUDE
	if Input.is_action_just_pressed("ui_accept"):
		_go_to_world_map()

# FB34: phone browsers have no keyboard, so ui_accept never fires there --
# a screen tap is the touch equivalent of "continue" on this screen.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_go_to_world_map()

func _go_to_world_map() -> void:
	get_tree().change_scene_to_file("res://scenes/WorldMap.tscn")
