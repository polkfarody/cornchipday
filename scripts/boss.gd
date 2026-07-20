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
@export var hazard_scene: PackedScene  # set instead of projectile_scene: dropped at the boss's own feet on the attack beat rather than fired at the player (Avocado's guac puddle)
@export var wobble_radius: float = 0.0  # > 0: player proximity (not touch) briefly wobbles the screen instead of a hit, checked every physics frame (Onion)
@export var split_into_scene: PackedScene  # set instead of a normal defeat: on the killing blow, spawns split_count copies of this in its place instead of dropping the ingredient itself (Big Red -> two Cherry Tomatoes)
@export var split_count: int = 2
@export var split_offset_x: float = 30.0
@export var shared_defeat_group: String = ""  # when set, only drops the ingredient on death if no other member of this group is still alive -- set programmatically on split-spawned pieces, not meant to be hand-authored in a scene file
@export var cannot_be_stomped: bool = false  # Grease Splatter: a jump-from-above contact hurts the player like any other touch instead of defeating it -- must be avoided entirely, not fought
@export var vulnerable_only_during_attack: bool = false  # Hot Sauce / Avocado: a stomp only lands during (and briefly after) the attack beat -- mistimed, it's a harmless bounce, not a hit
@export var attack_vulnerability_window: float = 1.0
@export var spin_dash_only: bool = false  # Queso Grande: a plain stomp bounces off harmlessly -- only the Air Fryer spin-dash actually defeats him
@export var defeated_by_slide_charge: bool = false  # Sour Cream Sam: not stomped at all -- charging into him at speed while sliding on his own ice is what defeats him
@export var slide_charge_min_speed: float = 150.0
@export var heat_zone_path: NodePath  # Iron Skillet: if set, stomping while this HeatZone is hot burns the player instead of hurting the boss -- only the cool phase is safe to land a hit

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var hurt_area: Area2D = $HurtArea
@onready var fire_timer: Timer = $FireTimer
@onready var body_collision: CollisionShape2D = $CollisionShape2D

var health: int
var start_x: float
var patrol_direction := 1.0
var is_defeated := false
var action_lock := 0.0  # seconds remaining where patrol/animation pause for a one-off reaction
var attack_vulnerable_remaining := 0.0
var heat_zone: Node = null

func _ready() -> void:
	health = max_health
	start_x = global_position.x
	hurt_area.body_entered.connect(_on_hurt_area_body_entered)
	fire_timer.wait_time = fire_interval
	fire_timer.timeout.connect(_perform_attack)
	fire_timer.start()
	sprite.play("idle")
	if heat_zone_path != NodePath():
		heat_zone = get_node(heat_zone_path)

func _physics_process(delta: float) -> void:
	if is_defeated:
		return

	if attack_vulnerable_remaining > 0.0:
		attack_vulnerable_remaining -= delta

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
	elif not _is_floor_ahead(patrol_direction):
		# Turn around before walking off a platform edge, rather than only
		# ever turning at a fixed distance from spawn (which breaks the
		# moment an obstacle or a shorter platform sits inside that range).
		patrol_direction = -patrol_direction
	velocity.x = patrol_direction * move_speed
	velocity.y = 0.0
	move_and_slide()
	# Also turn around immediately on hitting something solid (e.g. a jump
	# obstacle) instead of silently stalling against it until the
	# distance-based check above eventually (never) flips direction.
	# Only a near-horizontal collision normal counts as a wall: standing on
	# flat ground registers a slide collision every single frame too (floor
	# snap contact, normal ~(0,-1)), which would otherwise flip the
	# direction every frame and make the character jitter in place instead
	# of patrolling -- confirmed with a headless repro before this fix.
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if absf(collision.get_normal().x) > 0.5:
			patrol_direction = -patrol_direction
			break
	sprite.flip_h = patrol_direction < 0.0
	if sprite.animation != "move":
		sprite.play("move")

	if wobble_radius > 0.0:
		var player := get_tree().get_first_node_in_group("player")
		if player and global_position.distance_to(player.global_position) <= wobble_radius:
			player.apply_screen_wobble(0.2)

func _is_floor_ahead(direction: float) -> bool:
	var shape: RectangleShape2D = body_collision.shape
	var half_width: float = shape.size.x / 2.0
	var feet_y: float = global_position.y + body_collision.position.y + shape.size.y / 2.0
	var probe_x: float = global_position.x + direction * (half_width + 4.0)
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		Vector2(probe_x, feet_y - 4.0),
		Vector2(probe_x, feet_y + 16.0)
	)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	var result := space_state.intersect_ray(query)
	return not result.is_empty()

