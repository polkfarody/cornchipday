extends CharacterBody2D

const SPEED := 220.0
const JUMP_VELOCITY := -420.0
const GRAVITY := 1200.0
const SPRITE_SCALE := Vector2(0.22, 0.22)
const SPRITE_BASE_POSITION := Vector2(0, 2)
const RUN_BOB_AMPLITUDE := 4.0
const RUN_BOB_SPEED := 14.0
const RUN_TILT_DEGREES := 6.0

@onready var sprite: AnimatedSprite2D = $Sprite

var spawn_position: Vector2
var is_stunned := false
var run_cycle_time := 0.0

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
		sprite.flip_h = direction < 0.0

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	move_and_slide()
	_update_animation(delta)

func _update_animation(delta: float) -> void:
	var target := "idle"
	if not is_on_floor():
		target = "jump"
	elif absf(velocity.x) > 1.0:
		target = "run"
	if sprite.animation != target:
		sprite.play(target)

	# The run cycle only has one real pose to work with, so the sense of
	# motion comes from a procedural bob + tilt rather than frame-swapping.
	if target == "run":
		run_cycle_time += delta * RUN_BOB_SPEED
		sprite.position = SPRITE_BASE_POSITION + Vector2(0, sin(run_cycle_time) * RUN_BOB_AMPLITUDE)
		sprite.rotation_degrees = sin(run_cycle_time) * RUN_TILT_DEGREES
	else:
		run_cycle_time = 0.0
		sprite.position = SPRITE_BASE_POSITION
		sprite.rotation_degrees = 0.0

# Called by Obstacle on contact. No lives, no game over -- just a comedic
# stumble and a respawn at the last place the player stood, per the
# no-fail-state design pillar in game-brief.txt.
func hit_by_obstacle() -> void:
	if is_stunned:
		return
	is_stunned = true
	velocity = Vector2.ZERO
	sprite.position = SPRITE_BASE_POSITION
	sprite.rotation_degrees = 0.0
	sprite.play("hit")
	var tween := create_tween()
	tween.tween_property(sprite, "scale", SPRITE_SCALE * Vector2(1.3, 0.5), 0.15)
	tween.parallel().tween_property(sprite, "modulate", Color(0.6, 0.85, 0.5), 0.15)
	tween.tween_interval(0.35)
	tween.tween_callback(_respawn)

func _respawn() -> void:
	global_position = spawn_position
	sprite.scale = SPRITE_SCALE
	sprite.modulate = Color.WHITE
	is_stunned = false
