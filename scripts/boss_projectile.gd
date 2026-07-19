extends Area2D

# Simple horizontal projectile fired by a boss (e.g. Hot Sauce's sauce
# blast). Queues itself for removal after a fixed lifetime rather than
# trying to detect "off screen", so it works regardless of level layout.

const LIFETIME := 4.0

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
	if body.has_method("hit_by_obstacle"):
		body.hit_by_obstacle()
	queue_free()
