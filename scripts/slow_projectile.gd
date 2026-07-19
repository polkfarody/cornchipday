extends Area2D

# Queso Grande's cheese-glob attack: a hazard projectile that slows the
# player on contact instead of costing a life, a different interaction type
# from a standard hit. Shares the same set_direction() interface as
# boss_projectile.gd so boss.gd can fire either kind interchangeably.

const LIFETIME := 4.0

@export var slow_duration: float = 2.5
@export var slow_multiplier: float = 0.4

var velocity_x: float = 0.0
var time_alive: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func set_direction(vx: float) -> void:
	velocity_x = vx

func _physics_process(delta: float) -> void:
	position.x += velocity_x * delta
	time_alive += delta
	if time_alive > LIFETIME:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.has_method("apply_slow"):
		body.apply_slow(slow_duration, slow_multiplier)
	queue_free()