# Periodic attack beat: fires a projectile at the player (most bosses) or
# drops a static hazard at the boss's own feet instead (Avocado's guac
# puddle -- a terrain hazard to dodge around, not something aimed at you).
func _perform_attack() -> void:
	if is_defeated or action_lock > 0.0:
		return
	if projectile_scene == null and hazard_scene == null:
		return
	sprite.play("attack")
	action_lock = 0.5
	if vulnerable_only_during_attack:
		attack_vulnerable_remaining = attack_vulnerability_window
	if projectile_scene:
		var proj := projectile_scene.instantiate()
		get_tree().current_scene.add_child(proj)
		proj.global_position = global_position
		var dir := -1.0 if sprite.flip_h else 1.0
		proj.set_direction(dir * projectile_speed)
	elif hazard_scene:
		var shape: RectangleShape2D = body_collision.shape
		var hazard := hazard_scene.instantiate()
		get_tree().current_scene.add_child(hazard)
		hazard.global_position = Vector2(global_position.x, global_position.y + body_collision.position.y + shape.size.y / 2.0)

func _on_hurt_area_body_entered(body: Node) -> void:
	if is_defeated or not body.is_in_group("player"):
		return
	# Air Fryer spin dash (feature.md FB7/FB10): any contact while spinning
	# defeats the enemy instead of hurting the player, same as a stomp --
	# unconditionally, before any of the per-boss unique-defeat rules below.
	if body.get("is_spinning") == true:
		_take_stomp_hit(body)
		return

	if defeated_by_slide_charge:
		# Sour Cream Sam: not stomped at all -- charging into him at speed
		# while sliding on his own ice (see IceZone/player.gd is_on_ice) is
		# what defeats him. A slow approach just hurts you like any touch.
		if absf(body.velocity.x) >= slide_charge_min_speed:
			_take_stomp_hit(body)
		elif body.has_method("hit_by_obstacle"):
			body.hit_by_obstacle()
		return

	var is_stomp: bool = not cannot_be_stomped and body.velocity.y > 0.0 and body.global_position.y < global_position.y - 10.0
	if is_stomp:
		if heat_zone and heat_zone.is_hot:
			# Iron Skillet: stomping during the hot phase burns you instead
			# of hurting him -- only the cool phase is a safe opening.
			if body.has_method("hit_by_obstacle"):
				body.hit_by_obstacle()
		elif spin_dash_only:
			body.velocity.y = -380.0  # Queso Grande: a plain stomp bounces off harmlessly
		elif vulnerable_only_during_attack and attack_vulnerable_remaining <= 0.0:
			body.velocity.y = -380.0  # Hot Sauce / Avocado: wrong timing, bounces off harmlessly
		else:
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

	if split_into_scene:
		# Big Red's split (characters.txt Bestiary by Level, Level 4): the
		# killing blow doesn't drop the ingredient itself -- it spawns the
		# split pieces, hands each one this boss's own ingredient config
		# plus a group name unique to this split event, and the ingredient
		# only actually drops once the last piece in that group falls (see
		# the shared_defeat_group check below).
		var level := get_tree().current_scene
		var group_name := "split_%d" % get_instance_id()
		for i in split_count:
			var piece := split_into_scene.instantiate()
			level.add_child(piece)
			piece.global_position = global_position + Vector2((i - (split_count - 1) / 2.0) * split_offset_x, 0)
			piece.add_to_group(group_name)
			piece.shared_defeat_group = group_name
			piece.ingredient_scene = ingredient_scene
			piece.ingredient_spawn_position = ingredient_spawn_position
		await get_tree().create_timer(1.0).timeout
		queue_free()
		return

	if shared_defeat_group != "":
		# Leave the group immediately (not deferred to queue_free(), which
		# only actually happens after the timeout below) -- two group-mates
		# defeated in the same frame must each see the other's *current*
		# alive-ness, not a stale membership list neither has left yet.
		remove_from_group(shared_defeat_group)
		if not get_tree().get_nodes_in_group(shared_defeat_group).is_empty():
			# Still-living group-mates (e.g. the other Cherry Tomato) -- this
			# piece falls but the encounter isn't over yet, so no ingredient.
			await get_tree().create_timer(1.0).timeout
			queue_free()
			return

	if ingredient_scene:
		var ingredient := ingredient_scene.instantiate()
		var level := get_tree().current_scene
		level.add_child(ingredient)
		ingredient.global_position = ingredient_spawn_position
		if level.has_method("register_level_ingredient"):
			level.register_level_ingredient(ingredient)
	await get_tree().create_timer(1.0).timeout
	queue_free()
