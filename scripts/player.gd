extends CharacterBody2D

const SPEED := 220.0
const JUMP_VELOCITY := -420.0
const GRAVITY := 1200.0
const SPRITE_SCALE := Vector2(0.22, 0.22)
const SPRITE_BASE_POSITION := Vector2(0, 8)  # a few px below the collision box's own resting point, so Cornchip's feet sit slightly into the ground line rather than exactly on its top edge -- a cheap depth cue, purely visual (collision/physics untouched)
const RUN_BOB_AMPLITUDE := 4.0
const RUN_BOB_SPEED := 14.0
const RUN_TILT_DEGREES := 6.0
const SPIN_DURATION := 1.0
const SPIN_COOLDOWN := 1.5  # FB27: was instantly re-triggerable on SPIN_DURATION expiry, making the enemy-defeat window spammable into near-permanent invincibility
const SPIN_TINT := Color(1.3, 1.3, 0.6)
const SPIN_ROTATE_SPEED := 900.0  # deg/sec -- the "spin" pose is a single coiled sprite; the actual spin motion comes from rotating it in code rather than needing multiple animation frames
const SLEEP_TINT := Color(0.55, 0.55, 0.9)
const FALL_RESPAWN_Y := 650.0  # missed a jump gap -- same consequence as any other hit
const SLOW_TINT := Color(1.0, 0.85, 0.3)
const WOBBLE_AMPLITUDE := 6.0
const WOBBLE_SPEED := 18.0
const ICE_ACCEL := 300.0  # px/s^2 -- much softer than the instant velocity snap used off-ice, so input lags into a slide
const CLIMB_SPEED := 140.0  # FB33: L2 climbing bonus section -- grabbed by pressing up/down while inside a ClimbZone, released by leaving the zone or jumping off
const CARRY_OFFSET := Vector2(0, -45)  # Wrap finale delivery ritual (Phase 4): held above Cornchip's head, clear of the sprite

# Emitted on every hit (obstacle or enemy), whatever the source -- Level1
# listens to this to track lives, so any new hazard type gets lives-tracking
# for free just by calling hit_by_obstacle().
signal player_hit

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var camera: Camera2D = $Camera2D

var spawn_position: Vector2
var is_stunned := false
var is_asleep := false
var run_cycle_time := 0.0
var speed_multiplier := 1.0
var wobble_time_remaining := 0.0
var wobble_cycle_time := 0.0
var camera_base_offset: Vector2
var is_on_ice := false
var in_climb_zone := false
var is_climbing := false

# Air Fryer power-up (feature.md FB7/FB10): once granted, pressing Up briefly
# lets Cornchip defeat any enemy he touches instead of being hurt by it.
var has_spin_dash := false
var is_spinning := false
var spin_time_remaining := 0.0
var spin_cooldown_remaining := 0.0

# Double jump (characters.txt Bestiary by Level, Level 6): granted permanently
# starting Level 6 (level_base.gd's grants_double_jump), not a pickup -- Air
# Fryer taught us abilities don't survive the scene reload between levels, so
# this is re-granted fresh by whichever level should have it rather than
# trying to persist state across that boundary.
var has_double_jump := false
var air_jumps_used := 0

# Wrap finale delivery ritual (Phase 4, confirmed 2026-07-20): carrying is
# explicitly safe, not risky -- full jump/stomp stays available (this is a
# plain reparent-and-follow, nothing here touches movement/jump/collision),
# so carried_item just rides along as a child node. One at a time by design:
# start_carrying() refuses a second item while one is already held.
var carried_item: Node2D = null

func start_carrying(item: Node2D) -> bool:
	if carried_item != null:
		return false
	var old_parent := item.get_parent()
	if old_parent:
		old_parent.remove_child(item)
	add_child(item)
	item.position = CARRY_OFFSET
	item.rotation = 0.0
	carried_item = item
	return true

# Called by WrapBoss once the carried item is actually delivered -- hands
# ownership back so the caller can free/animate it without the player still
# tracking it as held.
func take_carried_item() -> Node2D:
	var item := carried_item
	if item == null:
		return null
	remove_child(item)
	carried_item = null
	return item

func _ready() -> void:
	spawn_position = global_position
	camera_base_offset = camera.offset

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# Rolling checkpoint: a hit respawns Cornchip near where he actually was,
	# not back at the level's start -- only running out of all 3 lives does
	# that (level_base.gd's reload_current_scene()). Updated continuously
	# while safely grounded, so a missed jump gap naturally checkpoints back
	# to the last solid ledge (no floor contact happens mid-fall to update
	# it), not wherever the fall started.
	if is_on_floor() and not is_stunned and not is_asleep:
		spawn_position = global_position

	if global_position.y > FALL_RESPAWN_Y:
		hit_by_obstacle()

	if is_stunned or is_asleep:
		velocity.x = 0.0
		move_and_slide()
		return

	var direction := Input.get_axis("ui_left", "ui_right")
	var target_velocity_x := direction * SPEED * speed_multiplier
	if is_on_ice:
		velocity.x = move_toward(velocity.x, target_velocity_x, ICE_ACCEL * delta)
	else:
		velocity.x = target_velocity_x
	if direction != 0.0:
		sprite.flip_h = direction < 0.0

	if is_on_floor():
		air_jumps_used = 0

	var climb_vertical := 0.0
	if in_climb_zone:
		if Input.is_action_pressed("ui_up"):
			climb_vertical -= 1.0
		if Input.is_action_pressed("ui_down"):
			climb_vertical += 1.0
		if climb_vertical != 0.0:
			is_climbing = true

	if Input.is_action_just_pressed("ui_accept"):
		if is_climbing:
			is_climbing = false
			velocity.y = JUMP_VELOCITY
		elif is_on_floor():
			velocity.y = JUMP_VELOCITY
		elif has_double_jump and air_jumps_used < 1:
			velocity.y = JUMP_VELOCITY
			air_jumps_used += 1

	if is_climbing:
		velocity.y = climb_vertical * CLIMB_SPEED

	if spin_cooldown_remaining > 0.0:
		spin_cooldown_remaining -= delta
	if has_spin_dash and not is_spinning and spin_cooldown_remaining <= 0.0 and not in_climb_zone and Input.is_action_just_pressed("ui_up"):
		_start_spin()
	if is_spinning:
		spin_time_remaining -= delta
		if spin_time_remaining <= 0.0:
			_end_spin()

	move_and_slide()
	_update_animation(delta)
	_update_wobble(delta)

