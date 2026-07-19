extends CharacterBody2D

# Generic level boss: patrols back and forth, periodically fires a
# projectile, and is defeated by being stomped (jumped on from above)
# `max_health` times. A side/non-stomp touch instead hurts the player via
# the existing hit_by_obstacle() stun-and-respawn, same as any obstacle.
# On defeat, spawns the level's ingredient at ingredient_spawn_position.
# Reused across bosses (Hot Sauce, Avocado, Cheese, Salsa Bowl) rather than
# writing one script per boss.

@export var max_health: int = 3
@export var move_speed: float = 40.0
@export var patrol_half_width: float = 60.0
@export var projectile_scene: PackedScene
@export var fire_interval: float = 3.0
@export var projectile_speed: float = 160.0
@export var ingredient_scene: PackedScene
@export var ingredient_spawn_position: Vector2
@export var sleep_duration: float = 0.0  # > 0: a side touch puts the player to sleep instead of the normal hit stun (Cheese)

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var hurt_area: Area2D = $HurtArea
@onready var fire_timer: Timer = $FireTimer

var health: int
var start_x: float
var patrol_direction := 1.0
var is_defeated := false
var action_lock := 0.0  # seconds remaining where patrol/animation pause for a one-off reaction

func _ready() -> void:
	health = max_health
	start_x = global_position.x
	hurt_area.body_entered.connect(_on_hurt_area_body_entered)
	fire_timer.wait_time = fire_interval
	fire_timer.timeout.connect(_fire_projectile)
	fire_timer.start()
	sprite.play("idle")

func _physics_process(delta: float) -> void:
	if is_defeated:
		return

	if action_lock > 0.0:
		action_lock -= delta
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var offset := global_position.x - start_x
	if offset > patrol_half_width:
		patrol_direction = -1.0
	elif offset < -patrol_half_width:
		patrol_direction = 1.0
	velocity.x = patrol_direction * move_speed
	velocity.y = 0.0
	move_and_slide()
	sprite.flip_h = patrol_direction < 0.0
	if sprite.animation != "move":
		sprite.play("move")

func _fire_projectile() -> void:
	if is_defeated or action_lock > 0.0 or projectile_scene == null:
		return
	sprite.play("attack")
	action_lock = 0.5
	var proj := projectile_scene.instantiate()
	get_tree().current_scene.add_child(proj)
	proj.global_position = global_position
	var dir := -1.0 if sprite.flip_h else 1.0
	proj.set_direction(dir * projectile_speed)

func _on_hurt_area_body_entered(body: Node) -> void:
	if is_defeated or not body.is_in_group("player"):
		return
	# Air Fryer spin dash (feature.md FB7/FB10): any contact while spinning
	# defeats the enemy instead of hurting the player, same as a stomp.
	if body.get("is_spinning") == true:
		_take_stomp_hit(body)
		return
	var is_stomp: bool = body.velocity.y > 0.0 and body.global_position.y < global_position.y - 10.0
	if is_stomp:
		_take_stomp_hit(body)
	elif sleep_duration > 0.0 and body.has_method("put_to_sleep"):
		body.put_to_sleep(sleep_duration)
	elif body.has_method("hit_by_obstacle"):
		body.hit_by_obstacle()

func _take_stomp_hit(player: Node) -> void:
	health -= 1
	player.velocity.y = -380.0
	if health <= 0:
		_die()
		return
	sprite.play("hit")
	action_lock = 0.4

func _die() -> void:
	is_defeated = true
	fire_timer.stop()
	hurt_area.set_deferred("monitoring", false)
	sprite.play("defeated")
	if ingredient_scene:
		var ingredient := ingredient_scene.instantiate()
		get_tree().current_scene.add_child(ingredient)
		ingredient.global_position = ingredient_spawn_position
	await get_tree().create_timer(1.0).timeout
	queue_free()
