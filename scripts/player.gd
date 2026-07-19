extends CharacterBody2D

const SPEED := 220.0
const JUMP_VELOCITY := -420.0
const GRAVITY := 1200.0

@onready var body: Polygon2D = $Body

var spawn_position: Vector2
var is_stunned := false

func _ready() -> void:
	spawn_position = global_position

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if is_stunned:
		velocity.x = 0.0
		move_and_slide()
		return

	var direction := Input.get_axis("ui_left", "ui_right")
	velocity.x = direction * SPEED
	if direction != 0.0:
		scale.x = sign(direction) * absf(scale.x)

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	move_and_slide()

# Called by Obstacle on contact. No lives, no game over -- just a comedic
# stumble and a respawn at the last place the player stood, per the
# no-fail-state design pillar in game-brief.txt.
func hit_by_obstacle() -> void:
	if is_stunned:
		return
	is_stunned = true
	velocity = Vector2.ZERO
	var tween := create_tween()
	tween.tween_property(body, "scale", Vector2(1.3, 0.5), 0.15)
	tween.parallel().tween_property(body, "modulate", Color(0.6, 0.85, 0.5), 0.15)
	tween.tween_interval(0.35)
	tween.tween_callback(_respawn)

func _respawn() -> void:
	global_position = spawn_position
	body.scale = Vector2.ONE
	body.modulate = Color.WHITE
	is_stunned = false