func grant_spin_dash() -> void:
	has_spin_dash = true

# FB33 (ClimbZone.tscn): entering re-arms the grab (engaged on the next
# up/down press, not automatically -- so brushing past the zone's edge
# mid-jump doesn't suck the player onto it); leaving always releases it
# immediately, same as walking off a ladder.
func set_in_climb_zone(value: bool) -> void:
	in_climb_zone = value
	if not value:
		is_climbing = false

func grant_double_jump() -> void:
	has_double_jump = true

# The Wrap finale (characters.txt Bestiary by Level, Level 7): jumping into a
# lit-up Wrap after delivering all 6 ingredients ends the game right there --
# no next level to transition to, so this just freezes the player in a happy
# pose rather than handing control back.
func win_celebration() -> void:
	set_physics_process(false)
	velocity = Vector2.ZERO
	sprite.position = SPRITE_BASE_POSITION
	sprite.rotation_degrees = 0.0
	sprite.play("celebrate")
	# FB21: hold the in-place celebration briefly (same beat as a normal
	# level-complete transition) before handing off to a real ending screen,
	# rather than freezing here forever.
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://scenes/EndingScreen.tscn")

# Sour Cream Sam's arena (characters.txt Bestiary by Level, Level 5): the
# challenge is the icy floor itself, not a separate attack -- toggled by
# IceZone.tscn's body_entered/body_exited over the boss arena, not a timed
# effect like apply_slow/put_to_sleep.
func set_on_ice(value: bool) -> void:
	is_on_ice = value

# Level 7's guac patch (Phase 4 remix flavor): sticky footing, the traction
# opposite of ice -- a plain toggled slowdown rather than a timed effect like
# apply_slow(), so it can't wear off mid-patch if the player lingers.
func set_on_guac(value: bool) -> void:
	speed_multiplier = 0.45 if value else 1.0

func _start_spin() -> void:
	is_spinning = true
	spin_time_remaining = SPIN_DURATION
	sprite.modulate = SPIN_TINT

func _end_spin() -> void:
	is_spinning = false
	spin_cooldown_remaining = SPIN_COOLDOWN
	sprite.modulate = Color.WHITE
	sprite.rotation_degrees = 0.0

func _update_animation(delta: float) -> void:
	var target := "idle"
	if is_spinning:
		target = "spin"
	elif is_climbing:
		# FB33: no climbing pose exists in the generated art (flagged mismatch,
		# not silently worked around) -- "jump" is the closest existing pose,
		# reused as a stand-in rather than blocking the mechanic on new art.
		target = "jump"
	elif is_on_ice and absf(velocity.x) > 1.0:
		target = "slide"
	elif not is_on_floor():
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
	elif target == "spin":
		# The spin pose is a single coiled sprite -- the actual spin motion
		# is this continuous rotation, not frame-swapping.
		run_cycle_time = 0.0
		sprite.position = SPRITE_BASE_POSITION
		sprite.rotation_degrees = wrapf(sprite.rotation_degrees + SPIN_ROTATE_SPEED * delta, 0.0, 360.0)
	else:
		run_cycle_time = 0.0
		sprite.position = SPRITE_BASE_POSITION
		sprite.rotation_degrees = 0.0

# Onion's nuisance effect (characters.txt Bestiary by Level, Level 3): mere
# proximity, not a hit -- no life lost, no stun, just a brief camera wobble.
# boss.gd re-calls this every physics frame the player stays in range, so a
# short duration here is enough to keep the wobble alive continuously while
# nearby and let it fade out shortly after leaving range.
func apply_screen_wobble(duration: float) -> void:
	wobble_time_remaining = maxf(wobble_time_remaining, duration)

func _update_wobble(delta: float) -> void:
	if wobble_time_remaining <= 0.0:
		return
	wobble_time_remaining -= delta
	if wobble_time_remaining <= 0.0:
		camera.offset = camera_base_offset
		return
	wobble_cycle_time += delta * WOBBLE_SPEED
	camera.offset = camera_base_offset + Vector2(
		sin(wobble_cycle_time) * WOBBLE_AMPLITUDE,
		cos(wobble_cycle_time * 1.3) * WOBBLE_AMPLITUDE * 0.6
	)

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
