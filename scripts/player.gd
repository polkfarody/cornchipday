extends CharacterBody2D

const SPEED := 220.0
const JUMP_VELOCITY := -420.0
const GRAVITY := 1200.0
const SPRITE_SCALE := Vector2(0.22, 0.22)
const SPRITE_BASE_POSITION := Vector2(0, 2)
const RUN_BOB_AMPLITUDE := 4.0
const RUN_BOB_SPEED := 14.0
const RUN_TILT_DEGREES := 6.0
const SPIN_DURATION := 1.0
const SPIN_TINT := Color(1.3, 1.3, 0.6)
const SLEEP_TINT := Color(0.55, 0.55, 0.9)
const FALL_RESPAWN_Y := 650.0  # missed a jump gap -- same consequence as any other hit
const SLOW_TINT := Color(1.0, 0.85, 0.3)

# Emitted on every hit (obstacle or enemy), whatever the source -- Level1
# listens to this to track lives, so any new hazard type gets lives-tracking
# for free just by calling hit_by_obstacle().
signal player_hit

@onready var sprite: AnimatedSprite2D = $Sprite

var spawn_position: Vector2
var is_stunned := false
var is_asleep := false
var run_cycle_time := 0.0
var speed_multiplier := 1.0

# Air Fryer power-up (feature.md FB7/FB10): once granted, pressing Up briefly
# lets Cornchip defeat any enemy he touches instead of being hurt by it.
var has_spin_dash := false
var is_spinning := false
var spin_time_remaining := 0.0

func _ready() -> void:
	spawn_position = global_position

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if global_position.y > FALL_RESPAWN_Y:
		hit_by_obstacle()

	if is_stunned or is_asleep:
		velocity.x = 0.0
		move_and_slide()
		return

	var direction := Input.get_axis("ui_left", "ui_right")
	velocity.x = direction * SPEED * speed_multiplier
	if direction != 0.0:
		sprite.flip_h = direction < 0.0

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	if has_spin_dash and not is_spinning and Input.is_action_just_pressed("ui_up"):
		_start_spin()
	if is_spinning:
		spin_time_remaining -= delta
		if spin_time_remaining <= 0.0:
			_end_spin()

	move_and_slide()
	_update_animation(delta)

func grant_spin_dash() -> void:
	has_spin_dash = true

func _start_spin() -> void:
	is_spinning = true
	spin_time_remaining = SPIN_DURATION
	sprite.modulate = SPIN_TINT

func _end_spin() -> void:
	is_spinning = false
	sprite.modulate = Color.WHITE

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

# Called by Obstacle/Boss on contact. No lives are lost forever here --
# just a comedic stumble and a respawn at the last place the player stood;
# Level1 is what actually decrements the 3-life counter and restarts the
# level at 0, keeping this stumble-and-recover feel unchanged either way.
func hit_by_obstacle() -> void:
	if is_stunned or is_asleep:
		return
	is_stunned = true
	player_hit.emit()
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
	sprite.modulate = Color.WHITE if not is_spinning else SPIN_TINT
	is_stunned = false

# Cheese's signature effect (characters.txt Bestiary by Level, Level 2):
# a timed incapacitation rather than a hit -- no life lost, just input
# disabled for `duration` seconds while Cornchip naps in place.
func put_to_sleep(duration: float) -> void:
	if is_stunned or is_asleep:
		return
	is_asleep = true
	velocity = Vector2.ZERO
	sprite.play("idle")
	sprite.modulate = SLEEP_TINT
	await get_tree().create_timer(duration).timeout
	is_asleep = false
	sprite.modulate = Color.WHITE if not is_spinning else SPIN_TINT

# Queso Grande's cheese-glob attack (characters.txt Bestiary by Level, Level 2):
# a hazard that slows rather than hits -- no life lost, movement speed is
# temporarily reduced instead.
func apply_slow(duration: float, multiplier: float) -> void:
	speed_multiplier = multiplier
	sprite.modulate = SLOW_TINT
	await get_tree().create_timer(duration).timeout
	speed_multiplier = 1.0
	sprite.modulate = Color.WHITE if not is_spinning else SPIN_TINT
